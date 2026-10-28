(* Synthetic controller integration checks; see docs/RECONSTRUCTION_TEST_MAP.ja.md. *)
open Interaction_check_fixture

(* The roles the Shell reads from the book. *)
let roles_of state = B.roles state.C.session.book

(* Roles are a book section: a malformed ROLE line refuses the whole book, so no
   screen ever sees unreadable roles. *)
let unreadable_roles_checks ~directory ~path =
  let directory = directory ^ "/unreadable-roles" in
  Unix.mkdir directory 0o700;
  let book_path = directory ^ "/book.txt" in
  F.create_copy ~source:path ~target:book_path;
  (* Roles are a book section: a malformed ROLE line refuses the whole book. *)
  let bad_path = directory ^ "/bad-role.txt" in
  F.write_new bad_path
    (Base.String.substr_replace_first (F.read book_path) ~pattern:"\nPLAN\t"
       ~with_:"\nROLE\twallet\tASSETS\nPLAN\t");
  require
    (match F.load bad_path with _ -> false | exception F.Refused _ -> true)
    "book-with-unreadable-role-refuses"

let run ~width_of ~directory ~path =
  unreadable_roles_checks ~directory ~path;
  (* Manage Loci workflow verification *)
  let current_home = C.initial ~config_home:directory (F.load path) in
  let loci_state = C.open_route current_home W.Loci in
  require (loci_state.workspace.route = W.Loci) "open-route-loci";
  let loci_count = List.length (Loci_screen.admitted_loci loci_state.session.book) in
  let loci_selected state = Loci_screen.selected state.C.screens.loci in
  require (loci_count >= 3) "loci-fixture-has-three-loci";
  let loci_end = key ~width_of loci_state `End in
  require (loci_selected loci_end = loci_count - 1) "loci-end-selects-last";
  let loci_before_end = key ~width_of loci_end (`ASCII 'k') in
  let loci_page_down = key ~width_of loci_before_end (`Page `Down) in
  require (loci_selected loci_page_down = loci_count - 1) "loci-page-down-stops-at-last";
  let loci_page_up = key ~width_of loci_page_down (`Page `Up) in
  require (loci_selected loci_page_up < loci_count - 1) "loci-page-up-moves-back";
  let loci_home = key ~width_of loci_page_up `Home in
  require (loci_selected loci_home = 0) "loci-home-selects-first";
  let loci_page_from_home = key ~width_of loci_home (`Page `Down) in
  require (loci_selected loci_page_from_home > 0) "loci-page-down-moves-forward";
  let loci_modal_add = key ~width_of loci_state (`ASCII 'n') in
  require (visible_form_id loci_modal_add = Some "admit_locus") "loci-n-opens-admit-form";
  let admit_form_ready =
    match visible_form loci_modal_add with
    | Some f ->
        let f2 = Ui_form.set_text f "token" "metro" in
        let f3 = Ui_form.set_choice f2 "role" 1 in
        (* Asset *)
        let f4 = Ui_form.set_focused f3 2 in
        (* focus confirm button *)
        with_visible_form loci_modal_add f4
    | None -> failwith "expected modal form for admit locus"
  in
  let admitted_state = key ~width_of admit_form_ready `Enter in
  require (no_modal admitted_state) "admit-locus-submitted";
  let all_loci = Loci_screen.admitted_loci admitted_state.session.book in
  require (List.mem "metro" all_loci) "admitted-locus-present-in-catalog";
  let roles_after = roles_of admitted_state in
  require (List.assoc_opt "metro" roles_after = Some Roles.Asset) "admitted-locus-has-asset-role";
  let select state locus =
    let loci = Loci_screen.admitted_loci state.C.session.book in
    let rec find i = function
      | [] -> failwith ("locus not admitted: " ^ locus)
      | x :: rest -> if x = locus then i else find (i + 1) rest
    in
    List.fold_left
      (fun state _ -> key ~width_of state (`ASCII 'j'))
      (key ~width_of state `Home)
      (List.init (find 0 loci) Fun.id)
  in
  (* Roles are an initial assignment only: never replaced, but a used Locus without
     one may receive it. *)
  let replace_refused = key ~width_of (select admitted_state "metro") (`ASCII 'r') in
  require
    (no_modal replace_refused
    && replace_refused.message
       = C.tr "This Locus already has an accounting role; roles are never replaced.")
    "loci-r-refuses-role-replacement";
  require
    (List.assoc_opt "metro" (roles_of replace_refused) = Some Roles.Asset)
    "loci-refused-replacement-keeps-role";
  (* Admission requires a role: an empty choice is refused and nothing is admitted. *)
  let admit_modal = key ~width_of admitted_state (`ASCII 'n') in
  let admit_without_role =
    match visible_form admit_modal with
    | Some f ->
        let f = Ui_form.set_focused (Ui_form.set_text f "token" "bus") 2 in
        key ~width_of (with_visible_form admit_modal f) `Enter
    | None -> failwith "expected modal form for admit locus"
  in
  require
    (match visible_form admit_without_role with
    | Some f -> Ui_form.notice f = "Choose an accounting role."
    | None -> false)
    "admit-locus-requires-a-role";
  require
    (not (List.mem "bus" (Loci_screen.admitted_loci admit_without_role.session.book)))
    "admit-without-role-admits-nothing";
  (* A used Locus without a role (food here) receives its first role once. *)
  let used_home = directory ^ "/used-locus-role" in
  Unix.mkdir used_home 0o700;
  F.create_copy ~source:path ~target:(used_home ^ "/book.txt");
  put_roles (used_home ^ "/book.txt") [ ("wallet", Asset) ];
  let used_state = C.initial ~config_home:used_home (F.load (used_home ^ "/book.txt")) in
  let used_loci = C.open_route used_state W.Loci in
  require
    (List.exists
       (fun (e : B.entry) ->
         List.exists (fun p -> Draft.lstr (D.Effect.locus p) = "food") e.effects)
       (B.entries used_loci.session.book))
    "fixture-food-is-used";
  require
    (List.exists
       (fun (_, row) -> Base.String.is_substring row ~substring:"without role)")
       (R.screen ~width_of (100, 30) used_loci))
    "loci-title-counts-loci-without-role";
  let role_modal = key ~width_of (select used_loci "food") (`ASCII 'r') in
  require (visible_form_id role_modal = Some "set_locus_role") "loci-r-opens-for-used-locus";
  let submit_role state choice =
    match visible_form state with
    | Some f ->
        let f = Ui_form.set_focused (Ui_form.set_choice f "role" choice) 1 in
        (* confirm button *)
        key ~width_of (with_visible_form state f) `Enter
    | None -> failwith "expected modal form for set locus role"
  in
  let no_choice = submit_role role_modal 0 in
  require
    (match visible_form no_choice with
    | Some f -> Ui_form.notice f = "Choose an accounting role."
    | None -> false)
    "loci-role-requires-a-choice";
  let assigned = submit_role no_choice 5 in
  (* Expense *)
  require (no_modal assigned) "set-locus-role-submitted";
  require
    (List.assoc_opt "food" (roles_of assigned) = Some Roles.Expense)
    "used-locus-role-assigned-once";
  require (no_modal (key ~width_of assigned (`ASCII 'r'))) "loci-r-refuses-after-initial-assignment";
  let updated_role_state = select (key ~width_of admit_without_role `Escape) "metro" in
  (* Locus label edit test (UI-30) *)
  let label_edit_modal = key ~width_of updated_role_state (`ASCII 'l') in
  require
    (match visible_form label_edit_modal with
    | Some f -> Ui_form.id f = "set_locus_label"
    | None -> false)
    "l-opens-set-locus-label";
  let label_form_ready =
    match visible_form label_edit_modal with
    | Some f ->
        let f = Ui_form.set_text f "label" "Subway Metro" in
        let f = Ui_form.set_text f "help" "Commute subway pass" in
        let f = Ui_form.set_focused f 2 in
        (* focus confirm button *)
        with_visible_form label_edit_modal f
    | None -> failwith "expected modal form for set locus label"
  in
  let label_review_modal = key ~width_of label_form_ready `Enter in
  require
    (match visible_form label_review_modal with
    | Some f -> Ui_form.id f = "review_locus_label"
    | None -> false)
    "label-form-enters-review";
  (* Test Esc returns to draft *)
  let back_to_label_form = key ~width_of label_review_modal `Escape in
  require
    (match visible_form back_to_label_form with
    | Some f -> Ui_form.id f = "set_locus_label"
    | None -> false)
    "label-esc-returns-to-edit";
  let re_review = key ~width_of back_to_label_form `Enter in
  require
    (match visible_form re_review with
    | Some f -> Ui_form.id f = "review_locus_label"
    | None -> false)
    "label-form-re-review";
  (* Small terminal refusal *)
  let narrow = key ~dimensions:(30, 10) ~width_of re_review `Enter in
  require
    (match visible_form narrow with
    | Some f -> Ui_form.notice f = "Enlarge the terminal to review locus label before saving."
    | None -> false)
    "label-save-rejects-narrow-terminal";
  (* Normal terminal save *)
  let label_saved = key ~width_of re_review `Enter in
  require (no_modal label_saved) "label-save-succeeds";
  require (B.label label_saved.session.book "metro" = "Subway Metro") "metro-label-updated";
  require (B.help label_saved.session.book "metro" = "Commute subway pass") "metro-help-updated";
  let narrow_lines = R.screen ~width_of (80, 24) label_saved |> List.map snd in
  require
    (List.exists
       (fun line ->
         Base.String.is_substring line ~substring:"metro"
         && Base.String.is_substring line ~substring:"Subway Metro")
       narrow_lines)
    "loci-80x24-list-keeps-label";
  require
    (List.exists (fun line -> Base.String.is_substring line ~substring:"represents") narrow_lines)
    "loci-80x24-detail-wraps-between-words";
  let reloaded_locus_book = (F.load path).book in
  require (B.label reloaded_locus_book "metro" = "Subway Metro") "metro-label-cold-reloaded";
  require (B.help reloaded_locus_book "metro" = "Commute subway pass") "metro-help-cold-reloaded";
  let loci_back = key ~width_of label_saved (`ASCII 'q') in
  require (loci_back.workspace.route = W.Home) "loci-q-back-to-home";
  (* Exchange test *)
  let cmd_root = key ~width_of loci_back (`ASCII ' ') in
  let tx_menu = key ~width_of cmd_root `Enter in
  let to_exch =
    key ~width_of
      (key ~width_of (key ~width_of tx_menu (`Arrow `Down)) (`Arrow `Down))
      (`Arrow `Down)
  in
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
        let f = Ui_form.set_focused f 8 in
        (* action buttons *)
        with_visible_form exch_modal f
    | None -> failwith "expected modal form for exchange"
  in
  let err_submitted = key ~width_of err_form `Enter in
  require
    (match visible_form err_submitted with
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
  require
    (match visible_form exch_preview with
    | Some f -> Ui_form.id f = "review_exchange"
    | None -> false)
    "exchange-preview-opened";
  (* Test Esc returns to draft *)
  let back_to_form = key ~width_of exch_preview `Escape in
  require
    (match visible_form back_to_form with Some f -> Ui_form.id f = "exchange" | None -> false)
    "exchange-esc-returns-to-edit";
  (* Enter again to preview *)
  let exch_preview2 = key ~width_of back_to_form `Enter in
  require
    (match visible_form exch_preview2 with
    | Some f -> Ui_form.id f = "review_exchange"
    | None -> false)
    "exchange-preview2-opened";
  (* Publish *)
  let exch_done = key ~width_of exch_preview2 `Enter in
  require (no_modal exch_done) "exchange-committed";
  require
    (exch_done.message = "Published and read back. Previous bytes are kept separately.")
    "exchange-success-message";
  let reloaded_book = (F.load path).book in
  let latest_entry = List.hd (List.rev (B.entries reloaded_book)) in
  require
    (latest_entry.exchange = Some ("exchange-source", "exchange-destination"))
    "exchange-keys-retained";
  require (latest_entry.memo = Some "Exchange JPY to EUR") "exchange-memo-retained";
  require (latest_entry.day = "2026-10-14") "exchange-day-retained";
  require (List.length latest_entry.effects = 2) "exchange-has-two-effects";
  let src_eff = List.nth latest_entry.effects 0 in
  let dst_eff = List.nth latest_entry.effects 1 in
  require (D.Identifier.Locus.to_string (D.Effect.locus src_eff) = "wallet") "exchange-source-locus";
  require
    (D.Identifier.Measure.to_string (D.Effect.measure src_eff) = "jpy")
    "exchange-source-measure";
  require
    (Z.equal (D.Quantity.quanta (D.Effect.quantity src_eff)) (Z.of_int (-1500)))
    "exchange-source-amount-negative";
  require
    (D.Identifier.Locus.to_string (D.Effect.locus dst_eff) = "bank")
    "exchange-destination-locus";
  require
    (D.Identifier.Measure.to_string (D.Effect.measure dst_eff) = "eur")
    "exchange-destination-measure";
  require
    (Z.equal (D.Quantity.quanta (D.Effect.quantity dst_eff)) (Z.of_int 1000))
    "exchange-destination-amount-positive";
  exch_done
