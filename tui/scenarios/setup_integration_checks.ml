(* Synthetic controller integration checks; see docs/RECONSTRUCTION_TEST_MAP.ja.md. *)
open Interaction_check_fixture

let run ~width_of ~directory ~path =
  (* Manage Loci workflow verification *)
  let current_home = C.initial ~config_home:directory (F.load path) in
  let loci_state = C.open_route current_home W.Loci in
  require (loci_state.workspace.route = W.Loci) "open-route-loci";
  let loci_modal_add = key ~width_of loci_state (`ASCII 'n') in
  require (visible_form_id loci_modal_add = Some "admit_locus") "loci-n-opens-admit-form";
  let admit_form_ready =
    match visible_form loci_modal_add with
    | Some f ->
        let f2 = Ui_form.set_text f "token" "metro" in
        let f3 = Ui_form.set_choice f2 "role" 1 in (* Asset *)
        let f4 = Ui_form.set_focused f3 2 in (* focus confirm button *)
        with_visible_form loci_modal_add f4
    | None -> failwith "expected modal form for admit locus"
  in
  let admitted_state = key ~width_of admit_form_ready `Enter in
  require (no_modal admitted_state) "admit-locus-submitted";
  let all_loci = Loci_screen.admitted_loci admitted_state.session.book in
  require (List.mem "metro" all_loci) "admitted-locus-present-in-catalog";
  let roles_after = X.accounting_roles admitted_state in
  require (List.assoc_opt "metro" roles_after = Some Roles.Asset) "admitted-locus-has-asset-role";
  let sel_idx =
    let rec find i = function
      | [] -> 0
      | x :: rest -> if x = "metro" then i else find (i + 1) rest
    in
    find 0 all_loci
  in
  let state_on_metro =
    List.fold_left (fun state _ -> key ~width_of state (`ASCII 'j')) admitted_state (List.init sel_idx Fun.id)
  in
  let role_modal = key ~width_of state_on_metro (`ASCII 'r') in
  require (visible_form_id role_modal = Some "set_locus_role") "loci-r-opens-set-role-form";
  let role_form_ready =
    match visible_form role_modal with
    | Some f ->
        let f2 = Ui_form.set_choice f "role" 5 in (* Expense *)
        let f3 = Ui_form.set_focused f2 1 in (* focus confirm button *)
        with_visible_form role_modal f3
    | None -> failwith "expected modal form for set locus role"
  in
  let updated_role_state = key ~width_of role_form_ready `Enter in
  require (no_modal updated_role_state) "set-locus-role-submitted";
  let roles_final = X.accounting_roles updated_role_state in
  require (List.assoc_opt "metro" roles_final = Some Roles.Expense) "locus-role-updated-to-expense";
  (* Locus label edit test (UI-30) *)
  let label_edit_modal = key ~width_of updated_role_state (`ASCII 'l') in
  require (match visible_form label_edit_modal with Some f -> Ui_form.id f = "set_locus_label" | None -> false) "l-opens-set-locus-label";
  let label_form_ready =
    match visible_form label_edit_modal with
    | Some f ->
        let f = Ui_form.set_text f "label" "Subway Metro" in
        let f = Ui_form.set_text f "help" "Commute subway pass" in
        let f = Ui_form.set_focused f 2 in (* focus confirm button *)
        with_visible_form label_edit_modal f
    | None -> failwith "expected modal form for set locus label"
  in
  let label_review_modal = key ~width_of label_form_ready `Enter in
  require (match visible_form label_review_modal with Some f -> Ui_form.id f = "review_locus_label" | None -> false) "label-form-enters-review";
  (* Test Esc returns to draft *)
  let back_to_label_form = key ~width_of label_review_modal `Escape in
  require (match visible_form back_to_label_form with Some f -> Ui_form.id f = "set_locus_label" | None -> false) "label-esc-returns-to-edit";
  let re_review = key ~width_of back_to_label_form `Enter in
  require (match visible_form re_review with Some f -> Ui_form.id f = "review_locus_label" | None -> false) "label-form-re-review";
  (* Small terminal refusal *)
  let narrow = key ~dimensions:(30, 10) ~width_of re_review `Enter in
  require (match visible_form narrow with Some f -> Ui_form.notice f = "Enlarge the terminal to review locus label before saving." | None -> false) "label-save-rejects-narrow-terminal";
  (* Normal terminal save *)
  let label_saved = key ~width_of re_review `Enter in
  require (no_modal label_saved) "label-save-succeeds";
  require (B.label label_saved.session.book "metro" = "Subway Metro") "metro-label-updated";
  require (B.help label_saved.session.book "metro" = "Commute subway pass") "metro-help-updated";
  let reloaded_locus_book = (F.load path).book in
  require (B.label reloaded_locus_book "metro" = "Subway Metro") "metro-label-cold-reloaded";
  require (B.help reloaded_locus_book "metro" = "Commute subway pass") "metro-help-cold-reloaded";
  let loci_back = key ~width_of label_saved (`ASCII 'q') in
  require (loci_back.workspace.route = W.Home) "loci-q-back-to-home";
  (* Exchange test *)
  let cmd_root = key ~width_of loci_back (`ASCII ' ') in
  let tx_menu = key ~width_of cmd_root `Enter in
  let to_exch = key ~width_of (key ~width_of (key ~width_of tx_menu (`Arrow `Down)) (`Arrow `Down)) (`Arrow `Down) in
  let exch_modal = key ~width_of to_exch `Enter in
  require (visible_form_id exch_modal = Some "exchange") "commands-opens-exchange-form";
  (* Validate error on same measure *)
  let err_form =
    match visible_form exch_modal with
    | Some f ->
        let f = Ui_form.set_text f "source_locus" "wallet" in
        let f = Ui_form.set_text f "source_measure" "jpy" in
        let f = Ui_form.set_text f "source_amount" "100" in
        let f = Ui_form.set_text f "destination_locus" "bank" in
        let f = Ui_form.set_text f "destination_measure" "jpy" in
        let f = Ui_form.set_text f "destination_amount" "100" in
        let f = Ui_form.set_focused f 8 in (* action buttons *)
        with_visible_form exch_modal f
    | None -> failwith "expected modal form for exchange"
  in
  let err_submitted = key ~width_of err_form `Enter in
  require (match visible_form err_submitted with
           | Some f -> Ui_form.notice f = "Source and destination Measures must differ."
           | _ -> false)
    "exchange-rejects-same-measure";
  (* Successful exchange JPY -> EUR *)
  let ok_form =
    match visible_form err_submitted with
    | Some f ->
        let f = Ui_form.set_text f "date" "2026-10-14" in
        let f = Ui_form.set_text f "memo" "Exchange JPY to EUR" in
        let f = Ui_form.set_text f "source_locus" "wallet" in
        let f = Ui_form.set_text f "source_measure" "jpy" in
        let f = Ui_form.set_text f "source_amount" "1500" in
        let f = Ui_form.set_text f "destination_locus" "bank" in
        let f = Ui_form.set_text f "destination_measure" "eur" in
        let f = Ui_form.set_text f "destination_amount" "10.00" in
        let f = Ui_form.set_focused f 8 in
        with_visible_form err_submitted f
    | None -> failwith "expected modal form for exchange"
  in
  let exch_preview = key ~width_of ok_form `Enter in
  require (match visible_form exch_preview with Some f -> Ui_form.id f = "review_exchange" | None -> false) "exchange-preview-opened";
  (* Test Esc returns to draft *)
  let back_to_form = key ~width_of exch_preview `Escape in
  require (match visible_form back_to_form with Some f -> Ui_form.id f = "exchange" | None -> false) "exchange-esc-returns-to-edit";
  (* Enter again to preview *)
  let exch_preview2 = key ~width_of back_to_form `Enter in
  require (match visible_form exch_preview2 with Some f -> Ui_form.id f = "review_exchange" | None -> false) "exchange-preview2-opened";
  (* Publish *)
  let exch_done = key ~width_of exch_preview2 `Enter in
  require (no_modal exch_done) "exchange-committed";
  require (exch_done.message = "Published and read back. Previous bytes are kept separately.") "exchange-success-message";
  let reloaded_book = (F.load path).book in
  let latest_entry = List.hd (List.rev (B.entries reloaded_book)) in
  require (latest_entry.exchange = Some ("exchange-source", "exchange-destination")) "exchange-keys-retained";
  require (latest_entry.memo = Some "Exchange JPY to EUR") "exchange-memo-retained";
  require (latest_entry.day = "2026-10-14") "exchange-day-retained";
  require (List.length latest_entry.effects = 2) "exchange-has-two-effects";
  let src_eff = List.nth latest_entry.effects 0 in
  let dst_eff = List.nth latest_entry.effects 1 in
  require (D.Identifier.Locus.to_string (D.Effect.locus src_eff) = "wallet") "exchange-source-locus";
  require (D.Identifier.Measure.to_string (D.Effect.measure src_eff) = "jpy") "exchange-source-measure";
  require (Z.equal (D.Quantity.quanta (D.Effect.quantity src_eff)) (Z.of_int (-1500))) "exchange-source-amount-negative";
  require (D.Identifier.Locus.to_string (D.Effect.locus dst_eff) = "bank") "exchange-destination-locus";
  require (D.Identifier.Measure.to_string (D.Effect.measure dst_eff) = "eur") "exchange-destination-measure";
  require (Z.equal (D.Quantity.quanta (D.Effect.quantity dst_eff)) (Z.of_int 1000)) "exchange-destination-amount-positive";
  exch_done
