(* Balances screen owner checks through the Screen contract only (pure, no files). *)
module B = Bakhlo_sexp.Daily_book
module O = Daily_overlays
module Balances = Balances_screen

let require condition name =
  if not condition then failwith ("FAILED: balances_owner_check: " ^ name)

let key ?(mods = []) button : Ui_input.input = `Key (button, mods)
let char_key c : Ui_input.input = `Key (`ASCII c, [])
let get = function Ok x -> x | Error why -> failwith why

let test_book_fixture =
  "(bakhlo-daily 3)\n(scope corrected-entries explicit-plans)\n\
   (measures (measure \"jpy\" 0) (measure \"eur\" 2))\n\
   (labels (provided (label \"wallet\" \"財布\" \"Cash\") (label \"bank\" \"銀行\" \"Bank\") (label \"food\" \"食費\" \"Food\")))\n\
   (approved-loci (provided \"wallet\" \"bank\" \"food\"))\n(entries)\n\
   (plans)\n\
   (support (zero-origin (\"food\" \"jpy\")) (openings)\n\
     (observations (observation (reflected) (quantities (\"wallet\" \"jpy\" 74500) (\"wallet\" \"eur\" 12345) (\"bank\" \"jpy\" 200000))))\n\
     (presence (not-supplied)))\n"

let test_roles =
  [ ("wallet", O.Asset); ("bank", O.Asset); ("food", O.Expense) ]

let env ~book balance_view_text : Screen.env =
  Screen.env_for_checks ~accounting_roles:test_roles ~book ~measure:"jpy" ~today:"2026-10-18"
    ~config:(function "balance-view.tsv" -> balance_view_text | name -> Error ("undeclared " ^ name)) ()

let geometry ?(dimensions = (80, 24)) ~width_of () : Screen.geometry =
  { screen = dimensions; body = dimensions; content = dimensions; width_of }

let unit_checks ~width_of () =
  let book = get (B.of_string test_book_fixture) in
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
  require (match List.nth_opt items_cur (Balances.selected owner) with
    | Some (O.Account_row _) -> true | _ -> false) "first-coord-present";

  (* 2. Items query with explicit balance-view.tsv *)
  let bv = env ~book (Ok (Some "bank\tjpy\nwallet\tjpy\n")) in
  let handle owner input = Balances.handle bv (geometry ~width_of ()) owner input in
  let items_bv = Balances.items bv owner in
  require (List.length items_bv = 2) "items-bv-exact-count";

  (* 3. Items query in Accounting mode *)
  let owner_acct, _ =
    handle owner (char_key 'v')
  in
  require (Balances.mode owner_acct = `Accounting) "v-toggles-to-accounting";
  require (Balances.title owner_acct = "Balances / Accounting") "title-accounting";
  let items_acct = Balances.items bv owner_acct in
  require (List.exists (function O.Header_row "Asset" -> true | _ -> false) items_acct) "acct-has-asset-header";
  require (List.exists (function O.Subtotal_row { role = O.Asset; _ } -> true | _ -> false) items_acct) "acct-has-asset-subtotal";

  (* 4. Toggle back to Current preserves selected coordinate *)
  let owner_back, _ =
    handle owner_acct (char_key 'v')
  in
  require (Balances.mode owner_back = `Current) "v-toggles-back-to-current";

  (* 5. Navigation in List: Down / Up / End / Home *)
  let owner_down, _ =
    handle owner (char_key 'j')
  in
  require (Balances.selected owner_down = 1) "j-moves-selection-down";
  let owner_up, _ =
    handle owner_down (char_key 'k')
  in
  require (Balances.selected owner_up = 0) "k-moves-selection-up";
  let owner_end, _ =
    handle owner (key `End)
  in
  require (Balances.selected owner_end = 1) "end-selects-last";
  let owner_home, _ =
    handle owner_end (key `Home)
  in
  require (Balances.selected owner_home = 0) "home-selects-first";

  (* 6. Detail pane toggle and scroll *)
  let owner_detail, _ =
    handle owner (char_key 'i')
  in
  require (Balances.detail_focused owner_detail) "i-opens-detail";
  let owner_enter_list, _ = handle owner_detail (key `Enter) in
  require (not (Balances.detail_focused owner_enter_list)) "enter-from-detail-returns-list";
  let owner_upper_detail, _ = handle owner (char_key 'I') in
  require (Balances.detail_focused owner_upper_detail) "uppercase-i-opens-detail";
  let owner_i_list, _ = handle owner_detail (char_key 'i') in
  require (not (Balances.detail_focused owner_i_list)) "i-from-detail-returns-list";
  List.iter (fun mods ->
    let tab_detail, request = handle owner (key ~mods `Tab) in
    require (Balances.detail_focused tab_detail && request = Screen.Stay)
      "tab-detail-toggle-keeps-measure";
    let tab_list, request = handle tab_detail (key ~mods `Tab) in
    require (not (Balances.detail_focused tab_list) && request = Screen.Stay)
      "tab-detail-toggle-returns-list") [ []; [ `Shift ] ];
  let uppercase_back, request = handle owner_detail (char_key 'Q') in
  require (not (Balances.detail_focused uppercase_back) && request = Screen.Stay)
    "uppercase-q-detail-returns-list";
  let _, request = handle uppercase_back (char_key 'Q') in
  require (request = Screen.Home) "uppercase-q-list-returns-home";
  let _owner_detail_down, _ =
    handle owner_detail (char_key 'j')
  in
  let owner_list_back, _ =
    handle owner_detail (key `Escape)
  in
  require (not (Balances.detail_focused owner_list_back)) "esc-returns-to-list";

  (* 7. Escape from list returns Back_to_home *)
  let _, cmd_esc =
    handle owner_list_back (key `Escape)
  in
  require (cmd_esc = Screen.Home) "esc-from-list-backs-to-home";

  (* 8. Space returns Open_commands *)
  let _, cmd_space =
    handle owner (char_key ' ')
  in
  require (cmd_space = Screen.Commands) "space-opens-commands";

  (* 9. 'o' key returns Observe intent with selected account *)
  let _, cmd_obs =
    handle owner (char_key 'o')
  in
  (match cmd_obs with
  | Screen.Observe { locus; measure; amount } ->
      require (locus = "bank") "observe-locus-bank";
      require (measure = "jpy") "observe-measure-jpy";
      require (amount = Some (Z.of_int 200000)) "observe-amount-200000"
  | _ -> failwith "expected-observe-intent");

  (* 10. 'p' key opens print preview *)
  let owner_print, _ =
    handle owner (char_key 'p')
  in
  require (Balances.modal owner_print) "p-opens-overlay";
  let owner_print_closed, _ =
    handle owner_print (key `Escape)
  in
  require (not (Balances.modal owner_print_closed)) "print-esc-closes";

  (* 11. 'c' key opens config picker *)
  let owner_cfg, _ =
    handle owner (char_key 'c')
  in
  require (Balances.modal owner_cfg) "c-opens-config-picker";
  let owner_cfg_closed, _ =
    handle owner_cfg (char_key 'q')
  in
  require (not (Balances.modal owner_cfg_closed)) "config-q-closes";

  (* 12. Screen rendering in 3 layout configurations *)
  let scr_stacked =
    Lazy.force (Balances.view bv (geometry ~dimensions:(80, 24) ~width_of ()) owner).rows
  in
  require (List.length scr_stacked = 24) "screen-stacked-height-24";
  let contains text needle =
    let rec loop i =
      i + String.length needle <= String.length text &&
      (String.sub text i (String.length needle) = needle || loop (i + 1)) in
    loop 0 in
  let painted_has rows needle = List.exists (fun (_, text) -> contains text needle) rows in
  require (painted_has scr_stacked "Amount" && painted_has scr_stacked "Measure"
    && painted_has scr_stacked "State") "current-full-columns-present";
  require (painted_has scr_stacked "+200,000" && painted_has scr_stacked "exact")
    "current-column-exact-amount-and-state";
  require (painted_has scr_stacked "銀行 [bank]" && painted_has scr_stacked "財布 [wallet]")
    "current-columns-preserve-label-and-stable-id";
  let eur_env = env ~book (Ok (Some "wallet\teur\n")) in
  let eur_rows = Lazy.force
    (Balances.view eur_env (geometry ~dimensions:(80, 24) ~width_of ()) owner).rows in
  require (painted_has eur_rows "Amount" && painted_has eur_rows "+123.45 eur")
    "current-amount-column-uses-scale-two-eur-not-raw-quanta";
  let unknown_env = env ~book (Ok (Some "bank\teur\nfood\tjpy\n")) in
  let unknown_rows = Lazy.force
    (Balances.view unknown_env (geometry ~dimensions:(80, 24) ~width_of ()) owner).rows in
  require (painted_has unknown_rows "unsupported" && painted_has unknown_rows "eur")
    "current-columns-retain-unsupported-and-measure";
  require (painted_has unknown_rows "exact" && painted_has unknown_rows "jpy")
    "current-columns-retain-supported-zero";
  let scr_split =
    Lazy.force (Balances.view bv (geometry ~dimensions:(120, 36) ~width_of ()) owner).rows
  in
  require (List.length scr_split = 36) "screen-split-height-36";
  require (painted_has scr_split "Amount" && painted_has scr_split "State")
    "current-wide-keeps-full-columns";
  let scr_tiny =
    Lazy.force (Balances.view bv (geometry ~dimensions:(32, 9) ~width_of ()) owner).rows
  in
  require (List.length scr_tiny = 9) "screen-tiny-height-9";

  (* 13. Footer formatting *)
  let ft = (Balances.view bv (geometry ~width_of ()) owner).footer in
  require (List.length ft = 2) "footer-has-2-lines";
  require (List.exists (fun line -> contains line "i/Enter/Tab details") ft)
    "list-footer-advertises-detail";
  let detail_ft = (Balances.view bv (geometry ~width_of ()) owner_detail).footer in
  require (List.exists (fun line -> contains line "Esc/i/Enter/Tab/q list") detail_ft)
    "detail-footer-advertises-return";
  require ((Balances.view bv (geometry ~width_of ()) owner).subtitle =
    Screen.Text "Selected Locus × Measure; balance-view order only.")
    "current-context-describes-coordinate-order";
  List.iter (fun dimensions ->
    List.iter (fun state ->
      let footer = (Balances.view bv (geometry ~dimensions ~width_of ()) state).footer in
      require (List.for_all (fun line -> width_of line <= fst dimensions) footer)
        "responsive-footer-fits-cell-width";
      require (List.exists (fun line -> contains line "p print") footer)
        "responsive-footer-keeps-print";
      require (List.exists (fun line -> contains line "page") footer)
        "responsive-footer-keeps-paging") [ owner; owner_detail ])
    [ (120,36); (80,24); (48,14); (32,9) ];
  require (List.for_all (fun hint -> List.exists (fun line -> contains line hint) ft)
    [ "w measure"; "v view"; "c config"; "o observe"; "Space commands" ])
    "medium-footer-keeps-feature-discovery";
  let scroll_env = env ~book (Ok (Some "bank\tjpy\nwallet\tjpy\nfood\tjpy\n")) in
  let tiny = geometry ~dimensions:(32,9) ~width_of () in
  let scroll_handle dimensions state input =
    fst (Balances.handle scroll_env (geometry ~dimensions ~width_of ()) state input) in
  let scrolled = Balances.set_selected 1 owner
    |> fun state -> scroll_handle (32,9) state (char_key 'i')
    |> fun state -> scroll_handle (32,9) state (key `End) in
  let _, scroll_before = Balances.detail_viewport scroll_env tiny scrolled in
  require (scroll_before.start > 0) "detail-scroll-fixture-really-scrolled";
  List.iter (fun return_key ->
    let returned = scroll_handle (32,9) scrolled return_key in
    let reopened = scroll_handle (32,9) returned (char_key 'i') in
    let _, after = Balances.detail_viewport scroll_env tiny reopened in
    require (after.start = scroll_before.start) "same-coordinate-return-retains-detail-scroll")
    [char_key 'i'; key `Enter; key `Escape; char_key 'q'; char_key 'h'];
  List.iter (fun dimensions ->
    List.iter (fun (motion, selected) ->
      let state = scroll_handle (32,9) scrolled (char_key 'i') in
      let state = scroll_handle dimensions state motion in
      let state = scroll_handle dimensions state (char_key 'i') in
      let _, after = Balances.detail_viewport scroll_env
        (geometry ~dimensions ~width_of ()) state in
      require (Balances.selected state = selected && after.start = 0)
        "changed-coordinate-starts-detail-at-top-after-resize")
      [ (key `Home,0); (key `End,2); (key (`Page `Up),0); (key (`Page `Down),2);
        (char_key 'j',2); (char_key 'k',0) ]) [(32,9);(48,14);(80,24)];
  print_endline "PASS: Balances vertical owner pure unit verification (state, query, motion, overlays, screen)."

let () = unit_checks ~width_of:String.length ()
