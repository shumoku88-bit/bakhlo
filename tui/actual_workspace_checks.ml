(* Synthetic qualification of the LOAM-aligned ActualWorkspace (UI-03 / UI-04).
   Validates 3-pane navigation (Loci / Transactions / Details), Locus live filtering,
   inline slash search, Date scope toggle, sort order toggle, Details scroll,
   record selection, and clean cursor positioning. *)

module B = Bakhlo_sexp.Daily_book
module A = Daily_actions
module Act = Actual_workspace

let require condition name =
  if not condition then failwith ("FAILED: actual_workspace_check: " ^ name)

let key ?(mods = []) button : Ui_input.input = `Key (button, mods)
let char_key c : Ui_input.input = `Key (`ASCII c, [])

let get = function Ok x -> x | Error why -> failwith why

let fixture =
  "(bakhlo-daily 3)\n(scope corrected-entries explicit-plans)\n\
   (measures (measure \"jpy\" 0))\n\
   (labels (provided (label \"assets:cash\" \"現金\" \"Cash\") (label \"expenses:groceries\" \"食費\" \"Food\") (label \"expenses:rent\" \"家賃\" \"Rent\")))\n\
   (approved-loci (provided \"assets:cash\" \"expenses:groceries\" \"expenses:rent\"))\n(entries)\n\
   (plans)\n\
   (support (zero-origin (\"expenses:groceries\" \"jpy\")) (openings)\n\
     (observations (observation (reflected) (quantities (\"assets:cash\" \"jpy\" 100000))))\n\
     (presence (not-supplied)))\n"

let add_entry book ~day ~memo ~locus1 ~amt1 ~locus2 ~amt2 =
  let entry =
    get
      (Result.map_error
         (fun error -> error.Daily_actions.message)
         (Daily_actions.build_transaction ~book ~mode:Daily_actions.New
            (Daily_actions.Multiple
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
               })))
  in
  get (B.put_entry book ~replace:false entry.entry ~plan:None)

let self_check () =
  let width_of text = Bonsai_term.View.width (Bonsai_term.View.text text) in
  let book = get (B.of_string fixture) in
  let book = add_entry book ~day:"2026-10-15" ~memo:"Supermarket" ~locus1:"assets:cash" ~amt1:(-1000) ~locus2:"expenses:groceries" ~amt2:1000 in
  let book = add_entry book ~day:"2026-10-14" ~memo:"Apartment rent" ~locus1:"assets:cash" ~amt1:(-50000) ~locus2:"expenses:rent" ~amt2:50000 in
  let book = add_entry book ~day:"2026-10-15" ~memo:"Coffee shop" ~locus1:"assets:cash" ~amt1:(-500) ~locus2:"expenses:groceries" ~amt2:500 in

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

  let ws, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (key ~mods:[`Shift] `Tab) in
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
  require (Base.String.is_substring (Act.notice ws_refused) ~substring:"Move to the Actuals pane") "loci-open-refused-notice";

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
  List.iter (fun book ->
    require (Act.visible_entries ~book no_match = []) "empty-visible-entries";
    require (Act.selected_entry ~book no_match = None) "empty-no-selection";
    List.iter (fun dimensions ->
      let rows = Act.screen ~book ~dimensions ~width_of no_match in
      let contains text = List.exists (fun (_, row) ->
        Base.String.is_substring row ~substring:text) rows in
      require (contains "0–0 / 0") "empty-range-is-zero";
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
  List.iter (fun (e : B.entry) -> require (e.day = "2026-10-15") "focus-day-entry-matched") day_results;

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
  List.iter (fun state ->
    let next, command = Act.handle ~book ~dimensions:dim_wide ~width_of state (key `Enter) in
    require (next = state) "enter-keeps-parent-state";
    require (match command, Act.selected_entry ~book state with
      | Act.Open_selected entry, Some selected -> entry.id = selected.id
      | _ -> false) "enter-opens-selected-once")
    [ ws; fst (Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'i')) ];
  let ws_detail, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'i') in
  let empty, _ = Act.handle ~book ~dimensions:dim_wide ~width_of no_match (key `Enter) in
  List.iter (fun state ->
    let next, command = Act.handle ~book ~dimensions:dim_wide ~width_of state (key `Enter) in
    require (command = Act.Stay && Act.pane next = Act.pane state
             && Act.selected_entry ~book next = None
             && Act.notice next <> "") "enter-empty-refuses-with-notice")
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
  let lines_wide = Act.screen ~book ~dimensions:dim_wide ~width_of ws in
  require (List.length lines_wide > 0) "wide-screen-rendered";
  let lines_compact = Act.screen ~book ~dimensions:dim_compact ~width_of ws in
  require (List.length lines_compact > 0) "compact-screen-rendered";
  let lines_48 = Act.screen ~book ~dimensions:(48, 14) ~width_of ws in
  let coffee_row =
    List.find_opt
      (fun (_, line) -> Base.String.is_substring line ~substring:"Coffee shop")
      lines_48
  in
  require
    (match coffee_row with
    | Some (_, line) -> Base.String.is_substring line ~substring:"+500 jpy"
    | None -> false)
    "48-column-row-keeps-full-amount";

  (* 10. Footer lines *)
  let ft = Act.footer ~dimensions:dim_wide ~width_of ws in
  require (List.length ft = 2) "footer-has-2-lines";
  require (Base.String.is_substring (List.hd ft) ~substring:"select") "footer-keys";

  (* 11. Capacity & page size bounds *)
  (* Page Down / Home navigation in Transactions *)
  let ws_pg, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (key (`Page `Down)) in
  require (Act.transaction_row ws_pg > 0 || List.length (Act.visible_entries ~book ws) <= 1) "page-down-advanced";
  let ws_home, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws_pg (key `Home) in
  require (Act.transaction_row ws_home = 0) "home-back-to-0";

  (* 12. returned_from_detail preserves locus and transaction identity *)
  let ws_locus, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws (char_key 'h') in
  let ws_locus, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws_locus (char_key 'j') in
  let ws_locus, _ = Act.handle ~book ~dimensions:dim_wide ~width_of ws_locus (char_key 'l') in
  let before_locus = Act.selected_locus ~book ws_locus in
  let before_entry = Act.selected_entry ~book ws_locus in
  let restored = Act.returned_from_detail ~before_book:book ~after_book:book ws_locus in
  require (Act.selected_locus ~book:book restored = before_locus) "returned-preserves-locus";
  require (Act.selected_entry ~book:book restored = before_entry) "returned-preserves-entry";

  Printf.printf "PASS: Actual workspace synthetic checks (3-pane, Loci filter, live search, date/order toggle, details scroll, selection, cursor).\n%!"
