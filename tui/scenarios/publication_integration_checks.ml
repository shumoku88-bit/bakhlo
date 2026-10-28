(* Publication through the Shell: saves, conflicts, reloads and cold read-back on synthetic
   books. *)
open Interaction_check_fixture
open Interaction_render_fixture

let run ~width_of ~directory ~path (home : C.state) =
  Retained_record_publication_checks.run ~width_of ~directory home;
  let before = F.read path in
  require (home.workspace.route = W.Home && not home.record_visible) "english-starts-bonsai-home";
  let actual = key ~width_of home `Enter in
  require (actual.workspace.route = W.Actual) "home-enter-opens-actual";
  require ((key ~width_of actual `Escape).workspace.route = W.Home) "actual-esc-returns-home";
  let selected = C.open_route home (W.Selected_day home.workspace.focus_day) in
  require ((key ~width_of selected (`ASCII 'q')).workspace.route = W.Home) "child-q-does-not-quit";
  require (H.handle home (`Key (`ASCII 'q', [])) = None) "home-q-exits";
  let outside_paste =
    match H.handle home (`Paste `Start) with
    | Some state -> state
    | None -> raise (F.Refused "paste-start-exited")
  in
  let outside_paste = key ~width_of (key ~width_of outside_paste (`ASCII 'r')) (`ASCII 'j') in
  let outside_paste =
    match H.handle outside_paste (`Paste `End) with
    | Some state -> state
    | None -> raise (F.Refused "paste-end-exited")
  in
  require
    (same_workspace outside_paste home
    && (not outside_paste.record_visible)
    && (not (C.has_record_draft outside_paste))
    && F.read path = before)
    "paste-executed-home-commands";
  require (get (Day.shift_months "2024-01-31" 1) = "2024-02-29") "calendar-month-clamp";
  require (get (Day.shift_years "2024-02-29" 1) = "2025-02-28") "calendar-year-clamp";
  require
    (get (Day.weekday "0001-01-01") = 0 && get (Day.weekday "2026-10-11") = 6)
    "calendar-weekday";
  require
    (Result.is_error (Day.shift_days "0001-01-01" (-1))
    && Result.is_error (Day.shift_days "9999-12-31" 1))
    "calendar-boundary";
  let opened = key ~width_of home (`ASCII ' ') in
  (match R.overlay_screen ~dimensions:(80, 24) ~width_of opened with
  | None -> failwith "commands-overlay-missing"
  | Some rows ->
      require
        (List.exists
           (fun (_, text) -> Base.String.is_substring text ~substring:"Home / Commands")
           rows)
        "commands-header-path-visible";
      require
        (List.exists
           (fun (_, text) -> Base.String.is_substring text ~substring:"Choose a command group.")
           rows)
        "commands-header-description-visible";
      require
        (List.exists (fun (_, text) -> Base.String.is_substring text ~substring:"select") rows)
        "commands-footer-navigation-visible";
      require
        (List.exists
           (fun (style, text) ->
             style = C.Active && Base.String.is_substring text ~substring:"> Transactions")
           rows)
        "commands-active-selection-visible");
  let menu =
    opened |> fun s ->
    key ~width_of s (`Arrow `Down) |> fun s -> key ~width_of s (`Arrow `Right)
  in
  require
    (match menu.overlay with C.Commands { page = M.Planning; _ } -> true | _ -> false)
    "commands-enter-group";
  (match R.overlay_screen ~dimensions:(80, 24) ~width_of menu with
  | None -> failwith "commands-group-overlay-missing"
  | Some rows ->
      require
        (List.exists
           (fun (_, text) ->
             Base.String.is_substring text ~substring:"Commands / Plans and attention")
           rows)
        "commands-group-header-path-visible";
      require
        (List.exists
           (fun (_, text) -> Base.String.is_substring text ~substring:"Scheduled household work.")
           rows)
        "commands-group-header-description-visible");
  let leaf = key ~width_of menu (`Arrow `Right) in
  require (leaf.overlay = menu.overlay && same_workspace leaf menu) "right-leaf-no-action";
  let parent = key ~width_of leaf `Escape in
  require
    (match parent.overlay with C.Commands { page = M.Root; selected = 1 } -> true | _ -> false)
    "commands-parent-selection";
  let scheduled = key ~width_of menu `Enter in
  require (scheduled.workspace.route = W.Scheduled) "commands-scheduled-route";
  let contains rows needle =
    List.exists (fun (_, text) -> Base.String.is_substring text ~substring:needle) rows
  in
  let inspected = key ~width_of scheduled (`ASCII 'i') in
  require (plan_detail inspected && not inspected.record_visible) "scheduled-inspect-detail-only";
  let actual_view = C.open_route home W.Actual in
  let wide_actual = R.screen ~width_of (120, 30) actual_view in
  require
    (contains wide_actual "Actuals" && contains wide_actual "Details")
    "actual-wide-two-pane-visible";
  let balances_view = C.open_route home W.Balances in
  require
    (match balance_items balances_view with
    | Balance_items.Account_row { locus = "wallet"; measure = "jpy"; _ } :: _ -> true
    | _ -> false)
    "balances-initial-selection-is-first-coordinate";
  let bal_detail_open = key ~width_of balances_view `Enter in
  require (Balances.detail_focused bal_detail_open.screens.balances) "balances-enter-opens-detail";
  let bal_detail_back = key ~width_of bal_detail_open `Escape in
  require
    ((not (Balances.detail_focused bal_detail_back.screens.balances))
    && bal_detail_back.workspace.route = W.Balances)
    "balances-detail-escape-returns-to-list";
  let bal_end = key ~width_of balances_view `End in
  let count = List.length (balance_items balances_view) in
  require
    (Balances.selected bal_end.C.screens.balances = max 0 (count - 1))
    "balances-end-selects-last-row";
  let bal_home = key ~width_of bal_end `Home in
  require (Balances.selected bal_home.C.screens.balances = 0) "balances-home-selects-first-row";
  let bal_page = key ~width_of bal_home (`Page `Down) in
  require
    (Balances.selected bal_page.C.screens.balances > 0 || count <= 1)
    "balances-page-down-moves-selection";
  (* Roles are a book section: give them to a copy, so this book stays as it was. *)
  let roles_book = directory ^ "/with-roles.txt" in
  F.create_copy ~source:path ~target:roles_book;
  put_roles roles_book [ ("bank", Asset); ("food", Expense); ("wallet", Asset) ];
  let bal_with_roles = C.open_route { home with session = F.load roles_book } W.Balances in
  let bal_accounting = key ~width_of bal_with_roles (`ASCII 'v') in
  let wide_with_roles = R.screen ~width_of (120, 30) bal_accounting in
  (* As LOAM, flow roles appear in "All current balance support", below the stock sections. *)
  let accounting_text =
    List.map
      (Balance_items.balance_item_line ~book:bal_accounting.C.session.book)
      (balance_items bal_accounting)
  in
  require
    (contains wide_with_roles "Balances / Accounting"
    && contains wide_with_roles "Asset"
    && contains wide_with_roles "Net Worth"
    && List.exists (fun line -> Base.String.is_substring line ~substring:"Expense") accounting_text
    )
    "balances-v-toggles-to-accounting-roles";
  let bal_restored_current = key ~width_of bal_accounting (`ASCII 'v') in
  require
    (Balances.mode bal_restored_current.screens.balances = `Current
    && List.for_all
         (function Balance_items.Account_row _ -> true | _ -> false)
         (balance_items bal_restored_current))
    "balances-current-restores-neutral-coordinate-rows";
  let bv_path = directory ^ "/balance-view.tsv" in
  F.write_new bv_path "bank\tjpy\nwallet\tjpy\n";
  let bal_custom_bv = C.open_route { home with session = F.load path } W.Balances in
  let wide_custom_bv = R.screen ~width_of (120, 30) bal_custom_bv in
  require
    (contains wide_custom_bv "bank" && contains wide_custom_bv "wallet")
    "balances-custom-balance-view-loaded-by-default";
  let replace_balance_view bytes =
    Unix.unlink bv_path;
    F.write_new bv_path bytes
  in
  replace_balance_view "malformed row\n";
  let malformed = C.open_route (C.initial (F.load path)) W.Balances in
  require
    (contains (R.screen ~width_of (120, 30) malformed) "Balance view unavailable"
    && (not (Balances.modal (key ~width_of malformed (`ASCII 'c')).C.screens.balances))
    && F.read bv_path = "malformed row\n")
    "balance-malformed-config-never-becomes-empty-selection";
  let malformed_print = key ~width_of malformed (`ASCII 'p') in
  (match Balances.form malformed_print.screens.balances with
  | Some f ->
      require (Ui_form.id f = "balance_print_refused") "balances-malformed-config-refuses-print"
  | None -> failwith "malformed balance view unexpectedly allowed print");
  require (F.read bv_path = "malformed row\n") "balances-refused-print-does-not-write-config";
  replace_balance_view "bank\tjpy\nwallet\tjpy\n";
  let bal_print = key ~width_of bal_custom_bv (`ASCII 'p') in
  (match Balances.form bal_print.screens.balances with
  | Some f ->
      require (Ui_form.id f = "balance_print_preview") "balances-p-opens-print-preview";
      require (Ui_form.title f = "Balances / Print Preview") "balances-print-title"
  | None -> failwith "expected print preview modal");
  let bal_after_print = key ~width_of bal_print `Escape in
  require (not (Balances.modal bal_after_print.screens.balances)) "balances-print-escapes";
  let items = balance_items bal_with_roles in
  let acct_idx =
    let rec find i = function
      | [] -> 0
      | Balance_items.Account_row _ :: _ -> i
      | _ :: rest -> find (i + 1) rest
    in
    find 0 items
  in
  let bal_on_account =
    {
      bal_with_roles with
      screens =
        {
          bal_with_roles.screens with
          balances = Balances.set_selected acct_idx bal_with_roles.screens.balances;
        };
    }
  in
  let bal_obs = key ~width_of bal_on_account (`ASCII 'o') in
  (match visible_form bal_obs with
  | Some f ->
      require (Ui_form.id f = "observe_quantity") "balances-o-opens-observe-form";
      require (Ui_form.get_text f "locus" <> Some "") "balances-o-prefilled-locus";
      require (Ui_form.focused f = Ui_form.find_field_index f "amount") "balances-o-focuses-amount"
  | None -> failwith "expected observe quantity modal");
  let bal_obs_cancel = key ~width_of bal_obs `Escape in
  require (no_modal bal_obs_cancel) "balances-observe-cancel-escapes";
  (* Test toggle to Accounting view with 'v' *)
  let bal_back_acct = key ~width_of bal_custom_bv (`ASCII 'v') in
  let wide_back_acct = R.screen ~width_of (120, 30) bal_back_acct in
  require (contains wide_back_acct "Balances / Accounting") "balances-v-toggles-to-accounting";
  let pace_path = directory ^ "/daily-pace.tsv" in
  let windows_path = directory ^ "/boundary-presets.tsv" in
  F.write_new pace_path "wallet\tjpy\n";
  F.write_new windows_path
    ("test-cycle\t" ^ Clock.today () ^ "\t" ^ get (Day.shift_days (Clock.today ()) 7) ^ "\n");
  let completion = key ~width_of inspected (`ASCII 'c') in
  require completion.record_visible "scheduled-completion-explicit";
  let _ = C.discard completion in
  let plan_creating = key ~width_of scheduled (`ASCII 'n') in
  require (is_plan_create plan_creating) "scheduled-key-n-opens-plan";
  let closed_plan = key ~width_of plan_creating `Escape in
  require (no_modal closed_plan) "scheduled-plan-cancel-closes-overlay";
  let plan_editing = key ~width_of closed_plan (`ASCII 'r') in
  require
    (plan_editing.record_visible && Option.is_some plan_editing.record)
    "scheduled-key-r-opens-edit";
  (match S.mode (Option.get plan_editing.record) with
  | Draft.Plan_edit _ -> ()
  | _ -> failwith "scheduled-e-mode-plan-edit");
  let closed_edit = C.discard (key ~width_of plan_editing `Escape) in
  let plan_cancelling = key ~width_of closed_edit (`ASCII 'x') in
  let cancelled_overlay = key ~width_of plan_cancelling `Escape in
  require
    (same_workspace cancelled_overlay closed_edit && F.read path = before)
    "scheduled-cancel-escape-retains-parent-and-bytes";
  let date_only =
    Option.get
      (H.handle ~width_of
         (key ~width_of (key ~width_of home (`ASCII 'r')) `Tab)
         (`Key (`Tab, [ `Shift ])))
  in
  let date_only = key ~width_of date_only `Backspace in
  let held_date = key ~width_of date_only `Escape in
  let resumed_date = key ~width_of held_date (`ASCII 'r') in
  require
    (C.has_record_draft held_date && resumed_date.record = held_date.record && F.read path = before)
    "record-date-only-draft-survives-cancel-and-resume";
  let draft = prepare_record ~width_of home in
  require (C.has_record_draft draft) "controller-record-draft";
  let review = key ~width_of draft `Enter in
  require (F.read path = before) "preview-published";
  let edit = key ~width_of (key ~width_of review `Tab) `Enter in
  require (C.has_record_draft edit && F.read path = before) "preview-edit-lost-draft";
  let cancelled = key ~width_of edit `Escape in
  require ((not cancelled.record_visible) && C.has_record_draft cancelled) "cancel-lost-held-draft";
  let request_discard state =
    Option.get (H.handle ~width_of state (`Key (`ASCII 'n', [ `Ctrl ])))
  in
  let confirming = request_discard cancelled in
  require
    (confirming.record = cancelled.record && C.has_record_draft confirming && F.read path = before)
    "discard-shortcut-must-not-delete-without-confirmation";
  require
    (match confirming.overlay with
    | C.Modal_form form -> (
        match Ui_form.get_selected_button form with
        | Some button -> button.is_cancel
        | None -> false)
    | _ -> false)
    "discard-confirmation-defaults-to-keep";
  let kept = key ~width_of confirming `Enter in
  let escaped = key ~width_of confirming `Escape in
  require
    (kept.record = cancelled.record && escaped.record = cancelled.record
   && same_workspace kept cancelled && no_modal kept)
    "discard-keep-and-escape-retain-exact-draft-and-parent";
  let selected = key ~width_of confirming (`Arrow `Right) in
  let tiny = key ~dimensions:(32, 9) ~width_of selected `Enter in
  require
    (tiny.record = cancelled.record && C.has_record_draft tiny)
    "discard-unreadable-confirmation-refused";
  let kept_after_resize = key ~width_of tiny `Enter in
  require
    (kept_after_resize.record = cancelled.record && no_modal kept_after_resize)
    "discard-tiny-refusal-resets-protective-choice";
  let discarded = key ~width_of selected `Enter in
  require
    (discarded.record = None && (not discarded.record_visible)
    && same_workspace discarded cancelled
    && F.read path = before)
    "discard-explicit-choice-clears-only-draft-without-writing";
  require (request_discard discarded == discarded) "discard-without-draft-is-noop";
  let uncertain =
    {
      cancelled with
      pending = Some (Publication.Expected_revision (F.revision_of_bytes before));
      pending_record_publication = true;
      blocked = true;
      message = "Publication outcome is unknown; do not retry.";
    }
  in
  let uncertain_choice = key ~width_of (request_discard uncertain) (`Arrow `Right) in
  let uncertain_tiny = key ~dimensions:(32, 9) ~width_of uncertain_choice `Enter in
  require
    (uncertain_tiny.message = uncertain.message && uncertain_tiny.record = uncertain.record)
    "discard-tiny-refusal-preserves-uncertain-warning-and-draft";
  let uncertain_refused = key ~width_of uncertain_choice `Enter in
  require
    (uncertain_refused.blocked
    && uncertain_refused.pending = uncertain.pending
    && uncertain_refused.record = uncertain.record
    && F.read path = before)
    "discard-confirmation-cannot-clear-unconfirmed-publication";
  let navigated = key ~width_of cancelled (`ASCII 'l') in
  require (C.has_record_draft navigated) "calendar-navigation-lost-draft";
  let resumed = key ~width_of navigated (`ASCII 'r') in
  let review = key ~width_of resumed `Enter in
  let tiny = key ~dimensions:(24, 8) ~width_of review `Enter in
  require (tiny.record_visible && F.read path = before) "tiny-publish-bypassed-review";
  let published = key ~width_of review `Enter in
  require
    ((not (C.has_record_draft published)) && not published.record_visible)
    "published-draft-not-cleared";
  let cold = F.load path in
  let entries = B.entries cold.book in
  require
    (List.length entries = 1 && (List.hd entries).memo = Some "English UI / 日本語のメモ")
    "english-record-cold-roundtrip";
  require
    (Book_display.quantity ~book:cold.book ~measure:"jpy" "wallet" = "963")
    "english-record-exact-balance";
  require
    (Book_display.quantity ~book:cold.book ~measure:"jpy" "bank" = "Unknown")
    "unknown-not-zero";
  let actual_screen = C.open_route published W.Actual in
  let actual_editing = key ~width_of actual_screen (`ASCII 'c') in
  require
    (actual_editing.record_visible && Option.is_some actual_editing.record)
    "actual-key-c-opens-edit";
  (match S.mode (Option.get actual_editing.record) with
  | Draft.Edit _ -> ()
  | _ -> failwith "actual-c-mode-edit");
  let closed_actual_edit = C.discard (key ~width_of actual_editing `Escape) in
  let actual_reversing = key ~width_of closed_actual_edit (`ASCII 'x') in
  require (is_reversal actual_reversing) "actual-key-x-opens-reverse-overlay";
  let reversal_preview = key ~width_of actual_reversing `Enter in
  require (F.read_revision path = cold.revision) "reversal-date-enter-is-preview-only";
  let reversed = key ~width_of reversal_preview `Enter in
  require (not (C.has_record_draft reversed)) "reversed-draft-clean";
  let cold_after_reverse = F.load path in
  let entries_after_reverse = B.entries cold_after_reverse.book in
  require (List.length entries_after_reverse = 2) "reversal-entry-published";
  let rev_entry = List.find (fun (e : B.entry) -> e.reversal_of <> None) entries_after_reverse in
  let orig_entry = List.find (fun (e : B.entry) -> e.reversal_of = None) entries_after_reverse in
  require (rev_entry.reversal_of = Some orig_entry.id) "reversal-links-to-original";
  let actual_after = C.open_route { reversed with session = cold_after_reverse } W.Actual in
  let try_double_reverse = key ~width_of actual_after (`ASCII 'x') in
  require
    (no_modal try_double_reverse && try_double_reverse.message <> "")
    "double-reversal-blocked";
  let cancel_ledger_path = directory ^ "/cancel_plan.txt" in
  F.write_new cancel_ledger_path (F.read path);
  let cancel_session = F.load cancel_ledger_path in
  let cancel_ctl = C.initial cancel_session |> fun s -> C.open_route s W.Scheduled in
  let cancel_modal = key ~width_of cancel_ctl (`ASCII 'x') in
  let cancel_preview = key ~width_of cancel_modal `Enter in
  require
    (F.read_revision cancel_ledger_path = cancel_session.revision)
    "cancel-date-enter-only-previews";
  let kept = key ~width_of cancel_preview `Enter in
  require
    (F.read_revision cancel_ledger_path = cancel_session.revision && same_workspace kept cancel_ctl)
    "cancel-preview-default-keeps-plan";
  let cancel_done =
    key ~width_of kept (`ASCII 'x') |> fun s ->
    key ~width_of s `Enter |> fun s ->
    key ~width_of s `Tab |> fun s -> key ~width_of s `Enter
  in
  let cancelled_cold = F.load cancel_ledger_path in
  let p = List.hd (B.plans cancelled_cold.book) in
  require (p.cancelled_on <> None) "plan-cold-cancelled-on-set";
  let re_cancel = key ~width_of cancel_done (`ASCII 'x') in
  require (no_modal re_cancel && re_cancel.message <> "") "already-cancelled-cancel-refused";
  let re_edit = key ~width_of cancel_done (`ASCII 'e') in
  require ((not re_edit.record_visible) && re_edit.message <> "") "already-cancelled-edit-refused";
  let re_pay = key ~width_of cancel_done (`ASCII 'c') in
  require ((not re_pay.record_visible) && re_pay.message <> "") "already-cancelled-pay-refused";
  let stopped = { home with blocked = true; message = "household-warning" } in
  require (C.submit stopped == stopped) "blocked-submit-identity";
  let moved = key ~width_of stopped (`ASCII 'l') in
  require (moved.blocked && moved.message = stopped.message) "navigation-hid-stop";
  List.iter
    (fun dimensions ->
      List.iter
        (fun state ->
          let rows = R.screen ~width_of dimensions state in
          require
            (List.length rows <= snd dimensions
            && List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows)
            "controller-terminal-cell-geometry")
        (review :: render_cases home))
    [ (48, 14); (80, 24); (140, 40); (20, 5) ];
  ()
