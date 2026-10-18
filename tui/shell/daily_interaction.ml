(* Input dispatch; state transitions and painting have separate owners. *)
open Daily_interaction_state
open Daily_interaction_context

let handle ?(dimensions = (80, 24)) ?(width_of = String.length) state (input : input) =
  let state =
    if is_record_browser state && not state.record_visible then
      let _, view = browser_viewport ~dimensions ~width_of state in
      { state with scroll = view.start }
    else state in
  if state.paste_blocked then
    match input with
    | `Paste `End ->
        Some
          {
            state with
            paste_blocked = false;
            message =
              (if state.blocked then state.message
               else tr "Paste ignored outside Record input; no commands were run.");
          }
    | `End -> None
    | _ -> Some state
  else if input = `Paste `Start && ((not state.record_visible) || Option.is_none state.record) then
    Some { state with paste_blocked = true }
  else if state.record_visible then
    match state.record with
    | None -> Some { state with record_visible = false }
    | Some record -> (
        match
          S.handle ~new_id:Daily_file.new_id ~book:state.session.book ~base_bytes:state.session.bytes ~blocked:state.blocked
            ~dimensions:(record_dimensions ~dimensions ~width_of state)
            ~width_of record input
        with
        | S.Updated record -> Some { state with record = Some record }
        | S.Closed record -> Some { state with record = Some record; record_visible = false }
        | S.Publish (payload, base_bytes, record) ->
            let draft = { state with record = Some record } in
            Some
              (if state.blocked then draft
               else
                 apply_commit_result state ~draft
                   (A.commit_payload ~session:state.session ~base_bytes payload)))
  else if Option.is_some (Screen_registry.modal state.screens) then
    match input with
    | `Key (`ASCII ('r' | 'R'), [ `Ctrl ]) -> Some (reload state)
    | _ -> modal_screen_input ~dimensions ~width_of state input
  else
    match state.overlay with
    | Commands menu -> (
        match M.handle menu input with
        | M.Updated menu -> Some { state with overlay = Commands menu }
        | M.Closed -> Some { state with overlay = No_overlay }
        | M.Chosen action -> Some (open_command state action))
    | Themes { selected; original; return_menu } -> (
        let count = List.length P.all_themes in
        match input with
        | `Key ((`Escape | `ASCII 'q'), []) ->
            Some
              { state with theme = original; overlay = Commands return_menu }
        | `Key ((`Arrow `Up | `Arrow `Left | `ASCII 'k'), [])
        | `Key ((`Arrow `Down | `Arrow `Right | `ASCII 'j'), []) ->
            let delta =
              match input with `Key ((`Arrow `Up | `Arrow `Left | `ASCII 'k'), []) -> -1 | _ -> 1
            in
            let selected = max 0 (min (count - 1) (selected + delta)) in
            Some
              {
                state with
                theme = List.nth P.all_themes selected;
                overlay = Themes { selected; original; return_menu };
              }
        | `Key (`Enter, []) ->
            let notice =
              match P.save_theme ?config_home:state.config_home state.theme with
              | Ok () -> tr "Theme saved."
              | Error _ -> tr "Theme changed for this session only; settings could not be saved."
            in
            Some { state with overlay = No_overlay; ui_notice = Some notice }
        | _ -> Some state)
    | Jump value -> (
        match input with
        | `Key (`Escape, []) -> Some { state with overlay = No_overlay }
        | `Key (`Enter, []) ->
            Some (update_calendar { state with overlay = No_overlay } (Cal.Jump value))
        | _ ->
            Some
              (match input_text value input with
              | None -> state
              | Some value -> { state with overlay = Jump value }))
    | Search value -> (
        match input with
        | `Key (`Escape, []) ->
            Some
              (sync { state with overlay = No_overlay; workspace = W.set_query state.workspace "" })
        | `Key (`Enter, []) ->
            Some
              (sync
                 { state with overlay = No_overlay; workspace = W.set_query state.workspace value })
        | _ ->
            Some
              (match input_text value input with
              | None -> state
              | Some value -> { state with overlay = Search value }))
    | Modal_form form -> (
        let result =
          match input with
          | `Key (`ASCII ('r' | 'R'), [`Ctrl]) -> Form.Updated form
          | _ -> Form.handle_input form input in
        match result with
        | Form.Cancel -> Some { state with overlay = No_overlay }
        | Form.Updated _ when input = `Key (`ASCII 'r', [`Ctrl])
                              || input = `Key (`ASCII 'R', [`Ctrl]) ->
            Some (reload state)
        | Form.Updated updated -> Some { state with overlay = Modal_form updated }
        | Form.Submit submitted -> (
            match Form.id submitted with
            | "annual_rollover" ->
                let body_w, body_h = body_dimensions ~dimensions ~width_of state in
                let pane_w = min 64 (max 8 (body_w - 4)) in
                let rows = Form.render_rows ~width:(max 0 (pane_w - 6)) ~height:10000 ~width_of submitted in
                if pane_w < 48 || List.length rows + 4 > body_h then
                  let reset = Form.update_field submitted "decision" (function
                    | Form.Buttons buttons -> Form.Buttons { buttons with selected = 0 }
                    | other -> other) in
                  Some { state with overlay = Modal_form (Form.set_notice reset
                      "Enlarge the terminal to review both paths before creating a year.") }
                else if state.blocked || has_record_draft state
                     || Form.payload submitted <> state.session.bytes then
                  Some { state with overlay = No_overlay;
                    message = "Annual review expired or a draft/recovery is held. Reopen the review." }
                else
                  (try
                     let session = F.rollover ~session:state.session in
                     Some { (initial ?config_home:state.config_home session) with
                       message = "Next annual book created and verified from disk. Prior year is read-only." }
                   with
                   | F.Refused why ->
                       Some { state with overlay = No_overlay; message = "Annual rollover refused: " ^ why }
                   | Unix.Unix_error _ | Sys_error _ ->
                       Some { state with overlay = No_overlay; blocked = true;
                         message = "Annual creation result is uncertain. Inspect both years; do not retry blindly." })
            | "discard_record" ->
                let width, height = body_dimensions ~dimensions ~width_of state in
                if width < 48 || height < 12 then
                  Some { (request_discard state) with
                    message = (if state.blocked then state.message
                      else tr "Enlarge the terminal to confirm draft discard.") }
                else Some (discard { state with overlay = No_overlay })
        | _ -> Some state))
    | No_overlay -> (
        let key = match input with `Key (key, mods) -> Some (key, mods) | _ -> None in
        let route_step = lazy (route_screen_input ~dimensions ~width_of state input) in
        let normalize (key, mods) =
          match key with `ASCII c -> (`ASCII (Char.lowercase_ascii c), mods) | _ -> (key, mods)
        in
        match Option.map normalize key with
        | Some (`ASCII 'q', [ `Ctrl ]) -> None
        | Some (`ASCII 'r', [ `Ctrl ]) -> Some (reload state)
        | Some (`ASCII 'n', [ `Ctrl ]) -> Some (request_discard state)
        | _ when Option.is_some (Lazy.force route_step) -> Lazy.force route_step
        | Some (`ASCII ' ', []) -> Some { state with overlay = Commands M.initial }
        | Some (`Uchar c, []) when Uchar.to_int c = 32 ->
            Some { state with overlay = Commands M.initial }
        | Some ((`Escape | `ASCII 'q'), []) when state.workspace.route = W.Home ->
            None
        | Some (`ASCII 'g', []) when state.workspace.route = W.Home ->
            Some (open_route state W.Calendar)
        | Some (`Enter, []) when state.workspace.route = W.Home ->
            Some (open_route state W.Calendar)
        | Some (`ASCII 'g', []) when state.workspace.route = W.Calendar ->
            Some (open_route state W.Home)
        | Some (`ASCII 'g', []) when (match state.workspace.route with W.Selected_day _ -> true | _ -> false) ->
            Some (open_route state W.Loci)
        | Some ((`Escape | `ASCII 'q'), []) ->
            if state.workspace.route = W.Calendar then
              if state.workspace.pane = W.Detail then
                Some { state with workspace = { state.workspace with pane = W.Calendar }; scroll = 0 }
              else if fst (Option.get key) = `Escape && state.workspace.calendar.zoom <> Cal.Day then
                Some
                  (sync
                     {
                       state with
                       workspace =
                         {
                           state.workspace with
                           calendar =
                             {
                               state.workspace.calendar with
                               zoom =
                                 (match state.workspace.calendar.zoom with
                                 | Cal.Year -> Cal.Month
                                 | Cal.Month -> Cal.Day
                                 | Cal.Day -> Cal.Day);
                             };
                         };
                     })
              else Some (open_route state W.Home)
            else Some (back state)
        | Some (`ASCII 'b', []) when (match state.workspace.route with
            | W.Scheduled | W.Selected_day _ -> true | _ -> false) ->
            Some (batch_plan_selected state)
        | Some (`ASCII 'g', []) when state.workspace.route = W.Scheduled ->
            Some (extend_plan_selected state)
        | Some (`ASCII 'v', []) when state.workspace.route = W.Scheduled ->
            Some (sync { state with workspace = W.toggle_schedule_view ~book:state.session.book state.workspace;
              message = (if state.blocked then state.message else "") })
        | Some ((`ASCII 'h' | `Arrow `Left | `ASCII 'l' | `Arrow `Right), [])
          when is_scheduled_months state && state.workspace.pane = W.Calendar ->
            let delta = match Option.map normalize key with
              | Some ((`ASCII 'h' | `Arrow `Left), _) -> -1 | _ -> 1 in
            (match Months.shift state.workspace.months delta with
             | Ok months -> Some { state with workspace = { state.workspace with months } }
             | Error message -> Some { state with message = (if state.blocked then state.message else message) })
        | Some (`ASCII ('f' | '/'), []) when is_scheduled_months state ->
            Some { state with message = (if state.blocked then state.message else
              "Months uses all current-open plans; v opens filtered List.") }
        | Some (`Enter, []) when is_scheduled_months state -> Some (pay_selected state)
        | Some (`ASCII 'r', []) when is_scheduled_months state -> Some (edit_selected state)
        | Some ((`ASCII ('h' | 'l') | `Arrow (`Left | `Right)), [])
          when is_record_browser state ->
            Some { state with workspace = { state.workspace with
              pane = (if state.workspace.pane = W.Calendar then W.Detail else W.Calendar) };
              scroll = 0 }
        | Some ((`Home | `End | `Page _ | `ASCII ('j' | 'k') | `Arrow (`Up | `Down)), [])
        | Some (`ASCII ('u' | 'd'), [ `Ctrl ]) when is_record_browser state ->
            let height, view = browser_viewport ~dimensions ~width_of state in
            let detail = state.workspace.pane = W.Detail in
            let page = max 1 (if detail then view.capacity else if is_scheduled_months state then 8 else
              Panel.capacity ~height ~heading:(state.workspace.route = W.Actual)) in
            let delta = match Option.map normalize key with
              | Some (`Home, _) -> -max_int
              | Some (`End, _) -> max_int
              | Some (`Page `Up, _) | Some (`ASCII 'u', [ `Ctrl ]) -> -page
              | Some (`Page `Down, _) | Some (`ASCII 'd', [ `Ctrl ]) -> page
              | Some ((`ASCII 'k' | `Arrow `Up), _) -> -1
              | _ -> 1 in
            if detail then
              Some { state with scroll = Panel.move ~last:view.last ~position:view.start delta }
            else Some { state with scroll = 0;
              workspace = W.move_selection ~book:state.session.book state.workspace delta }
        | Some ((`Tab | `ASCII 'w'), []) | Some (`Tab, [ `Shift ]) ->
            Some
              {
                state with
                workspace =
                  {
                    state.workspace with
                    pane = (if state.workspace.pane = W.Calendar then W.Detail else W.Calendar);
                  };
                scroll = (if is_record_browser state then state.scroll else 0);
              }
        | Some (`ASCII 't', []) when state.workspace.route = W.Calendar ->
            Some (update_calendar state (Cal.Today (F.today ())))
        | Some (`ASCII 'z', []) when state.workspace.route = W.Calendar ->
            Some (update_calendar state Cal.Cycle_zoom)
        | Some (`ASCII '/', []) ->
            Some
              {
                state with
                overlay = (if state.workspace.route = W.Calendar then Jump ""
                  else Search (W.browser state.workspace).query);
              }
        | Some (`ASCII 'r', []) | Some (`ASCII 'n', [])
          when state.workspace.route = W.Scheduled ->
            Some (open_plan_record state)
        | Some (`ASCII 'r', []) | Some (`ASCII 'n', []) -> Some (open_record state)
        | Some (`ASCII 'a', []) when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_route state W.Actual)
        | Some (`ASCII 's', []) when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_route state W.Scheduled)
        | Some (`ASCII 'b', []) when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_route state W.Balances)
        | Some (`ASCII 'd', []) when (match state.workspace.route with W.Selected_day _ -> true | _ -> false) ->
            Some (correct_date_selected state)
        | Some (`ASCII 'm', []) when (match state.workspace.route with W.Selected_day _ -> true | _ -> false) ->
            Some (classify_merchant_selected state)
        | Some (`ASCII 'd', []) when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_route state W.Daily_pace)
        | Some (`ASCII 'i', []) when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_route state W.Attention)
        | Some (`ASCII 'o', [])
          when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_observe state)
        | Some (`ASCII 'f', [])
          when state.workspace.route = W.Scheduled ->
            Some (sync { state with workspace = W.toggle_day_filter state.workspace })
        | Some (`ASCII 'x', []) when state.workspace.route = W.Scheduled ->
            Some (cancel_plan_selected state)
        | Some (`ASCII 'x', []) -> (
            match selected state with
            | Some (W.Scheduled_plan _) -> Some (cancel_plan_selected state)
            | Some (W.Actual_entry _) -> Some (reverse_entry_selected state)
            | _ -> Some state)
        | Some (`ASCII 'c', []) when state.workspace.route = W.Scheduled ->
            Some (pay_selected state)
        | Some (`ASCII 'e', []) when state.workspace.route = W.Scheduled ->
            Some (edit_selected state)
        | Some (`ASCII 'c', []) | Some (`ASCII 'e', []) | Some (`ASCII 'e', [ `Ctrl ]) ->
            Some (edit_selected state)
        | Some (`ASCII 'i', []) ->
            Some { state with workspace = { state.workspace with pane = W.Detail }; scroll = 0 }
        | Some (`Enter, []) ->
            if state.workspace.route = W.Calendar && state.workspace.pane = W.Calendar then
              Some (update_calendar state Cal.Drill)
            else if state.workspace.route = W.Calendar then
              match selected state with
              | None -> Some state
              | Some row -> Some (open_route state (W.Selected_day (W.date row)))
            else
              Some { state with workspace = { state.workspace with pane = W.Detail }; scroll = 0 }
        | (Some ((`ASCII 'h' | `Arrow `Left), []) | Some ((`ASCII 'l' | `Arrow `Right), []))
          when state.workspace.route = W.Calendar && state.workspace.pane = W.Calendar ->
            let action =
              match Option.get key with
              | (`ASCII 'h' | `Arrow `Left), _ -> Cal.Left
              | _ -> Cal.Right
            in
            Some (update_calendar state action)
        | Some ((`ASCII 'k' | `Arrow `Up), []) | Some ((`ASCII 'j' | `Arrow `Down), []) ->
            let delta =
              match Option.map normalize key with
              | Some ((`ASCII 'k' | `Arrow `Up), _) -> -1
              | _ -> 1
            in
            if state.workspace.route = W.Calendar && state.workspace.pane = W.Calendar then
              Some (update_calendar state (if delta < 0 then Cal.Up else Cal.Down))
            else if state.workspace.pane = W.Detail && state.workspace.route <> W.Calendar && state.workspace.route <> W.Home then
              Some { state with scroll = max 0 (state.scroll + delta) }
            else
              Some
                {
                  state with
                  workspace = W.move_selection ~book:state.session.book state.workspace delta;
                  scroll = 0;
                }
        | Some (`Page _, []) | Some (`ASCII ('u' | 'd'), [ `Ctrl ]) ->
            let delta =
              match Option.map normalize key with
              | Some (`Page `Up, _) | Some (`ASCII 'u', _) -> -1
              | _ -> 1
            in
            let step = delta * max 1 (snd dimensions - 8) in
            if
              state.workspace.pane = W.Calendar && state.workspace.route <> W.Home
              && state.workspace.route <> W.Daily_pace
              || (state.workspace.route = W.Home && state.workspace.pane = W.Detail)
            then
              Some
                {
                  state with
                  workspace = W.move_selection ~book:state.session.book state.workspace step;
                  scroll = 0;
                }
            else Some { state with scroll = max 0 (state.scroll + step) }
        | Some (`Home, []) ->
              Some
                {
                  state with
                  scroll = 0;
                  workspace = W.move_selection ~book:state.session.book state.workspace (-max_int);
                }
        | Some (`End, []) ->
              Some
                {
                  state with
                  scroll = max_int / 4;
                  workspace = W.move_selection ~book:state.session.book state.workspace max_int;
                }
        | _ -> ( match input with `End -> None | _ -> Some state))

