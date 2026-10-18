(* Daily Pace Trend: retrospective current-truth spending pace analysis over 10d, 30d, month, cycle. *)
module B = Bakhlo_sexp.Daily_book
module O = Daily_overlays
module Cal = Daily_calendar
module A = Daily_actions
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module F = Daily_file
module Panel = Ui_panel

type preset =
  | Ten_days
  | Thirty_days
  | Month
  | Cycle
  | Previous_cycle

type day_activity = {
  discretionary_outflow : Z.t;
  discretionary_inflow : Z.t;
  scheduled_settled_outflow : Z.t;
  scheduled_settled_inflow : Z.t;
  scheduled_reserved_outflow : Z.t;
}

type sample = {
  day : string;
  pace_quanta : Z.t option;
  available_through_end : Z.t;
  pool_balance : Z.t;
  deductions : Z.t;
  remaining_days : int;
  end_exclusive : string;
  activity : day_activity option;
  unavailable : string option;
}

type change_breakdown = {
  previous_pace : Z.t;
  current_pace : Z.t;
  change_per_day : Z.t;
  time_passage_effect : Z.t;
  free_money_effect : Z.t;
  pool_balance_change : Z.t;
  protection_release : Z.t;
  free_through_end_change : Z.t;
}

type graph_style = Line | Dots

type t = {
  preset : preset;
  selected_index : int;
  graph_style : graph_style;
  detail_focused : bool;
  detail_scroll : int;
}

let initial () =
  {
    preset = Ten_days;
    (* Ten_days always spans today-9..today, so today is index 9. *)
    selected_index = 9;
    graph_style = Line;
    detail_focused = false;
    detail_scroll = 0;
  }

let preset_label = function
  | Ten_days -> "10d"
  | Thirty_days -> "30d"
  | Month -> "Month"
  | Cycle -> "Cycle"
  | Previous_cycle -> "Previous Cycle"

let presets = [ Ten_days; Thirty_days; Month; Cycle; Previous_cycle ]

let next_graph_style = function Line -> Dots | Dots -> Line

let graph_style_label = function Line -> "line" | Dots -> "dots"

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

let resolve_range ~today ~preset ~boundary_presets_text =
  match preset with
  | Ten_days ->
      let start = match Cal.shift_days today (-9) with Ok d -> d | Error e -> failwith e in
      Ok (start, today, None)
  | Thirty_days ->
      let start = match Cal.shift_days today (-29) with Ok d -> d | Error e -> failwith e in
      Ok (start, today, None)
  | Month ->
      let start = String.sub today 0 8 ^ "01" in
      Ok (start, today, None)
  | Cycle -> (
      match boundary_presets_text with
      | None -> Error "Period not configured (boundary-presets.tsv missing)."
      | Some text -> (
          match parse_boundary_presets text with
          | Error e -> Error e
          | Ok windows -> (
              let matching = List.filter (fun (_, a, b) -> a <= today && today < b) windows in
              match matching with
              | [ (_, a, b) ] -> Ok (a, today, Some b)
              | [] -> Error "No explicit boundary preset contains today."
              | _ -> Error "Multiple boundary presets contain today; selection is ambiguous.")))
  | Previous_cycle -> (
      match boundary_presets_text with
      | None -> Error "Period not configured (boundary-presets.tsv missing)."
      | Some text -> (
          match parse_boundary_presets text with
          | Error e -> Error e
          | Ok windows -> (
              let current = List.filter (fun (_, a, b) -> a <= today && today < b) windows in
              match current with
              | [ (name, a, _) ] -> (
                  let prev_through = match Cal.shift_days a (-1) with Ok d -> d | Error e -> failwith e in
                  let prev = List.filter (fun (n, pa, pb) -> n = name && pa <= prev_through && prev_through < pb) windows in
                  match prev with
                  | [ (_, pa, pb) ] when pb = a -> Ok (pa, prev_through, Some pb)
                  | _ -> Error "Previous cycle boundary is not explicitly configured or not adjacent.")
              | [] -> Error "No explicit boundary preset contains today."
              | _ -> Error "Multiple boundary presets contain today; selection is ambiguous.")))

let day_number text =
  match Cal.parts text with
  | Error _ -> 0
  | Ok (y, m, d) ->
      let prev = y - 1 in
      let months = [| 0; 31; 59; 90; 120; 151; 181; 212; 243; 273; 304; 334 |] in
      let leap = y mod 400 = 0 || (y mod 4 = 0 && y mod 100 <> 0) in
      (365 * prev) + (prev / 4) - (prev / 100) + (prev / 400)
      + months.(m - 1) + d + (if leap && m > 2 then 1 else 0)

