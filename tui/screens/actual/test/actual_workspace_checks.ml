(* Synthetic qualification of the LOAM-aligned ActualWorkspace (UI-03 / UI-04).
   Validates 3-pane navigation (Loci / Transactions / Details), Locus live filtering,
   inline slash search, Date scope toggle, sort order toggle, Details scroll,
   record selection, and clean cursor positioning. *)

module B = Bakhlo_sexp.Daily_book
module A = Daily_draft
module Act = Actual_workspace
module RB = Record_browser

let require condition name =
  if not condition then failwith ("FAILED: actual_workspace_check: " ^ name)

let key ?(mods = []) button : Ui_input.input = `Key (button, mods)
let char_key c : Ui_input.input = `Key (`ASCII c, [])
let get = function Ok x -> x | Error why -> failwith why

let fixture =
  "(bakhlo-daily 3)\n\
   (scope corrected-entries explicit-plans)\n\
   (measures (measure \"jpy\" 0))\n\
   (labels (provided (label \"assets:cash\" \"現金\" \"Cash\") (label \"expenses:groceries\" \"食費\" \
   \"Food\") (label \"expenses:rent\" \"家賃\" \"Rent\")))\n\
   (approved-loci (provided \"assets:cash\" \"expenses:groceries\" \"expenses:rent\"))\n\
   (entries)\n\
   (plans)\n\
   (support (zero-origin (\"expenses:groceries\" \"jpy\")) (openings)\n\
   (observations (observation (reflected) (quantities (\"assets:cash\" \"jpy\" 100000))))\n\
   (presence (not-supplied)))\n"

let add_entry book ~day ~memo ~locus1 ~amt1 ~locus2 ~amt2 =
  let entry =
    get
      (Result.map_error
         (fun error -> error.A.message)
         (A.build_transaction
            ~new_id:(fun () -> day ^ ":" ^ memo)
            ~book ~mode:A.New
            (A.Multiple
               {
                 day;
                 memo;
                 draft =
                   {
                     Posting_draft.measure = "jpy";
                     rows =
                       [
                         {
                           Posting_draft.key = None;
                           locus = locus1;
                           negative = amt1 < 0;
                           amount = string_of_int (abs amt1);
                         };
                         {
                           Posting_draft.key = None;
                           locus = locus2;
                           negative = amt2 < 0;
                           amount = string_of_int (abs amt2);
                         };
                       ];
                   };
                 original_amount = None;
               })))
  in
  get (B.put_entry book ~replace:false entry.entry ~plan:None)

let self_check ~width_of () =
  let book = get (B.of_string fixture) in
  let book =
    add_entry book ~day:"2026-10-15" ~memo:"Supermarket" ~locus1:"assets:cash" ~amt1:(-1000)
      ~locus2:"expenses:groceries" ~amt2:1000
  in
  let book =
    add_entry book ~day:"2026-10-14" ~memo:"Apartment rent" ~locus1:"assets:cash" ~amt1:(-50000)
      ~locus2:"expenses:rent" ~amt2:50000
  in
  let book =
    add_entry book ~day:"2026-10-15" ~memo:"Coffee shop" ~locus1:"assets:cash" ~amt1:(-500)
      ~locus2:"expenses:groceries" ~amt2:500
  in

  let dim_wide = (120, 36) in
  let dim_compact = (80, 24) in

  (* 1. Initial State *)
  let ws = Act.create ~focus_date:"2026-10-15" in
  require (Act.focus_date ws = "2026-10-15") "initial-focus-date";
  require (Act.scope ws = Act.All_current) "initial-scope";
  require (Act.sort_order ws = Act.Desc) "initial-order";
  require (Act.pane ws = Act.Transactions) "initial-pane";
  require (Act.locus_row ws = 0) "initial-locus-row";
  require (Act.transaction_row ws = 0) "initial-tx-row";
  require (Act.search_query ws = "") "initial-search-query";
  require (not (Act.search_editing ws)) "initial-not-editing";

  let all_visible = Act.visible_entries ~book ws in
  require (List.length all_visible = 3) "initial-visible-3";

  (* 2. Pane Cycling *)
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (key `Tab) in
  require (Act.pane ws = Act.Details) "tab-to-details";
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (key `Tab) in
  require (Act.pane ws = Act.Loci) "tab-to-loci";
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (key `Tab) in
  require (Act.pane ws = Act.Transactions) "tab-to-transactions";

  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (key ~mods:[ `Shift ] `Tab) in
  require (Act.pane ws = Act.Loci) "backtab-to-loci";
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'l') in
  require (Act.pane ws = Act.Transactions) "l-to-transactions";
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'i') in
  require (Act.pane ws = Act.Details) "i-to-details";
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'i') in
  require (Act.pane ws = Act.Transactions) "i-back-to-transactions";

  (* 3. Locus filtering *)
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'h') in
  require (Act.pane ws = Act.Loci) "h-to-loci";
  require (Act.locus_row ws = 0) "locus-row-0";
  require (Act.selected_locus ~book ws = None) "locus-selected-none";

  (* Move down in Loci: row 1 *)
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'j') in
  require (Act.locus_row ws = 1) "locus-row-1";
  let selected_l = Act.selected_locus ~book ws in
  require (Option.is_some selected_l) "locus-selected-some";
  let l_entries = Act.visible_entries ~book ws in
  require (List.length l_entries > 0 && List.length l_entries <= 3) "locus-filtered";

  (* Try to open record from Loci pane: refused with notice *)
  let ws_refused, cmd = Act.handle ~book ~dimensions:dim_wide ~width_of ws (key `Enter) in
  require (cmd = Act.Stay) "enter-in-loci-stay";
  require
    (Base.String.is_substring (Act.notice ws_refused) ~substring:"Move to the Actuals pane")
    "loci-open-refused-notice";

  (* Return to row 0 (All loci) *)
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'k') in
  require (Act.locus_row ws = 0) "locus-back-to-0";
  require (List.length (Act.visible_entries ~book ws) = 3) "locus-back-all-3";

  (* 4. Inline Search (/) *)
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key '/') in
  require (Act.search_editing ws) "search-editing-started";
  require (Act.pane ws = Act.Transactions) "search-pane-tx";
  require (Act.cursor_position ~dimensions:dim_wide ~width_of ws <> None) "search-cursor-active";

  (* Type 'r', 'e', 'n', 't' *)
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'r') in
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'e') in
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'n') in
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 't') in
  require (Act.search_query ws = "rent") "search-query-rent";
  let search_results = Act.visible_entries ~book ws in
  require (List.length search_results = 1) "search-filtered-to-1";
  let first = List.hd search_results in
  require (first.memo = Some "Apartment rent") "search-matched-apartment-rent";

  (* Backspace to 'ren' *)
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (key `Backspace) in
  require (Act.search_query ws = "ren") "search-query-ren";

  (* Accept search with Enter: keeps query, exits editing mode *)
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (key `Enter) in
  require (not (Act.search_editing ws)) "search-editing-stopped";
  require (Act.search_query ws = "ren") "search-query-kept";
  require (Act.cursor_position ~dimensions:dim_wide ~width_of ws = None) "search-cursor-none";

  let no_match, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key '/') in
  let no_match, _ = Act.handle ~book ~dimensions:dim_wide ~width_of no_match (char_key 'z') in
  List.iter
    (fun book ->
      require (Act.visible_entries ~book no_match = []) "empty-visible-entries";
      require (Act.selected_entry ~book no_match = None) "empty-no-selection";
      List.iter
        (fun dimensions ->
          let rows =
            Act.screen ~book ~today:"2026-10-20" ~draft_retained:false ~dimensions ~width_of
              no_match
          in
          let contains text =
            List.exists (fun (_, row) -> Base.String.is_substring row ~substring:text) rows
          in
          require (contains "0/0") "empty-range-is-zero";
          if snd dimensions >= 9 then
            require (contains "(no matching Actual") "empty-explanation-visible")
        [ (120, 36); (80, 24); (48, 14); (32, 9); (32, 7) ])
    [ book; get (B.of_string fixture) ];

  (* Cancel search: start search then Esc *)
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key '/') in
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (key `Escape) in
  require (not (Act.search_editing ws)) "search-editing-cancelled";
  require (Act.search_query ws = "") "search-query-cleared";
  require (List.length (Act.visible_entries ~book ws) = 3) "search-restored-all";

  (* 5. Date Scope Toggle (f) *)
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'f') in
  require (Act.scope ws = Act.Focus_day) "scope-toggled-to-focus-day";
  let day_results = Act.visible_entries ~book ws in
  require (List.length day_results = 2) "focus-day-filtered-to-2";
  List.iter
    (fun (e : B.entry) -> require (e.day = "2026-10-15") "focus-day-entry-matched")
    day_results;

  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'f') in
  require (Act.scope ws = Act.All_current) "scope-toggled-back-all";
  require (List.length (Act.visible_entries ~book ws) = 3) "all-current-restored";

  (* 6. Sort Order Toggle (s) *)
  require (Act.sort_order ws = Act.Desc) "order-init-desc";
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 's') in
  require (Act.sort_order ws = Act.Asc) "order-toggled-asc";
  let asc_entries = Act.visible_entries ~book ws in
  require ((List.hd asc_entries).day = "2026-10-14") "asc-first-is-oldest";
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 's') in
  require (Act.sort_order ws = Act.Desc) "order-toggled-back-desc";
  let desc_entries = Act.visible_entries ~book ws in
  require ((List.hd desc_entries).day = "2026-10-15") "desc-first-is-newest";

  (* 7. Enter opens the selected record; i separately focuses Details. *)
  List.iter
    (fun state ->
      let next, command = Act.handle ~book ~dimensions:dim_wide ~width_of state (key `Enter) in
      require (next = state) "enter-keeps-parent-state";
      require
        (match (command, Act.selected_entry ~book state) with
        | Act.Open_selected entry, Some selected -> entry.id = selected.id
        | _ -> false)
        "enter-opens-selected-once")
    [ ws; fst (Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'i')) ];
  let ws_detail, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'i') in
  let empty, _ = Act.handle ~book ~dimensions:dim_wide ~width_of no_match (key `Enter) in
  List.iter
    (fun state ->
      let next, command = Act.handle ~book ~dimensions:dim_wide ~width_of state (key `Enter) in
      require
        (command = Act.Stay
        && Act.pane next = Act.pane state
        && Act.selected_entry ~book next = None
        && Act.notice next <> "")
        "enter-empty-refuses-with-notice")
    [ empty; fst (Act.handle ~book ~dimensions:dim_wide ~width_of empty (char_key 'i')) ];
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws_detail (key `Escape) in
  require (Act.pane ws = Act.Transactions) "escape-details-moves-back-to-tx";

  (* 8. Navigation & Bounds in Transactions *)
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'k') in
  require (Act.notice ws = "No previous Actual row.") "notice-no-prev-tx";
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'j') in
  require (Act.transaction_row ws = 1) "tx-row-advanced-1";
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'j') in
  require (Act.transaction_row ws = 2) "tx-row-advanced-2";
  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'j') in
  require (Act.notice ws = "No next Actual row.") "notice-no-next-tx";

  (* 9. Screen rendering (wide & compact) without exceptions *)
  let lines_wide =
    Act.screen ~book ~today:"2026-10-20" ~draft_retained:false ~dimensions:dim_wide ~width_of ws
  in
  require (List.length lines_wide > 0) "wide-screen-rendered";
  let lines_compact =
    Act.screen ~book ~today:"2026-10-20" ~draft_retained:false ~dimensions:dim_compact ~width_of ws
  in
  require (List.length lines_compact > 0) "compact-screen-rendered";
  let lines_48 =
    Act.screen ~book ~today:"2026-10-20" ~draft_retained:false ~dimensions:(48, 14) ~width_of ws
  in
  let coffee_row =
    List.find_opt (fun (_, line) -> Base.String.is_substring line ~substring:"Coffee shop") lines_48
  in
  require
    (match coffee_row with
    | Some (_, line) -> Base.String.is_substring line ~substring:"500 jpy"
    | None -> false)
    "48-column-row-keeps-full-amount";

  (* 10. Footer lines *)
  let ft = Act.footer ~dimensions:dim_wide ~width_of ws in
  require (List.length ft = 2) "footer-has-2-lines";
  require (Base.String.is_substring (List.hd ft) ~substring:"select") "footer-keys";

  (* 11. Capacity & page size bounds *)
  (* Page Down / Home navigation in Transactions *)
  let ws_pg, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (key (`Page `Down)) in
  require
    (Act.transaction_row ws_pg > 0 || List.length (Act.visible_entries ~book ws) <= 1)
    "page-down-advanced";
  let ws_home, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws_pg (key `Home) in
  require (Act.transaction_row ws_home = 0) "home-back-to-0";

  (* 12. returned_from_detail preserves locus and transaction identity *)
  let ws_locus, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'h') in
  let ws_locus, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws_locus (char_key 'j') in
  let ws_locus, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws_locus (char_key 'l') in
  let before_locus = Act.selected_locus ~book ws_locus in
  let before_entry = Act.selected_entry ~book ws_locus in
  let restored = Act.returned_from_detail ~before_book:book ~after_book:book ws_locus in
  require (Act.selected_locus ~book restored = before_locus) "returned-preserves-locus";
  require (Act.selected_entry ~book restored = before_entry) "returned-preserves-entry";

  (* 13. Record_browser shares Actual and Scheduled rows; day/locus filters run
     even when the text query is empty, and text search still covers ID, memo
     and Locus label. *)
  let plan_book =
    let rent_entry =
      List.find
        (fun (e : B.entry) -> e.id = "2026-10-14:Apartment rent")
        (B.entries book)
    in
    let plan : B.plan =
      let changes =
        match rent_entry.effects with
        | first :: second :: _ ->
            [ ("assets:cash", A.quanta first); ("expenses:rent", A.quanta second) ]
        | _ -> failwith "FAILED: actual_workspace_check: plan fixture effects"
      in
      {
        id = "plan-rent";
        day = "2026-10-16";
        measure = "jpy";
        changes;
        paid_by = None;
        cancelled_on = None;
      }
    in
    get (B.put_plan book ~replace:false plan)
  in
  let browser_rows browser =
    RB.visible ~book:plan_book browser (RB.all_rows plan_book)
  in
  let identities browser = List.map RB.identity (browser_rows browser) in
  let all_ids = identities RB.empty in
  require (List.length all_ids = 4) "browser-empty-query-keeps-all-rows";
  require
    (List.exists (fun (family, _) -> family = RB.Actual_row) all_ids
    && List.exists (fun (family, _) -> family = RB.Scheduled_row) all_ids)
    "browser-has-actual-and-scheduled";
  let day_browser = { RB.empty with day = Some "2026-10-15" } in
  require (List.length (browser_rows day_browser) = 2) "browser-empty-query-day-filter";
  List.iter
    (fun row -> require (RB.date row = "2026-10-15") "browser-day-filter-row")
    (browser_rows day_browser);
  let locus_browser = { RB.empty with locus = Some "expenses:rent" } in
  require
    (identities locus_browser
    = [ (RB.Scheduled_row, "plan-rent"); (RB.Actual_row, "2026-10-14:Apartment rent") ])
    "browser-empty-query-locus-filter";
  require
    (identities (RB.with_query RB.empty "coffee") = [ (RB.Actual_row, "2026-10-15:Coffee shop") ])
    "browser-search-memo";
  require
    (identities (RB.with_query RB.empty "2026-10-14:Apartment rent")
    = [ (RB.Actual_row, "2026-10-14:Apartment rent") ])
    "browser-search-id";
  require
    (List.length (identities (RB.with_query RB.empty "食費")) = 2)
    "browser-search-locus-label";
  require
    (identities (RB.with_query RB.empty "plan-rent") = [ (RB.Scheduled_row, "plan-rent") ])
    "browser-search-scheduled-id";
  require
    (browser_rows { day_browser with locus = Some "expenses:rent" } = [])
    "browser-empty-query-intersects-day-and-locus";
  require
    (identities (RB.with_query RB.empty "家賃") = identities locus_browser)
    "browser-search-label-covers-both-families";
  let memo_entry =
    { (List.hd (B.entries book)) with id = "independent-id"; memo = Some "Memo-only token" }
  in
  require
    (RB.matches ~book (RB.with_query RB.empty "memo-only") (RB.Actual_entry memo_entry))
    "browser-search-memo-independent-of-id";

  (* 14. A transaction index that no longer exists is not clamped by
     selected_entry, but the render clamps its own local selection. *)
  let empty_book = get (B.of_string fixture) in
  require (Act.transaction_row ws = 2) "stale-fixture-row";
  require (Act.selected_entry ~book:empty_book ws = None) "stale-row-selected-entry-none";
  let stale_rows =
    Act.screen ~book:empty_book ~today:"2026-10-20" ~draft_retained:false ~dimensions:dim_wide
      ~width_of ws
  in
  require
    (List.exists (fun (_, line) -> Base.String.is_substring line ~substring:"0/0") stale_rows)
    "stale-row-screen-clamps";

  (* 15. Bounded warm-render cache: selection, focus and scroll reuse the last
     book/scope/query projection without changing any output; a different book,
     a label change or another width provider refreshes the cached results; geometry reclamps them. *)
  let render ?(width_of = width_of) ~book ~dimensions state =
    Act.screen ~book ~today:"2026-10-20" ~draft_retained:false ~dimensions ~width_of state
  in
  let cold book = get (B.of_string (B.to_string book)) in
  let contains rows text =
    List.exists (fun (_, line) -> Base.String.is_substring line ~substring:text) rows
  in
  let starting = Act.create ~focus_date:"2026-10-15" in
  let step ?(book = book) ?(dimensions = dim_compact) state input =
    fst (Act.handle ~book ~dimensions ~width_of state input)
  in
  let after ?(book = book) ?(dimensions = dim_compact) inputs =
    List.fold_left (step ~book ~dimensions) starting inputs
  in
  let warm_state =
    after [ key (`Arrow `Down); key (`Arrow `Down); char_key 'i'; char_key 'j'; char_key 'i' ]
  in
  let warm_rows = render ~book ~dimensions:dim_compact warm_state in
  require
    (warm_rows = render ~book:(cold book) ~dimensions:dim_compact warm_state)
    "cache-warm-equals-cold";
  require (warm_rows = render ~book ~dimensions:dim_compact warm_state) "cache-warm-repeat";
  let shared_rows = Act.visible_entries ~book starting in
  let moved = step starting (key (`Arrow `Down)) in
  require
    (Act.visible_entries ~book moved == shared_rows)
    "cache-selection-reuses-query-rows";
  List.iter
    (fun (name, inputs) ->
      let state = after inputs in
      require
        (render ~book ~dimensions:dim_compact state
        = render ~book:(cold book) ~dimensions:dim_compact state)
        ("cache-warm-" ^ name))
    [
      ("down", [ key (`Arrow `Down) ]);
      ("end", [ key `End ]);
      ("page", [ key (`Page `Down) ]);
      ("pane", [ char_key 'h'; char_key 'l' ]);
      ("details", [ char_key 'i'; char_key 'j' ]);
      ("locus", [ char_key 'h'; char_key 'j'; char_key 'l' ]);
      ("order", [ char_key 's' ]);
      ("scope", [ char_key 'f' ]);
    ];
  (* A changed book (appended entry, corrected day, renamed label) must not
     reuse the previous projection. *)
  let appended =
    add_entry book ~day:"2026-10-16" ~memo:"Late entry" ~locus1:"assets:cash" ~amt1:(-700)
      ~locus2:"expenses:rent" ~amt2:700
  in
  let appended_rows = render ~book:appended ~dimensions:dim_compact warm_state in
  require (appended_rows <> warm_rows) "cache-book-entry-invalidated";
  require (contains appended_rows "(4,") "cache-book-entry-count";
  require (contains appended_rows "Late entry") "cache-book-entry-shown";
  require
    (appended_rows = render ~book:(cold appended) ~dimensions:dim_compact warm_state)
    "cache-book-entry-cold";
  let renamed = get (B.set_locus_label book ~id:"expenses:rent" ~label:"Rent renamed" ()) in
  let renamed_rows = render ~book:renamed ~dimensions:dim_compact warm_state in
  require (renamed_rows <> warm_rows) "cache-label-invalidated";
  require (contains renamed_rows "Rent renamed") "cache-label-shown";
  require
    (renamed_rows = render ~book:(cold renamed) ~dimensions:dim_compact warm_state)
    "cache-label-cold";
  let focused = after [ char_key 'f' ] in
  require (List.length (Act.visible_entries ~book focused) = 2) "cache-date-before";
  let redated =
    get (B.correct_entry_date book ~id:"2026-10-14:Apartment rent" ~day:"2026-10-15")
  in
  require
    (List.length (Act.visible_entries ~book:redated focused) = 3)
    "cache-date-membership-invalidated";
  require
    (List.length (Act.visible_entries ~book focused) = 2)
    "cache-date-old-book-restored";
  let query = "renamed" in
  let searched =
    after (char_key '/' :: List.init (String.length query) (fun i -> char_key query.[i]))
  in
  require (Act.visible_entries ~book searched = []) "cache-label-query-before";
  require
    (List.length (Act.visible_entries ~book:renamed searched) = 1)
    "cache-label-query-invalidated";
  require (Act.visible_entries ~book searched = []) "cache-label-old-book-restored";
  (* Stale selection: a warm projection for one book never leaks into another. *)
  let stale_rows = render ~book:empty_book ~dimensions:dim_compact ws in
  require (contains stale_rows "0/0") "cache-stale-count";
  require
    (stale_rows = render ~book:(cold empty_book) ~dimensions:dim_compact ws)
    "cache-stale-cold";
  (* Another width provider re-measures; switching back restores the paint. *)
  let double_width text = 2 * String.length text in
  let doubled = render ~width_of:double_width ~book ~dimensions:dim_compact warm_state in
  require
    (doubled = render ~width_of:double_width ~book:(cold book) ~dimensions:dim_compact warm_state)
    "cache-width-provider-cold";
  require (doubled <> warm_rows) "cache-width-provider-paint";
  require (render ~book ~dimensions:dim_compact warm_state = warm_rows) "cache-width-provider-restores";
  (* Geometry changes apply their own clamp on top of the reused maximum. *)
  List.iter
    (fun dimensions ->
      let state = after ~dimensions [ key (`Arrow `Down) ] in
      require
        (render ~book ~dimensions state = render ~book:(cold book) ~dimensions state)
        "cache-geometry-cold")
    [ dim_wide; dim_compact; (48, 14); (32, 9); (200, 60) ];
  (* Exact huge, split and multi-Measure amounts keep their summaries. Quantities
     are derived from an existing Effect, so no new dependency enters the check. *)
  let module D = B.D in
  let identifier = function
    | Ok value -> value
    | Error _ -> failwith "FAILED: actual_workspace_check: synthetic identifier"
  in
  let post measure locus quantity =
    D.Effect.create ~key:None
      ~locus:(identifier (D.Identifier.Locus.of_string locus))
      ~measure:(identifier (D.Identifier.Measure.of_string measure))
      ~quantity
  in
  let sample_effect = List.hd (List.hd (B.entries book)).effects in
  let unit = D.Quantity.neg (D.Effect.quantity sample_effect) in
  let rec doubled times value =
    if times = 0 then value else doubled (times - 1) (D.Quantity.add value value)
  in
  let huge = doubled 180 unit in
  let twice = D.Quantity.add unit unit in
  let amount_entry id day memo effects : B.entry =
    { id; day; memo = Some memo; effects; reversal_of = None; exchange = None;
      original_amount = None; merchant = None }
  in
  let mixed_book =
    get
      (B.of_payload
         {
           measures = [ ("jpy", 0); ("usd", 2) ];
           labels = None;
           approved = Some [ "wallet"; "food"; "rent" ];
           entries =
             [
               amount_entry "synthetic-huge" "2026-10-14" "Huge amount"
                 [
                   post "jpy" "wallet" (D.Quantity.neg huge);
                   post "jpy" "food" huge;
                 ];
               amount_entry "synthetic-split" "2026-10-15" "Split amount"
                 [
                   post "jpy" "wallet" (D.Quantity.neg twice);
                   post "jpy" "food" unit;
                   post "jpy" "rent" unit;
                 ];
               amount_entry "synthetic-multi" "2026-10-16" "Two Measures"
                 [
                   post "jpy" "wallet" (D.Quantity.neg unit);
                   post "jpy" "food" unit;
                   post "usd" "wallet" (D.Quantity.neg unit);
                   post "usd" "food" unit;
                 ];
             ];
           plans = [];
           origins = [];
           openings = [];
           observations = [];
           presence = None;
           bounded = [];
         })
  in
  let mixed_start = Act.create ~focus_date:"2026-10-16" in
  let mixed_rows = render ~book:mixed_book ~dimensions:dim_compact mixed_start in
  require (List.length (Act.visible_entries ~book:mixed_book mixed_start) = 3) "cache-mixed-visible";
  require (contains mixed_rows "split") "cache-split-summary";
  require (contains mixed_rows "multi (2)") "cache-multi-summary";
  require (contains mixed_rows "see details") "cache-huge-amount-bounded";
  require
    (mixed_rows = render ~book:(cold mixed_book) ~dimensions:dim_compact mixed_start)
    "cache-mixed-cold";
  require
    (render ~book:mixed_book ~dimensions:dim_compact mixed_start = mixed_rows)
    "cache-mixed-repeat";
  (* First-occurrence Loci order survives the reused scan. *)
  let locus_state =
    List.fold_left (step ~book:mixed_book) mixed_start
      [ char_key 'h'; char_key 'j'; char_key 'j'; char_key 'j' ]
  in
  let order =
    List.map
      (fun row ->
        let state =
          List.fold_left (step ~book:mixed_book) (step ~book:mixed_book mixed_start (char_key 'h'))
            (List.init row (fun _ -> char_key 'j'))
        in
        Act.selected_locus ~book:mixed_book state)
      [ 1; 2; 3 ]
  in
  require
    (Act.selected_locus ~book:mixed_book locus_state = Some "rent")
    "cache-locus-selection";
  require
    (order = [ Some "wallet"; Some "food"; Some "rent" ])
    "cache-locus-first-occurrence-order";

  Printf.printf
    "PASS: Actual workspace synthetic checks (3-pane, Loci filter, live search, date/order toggle, \
     details scroll, selection, cursor).\n\
     %!"
