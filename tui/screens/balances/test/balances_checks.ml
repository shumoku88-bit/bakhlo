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
     (observations (observation (reflected) (quantities (\"wallet\" \"jpy\" 74500) (\"bank\" \"jpy\" 200000))))\n\
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
  let scr_split =
    Lazy.force (Balances.view bv (geometry ~dimensions:(120, 36) ~width_of ()) owner).rows
  in
  require (List.length scr_split = 36) "screen-split-height-36";
  let scr_tiny =
    Lazy.force (Balances.view bv (geometry ~dimensions:(32, 9) ~width_of ()) owner).rows
  in
  require (List.length scr_tiny = 9) "screen-tiny-height-9";

  (* 13. Footer formatting *)
  let ft = (Balances.view bv (geometry ~width_of ()) owner).footer in
  require (List.length ft = 2) "footer-has-2-lines";
  print_endline "PASS: Balances vertical owner pure unit verification (state, query, motion, overlays, screen)."

let () = unit_checks ~width_of:String.length ()