let dates_between start_day through_day =
  let start_num = day_number start_day in
  let end_num = day_number through_day in
  let count = max 0 (end_num - start_num + 1) in
  List.init count (fun i ->
      match Cal.shift_days start_day i with Ok d -> d | Error _ -> start_day)

(* Exact cause of a refused pool balance, with its coordinate when recoverable. *)
let format_pace_error why =
  let coordinate () =
    match String.split_on_char ':' why with
    | _ :: locus :: measure :: [] -> Some (locus ^ " " ^ measure)
    | _ -> None
  in
  let balance label =
    match coordinate () with Some c -> label ^ ": " ^ c | None -> label ^ "."
  in
  if String.starts_with ~prefix:"daily-pace-balance-amount-unknown:" why then
    balance "Pool locus balance is unknown"
  else if String.starts_with ~prefix:"daily-pace-balance-support-unknown:" why then
    balance "Pool locus balance support is unknown"
  else if String.equal why "daily-pace-non-positive-horizon" then
    "Period end must be after observation date."
  else if String.equal why "daily-pace-duplicate-coordinate" then
    "Duplicate coordinate in Daily Pace pool."
  else if String.equal why "daily-pace-pool-measure-mismatch" then
    "Daily Pace pool contains mixed Measures."
  else if String.equal why "unknown-measure" then "Unknown Measure in Daily Pace pool."
  else why

(* Sum exact pool balances; unknown or unsupported balances refuse instead of defaulting. *)
let query_pool_balance book measure coords =
  let rec sum acc = function
    | [] -> Ok acc
    | (c : D.Effect_coordinate.t) :: rest -> (
        match Q.query (B.image book) c with
        | Ok (Q.Exact answer) -> sum (Z.add acc (D.Quantity.quanta (Q.quantity answer))) rest
        | Ok (Q.Known_present _) ->
            Error
              (format_pace_error
                 ("daily-pace-balance-amount-unknown:" ^ A.lstr c.locus ^ ":" ^ A.mstr c.measure))
        | Error (Q.Support_unknown _) ->
            Error
              (format_pace_error
                 ("daily-pace-balance-support-unknown:" ^ A.lstr c.locus ^ ":" ^ A.mstr c.measure)))
  in
  sum Z.zero coords
let zero_activity =
  {
    discretionary_outflow = Z.zero;
    discretionary_inflow = Z.zero;
    scheduled_settled_outflow = Z.zero;
    scheduled_settled_inflow = Z.zero;
    scheduled_reserved_outflow = Z.zero;
  }

(* Exact day activity: fold entries per day with per-entry NET pool effect so
   intra-pool transfers cancel. B.plans paid_by links identify scheduled
   payments; reversals of scheduled payments are scheduled too. Same-day
   target/reversal pairs skip effects but keep reserved on the paying day. *)
let compute_activities book measure pool =
  let entries = B.entries book in
  let plans = B.plans book in
  let by_id = Hashtbl.create (max 8 (List.length entries)) in
  List.iter (fun (e : B.entry) -> Hashtbl.replace by_id e.id e) entries;
  let paid_ids = Hashtbl.create 8 in
  List.iter
    (fun (p : B.plan) -> match p.paid_by with None -> () | Some eid -> Hashtbl.replace paid_ids eid true)
    plans;
  let scheduled_ids = Hashtbl.create 8 in
  Hashtbl.iter (fun eid _ -> Hashtbl.replace scheduled_ids eid true) paid_ids;
  List.iter
    (fun (e : B.entry) ->
      match e.reversal_of with
      | Some t when Hashtbl.mem paid_ids t -> Hashtbl.replace scheduled_ids e.id true
      | _ -> ())
    entries;
  let skip = Hashtbl.create 8 in
  List.iter
    (fun (e : B.entry) ->
      match e.reversal_of with
      | Some t -> (
          match Hashtbl.find_opt by_id t with
          | Some target when target.day = e.day ->
              Hashtbl.replace skip e.id true;
              Hashtbl.replace skip t true
          | _ -> ())
      | None -> ())
    entries;
  let plan_net (p : B.plan) =
    List.fold_left
      (fun acc (loc, q) -> if List.mem loc pool then Z.add acc q else acc)
      Z.zero p.changes
  in
  let table : (string, day_activity) Hashtbl.t = Hashtbl.create (max 8 (List.length entries)) in
  let add day f =
    let prev = match Hashtbl.find_opt table day with None -> zero_activity | Some a -> a in
    Hashtbl.replace table day (f prev)
  in
  List.iter
    (fun (p : B.plan) ->
      match p.paid_by with
      | Some eid when p.measure = measure ->
          let reserved = Z.neg (Z.min Z.zero (plan_net p)) in
          if Z.sign reserved > 0 then (
            match Hashtbl.find_opt by_id eid with
            | None -> ()
            | Some pay ->
                add pay.day (fun a ->
                    { a with scheduled_reserved_outflow = Z.add a.scheduled_reserved_outflow reserved }))
      | None | Some _ -> ())
    plans;
  List.iter
    (fun (e : B.entry) ->
      if Hashtbl.mem skip e.id then ()
      else
        let delta =
          List.fold_left
            (fun acc eff ->
              if A.mstr (D.Effect.measure eff) = measure && List.mem (A.lstr (D.Effect.locus eff)) pool then
                Z.add acc (A.quanta eff)
              else acc)
            Z.zero e.effects
        in
        if Z.equal delta Z.zero then ()
        else if Hashtbl.mem scheduled_ids e.id then
          if Z.sign delta < 0 then
            add e.day (fun a ->
                { a with scheduled_settled_outflow = Z.add a.scheduled_settled_outflow (Z.neg delta) })
          else
            add e.day (fun a ->
                { a with scheduled_settled_inflow = Z.add a.scheduled_settled_inflow delta })
        else if Z.sign delta < 0 then
          add e.day (fun a ->
              { a with discretionary_outflow = Z.add a.discretionary_outflow (Z.neg delta) })
        else add e.day (fun a -> { a with discretionary_inflow = Z.add a.discretionary_inflow delta }))
    entries;
  table


