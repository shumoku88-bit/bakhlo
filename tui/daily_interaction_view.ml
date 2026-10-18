(* Workspace painting, overlay placement and terminal caret coordinates. *)
open Daily_interaction_state
open Daily_interaction_context

let row_title book = function
  | W.Actual_entry entry ->
      let amount =
        match entry.B.effects with
        | [ a; b ] when D.Identifier.Measure.equal (D.Effect.measure a) (D.Effect.measure b) ->
            let positive = if Z.sign (A.quanta a) > 0 then a else b in
            let measure = A.mstr (D.Effect.measure positive) in
            let amount = B.format book measure (A.quanta positive) in
            if String.length amount > 20 then tr "see details" else amount ^ " " ^ measure
        | _ -> tr "split / see details"
      in
      entry.day ^ "  " ^ Option.value ~default:"(no description)" entry.memo ^ "  " ^ amount
  | W.Scheduled_plan plan ->
      let total =
        List.fold_left
          (fun n (_, v) -> if Z.sign v > 0 then Z.add n v else n)
          Z.zero plan.changes
      in
      let status =
        if plan.paid_by <> None then "[Paid]"
        else if plan.cancelled_on <> None then "[Cancelled]"
        else "[Open]"
      in
      let amt = B.format book plan.measure total in
      plan.day ^ "  " ^ plan.id ^ "  " ^ amt ^ " " ^ plan.measure ^ "  " ^ status

let actual_amount book (entry : B.entry) =
  let format p =
    let measure = A.mstr (D.Effect.measure p) and quanta = A.quanta p in
    let amount = B.format book measure (Z.abs quanta) in
    let parts = String.split_on_char '.' amount in
    let whole = List.hd parts in
    let grouped = Buffer.create (String.length amount + 16) in
    String.iteri (fun i c ->
      if i > 0 && (String.length whole - i) mod 3 = 0 then Buffer.add_char grouped ',';
      Buffer.add_char grouped c) whole;
    (if Z.sign quanta < 0 then "-" else if Z.sign quanta > 0 then "+" else "")
    ^ Buffer.contents grouped
    ^ (match List.tl parts with [] -> "" | xs -> "." ^ String.concat "." xs)
    ^ " " ^ measure in
  let measures = List.sort_uniq String.compare
    (List.map (fun p -> A.mstr (D.Effect.measure p)) entry.effects) in
  let positive = List.filter (fun p -> Z.sign (A.quanta p) > 0) entry.effects
  and negative = List.filter (fun p -> Z.sign (A.quanta p) < 0) entry.effects in
  if List.length measures > 1 then Printf.sprintf "multi (%d)" (List.length measures)
  else if List.length positive > 1 || List.length negative > 1 then "split"
  else match positive, entry.effects with
    | p :: _, _ | [], [p] -> format p
    | [], [] -> "—"
    | [], _ -> "see details"

let actual_table ~width_of ~width book rows =
  let room = max 0 (width - 6) in
  let amount_width = min 22 (max 12 (List.fold_left (fun n row ->
    match row with W.Actual_entry e -> max n (width_of (actual_amount book e))
    | _ -> n) 0 rows)) in
  let table date description amount =
    if room < 40 then O.pad ~width_of room description
    else
      let amount = if width_of amount <= amount_width then amount else "see details" in
      O.pad ~width_of 10 date ^ "  "
      ^ O.pad ~width_of (room - 14 - amount_width) description ^ "  "
      ^ String.make (max 0 (amount_width - width_of amount)) ' ' ^ amount in
  let titles = List.map (function
    | W.Actual_entry e -> table e.day (Option.value ~default:"(no description)" e.memo)
        (actual_amount book e)
    | row -> row_title book row) rows in
  ("  " ^ table "Date" "Description" "Amount", titles)

let scheduled_table ~width_of ~width book rows =
  let room = max 0 (width - 8) in
  let plans = List.filter_map (function W.Scheduled_plan p -> Some p | _ -> None) rows in
  let amount_w =
    min 20
      (max 10
         (List.fold_left
            (fun n (p : B.plan) ->
              let total =
                List.fold_left
                  (fun acc (_, v) -> if Z.sign v > 0 then Z.add acc v else acc)
                  Z.zero p.changes
              in
              let amt_str = B.format book p.measure total ^ " " ^ p.measure in
              max n (width_of amt_str))
            0 plans))
  in
  let status_w = 11 in
  let row_line (p : B.plan) =
    let total =
      List.fold_left
        (fun n (_, v) -> if Z.sign v > 0 then Z.add n v else n)
        Z.zero p.changes
    in
    let status =
      if p.paid_by <> None then "[Paid]"
      else if p.cancelled_on <> None then "[Cancelled]"
      else "[Open]"
    in
    let amt = B.format book p.measure total ^ " " ^ p.measure in
    if room < 40 then
      O.clip_text ~width_of room (p.day ^ "  " ^ O.visible p.id ^ "  " ^ amt ^ "  " ^ status)
    else
      let id_w = max 6 (room - 10 - 2 - amount_w - 2 - status_w) in
      O.pad ~width_of 10 p.day ^ "  "
      ^ O.pad ~width_of id_w (O.visible p.id) ^ "  "
      ^ O.pad_left ~width_of amount_w amt ^ "  "
      ^ status
  in
  List.map (function
    | W.Scheduled_plan p -> row_line p
    | row -> row_title book row) rows
let calendar_rows ?(width = 80) state =
  let calendar = state.workspace.calendar and book = state.session.book in
  let actuals = B.entries book and scheduled = B.open_plans book in
  let count prefix =
    ( List.length (List.filter (fun (e : B.entry) -> String.starts_with ~prefix e.day) actuals),
      List.length (List.filter (fun (p : B.plan) -> String.starts_with ~prefix p.day) scheduled) )
  in
  let cell width value = value ^ String.make (max 0 (width - String.length value)) ' ' in
  let today = F.today () in
  let names =
    [| "Jan"; "Feb"; "Mar"; "Apr"; "May"; "Jun"; "Jul"; "Aug"; "Sep"; "Oct"; "Nov"; "Dec" |]
  in
  match calendar.Cal.zoom with
  | Cal.Day ->
      let room = max 0 (width - 6) in
      let compact = room < 49 in
      let cell_width = if room >= 49 then 7 else if room >= 35 then 5 else 3 in
      let slots = get (Cal.month_slots calendar.selected_day) in
      let rec weeks = function
        | [] -> []
        | xs ->
            let week = List.filteri (fun i _ -> i < 7) xs in
            let rest = List.filteri (fun i _ -> i >= 7) xs in
            let dates =
              List.map
                (function
                  | None -> String.make cell_width ' '
                  | Some day ->
                      let actual, planned = count day in
                      let dd = String.sub day 8 2 in
                      let chosen = day = calendar.selected_day in
                      let label = if chosen then "[" ^ dd ^ "]" else if compact then dd else " " ^ dd in
                      let today_mark =
                        if day = today && (not chosen || room >= (7 * cell_width) + 2) then "*"
                        else if compact && chosen then "" else " "
                      in
                      cell cell_width
                        (label ^ today_mark
                         ^ (if compact then "" else (if actual > 0 then "a" else " ") ^ (if planned > 0 then "s" else " "))))
                week
            in
            String.concat "" dates :: weeks rest
      in
      if room < 22 then
        [ "[" ^ String.sub calendar.selected_day 8 2 ^ "] " ^ calendar.selected_day ]
      else
      [ String.concat "" (List.map (cell cell_width)
            (if cell_width = 3 then [ "Mo"; "Tu"; "We"; "Th"; "Fr"; "Sa"; "Su" ]
             else [ "Mon"; "Tue"; "Wed"; "Thu"; "Fri"; "Sat"; "Sun" ])) ]
      @ weeks slots
      @ [ tr (if compact then "[ ] selected   * today" else "a Actual   s open Scheduled   * today") ]
  | Cal.Month ->
      let year = String.sub calendar.selected_day 0 4 in
      if width < 64 then
        List.init 12 (fun i ->
            let prefix = Printf.sprintf "%s-%02d" year (i + 1) in
            let actual, planned = count prefix in
            Printf.sprintf "%s%02d %s    A%d S%d"
              (if String.starts_with ~prefix calendar.selected_day then "> " else "  ")
              (i + 1) names.(i) actual planned)
      else List.init 4 (fun quarter ->
          List.init 3 (fun column ->
              let i = (quarter * 3) + column in
              let prefix = Printf.sprintf "%s-%02d" year (i + 1) in
              let actual, planned = count prefix in
              let label = Printf.sprintf "%02d %s" (i + 1) names.(i) in
              let label = if String.starts_with ~prefix calendar.selected_day then "[" ^ label ^ "]" else " " ^ label ^ " " in
              cell 19 (Printf.sprintf "%s A%d S%d" label actual planned))
          |> String.concat "")
      @ [ ""; tr "A Actual   S open Scheduled" ]
  | Cal.Year ->
      let year = int_of_string (String.sub calendar.selected_day 0 4) in
      List.init 5 (fun i -> year + i - 2)
      |> List.filter (fun y -> y >= 1 && y <= 9999)
      |> List.map (fun y ->
          let prefix = Printf.sprintf "%04d" y in
          let actual, planned = count prefix in
          Printf.sprintf "%s%s    A%d  S%d" (if y = year then "> " else "  ") prefix actual planned)

