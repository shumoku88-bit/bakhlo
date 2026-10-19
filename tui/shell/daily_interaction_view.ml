(* Workspace painting, overlay placement and terminal caret coordinates. *)
open Daily_interaction_state
open Daily_interaction_context

let workspace_rows ?route_view ~width_of ~width ~height state =
  if annual_needs_history state.workspace.route && annual_unavailable state <> None then
    let title = match state.workspace.route with
      | W.Balances -> Balances.title state.screens.balances
      | W.Daily_pace -> "Daily Pace"
      | W.Income_expense -> "Income & Expense"
      | W.Transactions_flow -> "Transactions Flow"
      | W.Stock_flow -> "Stock–Flow"
      | _ -> assert false in
    Panel.frame ~width_of ~width ~height ~focused:true ~title:(title ^ " / Unavailable")
      ~scroll:0 ~selected:None
      [ "Annual file does not contain a qualified prior-year opening.";
        "Balances, Daily Pace and cross-year reports are unavailable.";
        Option.value ~default:"Opening evidence unavailable." (annual_unavailable state);
        "Actual entries and Scheduled records in this file remain inspectable.";
        "No zero opening or carried balance is inferred." ]
  else match route_view with Some view -> Lazy.force view.Screen.rows | None -> []

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
  | No_overlay | Commands _ ->
  match route_screen_view ~dimensions ~width_of state with
  | Some view -> view.footer
  | None ->
  [ "j/k scroll  Page Up/Down page  Home/End range"; "q/Esc back  Space Commands  Ctrl-r reload" ]

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
             | W.Scheduled -> tr "Scheduled"
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
            ((match state.workspace.route with
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

