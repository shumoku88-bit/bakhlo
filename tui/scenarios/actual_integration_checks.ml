(* Synthetic controller integration checks; see docs/RECONSTRUCTION_TEST_MAP.ja.md. *)
open Interaction_check_fixture

let actual_browsing_checks ~width_of ~directory home =
  let posting ?(measure = "jpy") locus quanta =
    D.Effect.create ~key:None
      ~locus:(get_id (D.Identifier.Locus.of_string locus))
      ~measure:(get_id (D.Identifier.Measure.of_string measure))
      ~quantity:(D.Quantity.of_quanta quanta)
  in
  let huge = Z.of_string (String.make 70 '9') in
  let entry n : B.entry =
    {
      id = Printf.sprintf "actual-%02d" n;
      day = Printf.sprintf "2026-10-%02d" (n + 1);
      memo =
        Some
          (if n = 17 then String.concat " " (List.init 80 (fun _ -> "日本語の長い説明"))
           else Printf.sprintf "Synthetic purchase %02d" n);
      effects =
        [
          posting "wallet" (Z.neg (if n = 17 then huge else Z.of_int (1234 + n)));
          posting "food" (if n = 17 then huge else Z.of_int (1234 + n));
        ];
      reversal_of = None;
      exchange = None;
      original_amount = None;
      merchant = None;
    }
  in
  let book =
    List.fold_left
      (fun book n -> get (B.put_entry book ~replace:false (entry n) ~plan:None))
      home.C.session.book (List.init 18 Fun.id)
  in
  let path = directory ^ "/actual-browsing.txt" in
  F.write_new path (Bakhlo_household.Daily_txt.text book);
  let before = F.read path in
  let state = C.open_route (C.initial ~config_home:directory (F.load path)) W.Actual in
  let contains rows needle =
    List.exists (fun (_, line) -> Base.String.is_substring line ~substring:needle) rows
  in
  require (Record_lines.actual_amount book (entry 0) = "+1,234 jpy") "actual-grouped-exact-amount";
  let euro = { (entry 0) with effects = [ posting ~measure:"eur" "food" (Z.of_int 123456) ] } in
  require
    (Record_lines.actual_amount book euro = "+1,234.56 eur")
    "actual-grouping-retains-decimals";
  require
    (Record_lines.actual_amount book
       { euro with effects = [ posting ~measure:"eur" "food" (Z.of_int (-123456)) ] }
    = "-1,234.56 eur")
    "actual-negative-amount-sign";
  require
    (Record_lines.actual_amount book { euro with effects = [] } = "—")
    "actual-missing-effects-not-zero";
  require
    (Record_lines.actual_amount book { euro with effects = [ posting "food" Z.zero ] } = "0 jpy")
    "actual-explicit-zero";
  require
    (Record_lines.actual_amount book
       {
         euro with
         effects =
           [ posting "wallet" (Z.of_int (-3)); posting "food" Z.one; posting "bank" (Z.of_int 2) ];
       }
    = "split")
    "actual-split-not-invented-total";
  require
    (Record_lines.actual_amount book { euro with effects = posting "food" Z.one :: euro.effects }
    = "multi (2)")
    "actual-mixed-measures-not-summed";
  let heading, titles =
    Record_lines.actual_table ~width_of ~width:58 book
      [ Record_browser.Actual_entry (entry 0); Record_browser.Actual_entry (entry 17) ]
  in
  require
    (Base.String.is_substring heading ~substring:"Amount"
    && Base.String.is_substring (List.hd titles) ~substring:"+1,234 jpy"
    && Base.String.is_substring (List.nth titles 1) ~substring:"see details"
    && Base.String.is_substring (List.nth titles 1) ~substring:"…"
    && List.for_all (fun line -> width_of line = 52) titles)
    "actual-fixed-columns-safe-ellipsis";
  List.iter
    (fun dimensions ->
      let key = key ~dimensions ~width_of in
      let detail = key state (`ASCII 'i') in
      let _, view = actual_window ~dimensions ~width_of detail in
      let capacity = view.Ui_panel.capacity and last = view.last in
      let identity = actual_selected_id detail in
      let ended = key detail `End in
      require
        (actual_scroll ended = last && actual_selected_id ended = identity)
        "actual-detail-end-does-not-reselect";
      require
        (actual_scroll (key ended (`ASCII 'j')) = last
        && actual_scroll (key ended (`ASCII 'k')) = max 0 (last - 1))
        "actual-detail-bottom-is-clamped-and-up-is-immediate";
      require
        (actual_scroll (key ended `Home) = 0 && actual_selected_id (key ended `Home) = identity)
        "actual-detail-home-does-not-reselect";
      require
        (actual_scroll (key detail (`Page `Down)) = min last (max 1 capacity))
        "actual-detail-page-visible-capacity";
      let listed = key ended `Escape in
      require
        ((not (actual_detail listed)) && actual_selected_id listed = identity)
        "actual-back-retains-selection";
      let page = key state (`Page `Down) in
      let content_w, content_h = actual_dims ~dimensions ~width_of state in
      let body_capacity = max 0 content_h + 1 in
      let context_rows = if body_capacity >= 5 then 2 else if body_capacity >= 4 then 1 else 0 in
      let panel_height = max 0 (content_h - context_rows) in
      let terminal = content_h + 4 in
      let detail_capacity = if terminal >= 48 then 12 else if terminal >= 36 then 10 else 8 in
      let tall = panel_height >= 16 && terminal >= 30 in
      let detail_height = if tall then detail_capacity + 1 else 0 in
      let wide = content_w >= 98 && tall in
      let tx_h = if wide then panel_height else max 0 (panel_height - detail_height) in
      let expected_page = min 17 (max 1 (tx_h - 2 - if tx_h >= 4 then 1 else 0)) in
      require (actual_row page = expected_page) "actual-list-page-excludes-borders-and-heading";
      let last_row = key state `End in
      require (actual_row last_row = 17 && actual_scroll last_row = 0) "actual-list-end-real-last";
      List.iter
        (fun state ->
          let rows = R.screen ~width_of dimensions state in
          require
            (List.length rows <= snd dimensions
            && List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows)
            "actual-bounded-layout";
          if snd dimensions >= 14 && actual_detail state then
            require (contains rows "ID: actual-17") "actual-long-detail-complete-id-at-end")
        [ state; page; ended ])
    [ (32, 9); (48, 14); (80, 24); (120, 36) ];
  let detail =
    key ~dimensions:(32, 9) ~width_of state (`ASCII 'i') |> fun s ->
    key ~dimensions:(32, 9) ~width_of s `End
  in
  let resized = key ~dimensions:(120, 36) ~width_of detail (`ASCII '!') in
  let _, resized_view = actual_window ~dimensions:(120, 36) ~width_of resized in
  require
    (actual_scroll resized = resized_view.Ui_panel.last
    && actual_selected_id resized = actual_selected_id detail)
    "actual-resize-clamps-without-reselection";
  let query = String.make 80 'x' ^ "日本語末尾" in
  let searching = key ~width_of state (`ASCII '/') |> fun s -> text ~width_of s query in
  List.iter
    (fun ((width, _) as dimensions) ->
      let rows = R.screen ~width_of dimensions searching in
      let header = snd (List.nth rows 1) in
      let caret = String.length header - 1 in
      require
        (Base.String.is_substring header ~substring:"日本語末尾")
        "actual-long-search-keeps-insertion-tail-visible";
      require
        (header.[caret] = ' '
        && width_of header < width
        && R.cursor_position ~width_of dimensions searching
           = Some (width_of (String.sub header 0 caret), 1))
        "actual-search-caret-matches-painted-insertion-cell";
      require (actual_query searching = query) "actual-search-resize-does-not-truncate-filter")
    [ (32, 9); (48, 14); (80, 24); (120, 36) ];
  let accepted = key ~width_of searching `Enter in
  require
    (actual_query accepted = query && R.cursor_position ~width_of (32, 9) accepted = None)
    "actual-long-search-accept-keeps-full-query-and-hides-caret";
  require
    (R.cursor_position ~width_of (0, 9) searching = None
    && R.cursor_position ~width_of (32, 1) searching = None)
    "actual-search-hides-caret-without-visible-input-cell";
  let searched = key ~width_of state (`ASCII '/') |> fun s -> text ~width_of s "purchase 03" in
  require
    (List.length (actual_rows searched) = 1 && actual_query searched = "purchase 03")
    "actual-search-filters-while-typing";
  let kept = key ~width_of searched `Enter in
  require (actual_query kept = "purchase 03") "actual-search-enter-keeps";
  let cleared = key ~width_of (key ~width_of kept (`ASCII '/')) `Escape in
  require
    (actual_query cleared = "" && List.length (actual_rows cleared) = 18)
    "actual-search-escape-clears";
  let parent = key ~width_of state (`ASCII 'j') in
  let draft = prepare_record ~width_of parent in
  let draft_rows = S.screen ~book ~dimensions:(72, 20) ~width_of (Option.get draft.record) in
  let closed = key ~width_of draft `Escape in
  require
    (same_workspace closed parent && C.has_record_draft closed && not closed.record_visible)
    "actual-record-cancel-retains-parent-and-draft";
  let resumed = key ~width_of closed (`ASCII 'n') in
  require
    (resumed.record_visible
    && S.screen ~book ~dimensions:(72, 20) ~width_of (Option.get resumed.record) = draft_rows)
    "actual-record-resumes-exact-draft";
  let at_second = key ~width_of state (`ASCII 'j') in
  let at_details = key ~width_of at_second (`ASCII 'i') in
  let drilled = key ~width_of at_details `Enter in
  require
    (match drilled.workspace.route with W.Selected_day d -> d = (entry 16).day | _ -> false)
    "actual-enter-drills-to-selected-day";
  List.iter
    (fun dimensions ->
      let direct = key ~dimensions ~width_of at_second `Enter in
      require
        (direct.workspace.route = W.Selected_day (entry 16).day
        && direct.drill_parent = Some W.Actual)
        "actual-single-enter-opens-with-parent";
      let returned = key ~dimensions ~width_of direct `Escape in
      require
        (returned.screens.actual = at_second.screens.actual && not (actual_detail returned))
        "actual-single-enter-return-preserves-list";
      let same_day_book =
        get (B.put_entry book ~replace:true { (entry 15) with day = (entry 16).day } ~plan:None)
      in
      let parent = { at_second with session = load_synthetic_book same_day_book } in
      let parent =
        with_day_browser parent
          {
            (day_browser parent) with
            query = "stale unmatched search";
            locus = Some "absent";
            day = Some "2020-01-01";
          }
      in
      let parent = key ~dimensions ~width_of parent (`ASCII 'j') in
      let direct = key ~dimensions ~width_of parent `Enter in
      require
        (match day_selected direct with
        | Some (Record_browser.Actual_entry e) -> e.id = "actual-16"
        | _ -> false)
        "actual-drill-opens-exact-id-despite-same-day-and-old-filters";
      require (F.read path = before) "actual-drill-and-return-do-not-write")
    [ (80, 24); (48, 14); (32, 9) ];
  (* Selected Day retains the old deferred overlay and raw detail-motion contract. *)
  let day_book =
    List.fold_left
      (fun book n ->
        get (B.put_entry book ~replace:true { (entry n) with day = (entry 16).day } ~plan:None))
      book [ 15; 17 ]
  in
  let day_base = { state with session = load_synthetic_book day_book } in
  let day = C.open_route day_base (W.Selected_day (entry 16).day) in
  require
    (day_id day = Some (Record_browser.Actual_row, "actual-17")
    && day_id (key ~width_of day (`Arrow `Down)) = Some (Record_browser.Actual_row, "actual-16")
    && day_id (key ~width_of (key ~width_of day (`ASCII 'J')) (`Arrow `Up)) = day_id day)
    "selected-day-entry-syncs-before-first-normalized-motion";
  let stale =
    with_day_browser day_base
      {
        (day_browser day) with
        selected = 99;
        selected_id = Some (Record_browser.Actual_row, "missing");
      }
  in
  let clamped = C.open_route stale (W.Selected_day (entry 16).day) in
  require
    ((Selected_day.browser clamped.screens.day).selected = 2
    && day_id clamped = Some (Record_browser.Actual_row, "actual-15")
    && day_id (key ~width_of clamped (`Arrow `Up)) = Some (Record_browser.Actual_row, "actual-16"))
    "selected-day-entry-persists-clamped-selection-before-motion";
  let detail = key ~width_of day (`ASCII 'I') in
  let ended = key ~width_of detail `End in
  require
    (day_detail ended
    && day_id ended = Some (Record_browser.Actual_row, "actual-15")
    && day_scroll ended = max_int / 4
    && day_scroll (key ~width_of ended (`ASCII 'K')) = (max_int / 4) - 1)
    "selected-day-detail-end-reselects-and-retains-unclamped-scroll";
  let first = key ~width_of ended `Home in
  require
    (day_detail first
    && day_id first = Some (Record_browser.Actual_row, "actual-17")
    && day_scroll first = 0)
    "selected-day-detail-home-reselects-first";
  List.iter
    (fun dimensions ->
      let paged = key ~dimensions ~width_of first (`Page `Down) in
      require
        (day_scroll paged = max 1 (snd dimensions - 8)
        && day_id paged = day_id first
        && day_detail paged)
        "selected-day-detail-page-uses-screen-height-minus-eight")
    [ (32, 9); (48, 14); (80, 24); (120, 36) ];
  let retained : Record_browser.t =
    {
      query = "purchase";
      locus = Some "wallet";
      day = Some (entry 16).day;
      order = Record_browser.Oldest;
      selected = 1;
      selected_id = Some (Record_browser.Actual_row, "actual-16");
    }
  in
  let retained_day = with_day_browser day retained in
  let revisited = C.open_route (C.open_route retained_day W.Home) (W.Selected_day (entry 16).day) in
  require
    (Selected_day.browser revisited.screens.day = retained
    && (not (day_detail revisited))
    && day_scroll revisited = 0)
    "selected-day-revisit-retains-filter-order-and-identity";
  (* A refused reload can replace the snapshot without admitting browser sync.
     Reads, painting and action targets must all keep the same raw row index. *)
  let stale_browser =
    {
      (day_browser day) with
      selected = 2;
      selected_id = Some (Record_browser.Actual_row, "actual-15");
    }
  in
  let raw = Selected_day.with_browser day.screens.day stale_browser in
  let reordered =
    get
      (B.put_entry day_book ~replace:false
         { (entry 18) with day = (entry 16).day; memo = Some "Inserted before retained rows" }
         ~plan:None)
  in
  let env = Screen.env_for_checks ~book:reordered ~measure:"jpy" ~today:(entry 16).day () in
  let env = { env with blocked = true } in
  let geometry : Screen.geometry =
    { screen = (120, 36); body = (120, 34); content = (120, 32); width_of }
  in
  require
    (match Selected_day.selected_row reordered raw with
    | Some (Record_browser.Actual_entry e) -> e.id = "actual-16"
    | _ -> false)
    "selected-day-refused-snapshot-read-keeps-raw-index";
  let _, request = Selected_day.handle env geometry raw (`Key (`ASCII 'e', [])) in
  require
    (match request with
    | Screen.Record_action { target = Some (Screen.Entry e); _ } -> e.id = "actual-16"
    | _ -> false)
    "selected-day-refused-snapshot-action-matches-raw-selection";
  let detail, _ = Selected_day.handle env geometry raw (`Key (`ASCII 'i', [])) in
  require
    (contains (Lazy.force (Selected_day.view env geometry detail).rows) "Synthetic purchase 16"
    && Selected_day.browser detail = stale_browser)
    "selected-day-refused-snapshot-paint-keeps-raw-browser";
  let moved, _ = Selected_day.handle env geometry raw (`Key (`ASCII 'j', [])) in
  require
    (match Selected_day.selected_row reordered moved with
    | Some (Record_browser.Actual_entry e) -> e.id = "actual-15"
    | _ -> false)
    "selected-day-refused-snapshot-first-motion-advances-visible-row";
  require
    ((Selected_day.browser (Selected_day.synced reordered raw)).selected = 3
    && (Selected_day.browser (Selected_day.synced reordered raw)).selected_id
       = stale_browser.selected_id)
    "selected-day-qualified-sync-explicitly-reanchors-identity";
  let searching =
    key ~width_of { day with message = "search sentinel"; record = closed.record } (`ASCII '/')
    |> fun s -> text ~width_of s "purchase 16"
  in
  require
    ((day_browser searching).query = ""
    && List.length (day_rows searching) = 3
    && Selected_day.modal searching.screens.day)
    "selected-day-search-defers-query-until-enter";
  List.iter
    (fun c ->
      let swallowed =
        match H.handle ~width_of searching (`Key (`ASCII c, [ `Ctrl ])) with
        | Some state -> state
        | None -> raise (F.Refused "selected-day-search-ran-quit")
      in
      require
        (swallowed.screens.day = searching.screens.day
        && swallowed.message = searching.message
        && swallowed.overlay = C.No_overlay
        && swallowed.record = searching.record
        && swallowed.session.revision = searching.session.revision
        && F.read path = before)
        "selected-day-search-swallows-global-quit-discard")
    [ 'q'; 'Q'; 'n'; 'N' ];
  List.iter
    (fun c ->
      let reloaded =
        match H.handle ~width_of searching (`Key (`ASCII c, [ `Ctrl ])) with
        | Some state -> state
        | None -> raise (F.Refused "selected-day-search-reload-exited")
      in
      require
        (Selected_day.modal reloaded.screens.day
        && (day_browser reloaded).query = ""
        && reloaded.message = C.tr "Reloaded. Unsaved draft retained."
        && reloaded.record = searching.record
        && F.read path = before
        && (key ~width_of reloaded `Enter |> day_browser).query = "purchase 16")
        "selected-day-search-ctrl-r-reloads-and-keeps-search")
    [ 'r'; 'R' ];
  let applied = key ~width_of searching `Enter in
  require
    ((day_browser applied).query = "purchase 16"
    && List.length (day_rows applied) = 1
    && day_id applied = Some (Record_browser.Actual_row, "actual-16")
    && not (Selected_day.modal applied.screens.day))
    "selected-day-search-enter-applies-retained-query";
  let cleared_day = key ~width_of (key ~width_of applied (`ASCII '/')) `Escape in
  require
    ((day_browser cleared_day).query = ""
    && List.length (day_rows cleared_day) = 3
    && not (Selected_day.modal cleared_day.screens.day))
    "selected-day-search-escape-clears";
  (* A failed reload kept the old central viewport; both extracted owners must
     preserve that viewport and a retained Record without accepting bad bytes. *)
  List.iter
    (fun (name, route, focus, scroll, browser) ->
      let reload_path = directory ^ "/" ^ name ^ "-reload.txt" in
      let bytes = Bakhlo_household.Daily_txt.text day_book in
      F.write_new reload_path bytes;
      let base = C.initial ~config_home:directory (F.load reload_path) in
      let base = { base with workspace = { base.workspace with focus_day = (entry 16).day } } in
      let detailed : C.state = focus (C.open_route base route) in
      let detailed = { detailed with record = closed.record } in
      let old_scroll = scroll detailed and old_browser = browser detailed in
      require
        (old_scroll > 0 && C.has_record_draft detailed)
        "owner-failed-reload-fixture-holds-viewport-and-draft";
      let corrupt = "invalid synthetic reload fixture" in
      Out_channel.with_open_bin reload_path (fun oc -> output_string oc corrupt);
      let refused =
        match H.handle ~width_of detailed (`Key (`ASCII 'r', [ `Ctrl ])) with
        | Some s -> s
        | None -> raise (F.Refused "owner-failed-reload-quit")
      in
      require
        (refused.blocked && refused.message <> ""
        && scroll refused = old_scroll
        && browser refused = old_browser
        && same_workspace refused detailed && refused.record = detailed.record
        && (not refused.record_visible)
        && refused.session.revision = F.revision_of_bytes bytes
        && F.read reload_path = corrupt)
        "owner-failed-reload-preserves-viewport-selection-book-and-held-draft";
      Out_channel.with_open_bin reload_path (fun oc -> output_string oc bytes);
      let restored =
        match H.handle ~width_of refused (`Key (`ASCII 'r', [ `Ctrl ])) with
        | Some s -> s
        | None -> raise (F.Refused "owner-successful-reload-quit")
      in
      require
        ((not restored.blocked)
        && scroll restored = 0
        && browser restored = old_browser
        && restored.record = detailed.record
        && F.read reload_path = bytes)
        "owner-successful-reload-resets-viewport-and-retains-held-draft")
    [
      ( "day",
        W.Selected_day (entry 16).day,
        (fun s -> key ~width_of (key ~width_of s (`ASCII 'i')) `End),
        day_scroll,
        day_browser );
    ];
  let day_path = directory ^ "/selected-day-record.txt" in
  F.write_new day_path (Bakhlo_household.Daily_txt.text book);
  let day_parent =
    {
      drilled with
      session = F.load day_path;
      workspace = { drilled.workspace with focus_day = "2024-02-29" };
    }
  in
  let day_draft = prepare_record ~width_of day_parent in
  let day_rows = S.screen ~book ~dimensions:(72, 20) ~width_of (Option.get day_draft.record) in
  require
    (contains day_rows (entry 16).day)
    "selected-day-record-inherits-route-date-not-the-focus-day";
  let held = key ~width_of day_draft `Escape in
  require
    (same_workspace held day_parent
    && held.drill_parent = day_parent.drill_parent
    && F.read day_path = before
    && C.has_record_draft held)
    "selected-day-record-cancel-retains-draft-parent-and-bytes";
  List.iter
    (fun state ->
      List.iter
        (fun ((width, _) as dimensions) ->
          let rows = R.screen ~width_of dimensions state in
          let expected =
            (entry 16).day ^ if C.has_record_draft state then "   Draft retained" else ""
          in
          require
            (snd (List.nth rows 1) = Ui_render.clip_text ~width_of width expected)
            "selected-day-context-uses-route-date";
          require (F.read day_path = before) "selected-day-context-does-not-write")
        [ (32, 9); (48, 14); (80, 24); (120, 36) ])
    [ day_parent; held ];
  let resumed = key ~width_of held (`ASCII 'r') in
  require
    (S.screen ~book ~dimensions:(72, 20) ~width_of (Option.get resumed.record) = day_rows)
    "selected-day-record-resumes-same-date-and-input";
  let review = C.submit resumed in
  require (F.read day_path = before) "selected-day-record-preview-does-not-write";
  let saved = key ~width_of (key ~width_of review `End) `Enter in
  require
    ((not saved.record_visible) && (not saved.blocked)
    && saved.workspace.route = day_parent.workspace.route
    && actual_selected_id saved = actual_selected_id day_parent)
    "selected-day-record-publication-retains-parent-selection";
  let cold = F.load day_path in
  let added =
    List.filter
      (fun (e : B.entry) ->
        not (List.exists (fun (old : B.entry) -> old.id = e.id) (B.entries book)))
      (B.entries cold.book)
  in
  require
    (match added with
    | [ e ] ->
        e.day = (entry 16).day
        && e.memo = Some "English UI / 日本語のメモ"
        && List.map Daily_actions.quanta e.effects = [ Z.of_int (-37); Z.of_int 37 ]
    | _ -> false)
    "selected-day-record-cold-retains-route-date-and-exact-postings";
  let back = key ~width_of saved (`ASCII 'q') in
  require
    (back.workspace.route = W.Actual && actual_detail back
    && actual_selected_id back = Some "actual-16")
    "selected-day-record-publication-preserves-drill-back-to-actual";
  let returned = key ~width_of drilled (`ASCII 'q') in
  require (returned.workspace.route = W.Actual) "selected-day-q-returns-to-actual";
  require (actual_row returned = 1) "actual-return-preserves-selected-row";
  require
    (actual_detail returned && actual_scroll returned = actual_scroll at_details)
    "actual-return-restores-detail-focus-and-scroll";
  require
    (Selected_day.browser returned.screens.day = Selected_day.browser drilled.screens.day)
    "actual-return-does-not-overwrite-selected-day-browser";
  let corrected_book =
    get (B.put_entry book ~replace:true { (entry 16) with day = "2026-09-01" } ~plan:None)
  in
  let corrected = { drilled with session = load_synthetic_book corrected_book } in
  let returned_corrected = key ~width_of corrected `Escape in
  require
    (actual_selected_id returned_corrected = Some "actual-16"
    && actual_row returned_corrected = 17
    && actual_detail returned_corrected)
    "actual-return-after-date-correction-follows-id-not-row";
  let filtered =
    key ~width_of state (`ASCII '/') |> fun s ->
    text ~width_of s "日本語" |> fun s ->
    key ~width_of s `Enter |> fun s ->
    key ~width_of s (`ASCII 's') |> fun s ->
    key ~width_of s (`ASCII 'h') |> fun s ->
    key ~width_of s (`ASCII 'j') |> fun s ->
    key ~width_of s (`ASCII 'l') |> fun s ->
    key ~width_of s (`ASCII 'i') |> fun s -> key ~dimensions:(80, 24) ~width_of s `End
  in
  require (actual_scroll filtered > 0) "actual-return-fixture-has-scrolled-detail";
  let filtered_drill = key ~dimensions:(80, 24) ~width_of filtered `Enter in
  let filtered_return = key ~dimensions:(80, 24) ~width_of filtered_drill (`ASCII 'q') in
  require
    (filtered_return.screens.actual = filtered.screens.actual
    && actual_detail filtered_return
    && actual_scroll filtered_return = actual_scroll filtered)
    "actual-return-preserves-filter-order-locus-detail-and-scroll";
  let refreshed =
    C.finish_publication ~record_publication:false filtered
      (load_synthetic_book corrected_book)
      "Synthetic publication"
  in
  require
    (refreshed.screens.actual = filtered.screens.actual
    && actual_detail refreshed
    && actual_scroll refreshed = actual_scroll filtered)
    "actual-publication-preserves-filter-order-locus-detail-and-scroll";
  let unmatched_book =
    get
      (B.put_entry book ~replace:true
         { (entry 17) with memo = Some "No longer matches" }
         ~plan:None)
  in
  let unmatched =
    C.finish_publication ~record_publication:false filtered
      (load_synthetic_book unmatched_book)
      "Synthetic publication"
  in
  require
    (actual_selected unmatched = None
    && actual_detail unmatched
    && actual_scroll unmatched = 0
    && contains (R.screen ~width_of (80, 24) unmatched) "no longer matches")
    "actual-publication-filter-exit-is-explicit-and-does-not-retain-stale-detail";
  require (F.read path = before) "actual-browsing-and-draft-did-not-write";
  let correcting = key ~width_of at_details (`ASCII 'c') in
  require correcting.record_visible "actual-correction-opens-record";
  (* LOAM Correction keeps the date; date moves are [d]'s own check. *)
  let correcting = key ~width_of correcting (`ASCII '!') in
  let review = C.submit correcting in
  require (F.read path = before) "actual-correction-review-does-not-write";
  let published = key ~width_of (key ~width_of review `End) `Enter in
  require ((not published.record_visible) && not published.blocked) "actual-correction-published";
  require
    (published.workspace.route = W.Actual
    && actual_detail published
    && actual_selected_id published = Some "actual-16"
    && actual_row published = actual_row at_details
    &&
    match actual_selected published with
    | Some (Record_browser.Actual_entry e) -> e.id = "actual-16"
    | _ -> false)
    "actual-correction-return-follows-id-not-old-row";
  let cold = F.load path in
  let corrected = List.find (fun (e : B.entry) -> e.id = "actual-16") (B.entries cold.book) in
  require
    (corrected.day = (entry 16).day
    && corrected.memo = Some "Synthetic purchase 16!"
    && corrected.effects = (entry 16).effects)
    "actual-correction-cold-retains-id-date-description-and-postings";
  (* LOAM Correction may also change a posting's Locus under the same ID. *)
  let first_locus (e : B.entry) = Daily_draft.lstr (D.Effect.locus (List.hd e.effects)) in
  let target = if first_locus corrected = "bank" then "wallet" else "bank" in
  let relocating = key ~width_of published (`ASCII 'c') in
  let relocating = key ~width_of (key ~width_of relocating `Tab) `Tab in
  let relocating =
    List.fold_left (fun s _ -> key ~width_of s `Backspace) relocating (List.init 20 Fun.id)
  in
  let relocating = String.fold_left (fun s c -> key ~width_of s (`ASCII c)) relocating target in
  let relocated = key ~width_of (key ~width_of (C.submit relocating) `End) `Enter in
  let cold = List.find (fun (e : B.entry) -> e.id = "actual-16") (B.entries (F.load path).book) in
  require
    ((not relocated.record_visible) && (not relocated.blocked)
    && first_locus cold = target
    && List.length cold.effects = List.length corrected.effects
    && cold.day = corrected.day)
    "actual-correction-changes-locus-same-id-cold";
  print_endline
    "PASS: Actual exact aligned summaries, live search, clamped detail/list paging, tiny resize, \
     stable selection and retained Record drafts (synthetic)."

let reversal_checks ~width_of ~directory home =
  let directory = directory ^ "/reversal" in
  Unix.mkdir directory 0o700;
  let make_effect locus quantity =
    D.Effect.create
      ~key:(Some (get_id (D.Identifier.Effect_key.of_string ("reverse-" ^ locus))))
      ~locus:(get_id (D.Identifier.Locus.of_string locus))
      ~measure:(get_id (D.Identifier.Measure.of_string "jpy"))
      ~quantity:(D.Quantity.of_quanta (Z.of_int quantity))
  in
  let target : B.entry =
    {
      id = "reverse-target";
      day = "2026-10-10";
      memo = Some "Original / 日本語";
      effects = [ make_effect "wallet" (-37); make_effect "food" 37 ];
      reversal_of = None;
      exchange = None;
      original_amount = None;
      merchant = None;
    }
  in
  let book = get (B.put_entry home.C.session.book ~replace:false target ~plan:None) in
  let path = directory ^ "/book.txt" in
  F.write_new path (Bakhlo_household.Daily_txt.text book);
  F.write_new (directory ^ "/input.txt") (Bakhlo_household.Daily_txt.text book);
  let base = C.initial ~config_home:directory (F.load path) |> fun s -> C.open_route s W.Actual in
  let before = F.read path in
  let names () = Sys.readdir directory |> Array.to_list |> List.sort String.compare in
  let before_names = names () in
  let unchanged label = require (F.read path = before && names () = before_names) label in
  let editor state =
    match session_of state with
    | Some (E.Reversal editor) -> editor
    | _ -> raise (F.Refused "reversal-editor-lost")
  in
  let input state event =
    match H.handle ~width_of state event with
    | Some s -> s
    | None -> raise (F.Refused "reversal-exited-controller")
  in
  let date state value =
    let state =
      List.fold_left
        (fun s _ -> key ~width_of s `Backspace)
        state
        (List.init (String.length (Rev.day (editor state))) Fun.id)
    in
    text ~width_of state value
  in
  let opened = key ~width_of base (`ASCII 'x') in
  let entered = date opened "2026/10/09" in
  let invalid = key ~width_of (date opened "2026-02-30") `Enter in
  require
    ((not (Rev.is_preview (editor invalid))) && Rev.day (editor invalid) = "2026-02-30")
    "reversal-invalid-date-retained";
  let review = key ~width_of entered `Enter in
  require
    (Rev.is_preview (editor review) && Rev.day (editor review) = "2026-10-09")
    "reversal-date-enters-canonical-preview";
  let ctrl_review = input entered (`Key (`Enter, [ `Ctrl ])) in
  require (Rev.is_preview (editor ctrl_review)) "reversal-ctrl-enter-only-previews-date";
  let same_review state =
    Rev.is_preview (editor state)
    && Rev.day (editor state) = Rev.day (editor review)
    && Rev.base_revision (editor state) = Rev.base_revision (editor review)
    && R.overlay_screen ~dimensions:(80, 24) ~width_of state
       = R.overlay_screen ~dimensions:(80, 24) ~width_of review
  in
  require
    (same_review (input review (`Key (`Enter, [ `Ctrl ]))))
    "reversal-ctrl-enter-does-not-publish";
  let body = Option.get (R.overlay_screen ~dimensions:(80, 24) ~width_of review) in
  let contains needle =
    List.exists (fun (_, text) -> Base.String.is_substring text ~substring:needle) body
  in
  List.iter
    (fun s -> require (contains s) ("reversal-review-missing-" ^ s))
    [
      "reverse-target";
      "2026-10-10";
      "2026-10-09";
      "日本語";
      "Original postings";
      "Inverse postings";
      "wallet  -37 jpy";
      "wallet  +37 jpy";
      "food  +37 jpy";
      "food  -37 jpy";
    ];
  require
    (R.cursor_position ~width_of (80, 24) opened <> None
    && R.cursor_position ~width_of (80, 24) review = None)
    "reversal-date-caret-only";
  List.iter
    (fun dimensions ->
      let date_view = Option.get (R.overlay_screen ~dimensions ~width_of opened) in
      let preview = Option.get (R.overlay_screen ~dimensions ~width_of review) in
      List.iter
        (fun rows ->
          require
            (List.length rows <= snd dimensions
            && List.for_all (fun (_, s) -> width_of s <= fst dimensions) rows)
            "reversal-surface-cell-bounds")
        [ date_view; preview ])
    [ (80, 24); (120, 36); (48, 14); (32, 9) ];
  List.iter
    (fun dimensions ->
      let refused = key ~dimensions ~width_of review `Enter in
      require (Rev.is_preview (editor refused)) "reversal-tiny-publish-refused")
    [ (48, 14); (32, 9) ];
  let editing = key ~width_of review `Escape in
  require
    ((not (Rev.is_preview (editor editing))) && Rev.day (editor editing) = "2026-10-09")
    "reversal-preview-escape-retains-date";
  let edit_action = key ~width_of (key ~width_of review `Tab) `Enter in
  require (not (Rev.is_preview (editor edit_action))) "reversal-selected-edit";
  List.iter
    (fun cancelled ->
      require
        (no_modal cancelled && same_workspace cancelled opened
        && cancelled.screens.actual = opened.screens.actual)
        "reversal-cancel-retains-parent")
    [
      key ~width_of opened `Escape;
      key ~width_of review (`ASCII 'q');
      key ~width_of (key ~width_of (key ~width_of review `Tab) `Tab) `Enter;
    ];
  let day_view = C.open_route base (W.Selected_day target.day) in
  let day_cancel = key ~width_of (key ~width_of day_view (`ASCII 'x')) `Escape in
  require (same_workspace day_cancel day_view) "reversal-selected-day-parent-retained";
  let held = prepare_record ~width_of base |> fun s -> key ~width_of s `Escape in
  let guarded = key ~width_of held (`ASCII 'x') in
  require
    (no_modal guarded && guarded.record = held.record && C.has_record_draft guarded)
    "reversal-does-not-destroy-retained-record-draft";
  let paste = input review (`Paste `Start) in
  let paste = input paste (`Key (`Enter, [])) |> fun s -> input s (`Key (`ASCII 'q', [])) in
  let paste = input paste (`Paste `End) in
  require (same_review paste) "reversal-paste-cannot-confirm-or-cancel";
  unchanged "reversal-input-review-cancel-refusal-do-not-write-or-allocate-artifacts";
  let missing = { review with session = unavailable_session review.session } in
  let failed = key ~width_of missing `Enter in
  require
    (is_reversal failed
    && (not (Rev.is_preview (editor failed)))
    && Rev.day (editor failed) = "2026-10-09"
    && Rev.base_revision (editor failed) = F.revision_of_bytes before
    && failed.message <> "")
    "reversal-storage-refusal-keeps-date-target-and-base";
  unchanged "reversal-failed-storage-keeps-original";
  let large = Z.of_string (String.make 225 '9' ^ "03") in
  let eur_effect locus n =
    D.Effect.create ~key:None
      ~locus:(get_id (D.Identifier.Locus.of_string locus))
      ~measure:(get_id (D.Identifier.Measure.of_string "eur"))
      ~quantity:(D.Quantity.of_quanta n)
  in
  let long_target =
    {
      target with
      memo = Some (String.concat "" (List.init 100 (fun _ -> "長い日本語")));
      effects = [ eur_effect "wallet" (Z.neg large); eur_effect "food" large ];
    }
  in
  F.write_new (directory ^ "/large-input.txt")
    (Bakhlo_household.Daily_txt.text
       (get (B.put_entry home.session.book ~replace:false long_target ~plan:None)));
  let long =
    Rev.create ~book ~base_revision:(F.revision_of_bytes before) ~day:"2026-10-09" long_target
  in
  let long =
    match Rev.handle ~blocked:false ~dimensions:(80, 24) ~width_of long (`Key (`Enter, [])) with
    | Rev.Updated t -> t
    | _ -> raise (F.Refused "reversal-long-date-preview")
  in
  let rows = Rev.screen ~dimensions:(160, 100) ~width_of long in
  List.iter
    (fun (locus, n) ->
      let s = locus ^ "  " ^ (if Z.sign n > 0 then "+" else "") ^ B.format book "eur" n ^ " eur" in
      List.iter
        (fun piece ->
          require
            (List.exists (fun (_, s) -> Base.String.is_substring s ~substring:piece) rows)
            "reversal-huge-exact-decimal-is-wrapped-not-clipped")
        (Ui_render.wrap_text ~width_of 154 s))
    [ ("wallet", Z.neg large); ("food", large); ("wallet", large); ("food", Z.neg large) ];
  (match Rev.handle ~blocked:false ~dimensions:(80, 24) ~width_of long (`Key (`Enter, [])) with
  | Rev.Updated _ -> ()
  | _ -> raise (F.Refused "reversal-unreviewed-end-published"));
  let ended =
    match Rev.handle ~blocked:false ~dimensions:(80, 24) ~width_of long (`Key (`End, [])) with
    | Rev.Updated t -> t
    | _ -> raise (F.Refused "reversal-end")
  in
  (match Rev.handle ~blocked:false ~dimensions:(80, 24) ~width_of ended (`Key (`Enter, [])) with
  | Rev.Publish (id, day, bytes) ->
      require
        (id = target.id && day = "2026-10-09" && bytes = F.revision_of_bytes before)
        "reversal-fixed-intent"
  | _ -> raise (F.Refused "reversal-reviewed-end-not-publishable"));
  let compact =
    match Rev.handle ~blocked:false ~dimensions:(48, 14) ~width_of ended (`Key (`End, [])) with
    | Rev.Updated t -> t
    | _ -> raise (F.Refused "reversal-compact-end")
  in
  (match Rev.handle ~blocked:false ~dimensions:(48, 14) ~width_of compact (`Key (`Enter, [])) with
  | Rev.Updated _ -> ()
  | _ -> raise (F.Refused "reversal-compact-end-bypassed-gate"));
  let changed_target = { target with memo = Some "Concurrent correction" } in
  (match
     F.publish base.session [ B.Put_entry { replace = true; entry = changed_target; plan = None } ]
   with
  | F.Written _ -> ()
  | _ -> raise (F.Refused "reversal-conflict-setup"));
  let changed_bytes = F.read path in
  let conflict = key ~width_of review `Enter in
  require
    (conflict.blocked && Rev.day (editor conflict) = "2026-10-09" && F.read path = changed_bytes)
    "reversal-disk-conflict-retains-draft";
  let reloaded = input review (`Key (`ASCII 'r', [ `Ctrl ])) in
  require
    (reloaded.blocked
    && Rev.base_revision (editor reloaded) = F.revision_of_bytes before
    && reloaded.session.revision = F.revision_of_bytes changed_bytes)
    "reversal-reload-cannot-bless-stale-preview";
  let stopped = key ~width_of reloaded `Enter in
  require (stopped.blocked && F.read path = changed_bytes) "reversal-stale-preview-cannot-publish";
  require
    (List.exists
       (fun (_, line) -> Base.String.is_substring line ~substring:"Writes stopped")
       (R.screen ~width_of (80, 24) stopped))
    "reversal-blocked-screen-does-not-offer-confirmation";
  let reset = input (key ~width_of reloaded (`ASCII 'q')) (`Key (`ASCII 'r', [ `Ctrl ])) in
  require (not reset.blocked) "reversal-explicit-cancel-reload-unblocks";
  let fresh = key ~width_of (key ~width_of (key ~width_of reset (`ASCII 'x')) `Enter) `Enter in
  let cold = F.load path in
  let reversal =
    List.find (fun (e : B.entry) -> e.reversal_of = Some target.id) (B.entries cold.book)
  in
  require
    (no_modal fresh
    && B.find_entry cold.book target.id = Some changed_target
    && reversal.day = Clock.today ()
    && List.length reversal.effects = List.length target.effects)
    "reversal-cold-readback-original-and-relation";
  List.iter2
    (fun original inverse ->
      require
        (D.Effect.locus original = D.Effect.locus inverse
        && D.Effect.measure original = D.Effect.measure inverse
        && D.Effect.key original = D.Effect.key inverse
        && Z.equal (Daily_actions.quanta inverse) (Z.neg (Daily_actions.quanta original)))
        "reversal-cold-exact-inverse-keys-coordinates")
    target.effects reversal.effects;
  let unknown_path = directory ^ "/unknown.txt" in
  F.write_new unknown_path before;
  let unknown_base =
    C.initial ~config_home:directory (F.load unknown_path) |> fun s -> C.open_route s W.Actual
  in
  let unknown_review = key ~width_of (key ~width_of unknown_base (`ASCII 'x')) `Enter in
  let unknown_op =
    [
      B.Put_entry
        { replace = false; entry = { reversal with id = "unknown-reversal" }; plan = None };
    ]
  in
  let draft =
    with_session unknown_review (E.Reversal (Rev.with_publish_error (editor unknown_review)))
  in
  let unknown () =
    C.apply_commit_result ~record_publication:false unknown_review ~draft
      (Daily_actions.Uncertain
         {
           message = "synthetic lost acknowledgement";
           evidence =
             Daily_actions.Expected_revision (expected_after unknown_base.session unknown_op);
         })
  in
  let unconfirmed = input (unknown ()) (`Key (`ASCII 'r', [ `Ctrl ])) in
  require
    (unconfirmed.blocked && unconfirmed.pending <> None && is_reversal unconfirmed
    && F.read unknown_path = before)
    "reversal-unknown-reload-does-not-retry";
  let attempted = key ~width_of unconfirmed `Enter in
  require
    ((not (Rev.is_preview (editor attempted))) && attempted.pending = unconfirmed.pending)
    "reversal-unknown-stays-stopped-with-date";
  (match F.publish unknown_base.session unknown_op with
  | F.Written _ -> ()
  | _ -> raise (F.Refused "reversal-ack-setup"));
  let present_bytes = F.read unknown_path in
  let confirmed = input (unknown ()) (`Key (`ASCII 'r', [ `Ctrl ])) in
  require
    ((not confirmed.blocked) && confirmed.pending = None && no_modal confirmed
    && F.read unknown_path = present_bytes
    && List.length (B.entries confirmed.session.book) = 2)
    "reversal-confirmed-reload-closes-draft-without-duplicate";
  print_endline
    "PASS: reversal date/Preview, exact signed quantities, tiny/end gates, cancel/draft retention, \
     stale base, storage refusal, unknown/reload and cold inverse (synthetic)."

let date_correction_checks ~width_of ~directory home =
  let make_effect key locus n =
    D.Effect.create
      ~key:(Some (get_id (D.Identifier.Effect_key.of_string key)))
      ~locus:(get_id (D.Identifier.Locus.of_string locus))
      ~measure:(get_id (D.Identifier.Measure.of_string "jpy"))
      ~quantity:(D.Quantity.of_quanta (Z.of_int n))
  in
  let target : B.entry =
    {
      id = "date-target";
      day = "2026-10-15";
      memo = Some "Date / 日本語";
      effects = [ make_effect "out" "wallet" (-123); make_effect "in" "food" 123 ];
      reversal_of = None;
      exchange = None;
      original_amount = None;
      merchant = None;
    }
  in
  let plan : B.plan =
    {
      id = "date-paid-plan";
      day = "2026-10-01";
      measure = "jpy";
      changes = [ ("wallet", Z.of_int (-123)); ("food", Z.of_int 123) ];
      paid_by = None;
      cancelled_on = None;
    }
  in
  let book = get (B.put_plan home.C.session.book ~replace:false plan) in
  let book = get (B.put_entry book ~replace:false target ~plan:(Some plan.id)) in
  let book =
    get
      (B.put_entry book ~replace:false { target with id = "other"; day = "2026-10-14" } ~plan:None)
  in
  let path = directory ^ "/date-correction.txt" in
  F.write_new path (Bakhlo_household.Daily_txt.text book);
  let before = F.read path in
  let base =
    C.open_route (C.initial ~config_home:directory (F.load path)) (W.Selected_day target.day)
  in
  let editor state =
    match session_of state with
    | Some (E.Date_correction e) -> e
    | _ -> raise (F.Refused "date-editor-lost")
  in
  let input state event =
    match H.handle ~width_of state event with
    | Some s -> s
    | None -> raise (F.Refused "date-controller-exited")
  in
  let date state value =
    let state =
      List.fold_left
        (fun s _ -> key ~width_of s `Backspace)
        state
        (List.init (String.length (Date.day (editor state))) Fun.id)
    in
    text ~width_of state value
  in
  let editing = key ~width_of base (`ASCII 'd') in
  require (Date.day (editor editing) = target.day) "date-prefills-current-date";
  let invalid = date editing "2026-02-29" |> fun s -> key ~width_of s `Enter in
  require
    ((not (Date.is_preview (editor invalid))) && F.read path = before)
    "date-invalid-calendar-does-not-preview-or-write";
  let review = date invalid "2026/10/12" |> fun s -> key ~width_of s `Enter in
  require
    (Date.is_preview (editor review) && Date.day (editor review) = "2026-10-12")
    "date-normalized-preview";
  let back = key ~width_of review `Escape in
  require
    ((not (Date.is_preview (editor back))) && Date.day (editor back) = "2026-10-12")
    "date-preview-escape-keeps-input";
  let cancelled = key ~width_of review (`ASCII 'q') in
  require
    (no_modal cancelled && same_workspace cancelled base && F.read path = before)
    "date-cancel-retains-parent-and-bytes";
  List.iter
    (fun dimensions ->
      let small = key ~dimensions ~width_of review `Enter in
      require
        (Date.is_preview (editor small) && F.read path = before)
        "date-tiny-preview-cannot-publish")
    [ (32, 9); (48, 14); (80, 14) ];
  let held = prepare_record ~width_of base |> fun s -> key ~width_of s `Escape in
  let refused = key ~width_of held (`ASCII 'd') in
  require (no_modal refused && refused.record = held.record) "date-does-not-discard-record-draft";
  let pasted =
    input review (`Paste `Start) |> fun s ->
    input s (`Key (`Enter, [])) |> fun s -> input s (`Paste `End)
  in
  require (pasted.overlay = review.overlay && F.read path = before) "date-paste-cannot-confirm";
  let missing = { review with session = unavailable_session review.session } in
  let failed = key ~width_of missing `Enter in
  require
    (Date.day (editor failed) = "2026-10-12"
    && Date.base_revision (editor failed) = F.revision_of_bytes before
    && F.read path = before)
    "date-storage-failure-retains-input-and-base";
  let actual = C.open_route (C.initial ~config_home:directory (F.load path)) W.Actual in
  let actual_review =
    key ~width_of actual (`ASCII 'd') |> fun s ->
    date s "2026-10-12" |> fun s -> key ~width_of s `Enter
  in
  let saved = key ~width_of actual_review `Enter in
  let cold = F.load path in
  require
    (no_modal saved
    && B.find_entry cold.book target.id = Some { target with day = "2026-10-12" }
    && B.plans cold.book = B.plans book
    && List.length (B.entries cold.book) = List.length (B.entries book))
    "date-cold-save-changes-only-date-preserves-keys-and-plan-link";
  require
    (actual_selected_id saved = Some target.id && actual_row saved = 1)
    "date-actual-save-follows-moved-id";
  let day_path = directory ^ "/date-selected-day.txt" in
  F.write_new day_path before;
  let drilled =
    C.open_route (C.initial ~config_home:directory (F.load day_path)) W.Actual |> fun s ->
    key ~width_of s (`ASCII 'i') |> fun s -> key ~width_of s `Enter
  in
  let moved =
    key ~width_of drilled (`ASCII 'd') |> fun s ->
    date s "2026-10-12" |> fun s ->
    key ~width_of s `Enter |> fun s -> key ~width_of s `Enter
  in
  require
    (moved.workspace.route = W.Selected_day target.day && day_rows moved = [])
    "date-moved-entry-leaves-old-selected-day";
  let parent = key ~width_of moved (`ASCII 'q') in
  require
    (parent.workspace.route = W.Actual && actual_detail parent
    && actual_selected_id parent = Some target.id
    && actual_row parent = 1
    && B.find_entry (F.load day_path).book target.id = Some { target with day = "2026-10-12" })
    "date-selected-day-save-cold-load-and-drill-back-follow-id";
  let stale = key ~width_of review `Enter in
  require (stale.blocked && Date.day (editor stale) = "2026-10-12") "date-stale-preview-stops";
  let reloaded = input review (`Key (`ASCII 'r', [ `Ctrl ])) in
  let stopped = key ~width_of reloaded `Enter in
  require
    (reloaded.blocked && stopped.blocked
    && Date.base_revision (editor stopped) = F.revision_of_bytes before
    && F.read_revision path = cold.revision)
    "date-reload-cannot-bless-stale-target";
  let long =
    Date.create ~base_revision:(F.revision_of_bytes before)
      { target with id = String.make 1200 'x' }
  in
  let update t key =
    match Date.handle ~blocked:false ~dimensions:(72, 16) ~width_of t (`Key (key, [])) with
    | Date.Updated t -> t
    | _ -> raise (F.Refused "date-long-target-not-reviewable")
  in
  let long = update long `Enter in
  let long = update long `Enter in
  let ended = update long `End in
  (match Date.handle ~blocked:false ~dimensions:(72, 16) ~width_of ended (`Key (`Enter, [])) with
  | Date.Publish (tx, _) -> require (tx.entry.id = String.make 1200 'x') "date-full-target-reviewed"
  | _ -> raise (F.Refused "date-reviewed-target-not-publishable"));
  let unsafe =
    Date.create ~base_revision:(F.revision_of_bytes before)
      { target with id = "target\027[31m\nnext" }
  in
  List.iter
    (fun editor ->
      require
        (List.for_all
           (fun (_, line) -> not (String.contains line '\027' || String.contains line '\n'))
           (Date.screen ~dimensions:(72, 16) ~width_of editor))
        "date-target-cannot-inject-terminal-controls")
    [ unsafe; update unsafe `Enter ];

  (* A retained Actual may refer to a Locus that is no longer admitted for new
     publication. Date and Merchant are independent metadata mutations; ordinary
     correction and reversal remain new Movement publications and stay refused. *)
  let retained_plan : B.plan =
    {
      id = "retained-locus-plan";
      day = "2026-10-11";
      measure = "jpy";
      changes = [ ("wallet", Z.of_int (-456)); ("food", Z.of_int 456) ];
      paid_by = None;
      cancelled_on = None;
    }
  in
  let retained_target : B.entry =
    {
      id = "retained-locus-target";
      day = "2026-10-11";
      memo = Some "Historical Locus";
      effects = [ make_effect "retained-out" "wallet" (-456); make_effect "retained-in" "food" 456 ];
      reversal_of = None;
      exchange = None;
      original_amount = Some ("eur", Z.of_int 789);
      merchant = None;
    }
  in
  let retained_admitted = get (B.put_plan home.C.session.book ~replace:false retained_plan) in
  let retained_admitted =
    get (B.put_entry retained_admitted ~replace:false retained_target ~plan:(Some retained_plan.id))
  in
  let admitted_bytes = Bakhlo_household.Daily_txt.text retained_admitted in
  (* food stays in the book but is no longer offered for new entries. *)
  let retained_bytes =
    String.split_on_char '\n' admitted_bytes
    |> List.map (fun line ->
        if String.starts_with ~prefix:"LOCUS\tfood\t" line then line ^ "\tHIDDEN" else line)
    |> String.concat "\n"
  in
  require (retained_bytes <> admitted_bytes) "retained-locus-policy-fixture-changed";
  let retained_book = Bakhlo_household.Daily_txt.book retained_bytes in
  let retained_bytes = Bakhlo_household.Daily_txt.text retained_book in
  require
    (B.approved_loci retained_book = Some [ "wallet"; "bank" ]
    && B.find_entry retained_book retained_target.id = Some retained_target)
    "retained-locus-fixture-loads-with-stable-entry";
  let retained_path = directory ^ "/retained-locus-mutations.txt" in
  F.write_new retained_path retained_bytes;
  let retained_initial () =
    C.open_route (C.initial ~config_home:directory (F.load retained_path)) W.Actual
  in
  let original_bytes = F.read retained_path in

  let correction = key ~width_of (retained_initial ()) (`ASCII 'c') in
  require correction.record_visible "retained-locus-correction-opens";
  let correction_refused = C.submit correction in
  let correction_rows =
    S.screen ~book:correction_refused.session.book ~dimensions:(72, 20) ~width_of
      (Option.get correction_refused.record)
  in
  require
    (correction_refused.record_visible
    && F.read retained_path = original_bytes
    && List.exists
         (fun (_, line) -> Base.String.is_substring line ~substring:"A Locus is not admitted")
         correction_rows)
    "retained-locus-ordinary-correction-remains-refused";

  let reversing = key ~width_of (retained_initial ()) (`ASCII 'x') in
  let reversal_review = key ~width_of reversing `Enter in
  let reversal_refused = key ~width_of reversal_review `Enter in
  require
    (is_reversal reversal_refused
    && F.read retained_path = original_bytes
    && Base.String.is_substring reversal_refused.message ~substring:"locus-unapproved")
    "retained-locus-reversal-remains-refused";

  let dating = key ~width_of (retained_initial ()) (`ASCII 'd') in
  let date_review = date dating "2026-10-09" |> fun s -> key ~width_of s `Enter in
  let date_saved = key ~width_of date_review `Enter in
  require (no_modal date_saved) "retained-locus-date-publication-closes-editor";
  require
    (Base.String.is_substring (F.read retained_path)
       ~substring:("TX\t" ^ retained_target.id ^ "\t2026-10-09"))
    "retained-locus-date-saves-the-new-date";
  let dated_session = F.load retained_path in
  let dated_target = Option.get (B.find_entry dated_session.book retained_target.id) in
  require
    (dated_target = { retained_target with day = "2026-10-09" }
    && B.plans dated_session.book = B.plans retained_book
    && List.map (fun (e : B.entry) -> e.id) (B.entries dated_session.book)
       = List.map (fun (e : B.entry) -> e.id) (B.entries retained_book))
    "retained-locus-date-cold-preserves-identity-effects-link-original-amount";

  let merchant_state = C.open_route (C.initial ~config_home:directory dated_session) W.Actual in
  let merchant_edit =
    key ~width_of merchant_state (`ASCII 'm') |> fun s -> text ~width_of s "historical-shop"
  in
  let merchant_review = key ~width_of merchant_edit `Enter in
  let merchant_saved = key ~width_of merchant_review `Enter in
  let party = get_id (D.Identifier.External_party.of_string "historical-shop") in
  let merchant_cold = F.load retained_path in
  let merchant_target = Option.get (B.find_entry merchant_cold.book retained_target.id) in
  require
    (no_modal merchant_saved
    && merchant_target
       = { retained_target with day = "2026-10-09"; merchant = Some (B.Merchant party) }
    && B.plans merchant_cold.book = B.plans retained_book
    && B.approved_loci merchant_cold.book = Some [ "wallet"; "bank" ])
    "retained-locus-merchant-cold-preserves-identity-effects-link-original-amount";
  print_endline
    "PASS: date-only correction validates dates, reviews target, refuses tiny/stale, preserves \
     drafts, keys and completed plans; retained unapproved-Locus Actuals allow dedicated \
     date/Merchant metadata while correction/reversal remain refused."

let original_amount_integration_checks ~width_of ~directory () =
  let dir = directory ^ "/original-amount-integration" in
  let contains rows needle =
    List.exists (fun (_, line) -> Base.String.is_substring line ~substring:needle) rows
  in
  let rec_screen s =
    S.screen ~book:s.C.session.book ~dimensions:(80, 24) ~width_of (Option.get s.C.record)
  in
  Unix.mkdir dir 0o700;
  let path = dir ^ "/book.txt" in
  let fixture =
    "BOOK\t1\n\
     MEASURE\tjpy\t0\n\
     MEASURE\tusd\t2\n\
     LOCUS\twallet\t財布\tCash\n\
     LOCUS\tfood\t食費\tFood\n\
     ZERO-ORIGIN\tfood\tjpy\n\
     ANCHOR\t-\n\
     ASSERT\twallet\tjpy\t10000\n\
     ENDANCHOR\n\
     END\n"
  in
  F.write_new path fixture;
  let initial_state = C.initial ~config_home:dir (F.load path) in
  let initial_bytes = F.read path in

  (* 1. 通常 (normal / happy path): Record with OriginalAmount -> Preview -> Publish -> Cold reload -> Detail check *)
  let actual_view = C.open_route initial_state W.Actual in
  let recording = H.handle ~width_of actual_view (`Key (`ASCII 'n', [])) in
  let rec_state =
    match recording with Some s -> s | None -> raise (F.Refused "orig-open-record")
  in
  let rec_state =
    key ~width_of rec_state `Tab
    (* quick capture -> full form *)
  in
  let open_orig = H.handle ~width_of rec_state (`Key (`ASCII 'o', [ `Ctrl ])) in
  let orig_ed =
    match open_orig with Some s -> s | None -> raise (F.Refused "orig-open-orig-editor")
  in
  (* Test 1a: Unregistered measure refusal *)
  let unreg_m =
    List.fold_left
      (fun s c -> Option.get (H.handle ~width_of s (`Key (`ASCII c, []))))
      orig_ed [ 'g'; 'b'; 'p' ]
  in
  let unreg_refused = Option.get (H.handle ~width_of unreg_m (`Key (`Enter, []))) in
  require
    (contains (rec_screen unreg_refused) "Measure 'gbp' scale is not configured in this book.")
    "orig-integration-unregistered-measure-refused";
  let clean_ed =
    List.fold_left
      (fun s _ -> Option.get (H.handle ~width_of s (`Key (`Backspace, []))))
      unreg_refused (List.init 3 Fun.id)
  in

  (* Test 1b: Registered scale 0 (JPY) allows integer, rejects decimals *)
  let jpy_m =
    List.fold_left
      (fun s c -> Option.get (H.handle ~width_of s (`Key (`ASCII c, []))))
      clean_ed [ 'j'; 'p'; 'y' ]
  in
  let jpy_amt_focus = Option.get (H.handle ~width_of jpy_m (`Key (`Enter, []))) in
  let jpy_decimal =
    List.fold_left
      (fun s c -> Option.get (H.handle ~width_of s (`Key (`ASCII c, []))))
      jpy_amt_focus [ '5'; '0'; '.'; '5' ]
  in
  let jpy_dec_refused = Option.get (H.handle ~width_of jpy_decimal (`Key (`Enter, []))) in
  require
    (contains (rec_screen jpy_dec_refused)
       "Enter a positive original amount with at most 0 decimal places.")
    "orig-integration-scale-0-decimal-refused";
  let jpy_clean =
    List.fold_left
      (fun s _ -> Option.get (H.handle ~width_of s (`Key (`Backspace, []))))
      jpy_dec_refused (List.init 4 Fun.id)
  in
  let jpy_valid_amt =
    List.fold_left
      (fun s c -> Option.get (H.handle ~width_of s (`Key (`ASCII c, []))))
      jpy_clean [ '5'; '0'; '0'; '0' ]
  in
  let jpy_attached = Option.get (H.handle ~width_of jpy_valid_amt (`Key (`Enter, []))) in
  require
    (contains (rec_screen jpy_attached) "Original amount: 5000 jpy")
    "orig-integration-scale-0-attached";
  (* Clear via Ctrl-O -> Ctrl-D *)
  let open_to_clear = Option.get (H.handle ~width_of jpy_attached (`Key (`ASCII 'o', [ `Ctrl ]))) in
  let cleared_state =
    Option.get (H.handle ~width_of open_to_clear (`Key (`ASCII 'd', [ `Ctrl ])))
  in
  require (contains (rec_screen cleared_state) "Original amount: (none)") "orig-integration-cleared";

  (* Test 1c: Registered scale 2 (USD): enter "usd" and "30.00" *)
  let reopen_ed = Option.get (H.handle ~width_of cleared_state (`Key (`ASCII 'o', [ `Ctrl ]))) in
  let with_m =
    List.fold_left
      (fun s c -> Option.get (H.handle ~width_of s (`Key (`ASCII c, []))))
      reopen_ed [ 'u'; 's'; 'd' ]
  in
  let to_amount = Option.get (H.handle ~width_of with_m (`Key (`Enter, []))) in
  let with_amt =
    List.fold_left
      (fun s c -> Option.get (H.handle ~width_of s (`Key (`ASCII c, []))))
      to_amount [ '3'; '0'; '.'; '0'; '0' ]
  in
  let attached = Option.get (H.handle ~width_of with_amt (`Key (`Enter, []))) in
  require
    (contains (rec_screen attached) "Original amount: 30.00 usd")
    "orig-attached-screen-summary";

  let filled =
    List.fold_left
      (fun s _ -> Option.get (H.handle ~width_of s (`Key (`Tab, []))))
      attached (List.init 2 Fun.id)
  in
  let filled = Option.get (H.handle ~width_of filled (`Key (`Enter, []))) in
  let filled =
    List.fold_left
      (fun s c -> Option.get (H.handle ~width_of s (`Key (`ASCII c, []))))
      filled [ '-'; '4'; '5'; '0'; '0' ]
  in
  let filled = Option.get (H.handle ~width_of filled (`Key (`Tab, []))) in
  let filled = Option.get (H.handle ~width_of filled (`Key (`Enter, []))) in
  let filled =
    List.fold_left
      (fun s c -> Option.get (H.handle ~width_of s (`Key (`ASCII c, []))))
      filled [ '+'; '4'; '5'; '0'; '0' ]
  in

  let preview = Option.get (H.handle ~width_of filled (`Key (`Enter, []))) in
  let preview_screen = rec_screen preview in
  require (contains preview_screen "Record / Preview") "orig-preview-opened";
  require
    (contains preview_screen "Original amount: 30.00 usd")
    "orig-preview-shows-original-amount";

  (* 2. 取消 (cancellation): Cancel in Preview leaves disk file unchanged *)
  let cancel_preview =
    Option.get
      (H.handle ~width_of
         (Option.get (H.handle ~width_of preview (`Key (`Tab, []))))
         (`Key (`Enter, [])))
  in
  require
    (cancel_preview.record_visible && F.read path = initial_bytes)
    "orig-cancel-preview-leaves-disk-unchanged";
  let cancel_record = Option.get (H.handle ~width_of cancel_preview (`Key (`Escape, []))) in
  require
    ((not cancel_record.record_visible) && F.read path = initial_bytes)
    "orig-cancel-record-leaves-disk-unchanged";

  let re_resumed = Option.get (H.handle ~width_of cancel_record (`Key (`ASCII 'n', []))) in
  (* re-open retained draft *)
  let re_preview = Option.get (H.handle ~width_of re_resumed (`Key (`ASCII 's', [ `Ctrl ]))) in
  (* open preview *)
  let re_preview_end = Option.get (H.handle ~width_of re_preview (`Key (`End, []))) in
  let published = Option.get (H.handle ~width_of re_preview_end (`Key (`Enter, []))) in
  (* confirm publish *)
  require (not published.record_visible) "orig-published-closes-record";
  let published_bytes = F.read path in
  require (published_bytes <> initial_bytes) "orig-published-mutated-disk";

  let cold_session = F.load path in
  let entries = B.entries cold_session.book in
  require (List.length entries = 1) "orig-cold-one-entry";
  let saved_entry = List.hd entries in
  require
    (saved_entry.original_amount = Some ("usd", Z.of_int 3000))
    "orig-cold-entry-has-original-amount";
  let cold_state = C.initial ~config_home:dir cold_session in
  let actual_detail = C.open_route cold_state W.Actual in
  let actual_detail = Option.get (H.handle ~width_of actual_detail (`Key (`ASCII 'i', []))) in
  let actual_detail_end = Option.get (H.handle ~width_of actual_detail (`Key (`End, []))) in
  require
    (contains (R.screen ~width_of (80, 24) actual_detail_end) "Original amount: 30.00 usd")
    "orig-actual-detail-shows-amount";

  (* 3. 保存失敗 (save failure): Filesystem read-only error preserves draft and file *)
  let new_rec = H.handle ~width_of cold_state (`Key (`ASCII 'n', [])) |> Option.get in
  let new_rec = H.handle ~width_of new_rec (`Key (`ASCII 'o', [ `Ctrl ])) |> Option.get in
  let new_rec =
    List.fold_left
      (fun s c -> Option.get (H.handle ~width_of s (`Key (`ASCII c, []))))
      new_rec [ 'u'; 's'; 'd' ]
  in
  let new_rec = Option.get (H.handle ~width_of new_rec (`Key (`Enter, []))) in
  let new_rec =
    List.fold_left
      (fun s c -> Option.get (H.handle ~width_of s (`Key (`ASCII c, []))))
      new_rec [ '1'; '0'; '.'; '0'; '0' ]
  in
  let new_rec = Option.get (H.handle ~width_of new_rec (`Key (`Enter, []))) in
  let new_rec =
    List.fold_left
      (fun s _ -> Option.get (H.handle ~width_of s (`Key (`Tab, []))))
      new_rec (List.init 2 Fun.id)
  in
  let new_rec = Option.get (H.handle ~width_of new_rec (`Key (`Enter, []))) in
  let new_rec =
    List.fold_left
      (fun s c -> Option.get (H.handle ~width_of s (`Key (`ASCII c, []))))
      new_rec [ '-'; '1'; '5'; '0'; '0' ]
  in
  let new_rec = Option.get (H.handle ~width_of new_rec (`Key (`Tab, []))) in
  let new_rec = Option.get (H.handle ~width_of new_rec (`Key (`Enter, []))) in
  let new_rec =
    List.fold_left
      (fun s c -> Option.get (H.handle ~width_of s (`Key (`ASCII c, []))))
      new_rec [ '+'; '1'; '5'; '0'; '0' ]
  in
  let fail_preview = Option.get (H.handle ~width_of new_rec (`Key (`ASCII 's', [ `Ctrl ]))) in
  let fail_preview = Option.get (H.handle ~width_of fail_preview (`Key (`End, []))) in
  let fail_state = { fail_preview with session = unavailable_session fail_preview.session } in
  let fail_attempt = H.handle ~width_of fail_state (`Key (`Enter, [])) |> Option.get in
  require
    (fail_attempt.record_visible && F.read path = published_bytes)
    "orig-save-failure-preserves-draft-and-disk";

  (* 4. Stale (stale detection): Concurrent disk modification stops publication and preserves draft *)
  let stale_preview = fail_preview in
  let dummy_entry : B.entry =
    {
      id = "dummy_tx";
      day = "2026-10-04";
      memo = None;
      effects =
        [
          D.Effect.create
            ~locus:(get_id (D.Identifier.Locus.of_string "wallet"))
            ~measure:(get_id (D.Identifier.Measure.of_string "jpy"))
            ~quantity:(D.Quantity.of_quanta (Z.of_int (-100)))
            ~key:None;
          D.Effect.create
            ~locus:(get_id (D.Identifier.Locus.of_string "food"))
            ~measure:(get_id (D.Identifier.Measure.of_string "jpy"))
            ~quantity:(D.Quantity.of_quanta (Z.of_int 100))
            ~key:None;
        ];
      reversal_of = None;
      exchange = None;
      original_amount = None;
      merchant = None;
    }
  in
  let updated_book = get (B.put_entry (F.load path).book ~replace:false dummy_entry ~plan:None) in
  let oc = open_out_bin path in
  output_string oc (Bakhlo_household.Daily_txt.text updated_book);
  close_out oc;
  let changed_disk_bytes = F.read path in
  let stale_pub = Option.get (H.handle ~width_of stale_preview (`Key (`Enter, []))) in
  require
    (stale_pub.blocked && stale_pub.record_visible && F.read path = changed_disk_bytes)
    "orig-stale-stops-publication-and-preserves-disk";

  (* 5. 結果不明 (unknown result): Uncertain commit preserves draft and file *)
  let uncertain_attempt =
    C.apply_commit_result ~record_publication:true stale_preview ~draft:stale_preview
      (Daily_actions.Uncertain
         {
           message = "synthetic lost acknowledgement";
           evidence = Daily_actions.Expected_revision (F.revision_of_bytes changed_disk_bytes);
         })
  in
  require
    (uncertain_attempt.blocked && uncertain_attempt.record_visible
    && F.read path = changed_disk_bytes)
    "orig-uncertain-preserves-draft-and-disk";

  print_endline
    "PASS: OriginalAmount normal Record/Preview/Detail, cancel, save failure, stale state and \
     unknown result."

let event_merchant_integration_checks ~width_of ~directory () =
  let dir = directory ^ "/event-merchant-integration" in
  let contains rows needle =
    List.exists (fun (_, line) -> Base.String.is_substring line ~substring:needle) rows
  in
  Unix.mkdir dir 0o700;
  let path = dir ^ "/book.txt" in
  let fixture =
    "BOOK\t1\n\
     MEASURE\tjpy\t0\n\
     MEASURE\tusd\t2\n\
     LOCUS\twallet\t財布\tCash\n\
     LOCUS\tfood\t食費\tFood\n\
     TX\te1\t2026-10-10\tDESC\tSanwa shopping\n\
     EFFECT\twallet\tjpy\t-3000\n\
     EFFECT\tfood\tjpy\t3000\n\
     ENDTX\n\
     ZERO-ORIGIN\tfood\tjpy\n\
     ANCHOR\t-\n\
     ASSERT\twallet\tjpy\t10000\n\
     ENDANCHOR\n\
     END\n"
  in
  F.write_new path fixture;
  let initial_state = C.initial ~config_home:dir (F.load path) in
  let initial_bytes = F.read path in

  (* 1. Actual workspace: search typing non-collision *)
  let actual_view = C.open_route initial_state W.Actual in
  let search_started = Option.get (H.handle ~width_of actual_view (`Key (`ASCII '/', []))) in
  require
    (Act.search_editing (Actual_screen.workspace search_started.screens.actual))
    "merch-search-editing-active";
  let search_typed_m = Option.get (H.handle ~width_of search_started (`Key (`ASCII 'm', []))) in
  require
    (Act.search_editing (Actual_screen.workspace search_typed_m.screens.actual)
    && Act.search_query (Actual_screen.workspace search_typed_m.screens.actual) = "m")
    "merch-typing-m-in-search-updates-query";
  require (no_modal search_typed_m) "merch-search-does-not-open-editor";
  let search_cleared = Option.get (H.handle ~width_of search_typed_m (`Key (`Escape, []))) in
  require
    (not (Act.search_editing (Actual_screen.workspace search_cleared.screens.actual)))
    "merch-search-cleared";

  (* 2. Open Event Merchant editor on unclassified Actual 'e1' *)
  let merch_opened = Option.get (H.handle ~width_of search_cleared (`Key (`ASCII 'm', []))) in
  let editor =
    match session_of merch_opened with
    | Some (E.Event_merchant ed) -> ed
    | _ -> failwith "merch-editor-not-opened"
  in
  require
    (Merchant.choice editor = Merchant.Merchant && Merchant.party_input editor = "")
    "merch-editor-starts-unresolved";
  let screen_editing = Option.get (R.overlay_screen ~dimensions:(80, 24) ~width_of merch_opened) in
  require
    (contains screen_editing "Event Merchant / Edit"
    && contains screen_editing "Target: e1"
    && contains screen_editing "Description: Sanwa shopping"
    && contains screen_editing "Disposition: Merchant")
    "merch-editing-screen-labels";

  (* Empty party ID refusal on Enter *)
  let empty_enter = Option.get (H.handle ~width_of merch_opened (`Key (`Enter, []))) in
  let empty_ed =
    match session_of empty_enter with
    | Some (E.Event_merchant ed) -> ed
    | _ -> failwith "empty-ed-lost"
  in
  require ((not (Merchant.is_preview empty_ed)) && empty_enter.message = "") "empty-stays-editing";
  let empty_screen = Option.get (R.overlay_screen ~dimensions:(80, 24) ~width_of empty_enter) in
  require
    (contains empty_screen "Merchant party id must be a non-empty single text field.")
    "merch-empty-party-notice";

  (* Tab toggles to Nonmerchant *)
  let tab_nonmerch = Option.get (H.handle ~width_of empty_enter (`Key (`Tab, []))) in
  let nonmerch_ed =
    match session_of tab_nonmerch with
    | Some (E.Event_merchant ed) -> ed
    | _ -> failwith "nonmerch-ed-lost"
  in
  require (Merchant.choice nonmerch_ed = Merchant.Nonmerchant) "merch-tab-toggles-nonmerchant";
  let nonmerch_screen = Option.get (R.overlay_screen ~dimensions:(80, 24) ~width_of tab_nonmerch) in
  require
    (contains nonmerch_screen "Disposition: Nonmerchant"
    && contains nonmerch_screen "Party id: (not applicable)")
    "merch-nonmerchant-screen";

  (* In Nonmerchant, character typing is ignored *)
  let ignore_type = Option.get (H.handle ~width_of tab_nonmerch (`Key (`ASCII 's', []))) in
  let ignore_ed =
    match session_of ignore_type with
    | Some (E.Event_merchant ed) -> ed
    | _ -> failwith "ignore-ed-lost"
  in
  require (Merchant.party_input ignore_ed = "") "merch-nonmerchant-ignores-typing";

  (* Tab back to Merchant *)
  let tab_merch = Option.get (H.handle ~width_of ignore_type (`Key (`Tab, []))) in
  let merch_ed =
    match session_of tab_merch with
    | Some (E.Event_merchant ed) -> ed
    | _ -> failwith "merch-ed-lost"
  in
  require (Merchant.choice merch_ed = Merchant.Merchant) "merch-tab-toggles-merchant";

  (* Type party 'sanwa' *)
  let typed =
    List.fold_left
      (fun s c -> Option.get (H.handle ~width_of s (`Key (`ASCII c, []))))
      tab_merch [ 's'; 'a'; 'n'; 'w'; 'a' ]
  in

  (* Cancel leaves disk unchanged *)
  let cancelled = Option.get (H.handle ~width_of typed (`Key (`Escape, []))) in
  require (no_modal cancelled && F.read path = initial_bytes) "merch-cancel-preserves-disk";
  require (cancelled.message = "Merchant classification cancelled.") "merch-cancel-message";

  (* Reopen and transition to Preview *)
  let reopened = Option.get (H.handle ~width_of cancelled (`Key (`ASCII 'm', []))) in
  let typed_again =
    List.fold_left
      (fun s c -> Option.get (H.handle ~width_of s (`Key (`ASCII c, []))))
      reopened [ 's'; 'a'; 'n'; 'w'; 'a' ]
  in
  let preview = Option.get (H.handle ~width_of typed_again (`Key (`Enter, []))) in
  let prev_ed =
    match session_of preview with Some (E.Event_merchant ed) -> ed | _ -> failwith "prev-ed-lost"
  in
  require (Merchant.is_preview prev_ed) "merch-preview-mode";
  let prev_screen = Option.get (R.overlay_screen ~dimensions:(80, 24) ~width_of preview) in
  require
    (contains prev_screen "Event Merchant / Preview"
    && contains prev_screen "Target remains: e1"
    && contains prev_screen "Proposed: Merchant sanwa")
    "merch-preview-screen";

  (* Edit return from Preview via 'e' *)
  let returned_edit = Option.get (H.handle ~width_of preview (`Key (`ASCII 'e', []))) in
  let ret_ed =
    match session_of returned_edit with
    | Some (E.Event_merchant ed) -> ed
    | _ -> failwith "ret-ed-lost"
  in
  require
    ((not (Merchant.is_preview ret_ed)) && Merchant.party_input ret_ed = "sanwa")
    "merch-return-preserves-input";
  let preview_again = Option.get (H.handle ~width_of returned_edit (`Key (`Enter, []))) in

  (* Tiny terminal gate refuses Enter in preview *)
  let tiny_attempt =
    Option.get (H.handle ~dimensions:(32, 9) ~width_of preview_again (`Key (`Enter, [])))
  in
  let tiny_screen = Option.get (R.overlay_screen ~dimensions:(32, 9) ~width_of tiny_attempt) in
  require (contains tiny_screen "Enlarge terminal") "merch-tiny-gate-notice";
  require
    (List.exists
       (fun line ->
         Base.String.is_substring line
           ~substring:"Enlarge terminal to review the Merchant target and proposal before Publish.")
       (R.footer ~dimensions:(32, 9) ~width_of tiny_attempt))
    "merch-tiny-footer-notice";
  require (F.read path = initial_bytes) "merch-tiny-gate-preserves-disk";

  (* Publish at normal dimensions *)
  let published = Option.get (H.handle ~width_of preview_again (`Key (`Enter, []))) in
  require (no_modal published) "merch-published-closes-overlay";
  require (published.message = "Published Merchant sanwa for e1.") "merch-published-message";
  let published_bytes = F.read path in
  require (published_bytes <> initial_bytes) "merch-published-mutated-disk";

  (* Cold read verifies entry is classified as Merchant sanwa *)
  let cold_session = F.load path in
  let cold_e1 = Option.get (B.find_entry cold_session.book "e1") in
  require
    (cold_e1.merchant = Some (B.Merchant (get_id (D.Identifier.External_party.of_string "sanwa"))))
    "merch-cold-verified";

  (* Detail view in Actual displays 'Merchant: Merchant sanwa' *)
  let actual_post = C.open_route (C.initial ~config_home:dir cold_session) W.Actual in
  let actual_info = Option.get (H.handle ~width_of actual_post (`Key (`ASCII 'i', []))) in
  let actual_info_end = Option.get (H.handle ~width_of actual_info (`Key (`End, []))) in
  let actual_detail = R.screen ~width_of (80, 24) actual_info_end in
  require (contains actual_detail "Merchant: Merchant sanwa") "merch-actual-detail-displays";

  (* 3. Duplicate classification refusal: pressing 'm' on classified entry *)
  let repeat_attempt = Option.get (H.handle ~width_of actual_post (`Key (`ASCII 'm', []))) in
  require (no_modal repeat_attempt) "merch-repeat-does-not-open";
  require
    (repeat_attempt.message = "Merchant already classified: Merchant sanwa.")
    "merch-repeat-message";

  (* 4. Nonmerchant publication on second entry *)
  let e2 : B.entry =
    {
      id = "e2";
      day = "2026-10-11";
      memo = Some "Peer refund";
      effects =
        [
          D.Effect.create
            ~locus:(get_id (D.Identifier.Locus.of_string "wallet"))
            ~measure:(get_id (D.Identifier.Measure.of_string "jpy"))
            ~quantity:(D.Quantity.of_quanta (Z.of_int 500))
            ~key:None;
          D.Effect.create
            ~locus:(get_id (D.Identifier.Locus.of_string "food"))
            ~measure:(get_id (D.Identifier.Measure.of_string "jpy"))
            ~quantity:(D.Quantity.of_quanta (Z.of_int (-500)))
            ~key:None;
        ];
      reversal_of = None;
      exchange = None;
      original_amount = None;
      merchant = None;
    }
  in
  let _ =
    match F.publish cold_session [ B.Put_entry { replace = false; entry = e2; plan = None } ] with
    | F.Written s -> s
    | _ -> failwith "pub-e2-fail"
  in
  let sess_e2 = F.load path in
  let state_e2 = C.open_route (C.initial ~config_home:dir sess_e2) W.Actual in
  let e2_opened = Option.get (H.handle ~width_of state_e2 (`Key (`ASCII 'm', []))) in
  let e2_tab = Option.get (H.handle ~width_of e2_opened (`Key (`Tab, []))) in
  let e2_prev = Option.get (H.handle ~width_of e2_tab (`Key (`Enter, []))) in
  let e2_pub = Option.get (H.handle ~width_of e2_prev (`Key (`Enter, []))) in
  require (e2_pub.message = "Published Nonmerchant for e2.") "merch-e2-pub-message";
  let cold_e2_sess = F.load path in
  let cold_e2 = Option.get (B.find_entry cold_e2_sess.book "e2") in
  require (cold_e2.merchant = Some B.Nonmerchant) "merch-e2-cold-nonmerchant";

  (* 5. Selected Day workspace integration *)
  let e3 : B.entry =
    {
      id = "e3";
      day = "2026-10-12";
      memo = Some "Bakery visit";
      effects =
        [
          D.Effect.create
            ~locus:(get_id (D.Identifier.Locus.of_string "wallet"))
            ~measure:(get_id (D.Identifier.Measure.of_string "jpy"))
            ~quantity:(D.Quantity.of_quanta (Z.of_int (-400)))
            ~key:None;
          D.Effect.create
            ~locus:(get_id (D.Identifier.Locus.of_string "food"))
            ~measure:(get_id (D.Identifier.Measure.of_string "jpy"))
            ~quantity:(D.Quantity.of_quanta (Z.of_int 400))
            ~key:None;
        ];
      reversal_of = None;
      exchange = None;
      original_amount = None;
      merchant = None;
    }
  in
  let _ =
    match F.publish cold_e2_sess [ B.Put_entry { replace = false; entry = e3; plan = None } ] with
    | F.Written s -> s
    | _ -> failwith "pub-e3-fail"
  in
  let sess_e3 = F.load path in
  let day_state = C.open_route (C.initial ~config_home:dir sess_e3) (W.Selected_day "2026-10-12") in
  let e3_opened = Option.get (H.handle ~width_of day_state (`Key (`ASCII 'm', []))) in
  let e3_typed =
    List.fold_left
      (fun s c -> Option.get (H.handle ~width_of s (`Key (`ASCII c, []))))
      e3_opened [ 'b'; 'a'; 'k'; 'e'; 'r'; 'y' ]
  in
  let e3_prev = Option.get (H.handle ~width_of e3_typed (`Key (`Enter, []))) in
  let e3_pub = Option.get (H.handle ~width_of e3_prev (`Key (`Enter, []))) in
  require
    (e3_pub.message = "Published Merchant bakery for e3.")
    "merch-e3-published-on-selected-day";

  (* 6. Reversal noninheritance *)
  let actual_for_rev = C.open_route (C.initial ~config_home:dir (F.load path)) W.Actual in
  let rev_session = Interaction_check_fixture.reverse_entry_selected actual_for_rev in
  let rev_preview = Option.get (H.handle ~width_of rev_session (`Key (`Enter, []))) in
  let _ = Option.get (H.handle ~width_of rev_preview (`Key (`Enter, []))) in
  let post_rev_session = F.load path in
  let rev_entries = B.entries post_rev_session.book in
  let rev_entry = List.find (fun (e : B.entry) -> e.reversal_of = Some "e3") rev_entries in
  require (rev_entry.merchant = None) "reversal-entry-has-no-merchant";
  let orig_entry = Option.get (B.find_entry post_rev_session.book "e3") in
  require
    (orig_entry.merchant
    = Some (B.Merchant (get_id (D.Identifier.External_party.of_string "bakery"))))
    "original-entry-retains-merchant";

  (* 7. Save failure retains draft *)
  let e_unclass : B.entry =
    {
      id = "e_unclass";
      day = "2026-10-14";
      memo = Some "Hardware store";
      effects =
        [
          D.Effect.create
            ~locus:(get_id (D.Identifier.Locus.of_string "wallet"))
            ~measure:(get_id (D.Identifier.Measure.of_string "jpy"))
            ~quantity:(D.Quantity.of_quanta (Z.of_int (-1500)))
            ~key:None;
          D.Effect.create
            ~locus:(get_id (D.Identifier.Locus.of_string "food"))
            ~measure:(get_id (D.Identifier.Measure.of_string "jpy"))
            ~quantity:(D.Quantity.of_quanta (Z.of_int 1500))
            ~key:None;
        ];
      reversal_of = None;
      exchange = None;
      original_amount = None;
      merchant = None;
    }
  in
  let _ =
    match
      F.publish post_rev_session [ B.Put_entry { replace = false; entry = e_unclass; plan = None } ]
    with
    | F.Written s -> s
    | _ -> failwith "pub-unclass-fail"
  in
  let sess_unclass = F.load path in
  let cur_bytes = F.read path in
  let state_unclass =
    C.open_route (C.initial ~config_home:dir sess_unclass) (W.Selected_day "2026-10-14")
  in
  let ed_fail = Option.get (H.handle ~width_of state_unclass (`Key (`ASCII 'm', []))) in
  let ed_fail_typed =
    List.fold_left
      (fun s c -> Option.get (H.handle ~width_of s (`Key (`ASCII c, []))))
      ed_fail [ 't'; 'o'; 'o'; 'l'; 's' ]
  in
  let ed_fail_prev = Option.get (H.handle ~width_of ed_fail_typed (`Key (`Enter, []))) in
  let bad_path_state = { ed_fail_prev with session = unavailable_session ed_fail_prev.session } in
  let fail_pub = Option.get (H.handle ~width_of bad_path_state (`Key (`Enter, []))) in
  require
    (Option.is_some (session_of fail_pub) && F.read path = cur_bytes)
    "merch-save-fail-preserves-draft-and-disk";

  (* 8. Stale conflict: another writer modified disk *)
  let stale_state = ed_fail_prev in
  let dummy : B.entry =
    {
      id = "dummy_concurrent";
      day = "2026-10-15";
      memo = None;
      effects =
        [
          D.Effect.create
            ~locus:(get_id (D.Identifier.Locus.of_string "wallet"))
            ~measure:(get_id (D.Identifier.Measure.of_string "jpy"))
            ~quantity:(D.Quantity.of_quanta (Z.of_int (-10)))
            ~key:None;
          D.Effect.create
            ~locus:(get_id (D.Identifier.Locus.of_string "food"))
            ~measure:(get_id (D.Identifier.Measure.of_string "jpy"))
            ~quantity:(D.Quantity.of_quanta (Z.of_int 10))
            ~key:None;
        ];
      reversal_of = None;
      exchange = None;
      original_amount = None;
      merchant = None;
    }
  in
  let concurrent_book = get (B.put_entry (F.load path).book ~replace:false dummy ~plan:None) in
  let oc = open_out_bin path in
  output_string oc (Bakhlo_household.Daily_txt.text concurrent_book);
  close_out oc;
  let stale_pub = Option.get (H.handle ~width_of stale_state (`Key (`Enter, []))) in
  require stale_pub.blocked "merch-stale-conflict-blocked";

  print_endline
    "PASS: Event Merchant classification normal, nonmerchant, unresolved, duplicate refusal, \
     unknown event, invalid party, correction/reversal, cancel, save fail, stale conflict and cold \
     reopen."

(* LOAM Ctrl-U without suspense: confirm, admit the ordinary Locus through the
   single writer, and return to the same draft with the remainder filled. *)
let unresolved_enable_checks ~width_of ~directory () =
  let dir = directory ^ "/unresolved-enable" in
  Unix.mkdir dir 0o700;
  let path = dir ^ "/book.txt" in
  F.create_copy ~source:Interaction_check_fixture.example_book ~target:path;
  let home = C.initial ~config_home:dir (F.load path) in
  let book = home.session.book in
  require
    (not (List.mem "suspense" (Option.value ~default:[] (B.approved_loci book))))
    "unresolved-fixture-starts-without-suspense";
  let step record input =
    match
      S.handle ~new_id:F.new_id ~book ~base_revision:home.session.revision ~blocked:false
        ~dimensions:(80, 24) ~width_of record input
    with
    | S.Updated next -> next
    | _ -> raise (F.Refused "unresolved-editor-unexpected-outcome")
  in
  let typed record text = String.fold_left (fun r c -> step r (`Key (`ASCII c, []))) record text in
  (* wallet -500 and food +300: an unbalanced draft whose remainder is +200. *)
  let draft = step (S.create ~book ~day:"2026-10-11" ~measure:"jpy" ()) (`Key (`Tab, [])) in
  let draft = typed (step (step draft (`Key (`Tab, []))) (`Key (`Tab, []))) "wallet" in
  let draft = typed (step draft (`Key (`Tab, []))) "-500" in
  let draft = typed (step draft (`Key (`Tab, []))) "food" in
  let draft = typed (step draft (`Key (`Tab, []))) "300" in
  let asking = step draft (`Key (`ASCII 'u', [ `Ctrl ])) in
  let state = { home with record = Some asking; record_visible = true } in
  let before = F.read path in
  let enabled =
    match H.handle ~dimensions:(80, 24) ~width_of state (`Key (`Enter, [])) with
    | Some s -> s
    | None -> raise (F.Refused "unresolved-shell-exited")
  in
  let approved b = List.mem "suspense" (Option.value ~default:[] (B.approved_loci b)) in
  require
    (approved enabled.session.book && approved (F.load path).book && F.read path <> before)
    "unresolved-enable-admits-suspense-and-cold-loads";
  require
    (enabled.record_visible && Option.is_some enabled.record)
    "unresolved-enable-returns-to-draft";
  let painted =
    S.screen ~book:enabled.session.book ~dimensions:(80, 24) ~width_of (Option.get enabled.record)
    |> List.map snd |> String.concat "\n"
  in
  require
    (Base.String.is_substring painted ~substring:"Unresolved recording enabled"
    && Base.String.is_substring painted ~substring:"suspense"
    && Base.String.is_substring painted ~substring:"+200"
    && List.length (B.entries enabled.session.book) = List.length (B.entries book))
    "unresolved-enable-fills-remainder-without-recording-movement";
  print_endline
    "PASS: Ctrl-U without suspense asks, admits only the ordinary Locus, cold-loads it and returns \
     to the filled draft without recording the Movement."

(* Quick capture through the Shell: after one ordinary Record, "r", the start of
   its description, Enter and Enter preview the same Movement; Publish appends a
   second entry with the same description and postings. *)
let quick_capture_integration_checks ~width_of ~directory () =
  let dir = directory ^ "/quick-capture" in
  Unix.mkdir dir 0o700;
  let path = dir ^ "/book.txt" in
  F.create_copy ~source:Interaction_check_fixture.example_book ~target:path;
  let home = C.initial ~config_home:dir (F.load path) in
  let first =
    key ~width_of (key ~width_of (C.submit (prepare_record ~width_of home)) `End) `Enter
  in
  require
    ((not first.record_visible) && List.length (B.entries first.session.book) = 1)
    "quick-first-record-published";
  let quick = key ~width_of first (`ASCII 'r') in
  let quick = String.fold_left (fun s c -> key ~width_of s (`ASCII c)) quick "Eng" in
  let quick = key ~width_of (key ~width_of quick `Enter) `Enter in
  let review_rows =
    S.screen ~book:quick.session.book ~dimensions:(80, 24) ~width_of (Option.get quick.record)
  in
  require (contains review_rows "Record / Preview") "quick-enter-enter-reaches-record-preview";
  let saved = key ~width_of (key ~width_of quick `End) `Enter in
  let entries = B.entries (F.load path).book in
  let same (a : B.entry) (b : B.entry) =
    let postings (e : B.entry) =
      List.sort compare
        (List.map
           (fun p -> (Daily_draft.lstr (D.Effect.locus p), Z.to_string (Daily_draft.quanta p)))
           e.effects)
    in
    a.memo = b.memo && postings a = postings b
  in
  require
    ((not saved.record_visible)
    && List.length entries = 2
    && match entries with [ a; b ] -> same a b && a.id <> b.id | _ -> false)
    "quick-capture-publishes-same-movement-as-new-entry-cold";
  print_endline
    "PASS: Quick capture through the Shell previews and publishes a repeat of a past Record as a \
     new entry (cold)."

(* The Actual period picker through the Shell: it takes the keys while open
   (Space does not open Commands), survives a reload, and Enter opens the chosen
   window; nothing is written. *)
let period_picker_integration_checks ~width_of ~directory home =
  let posting locus quanta =
    D.Effect.create ~key:None
      ~locus:(get_id (D.Identifier.Locus.of_string locus))
      ~measure:(get_id (D.Identifier.Measure.of_string "jpy"))
      ~quantity:(D.Quantity.of_quanta (Z.of_int quanta))
  in
  let entry n : B.entry =
    {
      id = Printf.sprintf "picker-%02d" n;
      day = Printf.sprintf "2026-10-%02d" (n + 1);
      memo = Some (Printf.sprintf "Synthetic picker purchase %02d" n);
      effects = [ posting "wallet" (-100 - n); posting "food" (100 + n) ];
      reversal_of = None;
      exchange = None;
      original_amount = None;
      merchant = None;
    }
  in
  let book =
    List.fold_left
      (fun book n -> get (B.put_entry book ~replace:false (entry n) ~plan:None))
      home.C.session.book (List.init 3 Fun.id)
  in
  let path = directory ^ "/actual-picker.txt" in
  F.write_new path (Bakhlo_household.Daily_txt.text book);
  let before = F.read path in
  let dimensions = (100, 30) in
  let key = key ~dimensions ~width_of in
  let overlay state = Option.value ~default:[] (R.overlay_screen ~dimensions ~width_of state) in
  let has rows needle =
    List.exists (fun (_, text) -> Base.String.is_substring text ~substring:needle) rows
  in
  let actual = C.open_route (C.initial ~config_home:directory (F.load path)) W.Actual in
  let picking = key actual (`ASCII 'f') in
  require (has (overlay picking) "Choose period") "picker-overlay-painted-through-the-shell";
  require
    (List.hd (R.footer picking) = List.hd (Actual_period_picker.footer ~width:100))
    "picker-footer-replaces-the-list-keys";
  let spaced = key picking (`ASCII ' ') in
  require
    (spaced.overlay = C.No_overlay && has (overlay spaced) "Choose period")
    "picker-keeps-space-from-the-commands";
  let months = key picking (`ASCII 'l') in
  require
    (has (overlay months) "[Month]" && has (overlay months) "2026-10")
    "picker-switches-to-months";
  let reloaded =
    match H.handle ~dimensions ~width_of months (`Key (`ASCII 'r', [ `Ctrl ])) with
    | Some state -> state
    | None -> raise (F.Refused "picker-reload-quit")
  in
  require
    (has (overlay reloaded) "[Month]" && has (overlay reloaded) "3 entries")
    "picker-survives-a-reload-recounted";
  let opened = key (key reloaded `End) `Enter in
  require
    (opened.workspace.route = W.Actual
    && R.overlay_screen ~dimensions ~width_of opened = None
    && has (R.screen ~width_of dimensions opened) "[Month]"
    && has (R.screen ~width_of dimensions opened) "Synthetic picker purchase 02")
    "picker-enter-opens-the-oldest-month";
  let closed = key picking `Escape in
  require
    (closed.workspace.route = W.Actual && R.overlay_screen ~dimensions ~width_of closed = None)
    "picker-escape-returns-to-the-list";
  require ((key closed `Escape).workspace.route = W.Home) "list-escape-still-returns-home";
  require (F.read path = before) "picker-never-writes";
  print_endline "PASS: Actual period picker through the Shell (keys, reload, choose, no writes)."
