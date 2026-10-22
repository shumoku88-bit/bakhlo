(* Synthetic qualification of the Actual workspace: the day-grouped list, the
   period filter and its windows, the EXPENSE totals and their partial marker,
   the amount order, and the existing 3-pane navigation, live search, details
   and cursor behaviour. *)

module B = Bakhlo_sexp.Daily_book
module A = Daily_draft
module Act = Actual_workspace
module Sc = Actual_screen
module Roles = Locus_roles
module O = Daily_overlays
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
   \"Food\") (label \"expenses:rent\" \"家賃\" \"Rent\") (label \"expenses:unfiled\" \"雑費\" \"Unfiled\")))\n\
   (approved-loci (provided \"assets:cash\" \"expenses:groceries\" \"expenses:rent\" \
   \"expenses:unfiled\"))\n\
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

let roles =
  [
    ("assets:cash", Roles.Asset);
    ("expenses:groceries", Roles.Expense);
    ("expenses:rent", Roles.Expense);
  ]

let month = { Act.start_day = "2026-10-01"; end_exclusive = "2026-11-01"; label = "Month 2026-10" }

let make_ctx ?(roles = Ok roles) ?(window = month) ?(today = "2026-10-15") ?(measure = "jpy") book =
  {
    Act.book = book;
    scope = { Act.window = window; today = today; focus_day = today; roles = roles; measure = measure };
    warning = None;
  }

let rows_of ctx t =
  Act.screen ~ctx:ctx ~total:None ~draft_retained:false ~dimensions:(120, 36)
    ~width_of:String.length t

let contains rows needle =
  List.exists (fun (_, line) -> Base.String.is_substring line ~substring:needle) rows

let presets = "Pension\t2026-09-01\t2026-10-01\t2026-11-01\n"

