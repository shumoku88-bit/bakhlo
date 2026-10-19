(* Input dispatch; state transitions and painting have separate owners. *)
open Shell_state
open Shell_dispatch

let handle ?(dimensions = (80, 24)) ?(width_of = String.length) state (input : input) =
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
        | _ when Option.is_some (Lazy.force route_step) -> (
            match Lazy.force route_step with Some (`State state) -> Some state | _ -> None)
        | Some (`ASCII ' ', []) -> Some { state with overlay = Commands M.initial }
        | Some (`Uchar c, []) when Uchar.to_int c = 32 ->
            Some { state with overlay = Commands M.initial }
        | Some ((`Escape | `ASCII 'q'), []) -> Some (back state)
        | Some (`ASCII ('r' | 'n'), []) -> Some (open_record state)
        | Some (`ASCII ('c' | 'e'), []) | Some (`ASCII 'e', [ `Ctrl ]) -> Some (Shell_record_actions.edit_target state None)
        | _ -> (
            match ambient_screen_input ~dimensions ~width_of state input with
            | Some state -> Some state
            | None -> match input with `End -> None | _ -> Some state))
