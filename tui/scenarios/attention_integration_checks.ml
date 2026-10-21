(* Synthetic controller integration checks; see docs/RECONSTRUCTION_TEST_MAP.ja.md. *)
open Interaction_check_fixture

let run ~width_of (home : C.state) =
  (* Attention workflow verification *)
  let att_state = key ~width_of home (`ASCII 'i') in
  require (att_state.workspace.route = W.Attention) "home-i-opens-attention";
  (* 1. Add overdue item *)
  let modal_add = key ~width_of att_state (`ASCII 'n') in
  require (visible_form_id modal_add = Some "add_attention") "attention-n-opens-add-form";
  let form_with_text =
    match visible_form modal_add with
    | Some f ->
        let f = Ui_form.set_text f "context" "Renew passport" in
        let f = Ui_form.set_choice f "due_kind" 2 in
        (* Due on date *)
        let f = Ui_form.set_text f "due_date" "2026-10-01" in
        let f = Ui_form.set_focused f 3 in
        with_visible_form modal_add f
    | None -> failwith "expected modal form"
  in
  let state_with_overdue = key ~width_of form_with_text `Enter in
  require (no_modal state_with_overdue) "attention-overdue-submitted";
  (* 2. Add second item (No due date) *)
  let modal_add2 = key ~width_of state_with_overdue (`ASCII 'n') in
  let form_with_text2 =
    match visible_form modal_add2 with
    | Some f ->
        let f = Ui_form.set_text f "context" "Buy groceries" in
        let f = Ui_form.set_choice f "due_kind" 0 in
        let f = Ui_form.set_focused f 3 in
        with_visible_form modal_add2 f
    | None -> failwith "expected modal form"
  in
  let added_state = key ~width_of form_with_text2 `Enter in
  require (no_modal added_state) "attention-add-submitted";
  let open_items = open_attentions added_state in
  require (List.length open_items = 2) "attention-two-items-added";
  (* Test screen layout, header rule, and overdue signal *)
  let att_screen = R.screen ~width_of (120, 36) added_state in
  require (contains att_screen "Attention (2 open • ! 1 overdue)") "attention-overdue-title";
  require (contains att_screen "! 2026-10-01") "attention-overdue-flag";
  require (contains att_screen "Renew passport") "attention-item1-context";
  require (contains att_screen "Buy groceries") "attention-item2-context";
  (* Test Tab detail toggle *)
  let att_tab = key ~width_of added_state `Tab in
  require
    (Attention_screen.detail_focused att_tab.C.screens.attention)
    "attention-tab-toggles-detail";
  let att_detail_screen = R.screen ~width_of (120, 36) att_tab in
  require (contains att_detail_screen "! OVERDUE") "attention-detail-shows-overdue";
  let att_tab_back = key ~width_of att_tab `Tab in
  require
    (not (Attention_screen.detail_focused att_tab_back.C.screens.attention))
    "attention-tab-toggles-back";
  let att_selected state = Attention_screen.selected state.C.screens.attention in
  let att_end = key ~width_of (key ~width_of added_state (`ASCII 'j')) `End in
  require (att_selected att_end = 1) "attention-end-from-second-selects-last";
  require (att_selected (key ~width_of att_end `Home) = 0) "attention-home-selects-first";
  (* Test drop 'x' on first item *)
  let modal_drop = key ~width_of added_state (`ASCII 'x') in
  require (visible_form_id modal_drop = Some "drop_attention") "attention-x-opens-drop-form";
  let dropped_state = key ~width_of modal_drop `Enter in
  require (no_modal dropped_state) "attention-drop-submitted";
  require (List.length (open_attentions dropped_state) = 1) "attention-item-dropped";
  (* Test resolve 'r' on second item *)
  let modal_resolve = key ~width_of dropped_state (`ASCII 'r') in
  require
    (visible_form_id modal_resolve = Some "resolve_attention")
    "attention-r-opens-resolve-form";
  let resolved_state = key ~width_of modal_resolve `Enter in
  require (no_modal resolved_state) "attention-resolve-submitted";
  require (List.length (open_attentions resolved_state) = 0) "attention-all-items-resolved";
  let back_home = key ~width_of resolved_state (`ASCII 'q') in
  require (back_home.workspace.route = W.Home) "attention-q-back-to-home";
  ()
