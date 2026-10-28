(* LOAM DailyPaceTarget over the current Daily Pace answer. Exact Z quanta;
   Euclidean division as in Lean's Int. Unlike LOAM (JPY only), any Measure
   works: inputs are whole units of the pace Measure, scaled to its quanta. *)
module B = Bakhlo_household.Daily_book
module O = Ui_render
module A = Daily_draft
module Panel = Ui_panel
module Trend = Daily_pace_trend

type plan = {
  target_per_day : Z.t;
  target_date : string;
  purchase : Z.t;
  days : int;
  daily_spend : Z.t;
  reachable : bool;
  path : Z.t list;
}

type options = { horizons : plan list; earliest : plan option }

let pace_on_target plan = match List.rev plan.path with last :: _ -> last | [] -> Z.zero
let digits text = String.for_all (fun c -> c >= '0' && c <= '9') text

(* Spending [s] on each of [days] days leaves [available - s*days] for
   [remaining - days] days, so the largest [s] reaching target [n] is
   floor((available - n*(remaining - days)) / days). *)
let solve (p : B.daily_pace) available n purchase days date =
  let rest = Z.of_int (p.remaining_days - days) in
  let raw = Z.ediv (Z.sub available (Z.mul n rest)) (Z.of_int days) in
  let spend = Z.max Z.zero raw in
  {
    target_per_day = n;
    target_date = date;
    purchase;
    days;
    daily_spend = spend;
    reachable = Z.geq raw Z.zero;
    path =
      List.init (days + 1) (fun i ->
          Z.ediv (Z.sub available (Z.mul spend (Z.of_int i))) (Z.of_int (p.remaining_days - i)));
  }

let unit_quanta book measure =
  match List.assoc_opt measure (B.measures book) with
  | Some scale -> Ok (Z.pow (Z.of_int 10) scale)
  | None -> Error ("Unknown Measure " ^ measure ^ ".")

let amount ~book (p : B.daily_pace) label text =
  if String.length text > 18 || not (digits text) then
    Error
      (label ^ " accepts nonnegative " ^ String.uppercase_ascii p.measure
     ^ " digits only (up to 18).")
  else if text = "" then Error ("Invalid " ^ label ^ ".")
  else Result.map (Z.mul (Z.of_string text)) (unit_quanta book p.measure)

let available_after ~book (p : B.daily_pace) purchase =
  if purchase = "" then Ok p.available_through_end
  else Result.map (Z.sub p.available_through_end) (amount ~book p "Spend today" purchase)

let target_amount ~book (p : B.daily_pace) target =
  if target = "" then
    Error
      ("Enter a nonnegative target " ^ String.uppercase_ascii p.measure ^ "/day (up to 18 digits).")
  else amount ~book p ("Target " ^ String.uppercase_ascii p.measure ^ "/day") target

let shift day n = match Day.shift_days day n with Ok d -> Some d | Error _ -> None
let valid_date date = Day.normalize date = Ok date

(* [D]/[DD] and [M-D]/[MM-DD] name the first such day after today and before
   cycle end; any other spelling is returned unchanged for full validation. *)
let resolve_date (p : B.daily_pace) text =
  let part value =
    if String.length value >= 1 && String.length value <= 2 && digits value then
      int_of_string_opt value
    else None
  in
  let month, day =
    match String.split_on_char '-' text with
    | [ day ] -> (Some None, part day)
    | [ month; day ] -> (Option.map Option.some (part month), part day)
    | _ -> (None, None)
  in
  match (month, day) with
  | Some month, Some day ->
      let fits date =
        match Day.parts date with
        | Ok (_, m, d) -> d = day && Option.fold ~none:true ~some:(( = ) m) month
        | Error _ -> false
      in
      let rec find offset =
        if offset >= p.remaining_days - 1 then
          Error
            ("No day " ^ text ^ " after today and before cycle end " ^ p.end_exclusive
           ^ " (exclusive).")
        else
          match shift p.observed_at (offset + 1) with
          | Some date when fits date -> Ok date
          | _ -> find (offset + 1)
      in
      find 0
  | _ -> Ok text

let ( let* ) = Result.bind

