(* Income & Expense Report: period-based P/L analysis by month, cycle, year, or all-time. *)
module B = Bakhlo_sexp.Daily_book
module Roles = Locus_roles
module O = Daily_overlays
module Cal = Daily_calendar
module A = Daily_draft
module D = Bakhlo_domain

type period_preset = Month | Cycle | Previous_cycle | Year | All_time
type period = { preset : period_preset; start_day : string; end_exclusive : string; label : string }
type line_item = { locus : string; label : string; amount : Z.t }

type measure_summary = {
  measure : string;
  income_items : line_item list;
  total_income : Z.t;
  expense_items : line_item list;
  total_expense : Z.t;
  scheduled_expense : Z.t;
  ordinary_expense : Z.t;
  net_savings : Z.t;
}

type report = {
  period : period;
  summaries : measure_summary list;
  unresolved_effects : (string * string * string * Z.t) list;
}

type t = {
  preset : period_preset;
  period_offset : int;
  selected_row : int;
  detail_focused : bool;
  detail_scroll : int;
}

let initial () =
  { preset = Cycle; period_offset = 0; selected_row = 0; detail_focused = false; detail_scroll = 0 }

let preset_label = function
  | Month -> "Month"
  | Cycle -> "Cycle"
  | Previous_cycle -> "Previous Cycle"
  | Year -> "Year"
  | All_time -> "All Time"

let presets = [ Month; Cycle; Previous_cycle; Year; All_time ]

(* Every window of boundary-presets.tsv as (name, start, end-exclusive). *)
let parse_boundary_presets text =
  match Boundary_presets.parse text with
  | Ok presets -> Ok (Boundary_presets.windows presets)
  | Error () -> Error "Malformed boundary-presets.tsv; no period was inferred."

let resolve_period ~today ~preset ~offset ~boundary_presets_text =
  match preset with
  | Month -> (
      let base_month_start = String.sub today 0 8 ^ "01" in
      match Cal.shift_months base_month_start offset with
      | Error e -> Error e
      | Ok start_day -> (
          match Cal.shift_months start_day 1 with
          | Error e -> Error e
          | Ok end_exclusive ->
              Ok
                {
                  preset;
                  start_day;
                  end_exclusive;
                  label = Printf.sprintf "Month of %s" (String.sub start_day 0 7);
                }))
  | Year -> (
      let base_year_start = String.sub today 0 4 ^ "-01-01" in
      match Cal.shift_years base_year_start offset with
      | Error e -> Error e
      | Ok start_day -> (
          match Cal.shift_years start_day 1 with
          | Error e -> Error e
          | Ok end_exclusive ->
              Ok
                {
                  preset;
                  start_day;
                  end_exclusive;
                  label = Printf.sprintf "Year %s" (String.sub start_day 0 4);
                }))
  | All_time ->
      Ok
        {
          preset;
          start_day = "0001-01-01";
          end_exclusive = "9999-12-31";
          label = "All Time (Full Ledger)";
        }
  | Cycle | Previous_cycle -> (
      match boundary_presets_text with
      | None -> Error "Cycle not configured in boundary-presets.tsv."
      | Some text -> (
          match parse_boundary_presets text with
          | Error e -> Error e
          | Ok windows -> (
              let current_window =
                List.find_opt (fun (_, a, b) -> a <= today && today < b) windows
              in
              match current_window with
              | None -> Error "No explicit boundary preset contains today."
              | Some (name, cur_a, cur_b) ->
                  let name_windows = List.filter (fun (n, _, _) -> n = name) windows in
                  let current_idx =
                    match
                      List.find_index (fun (_, a, b) -> a = cur_a && b = cur_b) name_windows
                    with
                    | Some idx -> idx
                    | None -> 0
                  in
                  let target_idx =
                    if preset = Previous_cycle then current_idx - 1 + offset
                    else current_idx + offset
                  in
                  if target_idx < 0 || target_idx >= List.length name_windows then
                    Error "Cycle boundary is outside configured presets."
                  else
                    let _, start_day, end_exclusive = List.nth name_windows target_idx in
                    let cycle_name =
                      if preset = Previous_cycle then "Previous Cycle" else "Cycle"
                    in
                    Ok
                      {
                        preset;
                        start_day;
                        end_exclusive;
                        label = Printf.sprintf "%s (%s .. %s)" cycle_name start_day end_exclusive;
                      })))

