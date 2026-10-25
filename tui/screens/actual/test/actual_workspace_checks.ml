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
  "BOOK\t1\n\
   MEASURE\tjpy\t0\n\
   LOCUS\tassets:cash\t現金\tCash\n\
   LOCUS\texpenses:groceries\t食費\tFood\n\
   LOCUS\texpenses:rent\t家賃\tRent\n\
   LOCUS\texpenses:unfiled\t雑費\tUnfiled\n\
   ZERO-ORIGIN\texpenses:groceries\tjpy\n\
   ANCHOR\t-\n\
   ASSERT\tassets:cash\tjpy\t100000\n\
   ENDANCHOR\n\
   END\n"

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
  { Act.book; scope = { Act.window; today; focus_day = today; roles; measure }; warning = None }

let rows_of ctx t =
  Act.screen ~ctx ~total:None ~draft_retained:false ~dimensions:(120, 36) ~width_of:String.length t

let contains rows needle =
  List.exists (fun (_, line) -> Base.String.is_substring line ~substring:needle) rows

let presets = "Pension\t2026-09-01\t2026-10-01\t2026-11-01\n"

let env ?(today = "2026-10-15") ?(roles = roles) ?(presets = Some presets) book =
  Screen.env_for_checks ~book ~measure:"jpy" ~today ~accounting_roles:roles
    ~config:(fun name ->
      if name = "boundary-presets.tsv" then Ok presets else Error ("undeclared " ^ name))
    ()

