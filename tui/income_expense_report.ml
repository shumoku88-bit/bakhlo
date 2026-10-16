(* Income & Expense Report: period-based P/L analysis by month, cycle, year, or all-time. *)
module B = Bakhlo_sexp.Daily_book
module Roles = Locus_roles
module O = Daily_overlays
module Cal = Daily_calendar
module A = Daily_actions
module D = Bakhlo_domain

type period_preset =
  | Month
  | Cycle
  | Previous_cycle
  | Year
  | All_time

type period = {
  preset : period_preset;
  start_day : string;
  end_exclusive : string;
  label : string;
}

type line_item = {
  locus : string;
  label : string;
  amount : Z.t;
}

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
  {
    preset = Month;
    period_offset = 0;
    selected_row = 0;
    detail_focused = false;
    detail_scroll = 0;
  }

let preset_label = function
  | Month -> "Month"
  | Cycle -> "Cycle"
  | Previous_cycle -> "Previous Cycle"
  | Year -> "Year"
  | All_time -> "All Time"

let presets = [ Month; Cycle; Previous_cycle; Year; All_time ]

let config_lines text =
  String.split_on_char '\n' text
  |> List.filter_map (fun line ->
         let s = String.trim line in
         if s = "" || String.starts_with ~prefix:"#" s then None else Some s)

let config_token s =
  s <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) s

let canonical_date day =
  match A.normalize_date day with Ok c -> c = day | Error _ -> false

let rec increasing = function
  | a :: b :: rest -> a < b && increasing (b :: rest)
  | [] | [ _ ] -> true

let parse_boundary_presets text =
  let lines = config_lines text in
  let rec loop names acc = function
    | [] -> Ok acc
    | line :: rest ->
        match String.split_on_char '\t' line with
        | name :: dates
          when config_token name && not (List.mem name names)
               && List.length dates >= 2
               && List.for_all canonical_date dates
               && increasing dates ->
            let rec windows = function
              | a :: b :: tail -> (name, a, b) :: windows (b :: tail)
              | _ -> []
            in
            loop (name :: names) (acc @ windows dates) rest
        | _ -> Error "Malformed boundary-presets.tsv; no period was inferred."
  in
  loop [] [] lines

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
                    match List.find_index (fun (_, a, b) -> a = cur_a && b = cur_b) name_windows with
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
                    let cycle_name = if preset = Previous_cycle then "Previous Cycle" else "Cycle" in
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
  let in_period (e : B.entry) =
    e.day >= period.start_day && e.day < period.end_exclusive
  in
  let period_entries = List.filter in_period entries in
  let measures =
    List.map fst (B.measures book)
    |> List.sort_uniq String.compare
  in
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
                      if is_sched then
                        scheduled_expense_acc := Z.add !scheduled_expense_acc exp
                      else
                        ordinary_expense_acc := Z.add !ordinary_expense_acc exp
                  | Some (Asset | Liability | Equity) ->
                      (* Balance sheet accounts; excluded from P/L *)
                      ()
                  | None ->
                      unresolved_acc := (e.day, locus, measure, quanta) :: !unresolved_acc)
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
  {
    period;
    summaries;
    unresolved_effects = List.rev !unresolved_acc;
  }