let compute_report ~book ~roles ~period =
  let entries = B.entries book in
  let plans = B.plans book in
  let in_period (e : B.entry) = e.day >= period.start_day && e.day < period.end_exclusive in
  let period_entries = List.filter in_period entries in
  let measures = List.map fst (B.measures book) |> List.sort_uniq String.compare in
  let is_scheduled_payment (e : B.entry) =
    List.exists (fun (p : B.plan) -> p.paid_by = Some e.id) plans
  in

  let unresolved_acc = ref [] in

  let summaries =
    List.map
      (fun measure ->
        let income_map = Hashtbl.create 16 in
        let expense_map = Hashtbl.create 16 in
        let scheduled_expense_acc = ref Z.zero in
        let ordinary_expense_acc = ref Z.zero in

        List.iter
          (fun (e : B.entry) ->
            let is_sched = is_scheduled_payment e in
            List.iter
              (fun eff ->
                if A.mstr (D.Effect.measure eff) = measure then
                  let locus = A.lstr (D.Effect.locus eff) in
                  let quanta = A.quanta eff in
                  match List.assoc_opt locus roles with
                  | Some Roles.Income ->
                      (* Credit is negative in raw effects; positive income is -quanta *)
                      let inc = Z.neg quanta in
                      let cur = Option.value ~default:Z.zero (Hashtbl.find_opt income_map locus) in
                      Hashtbl.replace income_map locus (Z.add cur inc)
                  | Some Roles.Expense ->
                      (* Debit is positive in raw effects; positive expense is quanta *)
                      let exp = quanta in
                      let cur = Option.value ~default:Z.zero (Hashtbl.find_opt expense_map locus) in
                      Hashtbl.replace expense_map locus (Z.add cur exp);
                      if is_sched then scheduled_expense_acc := Z.add !scheduled_expense_acc exp
                      else ordinary_expense_acc := Z.add !ordinary_expense_acc exp
                  | Some (Asset | Liability | Equity) ->
                      (* Balance sheet accounts; excluded from P/L *)
                      ()
                  | None -> unresolved_acc := (e.day, locus, measure, quanta) :: !unresolved_acc)
              e.effects)
          period_entries;

        let to_line_items map =
          Hashtbl.fold
            (fun locus amount acc ->
              let label = B.label book locus in
              let display_name =
                if label <> "" && label <> locus then Printf.sprintf "%s [%s]" label locus
                else locus
              in
              { locus; label = display_name; amount } :: acc)
            map []
          |> List.sort (fun a b -> String.compare a.label b.label)
        in
        let income_items = to_line_items income_map in
        let expense_items = to_line_items expense_map in
        let total_income =
          List.fold_left (fun acc item -> Z.add acc item.amount) Z.zero income_items
        in
        let total_expense =
          List.fold_left (fun acc item -> Z.add acc item.amount) Z.zero expense_items
        in
        let net_savings = Z.sub total_income total_expense in
        {
          measure;
          income_items;
          total_income;
          expense_items;
          total_expense;
          scheduled_expense = !scheduled_expense_acc;
          ordinary_expense = !ordinary_expense_acc;
          net_savings;
        })
      measures
  in
  { period; summaries; unresolved_effects = List.rev !unresolved_acc }

(* A Measure is active when the window has any role-classified income or expense.
   Inactive Measures are named once instead of painted as empty blocks. *)
(* A Measure is active when the window has any role-classified income or expense.
   Inactive Measures are named once instead of painted as empty blocks. *)
