(* Workspace painting, overlay placement and terminal caret coordinates. *)
open Daily_interaction_state
open Daily_interaction_context

let row_title = Record_lines.row_title
let actual_amount = Record_lines.actual_amount
let actual_table = Record_lines.actual_table
let scheduled_table = Record_lines.scheduled_table

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



let workspace_rows ?route_view ~width_of ~width ~height state =
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
    | W.Balances -> Balances.title state.screens.balances
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
  else if Option.is_some route_view then
    Lazy.force (Option.get route_view).Screen.rows
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
  match modal_screen_view ~dimensions ~width_of state with
  | Some view -> view.footer
  | None ->
  match state.overlay with
  | Themes _ -> [ "j/k or Up/Down preview theme"; "Enter save  Esc/q cancel" ]
  | Modal_form form -> (
      match Form.id form with
      | "discard_record" ->
          [ "Left/Right choose  Enter confirm  Esc keep";
            "Keep draft is the protective default; no book write" ]
      | _ ->
          [ "Enter submit  Tab next field  Esc cancel"; "Arrow keys / space to choose options" ])
  | No_overlay | Commands _ | Jump _ | Search _ ->
  match route_screen_view ~dimensions ~width_of state with
  | Some view -> view.footer
  | None ->
  if is_scheduled_months state then
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
    let route_view = route_screen_view ~dimensions ~width_of state in
    let draft = if has_record_draft state then "   Draft retained" else "" in
    let date_line () =
      state.workspace.calendar.selected_day ^ "   " ^ Cal.title state.workspace.calendar ^ tr " view" in
    let headers =
      if state.workspace.route = W.Home then []
      else match route_view with
      | Some view ->
          [
            line ~width_of width Heading (tr "Bakhlo" ^ "  /  " ^ view.Screen.title);
            (match view.subtitle with
             | Screen.Default -> line ~width_of width Chrome (date_line () ^ draft)
             | Screen.Text text -> line ~width_of width Chrome (text ^ draft)
             | Screen.Styled (style, text) -> line ~width_of width style text);
          ]
      | None ->
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
                | _ -> date_line ())
            ^ draft);
        ]
    in
    let header_count = List.length headers in
    let body =
      headers
      @ workspace_rows ?route_view ~width_of ~width ~height:(max 0 (body_height - header_count)) state
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

type overlay_frame = Ui_overlay.frame = {
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
  else if Option.is_some (modal_screen_view ~dimensions ~width_of state) then
    Option.bind (modal_screen_view ~dimensions ~width_of state) (fun view -> view.Screen.overlay)
  else if state.overlay = No_overlay || body_w < 8 || body_h < 3 then None
  else
    match state.overlay with
    | Commands menu ->
        let can_float = body_w >= 60 && body_h >= 14 in
        let pane_w = min 54 (max 8 (body_w - 4)) in
        let available_h = if can_float then max 5 (body_h - 4) else body_h in
        let pane_h = min (List.length (M.items menu.page) + 8) available_h in
        let rows = commands_overlay_rows ~width_of ~width:pane_w ~height:pane_h menu in
        let origin_x = max 0 ((width - pane_w) / 2) in
        let origin_y = max 0 ((body_h - pane_h) / 2) in
        Some { origin_x; origin_y; pane_width = pane_w; pane_height = List.length rows; rows; cursor = None }
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
      else Option.bind (route_screen_view ~dimensions ~width_of state) (fun view -> view.Screen.cursor)

