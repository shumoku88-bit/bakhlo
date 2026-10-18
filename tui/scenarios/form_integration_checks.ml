(* Synthetic controller integration checks; see docs/RECONSTRUCTION_TEST_MAP.ja.md. *)
open Interaction_check_fixture

let run ~width_of (home : C.state) =
  let form =
    Ui_form.create
      ~id:"test_form"
      ~title:"Test Modal Form"
      ~summary:["Line 1 summary"; "Line 2 summary"]
      ~fields:[
        Ui_form.text_field ~id:"memo" ~label:"Memo" ~value:"initial" ();
        Ui_form.choice_field ~id:"category" ~label:"Category" ~options:["Food"; "Transport"; "Other"] ~selected:0 ();
        Ui_form.action_buttons ~confirm:"Save" ~cancel:"Discard" ();
      ]
      ()
  in
  require (Ui_form.id form = "test_form") "form-id";
  require (Ui_form.title form = "Test Modal Form") "form-title";
  require (Ui_form.focused form = 0) "form-initial-focus-0";
  require (Ui_form.get_text form "memo" = Some "initial") "form-get-text";
  require (Ui_form.get_choice form "category" = Some 0) "form-get-choice";
  require (Ui_form.get_choice_value form "category" = Some "Food") "form-get-choice-value";
  let f_tab1 = match Ui_form.handle_input form (`Key (`Tab, [])) with Ui_form.Updated f -> f | _ -> failwith "tab1" in
  require (Ui_form.focused f_tab1 = 1) "form-tab-to-1";
  let f_tab2 = match Ui_form.handle_input f_tab1 (`Key (`Tab, [])) with Ui_form.Updated f -> f | _ -> failwith "tab2" in
  require (Ui_form.focused f_tab2 = 2) "form-tab-to-2";
  let f_tab3 = match Ui_form.handle_input f_tab2 (`Key (`Tab, [])) with Ui_form.Updated f -> f | _ -> failwith "tab3" in
  require (Ui_form.focused f_tab3 = 0) "form-tab-wrap-to-0";
  let f_stab = match Ui_form.handle_input f_tab3 (`Key (`Tab, [ `Shift ])) with Ui_form.Updated f -> f | _ -> failwith "stab" in
  require (Ui_form.focused f_stab = 2) "form-shift-tab-to-2";
  let f_typed = match Ui_form.handle_input form (`Key (`ASCII '!', [])) with Ui_form.Updated f -> f | _ -> failwith "typed" in
  require (Ui_form.get_text f_typed "memo" = Some "initial!") "form-text-appended";
  let f_bs = match Ui_form.handle_input f_typed (`Key (`Backspace, [])) with Ui_form.Updated f -> f | _ -> failwith "bs" in
  require (Ui_form.get_text f_bs "memo" = Some "initial") "form-text-backspace";
  let f_enter1 = match Ui_form.handle_input form (`Key (`Enter, [])) with Ui_form.Updated f -> f | _ -> failwith "enter1" in
  require (Ui_form.focused f_enter1 = 1) "form-enter-advances-focus";
  let f_ch_next = match Ui_form.handle_input f_enter1 (`Key ((`Arrow `Right), [])) with Ui_form.Updated f -> f | _ -> failwith "ch_next" in
  require (Ui_form.get_choice f_ch_next "category" = Some 1) "form-choice-next";
  require (Ui_form.get_choice_value f_ch_next "category" = Some "Transport") "form-choice-value-transport";
  let f_submitted = match Ui_form.handle_input f_ch_next (`Key (`Enter, [])) with Ui_form.Submit f -> f | _ -> failwith "submit" in
  require (Ui_form.id f_submitted = "test_form") "form-submitted-id";
  let f_on_btn = Ui_form.set_focused form 2 in
  let f_btn_right = match Ui_form.handle_input f_on_btn (`Key ((`Arrow `Right), [])) with Ui_form.Updated f -> f | _ -> failwith "btn_right" in
  require (Ui_form.get_button f_btn_right "action" = Some 1) "form-button-toggle-to-cancel";
  let f_cancelled = match Ui_form.handle_input f_btn_right (`Key (`Enter, [])) with Ui_form.Cancel -> true | _ -> false in
  require f_cancelled "form-enter-on-cancel-button";
  let esc_cancelled = match Ui_form.handle_input form (`Key (`Escape, [])) with Ui_form.Cancel -> true | _ -> false in
  require esc_cancelled "form-escape-cancels";
  let module O = Daily_overlays in
  let render ?(width = 40) ?(height = 20) form =
    Ui_form.render_rows ~width ~height ~width_of form in
  let cursor ?(width = 40) ?(height = 20) form =
    O.cursor_in_rows ~width_of ~width (render ~width ~height form) in
  require (cursor form = Some (13, 3)) "form-visible-text-caret";
  require (cursor f_tab1 = None && cursor f_tab2 = None) "form-choice-buttons-hide-caret";
  let form_ja = Ui_form.create ~id:"ja_form" ~title:"Japanese"
    ~fields:[Ui_form.text_field ~id:"memo" ~label:"メモ" ~value:"昼食代" ()] () in
  require (cursor form_ja = Some (12, 0)) "form-native-japanese-width";
  let long_value = String.make 80 'x' ^ "末尾|│" in
  let long_form = Ui_form.set_text form "memo" long_value in
  List.iter (fun width ->
      List.iter (fun height ->
          let rows = render ~width ~height long_form in
          require (List.length rows <= max 0 height
                   && List.for_all (fun (_, text) -> width_of text <= max 0 width) rows)
            "form-bounded-content";
          require (Ui_form.get_text long_form "memo" = Some long_value)
            "form-window-preserves-value";
          match cursor ~width ~height long_form with
          | Some (col, row) ->
              require (col < width && row < height) "form-caret-inside-window";
              let _, text = List.nth rows row in
              require (String.ends_with ~suffix:"|" text) "form-shows-insertion-tail"
          | None -> require (width <= 0 || height <= 0) "form-focused-text-visible")
        [0; 1; 3; 20])
    [0; 1; 6; 12; 40];
  let short_notice = Ui_form.set_notice form "Refused" in
  require (cursor form = cursor short_notice
           && List.length (render form) = List.length (render short_notice))
    "form-short-notice-reserves-geometry";
  let last_field = Ui_form.set_focused long_form 2 in
  require (List.exists (fun (style, _) -> style = O.Active)
             (render ~height:2 last_field))
    "form-buttons-follow-focus";
  let warning = Ui_form.set_notice form (String.make 200 'w') in
  require (List.exists (fun (style, text) -> style = O.Status
             && Base.String.is_substring text ~substring:"more")
             (render ~width:20 ~height:6 warning))
    "form-long-warning-explicit-overflow";
  List.iter (fun ((width, height) as dimensions) ->
      List.iter (fun overlay ->
          let state = { home with C.overlay } in
          match R.resolve_overlay ~dimensions ~width_of state with
          | None -> raise (F.Refused "form-overlay-missing")
          | Some frame ->
              let local = O.cursor_in_rows ~width_of ~width:frame.pane_width frame.rows in
              require (frame.cursor = Option.map (fun (col, row) ->
                  frame.origin_x + col, frame.origin_y + row) local)
                "form-overlay-painted-caret";
              (match frame.cursor with
              | Some (col, row) ->
                  require (col < width && row < height) "form-overlay-terminal-bounds"
              | None -> raise (F.Refused "form-overlay-caret-hidden"));
              let cancelled = key ~dimensions ~width_of state `Escape in
              require (no_modal cancelled
                       && cancelled.workspace = home.workspace
                       && cancelled.session.bytes = home.session.bytes)
                "form-overlay-cancel-preserves-parent")
        [C.Jump long_value; C.Search long_value; C.Modal_form long_form])
    [80,24; 120,36; 48,14; 32,9];
  form_ja

let cursor_checks ~width_of (home : C.state) form_ja =
  (* Common hardware cursor position & IME anchor verification across UI *)
  (* 1. Home workspace (browse mode) -> None (cursor hidden) *)
  require (R.cursor_position ~width_of (80, 24) home = None) "cursor-hidden-on-home";
  (* 2. Modal form active on text field -> Some (col, row) *)
  let form_ja_state = { home with overlay = C.Modal_form form_ja } in
  (match R.cursor_position ~width_of (80, 24) form_ja_state with
   | Some (col, row) ->
       require (col > 0 && col < 80) "cursor-modal-col-bounded";
       require (row > 0 && row < 24) "cursor-modal-row-bounded"
   | None -> failwith "expected-modal-form-cursor");
  (* 3. Record session active -> Some (col, row) matches Input caret cell *)
  let rec_state = key ~width_of home (`ASCII 'r') in
  require rec_state.record_visible "record-visible";
  (match R.cursor_position ~width_of (80, 24) rec_state with
   | Some (col, row) ->
       require (col > 0 && col < 80) "cursor-record-col-bounded";
       require (row > 0 && row < 24) "cursor-record-row-bounded"
   | None -> failwith "expected-record-session-cursor");
  (* 4. Jump and Search overlays -> Some (col, row) *)
  let jump_state = { home with overlay = C.Jump "2026-10" } in
  (match R.cursor_position ~width_of (80, 24) jump_state with
   | Some (col, row) ->
       require (col > 0 && col < 80) "cursor-jump-col-bounded";
       require (row > 0 && row < 24) "cursor-jump-row-bounded"
   | None -> failwith "expected-jump-overlay-cursor");
  let search_state = { home with overlay = C.Search "ramen" } in
  (match R.cursor_position ~width_of (80, 24) search_state with
   | Some (col, row) ->
       require (col > 0 && col < 80) "cursor-search-col-bounded";
       require (row > 0 && row < 24) "cursor-search-row-bounded"
   | None -> failwith "expected-search-overlay-cursor");
  (* 5. Single source of truth: resolve_overlay must strictly match cursor_position across overlays *)
  let check_overlay_sync state label =
    match R.resolve_overlay ~dimensions:(80, 24) ~width_of state with
    | None -> failwith ("expected-overlay-frame-" ^ label)
    | Some frame ->
        require (R.cursor_position ~width_of (80, 24) state = frame.cursor)
          ("overlay-cursor-sync-" ^ label);
        (match frame.cursor with
        | Some (col, row) ->
            require (col >= frame.origin_x && col < frame.origin_x + frame.pane_width)
              ("cursor-within-pane-width-" ^ label);
            require (row >= frame.origin_y && row < frame.origin_y + frame.pane_height)
              ("cursor-within-pane-height-" ^ label)
        | None -> ())
  in
  check_overlay_sync form_ja_state "modal-form";
  check_overlay_sync rec_state "record-session";
  check_overlay_sync jump_state "jump";
  check_overlay_sync search_state "search";
  (* 6. Japanese text IME cursor anchor stability *)
  let rec_ja = text ~width_of rec_state "コンビニ" in
  check_overlay_sync rec_ja "record-with-japanese-text";
  let search_ja = { home with overlay = C.Search "食費" } in
  check_overlay_sync search_ja "search-with-japanese-text";
  ()