let measure_active (ms : measure_summary) = ms.income_items <> [] || ms.expense_items <> []

let split_measures summaries = List.partition measure_active summaries

let by_amount_desc (items : line_item list) =
  List.sort (fun a b -> Z.compare b.amount a.amount) items

let signed book measure value =
  (if Z.sign value > 0 then "+" else "") ^ O.format_money book measure value

(* Proportional bar in the room that is left after the label and the exact
   amount. The amount is right-aligned and never clipped; when the room is too
   small the bar disappears first. *)
let bar ~room amount max_amount =
  if room < 3 || Z.sign amount <= 0 || Z.sign max_amount <= 0 then ""
  else
    let cells =
      if Z.gt amount max_amount then room
      else Z.to_int (Z.div (Z.mul (Z.of_int room) amount) max_amount)
    in
    String.concat "" (List.init (max 0 (min room cells)) (fun _ -> "█"))

let item_lines ~width_of ~pad_w ~book ~measure ~with_bar items =
  let col_locus = max 18 (min 36 (pad_w / 2)) in
  let col_amt = max 12 (min 22 (pad_w - col_locus - 6)) in
  let max_amount =
    List.fold_left (fun acc (it : line_item) -> if Z.gt it.amount acc then it.amount else acc) Z.zero items
  in
  List.map
    (fun (it : line_item) ->
      let amount = O.format_money book measure it.amount in
      let amount_cell = O.pad_left ~width_of col_amt amount in
      let label_cell = O.pad ~width_of col_locus it.label in
      let bar_room =
        if not with_bar then 0
        else max 0 (pad_w - width_of label_cell - width_of amount_cell - 2)
      in
      let mark = bar ~room:bar_room it.amount max_amount in
      ( O.Plain,
        "  " ^ label_cell ^ "  " ^ amount_cell ^ if mark = "" then "" else "  " ^ mark ))
    (by_amount_desc items)