let pace_lines state =
  let measure = state.workspace.measure in
  match current_pace_result state with
  | Error why -> [ tr "Daily Pace unavailable (not zero):"; why;
      "Supply an explicit daily-pace.tsv pool and boundary-presets.tsv period.";
      "Historical Trend is unavailable." ]
  | Ok (pace, start_day, end_exclusive) ->
          let amount n = B.format state.session.book measure n ^ " " ^ measure in
          let total_period_days =
            let day_num y m d =
              let prior = y - 1 in
              let before = [| 0; 0; 31; 59; 90; 120; 151; 181; 212; 243; 273; 304; 334 |] in
              (prior * 365) + (prior / 4) - (prior / 100) + (prior / 400) + before.(m)
              + (if m > 2 && A.is_leap_year y then 1 else 0)
              + d - 1
            in
            match (Cal.parts start_day, Cal.parts end_exclusive) with
            | Ok (y1, m1, d1), Ok (y2, m2, d2) ->
                let j1 = day_num y1 m1 d1 and j2 = day_num y2 m2 d2 in
                max 1 (j2 - j1)
            | _ -> max 1 pace.remaining_days
          in
          let elapsed_days = max 0 (total_period_days - pace.remaining_days) in
          let progress_ratio = float_of_int elapsed_days /. float_of_int total_period_days in
          let bar = O.progress_bar ~width:28 ~ratio:progress_ratio in
          let pool_origin = "config/daily-pace.tsv" in
          let window_origin = "config/boundary-presets.tsv" in
          [
            Printf.sprintf "Daily Pace: %s / day" (amount pace.daily_pace_quanta);
            "";
            Printf.sprintf "Period progress: %s %d/%d days" bar elapsed_days total_period_days;
            Printf.sprintf "Through end: %s (Available)" (amount pace.available_through_end);
            Printf.sprintf "Days remaining: %d days  (Observed: %s -> End: %s)"
              pace.remaining_days pace.observed_at pace.end_exclusive;
            Printf.sprintf "Source: Pool [%s] | Window [%s]" pool_origin window_origin;
            "";
            "Eligible Pool:";
          ]
          @ (if pace.pool_balances = [] then [ "  (none)" ]
             else
               List.map
                 (fun (coordinate, n) ->
                   let locus = A.lstr coordinate.D.Effect_coordinate.locus in
                   let label = B.label state.session.book locus in
                   let name = if label <> "" && label <> locus then Printf.sprintf "%s [%s]" label locus else locus in
                   Printf.sprintf "  %-24s %s" name (amount n))
                 pace.pool_balances)
          @ [ ""; "Scheduled Deductions:" ]
          @ (if pace.plan_deductions = [] then [ "  (no upcoming deductions)" ]
             else
               List.map
                 (fun (id, n) -> Printf.sprintf "  %-24s -%s" ("Plan " ^ id) (amount n))
                 pace.plan_deductions)
          @ [ ""; "Net Pool: " ^ amount pace.eligible_pool;
              "Total Deductions: -" ^ amount pace.automatic_deductions ]