let plan ~book (p : B.daily_pace) ~target ~date ~purchase =
  let* available = available_after ~book p purchase in
  let* n = target_amount ~book p target in
  let* date = resolve_date p date in
  if not (valid_date date) then Error "Enter a real target date as YYYY-MM-DD."
  else
    let distance = Trend.day_number date - Trend.day_number p.observed_at in
    if distance <= 0 || distance >= p.remaining_days then
      Error
        ("Target date must be after today and before cycle end " ^ p.end_exclusive ^ " (exclusive).")
    else Ok (solve p available n (Z.sub p.available_through_end available) distance date)

let options ~book (p : B.daily_pace) ~target ~purchase =
  let* available = available_after ~book p purchase in
  let* n = target_amount ~book p target in
  let last = max 0 (p.remaining_days - 1) in
  if last = 0 then Error "No later day remains in this cycle."
  else
    let plan_at days =
      Option.map
        (fun date -> solve p available n (Z.sub p.available_through_end available) days date)
        (shift p.observed_at days)
    in
    Ok
      {
        horizons =
          List.filter_map plan_at (List.filter (fun d -> d < last) [ 3; 7; 14; 21; 28; 42 ]);
        earliest =
          List.find_map
            (fun days ->
              Option.bind (plan_at days) (fun plan -> if plan.reachable then Some plan else None))
            (List.init last (fun i -> i + 1));
      }

(* Editing state is ephemeral; nothing here is saved. *)

type field = Target | Date | Purchase

type t = {
  target : string;
  date : string;
  purchase : string;
  field : field;
  horizon : int option;  (** Charted undated horizon; [None] follows the first reachable. *)
  notice : string;
}

let create () =
  { target = ""; date = ""; purchase = ""; field = Target; horizon = None; notice = "" }

type step = Stay of t | Back

let value t = match t.field with Target -> t.target | Date -> t.date | Purchase -> t.purchase

let set_value t text =
  match t.field with
  | Target -> { t with target = text; notice = "" }
  | Date -> { t with date = text; notice = "" }
  | Purchase -> { t with purchase = text; notice = "" }

let next = function Target -> Date | Date -> Purchase | Purchase -> Target
let previous = function Target -> Purchase | Date -> Target | Purchase -> Date
let limit = function Target | Purchase -> 18 | Date -> 10

let horizons ~book pace t =
  match pace with
  | Error _ -> []
  | Ok p -> (
      match options ~book p ~target:t.target ~purchase:t.purchase with
      | Ok o -> o.horizons
      | Error _ -> [])

let selected plans t =
  match t.horizon with
  | Some index -> max 0 (min index (List.length plans - 1))
  | None ->
      let rec first i = function
        | [] -> 0
        | plan :: rest -> if plan.reachable then i else first (i + 1) rest
      in
      first 0 plans

let update ~book ~pace t (input : Ui_input.input) =
  match input with
  | `Key ((`Escape | `ASCII ('q' | 'Q')), []) -> Back
  | `Key (`ASCII (('j' | 'k') as c), []) ->
      let plans = horizons ~book pace t in
      if plans = [] || t.date <> "" then Stay t
      else
        let index = selected plans t in
        let moved =
          if c = 'j' then min (index + 1) (List.length plans - 1) else max 0 (index - 1)
        in
        Stay { t with horizon = Some moved; notice = "" }
  | `Key ((`Tab | `Enter | `Arrow `Down), []) -> Stay { t with field = next t.field; notice = "" }
  | `Key (`Tab, [ `Shift ]) | `Key (`Arrow `Up, []) ->
      Stay { t with field = previous t.field; notice = "" }
  | `Key (`Backspace, []) ->
      let text = value t in
      Stay (set_value t (if text = "" then "" else String.sub text 0 (String.length text - 1)))
  | `Key (`ASCII c, []) ->
      let accepted = (c >= '0' && c <= '9') || (t.field = Date && c = '-') in
      if accepted && String.length (value t) < limit t.field then
        Stay (set_value t (value t ^ String.make 1 c))
      else
        let units =
          match pace with
          | Ok (p : B.daily_pace) -> String.uppercase_ascii p.measure
          | Error _ -> "whole-unit"
        in
        Stay
          {
            t with
            notice =
              (match t.field with
              | Target -> "Target accepts " ^ units ^ " digits only, at most 18. Esc/q closes."
              | Date -> "Date accepts 26, 11-02 or YYYY-MM-DD. Esc/q closes."
              | Purchase ->
                  "Spend today accepts " ^ units ^ " digits only, at most 18. Esc/q closes.");
          }
  | _ -> Stay t

