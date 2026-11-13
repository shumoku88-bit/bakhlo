(* Daily Pace Trend: retrospective current-truth spending pace analysis over 10d, 30d, month, cycle. *)
module B = Bakhlo_household.Book
module P = Bakhlo_household.Period
module Day = Bakhlo_household.Day
module O = Ui_render
module A = Draft
module Panel = Ui_panel

type preset = Ten_days | Thirty_days | Month | Cycle | Previous_cycle

type day_activity = B.day_activity = {
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

(* The days a preset lists, first and last inclusive; Period owns the rules. *)
let resolve_range ~today ~preset ~boundary_presets_text =
  let range =
    match preset with
    | Ten_days -> P.Last_days 10
    | Thirty_days -> P.Last_days 30
    | Month -> P.Month_to_date
    | Cycle -> P.Cycle_to_date
    | Previous_cycle -> P.Whole_previous_cycle
  in
  Result.map_error (P.message ~today) (P.range ~config:boundary_presets_text ~today range)

let day_number text = Result.value ~default:0 (Day.index text)

let dates_between start_day through_day =
  let start_num = day_number start_day in
  let end_num = day_number through_day in
  let count = max 0 (end_num - start_num + 1) in
  List.init count (fun i ->
      match Day.shift_days start_day i with Ok d -> d | Error _ -> start_day)

(* Sum exact pool balances; unknown or unsupported balances refuse instead of defaulting. *)
let query_pool_balance book coords =
  let rec sum acc = function
    | [] -> Ok acc
    | (c : B.coordinate) :: rest -> (
        match B.quantity book ~locus:c.locus ~measure:c.measure with
        | Some q -> sum (Z.add acc q.amount) rest
        | None ->
            Error
              (Pace.format_pace_error
                 ("daily-pace-balance-support-unknown:" ^ c.locus ^ ":" ^ c.measure)))
  in
  sum Z.zero coords

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
  | "daily-pace-non-positive-horizon" -> "Past pace has no remaining calendar horizon."
  | "plan-payment-missing" ->
      "History unavailable: Scheduled completion Actual " ^ coordinate ^ " is not retained."
  | _ -> "History unavailable: " ^ code

let compute_samples ~book ~measure ~pool ~boundary_presets_text ~today ~preset =
  let ( let* ) = Result.bind in
  if pool = [] then Error "Daily Pace pool is empty."
  else
    let* start_day, through_day = resolve_range ~today ~preset ~boundary_presets_text in
    let* cycle =
      Result.map_error (P.message ~today)
        (Result.bind (P.read boundary_presets_text) (P.cycle ~day:today))
    in
    let current_end = snd (List.nth cycle.windows cycle.index) in
    let end_for day =
      match P.window_of cycle day with
      | Some (_, stop) -> Ok stop
      | None -> Error ("No explicit cycle boundary for " ^ day ^ ".")
    in
    let* coords =
      List.fold_right
        (fun locus coords ->
          let* coords = coords in
          let* coordinate = A.coordinate ~locus ~measure in
          Ok (coordinate :: coords))
        pool (Ok [])
    in
    let* _ = query_pool_balance book coords in
    let* today_pace =
      match
        B.daily_pace book ~measure ~pool:coords ~observed_at:today ~end_exclusive:current_end
      with
      | Ok pace -> Ok pace
      | Error why -> Error (Pace.format_pace_error why)
    in
    let activities = Hashtbl.create 64 in
    List.iter
      (fun (day, a) -> Hashtbl.replace activities day a)
      (B.day_activities book ~measure ~pool:coords);
    let activity_of day =
      Some (Option.value ~default:B.quiet_day (Hashtbl.find_opt activities day))
    in
    (* Opening/current observation alone does not certify a complete historical
       interval: Core routes each coordinate through zero-origin or explicit
       bounded-history support, and refuses otherwise. *)
    let days = dates_between start_day through_day in
    let ends = List.map (fun day -> (day, end_for day)) days in
    let past = Hashtbl.create (List.length days) in
    let asked =
      List.filter_map
        (fun (day, stop) ->
          match stop with Ok stop when day <> today -> Some (day, stop) | _ -> None)
        ends
    in
    List.iter2
      (fun (day, _) answer -> Hashtbl.replace past day answer)
      asked
      (B.past_paces book ~measure ~pool:coords ~days:asked);
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
        (fun (day, stop) ->
          match stop with
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
                match Hashtbl.find past day with
                | Error why -> unavailable day stop (history_reason why)
                | Ok (p : B.past_pace) ->
                    {
                      day;
                      pace_quanta = Some p.pace;
                      available_through_end = p.available;
                      pool_balance = p.restated_pool;
                      deductions = Z.sub p.restated_pool p.available;
                      remaining_days = p.remaining_days;
                      end_exclusive = stop;
                      activity = activity_of day;
                      unavailable = None;
                    }))
        ends
    in
    Ok (start_day, through_day, samples)