let render_report_lines ~width ~width_of ~book ~report =
  let pad_w = max 0 (width - 4) in
  let header =
    [
      (O.Heading, Printf.sprintf "Income & Expense  [%s]" report.period.label);
      (O.Chrome, Printf.sprintf "Window: %s .. %s (exclusive)" report.period.start_day report.period.end_exclusive);
      (O.Plain, "");
    ]
  in
  let render_measure (ms : measure_summary) =
    let m = ms.measure in
    let fmt q = B.format book m q ^ " " ^ m in
    let col_locus = max 20 (min 36 (pad_w / 2)) in
    let col_amt = max 14 (min 20 (pad_w - col_locus - 6)) in

    let format_item (it : line_item) =
      (O.Plain, "  " ^ O.pad ~width_of col_locus it.label ^ "  " ^ O.pad_left ~width_of col_amt (fmt it.amount))
    in

    let inc_lines =
      if ms.income_items = [] then [ (O.Chrome, "  (no income recorded)") ]
      else List.map format_item ms.income_items
    in
    let exp_lines =
      if ms.expense_items = [] then [ (O.Chrome, "  (no expenses recorded)") ]
      else List.map format_item ms.expense_items
    in
    let savings_style = if Z.sign ms.net_savings >= 0 then O.Active else O.Status in
    let savings_sign = if Z.sign ms.net_savings > 0 then "+" else "" in

    [
      (O.Heading, Printf.sprintf "Currency: %s" m);
      (O.Chrome, "── Income ──────────────────────────────────────────────────────────");
    ]
    @ inc_lines
    @ [
        (O.Active, "Total Income: " ^ O.pad_left ~width_of (pad_w - 14) (fmt ms.total_income));
        (O.Chrome, "── Expense ─────────────────────────────────────────────────────────");
      ]
    @ exp_lines
    @ [
        (O.Active, "Total Expense: " ^ O.pad_left ~width_of (pad_w - 15) (fmt ms.total_expense));
        (O.Plain, Printf.sprintf "  Scheduled bills:    %s" (fmt ms.scheduled_expense));
        (O.Plain, Printf.sprintf "  Ordinary spending:  %s" (fmt ms.ordinary_expense));
        (O.Chrome, "── Net Savings ─────────────────────────────────────────────────────");
        (savings_style, Printf.sprintf "Net Savings: %s%s" savings_sign (fmt ms.net_savings));
        (O.Plain, "");
      ]
  in
  let summaries_lines = List.concat_map render_measure report.summaries in
  let unresolved_lines =
    if report.unresolved_effects = [] then []
    else
      [
        (O.Status, "── Unresolved Role Effects ─────────────────────────────────────────");
        (O.Chrome, "Activity exists on accounts without explicit accounting role in accounting-roles.tsv:");
      ]
      @ List.map
          (fun (date, locus, m, q) ->
            (O.Plain, Printf.sprintf "  %s  %-20s  %s %s" date locus (B.format book m q) m))
          report.unresolved_effects
  in
  header @ summaries_lines @ unresolved_lines

let render_detail_lines ~width ~width_of ~book ~report ~selected_row =
  [
    (O.Heading, "Report Overview");
    (O.Plain, "Period: " ^ report.period.label);
    (O.Plain, Printf.sprintf "Date range: %s .. %s" report.period.start_day report.period.end_exclusive);
    (O.Chrome, "");
    (O.Heading, "Accounting Formula");
    (O.Plain, "  Income  = Sum of negative postings on Income accounts");
    (O.Plain, "  Expense = Sum of positive postings on Expense accounts");
    (O.Plain, "  Savings = Income - Expense");
    (O.Chrome, "");
    (O.Heading, "Provenance Distinction");
    (O.Plain, "  Scheduled bills: paid via Scheduled plan completion");
    (O.Plain, "  Ordinary: direct ad-hoc transactions");
    (O.Chrome, "");
    (O.Heading, "Keys & Navigation");
    (O.Plain, "  1: Month");
    (O.Plain, "  2: Cycle (boundary-presets.tsv)");
    (O.Plain, "  3: Previous Cycle");
    (O.Plain, "  4: Year");
    (O.Plain, "  5: All Time");
    (O.Plain, "  [ / ]: Shift period back / forward");
    (O.Plain, "  p: Print preview");
    (O.Plain, "  Tab: Switch report / details");
    (O.Plain, "  Esc / q: Return to Home");
  ]

let print_summary ~book ~report =
  let lines = ref [] in
  let add s = lines := s :: !lines in
  add (Printf.sprintf "Income & Expense Report - %s" report.period.label);
  add (Printf.sprintf "Period: %s through %s (exclusive)" report.period.start_day report.period.end_exclusive);
  add "============================================================";
  List.iter
    (fun (ms : measure_summary) ->
      let m = ms.measure in
      let fmt q = B.format book m q ^ " " ^ m in
      add (Printf.sprintf "\nCurrency: %s" m);
      add "--- Income ---";
      if ms.income_items = [] then add "  (no income)"
      else List.iter (fun it -> add (Printf.sprintf "  %-28s  %16s" it.label (fmt it.amount))) ms.income_items;
      add (Printf.sprintf "Total Income:  %s" (fmt ms.total_income));
      add "--- Expense ---";
      if ms.expense_items = [] then add "  (no expense)"
      else List.iter (fun it -> add (Printf.sprintf "  %-28s  %16s" it.label (fmt it.amount))) ms.expense_items;
      add (Printf.sprintf "Total Expense: %s" (fmt ms.total_expense));
      add (Printf.sprintf "  Scheduled:   %s" (fmt ms.scheduled_expense));
      add (Printf.sprintf "  Ordinary:    %s" (fmt ms.ordinary_expense));
      add (Printf.sprintf "Net Savings:   %s" (fmt ms.net_savings)))
    report.summaries;
  if report.unresolved_effects <> [] then begin
    add "\n--- Unresolved Role Effects ---";
    List.iter
      (fun (date, locus, m, q) ->
        add (Printf.sprintf "  %s  %-20s  %s %s" date locus (B.format book m q) m))
      report.unresolved_effects
  end;
  List.rev !lines
