(* Synthetic controller integration checks; see docs/RECONSTRUCTION_TEST_MAP.ja.md. *)
open Interaction_check_fixture

let run ~width_of (home : C.state) =
  (* Attention workflow verification *)
  let att_state = key ~width_of home (`ASCII 'i') in
  require (att_state.workspace.route = W.Attention) "home-i-opens-attention";
  (* 1. Add overdue item *)
  let modal_add = key ~width_of att_state (`ASCII 'n') in
  require (C.is_add_attention modal_add.overlay) "attention-n-opens-add-form";
  let form_with_text =
    match modal_add.overlay with
    | C.Modal_form f ->
        let f = Ui_form.set_text f "context" "Renew passport" in
        let f = Ui_form.set_choice f "due_kind" 2 in (* Due on date *)
        let f = Ui_form.set_text f "due_date" "2026-10-01" in
        let f = Ui_form.set_focused f 3 in
        { modal_add with overlay = C.Modal_form f }
    | _ -> failwith "expected modal form"
  in
  let state_with_overdue = key ~width_of form_with_text `Enter in
  require (state_with_overdue.overlay = C.No_overlay) "attention-overdue-submitted";
  (* 2. Add second item (No due date) *)
  let modal_add2 = key ~width_of state_with_overdue (`ASCII 'n') in
  let form_with_text2 =
    match modal_add2.overlay with
    | C.Modal_form f ->
        let f = Ui_form.set_text f "context" "Buy groceries" in
        let f = Ui_form.set_choice f "due_kind" 0 in
        let f = Ui_form.set_focused f 3 in
        { modal_add2 with overlay = C.Modal_form f }
    | _ -> failwith "expected modal form"
  in
  let added_state = key ~width_of form_with_text2 `Enter in
  require (added_state.overlay = C.No_overlay) "attention-add-submitted";
  let open_items = C.open_attentions added_state in
  require (List.length open_items = 2) "attention-two-items-added";
  (* Test screen layout, header rule, and overdue signal *)
  let att_screen = R.screen ~width_of (120, 36) added_state in
  require (contains att_screen "Attention (2 open • ! 1 overdue)") "attention-overdue-title";
  require (contains att_screen "! 2026-10-01") "attention-overdue-flag";
  require (contains att_screen "Renew passport") "attention-item1-context";
  require (contains att_screen "Buy groceries") "attention-item2-context";
  (* Test Tab detail toggle *)
  let att_tab = key ~width_of added_state `Tab in
  require (att_tab.workspace.pane = W.Detail) "attention-tab-toggles-detail";
  let att_detail_screen = R.screen ~width_of (120, 36) att_tab in
  require (contains att_detail_screen "! OVERDUE") "attention-detail-shows-overdue";
  let att_tab_back = key ~width_of att_tab `Tab in
  require (att_tab_back.workspace.pane = W.Calendar) "attention-tab-toggles-back";
  (* Test drop 'x' on first item *)
  let modal_drop = key ~width_of added_state (`ASCII 'x') in
  require (C.is_drop_attention modal_drop.overlay) "attention-x-opens-drop-form";
  let dropped_state = key ~width_of modal_drop `Enter in
  require (dropped_state.overlay = C.No_overlay) "attention-drop-submitted";
  require (List.length (C.open_attentions dropped_state) = 1) "attention-item-dropped";
  (* Test resolve 'r' on second item *)
  let modal_resolve = key ~width_of dropped_state (`ASCII 'r') in
  require (C.is_resolve_attention modal_resolve.overlay) "attention-r-opens-resolve-form";
  let resolved_state = key ~width_of modal_resolve `Enter in
  require (resolved_state.overlay = C.No_overlay) "attention-resolve-submitted";
  require (List.length (C.open_attentions resolved_state) = 0) "attention-all-items-resolved";
  let back_home = key ~width_of resolved_state (`ASCII 'q') in
  require (back_home.workspace.route = W.Home) "attention-q-back-to-home";
  ()