(* Preset switch preserving the selected calendar date when the old range
   resolves; clamps to the new range, falls back to today when the old date
   is unavailable. A refused new range is an error, never a reset. *)
let change_preset ~today ~boundary_presets_text state preset =
  match resolve_range ~today ~preset ~boundary_presets_text with
  | Error msg -> Error msg
  | Ok (new_start, new_through) ->
      let selected_day =
        match resolve_range ~today ~preset:state.preset ~boundary_presets_text with
        | Error _ -> day_number today
        | Ok (old_start, old_through) ->
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
  | Ok (start_day, through_day) ->
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
    match Day.shift_days prev.day 1 with
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
let money_of book measure q = Book_display.format_money book measure q ^ " " ^ measure ^ "/day"

let signed_money book measure q =
  (if Z.sign q > 0 then "+" else "") ^ Book_display.format_money book measure q

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

(* What the household actually spent per day over the displayed days, today
   included even though it is not over yet:

     Spent 1,471 3,050 798 ... 738   17,470 in 10 days   1,747 jpy/day

   Beside today's pace it tells whether the period ran above or below it. The
   average is floored to the book's quantum, as Trend floors its windows, and
   the exact total and day count always accompany it. A day whose activity is
   unknown is left out of both, never counted as zero. *)
let average_spent samples =
  let total, days =
    List.fold_left
      (fun (total, days) s ->
        match s.activity with
        | None -> (total, days)
        | Some a -> (Z.add total a.discretionary_outflow, days + 1))
      (Z.zero, 0) samples
  in
  if days = 0 then None else Some (Z.fdiv total (Z.of_int days), total, days)

let average_spent_texts ~book ~measure samples =
  match average_spent samples with
  | None -> []
  | Some (average, total, days) ->
      let short = "Average spent " ^ money_of book measure average in
      [
        Printf.sprintf "%s • %s %s in %d %s" short
          (Book_display.format_money book measure total)
          measure days
          (if days = 1 then "day" else "days");
        short;
      ]

