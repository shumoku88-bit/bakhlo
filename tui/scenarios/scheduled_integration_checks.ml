(* Synthetic controller integration checks; see docs/RECONSTRUCTION_TEST_MAP.ja.md. *)
open Interaction_check_fixture

(* UI-15 List: ascending day/id, the local Loci pane, the day scope, fixed
   8-row pages and the optional full detail. Synthetic plans only. *)
let list_scope_checks ~width_of ~directory home =
  let plan id day changes : B.plan =
    { id; day; measure = "jpy"; changes; paid_by = None; cancelled_on = None }
  in
  let huge = Z.of_string (String.make 600 '9') in
  let plans =
    [
      plan "scope-a" "2026-11-10" [ ("wallet", Z.of_int (-100)); ("food", Z.of_int 100) ];
      plan "scope-b" "2026-11-10" [ ("bank", Z.of_int (-200)); ("wallet", Z.of_int 200) ];
      plan "scope-e" "2026-11-15" [ ("food", Z.of_int (-5)); ("wallet", Z.of_int 5) ];
      plan "scope-c" "2026-11-20" [ ("bank", Z.of_int (-300)); ("food", Z.of_int 300) ];
      plan "scope-d" "2026-12-01" [ ("food", Z.of_int (-1)); ("bank", Z.of_int 1) ];
    ]
    @ List.init 8 (fun n ->
        plan (Printf.sprintf "page-%02d" n)
          (Printf.sprintf "2026-12-%02d" (10 + n))
          [ ("wallet", Z.of_int (-n - 1)); ("food", Z.of_int (n + 1)) ])
    @ [ plan "scope-huge" "2026-12-20" [ ("wallet", Z.neg huge); ("food", huge) ] ]
  in
  let closing =
    List.fold_left
      (fun book (p : B.plan) -> get (B.cancel_plan book ~id:p.id ~day:"2026-11-01"))
      home.C.session.book (B.open_plans home.session.book)
  in
  let book = List.fold_left (fun book p -> get (B.put_plan book ~replace:false p)) closing plans in
  let path = directory ^ "/scheduled-list-scope.sexp" in
  F.write_new path (Bakhlo_household.Daily_txt.text book);
  let before = F.read path in
  let initial = C.initial ~config_home:directory (F.load path) in
  let workspace = get (W.create ~today:"2026-11-15" ~measure:"jpy") in
  let scheduled = Plans.create (get (Months.create ~today:"2026-11-15")) in
  let state =
    C.open_route
      { initial with workspace; screens = { initial.screens with scheduled } }
      W.Scheduled
  in
  let ids state = List.map Record_browser.identity (plan_rows state) in
  let ascending = ids state in
  let row (p : B.plan) = (Record_browser.Scheduled_row, p.id) in
  require
    ((plan_list state).order = Record_browser.Oldest
    && ascending = List.map row plans
    && Record_browser.date (List.hd (plan_rows state)) = "2026-11-10")
    "list-defaults-to-ascending-day-then-id";
  require
    (plan_id state = Some (row (List.hd plans)))
    "list-initial-selection-is-earliest-date-and-smallest-id";
  let loci = key ~width_of state (`ASCII 'h') in
  require
    ((plan_list loci).locus = None && ids loci = ascending && (plan_list loci).selected = 0)
    "list-h-selects-loci-without-changing-the-filter";
  let filtered = key ~width_of (key ~width_of loci (`ASCII 'h')) (`ASCII 'j') in
  let locus = (plan_list filtered).locus in
  let expected locus =
    List.filter_map
      (fun (p : B.plan) -> if List.mem locus (List.map fst p.changes) then Some (row p) else None)
      plans
  in
  (match locus with
  | None -> raise (F.Refused "list-loci-selection-did-not-filter")
  | Some locus ->
      require
        (ids filtered = expected locus
        && List.length (ids filtered) < List.length ascending
        && (plan_list filtered).selected = 0
        && plan_id filtered = Some (List.hd (expected locus)))
        "list-loci-selection-filters-exactly-and-resets-selection");
  List.iter
    (fun button ->
      let refused = key ~width_of filtered (`ASCII button) in
      require
        (no_modal refused && plan_list refused = plan_list filtered && F.read path = before)
        "list-loci-pane-does-not-act-on-a-background-occurrence")
    [ 'c'; 'r'; 'x'; 'e'; 'b'; 'g' ];
  let moved =
    key ~width_of (key ~width_of (key ~width_of filtered (`ASCII 'l')) (`ASCII 'l')) (`ASCII 'j')
  in
  (match locus with
  | None -> ()
  | Some locus ->
      require
        ((plan_list moved).locus = Some locus
        && (plan_list moved).selected = 1
        && plan_id moved = List.nth_opt (expected locus) 1)
        "list-l-equals-occurrence-pane-and-j-moves-the-plan");
  let restored = key ~width_of (key ~width_of moved (`ASCII 'h')) (`ASCII 'k') in
  require
    ((plan_list restored).locus = None
    && ids restored = ascending
    && (plan_list restored).selected = 0)
    "list-loci-all-row-restores-plans";
  let banked = key ~width_of restored (`ASCII 'j') in
  require (Option.is_some (plan_list banked).locus) "list-loci-refilters-after-restore";
  let day = key ~width_of (key ~width_of banked (`ASCII 'l')) (`ASCII 'f') in
  require
    ((plan_list day).day = Some "2026-11-15"
    && (plan_list day).locus = None && (plan_list day).selected = 0
    && plan_id day = Some (Record_browser.Scheduled_row, "scope-e")
    && not (plan_detail day))
    "list-f-day-scope-clears-locus-and-selection";
  let all = key ~width_of day (`ASCII 'f') in
  require
    ((plan_list all).day = None && (plan_list all).locus = None && ids all = ascending)
    "list-f-restores-all-current-open-plans";
  let paged = key ~dimensions:(32, 9) ~width_of all (`Page `Down) in
  let wide = key ~dimensions:(120, 36) ~width_of all (`Page `Down) in
  require
    ((plan_list paged).selected = 8 && (plan_list wide).selected = 8
    && plan_id paged = Some (Record_browser.Scheduled_row, "page-03"))
    "list-page-fixed-eight-rows-independent-of-viewport";
  List.iter
    (fun button ->
      let unchanged = key ~width_of (key ~width_of paged (`ASCII 'h')) button in
      require
        (plan_list unchanged = plan_list paged)
        "list-no-op-locus-navigation-keeps-the-occurrence-target")
    [ `Home; `ASCII 'k'; `Page `Up ];
  require
    ((plan_list (key ~width_of paged (`Page `Up))).selected = 0
    && (plan_list (key ~width_of paged `Home)).selected = 0
    && (plan_list (key ~width_of paged `End)).selected = List.length ascending - 1)
    "list-page-up-home-end";
  let loci_paged = key ~width_of (key ~width_of all (`ASCII 'h')) (`Page `Down) in
  require
    (Option.is_some (plan_list loci_paged).locus
    && List.length (ids loci_paged) < List.length ascending)
    "list-loci-page-moves-eight-rows";
  let paying = key ~width_of paged `Enter in
  require
    (paying.record_visible
    && (match S.mode (Option.get paying.record) with
      | Daily_actions.Pay id -> id = "page-03"
      | _ -> false)
    && (not (plan_detail paying))
    && F.read path = before)
    "list-enter-completes-the-selected-occurrence-without-writing";
  let paying_cancelled = key ~width_of paying `Escape in
  require
    ((not paying_cancelled.record_visible) && F.read path = before)
    "list-completion-cancel-keeps-the-plan";
  let detail = key ~width_of paying_cancelled (`ASCII 'i') in
  require
    (plan_detail detail && (not detail.record_visible)
    && plan_id detail = Some (Record_browser.Scheduled_row, "page-03"))
    "list-i-opens-optional-detail-keeping-the-plan";
  require
    (plan_detail (key ~width_of paying_cancelled `Tab)
    && plan_detail (key ~width_of paying_cancelled (`ASCII 'w')))
    "list-tab-and-w-also-open-detail";
  let backs = key ~width_of detail `Escape in
  require
    ((not (plan_detail backs))
    && plan_id backs = plan_id detail
    && (plan_list backs).locus = None && (plan_list backs).day = None)
    "list-detail-escape-keeps-selection-and-filters";
  let loci_detail = key ~width_of (key ~width_of all (`ASCII 'h')) (`ASCII 'i') in
  let origin = key ~width_of loci_detail `Escape in
  require
    (plan_detail loci_detail
    && plan_id origin = plan_id loci_detail
    && no_modal (key ~width_of origin `Enter))
    "list-detail-escape-returns-to-the-origin-loci-pane";
  let paid = key ~width_of (key ~width_of origin (`ASCII 'l')) `Enter in
  require
    (paid.record_visible
    &&
    match S.mode (Option.get paid.record) with
    | Daily_actions.Pay id -> id = "scope-a"
    | _ -> false)
    "list-occurrence-pane-enter-completes-the-selection";
  let paid_closed = key ~width_of paid `Escape in
  let queried = with_plan_query all "scope-c" in
  let query_detail = key ~width_of queried (`ASCII 'i') in
  let query_back = key ~width_of query_detail `Escape in
  require
    ((plan_list query_back).query = "scope-c"
    && plan_id query_back = Some (Record_browser.Scheduled_row, "scope-c")
    && not (plan_detail (key ~width_of query_detail (`ASCII 'q'))))
    "list-detail-escape-and-q-keep-the-applied-query";
  let months = key ~width_of query_detail (`ASCII 'v') in
  let listed = key ~width_of months (`ASCII 'v') in
  require
    (plan_months_view months
    && (not (plan_detail months))
    && (not (plan_months_view listed))
    && (not (plan_detail listed))
    && (plan_list listed).query = "scope-c")
    "list-view-cycle-clears-detail-and-keeps-the-query";
  let reentered = C.open_route (with_plan_query all "scope-c") W.Scheduled in
  require
    ((plan_list reentered).query = "scope-c"
    && plan_id reentered = Some (Record_browser.Scheduled_row, "scope-c")
    && (plan_list reentered).day = None
    && (plan_list reentered).locus = None
    && not (plan_detail reentered))
    "list-route-reentry-retains-query-and-id";
  let refiltered = C.open_route moved W.Scheduled in
  require
    ((plan_list refiltered).locus = (plan_list moved).locus && plan_id refiltered = plan_id moved)
    "list-route-reentry-retains-locus-and-selection";
  let relater =
    C.open_route
      { all with workspace = get (W.create ~today:"2026-12-01" ~measure:"jpy") }
      W.Scheduled
  in
  require
    ((plan_list (key ~width_of relater (`ASCII 'f'))).day = Some "2026-12-01"
    && plan_id (key ~width_of relater (`ASCII 'f')) = Some (Record_browser.Scheduled_row, "scope-d")
    )
    "list-enter-captures-the-current-focus-day";
  let scoped_locus = key ~width_of (key ~width_of day (`ASCII 'h')) `End in
  let same_day = C.open_route scoped_locus W.Scheduled in
  require
    ((plan_list same_day).locus = (plan_list scoped_locus).locus)
    "list-same-day-reentry-retains-the-locus";
  let different_day =
    C.open_route
      { scoped_locus with workspace = get (W.create ~today:"2026-12-01" ~measure:"jpy") }
      W.Scheduled
  in
  require
    ((plan_list different_day).day = Some "2026-12-01"
    && (plan_list different_day).locus = None
    && plan_id different_day = Some (Record_browser.Scheduled_row, "scope-d"))
    "list-changed-day-reentry-clears-the-obsolete-locus";
  let toggled = key ~width_of (key ~width_of all (`ASCII 'w')) (`ASCII 'w') in
  require
    ((not (plan_detail toggled)) && plan_id toggled = plan_id all)
    "list-w-twice-returns-to-the-origin-pane";
  let toggled_pay = key ~width_of toggled `Enter in
  require
    (toggled_pay.record_visible
    &&
    match S.mode (Option.get toggled_pay.record) with
    | Daily_actions.Pay id -> id = "scope-a"
    | _ -> false)
    "list-w-twice-restores-the-occurrence-pane-selection";
  let huged = with_plan_query all "scope-huge" in
  let huge_detail = key ~width_of huged (`ASCII 'i') in
  let huge_rows = R.screen ~width_of (120, 36) huge_detail in
  require
    (List.exists
       (fun (_, line) -> Base.String.is_substring line ~substring:(String.make 20 '9'))
       huge_rows)
    "list-huge-quantity-readable-in-optional-detail";
  require
    (List.length huge_rows <= 36 && List.for_all (fun (_, line) -> width_of line <= 120) huge_rows)
    "list-huge-detail-bounded";
  List.iter
    (fun dimensions ->
      List.iter
        (fun state ->
          let rows = R.screen ~width_of dimensions state in
          require
            (List.length rows <= snd dimensions
            && List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows)
            "list-scope-resize-bounded")
        [ loci; filtered; day; all; paged; huge_detail ])
    [ (32, 9); (48, 14); (80, 24); (120, 36) ];
  require
    (same_workspace paid_closed all && F.read path = before && not paid_closed.record_visible)
    "list-scope-never-writes";
  print_endline
    "PASS: Scheduled List is ascending by date/id with a local Loci filter, exact day scope, fixed \
     8-row pages, targeted completion, optional detail return and readable huge quantities \
     (synthetic)."

let scheduled_panel_checks ~width_of ~directory home =
  (* The full-width detail pane at 120x36 fits any short overflow fixture, so
     the amount is long enough to overflow the viewport at every dimension. *)
  let huge = Z.of_string (String.make 2400 '9') in
  let plan n : B.plan =
    {
      id = Printf.sprintf "panel-plan-%02d-%s" n (String.make 180 'p');
      day = Printf.sprintf "2026-10-%02d" (n + 1);
      measure = "jpy";
      changes = [ ("wallet", Z.neg huge); ("food", huge) ];
      paid_by = None;
      cancelled_on = None;
    }
  in
  let book =
    List.fold_left
      (fun book n -> get (B.put_plan book ~replace:false (plan n)))
      home.C.session.book (List.init 20 Fun.id)
  in
  let path = directory ^ "/scheduled-panels.sexp" in
  F.write_new path (Bakhlo_household.Daily_txt.text book);
  let before = F.read path in
  let state = C.open_route (C.initial ~config_home:directory (F.load path)) W.Scheduled in
  let count = List.length (plan_rows state) in
  List.iter
    (fun dimensions ->
      let key = key ~dimensions ~width_of in
      let detail = key state (`ASCII 'i') in
      let _, view = plan_window ~dimensions ~width_of detail in
      let identity = plan_id detail in
      require (view.last > 0) "scheduled-long-detail-overflows";
      let ended = key detail `End in
      require
        (plan_scroll ended = view.last && plan_id ended = identity)
        "scheduled-detail-end-preserves-identity";
      require
        (plan_scroll (key ended (`ASCII 'j')) = view.last
        && plan_scroll (key ended (`ASCII 'k')) = view.last - 1
        && plan_scroll (key ended `Home) = 0)
        "scheduled-detail-endpoints-and-immediate-up";
      require
        (plan_scroll (key detail (`Page `Down)) = min view.last (max 1 view.capacity))
        "scheduled-detail-page-visible-rows";
      let ctrl_down =
        get
          (match H.handle ~dimensions ~width_of detail (`Key (`ASCII 'd', [ `Ctrl ])) with
          | Some state -> Ok state
          | None -> Error "scheduled-ctrl-page-exited")
      in
      require
        (plan_scroll ctrl_down = plan_scroll (key detail (`Page `Down)))
        "scheduled-ctrl-page-same-capacity";
      let listed = key ended `Tab in
      let restored = key listed `Tab in
      require
        ((not (plan_detail listed))
        && plan_detail restored
        && plan_scroll restored = plan_scroll ended
        && plan_id restored = identity)
        "scheduled-focus-roundtrip-retains-detail-and-selection";
      require
        ((not (plan_detail (key state (`ASCII 'h'))))
        && (not (plan_detail (key (key state (`ASCII 'h')) (`ASCII 'l'))))
        && (plan_list (key state (`ASCII 'h'))).locus = (plan_list state).locus)
        "scheduled-list-horizontal-selects-panes-not-detail";
      let back = key ended `Escape in
      require ((not (plan_detail back)) && plan_id back = identity) "scheduled-back-keeps-selection";
      let scoped = key state (`ASCII 'f') in
      require
        ((plan_list scoped).day = Some (F.today ())
        && (plan_list scoped).locus = None && (plan_list scoped).selected = 0
        && not (plan_detail scoped))
        "scheduled-f-day-scope-clears-locus-and-selection";
      let unscoped = key scoped (`ASCII 'f') in
      require
        ((plan_list unscoped).day = None && (plan_list unscoped).locus = None
        && plan_rows unscoped = plan_rows state)
        "scheduled-f-restores-all-current-open";
      let reloaded =
        get
          (match H.handle ~dimensions ~width_of ended (`Key (`ASCII 'r', [ `Ctrl ])) with
          | Some state -> Ok state
          | None -> Error "scheduled-reload-exited")
      in
      require
        (plan_scroll reloaded = 0 && plan_id reloaded = identity)
        "scheduled-reload-anchors-identity-and-resets-detail";
      let page = key state (`Page `Down) in
      require (plan_row page = min (count - 1) 8) "scheduled-list-page-fixed-eight-rows";
      require
        (plan_row (key state `End) = count - 1 && plan_row (key (key state `End) `Home) = 0)
        "scheduled-list-real-endpoints";
      List.iter
        (fun state ->
          let rows = R.screen ~width_of dimensions state in
          require
            (List.length rows <= snd dimensions
            && List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows)
            "scheduled-shared-panels-bounded")
        [ state; page; ended ])
    [ (32, 9); (48, 14); (80, 24); (120, 36) ];
  let small =
    key ~dimensions:(32, 9) ~width_of state (`ASCII 'i') |> fun s ->
    key ~dimensions:(32, 9) ~width_of s `End
  in
  let resized = key ~dimensions:(120, 36) ~width_of small (`ASCII '!') in
  let _, view = plan_window ~dimensions:(120, 36) ~width_of resized in
  require
    (view.start = view.last && plan_id resized = plan_id small)
    "scheduled-resize-clamps-offset-not-identity";
  search_control_checks ~width_of ~path ~label:"scheduled"
    ~query:(fun s -> (plan_browser s).query)
    state "panel-plan-03";
  let editing = key ~width_of state (`ASCII 'r') in
  let draft = text ~width_of editing "q 日本語" in
  let closed = key ~width_of draft `Escape in
  require
    (same_workspace closed state && C.has_record_draft closed && not closed.record_visible)
    "scheduled-edit-cancel-retains-draft-and-parent";
  let resumed = X.open_command closed M.Record in
  require
    (S.screen ~book ~dimensions:(72, 20) ~width_of (Option.get draft.record)
    = S.screen ~book ~dimensions:(72, 20) ~width_of (Option.get resumed.record))
    "scheduled-draft-resumed-through-existing-record-command";
  let cancelled = key ~width_of (key ~width_of state (`ASCII 'x')) `Escape in
  require
    (same_workspace cancelled state && no_modal cancelled)
    "scheduled-cancel-overlay-return-context";
  require (F.read path = before) "scheduled-shared-panels-no-write";
  print_endline
    "PASS: Scheduled uses shared viewport, clamped detail/list paging, focus/resize, retained \
     draft and cancelled action context (synthetic).";
  list_scope_checks ~width_of ~directory home

let cancellation_checks ~width_of ~directory home =
  let plan : B.plan =
    {
      id = "cancel-target";
      day = "2026-10-20";
      measure = "eur";
      changes = [ ("wallet", Z.of_int (-120001)); ("food", Z.of_int 120001) ];
      paid_by = None;
      cancelled_on = None;
    }
  in
  let book = get (B.put_plan home.C.session.book ~replace:false plan) in
  let path = directory ^ "/cancellation.sexp" in
  F.write_new path (Bakhlo_household.Daily_txt.text book);
  let before = F.read path in
  let base =
    C.open_route (C.initial ~config_home:directory (F.load path)) W.Scheduled |> fun s ->
    Interaction_check_fixture.with_plan_query s plan.id
  in
  let editor state =
    match session_of state with
    | Some (E.Scheduled_cancel e) -> e
    | _ -> raise (F.Refused "cancel-review-lost")
  in
  let input state event =
    match H.handle ~width_of state event with
    | Some s -> s
    | None -> raise (F.Refused "cancel-controller-exited")
  in
  let date state value =
    let state =
      List.fold_left
        (fun s _ -> key ~width_of s `Backspace)
        state
        (List.init (String.length (Cancel.day (editor state))) Fun.id)
    in
    text ~width_of state value
  in
  let opened = key ~width_of base (`ASCII 'x') in
  let invalid = date opened "2026-02-29" |> fun s -> key ~width_of s `Enter in
  require
    ((not (Cancel.is_preview (editor invalid))) && F.read path = before)
    "cancel-invalid-date-does-not-preview-or-write";
  let review = date invalid "2026/10/16" |> fun s -> key ~width_of s `Enter in
  require
    (Cancel.is_preview (editor review)
    && Cancel.day (editor review) = "2026-10-16"
    && F.read path = before)
    "cancel-date-enter-is-read-only-preview";
  let kept = key ~width_of review `Enter in
  require
    (no_modal kept && same_workspace kept base && F.read path = before)
    "cancel-protective-default-keeps-plan";
  let edited = key ~width_of review (`ASCII 'e') in
  require
    ((not (Cancel.is_preview (editor edited))) && Cancel.day (editor edited) = "2026-10-16")
    "cancel-preview-edit-retains-date";
  let selected = key ~width_of review `Tab in
  List.iter
    (fun dimensions ->
      let refused = key ~dimensions ~width_of selected `Enter in
      require
        (Cancel.is_preview (editor refused) && F.read path = before)
        "cancel-tiny-confirmation-refused")
    [ (32, 9); (48, 14); (80, 14) ];
  List.iter
    (fun keycode ->
      let kept = key ~width_of selected keycode in
      require (same_workspace kept base && F.read path = before) "cancel-explicit-keep-never-writes")
    [ `Escape; `ASCII 'q' ];
  let pasted =
    input selected (`Paste `Start) |> fun s ->
    input s (`Key (`Enter, [])) |> fun s -> input s (`Paste `End)
  in
  require
    (Cancel.is_preview (editor pasted)
    && Cancel.day (editor pasted) = "2026-10-16"
    && F.read path = before)
    "cancel-paste-cannot-confirm";
  let held =
    prepare_record ~width_of home |> fun s ->
    key ~width_of s `Escape |> fun s -> C.open_route s W.Scheduled
  in
  let guarded = key ~width_of held (`ASCII 'x') in
  require
    (no_modal guarded && guarded.record = held.record && C.has_record_draft guarded)
    "cancel-does-not-destroy-record-draft";
  let missing = { selected with session = unavailable_session selected.session } in
  let failed = key ~width_of missing `Enter in
  require
    (Cancel.day (editor failed) = "2026-10-16"
    && Cancel.base_revision (editor failed) = F.revision_of_bytes before
    && F.read path = before)
    "cancel-storage-failure-keeps-date-target-and-base";
  let kept_failed = key ~width_of failed `Enter in
  require (no_modal kept_failed && F.read path = before) "cancel-failure-resets-choice-to-keep";
  let saved = key ~width_of selected `Enter in
  let cold = F.load path in
  require
    (no_modal saved
    && List.find (fun (p : B.plan) -> p.id = plan.id) (B.plans cold.book)
       = { plan with cancelled_on = Some "2026-10-16" }
    && B.entries cold.book = B.entries book
    && Daily_overlays.quantity ~book:cold.book ~measure:"jpy" "wallet"
       = Daily_overlays.quantity ~book ~measure:"jpy" "wallet")
    "cancel-cold-retains-target-due-exact-effects-and-actual-balance";
  let stale = key ~width_of selected `Enter in
  require
    (stale.blocked
    && Cancel.base_revision (editor stale) = F.revision_of_bytes before
    && F.read_revision path = cold.revision)
    "cancel-stale-confirmation-stops";
  let reloaded = input selected (`Key (`ASCII 'r', [ `Ctrl ])) |> fun s -> key ~width_of s `Enter in
  require
    (reloaded.blocked
    && Cancel.base_revision (editor reloaded) = F.revision_of_bytes before
    && F.read_revision path = cold.revision)
    "cancel-reload-cannot-bless-captured-confirmation";
  let huge = Z.of_string (String.make 600 '9') in
  let long_plan =
    { plan with id = String.make 600 'x'; changes = [ ("wallet", Z.neg huge); ("food", huge) ] }
  in
  let long =
    Cancel.create ~book ~base_revision:(F.revision_of_bytes before) ~day:"2026-10-16" long_plan
  in
  let update t key =
    match Cancel.handle ~blocked:false ~dimensions:(72, 19) ~width_of t (`Key (key, [])) with
    | Cancel.Updated t -> t
    | _ -> raise (F.Refused "cancel-long-review-transition")
  in
  let long =
    update long `Enter |> fun s ->
    update s `Tab |> fun s -> update s `Enter
  in
  let ended = update long `End in
  (match Cancel.handle ~blocked:false ~dimensions:(72, 19) ~width_of ended (`Key (`Enter, [])) with
  | Cancel.Publish (id, day, bytes) ->
      require
        (id = long_plan.id && day = "2026-10-16" && bytes = F.revision_of_bytes before)
        "cancel-reviewed-fixed-intent"
  | _ -> raise (F.Refused "cancel-reviewed-end-refused"));
  (match Cancel.handle ~blocked:false ~dimensions:(32, 9) ~width_of ended (`Key (`Enter, [])) with
  | Cancel.Updated _ -> ()
  | _ -> raise (F.Refused "cancel-shrink-after-end-bypassed-gate"));
  print_endline
    "PASS: Scheduled cancellation has read-only Preview, default Keep, date/target/end/tiny gates, \
     retained drafts, stale/storage refusal and cold non-destructive retirement."

let months_checks ~width_of ~directory home =
  let days =
    [
      "2026-10-20";
      "2026-11-30";
      "2026-12-31";
      "2027-01-15";
      "2027-04-30";
      "2027-05-01";
      "2027-12-31";
    ]
  in
  let plan n day : B.plan =
    {
      id = Printf.sprintf "month-%02d" n;
      day;
      measure = (if n = 3 then "eur" else "jpy");
      changes =
        (if n = 4 then [ ("wallet", Z.of_int (-30)); ("food", Z.of_int 10); ("bank", Z.of_int 20) ]
         else [ ("wallet", Z.of_int (-123456)); ("food", Z.of_int 123456) ]);
      paid_by = None;
      cancelled_on = None;
    }
  in
  let plans = List.mapi plan days in
  let book =
    List.fold_left
      (fun book (p : B.plan) -> get (B.cancel_plan book ~id:p.id ~day:"2026-11-01"))
      home.C.session.book (B.open_plans home.session.book)
  in
  let book = List.fold_left (fun book p -> get (B.put_plan book ~replace:false p)) book plans in
  let closed = { (plan 7 "2026-11-10") with id = "month-cancelled" } in
  let book =
    get (B.put_plan book ~replace:false closed) |> fun book ->
    get (B.cancel_plan book ~id:closed.id ~day:"2026-11-01")
  in
  let path = directory ^ "/months.sexp" in
  F.write_new path (Bakhlo_household.Daily_txt.text book);
  let before = F.read path in
  let initial = C.initial ~config_home:directory (F.load path) in
  let workspace = get (W.create ~today:"2026-11-15" ~measure:"jpy") in
  let scheduled = Plans.create (get (Months.create ~today:"2026-11-15")) in
  let listed =
    C.open_route
      { initial with workspace; screens = { initial.screens with scheduled } }
      W.Scheduled
    |> fun s -> with_plan_query s "month-02"
  in
  let list_browser = plan_list listed in
  let months = key ~width_of listed (`ASCII 'v') in
  require
    (List.map Record_browser.identity (plan_rows months)
     = List.map (fun (p : B.plan) -> (Record_browser.Scheduled_row, p.id)) plans
    && plan_list months = list_browser)
    "months-projects-all-current-open-without-list-filter";
  require
    (plan_id months = Some (Record_browser.Scheduled_row, "month-02")
    && Months.visible_months (plan_months months)
       = [ "2026-11-01"; "2026-12-01"; "2027-01-01"; "2027-02-01"; "2027-03-01"; "2027-04-01" ])
    "months-year-crossing-window-preserves-target";
  let january = key ~width_of months (`ASCII 'j') in
  let restored = key ~width_of january (`ASCII 'v') in
  require
    ((not (plan_months_view restored)) && plan_list restored = list_browser)
    "months-return-keeps-list-filters-and-visible-selection";
  let all_list = with_plan_query listed "" in
  let all_months = key ~width_of all_list (`ASCII 'v') |> fun s -> key ~width_of s `End in
  let returned_all = key ~width_of all_months (`ASCII 'v') in
  require
    (plan_id returned_all = Some (Record_browser.Scheduled_row, "month-06")
    && Months.first_month (plan_months all_months) = "2027-07-01")
    "months-selection-follows-horizon-and-returns-by-id";
  let oldest = key ~width_of all_months `Home in
  require
    (plan_id oldest = Some (Record_browser.Scheduled_row, "month-00")
    && Months.first_month (plan_months oldest) = "2026-11-01")
    "months-overdue-selection-does-not-shift-before-current-month";
  let shifted = key ~width_of oldest (`ASCII 'l') in
  require
    (Months.first_month (plan_months shifted) = "2026-12-01"
    && plan_id shifted = plan_id oldest
    && plan_months (key ~width_of shifted (`ASCII 'h')) = plan_months oldest)
    "months-horizontal-window-move-does-not-reselect-or-auto-follow";
  let no_earlier = key ~width_of oldest (`ASCII 'h') in
  require (plan_months no_earlier = plan_months oldest) "months-clamps-current-month-floor";
  List.iter
    (fun button ->
      let refused = key ~width_of months button in
      require
        (no_modal refused
        && plan_rows refused = plan_rows months
        && plan_list refused = list_browser)
        "months-keeps-unfiltered-frontier")
    [ `ASCII '/'; `ASCII 'f' ];
  let contains rows needle =
    List.exists (fun (_, line) -> Base.String.is_substring line ~substring:needle) rows
  in
  List.iter
    (fun dimensions ->
      let rows = R.screen ~width_of dimensions months in
      require
        (List.length rows <= snd dimensions
        && List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows)
        "months-resize-bounded";
      if fst dimensions >= 80 && snd dimensions >= 24 then
        List.iter
          (fun month -> require (contains rows month) "months-six-cards-visible")
          [ "2026-11"; "2026-12"; "2027-01"; "2027-02"; "2027-03"; "2027-04" ])
    [ (32, 9); (48, 14); (80, 24); (120, 36) ];
  let detail = key ~width_of january (`ASCII 'i') in
  require
    (plan_detail detail
    && contains (R.screen ~width_of (120, 36) detail) "1234.56 eur"
    && not (plan_detail (key ~width_of detail `Escape)))
    "months-exact-currency-details-and-board-return";
  require
    (plan_detail (key ~width_of january `Tab) && plan_detail (key ~width_of january (`ASCII 'w')))
    "months-tab-and-w-also-open-detail";
  let paying = key ~width_of months `Enter in
  require
    (paying.record_visible
    && (match S.mode (Option.get paying.record) with
      | Daily_actions.Pay id -> id = "month-02"
      | _ -> false)
    && F.read path = before)
    "months-enter-opens-selected-completion-without-publishing";
  let cancelled_pay = key ~width_of paying `Escape in
  require
    (same_workspace cancelled_pay months
    && cancelled_pay.screens.scheduled = months.screens.scheduled
    && C.has_record_draft cancelled_pay)
    "months-completion-cancel-retains-parent-and-draft";
  let kept =
    key ~width_of months (`ASCII 'x') |> fun s ->
    key ~width_of s `Enter |> fun s -> key ~width_of s `Enter
  in
  require (same_workspace kept months && F.read path = before) "months-cancel-keep-is-read-only";
  let limit = get (Months.create ~today:"9999-12-31") in
  require
    (Months.visible_months limit = [ "9999-12-01" ]
    && Result.is_error (Months.shift limit 1)
    && Result.is_error (Months.shift (plan_months oldest) (-1)))
    "months-supported-calendar-boundaries";
  require
    (Result.is_error (Months.shift (plan_months months) max_int)
    && Result.is_error (Months.shift (plan_months months) min_int))
    "months-extreme-shifts-refuse-without-overflow";
  let split =
    Months.screen ~book ~plans ~dimensions:(120, 36) ~width_of
      ~selected:(Some (List.nth plans 4))
      (plan_months months)
  in
  require (contains split "split (3)") "months-split-does-not-invent-a-total";
  let crowded =
    List.init 12 (fun n ->
        {
          (plan n "2026-11-29") with
          changes = [ ("wallet", Z.of_int (-100 - n)); ("food", Z.of_int (100 + n)) ];
        })
  in
  let selected = Some (List.nth crowded 11) in
  let cards =
    Months.screen ~book ~plans:crowded ~dimensions:(80, 19) ~width_of ~selected (plan_months months)
    |> List.filter (fun (style, _) ->
        match style with Daily_overlays.Columns _ -> true | _ -> false)
  in
  require (contains cards "111 jpy") "months-card-follows-selection-beyond-first-page";
  let huge = Z.of_string (String.make 600 '9') in
  let huge_plan =
    { (List.nth plans 1) with changes = [ ("wallet", Z.neg huge); ("food", huge) ] }
  in
  List.iter
    (fun dimensions ->
      let rows =
        Months.screen ~book ~plans:[ huge_plan ] ~dimensions ~width_of ~selected:(Some huge_plan)
          (plan_months months)
      in
      require
        (List.length rows <= snd dimensions
        && List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows)
        "months-huge-amount-stays-bounded")
    [ (32, 9); (48, 14); (80, 24); (120, 36) ];
  require
    (plan_row (key ~dimensions:(32, 9) ~width_of oldest (`Page `Down))
     = min (List.length (plan_rows oldest) - 1) 8
    && plan_row (key ~dimensions:(120, 36) ~width_of oldest (`Page `Down))
       = min (List.length (plan_rows oldest) - 1) 8)
    "months-page-fixed-eight-rows";
  List.iter
    (fun dimensions ->
      let rows =
        Months.screen ~book ~plans ~dimensions ~width_of
          ~selected:(Some (List.nth plans 2))
          (plan_months months)
      in
      require
        (List.length rows <= snd dimensions
        && List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows)
        "months-zero-and-tiny-surface-bounds")
    [ (0, 0); (0, 1); (1, 1); (1, 9) ];
  require (F.read path = before) "months-browsing-never-saves";
  let retired =
    key ~width_of months (`ASCII 'x') |> fun s ->
    key ~width_of s `Enter |> fun s ->
    key ~width_of s `Tab |> fun s -> key ~width_of s `Enter
  in
  let cold = F.load path in
  require
    (List.find (fun (p : B.plan) -> p.id = "month-02") (B.plans cold.book)
     = { (List.nth plans 2) with cancelled_on = Some (F.today ()) }
    && B.entries cold.book = B.entries book
    && plan_id retired = Some (Record_browser.Scheduled_row, "month-03")
    && plan_list retired = list_browser)
    "months-cancellation-retires-selected-id-and-clamps-to-next-plan";
  print_endline
    "PASS: Scheduled Months projects six current-open months, stable IDs and filters, exact \
     details, horizon/floor/year boundaries, compact resize and non-saving completion/Keep."

let continuation_checks ~width_of ~directory home =
  let directory = directory ^ "/continuation" in
  Unix.mkdir directory 0o700;
  let source : B.plan =
    {
      id = "continue-source";
      day = "2026-10-15";
      measure = "eur";
      changes = [ ("wallet", Z.of_int (-123456)); ("food", Z.of_int 123456) ];
      paid_by = None;
      cancelled_on = None;
    }
  in
  let source_book = get (B.put_plan home.C.session.book ~replace:false source) in
  let later =
    {
      source with
      id = "later-first";
      day = "2026-11-15";
      measure = "jpy";
      changes = [ ("bank", Z.of_int (-2)); ("food", Z.of_int 2) ];
    }
  in
  let other_later = { later with id = "later-second"; day = "2026-12-15" } in
  let same_date = { later with id = "same-date"; day = source.day } in
  let unrelated =
    {
      later with
      id = "unrelated";
      day = "2026-10-16";
      changes = [ ("wallet", Z.of_int (-5)); ("bank", Z.of_int 5) ];
    }
  in
  let closed = { later with id = "closed-later"; day = "2026-10-16" } in
  let book =
    List.fold_left
      (fun book p -> get (B.put_plan book ~replace:false p))
      source_book
      [ other_later; same_date; unrelated; closed; later ]
    |> fun book -> get (B.cancel_plan book ~id:closed.id ~day:source.day)
  in
  let complete path book target =
    F.write_new path (Bakhlo_household.Daily_txt.text book);
    let base =
      C.open_route (C.initial ~config_home:directory (F.load path)) W.Scheduled |> fun s ->
      Interaction_check_fixture.with_plan_query s target.B.id
    in
    let before = F.read path in
    let review = C.submit (Interaction_check_fixture.pay_selected base) in
    require (review.record_visible && F.read path = before) "continuation-does-not-precede-payment";
    key ~width_of review `Enter
  in
  let prompt state =
    match session_of state with
    | Some (E.Scheduled_continuation p) -> p
    | _ -> raise (F.Refused "continuation-prompt-missing")
  in
  let input state event =
    match H.handle ~width_of state event with
    | Some state -> state
    | None -> raise (F.Refused "continuation-controller-exit")
  in
  let path = directory ^ "/continuation.sexp" in
  let completed = complete path book source in
  let after_payment = F.read path in
  let paid_source =
    List.find (fun (p : B.plan) -> p.id = source.id) (B.plans completed.session.book)
  in
  require
    (paid_source.paid_by <> None && B.entry_count completed.session.book = B.entry_count book + 1)
    "continuation-starts-after-confirmed-atomic-completion";
  (match Cont.handle ~dimensions:(80, 24) ~width_of (prompt completed) (`Key (`Enter, [])) with
  | Cont.Closed (Some p) ->
      require (p.id = later.id) "continuation-earliest-later-positive-locus-set"
  | _ -> raise (F.Refused "continuation-default-not-keep"));
  let kept = key ~width_of completed `Enter in
  require (no_modal kept && F.read path = after_payment) "continuation-keep-never-creates";
  let review =
    key ~width_of completed `Tab |> fun s ->
    key ~width_of s `Tab |> fun s -> key ~width_of s `Enter
  in
  let rows = Option.get (R.overlay_screen ~dimensions:(80, 24) ~width_of review) in
  require
    (List.exists (fun (_, line) -> Base.String.is_substring line ~substring:later.id) rows)
    "continuation-review-retains-existing-plan-identity";
  List.iter
    (fun dimensions ->
      let ended = key ~dimensions ~width_of review `End in
      let rows = Option.get (R.overlay_screen ~dimensions ~width_of ended) in
      require
        (List.length rows <= snd dimensions
        && List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows)
        "continuation-review-resize-bounded")
    [ (32, 9); (48, 14); (80, 24); (120, 36) ];
  let added = key ~width_of completed `Tab |> fun s -> key ~width_of s `Enter in
  let editor =
    match session_of added with
    | Some (E.Scheduled_create e) -> e
    | _ -> raise (F.Refused "continuation-add-editor")
  in
  require
    (Sch.day editor = "" && Sch.measure editor = "eur")
    "continuation-does-not-infer-date-or-copy-candidate-measure";
  let cancelled = key ~width_of added `Escape in
  require
    (no_modal cancelled
    && F.read path = after_payment
    && List.find (fun (p : B.plan) -> p.id = source.id) (B.plans (F.load path).book) = paid_source)
    "continuation-cancel-add-keeps-published-completion";
  let next = String.fold_left (fun s c -> key ~width_of s (`ASCII c)) added "2026-12-20" in
  let next =
    List.fold_left (fun s _ -> key ~width_of s `Tab) next (List.init 7 Fun.id) |> fun s ->
    key ~width_of s `Enter
  in
  require (F.read path = after_payment) "continuation-next-preview-is-read-only";
  let saved = key ~width_of next `Enter in
  let cold = F.load path in
  let created = List.find (fun (p : B.plan) -> p.day = "2026-12-20") (B.plans cold.book) in
  require
    (no_modal saved && created.id <> source.id && created.measure = source.measure
   && created.changes = source.changes && created.paid_by = None && created.cancelled_on = None
    && B.entries cold.book = B.entries completed.session.book
    && List.find (fun (p : B.plan) -> p.id = source.id) (B.plans cold.book) = paid_source)
    "continuation-cold-add-is-independent-and-preserves-exact-eur-quanta";
  let stale =
    input completed (`Key (`ASCII 'r', [ `Ctrl ])) |> fun s ->
    key ~width_of s `Tab |> fun s -> key ~width_of s `Enter
  in
  require
    (stale.blocked && (not stale.record_visible)
    && F.read_revision path = cold.revision
    && Cont.base_revision (prompt stale) = completed.session.revision)
    "continuation-reload-does-not-bless-stale-awareness";
  let none_path = directory ^ "/continuation-none.sexp" in
  let none = complete none_path source_book source in
  let none_bytes = F.read none_path in
  let done_ = key ~width_of none `Enter in
  require (no_modal done_ && F.read none_path = none_bytes) "continuation-done-never-adds";
  let defer = key ~width_of none `Tab in
  (* A save the writer refuses: the session no longer matches the file. *)
  let stale_session = load_synthetic_book none.session.book in
  (match F.publish stale_session [ B.Add_locus "concurrent" ] with
  | F.Written _ -> ()
  | _ -> raise (F.Refused "continuation-concurrent-fixture"));
  let failed = key ~width_of { defer with session = stale_session } `Enter in
  require
    (F.read none_path = none_bytes
    && (not failed.record_visible)
    && Cont.base_revision (prompt failed) = none.session.revision)
    "continuation-defer-failure-does-not-rollback-completion";
  let deferred = key ~width_of defer `Enter in
  let cold_deferred = F.load none_path in
  let attention = get (C.attention (C.initial ~config_home:directory cold_deferred)) in
  require
    (no_modal deferred
    && B.entries cold_deferred.book = B.entries none.session.book
    && B.plans cold_deferred.book = B.plans none.session.book
    && List.exists
         (fun (item : Att.item) ->
           item.due = Att.Due_undetermined
           && Base.String.is_substring item.context ~substring:source.id)
         (Att.open_items attention))
    "continuation-defer-cold-retains-undecided-attention-only";
  let empty_prompt = prompt none in
  List.iter
    (fun dimensions ->
      let rows = Cont.screen ~dimensions ~width_of empty_prompt in
      require
        (List.length rows <= snd dimensions
        && List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows)
        "continuation-choices-tiny-bounds")
    [ (0, 0); (1, 1); (32, 4); (32, 9) ];
  let uncertain_path = directory ^ "/continuation-uncertain.sexp" in
  F.write_new uncertain_path (Bakhlo_household.Daily_txt.text source_book);
  let base =
    C.open_route (C.initial ~config_home:directory (F.load uncertain_path)) W.Scheduled |> fun s ->
    Interaction_check_fixture.with_plan_query s source.id
  in
  let pay = C.submit (Interaction_check_fixture.pay_selected base) in
  let tx =
    match
      S.handle ~new_id:Daily_file.new_id ~book:source_book ~base_revision:pay.session.revision
        ~blocked:false ~dimensions:(140, 40) ~width_of (Option.get pay.record)
        (`Key (`Enter, []))
    with
    | S.Publish (Daily_actions.Entry_tx tx, _, _) -> tx
    | _ -> raise (F.Refused "continuation-uncertain-intent")
  in
  let op = [ B.Put_entry { replace = tx.replace; entry = tx.entry; plan = tx.plan } ] in
  let unknown =
    C.apply_commit_result ~record_publication:true pay ~draft:pay
      (Daily_actions.Uncertain
         {
           message = "synthetic lost acknowledgement";
           evidence = Daily_actions.Expected_revision (expected_after base.session op);
         })
  in
  let unconfirmed = Shell_dispatch.reload unknown in
  require
    (unconfirmed.blocked && unconfirmed.record_visible && no_modal unconfirmed)
    "continuation-unknown-completion-cannot-offer-add";
  (match F.publish base.session op with
  | F.Written _ -> ()
  | _ -> raise (F.Refused "continuation-confirmation-setup"));
  let confirmed = Shell_dispatch.reload unconfirmed in
  require
    ((not confirmed.blocked) && confirmed.pending = None && (not confirmed.record_visible)
    && B.entry_count confirmed.session.book = B.entry_count source_book + 1
    && Cont.base_revision (prompt confirmed) = confirmed.session.revision)
    "continuation-only-confirmed-reload-opens-awareness-without-retry";
  print_endline
    "PASS: post-completion Keep/Review/Add/Done/Defer, later positive-Locus awareness, exact \
     independent next plan, no inferred date, cold Attention, stale and unknown completion guards."

(* LOAM Series Calendar: pure projection with a fixed date, then the screen
   over a book-adjacent scheduled-coverage.tsv relative to today's month. *)
module Cov = Scheduled_coverage

let coverage_checks ~width_of ~directory home =
  let plan ?paid ?cancelled id day changes : B.plan =
    { id; day; measure = "jpy"; changes; paid_by = paid; cancelled_on = cancelled }
  in
  let rent = [ ("bank", Z.of_int (-50000)); ("rent", Z.of_int 50000) ] in
  let rules =
    get
      (Cov.of_string
         "rent\t2026-09-27\t1\tbank\trent\n\
          water\t2026-10-05\t2\tbank\twater\n\
          later\t2026-01-01\t0\tbank\tgym\n")
  in
  let plans =
    [
      plan ~paid:"e1" "r-oct" "2026-10-27" rent;
      plan "r-nov" "2026-11-27" rent;
      plan "r-nov2" "2026-11-30" rent;
      plan ~cancelled:"2026-10-01" "r-dec" "2026-12-27" rent;
      plan "split" "2026-11-03"
        [ ("bank", Z.of_int (-5)); ("wallet", Z.of_int (-5)); ("rent", Z.of_int 10) ];
      plan "w-dec" "2026-12-05" [ ("bank", Z.of_int (-9)); ("water", Z.of_int 9) ];
    ]
  in
  let months, rows = get (Cov.project rules ~plans ~today:"2026-10-19" ~months:4) in
  require (months = [ "2026-10"; "2026-11"; "2026-12"; "2027-01" ]) "coverage-month-window";
  require
    (List.map (fun (r : Cov.row) -> r.rule.name) rows = [ "rent"; "water"; "later" ])
    "coverage-cadence-then-undecided-order";
  let cells name =
    List.map Cov.cell_text (List.find (fun (r : Cov.row) -> r.rule.name = name) rows).cells
  in
  require (cells "rent" = [ "27✓"; "27,30"; "!"; "!" ]) "coverage-rent-open-completed-cancelled-gap";
  require (cells "water" = [ "!"; ""; "05"; "" ]) "coverage-water-two-month-cadence";
  require (cells "later" = [ ""; ""; ""; "" ]) "coverage-undecided-expects-nothing";
  require ((List.hd rows).first_missing = Some "2026-12") "coverage-first-missing";
  require
    (Cov.cell_text
       {
         Cov.month = "2026-11";
         expected = true;
         open_days = [ "01"; "02"; "03" ];
         completed_days = [ "04" ];
       }
    = "3p/1✓")
    "coverage-wide-cell-counts";
  List.iter
    (fun bad -> require (Result.is_error (Cov.of_string bad)) "coverage-malformed-refused")
    [
      "rent\t2026-02-30\t1\tbank\trent\n";
      "rent\t2026-01-01\tx\tbank\trent\n";
      "rent\t2026-01-01\t1\t\trent\n";
      "rent\t2026-01-01\t1\tbank,bank\trent\n";
      "a\t2026-01-01\t1\tbank\trent\nb\t2026-01-01\t2\tbank\trent\n";
      "a\t2026-01-01\t1\tbank\trent\na\t2026-01-01\t2\tbank\tfood\n";
      "\n\n";
    ];
  require (Cov.of_string "" = Ok []) "coverage-empty-file-no-rules";
  (* Screen: today's month, independent of the wall clock. *)
  let today = F.today () in
  let month_after n =
    let index =
      (int_of_string (String.sub today 0 4) * 12) + int_of_string (String.sub today 5 2) - 1 + n
    in
    Printf.sprintf "%04d-%02d" (index / 12) ((index mod 12) + 1)
  in
  let food = [ ("wallet", Z.of_int (-1234)); ("food", Z.of_int 1234) ] in
  let book =
    List.fold_left
      (fun book (p : B.plan) -> get (B.cancel_plan book ~id:p.id ~day:today))
      home.C.session.book (B.open_plans home.session.book)
  in
  let book =
    List.fold_left
      (fun book p -> get (B.put_plan book ~replace:false p))
      book
      [
        plan "cov-a" (month_after 0 ^ "-28") food;
        plan "cov-b" (month_after 1 ^ "-28") food;
        plan "cov-f" (month_after 0 ^ "-15") [ ("bank", Z.of_int (-500)); ("wallet", Z.of_int 500) ];
        plan "cov-u" (month_after 0 ^ "-10") [ ("bank", Z.of_int (-100)); ("food", Z.of_int 100) ];
      ]
  in
  let sub = directory ^ "/coverage-" ^ F.new_id () in
  Unix.mkdir sub 0o700;
  let path = sub ^ "/book.sexp" in
  F.write_new path (Bakhlo_household.Daily_txt.text book);
  F.write_new (sub ^ "/scheduled-coverage.tsv")
    ("groceries\t" ^ month_after 0 ^ "-01\t1\twallet\tfood\nbills\t" ^ month_after 0
   ^ "-01\t0\tbank\tfood\n" ^ "fees\t" ^ month_after 0 ^ "-01\t2\tbank\twallet\n");
  let before = F.read path in
  let initial = C.initial ~config_home:sub (F.load path) in
  let opened = C.open_route initial W.Scheduled in
  let contains state needle =
    List.exists
      (fun (_, line) -> Base.String.is_substring line ~substring:needle)
      (R.screen ~width_of (120, 36) state)
  in
  require
    (contains opened "Scheduled Series Calendar"
    && contains opened "Monitored plans (3)"
    && contains opened "groceries" && contains opened "monthly" && contains opened "undecided"
    && contains opened "! = expected gap")
    "coverage-is-scheduled-entrance-with-monitored-rows";
  List.iter
    (fun dimensions ->
      let rows = R.screen ~width_of dimensions opened in
      require
        (List.length rows <= snd dimensions
        && List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows)
        "coverage-resize-bounded")
    [ (32, 9); (48, 14); (80, 24); (120, 36) ];
  let shifted = key ~width_of opened (`ASCII 'l') in
  require (contains shifted ("Month window: " ^ month_after 1)) "coverage-month-offset";
  let detail = key ~width_of opened `Enter in
  require
    (contains detail "Scheduled / Plan / groceries"
    && contains detail "[on pace]"
    && contains detail "MISSING monitored month"
    && contains detail "1,234 jpy")
    "coverage-enter-opens-plan-entries-and-gaps";
  let gap = key ~width_of (key ~width_of detail (`ASCII 'j')) (`ASCII 'j') in
  let refused = key ~width_of gap (`ASCII 'c') in
  require
    (no_modal refused && (not refused.record_visible) && F.read path = before)
    "coverage-missing-month-is-not-an-occurrence";
  let paying = key ~width_of detail `Enter in
  require
    (paying.record_visible
    && (match S.mode (Option.get paying.record) with
      | Daily_actions.Pay id -> id = "cov-a"
      | _ -> false)
    && F.read path = before)
    "coverage-plan-enter-opens-completion-without-publishing";
  let cancelled = key ~width_of paying `Escape in
  require
    (contains cancelled "Scheduled / Plan / groceries" && F.read path = before)
    "coverage-completion-cancel-returns-to-plan";
  let replenishing = key ~width_of opened (`ASCII 'e') in
  require
    ((match session_of replenishing with
       | Some (E.Scheduled_generate g) -> (Gen.source g).id = "cov-b" && Gen.selected_months g = 1
       | _ -> false)
    && F.read path = before)
    "coverage-e-replenishes-from-latest-on-pace-occurrence";
  let closed = key ~width_of replenishing `Escape in
  require (no_modal closed && F.read path = before) "coverage-replenish-cancel-is-read-only";
  let fees = key ~width_of (key ~width_of opened (`ASCII 'j')) (`ASCII 'e') in
  require
    (match session_of fees with
    | Some (E.Scheduled_generate g) -> (Gen.source g).id = "cov-f" && Gen.selected_months g = 2
    | _ -> false)
    "coverage-e-preselects-two-month-cadence";
  let undecided =
    key ~width_of (key ~width_of (key ~width_of opened (`ASCII 'j')) (`ASCII 'j')) (`ASCII 'e')
  in
  require
    (no_modal undecided && contains undecided "cannot be extended automatically")
    "coverage-undecided-cannot-replenish";
  let back = key ~width_of detail (`ASCII 'q') in
  require (contains back "Scheduled Series Calendar") "coverage-plan-q-returns-to-overview";
  let months = key ~width_of opened (`ASCII 'v') in
  let listed = key ~width_of months (`ASCII 'v') in
  let again = key ~width_of listed (`ASCII 'v') in
  require
    (plan_months_view months
    && contains listed "Scheduled / List"
    && contains again "Scheduled Series Calendar")
    "coverage-view-cycle-overview-months-list";
  let coverage_text () = F.read (sub ^ "/scheduled-coverage.tsv") in
  let original_rules = coverage_text () in
  let anchor_b = month_after 1 ^ "-28" in
  let choosing = key ~width_of opened (`ASCII 'p') in
  require
    ((not (no_modal choosing))
    && contains choosing "Scheduled / Plan Monitoring"
    && contains choosing "Expected pace" && contains choosing "> Monthly")
    "coverage-p-opens-expected-pace-chooser";
  let kept = key ~width_of choosing `Escape in
  require
    (no_modal kept
    && coverage_text () = original_rules
    && Base.String.is_substring kept.message ~substring:"Plan monitoring unchanged")
    "coverage-pace-escape-keeps-config";
  let paced = key ~width_of (key ~width_of choosing (`ASCII 'j')) `Enter in
  require
    (no_modal paced
    && F.read path = before
    && Base.String.is_substring (coverage_text ())
         ~substring:("groceries\t" ^ anchor_b ^ "\t2\twallet\tfood\n")
    && Base.String.is_substring paced.message
         ~substring:("Monitoring groceries: Every 2 months from " ^ anchor_b)
    && contains paced "> groceries")
    "coverage-p-saves-cadence-reanchors-and-follows-row";
  let undecided = key ~width_of paced (`ASCII 's') in
  require
    (F.read path = before
    && Base.String.is_substring (coverage_text ())
         ~substring:("groceries\t" ^ anchor_b ^ "\t0\twallet\tfood\n")
    && Base.String.is_substring undecided.message ~substring:"Future pace is undecided"
    && contains undecided "> groceries")
    "coverage-s-makes-pace-undecided-keeping-anchor-and-name";
  let stale = key ~width_of undecided (`ASCII 'p') in
  F.write_new (sub ^ "/other") original_rules;
  Unix.rename (sub ^ "/other") (sub ^ "/scheduled-coverage.tsv");
  let refused = key ~width_of stale `Enter in
  (* LOAM upserts into the image current at save time, so a change made
     elsewhere meanwhile is kept, never overwritten by a stale snapshot. *)
  require
    (F.read path = before
    && coverage_text ()
       = String.concat ""
           [
             "groceries\t" ^ anchor_b ^ "\t1\twallet\tfood\n";
             "bills\t" ^ month_after 0 ^ "-01\t0\tbank\tfood\n";
             "fees\t" ^ month_after 0 ^ "-01\t2\tbank\twallet\n";
           ]
    && Base.String.is_substring refused.message ~substring:"Monitoring groceries: Monthly")
    "coverage-pace-applies-onto-current-config";
  F.write_new (sub ^ "/bad") "";
  Unix.rename (sub ^ "/bad") (sub ^ "/scheduled-coverage.tsv");
  let malformed = C.open_route (C.initial ~config_home:sub (F.load path)) W.Scheduled in
  require (contains malformed "Scheduled / List") "coverage-empty-config-falls-back-to-list";
  F.write_new (sub ^ "/bad") "groceries\tnot-a-date\t1\twallet\tfood\n";
  Unix.rename (sub ^ "/bad") (sub ^ "/scheduled-coverage.tsv");
  let broken = C.open_route (C.initial ~config_home:sub (F.load path)) W.Scheduled in
  require
    (contains broken "Monitored plans [Unavailable]" && contains broken "malformed")
    "coverage-malformed-config-is-visible-not-empty";
  Unix.unlink (sub ^ "/scheduled-coverage.tsv");
  let none = C.open_route (C.initial ~config_home:sub (F.load path)) W.Scheduled in
  require (contains none "Scheduled / List") "coverage-missing-config-keeps-list-entrance";
  require (F.read path = before) "coverage-read-only";

  (* LOAM p / m / s / e from List and Months (UI-23): monitoring of the selected
     plan, and e on an unmonitored plan choosing a pace before extending. *)
  let lsub = directory ^ "/coverage-list-" ^ F.new_id () in
  Unix.mkdir lsub 0o700;
  let transfer = [ ("wallet", Z.of_int (-300)); ("bank", Z.of_int 300) ] in
  let lbook =
    List.fold_left
      (fun b p -> get (B.put_plan b ~replace:false p))
      book
      [ plan "lm-u" (month_after 0 ^ "-05") transfer ]
  in
  let lpath = lsub ^ "/book.sexp" in
  F.write_new lpath (Bakhlo_household.Daily_txt.text lbook);
  F.write_new
    (lsub ^ "/scheduled-coverage.tsv")
    ("groceries\t" ^ month_after 0 ^ "-01\t1\twallet\tfood\n");
  let lrules () = F.read (lsub ^ "/scheduled-coverage.tsv") in
  let lbefore = F.read lpath in
  let lopened = C.open_route (C.initial ~config_home:lsub (F.load lpath)) W.Scheduled in
  let llist = key ~width_of (key ~width_of lopened (`ASCII 'v')) (`ASCII 'v') in
  require
    (contains llist "Scheduled / List"
    && plan_id llist = Some (Record_browser.Scheduled_row, "lm-u"))
    "list-monitor-fixture-selects-unmonitored";
  let lchoosing = key ~width_of llist (`ASCII 'p') in
  require
    ((not (no_modal lchoosing)) && contains lchoosing "Expected pace")
    "list-p-opens-expected-pace";
  let lkept = key ~width_of lchoosing `Escape in
  require
    (no_modal lkept
    && Base.String.is_substring lkept.message ~substring:"Plan monitoring unchanged"
    && lrules () = "groceries\t" ^ month_after 0 ^ "-01\t1\twallet\tfood\n")
    "list-pace-escape-keeps-config";
  let lextend = key ~width_of lkept (`ASCII 'e') in
  require
    ((not (no_modal lextend)) && contains lextend "Expected pace")
    "list-e-unmonitored-asks-pace-first";
  let lcancel = key ~width_of lextend `Escape in
  require
    (no_modal lcancel
    && Base.String.is_substring lcancel.message ~substring:"Extend cancelled"
    && F.read lpath = lbefore)
    "list-e-pace-escape-cancels-extend";
  let lgen = key ~width_of (key ~width_of lcancel (`ASCII 'e')) `Enter in
  require
    ((match session_of lgen with
       | Some (E.Scheduled_generate g) -> (Gen.source g).id = "lm-u" && Gen.selected_months g = 1
       | _ -> false)
    && Base.String.is_substring (lrules ()) ~substring:"\t1\twallet\tbank\n"
    && F.read lpath = lbefore)
    "list-e-saves-pace-then-opens-generation";
  let lclosed = key ~width_of lgen `Escape in
  let lundecided = key ~width_of lclosed (`ASCII 's') in
  require
    (Base.String.is_substring (lrules ()) ~substring:"\t0\twallet\tbank\n"
    && Base.String.is_substring lundecided.message ~substring:"Future pace is undecided")
    "list-s-makes-pace-undecided";
  let lrefused = key ~width_of lundecided (`ASCII 'e') in
  require
    (no_modal lrefused
    && Base.String.is_substring lrefused.message ~substring:"cannot be extended automatically")
    "list-e-undecided-cannot-extend";
  let lloci = key ~width_of (key ~width_of lundecided (`ASCII 'h')) (`ASCII 'p') in
  require
    (no_modal lloci && Base.String.is_substring lloci.message ~substring:"Focus the Scheduled pane")
    "list-loci-pane-refuses-monitoring";
  let lmonths = key ~width_of (key ~width_of lundecided (`ASCII 'v')) (`ASCII 'v') in
  let lmonths_pace = key ~width_of lmonths (`ASCII 'm') in
  require
    (plan_months_view lmonths
    && (not (no_modal lmonths_pace))
    && contains lmonths_pace "Expected pace")
    "months-m-opens-expected-pace";
  require (F.read lpath = lbefore) "list-monitoring-never-writes-the-book";

  (* e through the controller: one explicit plan, atomic cold write, then a
     stale reload that must not publish. Synthetic dates derived from today. *)
  let esub = directory ^ "/coverage-e-" ^ F.new_id () in
  Unix.mkdir esub 0o700;
  let ebook =
    List.fold_left
      (fun b (p : B.plan) -> get (B.cancel_plan b ~id:p.id ~day:today))
      home.session.book (B.open_plans home.session.book)
  in
  let ebook = get (B.put_plan ebook ~replace:false (plan "e-base" (month_after 0 ^ "-28") food)) in
  let ebook = get (B.put_plan ebook ~replace:false (plan "e-src" (month_after 1 ^ "-28") food)) in
  let epath = esub ^ "/book.sexp" in
  F.write_new epath (Bakhlo_household.Daily_txt.text ebook);
  F.write_new
    (esub ^ "/scheduled-coverage.tsv")
    ("groceries\t" ^ month_after 0 ^ "-01\t1\twallet\tfood\n");
  let estate = C.open_route (C.initial ~config_home:esub (F.load epath)) W.Scheduled in
  let eopen = key ~width_of estate (`ASCII 'e') in
  require
    (match session_of eopen with Some (E.Scheduled_generate _) -> true | _ -> false)
    "coverage-e-opens-monitored-horizon";
  let epublished =
    key ~width_of (key ~width_of (key ~width_of (key ~width_of eopen `Enter) `Tab) `End) `Enter
  in
  let ecold = F.load epath in
  let escope = month_after 2 ^ "-28" in
  let eplan = List.find (fun (p : B.plan) -> p.day = escope) (B.plans ecold.book) in
  require
    (no_modal epublished
    && List.length (B.plans ecold.book) = List.length (B.plans ebook) + 1
    && eplan.measure = "jpy" && eplan.changes = food && eplan.paid_by = None
    && eplan.cancelled_on = None)
    "coverage-e-publishes-one-explicit-plan-atomically-cold";

  let epath2 = esub ^ "/stale.sexp" in
  F.write_new epath2 (Bakhlo_household.Daily_txt.text ebook);
  let estate2 = C.open_route (C.initial ~config_home:esub (F.load epath2)) W.Scheduled in
  let epending = key ~width_of (key ~width_of (key ~width_of estate2 (`ASCII 'e')) `Enter) `Tab in
  let changed_book =
    get (B.put_plan ebook ~replace:false (plan "outside" (month_after 0 ^ "-01") food))
  in
  let tmp = epath2 ^ ".tmp" in
  F.write_new tmp (Bakhlo_household.Daily_txt.text changed_book);
  Unix.rename tmp epath2;
  let erefused = key ~width_of (Shell_dispatch.reload epending) `Enter in
  require
    (erefused.blocked
    && F.read_revision epath2 = F.revision_of_bytes (Bakhlo_household.Daily_txt.text changed_book)
    && not (List.exists (fun (p : B.plan) -> p.day = escope) (B.plans (F.load epath2).book)))
    "coverage-e-stale-reload-cannot-publish";

  (* LOAM finishCreated (UI-23): an ordinary creation offers the published plan's
     expected pace over the route it was started from; the plan is never re-created. *)
  let csub = directory ^ "/coverage-created-" ^ F.new_id () in
  Unix.mkdir csub 0o700;
  let crules () =
    let file = csub ^ "/scheduled-coverage.tsv" in
    if Sys.file_exists file then F.read file else ""
  in
  let create_from state =
    let typed s text = String.fold_left (fun s c -> key ~width_of s (`ASCII c)) s text in
    let s =
      List.fold_left
        (fun s text -> typed (key ~width_of s `Tab) text)
        state
        [ "bank"; "-700"; "wallet"; "700" ]
    in
    let previewed =
      List.fold_left (fun s _ -> key ~width_of s `Tab) s [ 1; 2; 3 ] |> fun s ->
      key ~width_of s `Enter
    in
    key ~width_of previewed `Enter
  in
  let created_in path =
    List.filter
      (fun (p : B.plan) -> p.changes = [ ("bank", Z.of_int (-700)); ("wallet", Z.of_int 700) ])
      (B.plans (F.load path).book)
  in
  let fresh name =
    let path = csub ^ "/" ^ name ^ ".sexp" in
    F.write_new path (Bakhlo_household.Daily_txt.text book);
    path
  in
  let cpath = fresh "list" in
  let clist = C.open_route (C.initial ~config_home:csub (F.load cpath)) W.Scheduled in
  require (contains clist "Scheduled / List") "created-pace-fixture-starts-on-list";
  let cchoosing = create_from (key ~width_of clist (`ASCII 'n')) in
  require
    (List.length (created_in cpath) = 1
    && (not (no_modal cchoosing))
    && contains cchoosing "Expected pace after creation"
    && contains cchoosing "> This occurrence only")
    "created-pace-offered-after-ordinary-creation";
  let clast = key ~width_of cchoosing (`Arrow `Up) in
  List.iter
    (fun dimensions ->
      let rows = R.screen ~width_of dimensions clast in
      require
        (List.length rows <= snd dimensions
        && List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows
        && (fst dimensions < 48
           || List.exists
                (fun (_, line) ->
                  Base.String.is_substring line ~substring:"> Future pace undecided")
                rows))
        "created-pace-selection-stays-visible-and-bounded")
    [ (32, 9); (48, 14); (80, 24); (120, 36) ];
  let ckept = key ~width_of cchoosing `Escape in
  require
    (no_modal ckept && contains ckept "Scheduled / List"
    && crules () = ""
    && List.length (created_in cpath) = 1
    && Base.String.is_substring ckept.message
         ~substring:"Expected pace unchanged; no future Scheduled created.")
    "created-pace-escape-keeps-config-and-returns";
  let cmonthly = key ~width_of (key ~width_of cchoosing (`ASCII 'j')) `Enter in
  require
    (no_modal cmonthly
    && contains cmonthly "Scheduled / List"
    && Base.String.is_substring (crules ()) ~substring:"\t1\tbank\twallet\n"
    && Base.String.is_substring cmonthly.message ~substring:"Expected pace: Monthly"
    && List.length (created_in cpath) = 1)
    "created-pace-cadence-saves-monitoring-without-another-plan";
  let cundecided = key ~width_of (key ~width_of cchoosing (`Arrow `Up)) `Enter in
  require
    (no_modal cundecided
    && Base.String.is_substring (crules ()) ~substring:"\t0\tbank\twallet\n"
    && Base.String.is_substring cundecided.message ~substring:"Expected pace: undecided"
    && List.length (created_in cpath) = 1)
    "created-pace-undecided-saves-explicitly";
  let hpath = fresh "home" in
  let hhome = C.initial ~config_home:csub (F.load hpath) in
  let hchoosing = create_from (X.open_command hhome M.New_plan) in
  require
    ((not (no_modal hchoosing)) && hchoosing.workspace.route = hhome.workspace.route)
    "created-pace-from-commands-stays-over-starting-route";
  let hback = key ~width_of hchoosing `Escape in
  require
    (no_modal hback
    && hback.workspace.route = hhome.workspace.route
    && List.length (created_in hpath) = 1)
    "created-pace-escape-returns-to-commands-route";

  print_endline
    "PASS: Scheduled Series Calendar coverage rules/projection, entrance, month window, plan \
     entries/gaps, completion handoff/cancel, view cycle, malformed/missing config and read-only \
     bytes."