let self_check ~width_of () =
  let book = Bakhlo_sexp.Daily_txt.book fixture in
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
  let broken =
    {
      (make_ctx book) with
      scope = { (make_ctx book).scope with roles = Error "accounting-roles.tsv is malformed" };
    }
  in
  let rows_broken = rows_of broken ws in
  require (not (contains rows_broken "1,500 jpy")) "unreadable-roles-no-total";
  require
    (contains rows_broken "No day totals: accounting-roles.tsv is malformed")
    "unreadable-roles-notice";
  let rows_broken_80 =
    Act.screen ~ctx:broken ~total:None ~draft_retained:false ~dimensions:dim_compact
      ~width_of:String.length ws
  in
  require
    (contains rows_broken_80 "accounting-roles.tsv is malformed")
    "unreadable-roles-cause-at-80";
  (* A retained draft adds its notice; the cause stays on the line. *)
  let rows_drafted =
    Act.screen ~ctx:broken ~total:None ~draft_retained:true ~dimensions:dim_wide
      ~width_of:String.length ws
  in
  require
    (contains rows_drafted "Draft retained  |  No day totals: accounting-roles.tsv is malformed")
    "unreadable-roles-cause-kept-with-a-retained-draft";

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
  require
    (header_has_in rows_groceries "2026-10-15 Thu" "1,500 jpy")
    "filtered-total-matches-shown-rows";
  require (not (contains rows_groceries "2026-10-14 Wed")) "filtered-day-hidden";

  (* 5d. At 80x24 Details closes and the list keeps the height; [i] opens it. *)
  let screen_rows ws =
    Act.screen ~ctx ~total:None ~draft_retained:false ~dimensions:dim_compact
      ~width_of:String.length ws
  in
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
    [ book; Bakhlo_sexp.Daily_txt.book fixture ];

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
    (match amount_entries with e :: _ when e.memo = Some "Apartment rent" -> true | _ -> false)
    "amount-order-largest-first";
  let rows_amount = rows_of ctx ws in
  require (not (contains rows_amount " entries")) "amount-order-has-no-day-header";
  require (contains rows_amount "2026-10-14") "amount-order-keeps-the-date-column";
  let ws, _ = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (char_key 's') in
  require (Act.sort_order ws = Act.Newest) "order-back-to-newest";

  (* The amount order needs the roles: without them it is refused, not guessed. *)
  let broken_ctx =
    { (make_ctx book) with scope = { (make_ctx book).scope with roles = Error "unreadable" } }
  in
  let ws_amount, _ = Act.handle ~ctx:broken_ctx ~dimensions:dim_wide ~width_of ws (char_key 's') in
  let ws_amount, _ =
    Act.handle ~ctx:broken_ctx ~dimensions:dim_wide ~width_of ws_amount (char_key 's')
  in
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
    Act.screen ~ctx ~total:None ~draft_retained:false ~dimensions:dim_compact ~width_of ws
  in
  require (List.length lines_compact > 0) "compact-screen-rendered";
  let lines_48 =
    Act.screen ~ctx ~total:None ~draft_retained:false ~dimensions:(48, 14) ~width_of ws
  in
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
      List.find (fun (e : B.entry) -> e.id = "2026-10-14:Apartment rent") (B.entries book)
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
  let browser_rows browser = RB.visible ~book:plan_book browser (RB.all_rows plan_book) in
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
  require (List.length (identities (RB.with_query RB.empty "食費")) = 2) "browser-search-locus-label";
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
  let empty_book = Bakhlo_sexp.Daily_txt.book fixture in
  require (Act.transaction_row ws = 2) "stale-fixture-row";
  require (Act.selected_entry ~ctx:(make_ctx empty_book) ws = None) "stale-row-selected-entry-none";
  let stale_rows = rows_of (make_ctx empty_book) ws in
  require (contains stale_rows "0/0") "stale-row-screen-clamps";

  (* 17b. Moving back up from the end keeps the view until the selection reaches
     its top row; only then does the list scroll. *)
  let long_book =
    List.fold_left
      (fun book day ->
        add_entry book
          ~day:(Printf.sprintf "2026-10-%02d" day)
          ~memo:(Printf.sprintf "Long %02d" day) ~locus1:"assets:cash" ~amt1:(-100)
          ~locus2:"expenses:groceries" ~amt2:100)
      book
      (List.init 31 (fun i -> i + 1))
  in
  let long_ctx = make_ctx long_book in
  let press_list t input =
    fst (Act.handle ~ctx:long_ctx ~dimensions:dim_compact ~width_of t input)
  in
  let shown t =
    Act.screen ~ctx:long_ctx ~total:None ~draft_retained:false ~dimensions:dim_compact ~width_of t
  in
  (* The first list row under the column header. *)
  let first_row t =
    let rec after = function
      | (_, text) :: next :: _ when Base.String.is_substring text ~substring:"Description" ->
          snd next
      | _ :: rest -> after rest
      | [] -> ""
    in
    after (shown t)
  in
  let selected_row t =
    match
      List.find_opt (fun (_, text) -> Base.String.is_substring text ~substring:" > ") (shown t)
    with
    | Some (_, text) -> text
    | None -> ""
  in
  let at_end = press_list (Act.create ()) (key `End) in
  let up_once = press_list at_end (char_key 'k') in
  let up_thrice = press_list (press_list up_once (char_key 'k')) (char_key 'k') in
  require
    (first_row up_once = first_row at_end
    && first_row up_thrice = first_row at_end
    && selected_row up_thrice <> selected_row at_end)
    "moving-up-from-the-end-keeps-the-view";
  let far_up =
    List.fold_left (fun t _ -> press_list t (char_key 'k')) at_end (List.init 40 Fun.id)
  in
  require
    (first_row far_up <> first_row at_end && contains (shown far_up) (selected_row far_up))
    "the-view-moves-once-the-selection-reaches-its-top";
  let back_down = press_list far_up (char_key 'j') in
  require (first_row back_down = first_row far_up) "moving-down-inside-the-view-keeps-it";

  (* 18. The Screen owns the period, its windows, the period bar and the picker. *)
  let screen_env = env book in
  let geometry = { Screen.screen = (100, 30); body = (100, 27); content = (100, 27); width_of } in
  let press ?(env = screen_env) state input = fst (Sc.handle env geometry state input) in
  let request ?(env = screen_env) state input = snd (Sc.handle env geometry state input) in
  let keys ?env state inputs =
    List.fold_left (fun state input -> press ?env state input) state inputs
  in
  let title_of state = (Sc.view screen_env geometry state).Screen.title in
  let title_has state needle = Base.String.is_substring (title_of state) ~substring:needle in
  let bar ?(geometry = geometry) state =
    snd (List.hd (Lazy.force (Sc.view screen_env geometry state).Screen.rows))
  in
  let overlay ?(env = screen_env) state =
    match (Sc.view env geometry state).Screen.overlay with
    | Some frame -> frame.Ui_overlay.rows
    | None -> []
  in
  let refused = function Screen.Message why -> why <> "" | _ -> false in
  let selected_day state =
    Option.map
      (fun (e : B.entry) -> e.day)
      (Act.selected_entry ~ctx:(Sc.context screen_env state) (Sc.workspace state))
  in
  let fresh = Sc.create () in
  (* The Cycle window is the configured preset that contains today; the last day
     is named, not the exclusive end. *)
  require (title_has fresh "Cycle 2026-10-01 .. 2026-10-31") "title-names-the-cycle";
  require (title_has fresh "Expense 51,500 jpy") "title-shows-the-window-total";
  (* The period bar names every period, brackets the current one and keeps the total. *)
  let wide_bar = bar fresh in
  require
    (List.for_all
       (fun needle -> Base.String.is_substring wide_bar ~substring:needle)
       [
         "Day"; "[Cycle]"; "Month"; "Year"; "All"; "2026-10-01 .. 2026-10-31"; "Expense 51,500 jpy";
       ])
    "period-bar-names-every-period-the-window-and-the-total";
  require
    (match List.hd (Lazy.force (Sc.view screen_env geometry fresh).Screen.rows) with
    | O.Spans spans, _ -> List.mem (O.Heading, "[Cycle]") spans
    | _ -> false)
    "period-bar-marks-the-current-period";
  List.iter
    (fun width ->
      let narrow =
        { geometry with Screen.screen = (width, 24); body = (width, 21); content = (width, 21) }
      in
      let text = bar ~geometry:narrow fresh in
      require (width_of text <= width) "period-bar-fits";
      require
        (Base.String.is_substring text ~substring:"Expense 51,500 jpy")
        "period-bar-keeps-the-total-when-narrow")
    [ 80; 48; 32 ];

  (* A window outside the configured presets is refused, not guessed. *)
  let moved = press fresh (char_key ']') in
  require (Act.period_offset (Sc.workspace moved) = 0) "window-move-refused-outside-the-presets";
  require (refused (request fresh (char_key ']'))) "window-move-refusal-is-reported";
  let back = press fresh (char_key '[') in
  require (Act.period_offset (Sc.workspace back) = -1) "window-moved-back";
  require (title_has back "2026-09-01 .. 2026-09-30") "window-moved-to-the-previous-cycle";
  let cycle_year = press fresh (char_key '{') in
  require
    (title_has cycle_year "Cycle 2026-10-01 .. 2026-10-31")
    "year-move-refused-outside-the-presets";
  require (refused (request fresh (char_key '{'))) "year-move-refusal-is-reported";

  (* f opens the picker on the current window: every configured cycle, newest
     first, with its entry count and total, over the unchanged list. *)
  let picking = press fresh (char_key 'f') in
  require
    (Sc.modal picking && Sc.workspace picking = Sc.workspace fresh)
    "f-opens-the-picker-over-the-list";
  let picker = Option.get (Sc.picker picking) in
  require (Actual_period_picker.period picker = Act.Cycle) "picker-opens-on-the-current-period";
  require
    (match Actual_period_picker.selected picker with
    | Some row ->
        row.window.start_day = "2026-10-01"
        && row.now && row.count = 3 && row.total = Some "51,500 jpy"
    | None -> false)
    "picker-selects-the-current-window-with-its-count-and-total";
  let lines = overlay picking in
  let line_has needle = contains lines needle in
  require
    (line_has "Choose period" && line_has "[Cycle]"
    && line_has "2026-10-01 .. 2026-10-31  now"
    && line_has "3 entries  51,500 jpy"
    && line_has "2026-09-01 .. 2026-09-30"
    && line_has "no entries")
    "picker-lists-the-cycles-with-counts-and-totals";
  require
    (List.for_all (fun (_, text) -> width_of text <= 100) lines
    && (Sc.view screen_env geometry picking).Screen.footer = Actual_period_picker.footer ~width:100
    )
    "picker-fits-and-names-its-keys";
  require (keys picking [ key `Escape ] = fresh) "picker-escape-leaves-the-list-unchanged";
  require
    (keys picking [ char_key 'q' ] = fresh && keys picking [ char_key 'f' ] = fresh)
    "picker-q-and-f-close";

  (* Enter opens the chosen window; the list opens on its last day. *)
  let september = keys picking [ char_key 'j'; key `Enter ] in
  require (not (Sc.modal september)) "picker-enter-closes";
  require
    (title_has september "Cycle 2026-09-01 .. 2026-09-30"
    && Act.focus_day (Sc.workspace september) = Some "2026-09-30")
    "picker-enter-opens-the-chosen-cycle";
  (* The months run from the earliest to the latest of the ledger, today and the
     current window. *)
  let months = keys september [ char_key 'f'; char_key 'l' ] in
  let month_lines = overlay months in
  require
    (Actual_period_picker.period (Option.get (Sc.picker months)) = Act.Month
    && contains month_lines "[Month]"
    && contains month_lines "2026-10  now"
    && contains month_lines "2026-09"
    && not (contains month_lines "2026-08"))
    "picker-l-lists-the-months";
  require
    (match Actual_period_picker.selected (Option.get (Sc.picker months)) with
    | Some row -> row.window.start_day = "2026-09-01"
    | None -> false)
    "picker-period-switch-keeps-the-chosen-time";
  (* Month from today: the current month with today's group selected. *)
  let month = keys fresh [ char_key 'f'; char_key 'l'; key `Enter ] in
  require
    (Act.period (Sc.workspace month) = Act.Month && title_has month "Month 2026-10")
    "picker-opens-the-month";
  require (selected_day month = Some "2026-10-15") "month-selects-today";
  (* A year back and forth keeps the period: the same month a year earlier. *)
  let year_back = press month (char_key '{') in
  require (title_has year_back "Month 2025-10") "year-back-keeps-the-month";
  require (title_has (press year_back (char_key '}')) "Month 2026-10") "year-forward-returns";
  let year = keys fresh [ char_key 'f'; char_key 'l'; char_key 'l'; key `Enter ] in
  require
    (Act.period (Sc.workspace year) = Act.Year && title_has year "Year 2026")
    "picker-opens-the-year";
  require
    (Actual_period_picker.period
       (Option.get (Sc.picker (keys fresh [ char_key 'f'; key ~mods:[ `Shift ] `Tab ])))
    = Act.Today)
    "picker-shift-tab-goes-back";
  let all = keys fresh [ char_key 'f'; char_key 'h'; char_key 'h'; key `Enter ] in
  require
    (Act.period (Sc.workspace all) = Act.All && title_has all "All time")
    "picker-wraps-to-all";
  (* Days: the days with entries and today; a past day opens with its entries. *)
  let days = keys fresh [ char_key 'f'; char_key 'h' ] in
  let day_lines = overlay days in
  require
    (contains day_lines "[Day]"
    && contains day_lines "2026-10-15 Thu  now"
    && contains day_lines "2026-10-14 Wed"
    && contains day_lines "50,000 jpy")
    "picker-lists-the-days";
  let day = keys days [ char_key 'j'; key `Enter ] in
  require
    (Act.period (Sc.workspace day) = Act.Today
    && title_has day "Day 2026-10-14 Wed"
    && selected_day day = Some "2026-10-14")
    "picker-opens-a-past-day";

  (* Without boundary presets the Cycle picker says why; Enter refuses and stays. *)
  let unconfigured = env ~presets:None book in
  let bare = press ~env:unconfigured fresh (char_key 'f') in
  require
    (contains (overlay ~env:unconfigured bare) "Cycle not configured in boundary-presets.tsv.")
    "picker-names-a-missing-cycle";
  require
    (Sc.modal (press ~env:unconfigured bare (key `Enter))
    && refused (request ~env:unconfigured bare (key `Enter)))
    "picker-refuses-a-missing-cycle";
  require
    (title_has (keys ~env:unconfigured bare [ char_key 'l'; key `Enter ]) "Month 2026-10")
    "picker-month-works-without-presets";

  (* A reload recounts the open picker on the new book, on the same window. *)
  let grown =
    add_entry book ~day:"2026-10-16" ~memo:"Bakery" ~locus1:"assets:cash" ~amt1:(-300)
      ~locus2:"expenses:groceries" ~amt2:300
  in
  let reloaded, _ = Sc.reloaded (env grown) picking in
  require
    (match Option.bind (Sc.picker reloaded) Actual_period_picker.selected with
    | Some row ->
        row.window.start_day = "2026-10-01" && row.count = 4 && row.total = Some "51,800 jpy"
    | None -> false)
    "reload-recounts-the-open-picker";

  (* Entered on a day, the window contains that day and its group is selected. *)
  let focused = Sc.enter ~focus_day:"2026-10-14" (Sc.create ()) in
  require (title_has focused "Cycle 2026-10-01 .. 2026-10-31") "focus-day-window";
  require
    (title_has (Sc.enter ~focus_day:"2026-09-20" (Sc.create ())) "Cycle 2026-09-01 .. 2026-09-30")
    "focus-day-picks-its-cycle";
  require (selected_day (press focused (char_key 'z')) = Some "2026-10-14") "focus-day-selected";

  (* The amount column is as wide as the widest amount of the whole list (12 to
     22 cells), also when that row is off screen; a day scrolled into view shows
     its own total. *)
  let all = { Act.start_day = "0001-01-01"; end_exclusive = "9999-12-31"; label = "All time" } in
  (* Daily lunches, the newest with a description long enough to be cut where the
     amount column begins, and one wide amount on [wide_day]. *)
  let long_book ~wide_day ~wide =
    let book = Bakhlo_sexp.Daily_txt.book fixture in
    let book =
      if wide = 0 then book
      else
        add_entry book ~day:wide_day ~memo:"Wide" ~locus1:"assets:cash" ~amt1:(-wide)
          ~locus2:"expenses:rent" ~amt2:wide
    in
    List.fold_left
      (fun book d ->
        add_entry book
          ~day:(Printf.sprintf "2026-09-%02d" d)
          ~memo:(if d = 28 then "Lunch " ^ String.make 120 'x' else Printf.sprintf "Lunch %d" d)
          ~locus1:"assets:cash" ~amt1:(-500) ~locus2:"expenses:groceries" ~amt2:500)
      book (List.init 28 (fun d -> d + 1))
  in
  let render ~wide_day ~wide =
    let ctx = make_ctx ~window:all (long_book ~wide_day ~wide) in
    let ws = Act.create () in
    let at_end = Act.handle ~ctx ~dimensions:dim_wide ~width_of ws (key `End) |> fst in
    (rows_of ctx ws, rows_of ctx at_end)
  in
  let lunch rows =
    List.find_map
      (fun (_, line) -> if contains [ (O.Plain, line) ] "Lunch xxx" then Some line else None)
      rows
  in
  let column wide =
    let off_screen, at_end = render ~wide_day:"2026-08-01" ~wide in
    let on_screen, _ = render ~wide_day:"2026-09-27" ~wide in
    require (not (contains off_screen "Wide")) "wide-amount-off-screen";
    require (lunch off_screen = lunch on_screen) "amount-column-from-off-screen-row";
    (lunch off_screen, at_end)
  in
  let narrow, _ = column 0 in
  let wide, at_end = column 9876543210 in
  require (wide <> narrow) "amount-column-widens";
  require (contains at_end "9,876,543,210 jpy") "amount-column-shows-the-widest";
  require (contains at_end "2026-08-01 Sat  1 entry") "off-screen-day-header";
  require
    (List.exists
       (fun (_, line) ->
         Base.String.is_substring line ~substring:"2026-08-01"
         && Base.String.is_substring line ~substring:"9,876,543,210 jpy")
       at_end)
    "off-screen-day-total";
  let capped, at_end = column 1234567890123456789 in
  require (capped <> wide) "amount-column-capped";
  require (contains at_end "see details") "amount-beyond-the-cap";

  Printf.printf
    "PASS: Actual workspace synthetic checks (day groups, totals, partial marker, unreadable \
     roles, period windows, orders, 3-pane navigation, live search, details, selection).\n\
     %!"