(* Painting *)

let weekday date =
  match Day.weekday date with
  | Ok i -> List.nth [ "Mon"; "Tue"; "Wed"; "Thu"; "Fri"; "Sat"; "Sun" ] i
  | Error _ -> ""

let short_date date = String.sub date 5 (String.length date - 5) ^ " " ^ weekday date

(* Resample [path] at [count] evenly spaced positions, interpolating between
   days. Presentation only: plotted values never feed back into the plan. *)
let resample path count =
  let path = Array.of_list path in
  let days = Array.length path - 1 in
  let den = max 1 (count - 1) in
  let at i default = if i >= 0 && i < Array.length path then path.(i) else default in
  List.init count (fun i ->
      let day = i * days / den in
      let start = at day Z.zero in
      Z.add start
        (Z.ediv
           (Z.mul (Z.sub (at (day + 1) start) start) (Z.of_int (i * days mod den)))
           (Z.of_int den)))

let chart_rows ~width_of ~width ~height ~fmt current plan =
  let scale = Ui_chart.scale_for (plan.target_per_day :: current :: plan.path) in
  (* Widen the tick column for the [target] guide label when the plot can afford it. *)
  let axis = max (Ui_chart.axis_width ~width_of width scale fmt) (min 6 (width / 4)) in
  (* One spare column keeps the target-date marker off the panel border. *)
  let plot_width = max 1 (width - axis - 4) in
  let points =
    if Z.equal plan.purchase Z.zero then plan.path
    else current :: resample plan.path (max 2 (2 * plot_width))
  in
  let target_row = Ui_chart.row_for_value height scale.range plan.target_per_day in
  let rows =
    Ui_chart.line_rows ~width:plot_width ~height ~values:points
      ~selected:(List.length points - 1)
      ~range:scale.range ~grid_rows:[ target_row ]
    |> Ui_chart.with_value_axis ~width_of ~axis ~height ~scale ~label:fmt ~note:(fun row ->
        if row = target_row && axis >= 6 then "target" else "")
  in
  let date =
    String.make (axis + 3) ' '
    ^
    if plot_width >= 21 then O.pad ~width_of (plot_width - 10) "today" ^ plan.target_date
    else "today … " ^ plan.target_date
  in
  List.map (fun row -> (O.Plain, row)) rows @ [ (O.Chrome, date) ]

let option_rows ~width_of ~width ~fmt ~measure options chosen =
  let cells plan =
    [
      short_date plan.target_date;
      string_of_int plan.days;
      (if plan.reachable then fmt plan.daily_spend else "—");
      (if plan.reachable then fmt (Z.mul plan.daily_spend (Z.of_int plan.days)) else "—");
      (if plan.reachable then "✓" else fmt (pace_on_target plan));
    ]
  in
  let header = [ "Until"; "Days"; "Per day"; "Total"; "Pace then" ] in
  let rows = List.map cells options.horizons in
  let widths =
    List.fold_left
      (fun acc row -> List.map2 (fun w cell -> max w (width_of cell)) acc row)
      [ 0; 0; 0; 0; 0 ] (header :: rows)
  in
  (* A reachable row's pace then is the target by construction; the column only
     earns its place for a row whose zero-spend pace still falls short. *)
  let layouts =
    if List.for_all (fun p -> p.reachable) options.horizons then
      [ [ 0; 1; 2; 3 ]; [ 0; 1; 2 ]; [ 0; 2 ] ]
    else [ [ 0; 1; 2; 3; 4 ]; [ 0; 1; 2; 4 ]; [ 0; 2; 4 ] ]
  in
  let extent columns = List.fold_left (fun total i -> total + 2 + List.nth widths i) 3 columns in
  let columns =
    Option.value ~default:[ 0; 2 ] (List.find_opt (fun c -> extent c <= width) layouts)
  in
  let render marker row =
    marker
    ^ String.concat ""
        (List.map
           (fun i ->
             let text = List.nth row i and w = List.nth widths i in
             (if i = 0 then " " else "  ")
             ^ if i = 0 then O.pad ~width_of w text else O.pad_left ~width_of w text)
           columns)
  in
  let info style text =
    List.map (fun line -> (style, line)) (O.wrap_text ~width_of (max 1 width) text)
  in
  (if options.horizons = [] then []
   else
     info O.Plain
       (" To be back at "
       ^ fmt (List.hd options.horizons).target_per_day
       ^ " " ^ measure ^ "/day, spend at most:")
     @ [ (O.Chrome, render "  " header) ]
     @ List.mapi
         (fun i (plan, row) ->
           if i = chosen then (O.Active, render " ›" row)
           else ((if plan.reachable then O.Plain else O.Chrome), render "  " row))
         (List.combine options.horizons rows))
  @
  match options.earliest with
  | Some plan ->
      info O.Chrome
        (" Earliest: " ^ plan.target_date ^ " (" ^ string_of_int plan.days
        ^ (if plan.days = 1 then " day" else " days")
        ^ "), spending at most " ^ fmt plan.daily_spend ^ " " ^ measure ^ "/day")
  | None -> info O.Chrome " Not reachable in this cycle, even spending nothing."

