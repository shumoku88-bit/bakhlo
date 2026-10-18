(* Synthetic controller integration checks; see docs/RECONSTRUCTION_TEST_MAP.ja.md. *)
open Interaction_check_fixture

let run ~width_of ~directory ~path =
  (* Manage Loci workflow verification *)
  let current_home = C.initial ~config_home:directory (F.load path) in
  let loci_state = C.open_route current_home W.Loci in
  require (loci_state.workspace.route = W.Loci) "open-route-loci";
  let loci_modal_add = key ~width_of loci_state (`ASCII 'n') in
  require (C.is_admit_locus loci_modal_add.overlay) "loci-n-opens-admit-form";
  let admit_form_ready =
    match loci_modal_add.overlay with
    | C.Modal_form f ->
        let f2 = Ui_form.set_text f "token" "metro" in
        let f3 = Ui_form.set_choice f2 "role" 1 in (* Asset *)
        let f4 = Ui_form.set_focused f3 2 in (* focus confirm button *)
        { loci_modal_add with overlay = C.Modal_form f4 }
    | _ -> failwith "expected modal form for admit locus"
  in
  let admitted_state = key ~width_of admit_form_ready `Enter in
  require (admitted_state.overlay = C.No_overlay) "admit-locus-submitted";
  let all_loci = X.admitted_loci admitted_state in
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
    { admitted_state with workspace = { admitted_state.workspace with loci = { admitted_state.workspace.loci with selected = sel_idx } } }
  in
  let role_modal = key ~width_of state_on_metro (`ASCII 'r') in
  require (C.is_set_locus_role role_modal.overlay) "loci-r-opens-set-role-form";
  let role_form_ready =
    match role_modal.overlay with
    | C.Modal_form f ->
        let f2 = Ui_form.set_choice f "role" 5 in (* Expense *)
        let f3 = Ui_form.set_focused f2 1 in (* focus confirm button *)
        { role_modal with overlay = C.Modal_form f3 }
    | _ -> failwith "expected modal form for set locus role"
  in
  let updated_role_state = key ~width_of role_form_ready `Enter in
  require (updated_role_state.overlay = C.No_overlay) "set-locus-role-submitted";
  let roles_final = X.accounting_roles updated_role_state in
  require (List.assoc_opt "metro" roles_final = Some Roles.Expense) "locus-role-updated-to-expense";
  (* Locus label edit test (UI-30) *)
  let label_edit_modal = key ~width_of updated_role_state (`ASCII 'l') in
  require (match label_edit_modal.overlay with C.Modal_form f -> Ui_form.id f = "set_locus_label" | _ -> false) "l-opens-set-locus-label";
  let label_form_ready =
    match label_edit_modal.overlay with
    | C.Modal_form f ->
        let f = Ui_form.set_text f "label" "Subway Metro" in
        let f = Ui_form.set_text f "help" "Commute subway pass" in
        let f = Ui_form.set_focused f 2 in (* focus confirm button *)
        { label_edit_modal with overlay = C.Modal_form f }
    | _ -> failwith "expected modal form for set locus label"
  in
  let label_review_modal = key ~width_of label_form_ready `Enter in
  require (match label_review_modal.overlay with C.Modal_form f -> Ui_form.id f = "review_locus_label" | _ -> false) "label-form-enters-review";
  (* Test Esc returns to draft *)
  let back_to_label_form = key ~width_of label_review_modal `Escape in
  require (match back_to_label_form.overlay with C.Modal_form f -> Ui_form.id f = "set_locus_label" | _ -> false) "label-esc-returns-to-edit";
  let re_review = key ~width_of back_to_label_form `Enter in
  require (match re_review.overlay with C.Modal_form f -> Ui_form.id f = "review_locus_label" | _ -> false) "label-form-re-review";
  (* Small terminal refusal *)
  let narrow = key ~dimensions:(30, 10) ~width_of re_review `Enter in
  require (match narrow.overlay with C.Modal_form f -> Ui_form.notice f = "Enlarge the terminal to review locus label before saving." | _ -> false) "label-save-rejects-narrow-terminal";
  (* Normal terminal save *)
  let label_saved = key ~width_of re_review `Enter in
  require (label_saved.overlay = C.No_overlay) "label-save-succeeds";
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
  require (C.is_exchange exch_modal.overlay) "commands-opens-exchange-form";
  (* Validate error on same measure *)
  let err_form =
    match exch_modal.overlay with
    | C.Modal_form f ->
        let f = Ui_form.set_text f "source_locus" "wallet" in
        let f = Ui_form.set_text f "source_measure" "jpy" in
        let f = Ui_form.set_text f "source_amount" "100" in
        let f = Ui_form.set_text f "destination_locus" "bank" in
        let f = Ui_form.set_text f "destination_measure" "jpy" in
        let f = Ui_form.set_text f "destination_amount" "100" in
        let f = Ui_form.set_focused f 8 in (* action buttons *)
        { exch_modal with overlay = C.Modal_form f }
    | _ -> failwith "expected modal form for exchange"
  in
  let err_submitted = key ~width_of err_form `Enter in
  require (match err_submitted.overlay with
           | C.Modal_form f -> Ui_form.notice f = "Source and destination Measures must differ."
           | _ -> false)
    "exchange-rejects-same-measure";
  (* Successful exchange JPY -> EUR *)
  let ok_form =
    match err_submitted.overlay with
    | C.Modal_form f ->
        let f = Ui_form.set_text f "date" "2026-10-14" in
        let f = Ui_form.set_text f "memo" "Exchange JPY to EUR" in
        let f = Ui_form.set_text f "source_locus" "wallet" in
        let f = Ui_form.set_text f "source_measure" "jpy" in
        let f = Ui_form.set_text f "source_amount" "1500" in
        let f = Ui_form.set_text f "destination_locus" "bank" in
        let f = Ui_form.set_text f "destination_measure" "eur" in
        let f = Ui_form.set_text f "destination_amount" "10.00" in
        let f = Ui_form.set_focused f 8 in
        { err_submitted with overlay = C.Modal_form f }
    | _ -> failwith "expected modal form for exchange"
  in
  let exch_preview = key ~width_of ok_form `Enter in
  require (match exch_preview.overlay with C.Modal_form f -> Ui_form.id f = "review_exchange" | _ -> false) "exchange-preview-opened";
  (* Test Esc returns to draft *)
  let back_to_form = key ~width_of exch_preview `Escape in
  require (match back_to_form.overlay with C.Modal_form f -> Ui_form.id f = "exchange" | _ -> false) "exchange-esc-returns-to-edit";
  (* Enter again to preview *)
  let exch_preview2 = key ~width_of back_to_form `Enter in
  require (match exch_preview2.overlay with C.Modal_form f -> Ui_form.id f = "review_exchange" | _ -> false) "exchange-preview2-opened";
  (* Publish *)
  let exch_done = key ~width_of exch_preview2 `Enter in
  require (exch_done.overlay = C.No_overlay) "exchange-committed";
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