(* LOAM historyRows: the period's average spending (blank when it does not fit),
   heading, then a trailing window of [height - 2]
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
    let cell style room text =
      let fitted = fit room text in
      ((if fitted = text then style else O.Status), O.pad_left ~width_of room fitted)
    in
    let pace_cell room s =
      match s.pace_quanta with
      | None -> cell O.Status room "unknown"
      | Some q -> cell O.Heading room (money_of book measure q)
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
              | None -> (cell O.Chrome spent_width "—", cell O.Chrome diff_width "—")
              | Some activity ->
                  ( cell O.Heading spent_width
                      (Book_display.format_money book measure activity.discretionary_outflow),
                    match s.pace_quanta with
                    | None -> cell O.Chrome diff_width "—"
                    | Some q ->
                        cell O.Heading diff_width
                          (signed_money book measure (Z.sub q activity.discretionary_outflow)) )
            in
            [ (O.Heading, O.pad ~width_of 11 s.day); pace_cell pace_width s; spent; diff ] )
      else
        let current_width = if (not partial) && width >= 39 then 9 else 0 in
        let date_width = min 12 (width - 3) in
        let value_width = max 0 (width - 3 - date_width - current_width) in
        ( "   " ^ O.pad ~width_of date_width "Day"
          ^ O.pad_left ~width_of value_width (if partial then "Value / status" else "Quanta/day"),
          fun s ->
            [ (O.Heading, O.pad ~width_of date_width s.day); pace_cell value_width s ]
            @ if current_width > 0 && s.day = today then [ (O.Chrome, "  current") ] else [] )
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
          let spans =
            O.fit_spans ~width_of width (((if chosen then O.Heading else O.Plain), marker) :: row s)
          in
          let text = O.spans_text spans in
          (* The focused row, including its padding, remains one selection band.
             Other rows let exact values lead; unknown and overflow stay explicit. *)
          ((if selected_active then O.Active else O.Spans spans), text))
    in
    let average =
      match
        List.find_opt
          (fun text -> width_of text + 1 <= width)
          (average_spent_texts ~book ~measure samples)
      with
      | Some text -> (O.Heading, O.pad ~width_of width (" " ^ text))
      | None -> (O.Plain, "")
    in
    average :: (O.Chrome, O.pad ~width_of width heading) :: rows

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
              ^ Book_display.format_money book measure activity.discretionary_outflow
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
      let label q = Book_display.format_money book measure q in
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
  (* Pace and spending answer the day's question. Supporting sums remain readable;
     periods and provenance recede. Style whole wrapped lines, so a long quantity
     keeps its emphasis without another wrapping rule. *)
  let plain = line O.Plain and muted = line O.Chrome in
  let heading = line O.Heading and status = line O.Status in
  let amount q = Book_display.format_money book measure q in
  let count = List.length samples in
  let index = max 0 (min (count - 1) selected_index) in
  let activity_lines ~pace (a : day_activity) =
    let spent = "Spent: " ^ amount a.discretionary_outflow ^ " " ^ measure in
    heading
      (match pace with
      | Some q ->
          spent ^ " (diff: "
          ^ signed_money book measure (Z.sub q a.discretionary_outflow)
          ^ " " ^ measure ^ ")"
      | None -> spent)
    @ (if Z.sign a.discretionary_inflow > 0 then
         plain ("Unscheduled inflow: +" ^ amount a.discretionary_inflow ^ " " ^ measure)
       else [])
    @ (if Z.sign a.scheduled_settled_outflow > 0 || Z.sign a.scheduled_reserved_outflow > 0 then
         let variance = Z.sub a.scheduled_reserved_outflow a.scheduled_settled_outflow in
         plain
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
      plain
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
        plain
          ("Time passage: "
          ^ signed_money book measure b.time_passage_effect
          ^ " " ^ measure ^ "/day")
        @ plain
            ("Free money effect: "
            ^ signed_money book measure b.free_money_effect
            ^ " " ^ measure ^ "/day")
        @ plain
            ("Pool balance delta: "
            ^ signed_money book measure b.pool_balance_change
            ^ " " ^ measure)
        @ plain
            ("Scheduled protection release: "
            ^ signed_money book measure b.protection_release
            ^ " " ^ measure)
        @ plain
            ("Free-through-end delta: "
            ^ signed_money book measure b.free_through_end_change
            ^ " " ^ measure)
    | Error _ -> status "Day-to-day breakdown unavailable (not adjacent within one cycle)."
  in
  let average =
    match average_spent_texts ~book ~measure samples with
    | full :: _ -> heading (full ^ " (floored)")
    | [] -> []
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
            status ("Selected " ^ s.day ^ ": unavailable, not zero")
            @ status (Option.value s.unavailable ~default:"Historical pace unavailable.")
            @ activity s
        | Some q ->
            heading ("Selected " ^ s.day ^ ": " ^ money_of book measure q)
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
            @ plain ("Pool: " ^ amount s.pool_balance ^ " " ^ measure)
            @ plain ("Scheduled deductions: " ^ amount s.deductions)
            @ plain ("Available: " ^ amount s.available_through_end)
      in
      header @ average @ body @ disclosure
      @ match prev with Some p when known p && known s -> movement p s | _ -> [])
  | Some s -> (
      let first = (List.hd samples).day and last = (List.nth samples (count - 1)).day in
      let pace =
        match s.pace_quanta with Some q -> money_of book measure q | None -> "unavailable"
      in
      muted ("Period: " ^ preset_label preset)
      @ muted ("Display: " ^ first ^ " through " ^ last)
      @ average
      @ heading ("Selected " ^ s.day)
      @ heading ("Pace: " ^ pace ^ if s.day = today then "  current" else "")
      @ muted (summary_change ~book ~measure ~samples ~selected:index)
      @ activity s
      @ muted ("Cycle end (exclusive): " ^ s.end_exclusive)
      @ muted ("Remaining days: " ^ string_of_int s.remaining_days)
      @ plain ("Pool: " ^ amount s.pool_balance ^ " " ^ measure)
      @ plain ("Scheduled deductions: " ^ amount s.deductions)
      @ plain ("Available: " ^ amount s.available_through_end ^ " / remaining days")
      @ muted ("From: " ^ first)
      @ muted ("Through: " ^ last)
      @ disclosure
      @ match prev with Some p -> movement p s | None -> [])