let compute_samples ~book ~measure ~pool ~boundary_presets_text ~today ~preset =
  if pool = [] then Error "Daily Pace pool is empty."
  else
    match resolve_range ~today ~preset ~boundary_presets_text with
    | Error msg -> Error msg
    | Ok (start_day, through_day, cycle_end_opt) -> (
        let end_exclusive_res =
          match cycle_end_opt with
          | Some e -> Ok e
          | None -> (
              match boundary_presets_text with
              | None -> Error "Period not configured (boundary-presets.tsv missing)."
              | Some text -> (
                  match parse_boundary_presets text with
                  | Error e -> Error e
                  | Ok windows -> (
                      let matching =
                        List.filter (fun (_, a, b) -> a <= today && today < b) windows
                      in
                      match matching with
                      | [ (_, _, b) ] -> Ok b
                      | [] -> Error "No explicit boundary preset contains today."
                      | _ ->
                          Error
                            "Multiple boundary presets contain today; selection is ambiguous.")))
        in
        match end_exclusive_res with
        | Error why -> Error why
        | Ok end_exclusive -> (
            let coords =
              List.map
                (fun locus ->
                  {
                    D.Effect_coordinate.locus = A.get_id (D.Identifier.Locus.of_string locus);
                    measure = A.get_id (D.Identifier.Measure.of_string measure);
                  })
                pool
            in
            match query_pool_balance book measure coords with
            | Error why -> Error why
            | Ok current_pool_balance -> (
                (* Keep the current answer; past-day reconstruction stays unchanged. *)
                let horizon_pace =
                  if end_exclusive > today then
                    match
                      B.daily_pace book ~measure ~pool:coords ~observed_at:today ~end_exclusive
                    with
                    | Ok pace -> Ok (Some pace)
                    | Error why -> Error (format_pace_error why)
                  else Ok None
                in
                match horizon_pace with
                | Error why -> Error why
                | Ok today_pace ->
                    let plans = B.open_plans book in
                    let activities = compute_activities book measure pool in
                    (* shortcut: history requires zero-origin, extend when dated support is admitted. *)
                    let supported_history =
                      List.for_all (fun locus -> B.has_zero_origin book ~locus ~measure) pool
                    in
                    let activity_of day =
                      match Hashtbl.find_opt activities day with
                      | Some a -> Some a
                      | None -> Some zero_activity
                    in
                    let past_unsupported = "History unsupported: no zero-origin for every pool locus." in
                    let entries = B.entries book in
                    let days = dates_between start_day through_day in
                    let poor_sample day unsupported_past =
                      {
                        day;
                        pace_quanta = None;
                        available_through_end = Z.zero;
                        pool_balance = Z.zero;
                        deductions = Z.zero;
                        remaining_days = 0;
                        end_exclusive;
                        activity = activity_of day;
                        unavailable =
                          (if unsupported_past then Some past_unsupported
                           else Some "Past pace is not supported by current truth.");
                      }
                    in
                    let samples =
                      List.map
                        (fun day ->
                          let remaining_days =
                            let d_num = day_number day in
                            let e_num = day_number end_exclusive in
                            max 0 (e_num - d_num)
                          in
                          if remaining_days <= 0 then poor_sample day false
                          else
                            (match today_pace with
                            | Some pace when day = today ->
                                {
                                  day;
                                  pace_quanta = Some pace.B.daily_pace_quanta;
                                  available_through_end = pace.B.available_through_end;
                                  pool_balance = pace.B.eligible_pool;
                                  deductions = pace.B.automatic_deductions;
                                  remaining_days = pace.B.remaining_days;
                                  end_exclusive;
                                  activity = activity_of day;
                                  unavailable = None;
                                }
                            | _ ->
                                if day < today && not supported_history then poor_sample day true
                                else
                                  let post_effects =
                                    List.filter
                                      (fun (e : B.entry) -> e.day > day && e.day <= today)
                                      entries
                                    |> List.concat_map (fun (e : B.entry) -> e.effects)
                                    |> List.filter (fun eff ->
                                           A.mstr (D.Effect.measure eff) = measure
                                           && List.mem (A.lstr (D.Effect.locus eff)) pool)
                                  in
                                  let post_sum =
                                    List.fold_left
                                      (fun acc eff -> Z.add acc (A.quanta eff))
                                      Z.zero post_effects
                                  in
                                  let pool_balance = Z.sub current_pool_balance post_sum in
                                  let active_plans =
                                    List.filter
                                      (fun (p : B.plan) ->
                                        p.measure = measure && p.day >= day
                                        && p.day < end_exclusive && p.cancelled_on = None
                                        && p.paid_by = None)
                                      plans
                                  in
                                  let deductions =
                                    List.fold_left
                                      (fun total (p : B.plan) ->
                                        let plan_net =
                                          List.fold_left
                                            (fun acc (loc, q) ->
                                              if List.mem loc pool then Z.add acc q else acc)
                                            Z.zero p.changes
                                        in
                                        if Z.sign plan_net < 0 then Z.add total (Z.neg plan_net)
                                        else total)
                                      Z.zero active_plans
                                  in
                                  let available_through_end = Z.sub pool_balance deductions in
                                  {
                                    day;
                                    pace_quanta =
                                      Some (Z.ediv available_through_end (Z.of_int remaining_days));
                                    available_through_end;
                                    pool_balance;
                                    deductions;
                                    remaining_days;
                                    end_exclusive;
                                    activity = activity_of day;
                                    unavailable = None;
                                  }))
                        days
                    in
                    Ok (start_day, through_day, samples))))