let workspace_rows ~width_of ~width ~height state =
  let draw_frame = Panel.frame in
  let book = state.session.book and workspace = state.workspace in
  let rows = W.rows ~book workspace in
  let titles = List.map (row_title book) rows in
  let title =
    match workspace.W.route with
    | W.Home -> "Home"
    | W.Calendar -> "Calendar / Month flow"
    | W.Selected_day day -> "Household Day Workspace / " ^ day
    | W.Actual -> "Actual"
    | W.Scheduled -> "Scheduled / List"
    | W.Balances ->
        (match state.balance_mode with
        | `Accounting -> "Balances / Accounting"
        | `Current -> "Balances / Current")
    | W.Daily_pace -> "Daily Pace"
    | W.Income_expense -> "Income & Expense"
    | W.Transactions_flow -> "Transactions Flow"
    | W.Stock_flow -> "Stock–Flow"
    | W.Attention -> "Attention / Household matters"
    | W.Loci -> "Manage Loci / Admitted vocabulary"
    | W.Settlements -> "Settlements / Reimbursements"
  in
  let pad rows = rows @ List.init (max 0 (height - List.length rows)) (fun _ -> (Plain, "")) in
  let split_pane ?left_heading ~left_focused ~left_title ~left_scroll ~left_selected ~left_rows
      ~right_focused ~right_title ~right_scroll ~right_selected ~right_rows () =
    if width >= 80 then
      let left_width, right_width = browser_pane_widths width in
      let left_panel =
        draw_frame ?heading:left_heading ~width_of ~width:left_width ~height ~focused:left_focused
          ~title:left_title ~scroll:left_scroll ~selected:left_selected left_rows
      in
      let right_panel =
        draw_frame ~width_of ~width:right_width ~height ~focused:right_focused
          ~title:right_title ~scroll:right_scroll ~selected:right_selected right_rows
      in
      pad (List.map2 (fun (style_l, text_l) (style_r, text_r) ->
          (Columns (left_width, style_l, style_r), text_l ^ " " ^ text_r)) left_panel right_panel)
    else
      if right_focused then
        draw_frame ~width_of ~width ~height ~focused:true
          ~title:right_title ~scroll:right_scroll ~selected:right_selected right_rows
      else
        draw_frame ~width_of ~width ~height ~focused:true
          ?heading:left_heading ~title:left_title ~scroll:left_scroll ~selected:left_selected left_rows
  in
  if annual_needs_history workspace.route && annual_unavailable state <> None then
    draw_frame ~width_of ~width ~height ~focused:true ~title:(title ^ " / Unavailable")
      ~scroll:0 ~selected:None
      [ "Annual file does not contain a qualified prior-year opening.";
        "Balances, Daily Pace and cross-year reports are unavailable.";
        Option.value ~default:"Opening evidence unavailable." (annual_unavailable state);
        "Actual entries and Scheduled records in this file remain inspectable.";
        "No zero opening or carried balance is inferred." ]
  else if workspace.route = W.Home then
    (match F.annual_notice state.session with
     | None -> O.bonsai_home_lines ~width ~height ~width_of ~today:(F.today ())
     | Some notice ->
         (Status, notice)
         :: O.bonsai_home_lines ~width ~height:(max 0 (height - 1))
              ~width_of ~today:(F.today ()))
  else if workspace.route = W.Calendar then
    let calendar_focused = workspace.pane = W.Calendar in
    let detail =
      let actual = List.length (List.filter (function W.Actual_entry _ -> true | _ -> false) rows) in
      let scheduled = List.length rows - actual in
      Printf.sprintf "Actual %d   Open Scheduled %d" actual scheduled
      :: (if titles = [] then [ tr "No records in this period." ] else titles)
      @ [ tr "Flow unavailable: classification not supplied." ]
    in
    let period =
      let n = match workspace.calendar.zoom with Cal.Day -> 10 | Cal.Month -> 7 | Cal.Year -> 4 in
      String.sub workspace.calendar.selected_day 0 n
    in
    let calendar_frame ~width ~height =
      let calendar = calendar_rows ~width state in
      let selected = match workspace.calendar.zoom with
        | Cal.Month when width < 64 -> Some (int_of_string (String.sub workspace.calendar.selected_day 5 2) - 1)
        | Cal.Year -> Some (min 2 (int_of_string (String.sub workspace.calendar.selected_day 0 4) - 1))
        | Cal.Day | Cal.Month -> None
      in
      let scroll =
        if workspace.calendar.zoom <> Cal.Day || state.scroll <> 0 then state.scroll
        else
          let first = String.sub workspace.calendar.selected_day 0 8 ^ "01" in
          let week =
            (get (Cal.weekday first) + int_of_string (String.sub workspace.calendar.selected_day 8 2) - 1) / 7
          in
          max 0 (1 + week - max 1 (height - 2) + 1)
      in
      let result = draw_frame ~width_of ~width ~height ~focused:calendar_focused
          ~title:("Calendar / " ^ String.sub workspace.calendar.selected_day 0 (if workspace.calendar.zoom = Cal.Day then 7 else 4))
          ~scroll ~selected calendar in
      let marker = "[" ^ String.sub workspace.calendar.selected_day 8 2 ^ "]" in
      List.map (fun (style, text) ->
          if calendar_focused && workspace.calendar.zoom = Cal.Day && style = Plain
             && Base.String.is_substring text ~substring:marker
          then (Calendar_dates, text) else (style, text)) result
    in
    let detail_frame ~width ~height =
      draw_frame ~width_of ~width ~height ~focused:(not calendar_focused)
        ~title:("Detail / " ^ period) ~scroll:0
        ~selected:(if rows = [] then None else Some ((W.browser workspace).selected + 1)) detail
    in
    if width >= 120 then
      let left = 64 and right = width - 65 in
      let natural = List.length (calendar_rows ~width:left state) + 2 in
      let pane_height = min height (max natural (min 12 (List.length detail + 2))) in
      let left_rows = calendar_frame ~width:left ~height:pane_height in
      let right_rows = detail_frame ~width:right ~height:pane_height in
      pad (List.map2 (fun (style, left_text) (right_style, right_text) ->
          (Columns (left, style, right_style), left_text ^ " " ^ right_text)) left_rows right_rows)
    else
      let natural = List.length (calendar_rows ~width state) + 2 in
      if width >= 72 && height >= natural + 6 then
        let calendar_height = natural in
        calendar_frame ~width ~height:calendar_height
        @ [ (Plain, "") ]
        @ detail_frame ~width ~height:(height - calendar_height - 1)
      else if calendar_focused then calendar_frame ~width ~height
      else detail_frame ~width ~height
  else if workspace.route = W.Balances then
    let items = balance_items state in
    (* A medium terminal needs room for complete quantities. Preserve the
       existing split view on wide screens and the focus-only view on tiny ones. *)
    let stacked = width >= 72 && width < 120 && height >= 18 in
    let list_width =
      if stacked then width
      else if width >= 80 then let left, _ = browser_pane_widths width in left
      else width
    in
    let lines = balance_lines ~width_of ~width:(max 0 (list_width - 6)) state in
    let detail =
      match List.nth_opt items workspace.balance_selected with
      | None -> [ tr "No supplied Locus / Measure coordinates." ]
      | Some item -> O.balance_item_detail ~book item
    in
    let right_width =
      if stacked then width
      else if width >= 80 then width - max 36 (min 58 (width * 52 / 100)) - 1
      else width
    in
    let wrapped_detail = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) detail in
    let is_detail = workspace.pane = W.Detail in
    if stacked then
      let list_height = height / 2 in
      draw_frame ~width_of ~width ~height:list_height
        ~focused:(not is_detail) ~title ~scroll:0
        ~selected:(if lines = [] then None else Some workspace.balance_selected)
        ?heading:(if lines = [] then Some "No balances are selected." else None)
        lines
      @ draw_frame ~width_of ~width ~height:(height - list_height)
          ~focused:is_detail ~title:"Selected Balance" ~scroll:state.scroll
          ~selected:None wrapped_detail
    else
      split_pane
        ?left_heading:(if lines = [] then Some "No balances are selected." else None)
        ~left_focused:(not is_detail) ~left_title:title ~left_scroll:0
        ~left_selected:(if lines = [] then None else Some workspace.balance_selected)
        ~left_rows:lines
        ~right_focused:is_detail ~right_title:"Selected Balance"
        ~right_scroll:state.scroll ~right_selected:None ~right_rows:wrapped_detail ()
  else if workspace.route = W.Daily_pace then
    let measure = workspace.measure in
    let trend_res = pace_samples state in
    let is_detail = workspace.pane = W.Detail in
    let left_width, right_width = browser_pane_widths width in
    match trend_res with
    | Ok (_, _, samples) ->
        let count = List.length samples in
        let selected_idx = max 0 (min (count - 1) state.pace_trend.selected_index) in
        let title = Printf.sprintf "Daily Pace / Trend • %s [%s]"
            (Trend.preset_label state.pace_trend.preset)
            (Trend.graph_style_label state.pace_trend.graph_style) in
        let wide = width >= 80 && height >= 15 in
        let lower_height =
          if height >= 15 then max 7 (height / 2)
          else if height >= 9 then 3 else 0 in
        let detail_width = if is_detail then width
          else if wide then min 60 (max 30 (width * 40 / 100)) else width in
        let detail_height = if wide then lower_height else 0 in
        let history_width = if wide then width - detail_width - 1 else width in
        let history_height = lower_height in
        let detail_panel ~height =
          let detail_rows = pace_sample_detail ~width_of ~width:detail_width state samples in
          draw_frame ~width_of ~width:detail_width ~height ~focused:is_detail
            ~title:"Selected day" ~scroll:state.scroll ~selected:None detail_rows
        in
        if is_detail then detail_panel ~height
        else
          let chart_height = height - lower_height in
          let chart =
            Trend.render_chart ~width:(max 0 (width - 6))
              ~height:(Panel.capacity ~height:chart_height ~heading:false)
              ~width_of ~book ~today:(F.today ()) ~measure ~samples
              ~selected_index:selected_idx ~graph_style:state.pace_trend.graph_style
            |> Panel.frame_rows ~width_of ~width ~height:chart_height
                 ~focused:(not is_detail) ~title
          in
          let history =
            Trend.render_history ~width:(max 0 (history_width - 6))
              ~height:(Panel.capacity ~height:history_height ~heading:false)
              ~width_of ~book ~measure ~samples ~selected_index:selected_idx
            |> Panel.frame_rows ~width_of ~width:history_width ~height:history_height
                 ~focused:(not is_detail) ~title:"History"
          in
          let lower =
            if wide then
              List.map2
                (fun (left_style, left_text) (right_style, right_text) ->
                  (Columns (history_width, left_style, right_style), left_text ^ " " ^ right_text))
                history (detail_panel ~height:detail_height)
            else history @ (if detail_height = 0 then [] else detail_panel ~height:detail_height)
          in
          chart @ lower
    | Error why ->
        if is_detail then
          draw_frame ~width_of ~width ~height ~focused:true ~title:"Pace Detail & Evidence"
            ~scroll:state.scroll ~selected:None
            (List.concat_map (O.wrap_text ~width_of (max 1 (width - 6))) (pace_detail_lines state))
        else
        let left_title = Printf.sprintf "Daily Pace / %s" (Trend.preset_label state.pace_trend.preset) in
        let right_title = "Pace Detail & Evidence" in
        let left_rows =
          List.concat_map (O.wrap_text ~width_of (max 1 (left_width - 6)))
            [
              tr "Daily Pace unavailable:";
              why;
              "Supply an explicit daily-pace.tsv pool and boundary-presets.tsv period.";
            ]
        in
        let right_rows = pace_detail_lines state in
        let wrapped_detail = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) right_rows in
        split_pane
          ~left_focused:(not is_detail) ~left_title ~left_scroll:0
          ~left_selected:None ~left_rows
          ~right_focused:is_detail ~right_title
          ~right_scroll:(if is_detail then state.scroll else 0)
          ~right_selected:None ~right_rows:wrapped_detail ()
  else if workspace.route = W.Income_expense then
    let period_res = checked_report_period state state.income_expense.preset state.income_expense.period_offset in
    let is_detail = workspace.pane = W.Detail in
    let left_width, right_width = browser_pane_widths width in
    match period_res with
    | Ok period ->
        let roles = accounting_roles state in
        let rep = IncExp.compute_report ~book:state.session.book ~roles ~period in
        let left_title = Printf.sprintf "Income & Expense • %s" (IncExp.preset_label state.income_expense.preset) in
        let right_title = "Report Details & Formulas" in
        let left_rows = List.map snd (IncExp.render_report_lines ~width:(max 0 (left_width - 4)) ~width_of ~book:state.session.book ~report:rep) in
        let detail_rows = List.map snd (IncExp.render_detail_lines ~width:(max 0 (right_width - 6)) ~width_of ~book:state.session.book ~report:rep ~selected_row:0) in
        let wrapped_detail = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) detail_rows in
        split_pane
          ~left_focused:(not is_detail) ~left_title ~left_scroll:(if not is_detail then state.scroll else 0)
          ~left_selected:None ~left_rows
          ~right_focused:is_detail ~right_title
          ~right_scroll:(if is_detail then state.scroll else 0)
          ~right_selected:None ~right_rows:wrapped_detail ()
    | Error why ->
        let left_title = "Income & Expense" in
        let right_title = "Period Unavailable" in
        let left_rows = [ tr "Report period unavailable:"; why; "Supply an explicit boundary-presets.tsv or choose Month / Year." ] in
        let wrapped_left = List.concat_map (O.wrap_text ~width_of (max 1 (left_width - 6))) left_rows in
        split_pane
          ~left_focused:(not is_detail) ~left_title ~left_scroll:0
          ~left_selected:None ~left_rows:wrapped_left
          ~right_focused:is_detail ~right_title
          ~right_scroll:0 ~right_selected:None ~right_rows:[ why ] ()
  else if workspace.route = W.Transactions_flow then
    let period_res = checked_report_period state state.transactions_flow.preset state.transactions_flow.period_offset in
    let is_detail = workspace.pane = W.Detail in
    let left_width, right_width = browser_pane_widths width in
    match period_res with
    | Ok period ->
        let rep = Flow.compute_report ~book:state.session.book ~period in
        let selected_row = min (max 0 (List.length rep.rows - 1)) state.transactions_flow.selected_row in
        let left_title = Printf.sprintf "Transactions Flow • %s" (IncExp.preset_label state.transactions_flow.preset) in
        let right_title = "Flow Detail & Transactions" in
        let left_rows = List.map snd (Flow.render_summary_lines ~width:(max 0 (left_width - 4)) ~width_of ~book:state.session.book ~report:rep ~selected_row) in
        let detail_rows = List.map snd (Flow.render_detail_lines ~width:(max 0 (right_width - 6)) ~width_of ~book:state.session.book ~report:rep ~selected_row) in
        let wrapped_detail = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) detail_rows in
        split_pane
          ~left_focused:(not is_detail) ~left_title ~left_scroll:(if not is_detail then state.scroll else 0)
          ~left_selected:None ~left_rows
          ~right_focused:is_detail ~right_title
          ~right_scroll:(if is_detail then state.scroll else 0)
          ~right_selected:None ~right_rows:wrapped_detail ()
    | Error why ->
        let left_title = "Transactions Flow" in
        let right_title = "Period Unavailable" in
        let left_rows = [ tr "Report period unavailable:"; why; "Supply an explicit boundary-presets.tsv or choose Month / Year." ] in
        let wrapped_left = List.concat_map (O.wrap_text ~width_of (max 1 (left_width - 6))) left_rows in
        split_pane
          ~left_focused:(not is_detail) ~left_title ~left_scroll:0
          ~left_selected:None ~left_rows:wrapped_left
          ~right_focused:is_detail ~right_title
          ~right_scroll:0 ~right_selected:None ~right_rows:[ why ] ()
  else if workspace.route = W.Stock_flow then
    let rep_res = stock_flow_result state in
    let is_detail = workspace.pane = W.Detail in
    let left_width, right_width = browser_pane_widths width in
    match rep_res with
    | Ok rep ->
        let left_title = Printf.sprintf "Stock–Flow • %s (%s)" (IncExp.preset_label state.stock_flow.preset) rep.measure in
        let right_title = "Principles & Evidence" in
        let left_rows = List.map snd (StockFlow.render_summary_lines ~width:(max 0 (left_width - 4)) ~width_of ~book:state.session.book ~report:rep) in
        let detail_rows = List.map snd (StockFlow.render_detail_lines ~width:(max 0 (right_width - 6)) ~width_of ~book:state.session.book ~report:rep) in
        let wrapped_detail = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) detail_rows in
        split_pane
          ~left_focused:(not is_detail) ~left_title ~left_scroll:(if not is_detail then state.scroll else 0)
          ~left_selected:None ~left_rows
          ~right_focused:is_detail ~right_title
          ~right_scroll:(if is_detail then state.scroll else 0)
          ~right_selected:None ~right_rows:wrapped_detail ()
    | Error why ->
        let left_title = "Stock–Flow" in
        let right_title = "Stock–Flow Unavailable" in
        let left_rows = [ tr "Stock–Flow unavailable:"; why; "Review balance coordinates and boundary presets." ] in
        let wrapped_left = List.concat_map (O.wrap_text ~width_of (max 1 (left_width - 6))) left_rows in
        split_pane
          ~left_focused:(not is_detail) ~left_title ~left_scroll:0
          ~left_selected:None ~left_rows:wrapped_left
          ~right_focused:is_detail ~right_title
          ~right_scroll:0 ~right_selected:None ~right_rows:[ why ] ()
  else if workspace.route = W.Attention then
    let items = open_attentions state in
    let left_title = match state.attention with
      | Ok t ->
          let s = Att.summarize ~today:(F.today ()) t in
          if s.overdue_count > 0 then
            Printf.sprintf "Attention (%d open • ! %d overdue)" (List.length items) s.overdue_count
          else
            Printf.sprintf "Attention (%d open)" (List.length items)
      | Error _ -> "Attention / Unavailable" in
    let right_title = "Selected matter" in
    let left_width, right_width = browser_pane_widths width in
    let pad_w = max 0 (left_width - 4) in
    let col_due = 14 in
    let col_ctx = max 16 (pad_w - col_due - 4) in
    let th = "  " ^ O.pad ~width_of col_due "Due" ^ "  " ^ O.pad ~width_of col_ctx "Matter / Context" in
    let rule = O.rule ~width_of pad_w in
    let left_rows = match state.attention with
      | Error why -> O.wrap_text ~width_of (max 1 (left_width - 6))
          ("Attention unavailable: " ^ why ^ ". Writes refused; Ctrl-R reloads.")
      | Ok _ ->
          if items = [] then [ tr "No open attention items." ]
          else
            [ th; rule ]
            @ List.mapi
                (fun idx (item : Att.item) ->
                  let is_sel = idx = workspace.attention.selected in
                  let marker = if is_sel then "> " else "  " in
                  let due_text = Att.due_display ~today:(F.today ()) item.due in
                  let line = marker ^ O.pad ~width_of col_due due_text ^ "  " ^ item.context in
                  line)
                items
    in
    let detail =
      match state.attention, selected_attention state with
      | Error why, _ -> [ "Attention unavailable (not empty)."; why; "Writes refused; Ctrl-R reloads." ]
      | Ok _, None -> [ tr "No selected attention item."; ""; tr "Press 'n' to add a household matter." ]
      | Ok _, Some item ->
          let urgency_str =
            match item.due with
            | Att.Due_on d ->
                if d < F.today () then Printf.sprintf "! OVERDUE (due %s, today %s)" d (F.today ())
                else if d = F.today () then "DUE TODAY"
                else Printf.sprintf "Due on %s" d
            | Att.No_due_date -> "No due date specified"
            | Att.Due_undetermined -> "Due date undetermined / timing unknown"
          in
          [
            "Matter / Description:";
            "  " ^ item.context;
            "";
            "Urgency / Due:";
            "  " ^ urgency_str;
            "";
            "Item ID:    " ^ item.id;
            "Lifecycle:  Open (unresolved)";
            "";
            "Actions:";
            "  n : Add new attention item";
            "  r : Resolve this item (record completed)";
            "  x : Drop this item (abandon/cancel)";
            "";
            "Navigation:";
            "  Tab / i : Toggle detail scroll";
            "  j / k   : Select next/previous matter";
            "  q / Esc : Return to Home";
          ]
    in
    let wrapped_detail = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) detail in
    let is_detail = workspace.pane = W.Detail in
    split_pane
      ~left_focused:(not is_detail) ~left_title ~left_scroll:0
      ~left_selected:(if items = [] then None else Some (workspace.attention.selected + 2))
      ~left_rows
      ~right_focused:is_detail ~right_title
      ~right_scroll:(if is_detail then state.scroll else 0)
      ~right_selected:None ~right_rows:wrapped_detail ()
  else if workspace.route = W.Loci then
    let loci = admitted_loci state in
    let roles = accounting_roles state in
    let left_title = Printf.sprintf "Manage Loci (%d admitted)" (List.length loci) in
    let right_title = "Locus Detail" in
    let locus_line locus =
      let label = B.label book locus in
      let role_opt = List.assoc_opt locus roles in
      let role_tag =
        match role_opt with
        | Some r -> "[" ^ Roles.role_label r ^ "]"
        | None -> "[--]"
      in
      if label <> "" && label <> locus then
        Printf.sprintf "%-18s  %-12s  %s" locus role_tag label
      else
        Printf.sprintf "%-18s  %-12s" locus role_tag
    in
    let left_rows =
      if loci = [] then [ tr "No admitted loci in this book." ]
      else List.map locus_line loci
    in
    let detail =
      match selected_locus state with
      | None -> [ tr "No selected locus."; ""; tr "Press 'n' to admit a new coordinate token." ]
      | Some locus ->
          let label = B.label book locus in
          let role_opt = List.assoc_opt locus roles in
          let role_str = match role_opt with None -> "None / Unassigned" | Some r -> Roles.role_label r in
          let balances =
            if annual_unavailable state <> None then
              [ "  Unavailable: prior-year opening evidence is not connected." ]
            else
              List.map (fun (m, _) ->
                let q = O.quantity ~book ~measure:m locus in
                Printf.sprintf "  %s: %s" (String.uppercase_ascii m) q)
                (B.measures book)
          in
          [
            "Locus Token:      " ^ locus;
            "Display Label:    " ^ (if label <> "" then label else "(same as token)");
            "Accounting Role:  " ^ role_str;
            "";
            "Current Balances:";
          ]
          @ (if balances = [] then [ "  (no measures)" ] else balances)
          @ [
            "";
            "Role Impact:";
            (match role_opt with
             | Some Roles.Asset -> "  Asset: Positive balance represents owned resources."
             | Some Roles.Liability -> "  Liability: Positive balance represents debt owed."
             | Some Roles.Equity -> "  Equity: Capital / opening balance baseline."
             | Some Roles.Income -> "  Income: Inflow tracking for reporting."
             | Some Roles.Expense -> "  Expense: Outflow tracking for reporting."
             | None -> "  Unassigned: Available for general posting; excluded from role summaries.");
            "";
            "Actions:";
            "  n : Admit new Locus token";
            "  r : Set / change accounting role";
          ]
    in
    let right_width = if width >= 80 then width - max 36 (min 58 (width * 52 / 100)) - 1 else width in
    let wrapped_detail = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) detail in
    let is_detail = workspace.pane = W.Detail in
    split_pane
      ~left_focused:(not is_detail) ~left_title ~left_scroll:0
      ~left_selected:(if loci = [] then None else Some workspace.loci.selected)
      ~left_rows
      ~right_focused:is_detail ~right_title
      ~right_scroll:state.scroll ~right_selected:None ~right_rows:wrapped_detail ()
  else if workspace.route = W.Settlements then
    let rows = settlement_rows state in
    let scope_label = match state.settlement_scope with Stl.Open_only -> "Open" | Stl.All -> "All current" in
    let left_title = match state.settlements with
      | Ok _ -> Printf.sprintf "Settlements [%s] (%d)" scope_label (List.length rows)
      | Error _ -> "Settlements / Unavailable" in
    let right_title = "Commitment Details" in
    let row_line r =
      let desc = match r.Stl.label with Some l -> l | None -> r.id in
      let rem = Stl.outstanding r in
      let status = if Z.equal rem Z.zero then "done" else "" in
      let trunc_desc = if String.length desc > 22 then String.sub desc 0 19 ^ "..." else desc in
      Printf.sprintf "%-22s  %10s %-4s %s" trunc_desc (Z.to_string rem) r.measure status
    in
    let left_rows = match state.settlements with
      | Error why -> O.wrap_text ~width_of (max 1 (width / 2 - 6))
          ("Settlements unavailable: " ^ why ^ ". Writes refused; Ctrl-R reloads.")
      | Ok _ -> if rows = [] then [ tr "  (no commitments in this scope)" ] else List.map row_line rows
    in
    let detail =
      match state.settlements, selected_settlement state with
      | Error why, _ -> [ "Settlements unavailable (not empty)."; why; "Writes refused; Ctrl-R reloads." ]
      | Ok _, None -> [ tr "No selected commitment."; ""; tr "Press 'n' to add a new settlement commitment." ]
      | Ok _, Some r ->
          let rem = Stl.outstanding r in
          let desc = match r.label with Some l -> l | None -> "(no description)" in
          let effective = match r.effective_on with Some d -> d | None -> "(date unknown)" in
          [
            "Identity:    " ^ r.id;
            "Description: " ^ desc;
            "Direction:   " ^ r.debtor ^ " -> " ^ r.creditor;
            "Measure:     " ^ r.measure;
            "Committed:   " ^ Z.to_string r.committed ^ " " ^ r.measure;
            "Settled:     " ^ Z.to_string r.settled ^ " " ^ r.measure;
            "Adjusted:    " ^ Z.to_string r.extinguished ^ " " ^ r.measure;
            "Remaining:   " ^ Z.to_string rem ^ " " ^ r.measure;
            "Effective:   " ^ effective;
            "";
            "Allocations:";
            (if Z.gt r.settled Z.zero then Printf.sprintf "  Settled payment: %s %s" (Z.to_string r.settled) r.measure else "  Direct settlement: (none)");
            (if Z.gt r.extinguished Z.zero then Printf.sprintf "  Non-payment reduction: %s %s" (Z.to_string r.extinguished) r.measure else "  Reductions: (none)");
            "";
            "Actions:";
            "  a / Enter : Settlement action (Settle / Reduce / Retract)";
            "  s         : Cycle scope (Open only <-> All current)";
            "  n         : Add new settlement commitment";
          ]
    in
    let right_width = if width >= 80 then width - max 36 (min 58 (width * 52 / 100)) - 1 else width in
    let wrapped_detail = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) detail in
    let is_detail = workspace.pane = W.Detail in
    split_pane
      ~left_focused:(not is_detail) ~left_title ~left_scroll:0
      ~left_selected:(if rows = [] then None else Some workspace.settlements.selected)
      ~left_rows
      ~right_focused:is_detail ~right_title
      ~right_scroll:state.scroll ~right_selected:None ~right_rows:wrapped_detail ()
  else if workspace.route = W.Actual then
    Act.screen ~book:state.session.book ~dimensions:(width, height) ~width_of state.actual_workspace
  else if is_scheduled_months state then
    if workspace.pane = W.Detail then
      let detail = browser_detail_rows ~width_of ~width state in
      Panel.frame ~width_of ~width ~height ~focused:true ~title:"Selected Scheduled"
        ~scroll:state.scroll ~selected:None detail
    else
      let plans = List.filter_map (function W.Scheduled_plan p -> Some p | _ -> None) rows in
      let selected = match selected state with Some (W.Scheduled_plan p) -> Some p | _ -> None in
      Months.screen ~book ~plans ~dimensions:(width, height) ~width_of ~selected workspace.months
  else
    let is_detail = workspace.pane = W.Detail in
    let right_title =
      match workspace.route with
      | W.Scheduled -> "Plan Detail"
      | _ -> "Selected Record"
    in

    let left_width, right_width = browser_pane_widths width in
    let wrapped_detail = browser_detail_rows ~width_of ~width:right_width state in
    let list_title =
      match workspace.route with
      | W.Scheduled -> Printf.sprintf "Scheduled / List (%d)" (List.length rows)
      | W.Selected_day day -> Printf.sprintf "Day %s (%d)" day (List.length rows)
      | _ -> title
    in
    let left_rows =
      if rows = [] then [ tr "No records in this view." ]
      else match workspace.route with
      | W.Scheduled -> scheduled_table ~width_of ~width:left_width book rows
      | W.Selected_day _ ->
          let _, ts = actual_table ~width_of ~width:left_width book rows in
          ts
      | _ -> titles
    in
    split_pane
      ~left_focused:(not is_detail) ~left_title:list_title
      ~left_scroll:(if is_detail then 0 else state.scroll)
      ~left_selected:(if titles = [] then None else Some (W.browser workspace).selected)
      ~left_rows
      ~right_focused:is_detail ~right_title
      ~right_scroll:(if is_detail then state.scroll else 0)
      ~right_selected:None ~right_rows:wrapped_detail ()

