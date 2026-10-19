(* Synthetic controller integration checks; see docs/RECONSTRUCTION_TEST_MAP.ja.md. *)
open Interaction_check_fixture

let scheduled_panel_checks ~width_of ~directory home =
  let huge = Z.of_string (String.make 600 '9') in
  let plan n : B.plan = {id=Printf.sprintf "panel-plan-%02d-%s" n (String.make 180 'p');
    day=Printf.sprintf "2026-10-%02d" (n+1); measure="jpy";
    changes=["wallet", Z.neg huge; "food", huge]; paid_by=None; cancelled_on=None} in
  let book = List.fold_left (fun book n -> get (B.put_plan book ~replace:false (plan n)))
    home.C.session.book (List.init 20 Fun.id) in
  let path = directory ^ "/scheduled-panels.sexp" in
  F.write_new path (B.to_string book);
  let before = F.read path in
  let state = C.open_route (C.initial ~config_home:directory (F.load path)) W.Scheduled in
  let count = List.length (plan_rows state) in
  List.iter (fun dimensions ->
    let key = key ~dimensions ~width_of in
    let detail = key state `Enter in
    let height, view = plan_window ~dimensions ~width_of detail in
    let identity = (plan_id detail) in
    require (view.last>0) "scheduled-long-detail-overflows";
    let ended = key detail `End in
    require ((plan_scroll ended)=view.last && (plan_id ended)=identity)
      "scheduled-detail-end-preserves-identity";
    require ((plan_scroll (key ended (`ASCII 'j')))=view.last
      && (plan_scroll (key ended (`ASCII 'k')))=view.last-1
      && (plan_scroll (key ended `Home))=0) "scheduled-detail-endpoints-and-immediate-up";
    require ((plan_scroll (key detail (`Page `Down)))=min view.last (max 1 view.capacity))
      "scheduled-detail-page-visible-rows";
    let ctrl_down = get (match H.handle ~dimensions ~width_of detail (`Key (`ASCII 'd',[`Ctrl])) with
      | Some state -> Ok state | None -> Error "scheduled-ctrl-page-exited") in
    require ((plan_scroll ctrl_down)=(plan_scroll (key detail (`Page `Down)))) "scheduled-ctrl-page-same-capacity";
    let listed = key ended `Tab in
    let restored = key listed `Tab in
    require (not (plan_detail listed) && plan_detail restored
      && (plan_scroll restored)=(plan_scroll ended) && (plan_id restored)=identity)
      "scheduled-focus-roundtrip-retains-detail-and-selection";
    require (not (plan_detail (key detail (`ASCII 'h')))
      && plan_detail (key (key detail (`ASCII 'h')) (`ASCII 'l')))
      "scheduled-browser-horizontal-focus";
    let back = key ended `Escape in
    require (not (plan_detail back) && (plan_id back)=identity)
      "scheduled-back-keeps-selection";
    require ((plan_scroll (key ended (`ASCII 'f')))=0) "scheduled-filter-resets-detail";
    let reloaded = get (match H.handle ~dimensions ~width_of ended (`Key (`ASCII 'r',[`Ctrl])) with
      | Some state -> Ok state | None -> Error "scheduled-reload-exited") in
    require ((plan_scroll reloaded)=0 && (plan_id reloaded)=identity)
      "scheduled-reload-anchors-identity-and-resets-detail";
    let page = key state (`Page `Down) in
    require ((plan_row page)=min (count-1) (max 1 (height-2)))
      "scheduled-list-page-excludes-borders-no-heading";
    require ((plan_row (key state `End))=count-1
      && (plan_row (key (key state `End) `Home))=0) "scheduled-list-real-endpoints";
    List.iter (fun state ->
      let rows = R.screen ~width_of dimensions state in
      require (List.length rows<=snd dimensions && List.for_all (fun (_,line)->width_of line<=fst dimensions) rows)
        "scheduled-shared-panels-bounded") [state;page;ended]) [32,9;48,14;80,24;120,36];
  let small = key ~dimensions:(32,9) ~width_of state `Enter |> fun s -> key ~dimensions:(32,9) ~width_of s `End in
  let resized = key ~dimensions:(120,36) ~width_of small (`ASCII '!') in
  let _, view = plan_window ~dimensions:(120,36) ~width_of resized in
  require (view.start=view.last && (plan_id resized)=(plan_id small))
    "scheduled-resize-clamps-offset-not-identity";
  let editing = key ~width_of state (`ASCII 'e') in
  let draft = text ~width_of editing "q 日本語" in
  let closed = key ~width_of draft `Escape in
  require ((same_workspace closed state) && C.has_record_draft closed && not closed.record_visible)
    "scheduled-edit-cancel-retains-draft-and-parent";
  let resumed = X.open_command closed M.Record in
  require (S.screen ~book ~dimensions:(72,20) ~width_of (Option.get draft.record)
    = S.screen ~book ~dimensions:(72,20) ~width_of (Option.get resumed.record))
    "scheduled-draft-resumed-through-existing-record-command";
  let cancelled = key ~width_of (key ~width_of state (`ASCII 'x')) `Escape in
  require ((same_workspace cancelled state) && no_modal cancelled)
    "scheduled-cancel-overlay-return-context";
  require (F.read path=before) "scheduled-shared-panels-no-write";
  print_endline "PASS: Scheduled uses shared viewport, clamped detail/list paging, focus/resize, retained draft and cancelled action context (synthetic)."

let cancellation_checks ~width_of ~directory home =
  let plan : B.plan = { id = "cancel-target"; day = "2026-10-20"; measure = "eur";
    changes = ["wallet", Z.of_int (-120001); "food", Z.of_int 120001];
    paid_by = None; cancelled_on = None } in
  let book = get (B.put_plan home.C.session.book ~replace:false plan) in
  let path = directory ^ "/cancellation.sexp" in
  F.write_new path (B.to_string book);
  let before = F.read path in
  let base = C.open_route (C.initial ~config_home:directory (F.load path)) W.Scheduled
    |> fun s -> Interaction_check_fixture.with_plan_query s plan.id in
  let editor state = match session_of state with
    | Some (E.Scheduled_cancel e) -> e | _ -> raise (F.Refused "cancel-review-lost") in
  let input state event = match H.handle ~width_of state event with
    | Some s -> s | None -> raise (F.Refused "cancel-controller-exited") in
  let date state value =
    let state = List.fold_left (fun s _ -> key ~width_of s `Backspace)
      state (List.init (String.length (Cancel.day (editor state))) Fun.id) in
    text ~width_of state value in
  let opened = key ~width_of base (`ASCII 'x') in
  let invalid = date opened "2026-02-29" |> fun s -> key ~width_of s `Enter in
  require (not (Cancel.is_preview (editor invalid)) && F.read path = before)
    "cancel-invalid-date-does-not-preview-or-write";
  let review = date invalid "2026/10/16" |> fun s -> key ~width_of s `Enter in
  require (Cancel.is_preview (editor review) && Cancel.day (editor review) = "2026-10-16"
           && F.read path = before) "cancel-date-enter-is-read-only-preview";
  let kept = key ~width_of review `Enter in
  require ((no_modal kept) && (same_workspace kept base) && F.read path = before)
    "cancel-protective-default-keeps-plan";
  let edited = key ~width_of review (`ASCII 'e') in
  require (not (Cancel.is_preview (editor edited)) && Cancel.day (editor edited) = "2026-10-16")
    "cancel-preview-edit-retains-date";
  let selected = key ~width_of review `Tab in
  List.iter (fun dimensions ->
    let refused = key ~dimensions ~width_of selected `Enter in
    require (Cancel.is_preview (editor refused) && F.read path = before)
      "cancel-tiny-confirmation-refused") [32,9;48,14;80,14];
  List.iter (fun keycode ->
    let kept = key ~width_of selected keycode in
    require ((same_workspace kept base) && F.read path = before) "cancel-explicit-keep-never-writes")
    [`Escape; `ASCII 'q'];
  let pasted = input selected (`Paste `Start) |> fun s -> input s (`Key (`Enter, []))
    |> fun s -> input s (`Paste `End) in
  require (Cancel.is_preview (editor pasted) && Cancel.day (editor pasted) = "2026-10-16"
           && F.read path = before) "cancel-paste-cannot-confirm";
  let held = prepare_record ~width_of home |> fun s -> key ~width_of s `Escape
    |> fun s -> C.open_route s W.Scheduled in
  let guarded = key ~width_of held (`ASCII 'x') in
  require ((no_modal guarded) && guarded.record = held.record && C.has_record_draft guarded)
    "cancel-does-not-destroy-record-draft";
  let missing = { selected with session = { selected.session with path = directory ^ "/absent-cancel/book.sexp" } } in
  let failed = key ~width_of missing `Enter in
  require (Cancel.day (editor failed) = "2026-10-16" && Cancel.base_bytes (editor failed) = before
           && F.read path = before) "cancel-storage-failure-keeps-date-target-and-base";
  let kept_failed = key ~width_of failed `Enter in
  require ((no_modal kept_failed) && F.read path = before) "cancel-failure-resets-choice-to-keep";
  let records_path = directory ^ "/cancellation-records.sexp" in
  F.write_new records_path (B.to_records_string book);
  let records = { base with session = F.load records_path } in
  let records_bytes = F.read records_path in
  let refused = key ~width_of records (`ASCII 'x') |> fun s -> key ~width_of s `Enter
    |> fun s -> key ~width_of s `Tab |> fun s -> key ~width_of s `Enter in
  require (Cancel.is_preview (editor refused) && F.read records_path = records_bytes)
    "cancel-records-refusal-keeps-confirmation-without-write";
  let saved = key ~width_of selected `Enter in
  let cold = F.load path in
  require ((no_modal saved)
           && List.find (fun (p : B.plan) -> p.id = plan.id) (B.plans cold.book)
              = { plan with cancelled_on = Some "2026-10-16" }
           && B.entries cold.book = B.entries book
           && Daily_overlays.quantity ~book:cold.book ~measure:"jpy" "wallet"
              = Daily_overlays.quantity ~book ~measure:"jpy" "wallet")
    "cancel-cold-retains-target-due-exact-effects-and-actual-balance";
  let stale = key ~width_of selected `Enter in
  require (stale.blocked && Cancel.base_bytes (editor stale) = before && F.read path = cold.bytes)
    "cancel-stale-confirmation-stops";
  let reloaded = input selected (`Key (`ASCII 'r', [`Ctrl])) |> fun s -> key ~width_of s `Enter in
  require (reloaded.blocked && Cancel.base_bytes (editor reloaded) = before && F.read path = cold.bytes)
    "cancel-reload-cannot-bless-captured-confirmation";
  let huge = Z.of_string (String.make 600 '9') in
  let long_plan = { plan with id = String.make 600 'x'; changes = ["wallet", Z.neg huge; "food", huge] } in
  let long = Cancel.create ~book ~base_bytes:before ~day:"2026-10-16" long_plan in
  let update t key = match Cancel.handle ~blocked:false ~dimensions:(72,19) ~width_of t (`Key (key, [])) with
    | Cancel.Updated t -> t | _ -> raise (F.Refused "cancel-long-review-transition") in
  let long = update long `Enter |> fun s -> update s `Tab |> fun s -> update s `Enter in
  let ended = update long `End in
  (match Cancel.handle ~blocked:false ~dimensions:(72,19) ~width_of ended (`Key (`Enter, [])) with
   | Cancel.Publish (id, day, bytes) ->
       require (id = long_plan.id && day = "2026-10-16" && bytes = before) "cancel-reviewed-fixed-intent"
   | _ -> raise (F.Refused "cancel-reviewed-end-refused"));
  (match Cancel.handle ~blocked:false ~dimensions:(32,9) ~width_of ended (`Key (`Enter, [])) with
   | Cancel.Updated _ -> () | _ -> raise (F.Refused "cancel-shrink-after-end-bypassed-gate"));
  print_endline "PASS: Scheduled cancellation has read-only Preview, default Keep, date/target/end/tiny gates, retained drafts, stale/Records/storage refusal and cold non-destructive retirement."

let months_checks ~width_of ~directory home =
  let days = ["2026-10-20"; "2026-11-30"; "2026-12-31"; "2027-01-15";
    "2027-04-30"; "2027-05-01"; "2027-12-31"] in
  let plan n day : B.plan = { id = Printf.sprintf "month-%02d" n; day;
    measure = (if n = 3 then "eur" else "jpy");
    changes = (if n = 4 then ["wallet", Z.of_int (-30); "food", Z.of_int 10; "bank", Z.of_int 20]
      else ["wallet", Z.of_int (-123456); "food", Z.of_int 123456]);
    paid_by = None; cancelled_on = None } in
  let plans = List.mapi plan days in
  let book = List.fold_left (fun book (p : B.plan) ->
    get (B.cancel_plan book ~id:p.id ~day:"2026-11-01")) home.C.session.book (B.open_plans home.session.book) in
  let book = List.fold_left (fun book p -> get (B.put_plan book ~replace:false p)) book plans in
  let closed = { (plan 7 "2026-11-10") with id = "month-cancelled" } in
  let book = get (B.put_plan book ~replace:false closed)
    |> fun book -> get (B.cancel_plan book ~id:closed.id ~day:"2026-11-01") in
  let path = directory ^ "/months.sexp" in
  F.write_new path (B.to_string book);
  let before = F.read path in
  let initial = C.initial ~config_home:directory (F.load path) in
  let workspace = get (W.create ~today:"2026-11-15" ~measure:"jpy") in
  let scheduled = Plans.create (get (Months.create ~today:"2026-11-15")) in
  let listed = C.open_route { initial with workspace; screens = { initial.screens with scheduled } } W.Scheduled
    |> fun s -> with_plan_query s "month-02" in
  let list_browser = plan_list listed in
  let months = key ~width_of listed (`ASCII 'v') in
  require (List.map Record_browser.identity (plan_rows months)
           = List.map (fun (p : B.plan) -> (Record_browser.Scheduled_row, p.id)) plans
           && plan_list months = list_browser)
    "months-projects-all-current-open-without-list-filter";
  require ((plan_id months) = Some (Record_browser.Scheduled_row, "month-02")
           && Months.visible_months (plan_months months)
              = ["2026-11-01";"2026-12-01";"2027-01-01";"2027-02-01";"2027-03-01";"2027-04-01"])
    "months-year-crossing-window-preserves-target";
  let january = key ~width_of months (`ASCII 'j') in
  let restored = key ~width_of january (`ASCII 'v') in
  require (not (plan_months_view restored) && plan_list restored = list_browser)
    "months-return-keeps-list-filters-and-visible-selection";
  let all_list = with_plan_query listed "" in
  let all_months = key ~width_of all_list (`ASCII 'v') |> fun s -> key ~width_of s `End in
  let returned_all = key ~width_of all_months (`ASCII 'v') in
  require ((plan_id returned_all) = Some (Record_browser.Scheduled_row, "month-06")
           && Months.first_month (plan_months all_months) = "2027-07-01")
    "months-selection-follows-horizon-and-returns-by-id";
  let oldest = key ~width_of all_months `Home in
  require ((plan_id oldest) = Some (Record_browser.Scheduled_row, "month-00")
           && Months.first_month (plan_months oldest) = "2026-11-01")
    "months-overdue-selection-does-not-shift-before-current-month";
  let shifted = key ~width_of oldest (`ASCII 'l') in
  require (Months.first_month (plan_months shifted) = "2026-12-01"
           && (plan_id shifted) = (plan_id oldest)
           && plan_months (key ~width_of shifted (`ASCII 'h')) = (plan_months oldest))
    "months-horizontal-window-move-does-not-reselect-or-auto-follow";
  let no_earlier = key ~width_of oldest (`ASCII 'h') in
  require ((plan_months no_earlier) = (plan_months oldest)) "months-clamps-current-month-floor";
  List.iter (fun button ->
    let refused = key ~width_of months button in
    require ((no_modal refused) && plan_rows refused = plan_rows months
             && plan_list refused = list_browser) "months-keeps-unfiltered-frontier")
    [`ASCII '/'; `ASCII 'f'];
  let contains rows needle = List.exists (fun (_, line) -> Base.String.is_substring line ~substring:needle) rows in
  List.iter (fun dimensions ->
    let rows = R.screen ~width_of dimensions months in
    require (List.length rows <= snd dimensions
             && List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows) "months-resize-bounded";
    if fst dimensions >= 80 && snd dimensions >= 24 then
      List.iter (fun month -> require (contains rows month) "months-six-cards-visible")
        ["2026-11";"2026-12";"2027-01";"2027-02";"2027-03";"2027-04"])
    [32,9;48,14;80,24;120,36];
  let detail = key ~width_of january `Tab in
  require (contains (R.screen ~width_of (120,36) detail) "1234.56 eur"
           && not (plan_detail (key ~width_of detail `Escape)))
    "months-exact-currency-details-and-board-return";
  let paying = key ~width_of months `Enter in
  require (paying.record_visible && (match S.mode (Option.get paying.record) with
    | Daily_actions.Pay id -> id = "month-02" | _ -> false) && F.read path = before)
    "months-enter-opens-selected-completion-without-publishing";
  let cancelled_pay = key ~width_of paying `Escape in
  require ((same_workspace cancelled_pay months) && cancelled_pay.screens.scheduled = months.screens.scheduled && C.has_record_draft cancelled_pay)
    "months-completion-cancel-retains-parent-and-draft";
  let kept = key ~width_of months (`ASCII 'x') |> fun s -> key ~width_of s `Enter
    |> fun s -> key ~width_of s `Enter in
  require ((same_workspace kept months) && F.read path = before) "months-cancel-keep-is-read-only";
  let limit = get (Months.create ~today:"9999-12-31") in
  require (Months.visible_months limit = ["9999-12-01"]
           && Result.is_error (Months.shift limit 1)
           && Result.is_error (Months.shift (plan_months oldest) (-1)))
    "months-supported-calendar-boundaries";
  require (Result.is_error (Months.shift (plan_months months) max_int)
           && Result.is_error (Months.shift (plan_months months) min_int))
    "months-extreme-shifts-refuse-without-overflow";
  let split = Months.screen ~book ~plans ~dimensions:(120,36) ~width_of
    ~selected:(Some (List.nth plans 4)) (plan_months months) in
  require (contains split "split (3)") "months-split-does-not-invent-a-total";
  let crowded = List.init 12 (fun n -> { (plan n "2026-11-29") with
    changes = ["wallet", Z.of_int (-100-n); "food", Z.of_int (100+n)] }) in
  let selected = Some (List.nth crowded 11) in
  let cards = Months.screen ~book ~plans:crowded ~dimensions:(80,19) ~width_of ~selected (plan_months months)
    |> List.filter (fun (style, _) -> match style with Daily_overlays.Columns _ -> true | _ -> false) in
  require (contains cards "111 jpy") "months-card-follows-selection-beyond-first-page";
  let huge = Z.of_string (String.make 600 '9') in
  let huge_plan = { (List.nth plans 1) with changes = ["wallet", Z.neg huge; "food", huge] } in
  require (contains (Months.screen ~book ~plans:[huge_plan] ~dimensions:(80,19) ~width_of
    ~selected:(Some huge_plan) (plan_months months)) "see details") "months-huge-amount-not-clipped-as-a-number";
  List.iter (fun dimensions ->
    let rows = Months.screen ~book ~plans ~dimensions ~width_of ~selected:(Some (List.nth plans 2)) (plan_months months) in
    require (List.length rows <= snd dimensions
             && List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows) "months-zero-and-tiny-surface-bounds")
    [0,0;0,1;1,1;1,9];
  require (F.read path = before) "months-browsing-never-saves";
  let retired = key ~width_of months (`ASCII 'x') |> fun s -> key ~width_of s `Enter
    |> fun s -> key ~width_of s `Tab |> fun s -> key ~width_of s `Enter in
  let cold = F.load path in
  require (List.find (fun (p : B.plan) -> p.id = "month-02") (B.plans cold.book)
             = { (List.nth plans 2) with cancelled_on = Some (F.today ()) }
           && B.entries cold.book = B.entries book
           && (plan_id retired) = Some (Record_browser.Scheduled_row, "month-03")
           && plan_list retired = list_browser)
    "months-cancellation-retires-selected-id-and-clamps-to-next-plan";
  print_endline "PASS: Scheduled Months projects six current-open months, stable IDs and filters, exact details, horizon/floor/year boundaries, compact resize and non-saving completion/Keep."

let continuation_checks ~width_of ~directory home =
  let directory = directory ^ "/continuation" in
  Unix.mkdir directory 0o700;
  let source : B.plan = { id = "continue-source"; day = "2026-10-15"; measure = "eur";
    changes = ["wallet", Z.of_int (-123456); "food", Z.of_int 123456];
    paid_by = None; cancelled_on = None } in
  let source_book = get (B.put_plan home.C.session.book ~replace:false source) in
  let later = { source with id = "later-first"; day = "2026-11-15"; measure = "jpy";
    changes = ["bank", Z.of_int (-2); "food", Z.of_int 2] } in
  let other_later = { later with id = "later-second"; day = "2026-12-15" } in
  let same_date = { later with id = "same-date"; day = source.day } in
  let unrelated = { later with id = "unrelated"; day = "2026-10-16";
    changes = ["wallet", Z.of_int (-5); "bank", Z.of_int 5] } in
  let closed = { later with id = "closed-later"; day = "2026-10-16" } in
  let book = List.fold_left (fun book p -> get (B.put_plan book ~replace:false p))
    source_book [other_later; same_date; unrelated; closed; later]
    |> fun book -> get (B.cancel_plan book ~id:closed.id ~day:source.day) in
  let complete path book target =
    F.write_new path (B.to_string book);
    let base = C.open_route (C.initial ~config_home:directory (F.load path)) W.Scheduled
      |> fun s -> Interaction_check_fixture.with_plan_query s target.B.id in
    let before = F.read path in
    let review = C.submit (Interaction_check_fixture.pay_selected base) in
    require (review.record_visible && F.read path = before) "continuation-does-not-precede-payment";
    key ~width_of review `Enter in
  let prompt state = match session_of state with
    | Some (E.Scheduled_continuation p) -> p | _ -> raise (F.Refused "continuation-prompt-missing") in
  let input state event = match H.handle ~width_of state event with
    | Some state -> state | None -> raise (F.Refused "continuation-controller-exit") in
  let path = directory ^ "/continuation.sexp" in
  let completed = complete path book source in
  let after_payment = F.read path in
  let paid_source = List.find (fun (p : B.plan) -> p.id = source.id) (B.plans completed.session.book) in
  require (paid_source.paid_by <> None && B.entry_count completed.session.book = B.entry_count book + 1)
    "continuation-starts-after-confirmed-atomic-completion";
  (match Cont.handle ~dimensions:(80,24) ~width_of (prompt completed) (`Key (`Enter, [])) with
   | Cont.Closed (Some p) -> require (p.id = later.id) "continuation-earliest-later-positive-locus-set"
   | _ -> raise (F.Refused "continuation-default-not-keep"));
  let kept = key ~width_of completed `Enter in
  require ((no_modal kept) && F.read path = after_payment) "continuation-keep-never-creates";
  let review = key ~width_of completed `Tab |> fun s -> key ~width_of s `Tab |> fun s -> key ~width_of s `Enter in
  let rows = Option.get (R.overlay_screen ~dimensions:(80,24) ~width_of review) in
  require (List.exists (fun (_, line) -> Base.String.is_substring line ~substring:later.id) rows)
    "continuation-review-retains-existing-plan-identity";
  List.iter (fun dimensions ->
    let ended = key ~dimensions ~width_of review `End in
    let rows = Option.get (R.overlay_screen ~dimensions ~width_of ended) in
    require (List.length rows <= snd dimensions
             && List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows)
      "continuation-review-resize-bounded") [32,9;48,14;80,24;120,36];
  let added = key ~width_of completed `Tab |> fun s -> key ~width_of s `Enter in
  let editor = match session_of added with Some (E.Scheduled_create e) -> e | _ -> raise (F.Refused "continuation-add-editor") in
  require (Sch.day editor = "" && Sch.measure editor = "eur") "continuation-does-not-infer-date-or-copy-candidate-measure";
  let cancelled = key ~width_of added `Escape in
  require ((no_modal cancelled) && F.read path = after_payment
           && (List.find (fun (p : B.plan) -> p.id = source.id) (B.plans (F.load path).book)) = paid_source)
    "continuation-cancel-add-keeps-published-completion";
  let next = String.fold_left (fun s c -> key ~width_of s (`ASCII c)) added "2026-12-20" in
  let next = List.fold_left (fun s _ -> key ~width_of s `Tab) next (List.init 7 Fun.id)
    |> fun s -> key ~width_of s `Enter in
  require (F.read path = after_payment) "continuation-next-preview-is-read-only";
  let saved = key ~width_of next `Enter in
  let cold = F.load path in
  let created = List.find (fun (p : B.plan) -> p.day = "2026-12-20") (B.plans cold.book) in
  require ((no_modal saved) && created.id <> source.id && created.measure = source.measure
           && created.changes = source.changes && created.paid_by = None && created.cancelled_on = None
           && B.entries cold.book = B.entries completed.session.book
           && List.find (fun (p : B.plan) -> p.id = source.id) (B.plans cold.book) = paid_source)
    "continuation-cold-add-is-independent-and-preserves-exact-eur-quanta";
  let stale = input completed (`Key (`ASCII 'r', [`Ctrl]))
    |> fun s -> key ~width_of s `Tab |> fun s -> key ~width_of s `Enter in
  require (stale.blocked && not stale.record_visible && F.read path = cold.bytes
           && Cont.base_bytes (prompt stale) = completed.session.bytes)
    "continuation-reload-does-not-bless-stale-awareness";
  let none_path = directory ^ "/continuation-none.sexp" in
  let none = complete none_path source_book source in
  let none_bytes = F.read none_path in
  let done_ = key ~width_of none `Enter in
  require ((no_modal done_) && F.read none_path = none_bytes) "continuation-done-never-adds";
  let defer = key ~width_of none `Tab in
  let failed = key ~width_of { defer with attention_path = directory } `Enter in
  require (F.read none_path = none_bytes && not failed.record_visible
           && Cont.base_bytes (prompt failed) = none.session.bytes)
    "continuation-defer-failure-does-not-rollback-completion";
  let deferred = key ~width_of defer `Enter in
  let attention = get (Attention_file.load_file none.attention_path) in
  require ((no_modal deferred) && F.read none_path = none_bytes
           && List.exists (fun (item : Att.item) -> item.due = Att.Due_undetermined
             && Base.String.is_substring item.context ~substring:source.id) (Att.open_items attention))
    "continuation-defer-cold-retains-undecided-attention-only";
  let empty_prompt = prompt none in
  List.iter (fun dimensions ->
    let rows = Cont.screen ~dimensions ~width_of empty_prompt in
    require (List.length rows <= snd dimensions && List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows)
      "continuation-choices-tiny-bounds") [0,0;1,1;32,4;32,9];
  let uncertain_path = directory ^ "/continuation-uncertain.sexp" in
  F.write_new uncertain_path (B.to_string source_book);
  let base = C.open_route (C.initial ~config_home:directory (F.load uncertain_path)) W.Scheduled
    |> fun s -> Interaction_check_fixture.with_plan_query s source.id in
  let pay = C.submit (Interaction_check_fixture.pay_selected base) in
  let tx = match S.handle ~new_id:Daily_file.new_id ~book:source_book ~base_bytes:pay.session.bytes ~blocked:false
    ~dimensions:(140,40) ~width_of (Option.get pay.record) (`Key (`Enter, [])) with
    | S.Publish (Daily_actions.Entry_tx tx, _, _) -> tx
    | _ -> raise (F.Refused "continuation-uncertain-intent") in
  let candidate = get (B.put_entry source_book ~replace:tx.replace tx.entry ~plan:tx.plan) in
  let unknown = C.apply_commit_result pay ~draft:pay
    (Daily_actions.Uncertain { message = "synthetic lost acknowledgement";
      evidence = Daily_actions.Monolithic_candidate (B.to_string candidate) }) in
  let unconfirmed = Shell_dispatch.reload unknown in
  require (unconfirmed.blocked && unconfirmed.record_visible && (no_modal unconfirmed))
    "continuation-unknown-completion-cannot-offer-add";
  (match F.publish base.session candidate with F.Written _ -> () | _ -> raise (F.Refused "continuation-confirmation-setup"));
  let confirmed = Shell_dispatch.reload unconfirmed in
  require (not confirmed.blocked && confirmed.pending = None && not confirmed.record_visible
           && B.entry_count confirmed.session.book = B.entry_count source_book + 1
           && Cont.base_bytes (prompt confirmed) = confirmed.session.bytes)
    "continuation-only-confirmed-reload-opens-awareness-without-retry";
  print_endline "PASS: post-completion Keep/Review/Add/Done/Defer, later positive-Locus awareness, exact independent next plan, no inferred date, cold Attention, stale and unknown completion guards."