(* Cursor within the actually rendered range: clamp the stored index to the
   real last row before stepping. Range failure stays an explicit error. *)
let move_selection ~today ~preset ~boundary_presets_text ~position delta =
  match resolve_range ~today ~preset ~boundary_presets_text with
  | Error msg -> Error msg
  | Ok (start_day, through_day, _) ->
      let last = max 0 (day_number through_day - day_number start_day) in
      Ok (Panel.move ~last ~position delta)

(* Braille 2x4 subcell plot with integer-only nice ticks.
   Amounts use the book's Measure scale with 3-digit grouping, never raw
   quanta; a value that cannot fit is omitted whole, never cut mid-number. *)
(* Guarded adjacent-day decomposition: exact Z ediv time/free split; refuses
   across cycles, holes, shortened horizons and inconsistent evidence. *)
let compare_change ~prev ~current =
  if prev.pace_quanta = None || current.pace_quanta = None then
    Error "Daily Pace change requires two supported days."
  else
  if prev.end_exclusive <> current.end_exclusive then
    Error "Daily Pace change crosses a cycle boundary."
  else
    match Cal.shift_days prev.day 1 with
    | Ok next when next = current.day ->
        if prev.remaining_days <> current.remaining_days + 1 || current.remaining_days <= 0 then
          Error "Daily Pace change requires a one-day shorter positive horizon."
        else if Z.sign prev.deductions < 0 || Z.sign current.deductions < 0 then
          Error "Daily Pace change requires nonnegative protected Scheduled outflows."
        else if
          (not (Z.equal (Z.sub prev.pool_balance prev.deductions) prev.available_through_end))
          || not (Z.equal (Z.sub current.pool_balance current.deductions) current.available_through_end)
        then Error "Daily Pace change has inconsistent available-through-end evidence."
        else
          (match prev.pace_quanta, current.pace_quanta with
          | Some previous_pace, Some current_pace ->
              let old_free_on_new_horizon =
                Z.ediv prev.available_through_end (Z.of_int current.remaining_days)
              in
              let time_passage_effect = Z.sub old_free_on_new_horizon previous_pace in
              let free_money_effect = Z.sub current_pace old_free_on_new_horizon in
              let pool_balance_change = Z.sub current.pool_balance prev.pool_balance in
              let protection_release = Z.sub prev.deductions current.deductions in
              Ok
                {
                  previous_pace;
                  current_pace;
                  change_per_day = Z.sub current_pace previous_pace;
                  time_passage_effect;
                  free_money_effect;
                  pool_balance_change;
                  protection_release;
                  free_through_end_change = Z.add pool_balance_change protection_release;
                }
          | None, _ -> Error "Daily Pace change previous day unavailable."
          | _, None -> Error "Daily Pace change current day unavailable.")
    | _ -> Error "Daily Pace change requires consecutive calendar days."

