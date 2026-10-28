(* Commitment settlements through the Shell on a synthetic book. *)
open Interaction_check_fixture

(* A Measure with decimals reads at its scale: 1,050.00 eur is 105000 smallest units and
   is shown, pre-filled and settled as 1,050.00, never as 105000. *)
let decimal_measure_checks ~width_of ~directory =
  let dir = directory ^ "/settlement-decimals" in
  Unix.mkdir dir 0o700;
  let path = dir ^ "/book.txt" in
  F.create_copy ~source:example_book ~target:path;
  let screen = C.open_route (C.initial ~config_home:dir (F.load path)) W.Settlements in
  let contains rows needle =
    List.exists (fun (_, text) -> Base.String.is_substring text ~substring:needle) rows
  in
  let adding = key ~width_of screen (`ASCII 'n') in
  let added =
    match visible_form adding with
    | Some f ->
        let f = Ui_form.set_text f "label" "Synthetic ticket" in
        let f = Ui_form.set_text f "debtor" "yamada" in
        let f = Ui_form.set_text f "creditor" "household" in
        let f = Ui_form.set_text f "measure" "eur" in
        let f = Ui_form.set_text f "amount" "1050.00" in
        key ~width_of (with_visible_form adding (Ui_form.set_focused f 5)) `Enter
    | None -> failwith "expected modal form for add settlement"
  in
  require
    (match settlement_rows added with
    | [ r ] -> Z.equal (Stl.outstanding r) (Z.of_int 105000)
    | _ -> false)
    "decimal-commitment-stored-in-smallest-units";
  let rows = R.screen ~width_of (120, 30) added in
  require
    (contains rows "1,050.00" && not (contains rows "105000"))
    "decimal-commitment-shown-at-scale";
  let acting = key ~width_of added (`ASCII 'a') in
  match visible_form acting with
  | Some f ->
      require (Ui_form.get_text f "amount" = Some "1050.00") "decimal-remaining-prefilled-at-scale";
      let f = Ui_form.set_focused (Ui_form.set_choice f "action_kind" 0) 2 in
      let settled = key ~width_of (with_visible_form acting f) `Enter in
      require (settlement_rows settled = []) "decimal-prefilled-amount-settles-the-commitment"
  | None -> failwith "expected modal form for action settlement"

let run ~width_of ~directory ~path (exch_done : C.state) =
  decimal_measure_checks ~width_of ~directory;
  (* Settlements (UI-27, UI-28) test suite *)
  let contains rows needle =
    List.exists (fun (_, text) -> Base.String.is_substring text ~substring:needle) rows
  in
  let cmd_root = key ~width_of exch_done (`ASCII ' ') in
  let to_planning = key ~width_of cmd_root (`Arrow `Down) in
  (* Planning is index 1 *)
  let plan_menu = key ~width_of to_planning `Enter in
  let to_settlements =
    key ~width_of
      (key ~width_of (key ~width_of plan_menu (`Arrow `Down)) (`Arrow `Down))
      (`Arrow `Down)
  in
  (* Scheduled 0, New Plan 1, Attention 2, Settlements 3 *)
  let stl_view = key ~width_of to_settlements `Enter in
  require (stl_view.workspace.route = W.Settlements) "commands-opens-settlements-view";
  let wide_stl = R.screen ~width_of (120, 30) stl_view in
  require
    (contains wide_stl "Settlements [Open]" && contains wide_stl "Commitment Details")
    "settlements-wide-two-pane-visible";
  (* Add settlement commitment *)
  let add_modal = key ~width_of stl_view (`ASCII 'n') in
  require (visible_form_id add_modal = Some "add_settlement") "n-opens-add-settlement-form";
  let add_ready =
    match visible_form add_modal with
    | Some f ->
        let f = Ui_form.set_text f "label" "Dinner reimbursement" in
        let f = Ui_form.set_text f "debtor" "yamada" in
        let f = Ui_form.set_text f "creditor" "household" in
        let f = Ui_form.set_text f "measure" "jpy" in
        let f = Ui_form.set_text f "amount" "5000" in
        let f = Ui_form.set_focused f 5 in
        (* Action buttons *)
        with_visible_form add_modal f
    | None -> failwith "expected modal form for add settlement"
  in
  let added_state = key ~width_of add_ready `Enter in
  require (no_modal added_state) "add-settlement-submitted";
  let stl_rows = settlement_rows added_state in
  require (List.length stl_rows = 1) "settlement-row-added";
  let r = List.hd stl_rows in
  require (r.Stl.id = "comm-1" && r.label = Some "Dinner reimbursement") "settlement-row-fields";
  require (Z.equal (Stl.outstanding r) (Z.of_int 5000)) "settlement-outstanding-5000";
  (* Settle partial amount: 3,000 jpy *)
  let act_modal = key ~width_of added_state (`ASCII 'a') in
  require (visible_form_id act_modal = Some "action_settlement") "a-opens-action-settlement-form";
  let act_ready =
    match visible_form act_modal with
    | Some f ->
        let f = Ui_form.set_choice f "action_kind" 0 in
        (* Settle *)
        let f = Ui_form.set_text f "amount" "3000" in
        let f = Ui_form.set_focused f 2 in
        with_visible_form act_modal f
    | None -> failwith "expected modal form for action settlement"
  in
  let settled_state = key ~width_of act_ready `Enter in
  require (no_modal settled_state) "settle-action-submitted";
  let r2 = List.hd (settlement_rows settled_state) in
  require (Z.equal (Stl.outstanding r2) (Z.of_int 2000)) "settlement-outstanding-after-settle-2000";
  require (Z.equal r2.settled (Z.of_int 3000)) "settled-amount-3000";
  (* Reduce without payment: 1,000 jpy *)
  let act_modal2 = key ~width_of settled_state (`ASCII 'a') in
  let act_ready2 =
    match visible_form act_modal2 with
    | Some f ->
        let f = Ui_form.set_choice f "action_kind" 1 in
        (* Reduce *)
        let f = Ui_form.set_text f "amount" "1000" in
        let f = Ui_form.set_focused f 2 in
        with_visible_form act_modal2 f
    | None -> failwith "expected modal form for action settlement"
  in
  let reduced_state = key ~width_of act_ready2 `Enter in
  require (no_modal reduced_state) "reduce-action-submitted";
  let r3 = List.hd (settlement_rows reduced_state) in
  require (Z.equal (Stl.outstanding r3) (Z.of_int 1000)) "settlement-outstanding-after-reduce-1000";
  require (Z.equal r3.extinguished (Z.of_int 1000)) "extinguished-amount-1000";
  (* Full final settlement of remaining 1,000 jpy *)
  let act_modal3 = key ~width_of reduced_state (`ASCII 'a') in
  let act_ready3 =
    match visible_form act_modal3 with
    | Some f ->
        let f = Ui_form.set_choice f "action_kind" 0 in
        (* Settle *)
        let f = Ui_form.set_text f "amount" "1000" in
        let f = Ui_form.set_focused f 2 in
        with_visible_form act_modal3 f
    | None -> failwith "expected modal form for action settlement"
  in
  let fully_settled_state = key ~width_of act_ready3 `Enter in
  require (settlement_rows fully_settled_state = []) "open-rows-empty-after-full-settle";
  (* Scope cycle to All current *)
  let all_scope_state = key ~width_of fully_settled_state (`ASCII 's') in
  require
    (Settlements_screen.scope all_scope_state.C.screens.settlements = Stl.All)
    "scope-toggled-to-all";
  let all_rows = settlement_rows all_scope_state in
  require (List.length all_rows = 1) "all-scope-has-completed-row";
  let wide_all = R.screen ~width_of (120, 30) all_scope_state in
  require (contains wide_all "done") "all-scope-shows-done-marker";
  (* q returns to Home *)
  let back_home = key ~width_of all_scope_state (`ASCII 'q') in
  require (back_home.workspace.route = W.Home) "settlements-q-back-to-home";
  (* Disk persistence verify *)
  let stl_file =
    get (Settlement_file.load_file (Settlement_file.file_path ~config_home:directory path))
  in
  require (List.length stl_file.rows = 1) "settlements-persisted-to-file";
  back_home