let footer ?(dimensions = (80, 24)) ?(width_of = String.length) state =
  match state.overlay with
  | Balance_picker _ -> [ "j/k select  Space toggle  Enter review"; "Esc/q cancel; unknown stays '?'  no write until confirmed" ]
  | (Reversal _ | Date_correction _ | Scheduled_cancel _ | Event_merchant _) when state.blocked ->
      [ "Writes stopped; date retained"; "Ctrl-r inspect/reload  q keep" ]
  | Reversal editor -> Rev.footer editor
  | Date_correction editor -> Date.footer editor
  | Event_merchant editor -> Merchant.footer editor
  | Scheduled_create editor -> Sch.footer editor
  | Scheduled_cancel editor -> Cancel.footer editor
  | Scheduled_continuation prompt -> Cont.footer prompt
  | Scheduled_bulk _ when state.blocked ->
      [ "Writes stopped; batch retained"; "Ctrl-r inspect/reload  Esc cancel" ]
  | Scheduled_bulk editor -> Bulk.footer editor
  | Scheduled_generate _ when state.blocked ->
      [ "Writes stopped; generation retained"; "Ctrl-r inspect/reload  Esc cancel" ]
  | Scheduled_generate editor -> Gen.footer editor
  | Themes _ -> [ "j/k or Up/Down preview theme"; "Enter save  Esc/q cancel" ]
  | Modal_form form -> (
      match Form.id form with
      | "balance_print_preview" | "balance_print_refused" ->
          [ "PgUp/Dn scroll  Home/End  Enter/Esc close"; "Preview only; no terminal output or book write" ]
      | "discard_record" ->
          [ "Left/Right choose  Enter confirm  Esc keep";
            "Keep draft is the protective default; no book write" ]
      | "observe_quantity" ->
          [ "Enter next/Add  Tab fields  Left/Right action"; "Add observed rows together, then Preview; Esc cancels" ]
      | "observe_preview" ->
          [ "Left/Right choose  Enter confirm  e edit  Esc cancel"; "Full image must fit before Publish; no partial save" ]
      | "daily_pace_what_if" ->
          [ "Enter simulate scenario  Tab switch field/button  Esc close"; "Read-only simulation - does not publish any entries" ]
      | "configure_daily_pace" ->
          [ "Enter review  Tab switch field  Esc cancel"; "Edits only daily-pace.tsv" ]
      | "review_pool" ->
          [ "Enter save  Tab choose Edit  Esc edit"; "Full pool must fit before saving" ]
      | "configure_cycle_boundaries" ->
          [ "Enter review  Tab switch field  Esc cancel"; "Edits only boundary-presets.tsv" ]
      | "review_cycle_boundaries" ->
          [ "Enter save  Tab choose Edit  Esc edit"; "Full boundaries must fit before saving" ]
      | "review_balance_view" ->
          [ "Enter save  Tab choose Edit  Esc edit"; "Full selection must fit before saving" ]
      | _ ->
          [ "Enter submit  Tab next field  Esc cancel"; "Arrow keys / space to choose options" ])
  | No_overlay | Commands _ | Jump _ | Search _ ->
  if state.workspace.W.route = W.Actual then
    Act.footer ~dimensions ~width_of state.actual_workspace
  else if is_scheduled_months state then
    if state.workspace.pane = W.Detail then
      [ "j/k PgUp/Dn Home/End scroll  Tab Months"; "Enter/c complete  g generate  b batch  x cancel  v List  q back" ]
    else if fst dimensions < 46 then
      [ "j/k select  h/l months  v List"; "Enter complete  x cancel  q back" ]
    else
      [ "j/k select  h/l months  Enter/c complete  q back";
        "i/Tab detail  b batch  r/e edit  g generate  x cancel  n new  v List" ]
  else
  match (state.workspace.W.route, state.workspace.pane) with
  | W.Home, _ ->
      let attn_badge =
        match state.attention with
        | Ok t -> Att.badge (Att.summarize ~today:(F.today ()) t)
        | Error _ -> ""
      in
      [
        " [Enter] calendar   [i] attention" ^ attn_badge;
        " [Space] commands   [q] quit";
      ]
  | W.Calendar, W.Calendar ->
      [
        (match state.workspace.calendar.zoom with
         | Cal.Day -> "h/l day  j/k week  Enter open  z zoom  / jump  t today"
         | Cal.Month -> "h/l month  j/k quarter  Enter days  z zoom  / jump  t today"
         | Cal.Year -> "h/l/j/k year  Enter months  z zoom  / jump  t today");
        "q/Esc Home  Tab/w Detail  r Record  Space Commands  a/s/b/d views";
      ]
  | W.Calendar, W.Detail ->
      [
        "q/Esc Calendar  j/k select  Enter Selected Day  Tab/w pane";
        "r Record  Space Commands  a/s/b/d views";
      ]
  | W.Scheduled, W.Calendar ->
      [
        "j/k select  Enter/i/Tab Detail  h/l pane  c Complete  e Edit  g Generate  x Cancel";
        "b Batch amount  v Months  n New Plan  f Filter  / search  Space Commands  q/Esc Home";
      ]
  | W.Actual, W.Calendar ->
      [
        "j/k select  Enter/i/Tab Detail  h/l pane  c Correct  x Reverse  f Day/All  s Order";
        "n Record  / search  Space Commands  q/Esc Home  Ctrl-r reload";
      ]
  | W.Scheduled, W.Detail ->
      [
        "j/k scroll  Page Up/Down page  Home/End range  h/l/Tab pane";
        "b Batch amount  v Months  q/Esc list  c Complete  e Edit  g Generate  x Cancel  n New Plan  Ctrl-r reload";
      ]
  | W.Actual, W.Detail ->
      [
        "j/k scroll  Page Up/Down page  Home/End range  h/l/Tab pane";
        "q/Esc list  c Correct  x Reverse  n Record  / search  Ctrl-r reload";
      ]
  | W.Selected_day _, W.Calendar ->
      [
        "j/k select  Enter/i/Tab Detail  c Correct  d Date  x Reverse  m Merchant  e Extend  b Batch  g Loci  r Record";
        (match state.drill_parent with
         | Some W.Actual -> "Space Commands  q/Esc Actual  Ctrl-r reload"
         | _ -> "Space Commands  q/Esc Home  Ctrl-r reload");
      ]
  | W.Balances, W.Calendar ->
      if fst dimensions < 64 then
        [ "j/k select  i detail  v mode"; "c setup  o observe  p print  q" ]
      else
      let v_label = match state.balance_mode with `Accounting -> "v current" | `Current -> "v accounting" in
      [
        Printf.sprintf "j/k select  Enter/i Detail  c visible accounts  o observe  %s  p print" v_label;
        "PgUp/Dn Home/End range  Space Commands  q/Esc Home  Ctrl-r reload";
      ]
  | W.Balances, W.Detail ->
      if fst dimensions < 64 then
        [ "j/k scroll PgUp/Dn Home/End"; "Tab list  o observe  p print  q" ]
      else
      [
        "j/k scroll  PgUp/Dn Home/End  Tab/w list  c visible accounts  o observe";
        "q/Esc back to list  Space Commands  Ctrl-r reload";
      ]
  | W.Daily_pace, W.Calendar ->
      if fst dimensions < 64 then
        [ "h/l day  i detail  1-5 period"; "w what-if  v style  q back" ]
      else
        [ "1-5 period  h/l day  v style  Tab/i detail  w what-if";
          "PgUp/Dn Home/End  c pool  b cycle  Space Commands  q back" ]
  | W.Daily_pace, W.Detail ->
      if fst dimensions < 64 then
        [ "j/k scroll  h/l day  Tab trend"; "PgUp/Dn Home/End  q back" ]
      else
        [ "j/k PgUp/Dn Home/End scroll  h/l day  Tab/i timeline";
          "w what-if  c pool  b cycle  q/Esc timeline" ]
  | W.Income_expense, W.Calendar ->
      [ "1-5 period  [ / ] shift  p print  Tab detail  r Record"; "Space Commands  q/Esc Home  Ctrl-r reload" ]
  | W.Income_expense, W.Detail ->
      [ "j/k scroll  Tab report  p print  q/Esc back to report  r Record"; "Space Commands  Ctrl-r reload" ]
  | W.Transactions_flow, W.Calendar ->
      [ "1-5 period  [ / ] shift  j/k row  p print  Tab detail  r Record"; "Space Commands  q/Esc Home  Ctrl-r reload" ]
  | W.Transactions_flow, W.Detail ->
      [ "j/k scroll  Tab report  p print  q/Esc back to report  r Record"; "Space Commands  Ctrl-r reload" ]
  | W.Stock_flow, W.Calendar ->
      [ "1-5 period  [ / ] shift  p print  Tab detail  r Record"; "Space Commands  q/Esc Home  Ctrl-r reload" ]
  | W.Stock_flow, W.Detail ->
      [ "j/k scroll  Tab report  p print  q/Esc back to report  r Record"; "Space Commands  Ctrl-r reload" ]
  | W.Attention, W.Calendar ->
      [
        "n new  r resolve  x drop  j/k select  Enter/Tab detail";
        "q/Esc Home  Space Commands  Ctrl-r reload";
      ]
  | W.Attention, W.Detail ->
      [
        "j/k scroll  Tab list  n new  r resolve  x drop";
        "q/Esc back to list  Space Commands  Ctrl-r reload";
      ]
  | W.Loci, _ ->
      [
        "n admit locus  r set role  j/k select  Enter/Tab detail";
        "q/Esc Home  Space Commands  Ctrl-r reload";
      ]
  | W.Settlements, _ ->
      [
        "n add  a action  s scope  j/k select  Enter/Tab detail";
        "q/Esc Home  Space Commands  Ctrl-r reload";
      ]
  | _, _ ->
      [
        "j/k scroll  Page Up/Down page  Home/End range"; "q/Esc back  Space Commands  Ctrl-r reload";
      ]