(* Shared display helpers: grouped Measure amounts, never raw quanta; a value
   that cannot fit is omitted whole, never cut mid-number. *)
let money_of book measure q = O.format_money book measure q ^ " " ^ measure ^ "/day"

let signed_money book measure q =
  (if Z.sign q > 0 then "+" else "") ^ O.format_money book measure q

let fit_value ~width_of v full fallback =
  if width_of full <= v then full
  else if v >= width_of "…" && width_of fallback <= v then fallback
  else "…"

let count_supported samples =
  List.fold_left
    (fun acc s -> match s.pace_quanta with None -> acc | Some _ -> acc + 1)
    0 samples

let ceil_div a b = if Z.sign a >= 0 then Z.div (Z.add a (Z.sub b Z.one)) b else Z.div a b

let nice_ceiling raw =
  (* raw is positive; 1/2/5×10^n cover, all in Z so 400-digit spans stay bounded. *)
  assert (Z.sign raw > 0);
  let digits = String.length (Z.to_string raw) - 1 in
  let unit = Z.pow (Z.of_int 10) digits in
  if Z.compare raw unit <= 0 then unit
  else if Z.compare raw (Z.mul unit (Z.of_int 2)) <= 0 then Z.mul unit (Z.of_int 2)
  else if Z.compare raw (Z.mul unit (Z.of_int 5)) <= 0 then Z.mul unit (Z.of_int 5)
  else Z.mul unit (Z.of_int 10)

let short_day day = if String.length day >= 10 then String.sub day 5 5 else day

let braille_mask =
  [| (0, 0, 0x01); (0, 1, 0x02); (0, 2, 0x04); (1, 0, 0x08); (1, 1, 0x10); (1, 2, 0x20); (0, 3, 0x40); (1, 3, 0x80) |]

(* Selected date/pace summary: exact grouped amount or detail cue, never a
   truncated number. *)
let summary_text ~width ~width_of ~book ~today ~measure sel =
  let money q = money_of book measure q in
  let mark = if sel.day = today then " (today)" else "" in
  let full_summary =
    match sel.pace_quanta with
    | Some q -> sel.day ^ mark ^ " ◆ " ^ money q
    | None -> sel.day ^ mark ^ " unavailable"
  in
  if width_of full_summary <= width then full_summary
  else
    let compact =
      match sel.pace_quanta with
      | Some q -> sel.day ^ mark ^ " ◆ " ^ O.format_money book measure q
      | None -> sel.day ^ mark ^ " unavailable"
    in
    let bare =
      match sel.pace_quanta with
      | Some q -> sel.day ^ " ◆ " ^ money q
      | None -> sel.day ^ " unavailable"
    in
    let cue = sel.day ^ " ◆ … (i detail)" in
    if width_of bare <= width then bare
    else if width_of compact <= width then compact
    else if width_of cue <= width then cue
    else O.clip_text ~width_of width (sel.day ^ " ◆ …")

(* Shared history rows over the existing samples: full Day | Quanta/day |
   Spent | Pace diff only at width>=46 with activity; otherwise selection +
   exact pace or a detail cue, never a truncated number. *)
