(* Daily Pace Trend: retrospective current-truth spending pace analysis over 10d, 30d, month, cycle. *)
module B = Bakhlo_household.Daily_book
module O = Daily_overlays
module Cal = Daily_calendar
module A = Daily_draft
module D = Bakhlo_domain
module Panel = Ui_panel

type preset = Ten_days | Thirty_days | Month | Cycle | Previous_cycle

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

(* Every window of boundary-presets.tsv as (name, start, end-exclusive). *)
let parse_boundary_presets text =
  match Boundary_presets.parse text with
  | Ok presets -> Ok (Boundary_presets.windows presets)
  | Error () -> Error "Malformed boundary-presets.tsv; no period was inferred."

(* Every window and the one window containing [today]. *)
let current_window ~today = function
  | None -> Error "Period not configured (boundary-presets.tsv missing)."
  | Some text ->
      Result.bind (parse_boundary_presets text) (fun windows ->
          match List.filter (fun (_, a, b) -> a <= today && today < b) windows with
          | [ current ] -> Ok (windows, current)
          | [] -> Error "No explicit boundary preset contains today."
          | _ -> Error "Multiple boundary presets contain today; selection is ambiguous.")

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
  | Cycle ->
      Result.map
        (fun (_, (_, a, b)) -> (a, today, Some b))
        (current_window ~today boundary_presets_text)
  | Previous_cycle ->
      Result.bind (current_window ~today boundary_presets_text) (fun (windows, (name, a, _)) ->
          let prev_through = match Cal.shift_days a (-1) with Ok d -> d | Error e -> failwith e in
          let prev =
            List.filter
              (fun (n, pa, pb) -> n = name && pa <= prev_through && prev_through < pb)
              windows
          in
          match prev with
          | [ (_, pa, pb) ] when pb = a -> Ok (pa, prev_through, Some pb)
          | _ -> Error "Previous cycle boundary is not explicitly configured or not adjacent.")

let day_number text =
  match Cal.parts text with
  | Error _ -> 0
  | Ok (y, m, d) ->
      let prev = y - 1 in
      let months = [| 0; 31; 59; 90; 120; 151; 181; 212; 243; 273; 304; 334 |] in
      let leap = y mod 400 = 0 || (y mod 4 = 0 && y mod 100 <> 0) in
      (365 * prev) + (prev / 4) - (prev / 100) + (prev / 400)
      + months.(m - 1)
      + d
      + if leap && m > 2 then 1 else 0

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
    | [ _; locus; measure ] -> Some (locus ^ " " ^ measure)
    | _ -> None
  in
  let balance label = match coordinate () with Some c -> label ^ ": " ^ c | None -> label ^ "." in
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
let query_pool_balance book coords =
  let rec sum acc = function
    | [] -> Ok acc
    | (c : D.Effect_coordinate.t) :: rest -> (
        match B.quantity book ~locus:(A.lstr c.locus) ~measure:(A.mstr c.measure) with
        | Some q -> sum (Z.add acc q.amount) rest
        | None ->
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
    (fun (p : B.plan) ->
      match p.paid_by with None -> () | Some eid -> Hashtbl.replace paid_ids eid true)
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
      | Some eid when p.measure = measure -> (
          let reserved = Z.neg (Z.min Z.zero (plan_net p)) in
          if Z.sign reserved > 0 then
            match Hashtbl.find_opt by_id eid with
            | None -> ()
            | Some pay ->
                add pay.day (fun a ->
                    {
                      a with
                      scheduled_reserved_outflow = Z.add a.scheduled_reserved_outflow reserved;
                    }))
      | None | Some _ -> ())
    plans;
  List.iter
    (fun (e : B.entry) ->
      if Hashtbl.mem skip e.id then ()
      else
        let delta =
          List.fold_left
            (fun acc eff ->
              if
                A.mstr (D.Effect.measure eff) = measure
                && List.mem (A.lstr (D.Effect.locus eff)) pool
              then Z.add acc (A.quanta eff)
              else acc)
            Z.zero e.effects
        in
        if Z.equal delta Z.zero then ()
        else if Hashtbl.mem scheduled_ids e.id then
          if Z.sign delta < 0 then
            add e.day (fun a ->
                {
                  a with
                  scheduled_settled_outflow = Z.add a.scheduled_settled_outflow (Z.neg delta);
                })
          else
            add e.day (fun a ->
                { a with scheduled_settled_inflow = Z.add a.scheduled_settled_inflow delta })
        else if Z.sign delta < 0 then
          add e.day (fun a ->
              { a with discretionary_outflow = Z.add a.discretionary_outflow (Z.neg delta) })
        else
          add e.day (fun a -> { a with discretionary_inflow = Z.add a.discretionary_inflow delta }))
    entries;
  table

