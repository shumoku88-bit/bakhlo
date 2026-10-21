(* Synthetic controller integration checks; see docs/RECONSTRUCTION_TEST_MAP.ja.md. *)
open Interaction_check_fixture

(* Liquidity: real Commands -> Reports and analysis -> Liquidity selection,
   an explicit Run over the synthetic file, then a cancelled return. *)
let run_liquidity ~width_of ~directory =
  let dir = directory ^ "/liquidity" in
  Unix.mkdir dir 0o700;
  let path = dir ^ "/book.sexp" in
  let book_bytes =
    "(bakhlo-daily 1) (scope corrected-entries explicit-plans)\n\
     (measures (measure jpy 0))\n\
     (labels (not-supplied)) (approved-loci (provided wallet ext))\n\
     (entries (entry seed (date 2026-01-01) (memo (none)) \
      (postings (posting wallet jpy 1000 (none)) (posting ext jpy -1000 (none))) \
      (reversal-of (none))))\n\
     (plans)\n\
     (support (zero-origin (wallet jpy)) (openings) (observations) \
      (presence (not-supplied)))\n"
  in
  F.write_new path book_bytes;
  F.write_new (dir ^ "/balance-view.tsv") "wallet\tjpy\n";
  let at_home = C.open_route (C.initial ~config_home:dir (F.load path)) W.Home in
  let bytes_before = F.read path in
  let commands = key ~width_of at_home (`ASCII ' ') in
  require
    (match commands.overlay with C.Commands { page = M.Root; _ } -> true | _ -> false)
    "liquidity-space-opens-commands";
  let analysis_index = Option.get (List.find_index
    (fun (item, _) -> item = M.Group M.Analysis) (M.items M.Root)) in
  let analysis = List.fold_left (fun state _ -> key ~width_of state (`ASCII 'j'))
    commands (List.init analysis_index Fun.id) in
  let analysis = key ~width_of analysis `Enter in
  require
    (match analysis.overlay with C.Commands { page = M.Analysis; _ } -> true | _ -> false)
    "liquidity-reports-analysis-group";
  let liquidity_index = Option.get (List.find_index
    (fun (item, _) -> item = M.Action M.Liquidity) (M.items M.Analysis)) in
  let selected = List.fold_left (fun state _ -> key ~width_of state (`ASCII 'j'))
    analysis (List.init liquidity_index Fun.id) in
  let liquidity = key ~width_of selected `Enter in
  require (liquidity.workspace.route = W.Liquidity) "liquidity-menu-selects-route";
  require (no_modal liquidity) "liquidity-route-has-no-modal";
  let env = X.screen_env ~config_files:Liquidity_screen.config_files liquidity in
  let screen = liquidity.C.screens.liquidity in
  require (Result.is_error (Liquidity_screen.result env screen))
    "liquidity-open-has-no-answer";
  let rows = R.screen ~width_of (80, 24) liquidity in
  require (contains rows "Forecast path: UNKNOWN") "liquidity-forecast-stays-unknown";
  require (contains rows "Known low-water mark: UNKNOWN") "liquidity-low-water-stays-unknown";
  require (Liquidity_screen.run_focused screen) "liquidity-enter-focuses-run";
  let ran = key ~width_of liquidity `Enter in
  let env = X.screen_env ~config_files:Liquidity_screen.config_files ran in
  let snapshot = get (Liquidity_screen.result env ran.C.screens.liquidity) in
  require (snapshot.Liquidity_report.measure = "jpy"
           && Z.equal snapshot.Liquidity_report.current_selected (Z.of_int 1000))
    "liquidity-explicit-run-answers-exact-selected-balance";
  let rows = R.screen ~width_of (80, 24) ran in
  require (contains rows "Forecast path: UNKNOWN") "liquidity-run-keeps-forecast-unknown";
  let home = key ~width_of ran `Escape in
  require (home.workspace.route = W.Home) "liquidity-escape-cancels-back-home";
  require (String.equal (F.read path) bytes_before)
    "liquidity-flow-leaves-synthetic-book-bytes-unchanged";
  require (String.equal (F.read (dir ^ "/balance-view.tsv")) "wallet\tjpy\n")
    "liquidity-flow-never-rewrites-the-selection"

let run ~width_of ~directory (back_home : C.state) =
  let contains rows needle = List.exists (fun (_, text) -> Base.String.is_substring text ~substring:needle) rows in
  (* Test Income & Expense report with Cycle / Month / Year / All-Time *)
  let ie_ctl = C.open_route back_home W.Income_expense in
  require (ie_ctl.workspace.route = W.Income_expense) "route-income-expense";
  let wide_ie = R.screen ~width_of (120, 30) ie_ctl in
  require (contains wide_ie "Income & Expense" && contains wide_ie "Report Details") "income-expense-wide-visible";
  let ie_cycle = key ~width_of ie_ctl (`ASCII '2') in
  let wide_cycle = R.screen ~width_of (120, 30) ie_cycle in
  require (contains wide_cycle "Cycle" || contains wide_cycle "Income & Expense") "income-expense-2-cycle";
  let ie_prev_cycle = key ~width_of ie_cycle (`ASCII '3') in
  let wide_prev_cycle = R.screen ~width_of (120, 30) ie_prev_cycle in
  require (contains wide_prev_cycle "Cycle" || contains wide_prev_cycle "Period") "income-expense-3-prev-cycle";
  let ie_year = key ~width_of ie_prev_cycle (`ASCII '4') in
  let wide_year = R.screen ~width_of (120, 30) ie_year in
  require (contains wide_year "Year") "income-expense-4-year";
  let ie_all = key ~width_of ie_year (`ASCII '5') in
  let wide_all = R.screen ~width_of (120, 30) ie_all in
  require (contains wide_all "All Time") "income-expense-5-all-time";
  let ie_shifted = key ~width_of ie_ctl (`ASCII '[') in
  let wide_shifted = R.screen ~width_of (120, 30) ie_shifted in
  require (contains wide_shifted "Income & Expense") "income-expense-bracket-shift";
  let ie_detail = key ~width_of ie_ctl `Enter in
  require (Income_expense_screen.detail_focused ie_detail.C.screens.income_expense) "income-expense-enter-opens-detail";
  let ie_back_report = key ~width_of ie_detail `Escape in
  require (not (Income_expense_screen.detail_focused ie_back_report.C.screens.income_expense) && ie_back_report.workspace.route = W.Income_expense)
    "income-expense-esc-returns-to-report";
  let ie_print = key ~width_of ie_ctl (`ASCII 'p') in
  (match visible_form ie_print with
   | Some f ->
       require (Ui_form.id f = "income_expense_print_preview") "ie-p-opens-print-preview";
       require (Ui_form.title f = "Income & Expense / Print Preview") "ie-print-title"
   | None -> failwith "expected ie print preview modal");
  let ie_after_print = key ~width_of ie_print `Escape in
  require (no_modal ie_after_print) "ie-print-escapes";
  let ie_back_home = key ~width_of ie_ctl (`ASCII 'q') in
  require (ie_back_home.workspace.route = W.Home) "ie-q-back-to-home";
  (* Test Transactions Flow report with Cycle / Month / Year / All-Time *)
  let flow_ctl = C.open_route back_home W.Transactions_flow in
  require (flow_ctl.workspace.route = W.Transactions_flow) "flow-route-opens";
  let flow_screen = R.screen ~width_of (120, 36) flow_ctl in
  require (contains flow_screen "Transactions Flow") "flow-screen-shows-heading";
  require (contains flow_screen "active coordinate") "flow-screen-shows-active-coordinates";
  require (contains flow_screen "Gross") "flow-screen-shows-gross-column";
  (* 1: Month *)
  let flow_m = key ~width_of flow_ctl (`ASCII '1') in
  require (contains (R.screen ~width_of (120, 36) flow_m) "Month of") "flow-preset-month";
  (* 2: Cycle *)
  let flow_cyc = key ~width_of flow_ctl (`ASCII '2') in
  require (contains (R.screen ~width_of (120, 36) flow_cyc) "Cycle" || contains (R.screen ~width_of (120, 36) flow_cyc) "Transactions Flow") "flow-preset-cycle";
  (* 3: Previous Cycle *)
  let flow_prev_cyc = key ~width_of flow_ctl (`ASCII '3') in
  require (contains (R.screen ~width_of (120, 36) flow_prev_cyc) "Cycle" || contains (R.screen ~width_of (120, 36) flow_prev_cyc) "Period") "flow-preset-prev-cycle";
  (* 4: Year *)
  let flow_yr = key ~width_of flow_ctl (`ASCII '4') in
  require (contains (R.screen ~width_of (120, 36) flow_yr) "Year") "flow-preset-year";
  (* 5: All Time *)
  let flow_all = key ~width_of flow_ctl (`ASCII '5') in
  require (contains (R.screen ~width_of (120, 36) flow_all) "All Time") "flow-preset-all-time";
  (* Shift period with [ and ] *)
  let flow_shift = key ~width_of flow_m (`ASCII '[') in
  require (contains (R.screen ~width_of (120, 36) flow_shift) "Month of 2026-09") "flow-shift-back";
  let flow_shift_fwd = key ~width_of flow_shift (`ASCII ']') in
  require (contains (R.screen ~width_of (120, 36) flow_shift_fwd) "Month of 2026-10") "flow-shift-fwd";
  (* Selection navigation with j/k *)
  let flow_j = key ~width_of flow_all (`ASCII 'j') in
  require (Transactions_flow_screen.selected_row flow_j.C.screens.transactions_flow >= 0) "flow-j-moves-row";
  let flow_k = key ~width_of flow_j (`ASCII 'k') in
  require (Transactions_flow_screen.selected_row flow_k.C.screens.transactions_flow = 0) "flow-k-moves-row-back";
  (* Detail toggle with Tab *)
  let flow_tab = key ~width_of flow_all `Tab in
  require (Transactions_flow_screen.detail_focused flow_tab.C.screens.transactions_flow) "flow-tab-toggles-detail";
  let flow_tab_back = key ~width_of flow_tab `Tab in
  require (not (Transactions_flow_screen.detail_focused flow_tab_back.C.screens.transactions_flow)) "flow-tab-toggles-calendar";
  (* p opens print preview modal *)
  let flow_print = key ~width_of flow_all (`ASCII 'p') in
  (match visible_form flow_print with
   | Some f ->
       require (Ui_form.id f = "transactions_flow_print_preview") "flow-p-opens-print-preview";
       require (Ui_form.title f = "Transactions Flow / Print Preview") "flow-print-title"
   | None -> failwith "expected flow print preview modal");
  let flow_after_print = key ~width_of flow_print `Escape in
  require (no_modal flow_after_print) "flow-print-escapes";
  let flow_back_home = key ~width_of flow_ctl (`ASCII 'q') in
  require (flow_back_home.workspace.route = W.Home) "flow-q-back-to-home";
  let sf_dir = directory ^ "/stock-flow" in
  Unix.mkdir sf_dir 0o700;
  let sf_path = sf_dir ^ "/book.sexp" in
  F.create_copy ~source:Interaction_check_fixture.example_book ~target:sf_path;
  let sf_ctl = C.open_route (C.initial ~config_home:sf_dir (F.load sf_path)) W.Stock_flow in
  let bv_path = sf_dir ^ "/balance-view.tsv" in
  let configure bytes =
    if Sys.file_exists bv_path then Unix.unlink bv_path;
    F.write_new bv_path bytes
  in
  let refused () =
    require (Result.is_error (stock_flow_result sf_ctl)) "sf-invalid-evidence-refuses";
    let printed = key ~width_of sf_ctl (`ASCII 'p') in
    require (no_modal printed && printed.message <> "")
      "sf-invalid-evidence-cannot-print-numeric-report"
  in
  refused ();
  List.iter (fun bytes -> configure bytes; refused ())
    ["bank\tjpy\n"; "wallet\tjpy\n"; "food\tjpy\nbad-row\n";
     "food\tjpy\nwallet\teur\n"; "food\tjpy\nfood\tjpy\n"; ""];
  configure "food\tjpy\n";
  let report = get (stock_flow_result sf_ctl) in
  require (report.measure = "jpy" && Z.equal report.reconstructed_start Z.zero
           && Z.equal report.reconstructed_end Z.zero)
    "sf-explicit-zero-origin-boundaries";
  let detail = key ~width_of sf_ctl `Tab in
  let returned = key ~width_of detail `Escape in
  require (returned.workspace.route = W.Stock_flow && not (Stock_flow_screen.detail_focused returned.C.screens.stock_flow))
    "sf-detail-return-retains-report";
  let sf_back_home = key ~width_of returned (`ASCII 'q') in
  require (sf_back_home.workspace.route = W.Home) "sf-report-return-home";
  run_liquidity ~width_of ~directory;
  ()