let render_history ~width ~height ~width_of ~book ~measure ~samples ~selected_index =
  if width < 8 || height < 1 || samples = [] then []
  else
    let count = List.length samples in
    let arr = Array.of_list samples in
    let selected = Panel.move ~last:(count - 1) ~position:selected_index 0 in
    let wide = width >= 46 && Array.exists (fun s -> s.activity <> None) arr in
    let heading = wide && height >= 2 in
    let cap = min count (height - if heading then 1 else 0) in
    let start = max 0 (min (count - cap) (selected - cap / 2)) in
    let budget = width - 15 in
    let spent_width = max 8 (budget * 28 / 100) in
    let diff_width = max 9 (budget * 28 / 100) in
    let pace_width = budget - spent_width - diff_width in
    let cell width text = O.pad_left ~width_of width (fit_value ~width_of width text "see details") in
    let table_row marker day pace spent diff =
      marker ^ O.pad ~width_of 10 day ^ " " ^ cell pace_width pace ^ " "
      ^ cell spent_width spent ^ " " ^ cell diff_width diff
    in
    let rows =
      List.init cap (fun offset ->
        let i = start + offset in
        let sample = arr.(i) in
        let marker = if i = selected then "◆ " else "  " in
        let pace = match sample.pace_quanta with
          | None -> "unknown"
          | Some q -> money_of book measure q
        in
        let text =
          if wide then
            let spent, diff = match sample.activity with
              | None -> "—", "—"
              | Some activity ->
                  O.format_money book measure activity.discretionary_outflow,
                  (match sample.pace_quanta with
                   | None -> "—"
                   | Some q -> signed_money book measure (Z.sub q activity.discretionary_outflow))
            in
            table_row marker sample.day pace spent diff
          else
            let prefix = marker ^ sample.day ^ "  " in
            prefix ^ fit_value ~width_of (width - width_of prefix) pace "…"
        in
        (if i = selected then O.Active else O.Plain), O.pad ~width_of width text)
    in
    if heading then (O.Chrome, table_row "  " "Day" "Quanta/day" "Spent" "Pace diff") :: rows
    else rows

(* Summary plus braille plot and date axis; history rows live in
   render_history. Tiny heights keep the selected date/pace summary, with
   the support count when it fits. *)