let rec screen ?(width_of = String.length) ((width, height) as dimensions) state =
  let feedback = feedback_lines ~dimensions ~width_of state in
  let usable = max 0 (height - List.length feedback) in
  if state.record_visible then
    match state.record with
    | Some record ->
        let pane_dimensions = record_dimensions ~dimensions ~width_of state in
        let rows = S.screen ~book:state.session.book ~dimensions:pane_dimensions ~width_of record in
        let pane_height = snd pane_dimensions in
        let body = List.filteri (fun i _ -> i < max 0 (pane_height - 2)) rows in
        let help = List.filteri (fun i _ -> i >= max 0 (pane_height - 2)) rows in
        if pane_dimensions = (width, usable) then body @ feedback @ help
        else
          let parent = screen ~width_of dimensions { state with record_visible = false } in
          List.filteri (fun i _ -> i < max 0 (height - 2)) parent
          @ List.map (fun (style, text) -> line ~width_of width style text) help
    | None -> List.init height (fun _ -> (Plain, ""))
  else
    let body_height = max 0 (height - List.length feedback - 2) in
    let headers =
      if state.workspace.route = W.Home then []
      else if state.workspace.route = W.Actual then
        [
          line ~width_of width Heading
            (tr "Bakhlo" ^ "  /  " ^ tr "Actual" ^ "  |  "
            ^ Act.scope_text state.actual_workspace ^ "  |  "
            ^ Act.current_locus_name ~book:state.session.book state.actual_workspace);
          (if Act.search_editing state.actual_workspace || Act.search_query state.actual_workspace <> "" then
             let style, text = Act.search_line ~width ~width_of state.actual_workspace in
             line ~width_of width style text
           else
             line ~width_of width Chrome
               (state.workspace.calendar.selected_day ^ "   "
                ^ Cal.title state.workspace.calendar ^ tr " view"
                ^ if has_record_draft state then "   Draft retained" else ""));
        ]
      else
        [
          line ~width_of width Heading
            (tr "Bakhlo" ^ "  /  " ^ (match state.workspace.route with
             | W.Home -> tr "Home"
             | W.Calendar -> tr "Calendar"
             | W.Actual -> tr "Actual"
             | W.Scheduled -> tr (if is_scheduled_months state then "Scheduled / Months" else "Scheduled")
             | W.Selected_day _ -> tr "Selected Day"
             | W.Balances -> tr "Balances"
             | W.Daily_pace -> tr "Daily Pace"
             | W.Attention -> tr "Attention"
             | W.Loci -> tr "Manage Loci"
             | W.Income_expense -> tr "Income & Expense"
             | W.Transactions_flow -> tr "Transactions Flow"
             | W.Stock_flow -> tr "Stock–Flow"
             | W.Settlements -> tr "Settlements"));
          line ~width_of width Chrome
            ((if is_scheduled_months state then "Explicit current-open plans; no recurrence inferred."
              else match state.workspace.route with
                | W.Selected_day day -> day ^ "   " ^ tr "Day" ^ tr " view"
                | W.Daily_pace ->
                    (match current_pace_result state with
                     | Error _ -> "Today: unavailable (not zero)"
                     | Ok (pace, _, _) ->
                         let text = "Today: " ^ O.format_money state.session.book pace.measure
                             pace.daily_pace_quanta ^ " " ^ pace.measure ^ "/day" in
                         if width_of text <= width then text else "Today: End, then i for full value")
                | _ -> state.workspace.calendar.selected_day ^ "   " ^ Cal.title state.workspace.calendar ^ tr " view")
            ^ if has_record_draft state then "   Draft retained" else "");
        ]
    in
    let header_count = List.length headers in
    let body =
      headers
      @ workspace_rows ~width_of ~width ~height:(max 0 (body_height - header_count)) state
    in
    let visible_body = List.filteri (fun i _ -> i < body_height) body in
    let bottom_pad = max 0 (body_height - List.length visible_body) in
    let full_body = visible_body @ List.init bottom_pad (fun _ -> (Plain, "")) in
    full_body @ feedback @ List.map (line ~width_of width Chrome) (footer ~dimensions ~width_of state)