let render_report_lines ~width ~width_of ~book ~report ~previous =
  let pad_w = max 0 (width - 4) in
  let previous_measure measure =
    Option.bind previous (fun (prev : report) ->
        List.find_opt (fun (ms : measure_summary) -> ms.measure = measure) prev.summaries)
  in
  let header =
    [
      (O.Heading, Printf.sprintf "Income & Expense  [%s]" report.period.label);
      ( O.Chrome,
        Printf.sprintf "Window: %s .. %s (exclusive)" report.period.start_day
          report.period.end_exclusive );
      ( O.Plain,
        match previous with
        | None -> "Previous window: none of this kind (nothing inferred)."
        | Some (prev : report) -> "Previous: " ^ prev.period.label );
      (O.Plain, "");
    ]
  in
  let totals_block (ms : measure_summary) =
    let m = ms.measure in
    let prev = previous_measure m in
    let prev_of pick = Option.map pick prev in
    let line label current previous_value =
      let amount = O.format_money book m current ^ " " ^ m in
      let assemble detail = Printf.sprintf "  %-10s %14s   %s" label amount detail in
      let text =
        match previous_value with
        | None -> assemble "prev n/a"
        | Some prev_value ->
            let delta = Z.sub current prev_value in
            let detailed =
              assemble
                (Printf.sprintf "prev %s  %s" (O.format_money book m prev_value)
                   (signed book m delta))
            in
            (* Keep the difference itself when the full comparison does not fit. *)
            if width_of detailed <= pad_w then detailed
            else assemble (Printf.sprintf "Δ %s" (signed book m delta))
      in
      (O.Active, text)
    in
    [
      (O.Heading, Printf.sprintf "Currency: %s" m);
      line "Income" ms.total_income (prev_of (fun (p : measure_summary) -> p.total_income));
      line "Expense" ms.total_expense (prev_of (fun (p : measure_summary) -> p.total_expense));
      line "Result" ms.net_savings (prev_of (fun (p : measure_summary) -> p.net_savings));
      ( O.Plain,
        Printf.sprintf "  split: Scheduled %s  |  other %s"
          (O.format_money book m ms.scheduled_expense ^ " " ^ m)
          (O.format_money book m ms.ordinary_expense ^ " " ^ m) );
      (O.Plain, "");
    ]
  in
  let breakdown (ms : measure_summary) =
    if ms.expense_items = [] then []
    else
      (O.Chrome, "  Expense by Locus (largest first)")
      :: item_lines ~width_of ~pad_w ~book ~measure:ms.measure ~with_bar:true ms.expense_items
      @ [ (O.Plain, "") ]
  in
  let income_breakdown (ms : measure_summary) =
    if ms.income_items = [] then []
    else
      (O.Chrome, "  Income by Locus (largest first)")
      :: item_lines ~width_of ~pad_w ~book ~measure:ms.measure ~with_bar:false ms.income_items
      @ [ (O.Plain, "") ]
  in
  let active, inactive = split_measures report.summaries in
  let summaries_lines =
    List.concat_map
      (fun (ms : measure_summary) ->
        totals_block ms @ breakdown ms @ income_breakdown ms)
      active
  in
  let empty_lines =
    if active = [] then [ (O.Chrome, "  (no role-classified activity in this window)") ] else []
  in
  let inactive_lines =
    match inactive with
    | [] -> []
    | names ->
        [
          ( O.Chrome,
            "No activity in this window: "
            ^ String.concat ", " (List.map (fun (ms : measure_summary) -> ms.measure) names) );
        ]
  in
  let unresolved_lines =
    if report.unresolved_effects = [] then []
    else
      [
        (O.Status, "── Unresolved Role Effects ─────────────────────────────────────────");
        ( O.Chrome,
          "Activity exists on accounts without explicit accounting role in accounting-roles.tsv:" );
      ]
      @ List.map
          (fun (date, locus, m, q) ->
            (O.Plain, Printf.sprintf "  %s  %-20s  %s %s" date locus (O.format_money book m q) m))
          report.unresolved_effects
  in
  header @ summaries_lines @ empty_lines @ inactive_lines @ unresolved_lines

(* Compare view: the last N windows of the same kind side by side. Rows are the
   answers; columns are windows. Measures stay separate (one block per Measure). *)