(* Core refusal codes carry "code:locus:measure"; name the coordinate, never guess. *)
let history_reason code =
  let kind, coordinate =
    match String.index_opt code ':' with
    | Some i -> (String.sub code 0 i, String.sub code (i + 1) (String.length code - i - 1))
    | None -> (code, "")
  in
  match kind with
  | "history-support-missing" ->
      "History unsupported: no zero-origin or bounded history for " ^ coordinate ^ "."
  | "history-precedes-bounded-start" ->
      "History unavailable: before bounded history start for " ^ coordinate ^ "."
  | "history-bounded-anchor-missing" ->
      "History unavailable: bounded history needs an exact current observation for " ^ coordinate
      ^ "."
  | "history-support-conflict" ->
      "History refused: overlapping history support for " ^ coordinate ^ "."
  | _ -> "History unavailable: " ^ code

let compute_samples ~book ~measure ~pool ~boundary_presets_text ~today ~preset =
  let ( let* ) = Result.bind in
  if pool = [] then Error "Daily Pace pool is empty."
  else
    let* start_day, through_day, _ = resolve_range ~today ~preset ~boundary_presets_text in
    let* windows =
      match boundary_presets_text with
      | None -> Error "Period not configured (boundary-presets.tsv missing)."
      | Some text -> parse_boundary_presets text
    in
    let* name, current_end =
      match List.filter (fun (_, a, b) -> a <= today && today < b) windows with
      | [ (name, _, stop) ] -> Ok (name, stop)
      | [] -> Error "No explicit boundary preset contains today."
      | _ -> Error "Multiple boundary presets contain today; selection is ambiguous."
    in
    let end_for day =
      match List.filter (fun (n, a, b) -> n = name && a <= day && day < b) windows with
      | [ (_, _, stop) ] -> Ok stop
      | _ -> Error ("No explicit cycle boundary for " ^ day ^ ".")
    in
    let coords =
      List.map
        (fun locus ->
          {
            D.Effect_coordinate.locus = A.get_id (D.Identifier.Locus.of_string locus);
            measure = A.get_id (D.Identifier.Measure.of_string measure);
          })
        pool
    in
    let* _ = query_pool_balance book coords in
    let* today_pace =
      match
        B.daily_pace book ~measure ~pool:coords ~observed_at:today ~end_exclusive:current_end
      with
      | Ok pace -> Ok pace
      | Error why -> Error (format_pace_error why)
    in
    let plans = B.plans book in
    let activities = compute_activities book measure pool in
    let activity_of day =
      Some (Option.value ~default:zero_activity (Hashtbl.find_opt activities day))
    in
    (* Opening/current observation alone does not certify a complete historical
       interval: Core routes each coordinate through zero-origin or explicit
       bounded-history support, and refuses otherwise. *)
    let days = dates_between start_day through_day in
    let pools = Hashtbl.create (List.length days) in
    List.iter2 (Hashtbl.replace pools) days
      (B.pools_at_end_of_days book ~measure ~pool:coords ~days);
    let history_pool day = Result.map_error history_reason (Hashtbl.find pools day) in
    let deductions_for day stop =
      List.fold_left
        (fun result (plan : B.plan) ->
          let* total = result in
          let drain =
            if plan.measure <> measure then Z.zero
            else
              Z.neg
                (Z.min Z.zero
                   (List.fold_left
                      (fun sum (locus, q) -> if List.mem locus pool then Z.add sum q else sum)
                      Z.zero plan.changes))
          in
          if Z.equal drain Z.zero || plan.day >= stop || plan.cancelled_on <> None then Ok total
          else
            match plan.paid_by with
            | None -> Ok (Z.add total drain)
            | Some id -> (
                match B.find_entry book id with
                | None ->
                    Error
                      ("History unavailable: Scheduled completion Actual " ^ id
                     ^ " is not retained.")
                | Some paid -> Ok (if paid.day <= day then total else Z.add total drain)))
        (Ok Z.zero) plans
    in
    let unavailable day stop why =
      {
        day;
        pace_quanta = None;
        available_through_end = Z.zero;
        pool_balance = Z.zero;
        deductions = Z.zero;
        remaining_days = 0;
        end_exclusive = stop;
        activity = activity_of day;
        unavailable = Some why;
      }
    in
    let samples =
      List.map
        (fun day ->
          match end_for day with
          | Error why -> unavailable day "" why
          | Ok stop -> (
              if day = today then
                {
                  day;
                  pace_quanta = Some today_pace.B.daily_pace_quanta;
                  available_through_end = today_pace.B.available_through_end;
                  pool_balance = today_pace.B.eligible_pool;
                  deductions = today_pace.B.automatic_deductions;
                  remaining_days = today_pace.B.remaining_days;
                  end_exclusive = stop;
                  activity = activity_of day;
                  unavailable = None;
                }
              else
                match history_pool day with
                | Error why -> unavailable day stop why
                | Ok pool_balance -> (
                    let remaining_days = day_number stop - day_number day in
                    if remaining_days <= 0 then
                      unavailable day stop "Past pace has no remaining calendar horizon."
                    else
                      match deductions_for day stop with
                      | Error why -> unavailable day stop why
                      | Ok deductions ->
                          let available_through_end = Z.sub pool_balance deductions in
                          {
                            day;
                            pace_quanta =
                              Some (Z.ediv available_through_end (Z.of_int remaining_days));
                            available_through_end;
                            pool_balance;
                            deductions;
                            remaining_days;
                            end_exclusive = stop;
                            activity = activity_of day;
                            unavailable = None;
                          })))
        days
    in
    Ok (start_day, through_day, samples)