let commands_overlay_rows ~width_of ~width ~height (menu : M.t) =
  let framed = height >= 5 && width >= 8 in
  let body_height = if framed then height - 2 else height in
  let path, description, back_label =
    match menu.page with
    | M.Root -> (" Home / Commands", " Choose a command group.", "Esc close")
    | M.Transactions -> (" Commands / Transactions", " Recording and exchange.", "Esc back")
    | M.Planning -> (" Commands / Plans and attention", " Scheduled household work.", "Esc back")
    | M.Analysis -> (" Commands / Reports and analysis", " Read household answers.", "Esc back")
    | M.Setup -> (" Commands / Household setup", " Explicit household evidence.", "Esc back")
  in
  let header =
    if body_height >= 9 then
      [ (Status, path); (Chrome, description); (Plain, "") ]
    else if body_height >= 3 then
      [ (Status, path) ]
    else []
  in
  let footer =
    if body_height >= 9 then
      [ (Plain, ""); (Chrome, " ↑/↓ select  → group  ← back"); (Chrome, " Enter open  " ^ back_label) ]
    else if body_height >= 2 then
      [ (Chrome, " ↑↓/jk Enter  " ^ back_label) ]
    else []
  in
  let page_cap = max 1 (body_height - List.length header - List.length footer) in
  let items = List.map snd (M.items menu.page) in
  let count = List.length items in
  let last = max 0 (count - page_cap) in
  let start = min last (max 0 (menu.selected - (page_cap / 2))) in
  let visible_items = items |> List.filteri (fun i _ -> i >= start && i < start + page_cap) in
  let item_lines =
    visible_items
    |> List.mapi (fun i text ->
        let index = i + start in
        let chosen = index = menu.selected in
        let marker = if chosen then "  > " else "    " in
        let style = if chosen then Active else Plain in
        (style, marker ^ text))
  in
  let pad_count = max 0 (page_cap - List.length item_lines) in
  let pad_lines = List.init pad_count (fun _ -> (Plain, "")) in
  let body_content = header @ item_lines @ pad_lines @ footer in
  let content =
    body_content
    |> List.mapi (fun i (style, text) ->
        if i < body_height then
          O.panel_line ~width ~width_of style text
        else (Plain, ""))
    |> List.filteri (fun i _ -> i < body_height)
  in
  let style = if width >= 54 && height >= 14 then Focused_frame else Frame in
  (O.panel_border ~width ~style ~width_of "Commands")
  :: content
  @ [ O.panel_bottom ~width ~style ~width_of () ]