let result_rows ~width_of ~width ~fmt (p : B.daily_pace) plan =
  let info style text =
    List.map (fun line -> (style, line)) (O.wrap_text ~width_of (max 1 width) text)
  in
  let m = p.measure in
  let through = Option.value ~default:plan.target_date (shift plan.target_date (-1)) in
  if plan.reachable then
    info O.Plain
      (" Spend up to " ^ fmt plan.daily_spend ^ " " ^ m ^ "/day for " ^ string_of_int plan.days
     ^ " days ("
      ^ fmt (Z.mul plan.daily_spend (Z.of_int plan.days))
      ^ " total)")
    (* Pace depends on the total, so uneven days within it reach the same target. *)
    @ info O.Chrome
        (" " ^ p.observed_at ^ " … " ^ through ^ "; uneven days are fine within the total")
    @ info O.Chrome
        (" Pace from " ^ plan.target_date ^ ": "
        ^ fmt (pace_on_target plan)
        ^ " " ^ m ^ "/day (target " ^ fmt plan.target_per_day ^ ")")
  else
    info O.Plain
      (" Not reachable by " ^ plan.target_date ^ ": even spending 0, pace is "
      ^ fmt (pace_on_target plan)
      ^ " " ^ m ^ "/day (target " ^ fmt plan.target_per_day ^ ").")
    @ info O.Chrome
        (" Available now: " ^ fmt (Z.sub p.available_through_end plan.purchase) ^ " " ^ m)

