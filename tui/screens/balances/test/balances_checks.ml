(* Balances screen owner checks through the Screen contract only (pure, no files). *)
module B = Bakhlo_household.Daily_book
module O = Daily_overlays
module Balances = Balances_screen

let require condition name = if not condition then failwith ("FAILED: balances_owner_check: " ^ name)
let key ?(mods = []) button : Ui_input.input = `Key (button, mods)
let char_key c : Ui_input.input = `Key (`ASCII c, [])
let get = function Ok x -> x | Error why -> failwith why

let test_book_fixture =
  "BOOK\t1\n\
   MEASURE\tjpy\t0\n\
   MEASURE\teur\t2\n\
   MEASURE\tunambiguously-long-currency\t0\n\
   LOCUS\twallet\t財布\tCash\n\
   LOCUS\tbank\t銀行\tBank\n\
   LOCUS\tfood\t食費\tFood\n\
   ZERO-ORIGIN\tfood\tjpy\n\
   ANCHOR\t-\n\
   ASSERT\twallet\tjpy\t74500\n\
   ASSERT\twallet\teur\t12345\n\
   ASSERT\twallet\tunambiguously-long-currency\t4567\n\
   ASSERT\tbank\tjpy\t200000\n\
   ENDANCHOR\n\
   END\n"

let fixture_book () = Bakhlo_household.Daily_txt.book test_book_fixture

let test_roles =
  [ ("wallet", Locus_roles.Asset); ("bank", Locus_roles.Asset); ("food", Locus_roles.Expense) ]

let env ~book balance_view_text : Screen.env =
  Screen.env_for_checks ~accounting_roles:test_roles ~book ~measure:"jpy" ~today:"2026-10-18"
    ~config:(function
      | "balance-view.tsv" -> balance_view_text | name -> Error ("undeclared " ^ name))
    ()

let geometry ?(dimensions = (80, 24)) ~width_of () : Screen.geometry =
  let width, height = dimensions in
  (* Shell Standard layout: content = screen minus header, feedback and footer. *)
  { screen = dimensions; body = dimensions; content = (width, max 0 (height - 5)); width_of }

let unit_checks ~width_of () =
  let book = fixture_book () in
  let none = env ~book (Ok None) in
  let owner = Balances.create () in
  require (Balances.mode owner = `Current) "initial-mode-current";
  require (Balances.selected owner = 0) "initial-selected-0";
  require (not (Balances.detail_focused owner)) "initial-pane-list";
  require (not (Balances.modal owner)) "initial-no-overlay";
  require (Balances.title owner = "Balances / Current") "initial-title-current";

  (* 1. Items query in Current mode with no balance-view.tsv (defaults to approved loci) *)
  let items_cur = Balances.items none owner in
  require (List.length items_cur > 0) "items-current-nonempty";
  require
    (match List.nth_opt items_cur (Balances.selected owner) with
    | Some (Balance_items.Account_row _) -> true
    | _ -> false)
    "first-coord-present";

  (* 2. Items query with explicit balance-view.tsv *)
  let bv = env ~book (Ok (Some "bank\tjpy\nwallet\tjpy\n")) in
  let handle owner input = Balances.handle bv (geometry ~width_of ()) owner input in
  let items_bv = Balances.items bv owner in
  require (List.length items_bv = 2) "items-bv-exact-count";

  (* 3. Items query in Accounting mode *)
  let owner_acct, _ = handle owner (char_key 'v') in
  require (Balances.mode owner_acct = `Accounting) "v-toggles-to-accounting";
  require (Balances.title owner_acct = "Balances / Accounting") "title-accounting";
  let items_acct = Balances.items bv owner_acct in
  require
    (List.exists (function Balance_items.Header_row "Asset" -> true | _ -> false) items_acct)
    "acct-has-asset-header";
  require
    (List.exists
       (function Balance_items.Subtotal_row { role = Locus_roles.Asset; _ } -> true | _ -> false)
       items_acct)
    "acct-has-asset-subtotal";

  (* 4. Toggle back to Current preserves selected coordinate *)
  let owner_back, _ = handle owner_acct (char_key 'v') in
  require (Balances.mode owner_back = `Current) "v-toggles-back-to-current";

  (* 5. Navigation in List: Down / Up / End / Home *)
  let owner_down, _ = handle owner (char_key 'j') in
  require (Balances.selected owner_down = 1) "j-moves-selection-down";
  let owner_up, _ = handle owner_down (char_key 'k') in
  require (Balances.selected owner_up = 0) "k-moves-selection-up";
  let owner_end, _ = handle owner (key `End) in
  require (Balances.selected owner_end = 1) "end-selects-last";
  let owner_home, _ = handle owner_end (key `Home) in
  require (Balances.selected owner_home = 0) "home-selects-first";

  (* 6. Detail pane toggle and scroll *)
  let owner_detail, _ = handle owner (char_key 'i') in
  require (Balances.detail_focused owner_detail) "i-opens-detail";
  let owner_enter_list, _ = handle owner_detail (key `Enter) in
  require (not (Balances.detail_focused owner_enter_list)) "enter-from-detail-returns-list";
  let owner_upper_detail, _ = handle owner (char_key 'I') in
  require (Balances.detail_focused owner_upper_detail) "uppercase-i-opens-detail";
  let owner_i_list, _ = handle owner_detail (char_key 'i') in
  require (not (Balances.detail_focused owner_i_list)) "i-from-detail-returns-list";
  List.iter
    (fun mods ->
      let tab_detail, request = handle owner (key ~mods `Tab) in
      require
        (Balances.detail_focused tab_detail && request = Screen.Stay)
        "tab-detail-toggle-keeps-measure";
      let tab_list, request = handle tab_detail (key ~mods `Tab) in
      require
        ((not (Balances.detail_focused tab_list)) && request = Screen.Stay)
        "tab-detail-toggle-returns-list")
    [ []; [ `Shift ] ];
  let uppercase_back, request = handle owner_detail (char_key 'Q') in
  require
    ((not (Balances.detail_focused uppercase_back)) && request = Screen.Stay)
    "uppercase-q-detail-returns-list";
  let _, request = handle uppercase_back (char_key 'Q') in
  require (request = Screen.Home) "uppercase-q-list-returns-home";
  let _owner_detail_down, _ = handle owner_detail (char_key 'j') in
  let owner_list_back, _ = handle owner_detail (key `Escape) in
  require (not (Balances.detail_focused owner_list_back)) "esc-returns-to-list";

  (* 7. Escape from list returns Back_to_home *)
  let _, cmd_esc = handle owner_list_back (key `Escape) in
  require (cmd_esc = Screen.Home) "esc-from-list-backs-to-home";

  (* 8. Space returns Open_commands *)
  let _, cmd_space = handle owner (char_key ' ') in
  require (cmd_space = Screen.Commands) "space-opens-commands";

  (* 9. 'o' key returns Observe intent with selected account *)
  let _, cmd_obs = handle owner (char_key 'o') in
  (match cmd_obs with
  | Screen.Observe { locus; measure; amount } ->
      require (locus = "bank") "observe-locus-bank";
      require (measure = "jpy") "observe-measure-jpy";
      require (amount = Some (Z.of_int 200000)) "observe-amount-200000"
  | _ -> failwith "expected-observe-intent");

  (* 10. 'p' key opens print preview *)
  let owner_print, _ = handle owner (char_key 'p') in
  require (Balances.modal owner_print) "p-opens-overlay";
  let owner_print_closed, _ = handle owner_print (key `Escape) in
  require (not (Balances.modal owner_print_closed)) "print-esc-closes";

  (* 11. 'c' key opens config picker *)
  let owner_cfg, _ = handle owner (char_key 'c') in
  require (Balances.modal owner_cfg) "c-opens-config-picker";
  let owner_cfg_closed, _ = handle owner_cfg (char_key 'q') in
  require (not (Balances.modal owner_cfg_closed)) "config-q-closes";

  let contains text needle =
    let rec loop i =
      i + String.length needle <= String.length text
      && (String.sub text i (String.length needle) = needle || loop (i + 1))
    in
    loop 0
  in
  let painted_has rows needle = List.exists (fun (_, text) -> contains text needle) rows in

  (* 12. Current rendering: exact IDs and Measure-scaled Amount in owned geometry *)
  let stacked_geometry = geometry ~dimensions:(80, 24) ~width_of () in
  let scr_stacked = Lazy.force (Balances.view bv stacked_geometry owner).rows in
  require (List.length scr_stacked = 19) "screen-stacked-content-height-19";
  require
    (painted_has scr_stacked "Amount" && painted_has scr_stacked "Measure"
   && painted_has scr_stacked "State")
    "current-full-columns-present";
  require
    (painted_has scr_stacked "200,000" && painted_has scr_stacked "exact")
    "current-column-scaled-amount-and-state";
  require
    (painted_has scr_stacked "bank" && painted_has scr_stacked "wallet"
    && (not (painted_has scr_stacked "財布"))
    && not (painted_has scr_stacked "銀行"))
    "current-columns-use-ids-not-labels";
  let ordered_detail, _ = Balances.detail_viewport bv stacked_geometry owner in
  require
    (match ordered_detail with
    | " Locus: bank" :: " Measure: jpy" :: " Amount: 200,000 jpy" :: " State: exact" :: _ -> true
    | _ -> false)
    "selected-detail-keeps-coordinate-amount-state-order";
  require (painted_has scr_stacked "Selected balance") "stacked-detail-title-present";

  (* Amounts are Measure-scaled, without an adjustment '+'. Measures and zeros stay explicit. *)
  let eur_env = env ~book (Ok (Some "wallet\teur\n")) in
  let eur_rows = Lazy.force (Balances.view eur_env stacked_geometry owner).rows in
  require
    (painted_has eur_rows "123.45" && not (painted_has eur_rows "12,345"))
    "current-eur-shows-scaled-amount-not-raw-quanta";
  let eur_detail, _ = Balances.detail_viewport eur_env stacked_geometry owner in
  require
    (contains (String.concat "" eur_detail) "Amount: 123.45 eur")
    "detail-amount-is-scaled-and-labelled";
  let eur_print = Balances.print_preview_form eur_env owner in
  require
    (List.exists (fun line -> contains line "123.45 eur") eur_print.Ui_form.summary
    && not (List.exists (fun line -> contains line "12,345") eur_print.Ui_form.summary))
    "print-shares-scaled-amount-with-current-list";
  (* Scale-2 edges: exact one minor unit both signs and exact zero keep decimals. *)
  let edge_book = fixture_book () in
  let edge_book =
    get
      (B.observe_quantities edge_book
         [ ("wallet", "eur", Z.of_int 1); ("bank", "eur", Z.of_int (-1)); ("food", "eur", Z.zero) ])
  in
  let edge_env = env ~book:edge_book (Ok (Some "wallet\teur\nbank\teur\nfood\teur\n")) in
  let edge_detail index =
    let rows, _ =
      Balances.detail_viewport edge_env stacked_geometry (Balances.set_selected index owner)
    in
    String.concat "" rows
  in
  require (contains (edge_detail 0) "Amount: 0.01 eur") "scale2-positive-one-minor-unit";
  require (contains (edge_detail 1) "Amount: -0.01 eur") "scale2-negative-one-minor-unit";
  require (contains (edge_detail 2) "Amount: 0.00 eur") "scale2-exact-zero-keeps-decimals";
  let edge_rows = Lazy.force (Balances.view edge_env stacked_geometry owner).rows in
  require
    (painted_has edge_rows "0.01" && painted_has edge_rows "-0.01"
    && not (painted_has edge_rows "+0.01"))
    "current-table-shows-signed-scaled-amount-without-plus";
  let _, eur_observe = Balances.handle eur_env stacked_geometry owner (char_key 'o') in
  require
    (eur_observe
    = Screen.Observe { locus = "wallet"; measure = "eur"; amount = Some (Z.of_int 12345) })
    "amount-presentation-does-not-rescale-observe-intent";
  let unknown_env = env ~book (Ok (Some "bank\teur\nfood\tjpy\n")) in
  let bank_detail, _ =
    Balances.detail_viewport unknown_env stacked_geometry (Balances.set_selected 0 owner)
  in
  let bank_text = String.concat "" bank_detail in
  require
    (contains bank_text "Amount: ? eur" && contains bank_text "State: unsupported")
    "unknown-amount-is-question-with-measure";
  let food_detail, _ =
    Balances.detail_viewport unknown_env stacked_geometry (Balances.set_selected 1 owner)
  in
  require
    (contains (String.concat "" food_detail) "Amount: 0 jpy"
    && contains (String.concat "" food_detail) "State: exact")
    "zero-amount-is-exact-not-unknown";
  let unsupported_env = env ~book (Ok (Some "bank\teur\n")) in
  let unsupported_detail, _ = Balances.detail_viewport unsupported_env stacked_geometry owner in
  require
    (contains (String.concat "" unsupported_detail) "Amount: ? eur"
    && contains (String.concat "" unsupported_detail) "State: unsupported")
    "unsupported-does-not-become-an-exact-zero";
  let _, observe_unknown = Balances.handle unsupported_env stacked_geometry owner (char_key 'o') in
  require
    (observe_unknown = Screen.Observe { locus = "bank"; measure = "eur"; amount = None })
    "observe-keeps-unsupported-amount-unknown";
  let huge = Z.of_string (String.make 100 '7') in
  let huge_book = get (B.observe_quantities book [ ("wallet", "jpy", Z.neg huge) ]) in
  let huge_env = env ~book:huge_book (Ok (Some "wallet\tjpy\n")) in
  let huge_detail, _ =
    Balances.detail_viewport huge_env stacked_geometry (Balances.set_selected 0 owner)
  in
  require
    (contains
       (String.concat ""
          (List.map (fun line -> String.sub line 1 (String.length line - 1)) huge_detail))
       ("Amount: " ^ O.format_money huge_book "jpy" (Z.neg huge) ^ " jpy"))
    "detail-keeps-huge-negative-amount-exact";
  let huge_rows = Lazy.force (Balances.view huge_env stacked_geometry owner).rows in
  require
    (painted_has huge_rows "see details" && not (painted_has huge_rows (String.make 20 '7')))
    "current-huge-quantity-uses-see-details-without-partial-digits";
  let long_measure_env = env ~book (Ok (Some "wallet\tverylongmeasure\n")) in
  let long_measure_rows = Lazy.force (Balances.view long_measure_env stacked_geometry owner).rows in
  require
    (painted_has long_measure_rows "verylongmeasure" && painted_has long_measure_rows "unsupported")
    "long-measure-uses-compact-form-with-whole-token";

  (* 13. Owned geometry: 80 columns stack, wide splits, page steps match panels. *)
  let scr_split =
    Lazy.force (Balances.view bv (geometry ~dimensions:(120, 36) ~width_of ()) owner).rows
  in
  require (List.length scr_split = 31) "screen-wide-content-height-31";
  require
    (List.exists (function O.Columns _, _ -> true | _ -> false) scr_split)
    "wide-layout-splits-list-and-detail";
  require
    (not (List.exists (function O.Columns _, _ -> true | _ -> false) scr_stacked))
    "stacked-layout-has-no-columns";
  require (painted_has scr_split "Balances [active]") "focused-list-title-marks-active";
  let tiny_geometry = geometry ~dimensions:(32, 9) ~width_of () in
  let scr_tiny = Lazy.force (Balances.view bv tiny_geometry owner).rows in
  require (List.length scr_tiny = 4) "screen-tiny-content-height-4";
  let long_locus_env = env ~book (Ok (Some "averyverylonglocus\teur\n")) in
  let long_locus_rows = Lazy.force (Balances.view long_locus_env tiny_geometry owner).rows in
  require (painted_has long_locus_rows "eur") "narrow-compact-row-keeps-measure-under-long-locus";
  let long_currency_env = env ~book (Ok (Some "wallet\tunambiguously-long-currency\n")) in
  let long_currency_rows = Lazy.force (Balances.view long_currency_env tiny_geometry owner).rows in
  require
    (painted_has long_currency_rows "see details" && not (painted_has long_currency_rows "4,567"))
    "hidden-currency-never-qualifies-visible-digits";
  let paging_view =
    Ok (Some (String.concat "" (List.init 12 (fun i -> "p" ^ string_of_int i ^ "\tjpy\n"))))
  in
  let paging_env = env ~book paging_view in
  let page_down dimensions =
    let state =
      fst (Balances.handle paging_env (geometry ~dimensions ~width_of ()) owner (key (`Page `Down)))
    in
    Balances.selected state
  in
  require (page_down (80, 24) = 7) "page-step-matches-stacked-list-capacity";
  require (page_down (48, 14) = 6) "page-step-matches-compact-list-capacity";
  require (page_down (32, 9) = 1) "page-step-matches-tiny-list-capacity";
  require (page_down (120, 36) = 11) "page-step-clamps-to-last-row-wide";
  let warning_geometry = { stacked_geometry with Screen.content = (80, 15) } in
  let warned = fst (Balances.handle paging_env warning_geometry owner (key (`Page `Down))) in
  require
    (Balances.selected warned = 3
    && List.length (Lazy.force (Balances.view paging_env warning_geometry warned).rows) = 15)
    "warning-reduced-content-paints-and-pages-the-same-list";
  let compact_warning = { stacked_geometry with Screen.content = (80, 11) } in
  let focused = fst (Balances.handle bv compact_warning owner (char_key 'i')) in
  let _, focused_view = Balances.detail_viewport bv compact_warning focused in
  require
    (focused_view.capacity = 9
    && List.length (Lazy.force (Balances.view bv compact_warning focused).rows) = 11)
    "warning-reduced-content-keeps-focused-detail-scrollable";
  let _, stacked_detail_view = Balances.detail_viewport bv stacked_geometry owner in
  require (stacked_detail_view.capacity = 6) "stacked-detail-capacity-6";
  let _, wide_detail_view =
    Balances.detail_viewport bv (geometry ~dimensions:(120, 36) ~width_of ()) owner
  in
  require (wide_detail_view.capacity = 29) "wide-detail-capacity-29";
  let owner_tiny_detail = fst (Balances.handle bv tiny_geometry owner (char_key 'i')) in
  let _, tiny_detail_view = Balances.detail_viewport bv tiny_geometry owner_tiny_detail in
  require (tiny_detail_view.capacity = 2) "tiny-focused-detail-capacity-2";

  (* 14. Footer formatting *)
  let ft = (Balances.view bv stacked_geometry owner).footer in
  require (List.length ft = 2) "footer-has-2-lines";
  let _, measure_request = Balances.handle bv stacked_geometry owner (char_key 'w') in
  require (measure_request = Screen.Cycle_measure `Prev) "measure-key-stays-connected";
  List.iter
    (fun dimensions ->
      List.iter
        (fun state ->
          let footer = (Balances.view bv (geometry ~dimensions ~width_of ()) state).footer in
          require
            (List.for_all (fun line -> width_of line <= fst dimensions) footer)
            "responsive-footer-fits-cell-width";
          require
            (List.exists (fun line -> contains line "[p]") footer
            && List.exists (fun line -> contains line "[C-u/d]") footer)
            "responsive-guide-keeps-print-and-paging")
        [ owner; owner_detail ])
    [ (120, 36); (80, 24); (48, 14); (32, 9) ];
  let scroll_env = env ~book (Ok (Some "bank\tjpy\nwallet\tjpy\nfood\tjpy\n")) in
  let tiny = geometry ~dimensions:(32, 9) ~width_of () in
  let scroll_handle dimensions state input =
    fst (Balances.handle scroll_env (geometry ~dimensions ~width_of ()) state input)
  in
  let scrolled =
    Balances.set_selected 1 owner |> fun state ->
    scroll_handle (32, 9) state (char_key 'i') |> fun state ->
    scroll_handle (32, 9) state (key `End)
  in
  let _, scroll_before = Balances.detail_viewport scroll_env tiny scrolled in
  require (scroll_before.start > 0) "detail-scroll-fixture-really-scrolled";
  List.iter
    (fun return_key ->
      let returned = scroll_handle (32, 9) scrolled return_key in
      let reopened = scroll_handle (32, 9) returned (char_key 'i') in
      let _, after = Balances.detail_viewport scroll_env tiny reopened in
      require (after.start = scroll_before.start) "same-coordinate-return-retains-detail-scroll")
    [ char_key 'i'; key `Enter; key `Escape; char_key 'q'; char_key 'h' ];
  List.iter
    (fun dimensions ->
      List.iter
        (fun (motion, selected) ->
          let state = scroll_handle (32, 9) scrolled (char_key 'i') in
          let state = scroll_handle dimensions state motion in
          let state = scroll_handle dimensions state (char_key 'i') in
          let _, after =
            Balances.detail_viewport scroll_env (geometry ~dimensions ~width_of ()) state
          in
          require
            (Balances.selected state = selected && after.start = 0)
            "changed-coordinate-starts-detail-at-top-after-resize")
        [
          (key `Home, 0);
          (key `End, 2);
          (key (`Page `Up), 0);
          (key (`Page `Down), 2);
          (char_key 'j', 2);
          (char_key 'k', 0);
        ])
    [ (32, 9); (48, 14); (80, 24) ];
  print_endline
    "PASS: Balances vertical owner pure unit verification (state, query, motion, overlays, screen)."

let () = unit_checks ~width_of:String.length ()