let render_chart ~width ~height ~width_of ~book ~today ~measure ~samples ~selected_index ~graph_style =
  if width < 8 || height < 1 || samples = [] then []
  else
    let count = List.length samples in
    let arr = Array.of_list samples in
    let selected = Panel.move ~last:(count - 1) ~position:selected_index 0 in
    let sel = arr.(selected) in
    let summary_row =
      (O.Active, O.pad ~width_of width (summary_text ~width ~width_of ~book ~today ~measure sel))
    in
    let supported = count_supported samples in
    let head =
      if supported < count then
        [
          summary_row;
          ( O.Chrome,
            O.pad ~width_of width
              (Printf.sprintf "%d/%d supported days; unknown days stay gaps" supported count) );
        ]
      else [ summary_row ]
    in
    let header_h = List.length head in
    if height <= header_h then List.filteri (fun i _ -> i < height) head
    else if height - header_h - 1 < 1 then head
    else
      let plot_h =
        max 1 (min 12 (height - header_h - 1))
      in
      let valid =
        Array.fold_left (fun acc s -> match s.pace_quanta with None -> acc | Some q -> q :: acc) [] arr
      in
      match valid with
      | [] -> head @ [ (O.Chrome, O.pad ~width_of width "No valid pace data in this period.") ]
      | _ ->
          let min_q = List.fold_left Z.min (List.hd valid) valid in
          let max_q = List.fold_left Z.max (List.hd valid) valid in
          let span = Z.sub max_q min_q in
          let step = if Z.equal span Z.zero then Z.one else
            nice_ceiling (ceil_div span (Z.of_int (max 1 (min 4 (plot_h - 1))))) in
          let lower, upper =
            if Z.equal span Z.zero then Z.pred min_q, Z.succ max_q
            else Z.mul (Z.ediv min_q step) step, Z.mul (ceil_div max_q step) step in
          let range = Z.sub upper lower in
          let rec ticks_from t acc =
            if Z.compare t upper > 0 then List.rev acc
            else ticks_from (Z.add t step) (t :: acc) in
          let ticks = ticks_from lower [] in
          let tick_row t =
            Z.to_int (Z.ediv (Z.mul (Z.sub upper t) (Z.of_int (plot_h - 1))) range) in
          let tick_at =
            List.fold_left
              (fun acc t ->
                let r = tick_row t in
                if List.mem_assoc r acc then acc else (r, t) :: acc)
              [] ticks
          in
          let natural_axis = List.fold_left (fun w t -> max w (width_of (O.format_money book measure t))) 0 ticks in
          let axis_w = min natural_axis (max 1 (min 12 (width / 3))) in
          let plot_w = max 1 (width - axis_w - 3) in
          let sub_w = 2 * plot_w and sub_h = 4 * plot_h in
          let dots = Array.make (sub_w * sub_h) false in
          let set_dot sx sy =
            if sx >= 0 && sy >= 0 && sx < sub_w && sy < sub_h then dots.(sy * sub_w + sx) <- true
          in
          let col_of i = if count <= 1 then 0 else i * (sub_w - 1) / (count - 1) in
          let sub_row_of q =
            Z.to_int (Z.ediv (Z.mul (Z.sub upper q) (Z.of_int (sub_h - 1))) range) in
          let points = Array.mapi (fun i s ->
            Option.map (fun q -> col_of i, sub_row_of q) s.pace_quanta) arr in
          Array.iter (Option.iter (fun (x, y) -> set_dot x y)) points;
          (* Joins are display-only interpolation: adjacent valid days sharing
             one end_exclusive only, never across holes or cycle resets. *)
          let joinable i =
            i + 1 < count && arr.(i).pace_quanta <> None && arr.(i + 1).pace_quanta <> None
            && arr.(i).end_exclusive = arr.(i + 1).end_exclusive
            && day_number arr.(i + 1).day = day_number arr.(i).day + 1
          in
          (match graph_style with
          | Dots -> ()
          | Line ->
              for i = 0 to count - 2 do
                if joinable i then
                  match points.(i), points.(i + 1) with
                  | Some (x0, y0), Some (x1, y1) ->
                      let steps = max (abs (x1 - x0)) (abs (y1 - y0)) in
                      if steps > 1 then
                        for s = 1 to steps - 1 do
                          set_dot (x0 + (x1 - x0) * s / steps) (y0 + (y1 - y0) * s / steps)
                        done
                  | None, _ | _, None -> ()
              done);
          let plot_text = Array.init plot_h (fun _ -> Array.make plot_w " ") in
          for y = 0 to plot_h - 1 do
            let grid = List.mem_assoc y tick_at in
            for x = 0 to plot_w - 1 do
              let mask = ref 0 in
              Array.iter
                (fun (dx, dy, bit) ->
                  if dots.((4 * y + dy) * sub_w + (2 * x + dx)) then mask := !mask lor bit)
                braille_mask;
              plot_text.(y).(x) <-
                (if !mask = 0 then (if grid then "·" else " ") else O.utf8 (Uchar.of_int (0x2800 + !mask)))
            done
          done;
          (* Each sample is drawn once; the selected cell always wins. *)
          let draw_marker i glyph =
            match points.(i) with
            | None -> ()
            | Some (x, y) -> plot_text.(y / 4).(x / 2) <- glyph
          in
          for i = 0 to count - 1 do
            if i <> selected then draw_marker i "●"
          done;
          draw_marker selected "◆";
          let plot_rows =
            List.init plot_h (fun y ->
                let label =
                  match List.assoc_opt y tick_at with
                  | None -> ""
                  | Some t ->
                      let full = O.format_money book measure t in
                      if width_of full <= axis_w then full else if axis_w >= width_of "…" then "…" else ""
                in
                let row_text = String.concat "" (Array.to_list plot_text.(y)) in
                (O.Plain, O.pad_left ~width_of axis_w label ^ " │ " ^ row_text))
          in
          let start_day = short_day arr.(0).day and end_day = short_day arr.(count - 1).day in
          let rule_line =
            let prefix = String.make axis_w ' ' ^ " ╰─" ^ start_day in
            let room = width - width_of prefix - width_of end_day in
            if room >= 0 then prefix ^ O.rule ~width_of room ^ end_day
            else
              let compact = start_day ^ "–" ^ end_day in
              if width_of compact <= width then O.pad ~width_of width compact
              else O.pad ~width_of width start_day
          in
          head @ plot_rows @ [ (O.Chrome, O.pad ~width_of width rule_line) ]