let body_rows ~width_of ~width ~capacity ~book ~pace t =
  let info style text =
    List.map (fun line -> (style, line)) (O.wrap_text ~width_of (max 1 width) text)
  in
  let measure = match pace with Ok (p : B.daily_pace) -> p.measure | Error _ -> "" in
  (* LOAM inputSpan: the value, a caret cell while active, `_` for an empty
     inactive field; the date hint follows the value itself. *)
  let field label active text extra =
    let label_text = O.pad ~width_of 17 label in
    let room = max 1 (width - 17 - width_of extra) in
    if active then
      let shown, caret = O.input_text ~width_of ~width:room ~cursor:None ~caret:"|" text in
      ( (match caret with Some col -> O.Input (17 + col) | None -> O.Plain),
        label_text ^ shown ^ extra )
    else (O.Plain, label_text ^ O.clip_text ~width_of room (if text = "" then "_" else text) ^ extra)
  in
  (* Show what an abbreviated date resolves to, beside the field itself. *)
  let resolved =
    match pace with
    | Ok p when t.date <> "" -> (
        match resolve_date p t.date with
        | Ok date when valid_date date ->
            (if date = t.date then "  " else "  → " ^ date ^ " ") ^ weekday date
        | _ -> "")
    | _ -> ""
  in
  let resolved = if width >= 17 + 12 + width_of resolved then resolved else "" in
  let head =
    [
      field (" Target " ^ String.uppercase_ascii measure ^ "/day: ") (t.field = Target) t.target "";
      field " Target date:    " (t.field = Date) t.date resolved;
      field " Spend today:    " (t.field = Purchase) t.purchase "";
    ]
  in
  let notice = if t.notice = "" then [] else info O.Status t.notice in
  match pace with
  | Error why ->
      head @ info O.Plain " Current projection unavailable (not zero)." @ info O.Chrome why @ notice
  | Ok p -> (
      let fmt q = Book_display.format_money book p.measure q in
      let current = p.daily_pace_quanta in
      let now =
        info O.Chrome
          (" Now: " ^ fmt current ^ " " ^ p.measure ^ "/day • " ^ string_of_int p.remaining_days
         ^ " days left")
      in
      (* The answer precedes context, so the smallest panes still show it. *)
      let bought =
        match available_after ~book p t.purchase with
        | Ok available when not (Z.equal available p.available_through_end) ->
            info O.Plain
              (" After "
              ^ fmt (Z.sub p.available_through_end available)
              ^ " today: "
              ^ fmt (Z.ediv available (Z.of_int p.remaining_days))
              ^ " " ^ p.measure ^ "/day (now " ^ fmt current ^ ")")
        | _ -> []
      in
      let text = head @ notice @ bought in
      (* Plot rows plus the date axis; a squeezed chart is omitted rather than distorted. *)
      let with_chart text plan =
        let height = capacity - List.length text - 1 in
        if height >= 3 && width >= 24 then
          text
          @ [ (O.Plain, "") ]
          @ chart_rows ~width_of ~width ~height:(height - 1) ~fmt current plan
        else text
      in
      if t.target = "" then
        text
        @ info O.Chrome
            (" Enter a target pace; a date (26, 11-02 or YYYY-MM-DD) "
           ^ "gives a daily plan. Nothing is recorded.")
        @ now
      else if t.date = "" then
        match options ~book p ~target:t.target ~purchase:t.purchase with
        | Error why -> text @ info O.Plain why @ now
        | Ok o -> (
            let chosen = selected o.horizons t in
            let text = text @ option_rows ~width_of ~width ~fmt ~measure:p.measure o chosen @ now in
            match List.nth_opt o.horizons chosen with
            | Some plan -> with_chart text plan
            | None -> text)
      else
        match plan ~book p ~target:t.target ~date:t.date ~purchase:t.purchase with
        | Error why -> text @ info O.Plain why @ now
        | Ok plan -> with_chart (text @ result_rows ~width_of ~width ~fmt p plan @ now) plan)

let frame ~width_of ~screen ~body:((body_w, body_h) as body) ~book ~pace t =
  if not (body_w >= 62 && body_h >= 20) then
    (* Compact: the whole body, LOAM's title line and no frame. The answer keeps
       every row; the Shell footer already says nothing is recorded. *)
    let width = max 1 body_w in
    let rows =
      (O.Plain, " Daily Pace / Target plan")
      :: body_rows ~width_of ~width ~capacity:(body_h - 1) ~book ~pace t
    in
    let rows = List.filteri (fun i _ -> i < body_h) rows in
    let rows = rows @ List.init (max 0 (body_h - List.length rows)) (fun _ -> (O.Plain, "")) in
    List.map
      (fun (style, text) -> (style, O.pad ~width_of width (O.clip_text ~width_of width text)))
      rows
    |> Ui_overlay.centered ~width_of ~screen ~body ~pane_width:width ~caret:`Bounded
  else
    let pane_w = min 96 (body_w - 4) and pane_h = body_h - 2 in
    let width = max 1 (pane_w - 2) in
    let footer =
      let assumption = " Plan only: assumes no income or new Scheduled before the target date."
      and writes = " No writes or reservations." in
      if width_of (assumption ^ writes) <= width then [ (O.Chrome, assumption ^ writes) ]
      else [ (O.Chrome, assumption); (O.Chrome, writes) ]
    in
    let capacity = max 0 (pane_h - 2 - List.length footer) in
    let rows = body_rows ~width_of ~width ~capacity ~book ~pace t in
    let rows = List.filteri (fun i _ -> i < capacity) rows in
    let rows = rows @ List.init (capacity - List.length rows) (fun _ -> (O.Plain, "")) @ footer in
    let rows =
      List.map
        (fun (style, text) ->
          (* The frame adds one border cell before the caret column. *)
          ( (match style with O.Input col -> O.Input (col + 1) | s -> s),
            O.clip_text ~width_of width text ))
        rows
    in
    Panel.frame_rows ~inset:0 ~width_of ~width:pane_w ~height:pane_h ~focused:true
      ~title:"Daily Pace / Target plan" rows
    |> Ui_overlay.centered ~width_of ~screen ~body ~pane_width:pane_w ~caret:`Bounded