(* Preset switch preserving the selected calendar date when the old range
   resolves; clamps to the new range, falls back to today when the old date
   is unavailable. A refused new range is an error, never a reset. *)
let change_preset ~today ~boundary_presets_text state preset =
  match resolve_range ~today ~preset ~boundary_presets_text with
  | Error msg -> Error msg
  | Ok (new_start, new_through, _) ->
      let selected_day =
        match resolve_range ~today ~preset:state.preset ~boundary_presets_text with
        | Error _ -> day_number today
        | Ok (old_start, old_through, _) ->
            let first = day_number old_start in
            let last = max 0 (day_number old_through - first) in
            first + Panel.move ~last ~position:state.selected_index 0
      in
      let last = max 0 (day_number new_through - day_number new_start) in
      let at = max 0 (min last (selected_day - day_number new_start)) in
      Ok { state with preset; selected_index = at }

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
  else if prev.end_exclusive <> current.end_exclusive then
    Error "Daily Pace change crosses a cycle boundary."
  else
    match Cal.shift_days prev.day 1 with
    | Ok next when next = current.day -> (
        if prev.remaining_days <> current.remaining_days + 1 || current.remaining_days <= 0 then
          Error "Daily Pace change requires a one-day shorter positive horizon."
        else if Z.sign prev.deductions < 0 || Z.sign current.deductions < 0 then
          Error "Daily Pace change requires nonnegative protected Scheduled outflows."
        else if
          (not (Z.equal (Z.sub prev.pool_balance prev.deductions) prev.available_through_end))
          || not
               (Z.equal
                  (Z.sub current.pool_balance current.deductions)
                  current.available_through_end)
        then Error "Daily Pace change has inconsistent available-through-end evidence."
        else
          match (prev.pace_quanta, current.pace_quanta) with
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
let signed_money book measure q = (if Z.sign q > 0 then "+" else "") ^ O.format_money book measure q

let count_supported samples =
  List.fold_left (fun acc s -> match s.pace_quanta with None -> acc | Some _ -> acc + 1) 0 samples

(* Selected date/pace summary: exact grouped amount or detail cue, never a
   truncated number. *)
let fit_value ~width ~width_of text =
  if width_of text <= width then text
  else if width >= 11 then "see details"
  else if width > 0 then "…"
  else ""

let summary_text ~width ~width_of ~book ~today ~measure ~partial sel =
  let value =
    match sel.pace_quanta with
    | Some q -> money_of book measure q
    | None -> "unavailable (not zero)"
  in
  let label = " Selected " ^ sel.day ^ "   " in
  let marker =
    if
      (not partial) && sel.day = today && width >= 38
      && width_of (label ^ value ^ "  current") <= width
    then "  current"
    else ""
  in
  let room = max 0 (width - width_of (label ^ marker)) in
  (* A tiny pane keeps the exact amount reachable beside its date. *)
  let compact = sel.day ^ " ◆ " ^ value in
  if width < 38 && width_of compact <= width then compact
  else if width_of label <= width then label ^ fit_value ~width:room ~width_of value ^ marker
  else O.clip_text ~width_of width (sel.day ^ " ◆ …")

let summary_change ~book ~measure ~samples ~selected =
  if selected = 0 then "first point"
  else
    match (List.nth_opt samples (selected - 1), List.nth_opt samples selected) with
    | Some previous, Some current -> (
        if previous.end_exclusive <> current.end_exclusive then "change unavailable (cycle reset)"
        else
          match (previous.pace_quanta, current.pace_quanta) with
          | Some prior, Some now ->
              "change " ^ signed_money book measure (Z.sub now prior) ^ " " ^ measure ^ "/day"
          | _ -> "change unavailable")
    | _ -> "previous day unavailable"

(* LOAM historyRows: blank, heading, then a trailing window of [height - 2]
   dates. The selected date is marked " > ", or " * " while details own focus. *)
let render_history ~width ~height ~width_of ~book ~today ~measure ~samples ~selected_index
    ~detail_focused =
  let capacity = height - 2 in
  if width < 8 || capacity <= 0 || samples = [] then []
  else
    let count = List.length samples in
    let selected = Panel.move ~last:(count - 1) ~position:selected_index 0 in
    let start = if selected < capacity then 0 else selected + 1 - capacity in
    let fit room text =
      if width_of text <= room then text
      else if room >= 11 then "see details"
      else if room > 0 then "…"
      else ""
    in
    let cell room text = O.pad_left ~width_of room (fit room text) in
    let pace_text s =
      match s.pace_quanta with None -> "unknown" | Some q -> money_of book measure q
    in
    let partial = count_supported samples < count in
    let table = width >= 46 && List.exists (fun s -> s.activity <> None) samples in
    let heading, row =
      if table then
        let rest = width - 3 - 11 in
        let pace_width = max 14 (rest * 42 / 100) and spent_width = max 9 (rest * 28 / 100) in
        let diff_width = max 0 (rest - pace_width - spent_width) in
        ( "   " ^ O.pad ~width_of 11 "Day"
          ^ O.pad_left ~width_of pace_width "Quanta/day"
          ^ O.pad_left ~width_of spent_width "Spent"
          ^ O.pad_left ~width_of diff_width "Pace diff",
          fun s ->
            let spent, diff =
              match s.activity with
              | None -> ("—", "—")
              | Some activity ->
                  ( O.format_money book measure activity.discretionary_outflow,
                    match s.pace_quanta with
                    | None -> "—"
                    | Some q -> signed_money book measure (Z.sub q activity.discretionary_outflow)
                  )
            in
            O.pad ~width_of 11 s.day
            ^ cell pace_width (pace_text s)
            ^ cell spent_width spent ^ cell diff_width diff )
      else
        let current_width = if (not partial) && width >= 39 then 9 else 0 in
        let date_width = min 12 (width - 3) in
        let value_width = max 0 (width - 3 - date_width - current_width) in
        ( "   " ^ O.pad ~width_of date_width "Day"
          ^ O.pad_left ~width_of value_width (if partial then "Value / status" else "Quanta/day"),
          fun s ->
            O.pad ~width_of date_width s.day
            ^ cell value_width (pace_text s)
            ^ if current_width > 0 && s.day = today then "  current" else "" )
    in
    let rows =
      List.filteri (fun i _ -> i >= start && i < start + capacity) samples
      |> List.mapi (fun offset s ->
          let chosen = start + offset = selected in
          let selected_active = chosen && ((not detail_focused) || (partial && not table)) in
          let marker =
            if not chosen then "   "
            else if detail_focused && not selected_active then " * "
            else " > "
          in
          ((if selected_active then O.Active else O.Plain), O.pad ~width_of width (marker ^ row s)))
    in
    (O.Plain, "") :: (O.Chrome, O.pad ~width_of width heading) :: rows

(* Summary plus braille plot and date axis; history rows live in
   render_history. Tiny heights keep the selected date/pace summary, with
   the support count when it fits. *)
let render_chart ~width ~height ~width_of ~book ~today ~measure ~samples ~selected_index
    ~graph_style =
  if width < 8 || height < 1 || samples = [] then []
  else
    let count = List.length samples in
    let arr = Array.of_list samples in
    let selected = Panel.move ~last:(count - 1) ~position:selected_index 0 in
    let sel = arr.(selected) in
    let supported = count_supported samples in
    let partial = supported < count in
    let summary_row =
      ( O.Active,
        O.pad ~width_of width (summary_text ~width ~width_of ~book ~today ~measure ~partial sel) )
    in
    let head =
      if partial then
        [
          summary_row;
          ( O.Chrome,
            O.pad ~width_of width
              (Printf.sprintf " %d/%d supported days • %s; unknown days stay gaps" supported count
                 (graph_style_label graph_style)) );
        ]
      else
        let change = summary_change ~book ~measure ~samples ~selected in
        let suffix =
          match (sel.pace_quanta, sel.activity) with
          | Some pace, Some activity ->
              " • spent "
              ^ O.format_money book measure activity.discretionary_outflow
              ^ " " ^ measure ^ " ("
              ^ signed_money book measure (Z.sub pace activity.discretionary_outflow)
              ^ " vs pace)"
          | _ -> ""
        in
        let second = " " ^ change ^ suffix in
        [
          summary_row;
          ( O.Chrome,
            O.pad ~width_of width
              (if width_of second <= width then second
               else " " ^ fit_value ~width:(max 0 (width - 1)) ~width_of change) );
        ]
    in
    (* LOAM trendPanel: two summary rows, then plot rows and a date axis only
       when the pane has at least six rows. *)
    let plot_h = if height >= 6 then height - 3 else 0 in
    if plot_h = 0 then List.filteri (fun i _ -> i < height) head
    else
      let label q = O.format_money book measure q in
      let values = List.map (fun s -> s.pace_quanta) samples in
      let numbers = List.filter_map Fun.id values in
      let axis =
        match numbers with
        | [] -> 3
        | _ -> Ui_chart.axis_width ~width_of width (Ui_chart.scale_for numbers) label
      in
      let plot =
        match numbers with
        | [] -> [ " No qualified points in this range" ]
        | _ ->
            let scale = Ui_chart.scale_for numbers in
            let joins =
              List.init
                (max 0 (count - 1))
                (fun i ->
                  arr.(i).pace_quanta <> None && arr.(i + 1).pace_quanta <> None
                  && arr.(i).end_exclusive = arr.(i + 1).end_exclusive
                  && day_number arr.(i + 1).day = day_number arr.(i).day + 1)
            in
            Ui_chart.qualified_rows
              ~width:(max 1 (width - axis - 3))
              ~height:plot_h ~values ~joins ~selected ~range:scale.range
              ~connect:(graph_style = Line)
              ~grid_rows:(List.map (Ui_chart.row_for_value plot_h scale.range) scale.ticks)
            |> Ui_chart.with_value_axis ~width_of ~axis ~height:plot_h ~scale ~label
      in
      let plot =
        List.init plot_h (fun i ->
            ( O.Plain,
              O.pad ~width_of width (match List.nth_opt plot i with Some row -> row | None -> "") ))
      in
      let first = arr.(0).day and last = arr.(count - 1).day in
      let left = axis + 3 in
      let date_axis =
        if width - left >= 21 then
          String.make left ' ' ^ O.pad ~width_of (width - left - 10) first ^ last
        else O.clip_text ~width_of width (first ^ " ... " ^ last)
      in
      head @ plot @ [ (O.Chrome, O.pad ~width_of width date_axis) ]

(* LOAM DailyPaceTrend detailLines: full history (every day supported) or
   partial history (Supported k/n, unknown dates kept as gaps). Two deliberate
   additions: a scheduled-linked inflow/reversal row, and a day's known
   activity beneath an unknown pace, never a dummy pool or zero. *)
let render_detail ~width ~width_of ~book ~measure ~samples ~selected_index ~today ~preset =
  let line style text =
    List.map (fun part -> (style, " " ^ part)) (O.wrap_text ~width_of (max 1 (width - 1)) text)
  in
  let plain = line O.Plain and muted = line O.Chrome in
  let amount q = O.format_money book measure q in
  let count = List.length samples in
  let index = max 0 (min (count - 1) selected_index) in
  let activity_lines ~pace (a : day_activity) =
    let spent = "Spent: " ^ amount a.discretionary_outflow ^ " " ^ measure in
    plain
      (match pace with
      | Some q ->
          spent ^ " (diff: "
          ^ signed_money book measure (Z.sub q a.discretionary_outflow)
          ^ " " ^ measure ^ ")"
      | None -> spent)
    @ (if Z.sign a.discretionary_inflow > 0 then
         muted ("Unscheduled inflow: +" ^ amount a.discretionary_inflow ^ " " ^ measure)
       else [])
    @ (if Z.sign a.scheduled_settled_outflow > 0 || Z.sign a.scheduled_reserved_outflow > 0 then
         let variance = Z.sub a.scheduled_reserved_outflow a.scheduled_settled_outflow in
         muted
           ("Settled: "
           ^ amount a.scheduled_settled_outflow
           ^ " " ^ measure
           ^
           if Z.equal variance Z.zero then " (as planned)"
           else " (" ^ signed_money book measure variance ^ " vs plan)")
       else [])
    (* Scheduled payments and their reversals are distinct from discretionary
       income: a linked reversal restores pool funds but is not a receipt. *)
    @
    if Z.sign a.scheduled_settled_inflow > 0 then
      muted
        ("Scheduled-linked inflow/reversal: +" ^ amount a.scheduled_settled_inflow ^ " " ^ measure)
    else []
  in
  let activity (s : sample) =
    match s.activity with None -> [] | Some a -> activity_lines ~pace:s.pace_quanta a
  in
  let disclosure =
    muted "Reconstructed current truth." @ muted "no separate daily snapshot is kept."
  in
  let movement prev current =
    match compare_change ~prev ~current with
    | Ok b ->
        muted
          ("Time passage: "
          ^ signed_money book measure b.time_passage_effect
          ^ " " ^ measure ^ "/day")
        @ muted
            ("Free money effect: "
            ^ signed_money book measure b.free_money_effect
            ^ " " ^ measure ^ "/day")
        @ muted
            ("Pool balance delta: "
            ^ signed_money book measure b.pool_balance_change
            ^ " " ^ measure)
        @ muted
            ("Scheduled protection release: "
            ^ signed_money book measure b.protection_release
            ^ " " ^ measure)
        @ muted
            ("Free-through-end delta: "
            ^ signed_money book measure b.free_through_end_change
            ^ " " ^ measure)
    | Error _ -> muted "Day-to-day breakdown unavailable (not adjacent within one cycle)."
  in
  let prev = if index = 0 then None else List.nth_opt samples (index - 1) in
  match List.nth_opt samples index with
  | None -> muted "No sample selected."
  | Some s when count_supported samples < count -> (
      let known (x : sample) = x.pace_quanta <> None in
      let header = muted (Printf.sprintf "Supported: %d/%d days" (count_supported samples) count) in
      let body =
        match s.pace_quanta with
        | None ->
            plain ("Selected " ^ s.day ^ ": unavailable, not zero")
            @ muted (Option.value s.unavailable ~default:"Historical pace unavailable.")
            @ activity s
        | Some q ->
            plain ("Selected " ^ s.day ^ ": " ^ money_of book measure q)
            @ muted
                (match prev with
                | None -> "first point"
                | Some p when known p -> summary_change ~book ~measure ~samples ~selected:index
                | Some _ -> "previous day unavailable")
            @ activity s
            @ muted
                ("Origin: "
                ^
                if s.day = today then "current admitted truth"
                else "reconstructed from current knowledge, not as-known history")
            @ muted ("Cycle end (exclusive): " ^ s.end_exclusive)
            @ muted ("Remaining days: " ^ string_of_int s.remaining_days)
            @ muted ("Pool: " ^ amount s.pool_balance ^ " " ^ measure)
            @ muted ("Scheduled deductions: " ^ amount s.deductions)
            @ muted ("Available: " ^ amount s.available_through_end)
      in
      header @ body @ disclosure
      @ match prev with Some p when known p && known s -> movement p s | _ -> [])
  | Some s -> (
      let first = (List.hd samples).day and last = (List.nth samples (count - 1)).day in
      let pace =
        match s.pace_quanta with Some q -> money_of book measure q | None -> "unavailable"
      in
      muted ("Period: " ^ preset_label preset)
      @ muted ("Display: " ^ first ^ " through " ^ last)
      @ plain ("Selected " ^ s.day)
      @ plain ("Pace: " ^ pace ^ if s.day = today then "  current" else "")
      @ muted (summary_change ~book ~measure ~samples ~selected:index)
      @ activity s
      @ muted ("Cycle end (exclusive): " ^ s.end_exclusive)
      @ muted ("Remaining days: " ^ string_of_int s.remaining_days)
      @ muted ("Pool: " ^ amount s.pool_balance ^ " " ^ measure)
      @ muted ("Scheduled deductions: " ^ amount s.deductions)
      @ muted ("Available: " ^ amount s.available_through_end ^ " / remaining days")
      @ muted ("From: " ^ first)
      @ muted ("Through: " ^ last)
      @ disclosure
      @ match prev with Some p -> movement p s | None -> [])