let env ?(today = "2026-10-15") ?(roles = roles) ?(presets = Some presets) book =
  Screen.env_for_checks ~book ~measure:"jpy" ~today ~accounting_roles:roles
    ~config:(fun name ->
      if name = "boundary-presets.tsv" then Ok presets
      else Error ("undeclared " ^ name))
    ()

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

  (* 1. Initial state: the Cycle window, newest first, the Actuals pane. *)
  let ws = Act.create () in
  require (Act.period ws = Act.Cycle) "initial-period-cycle";
  require (Act.period_offset ws = 0) "initial-period-offset";
  require (Act.sort_order ws = Act.Newest) "initial-order";
  require (Act.pane ws = Act.Transactions) "initial-pane";
  require (Act.locus_row ws = 0) "initial-locus-row";
  require (Act.transaction_row ws = 0) "initial-tx-row";
  require (Act.search_query ws = "") "initial-search-query";
  require (not (Act.search_editing ws)) "initial-not-editing";

  let ctx = make_ctx book in
  require (List.length (Act.visible_entries ~ctx ws) = 3) "initial-visible-3";

  (* 2. The list is grouped by day: a header per day, then its entries. *)
  let rows = rows_of ctx ws in
  require (contains rows "2026-10-15") "day-header-15";
  require (contains rows "2026-10-14") "day-header-14";
  require (contains rows "2 entries") "day-header-count";
  require (contains rows "Supermarket") "day-entry-supermarket";
  require (contains rows "Apartment rent") "day-entry-rent";
  (* The exact EXPENSE total per day, in the shared money format. *)
  require (contains rows "1,500 jpy") "day-total-15";
  require (contains rows "50,000 jpy") "day-total-14";
  (* The entries of a day follow their header. *)
  let index needle =
    let rec go i = function
      | [] -> -1
      | (_, line) :: rest ->
          if Base.String.is_substring line ~substring:needle then i else go (i + 1) rest
    in
    go 0 rows
  in
  require (index "2026-10-15" < index "Supermarket") "header-precedes-its-entries";
  require (index "2026-10-14" < index "Apartment rent") "header-precedes-its-entries-14";

  (* 3. The default selection is today's group. *)
  let selected = Act.selected_entry ~ctx ws in
  require
    (match selected with Some e -> e.day = "2026-10-15" | None -> false)
    "default-selection-today";
  (* Without entries today, the latest day before today is selected. *)
  let ctx_no_today = make_ctx ~today:"2026-10-20" book in
  let selected = Act.selected_entry ~ctx:ctx_no_today ws in
  require
    (match selected with Some e -> e.day = "2026-10-15" | None -> false)
    "default-selection-latest-before-today";

  (* 4. A day with an effect without a role marks its total partial. *)
  let book_with_unknown =
    add_entry book ~day:"2026-10-15" ~memo:"Unclassified" ~locus1:"assets:cash" ~amt1:(-300)
      ~locus2:"expenses:unfiled" ~amt2:300
  in
  let rows_unknown = rows_of (make_ctx book_with_unknown) ws in
  require (contains rows_unknown "1,500 jpy+?") "partial-total-is-marked";
  require (not (contains rows_unknown "1,800 jpy")) "partial-total-is-not-guessed";

  (* 5. Unreadable accounting roles: no totals, one notice whose cause stays
     visible at 80 columns and names the file once. *)
  let broken = { (make_ctx book) with scope = { (make_ctx book).scope with roles = Error "accounting-roles.tsv is malformed" } } in
  let rows_broken = rows_of broken ws in
  require (not (contains rows_broken "1,500 jpy")) "unreadable-roles-no-total";
  require (contains rows_broken "No day totals: accounting-roles.tsv is malformed") "unreadable-roles-notice";
  let rows_broken_80 =
    Act.screen ~ctx:broken ~total:None ~draft_retained:false ~dimensions:dim_compact
      ~width_of:String.length ws
  in
  require (contains rows_broken_80 "accounting-roles.tsv is malformed") "unreadable-roles-cause-at-80";

  require (contains rows_broken "Supermarket") "unreadable-roles-list-still-works";
  require (List.length (Act.visible_entries ~ctx:broken ws) = 3) "unreadable-roles-entries-kept";

  (* 5b. Day headers are headings with a counted noun; entries sit under them. *)
  let header_has_in rows day text =
    match List.find_opt (fun (_, line) -> Base.String.is_substring line ~substring:day) rows with
    | Some (style, line) ->
        (* The wide layout carries the Actuals style as its right column. *)
        (match style with O.Columns (_, _, right) -> right | style -> style) = O.Heading
        && Base.String.is_substring line ~substring:text
    | None -> false
  in
  let header_has = header_has_in rows in
  require (header_has "2026-10-15 Thu" "2 entries") "day-header-is-a-heading";
  require (header_has "2026-10-14 Wed" "1 entry") "one-entry-is-singular";
  require (not (contains rows "1 entries")) "no-1-entries";
  require (contains rows "     Apartment rent") "entries-indented-under-the-day";

  (* 5c. Under a Locus filter the day count and total describe the shown rows:
     Loci follow their first occurrence (cash, groceries, rent), row 0 is all. *)
  let step t c = fst (Act.handle ~ctx ~dimensions:dim_wide ~width_of t (char_key c)) in
  let groceries = step (step (step ws 'h') 'j') 'j' in
  require (Act.selected_locus ~ctx groceries = Some "expenses:groceries") "locus-filter-selected";
  let rows_groceries = rows_of ctx groceries in
  require (header_has_in rows_groceries "2026-10-15 Thu" "1,500 jpy") "filtered-total-matches-shown-rows";
  require (not (contains rows_groceries "2026-10-14 Wed")) "filtered-day-hidden";

  (* 5d. At 80x24 Details closes and the list keeps the height; [i] opens it. *)
  let screen_rows ws = Act.screen ~ctx ~total:None ~draft_retained:false ~dimensions:dim_compact ~width_of:String.length ws in
  let rows_80 = screen_rows ws in
  require (not (contains rows_80 "Details")) "compact-details-collapsed";
  require (List.length rows_80 = snd dim_compact) "compact-list-fills-the-height";
  require (contains (screen_rows (step ws 'i')) "Details") "compact-details-on-i";


  (* 6. Pane cycling *)
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (key `Tab) in
  require (Act.pane ws = Act.Details) "tab-to-details";
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (key `Tab) in
  require (Act.pane ws = Act.Loci) "tab-to-loci";
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (key `Tab) in
  require (Act.pane ws = Act.Transactions) "tab-to-transactions";

  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (key ~mods:[ `Shift ] `Tab) in
  require (Act.pane ws = Act.Loci) "backtab-to-loci";
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 'l') in
  require (Act.pane ws = Act.Transactions) "l-to-transactions";
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 'i') in
  require (Act.pane ws = Act.Details) "i-to-details";
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 'i') in
  require (Act.pane ws = Act.Transactions) "i-back-to-transactions";

  (* 7. Locus filtering *)
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 'h') in
  require (Act.pane ws = Act.Loci) "h-to-loci";
  require (Act.locus_row ws = 0) "locus-row-0";
  require (Act.selected_locus ~ctx ws = None) "locus-selected-none";

  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 'j') in
  require (Act.locus_row ws = 1) "locus-row-1";
  let selected_l = Act.selected_locus ~ctx ws in
  require (Option.is_some selected_l) "locus-selected-some";
  let l_entries = Act.visible_entries ~ctx ws in
  require (List.length l_entries > 0 && List.length l_entries <= 3) "locus-filtered";

  let ws_refused, cmd = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (key `Enter) in
  require (cmd = Act.Stay) "enter-in-loci-stay";
  require
    (Base.String.is_substring (Act.notice ws_refused) ~substring:"Move to the Actuals pane")
    "loci-open-refused-notice";

  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 'k') in
  require (Act.locus_row ws = 0) "locus-back-to-0";
  require (List.length (Act.visible_entries ~ctx ws) = 3) "locus-back-all-3";

  (* 8. Inline Search (/) *)
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key '/') in
  require (Act.search_editing ws) "search-editing-started";
  require (Act.pane ws = Act.Transactions) "search-pane-tx";
  require (Act.cursor_position ~dimensions:dim_wide ~width_of ws <> None) "search-cursor-active";

  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 'r') in
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 'e') in
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 'n') in
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 't') in
  require (Act.search_query ws = "rent") "search-query-rent";
  let search_results = Act.visible_entries ~ctx ws in
  require (List.length search_results = 1) "search-filtered-to-1";
  let first = List.hd search_results in
  require (first.memo = Some "Apartment rent") "search-matched-apartment-rent";

  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (key `Backspace) in
  require (Act.search_query ws = "ren") "search-query-ren";

  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (key `Enter) in
  require (not (Act.search_editing ws)) "search-editing-stopped";
  require (Act.search_query ws = "ren") "search-query-kept";
  require (Act.cursor_position ~dimensions:dim_wide ~width_of ws = None) "search-cursor-none";

  let no_match, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key '/') in
  let no_match, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of no_match (char_key 'z') in
  List.iter
    (fun book ->
      require (Act.visible_entries ~ctx:(make_ctx book) no_match = []) "empty-visible-entries";
      require (Act.selected_entry ~ctx:(make_ctx book) no_match = None) "empty-no-selection";
      List.iter
        (fun dimensions ->
          let rows =
            Act.screen ~ctx:(make_ctx book) ~total:None ~draft_retained:false ~dimensions ~width_of
              no_match
          in
          require (contains rows "0/0") "empty-range-is-zero";
          if snd dimensions >= 9 then
            require (contains rows "(no matching Actual") "empty-explanation-visible")
        [ (120, 36); (80, 24); (48, 14); (32, 9); (32, 7) ])
    [ book; get (B.of_string fixture) ];

  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key '/') in
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (key `Escape) in
  require (not (Act.search_editing ws)) "search-editing-cancelled";
  require (Act.search_query ws = "") "search-query-cleared";
  require (List.length (Act.visible_entries ~ctx ws) = 3) "search-restored-all";

  (* 9. The order cycles by date and then by amount; the amount order has no
     day header, because a day group would mislead there. *)
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 's') in
  require (Act.sort_order ws = Act.Oldest) "order-toggled-asc";
  let asc_entries = Act.visible_entries ~ctx ws in
  require ((List.hd asc_entries).day = "2026-10-14") "asc-first-is-oldest";
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 's') in
  require (Act.sort_order ws = Act.Largest) "order-toggled-amount";
  let amount_entries = Act.visible_entries ~ctx ws in
  require
    (match amount_entries with
    | e :: _ when e.memo = Some "Apartment rent" -> true
    | _ -> false)
    "amount-order-largest-first";
  let rows_amount = rows_of ctx ws in
  require (not (contains rows_amount " entries")) "amount-order-has-no-day-header";
  require (contains rows_amount "2026-10-14") "amount-order-keeps-the-date-column";
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 's') in
  require (Act.sort_order ws = Act.Newest) "order-back-to-newest";

  (* The amount order needs the roles: without them it is refused, not guessed. *)
  let broken_ctx = { (make_ctx book) with scope = { (make_ctx book).scope with roles = Error "unreadable" } } in
  let ws_amount, _ = Act.handle ~ctx:broken_ctx ~dimensions:dim_wide ~width_of ws (char_key 's') in
  let ws_amount, _ = Act.handle ~ctx:broken_ctx ~dimensions:dim_wide ~width_of ws_amount (char_key 's') in
  require (Act.sort_order ws_amount = Act.Oldest) "amount-order-refused-without-roles";
  require
    (Base.String.is_substring (Act.notice ws_amount) ~substring:"accounting-roles.tsv")
    "amount-order-refusal-names-the-file";

  (* 10. Enter opens the selected record; i separately focuses Details. *)
  List.iter
    (fun state ->
      let next, command = Act.handle ~ctx ~dimensions:dim_wide ~width_of state (key `Enter) in
      require (next = state) "enter-keeps-parent-state";
      require
        (match (command, Act.selected_entry ~ctx state) with
        | Act.Open_selected entry, Some selected -> entry.id = selected.id
        | _ -> false)
        "enter-opens-selected-once")
    [ ws; fst (Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 'i')) ];
  let ws_detail, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 'i') in
  let empty, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of no_match (key `Enter) in
  List.iter
    (fun state ->
      let next, command = Act.handle ~ctx ~dimensions:dim_wide ~width_of state (key `Enter) in
      require
        (command = Act.Stay
        && Act.pane next = Act.pane state
        && Act.selected_entry ~ctx next = None
        && Act.notice next <> "")
        "enter-empty-refuses-with-notice")
    [ empty; fst (Act.handle ~ctx ~dimensions:dim_wide ~width_of empty (char_key 'i')) ];
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws_detail (key `Escape) in
  require (Act.pane ws = Act.Transactions) "escape-details-moves-back-to-tx";

  (* 11. Navigation & Bounds in Transactions *)
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 'k') in
  require (Act.notice ws = "No previous Actual row.") "notice-no-prev-tx";
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 'j') in
  require (Act.transaction_row ws = 1) "tx-row-advanced-1";
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 'j') in
  require (Act.transaction_row ws = 2) "tx-row-advanced-2";
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 'j') in
  require (Act.notice ws = "No next Actual row.") "notice-no-next-tx";

  (* 12. Screen rendering (wide & compact) without exceptions *)
  let lines_wide = rows_of ctx ws in
  require (List.length lines_wide > 0) "wide-screen-rendered";
  let lines_compact =
    Act.screen ~ctx:ctx ~total:None ~draft_retained:false ~dimensions:dim_compact ~width_of ws
  in
  require (List.length lines_compact > 0) "compact-screen-rendered";
  let lines_48 = Act.screen ~ctx:ctx ~total:None ~draft_retained:false ~dimensions:(48, 14) ~width_of ws in
  let coffee_row =
    List.find_opt (fun (_, line) -> Base.String.is_substring line ~substring:"Coffee shop") lines_48
  in
  require
    (match coffee_row with
    | Some (_, line) -> Base.String.is_substring line ~substring:"500 jpy"
    | None -> false)
    "48-column-row-keeps-full-amount";

  (* 13. Footer lines *)
  let ft = Act.footer ~dimensions:dim_wide ~width_of ws in
  require (List.length ft = 2) "footer-has-2-lines";
  require (Base.String.is_substring (List.hd ft) ~substring:"select") "footer-keys";
  require (Base.String.is_substring (List.hd ft) ~substring:"period") "footer-names-the-period";

  (* 14. Capacity & page size bounds *)
  let ws_pg, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (key (`Page `Down)) in
  require
    (Act.transaction_row ws_pg > 0 || List.length (Act.visible_entries ~ctx ws) <= 1)
    "page-down-advanced";
  let ws_home, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws_pg (key `Home) in
  require (Act.transaction_row ws_home = 0) "home-back-to-0";

  (* 15. returned_from_detail preserves locus and transaction identity *)
  let ws_locus, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 'h') in
  let ws_locus, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws_locus (char_key 'j') in
  let ws_locus, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws_locus (char_key 'l') in
  let ws_locus = Act.set_scope (make_ctx book).scope ws_locus in
  let before_locus = Act.selected_locus ~ctx ws_locus in
  let before_entry = Act.selected_entry ~ctx ws_locus in
  let restored, _ = Act.returned_from_detail ~before_book:book ~after_book:book ws_locus in
  require (Act.selected_locus ~ctx restored = before_locus) "returned-preserves-locus";
  require (Act.selected_entry ~ctx restored = before_entry) "returned-preserves-entry";

  (* 16. Record_browser shares Actual and Scheduled rows; day/locus filters run
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

  (* 17. A transaction index that no longer exists is not clamped by
     selected_entry, but the render clamps its own local selection. *)
  let empty_book = get (B.of_string fixture) in
  require (Act.transaction_row ws = 2) "stale-fixture-row";
  require (Act.selected_entry ~ctx:(make_ctx empty_book) ws = None) "stale-row-selected-entry-none";
  let stale_rows = rows_of (make_ctx empty_book) ws in
  require (contains stale_rows "0/0") "stale-row-screen-clamps";

  (* 18. The Screen owns the period filter and its windows. *)
  let screen_env = env book in
  let geometry = { Screen.screen = (100, 30); body = (100, 27); content = (100, 27); width_of } in
  let title_of state = (Sc.view screen_env geometry state).Screen.title in
  let title_has state needle =
    Base.String.is_substring (title_of state) ~substring:needle
  in
  (* The Cycle window is the configured preset that contains today. *)
  require (title_has (Act.create ()) "Cycle 2026-10-01..2026-11-01") "title-names-the-cycle";
  require (title_has (Act.create ()) "Expense 51,500 jpy") "title-shows-the-window-total";

  (* A window outside the configured presets is refused, not guessed. *)
  let ws, request = Sc.handle screen_env geometry (Act.create ()) (char_key ']') in
  require (Act.period_offset ws = 0) "window-move-refused-outside-the-presets";
  require
    (match request with Screen.Message why -> why <> "" | _ -> false)
    "window-move-refusal-is-reported";
  (* The window moves to the previous configured window. *)
  let ws, _ = Sc.handle screen_env geometry (Act.create ()) (char_key '[') in
  require (Act.period_offset ws = -1) "window-moved-back";
  require (title_has ws "2026-09-01") "window-moved-to-the-previous-cycle";

  (* The period filter cycles; the window follows it. *)
  let ws, request = Sc.handle screen_env geometry (Act.create ()) (char_key 'f') in
  require (Act.period ws = Act.Month) "period-cycles-to-month";
  require (request <> Screen.Ignored) "period-stays-on-the-route";
  require (title_has ws "Month 2026-10") "title-names-the-month";
  let ws, _ = Sc.handle screen_env geometry ws (char_key 'f') in
  require (Act.period ws = Act.All) "period-cycles-to-all";
  require (title_has ws "All time") "title-names-all-time";
  let ws, _ = Sc.handle screen_env geometry ws (char_key 'f') in
  require (Act.period ws = Act.Today) "period-cycles-to-today";
  require (title_has ws "Day 2026-10-15") "title-names-the-day";

  (* Opened from the Calendar on a day, the window contains that day and its group
     is selected. *)
  let focused = Sc.enter ~focus_day:"2026-10-14" (Act.create ()) in
  require (title_has focused "Cycle 2026-10-01..2026-11-01") "focus-day-window";
  require (title_has (Sc.enter ~focus_day:"2026-09-20" (Act.create ())) "Cycle 2026-09-01..2026-10-01")
    "focus-day-picks-its-cycle";
  let focused, _ = Sc.handle screen_env geometry focused (char_key 'z') in
  require
    (match Act.selected_entry ~ctx:(Sc.context screen_env focused) focused with
     | Some e -> e.day = "2026-10-14"
     | None -> false)
    "focus-day-selected";

  Printf.printf
    "PASS: Actual workspace synthetic checks (day groups, totals, partial marker, unreadable \
     roles, period windows, orders, 3-pane navigation, live search, details, selection).\n\
     %!"