type overlay_frame = {
  origin_x : int;
  origin_y : int;
  pane_width : int;
  pane_height : int;
  rows : (Daily_overlays.style * string) list;
  cursor : (int * int) option;
}

let resolve_overlay ~dimensions:((width, height) as dimensions) ~width_of state : overlay_frame option =
  let body_w, body_h = body_dimensions ~dimensions ~width_of state in
  let framed_form ~pane_w form =
    let content_width = max 0 (pane_w - 6) in
    let form_rows = Form.render_rows ~width:content_width
        ~height:(Panel.capacity ~height:body_h ~heading:false) ~width_of form in
    let pane_h = min body_h (max 5 (List.length form_rows + 2)) in
    let rows = Panel.frame_rows ~width_of ~width:pane_w ~height:pane_h
        ~focused:true ~title:(Form.title form) form_rows in
    let origin_x = max 0 ((width - pane_w) / 2) in
    let origin_y = max 0 ((body_h - pane_h) / 2) in
    let cursor = O.cursor_in_rows ~width_of ~width:pane_w rows
      |> Option.map (fun (col, row) -> (origin_x + col, origin_y + row)) in
    Some { origin_x; origin_y; pane_width = pane_w;
      pane_height = List.length rows; rows; cursor }
  in
  if state.record_visible then
    match state.record with
    | None -> None
    | Some record ->
        let pane_dimensions = record_dimensions ~dimensions ~width_of state in
        let available = (body_w, body_h + 2) in
        if pane_dimensions = available then None
        else
          let pane_w = fst pane_dimensions in
          let pane_h = snd pane_dimensions in
          let all_rows = S.screen ~book:state.session.book ~dimensions:pane_dimensions ~width_of record in
          let rows =
            all_rows
            |> List.filteri (fun i _ -> i < max 0 (pane_h - 2))
            |> List.map (fun (style, text) -> (style, O.pad ~width_of pane_w text))
          in
          let actual_h = List.length rows in
          let origin_x = max 0 ((width - pane_w) / 2) in
          let origin_y =
            if body_h - pane_h >= 2 then 2 + max 0 ((body_h - 2 - pane_h) / 2)
            else max 0 ((body_h - pane_h) / 2)
          in
          let cursor =
            match O.cursor_in_rows ~width_of ~width:pane_w rows with
            | Some (caret, row_idx) ->
                let col = origin_x + caret in
                let row = origin_y + row_idx in
                if col < width && row < height then Some (col, row) else None
            | None -> None
          in
          Some { origin_x; origin_y; pane_width = pane_w; pane_height = actual_h; rows; cursor }
  else if state.overlay = No_overlay || body_w < 8 || body_h < 3 then None
  else
    match state.overlay with
    | Scheduled_bulk editor ->
        let pane_dimensions = bulk_dimensions ~dimensions ~width_of state in
        let pane_w = fst pane_dimensions in
        let rows = Bulk.screen ~dimensions:pane_dimensions ~width_of editor in
        let pane_h = List.length rows in
        let origin_x = max 0 ((width - pane_w) / 2) in
        let origin_y = max 0 ((body_h - pane_h) / 2) in
        let cursor = Option.map (fun (col, row) -> (origin_x + col, origin_y + row))
          (O.cursor_in_rows ~width_of ~width:pane_w rows) in
        Some { origin_x; origin_y; pane_width = pane_w; pane_height = pane_h; rows; cursor }
    | Scheduled_generate editor ->
        let pane_dimensions = generate_dimensions ~dimensions ~width_of state in
        let pane_w = fst pane_dimensions in
        let rows = Gen.screen ~dimensions:pane_dimensions ~width_of editor in
        let pane_h = List.length rows in
        let origin_x = max 0 ((width - pane_w) / 2) in
        let origin_y = max 0 ((body_h - pane_h) / 2) in
        let cursor = Option.map (fun (col, row) -> (origin_x + col, origin_y + row))
          (O.cursor_in_rows ~width_of ~width:pane_w rows) in
        Some { origin_x; origin_y; pane_width = pane_w; pane_height = pane_h; rows; cursor }
    | Scheduled_continuation prompt ->
        let pane_dimensions = continuation_dimensions ~dimensions ~width_of state in
        let pane_w = fst pane_dimensions in
        let rows = Cont.screen ~dimensions:pane_dimensions ~width_of prompt in
        let pane_h = List.length rows in
        Some { origin_x = max 0 ((width - pane_w) / 2); origin_y = max 0 ((body_h - pane_h) / 2);
          pane_width = pane_w; pane_height = pane_h; rows; cursor = None }
    | Scheduled_cancel editor ->
        let pane_dimensions = cancellation_dimensions ~dimensions ~width_of state in
        let pane_w = fst pane_dimensions in
        let rows = Cancel.screen ~dimensions:pane_dimensions ~width_of editor in
        let pane_h = List.length rows in
        let origin_x = max 0 ((width - pane_w) / 2) in
        let origin_y = max 0 ((body_h - pane_h) / 2) in
        let cursor = Option.map (fun (col, row) -> (origin_x + col, origin_y + row))
          (O.cursor_in_rows ~width_of ~width:pane_w rows) in
        Some { origin_x; origin_y; pane_width = pane_w; pane_height = pane_h; rows; cursor }
    | Date_correction editor ->
        let pane_dimensions = date_dimensions ~dimensions ~width_of state in
        let pane_w = fst pane_dimensions in
        let rows = Date.screen ~dimensions:pane_dimensions ~width_of editor in
        let pane_h = List.length rows in
        let origin_x = max 0 ((width - pane_w) / 2) in
        let origin_y = max 0 ((body_h - pane_h) / 2) in
        let cursor = Option.map (fun (col, row) -> (origin_x + col, origin_y + row))
          (O.cursor_in_rows ~width_of ~width:pane_w rows) in
        Some { origin_x; origin_y; pane_width = pane_w; pane_height = pane_h; rows; cursor }
    | Event_merchant editor ->
        let pane_dimensions = merchant_dimensions ~dimensions ~width_of state in
        let pane_w = fst pane_dimensions in
        let rows = Merchant.screen ~dimensions:pane_dimensions ~width_of editor in
        let pane_h = List.length rows in
        let origin_x = max 0 ((width - pane_w) / 2) in
        let origin_y = max 0 ((body_h - pane_h) / 2) in
        let cursor =
          match O.cursor_in_rows ~width_of ~width:pane_w rows with
          | Some (col, row) ->
              let c = origin_x + col and r = origin_y + row in
              if c < width && r < height then Some (c, r) else None
          | None -> None
        in
        Some { origin_x; origin_y; pane_width = pane_w; pane_height = pane_h; rows; cursor }
    | Reversal editor ->
        let pane_dimensions = reversal_dimensions ~dimensions ~width_of state in
        let pane_w = fst pane_dimensions in
        let rows = Rev.screen ~dimensions:pane_dimensions ~width_of editor in
        let pane_h = List.length rows in
        let origin_x = max 0 ((width - pane_w) / 2) in
        let origin_y = max 0 ((body_h - pane_h) / 2) in
        let cursor =
          match O.cursor_in_rows ~width_of ~width:pane_w rows with
          | Some (col, row) ->
              let c = origin_x + col and r = origin_y + row in
              if c < width && r < height then Some (c, r) else None
          | None -> None
        in
        Some { origin_x; origin_y; pane_width = pane_w; pane_height = pane_h; rows; cursor }
    | Scheduled_create editor ->
        let pane_dimensions = scheduled_dimensions ~dimensions ~width_of state in
        let pane_w = fst pane_dimensions in
        let rows = Sch.screen ~book:state.session.book ~dimensions:pane_dimensions ~width_of editor in
        let pane_h = List.length rows in
        let origin_x = max 0 ((width - pane_w) / 2) in
        let origin_y = max 0 ((body_h - pane_h) / 2) in
        let cursor =
          match O.cursor_in_rows ~width_of ~width:pane_w rows with
          | Some (col, row) ->
              let c = origin_x + col and r = origin_y + row in
              if c < width && r < height then Some (c, r) else None
          | None -> None
        in
        Some { origin_x; origin_y; pane_width = pane_w; pane_height = pane_h; rows; cursor }
    | Commands menu ->
        let can_float = body_w >= 60 && body_h >= 14 in
        let pane_w = min 54 (max 8 (body_w - 4)) in
        let available_h = if can_float then max 5 (body_h - 4) else body_h in
        let pane_h = min (List.length (M.items menu.page) + 8) available_h in
        let rows = commands_overlay_rows ~width_of ~width:pane_w ~height:pane_h menu in
        let origin_x = max 0 ((width - pane_w) / 2) in
        let origin_y = max 0 ((body_h - pane_h) / 2) in
        Some { origin_x; origin_y; pane_width = pane_w; pane_height = List.length rows; rows; cursor = None }
    | Balance_picker picker ->
        let pane_w = min 64 (max 8 (body_w - 4)) in
        let pane_h = min body_h (max 5 (List.length picker.candidates + 3)) in
        let rows = List.map (fun locus ->
            (if List.mem locus picker.chosen then "[x] " else "[ ] ")
            ^ locus ^ " / " ^ state.workspace.measure) picker.candidates in
        let rows = Panel.frame ~width_of ~width:pane_w ~height:pane_h ~focused:true
            ~title:("Balances / Visible accounts (" ^ state.workspace.measure ^ ")")
            ~heading:(Printf.sprintf "Chosen: %d; unknown stays '?'" (List.length picker.chosen))
            ~scroll:0 ~selected:(Some picker.cursor) rows in
        Some { origin_x = max 0 ((width - pane_w) / 2);
          origin_y = max 0 ((body_h - pane_h) / 2); pane_width = pane_w;
          pane_height = List.length rows; rows; cursor = None }
    | Themes { selected; _ } ->
        let pane_w = min 54 (max 8 (body_w - 4)) in
        let items = List.map P.theme_label P.all_themes in
        let pane_h = min body_h (max 5 (List.length items + 2)) in
        let rows =
          Panel.frame ~width_of ~width:pane_w ~height:pane_h ~focused:true ~title:(tr "Theme")
            ~scroll:0 ~selected:(Some selected) items
        in
        let origin_x = max 0 ((width - pane_w) / 2) in
        let origin_y = max 0 ((body_h - pane_h) / 2) in
        Some { origin_x; origin_y; pane_width = pane_w; pane_height = List.length rows; rows; cursor = None }
    | Jump value ->
        framed_form ~pane_w:(min 54 (max 8 (body_w - 4)))
          (Form.create ~id:"jump" ~title:(tr "Jump to date / month / year")
             ~fields:[Form.text_field ~id:"value" ~label:"" ~value ()]
             ~notice:(tr "Enter apply; Esc cancel") ())
    | Search value ->
        framed_form ~pane_w:(min 54 (max 8 (body_w - 4)))
          (Form.create ~id:"search" ~title:(tr "Search Actual / Scheduled")
             ~fields:[Form.text_field ~id:"value" ~label:"" ~value ()]
             ~notice:(tr "Enter apply; Esc clear") ())
    | Modal_form form when is_balance_print form ->
        let pane_width, pane_height, content, _ =
          balance_print_viewport ~dimensions ~width_of state form in
        let rows = Panel.frame ~width_of ~width:pane_width ~height:pane_height
          ~focused:true ~title:(Form.title form) ~scroll:state.balance_print_scroll
          ~selected:None content in
        Some { origin_x = max 0 ((width - pane_width) / 2);
          origin_y = max 0 ((body_h - pane_height) / 2);
          pane_width; pane_height; rows; cursor = None }
    | Modal_form form ->
        framed_form ~pane_w:(min 64 (max 8 (body_w - 4))) form
    | No_overlay -> None