let render_detail ~width:_ ~width_of:_ ~book ~measure ~sample ~prev_sample ~today ~preset =
  match sample with
  | None -> [ (O.Chrome, "No sample selected.") ]
  | Some s ->
      let header =
        [
          (O.Heading, "Daily Pace Detail");
          (O.Plain, "Selected date: " ^ s.day ^ (if s.day = today then " (Today)" else ""));
          (O.Plain, "Period: " ^ preset_label preset);
          (O.Chrome, "");
        ]
      in
      let pace_line =
        match s.pace_quanta with
        | Some q ->
            let change =
              match prev_sample with
              | None -> ""
              | Some ps -> (
                  match compare_change ~prev:ps ~current:s with
                  | Ok b -> " (change: " ^ signed_money book measure b.change_per_day ^ " " ^ measure ^ "/day)"
                  | Error _ -> "")
            in
            [ (O.Active, "Daily Pace: " ^ money_of book measure q ^ change) ]
        | None -> (
            match s.unavailable with
            | Some why -> [ (O.Status, "Daily Pace: unavailable (" ^ why ^ ")") ]
            | None -> [ (O.Status, "Daily Pace: unavailable") ])
      in
      let activity_lines =
        match s.activity with
        | None -> []
        | Some a ->
            let spent = "Spent: " ^ O.format_money book measure a.discretionary_outflow ^ " " ^ measure in
            let spent =
              match s.pace_quanta with
              | None -> spent
              | Some q ->
                  spent ^ " (diff: " ^ signed_money book measure (Z.sub q a.discretionary_outflow) ^ " " ^ measure
                  ^ ")"
            in
            let inflow =
              if Z.sign a.discretionary_inflow > 0 then
                [ (O.Plain, "Unscheduled inflow: +" ^ O.format_money book measure a.discretionary_inflow ^ " " ^ measure)
                ]
              else []
            in
            let settled =
              if Z.sign a.scheduled_settled_outflow > 0 || Z.sign a.scheduled_reserved_outflow > 0 then
                let variance = Z.sub a.scheduled_reserved_outflow a.scheduled_settled_outflow in
                let variance_text =
                  if Z.equal variance Z.zero then " (as planned)"
                  else " (" ^ signed_money book measure variance ^ " vs plan)"
                in
                [
                  ( O.Plain,
                    "Settled: " ^ O.format_money book measure a.scheduled_settled_outflow ^ " " ^ measure
                    ^ variance_text );
                ]
              else []
            in
            (* Scheduled payments and their reversals are distinct from
               discretionary income. A positive linked reversal restores
               pool funds, but it is not a new unscheduled receipt. *)
            let scheduled_inflow =
              if Z.sign a.scheduled_settled_inflow > 0 then
                [
                  ( O.Plain,
                    "Scheduled-linked inflow/reversal: +"
                    ^ O.format_money book measure a.scheduled_settled_inflow ^ " " ^ measure );
                ]
              else []
            in
            (O.Plain, spent) :: (inflow @ settled @ scheduled_inflow)
      in
      let change_lines =
        match prev_sample with
        | None -> []
        | Some ps -> (
            match compare_change ~prev:ps ~current:s with
            | Ok b ->
                [
                  (O.Plain, "Time passage: " ^ signed_money book measure b.time_passage_effect ^ " " ^ measure ^ "/day");
                  (O.Plain, "Free money effect: " ^ signed_money book measure b.free_money_effect ^ " " ^ measure ^ "/day");
                  (O.Plain, "Pool balance delta: " ^ signed_money book measure b.pool_balance_change ^ " " ^ measure);
                  (O.Plain, "Scheduled protection release: " ^ signed_money book measure b.protection_release ^ " " ^ measure);
                  (O.Plain, "Free-through-end delta: " ^ signed_money book measure b.free_through_end_change ^ " " ^ measure);
                ]
            | Error why -> [ (O.Plain, "Day-to-day breakdown unavailable (" ^ why ^ ")") ])
      in
      let breakdown =
        (match s.pace_quanta with
        | Some _ ->
            [
              (O.Chrome, "");
              (O.Plain, "Through end: " ^ O.format_money book measure s.available_through_end ^ " " ^ measure ^ " (Available)");
              (O.Plain, Printf.sprintf "Period progress: %d days remaining to cycle end" s.remaining_days);
              (O.Plain, "Pool accounts balance: " ^ O.format_money book measure s.pool_balance ^ " " ^ measure);
              (O.Plain, "Protected scheduled:   -" ^ O.format_money book measure s.deductions ^ " " ^ measure);
              (O.Plain, "Days remaining:        " ^ string_of_int s.remaining_days ^ " days");
              (O.Plain, "Cycle end (exclusive): " ^ s.end_exclusive);
              (O.Plain, "Source: Pool [config/daily-pace.tsv] | Window [config/boundary-presets.tsv]");
              (O.Chrome, "");
              (O.Chrome, "Reconstructed current truth; no separate daily snapshot is kept.");
            ]
        | None ->
            [
              (O.Chrome, "");
              (O.Plain, "Cycle end (exclusive): " ^ s.end_exclusive);
              (O.Plain, "Source: Pool [config/daily-pace.tsv] | Window [config/boundary-presets.tsv]");
              (O.Chrome, "");
              (O.Chrome, "Reconstructed current truth; no separate daily snapshot is kept.");
            ])
      in
      header @ pace_line @ activity_lines @ change_lines @ breakdown