let render_compare_lines ~width ~width_of ~book ~reports =
  let pad_w = max 0 (width - 4) in
  let n_total = List.length reports in
  let label_w = min 20 (max 12 (pad_w * 30 / 100)) in
  let room = max 0 (pad_w - label_w - 1) in
  let col_w = 14 in
  let fits = max 1 (room / col_w) in
  let n = min n_total fits in
  let reports =
    let skip = max 0 (n_total - n) in
    List.filteri (fun i _ -> i >= skip) reports
  in
  let measures =
    List.sort_uniq String.compare
      (List.concat_map (fun (_, (r : report)) -> List.map (fun (ms : measure_summary) -> ms.measure) r.summaries) reports)
  in
  let measure_active_in measure =
    List.exists
      (fun (_, (r : report)) ->
        List.exists
          (fun (ms : measure_summary) -> ms.measure = measure && measure_active ms)
          r.summaries)
      reports
  in
  let summary_of measure (r : report) =
    List.find_opt (fun (ms : measure_summary) -> ms.measure = measure) r.summaries
  in
  let header =
    (O.Heading, Printf.sprintf "Compare: %d window(s) of this kind" n)
    :: ( O.Chrome,
         "Window: "
         ^ String.concat "  " (List.map (fun ((p : period), _) -> p.label) reports) )
    :: [ (O.Plain, "") ]
  in
  let cell measure index (ms : measure_summary option) =
    match ms with
    | None -> "—"
    | Some summary ->
        let value =
          match index with
          | 0 -> summary.total_income
          | 1 -> summary.total_expense
          | 2 -> summary.scheduled_expense
          | 3 -> summary.ordinary_expense
          | _ -> summary.net_savings
        in
        O.format_money book measure value
  in
  let row measure label index =
    let cells = List.map (fun (_, r) -> cell measure index (summary_of measure r)) reports in
    ( O.Plain,
      "  " ^ O.pad ~width_of label_w label ^ " "
      ^ String.concat " " (List.map (O.pad_left ~width_of (col_w - 1)) cells) )
  in
  let block measure =
    if not (measure_active_in measure) then []
    else
      let top_loci =
        match List.rev reports with
        | (_, (newest : report)) :: _ -> (
            match summary_of measure newest with
            | None -> []
            | Some ms -> List.filteri (fun i _ -> i < 6) (by_amount_desc ms.expense_items))
        | [] -> []
      in
      let locus_row (it : line_item) =
        let cells =
          List.map
            (fun (_, (r : report)) ->
              match summary_of measure r with
              | None -> "—"
              | Some ms ->
                  let amount =
                    List.fold_left
                      (fun acc (candidate : line_item) ->
                        if candidate.locus = it.locus then candidate.amount else acc)
                      Z.zero ms.expense_items
                  in
                  if Z.equal amount Z.zero then "" else O.format_money book measure amount)
            reports
        in
        ( O.Plain,
          "    " ^ O.pad ~width_of (label_w - 4) it.label ^ " "
          ^ String.concat " " (List.map (O.pad_left ~width_of (col_w - 1)) cells) )
      in
      [
        (O.Heading, Printf.sprintf "  %s" measure);
        row measure "Income" 0;
        row measure "Expense" 1;
        row measure "  Scheduled" 2;
        row measure "  other" 3;
        row measure "Result" 4;
        (O.Chrome, "  top expense Loci");
      ]
      @ List.map locus_row top_loci
      @ [ (O.Plain, "") ]
  in
  header @ List.concat_map block measures

let print_summary ~book ~report =
  let lines = ref [] in
  let add s = lines := s :: !lines in
  add (Printf.sprintf "Income & Expense Report - %s" report.period.label);
  add
    (Printf.sprintf "Period: %s through %s (exclusive)" report.period.start_day
       report.period.end_exclusive);
  add "============================================================";
  let active, inactive = split_measures report.summaries in
  List.iter
    (fun (ms : measure_summary) ->
      let m = ms.measure in
      let fmt q = O.format_money book m q ^ " " ^ m in
      add "";
      add (Printf.sprintf "Currency: %s" m);
      add (Printf.sprintf "Income:  %s" (fmt ms.total_income));
      add (Printf.sprintf "Expense: %s" (fmt ms.total_expense));
      add (Printf.sprintf "  Scheduled: %s" (fmt ms.scheduled_expense));
      add (Printf.sprintf "  other:     %s" (fmt ms.ordinary_expense));
      add (Printf.sprintf "Result:  %s" (fmt ms.net_savings));
      if ms.expense_items <> [] then
        List.iter
          (fun (it : line_item) ->
            add (Printf.sprintf "  %-28s  %16s" it.label (fmt it.amount)))
          (by_amount_desc ms.expense_items);
      if ms.income_items <> [] then
        List.iter
          (fun (it : line_item) ->
            add (Printf.sprintf "  +%-27s  %16s" it.label (fmt it.amount)))
          (by_amount_desc ms.income_items))
    active;
  if active = [] then add "  (no role-classified activity in this window)";
  (match inactive with
  | [] -> ()
  | names ->
      add
        ("No activity in this window: "
        ^ String.concat ", " (List.map (fun (ms : measure_summary) -> ms.measure) names)));
  if report.unresolved_effects <> [] then begin
    add "";
    add "--- Unresolved Role Effects ---";
    List.iter
      (fun (date, locus, m, q) ->
        add (Printf.sprintf "  %s  %-20s  %s %s" date locus (O.format_money book m q) m))
      report.unresolved_effects
  end;
  List.rev !lines