let overlay_screen ~dimensions ~width_of state =
  match resolve_overlay ~dimensions ~width_of state with
  | Some frame -> Some frame.rows
  | None -> None

let overlay_position ~dimensions ~width_of state ~pane_width ~pane_height =
  match resolve_overlay ~dimensions ~width_of state with
  | Some frame -> (frame.origin_x, frame.origin_y)
  | None ->
      let width, height = body_dimensions ~dimensions ~width_of state in
      let top =
        if state.record_visible && height - pane_height >= 2 then
          2 + max 0 ((height - 2 - pane_height) / 2)
        else max 0 ((height - pane_height) / 2)
      in
      (max 0 ((width - pane_width) / 2), top)

let cursor_position ~width_of ((width, height) as dimensions) state : (int * int) option =
  match resolve_overlay ~dimensions ~width_of state with
  | Some frame -> frame.cursor
  | None ->
      if state.record_visible then
        match state.record with
        | None -> None
        | Some record ->
            let pane_dimensions = record_dimensions ~dimensions ~width_of state in
            let rows = S.screen ~book:state.session.book ~dimensions:pane_dimensions ~width_of record in
            let painted = List.filteri (fun i _ -> i < max 0 height) rows in
            O.cursor_in_rows ~width_of ~width:(min width (fst pane_dimensions)) painted
      else if state.workspace.route = W.Actual then
        Act.cursor_position ~dimensions ~width_of state.actual_workspace
      else None

