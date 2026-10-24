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
     (entries (entry seed (date 2026-01-01) (memo (none)) (postings (posting wallet jpy 1000 \
     (none)) (posting ext jpy -1000 (none))) (reversal-of (none))))\n\
     (plans)\n\
     (support (zero-origin (wallet jpy)) (openings) (observations) (presence (not-supplied)))\n"
  in
  F.write_new path (book_txt_of_sexp book_bytes);
  F.write_new (dir ^ "/balance-view.tsv") "wallet\tjpy\n";
  let at_home = C.open_route (C.initial ~config_home:dir (F.load path)) W.Home in
  let bytes_before = F.read path in
  let commands = key ~width_of at_home (`ASCII ' ') in
  require
    (match commands.overlay with C.Commands { page = M.Root; _ } -> true | _ -> false)
    "liquidity-space-opens-commands";
  let analysis_index =
    Option.get (List.find_index (fun (item, _) -> item = M.Group M.Analysis) (M.items M.Root))
  in
  let analysis =
    List.fold_left
      (fun state _ -> key ~width_of state (`ASCII 'j'))
      commands (List.init analysis_index Fun.id)
  in
  let analysis = key ~width_of analysis `Enter in
  require
    (match analysis.overlay with C.Commands { page = M.Analysis; _ } -> true | _ -> false)
    "liquidity-reports-analysis-group";
  let liquidity_index =
    Option.get (List.find_index (fun (item, _) -> item = M.Action M.Liquidity) (M.items M.Analysis))
  in
  let selected =
    List.fold_left
      (fun state _ -> key ~width_of state (`ASCII 'j'))
      analysis
      (List.init liquidity_index Fun.id)
  in
  let liquidity = key ~width_of selected `Enter in
  require (liquidity.workspace.route = W.Liquidity) "liquidity-menu-selects-route";
  require (no_modal liquidity) "liquidity-route-has-no-modal";
  let env = X.screen_env ~config_files:Liquidity_screen.config_files liquidity in
  let screen = liquidity.C.screens.liquidity in
  require (Result.is_error (Liquidity_screen.result env screen)) "liquidity-open-has-no-answer";
  let rows = R.screen ~width_of (80, 24) liquidity in
  require (contains rows "Forecast path: UNKNOWN") "liquidity-forecast-stays-unknown";
  require (contains rows "Known low-water mark: UNKNOWN") "liquidity-low-water-stays-unknown";
  require (Liquidity_screen.run_focused screen) "liquidity-enter-focuses-run";
  let ran = key ~width_of liquidity `Enter in
  let env = X.screen_env ~config_files:Liquidity_screen.config_files ran in
  let snapshot = get (Liquidity_screen.result env ran.C.screens.liquidity) in
  require
    (snapshot.Liquidity_report.measure = "jpy"
    && Z.equal snapshot.Liquidity_report.current_selected (Z.of_int 1000))
    "liquidity-explicit-run-answers-exact-selected-balance";
  let rows = R.screen ~width_of (80, 24) ran in
  require (contains rows "Forecast path: UNKNOWN") "liquidity-run-keeps-forecast-unknown";
  let home = key ~width_of ran `Escape in
  require (home.workspace.route = W.Home) "liquidity-escape-cancels-back-home";
  require
    (String.equal (F.read path) bytes_before)
    "liquidity-flow-leaves-synthetic-book-bytes-unchanged";
  require
    (String.equal (F.read (dir ^ "/balance-view.tsv")) "wallet\tjpy\n")
    "liquidity-flow-never-rewrites-the-selection"

(* Multicurrency Spend: real Commands -> Reports and analysis -> Multicurrency
   Spend selection, an explicit Run over a synthetic multi-Measure book, then a
   cancelled return. Distinct Measures stay separate; nothing is converted. *)
let run_multicurrency ~width_of ~directory =
  let dir = directory ^ "/multicurrency" in
  Unix.mkdir dir 0o700;
  let path = dir ^ "/book.sexp" in
  (* The window seeds from the current calendar month, so the synthetic entries
     must fall inside it. *)
  let today = F.today () in
  let month_start = String.sub today 0 8 ^ "01" in
  let book_bytes =
    Printf.sprintf
      "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
       (measures (measure jpy 0) (measure eur 2))\n\
       (labels (not-supplied)) (approved-loci (provided wallet bank food rent))\n\
       (entries (entry spend-jpy (date %s) (memo (none)) (postings (posting food jpy 1000 (none)) \
       (posting wallet jpy -1000 (none))) (reversal-of (none)) (exchange (none)) (original-amount \
       (none)) (merchant (none))) (entry spend-eur (date %s) (memo (none)) (postings (posting rent \
       eur 5000 (none)) (posting bank eur -5000 (none))) (reversal-of (none)) (exchange (none)) \
       (original-amount (none)) (merchant (none))))\n\
       (plans)\n\
       (support (zero-origin (wallet jpy) (bank jpy) (wallet eur) (bank eur)) (openings) \
       (observations) (presence (not-supplied)))\n"
      month_start month_start
  in
  F.write_new path (book_txt_of_sexp book_bytes);
  F.write_new (dir ^ "/accounting-roles.tsv")
    "food\tExpense\nrent\tExpense\nwallet\tAsset\nbank\tAsset\n";
  let at_home = C.open_route (C.initial ~config_home:dir (F.load path)) W.Home in
  let bytes_before = F.read path in
  let roles_before = F.read (dir ^ "/accounting-roles.tsv") in
  let commands = key ~width_of at_home (`ASCII ' ') in
  require
    (match commands.overlay with C.Commands { page = M.Root; _ } -> true | _ -> false)
    "multicurrency-space-opens-commands";
  let analysis_index =
    Option.get (List.find_index (fun (item, _) -> item = M.Group M.Analysis) (M.items M.Root))
  in
  let analysis =
    List.fold_left
      (fun state _ -> key ~width_of state (`ASCII 'j'))
      commands (List.init analysis_index Fun.id)
  in
  let analysis = key ~width_of analysis `Enter in
  require
    (match analysis.overlay with C.Commands { page = M.Analysis; _ } -> true | _ -> false)
    "multicurrency-reports-analysis-group";
  let spend_index =
    Option.get
      (List.find_index
         (fun (item, _) -> item = M.Action M.Multicurrency_spend)
         (M.items M.Analysis))
  in
  let selected =
    List.fold_left
      (fun state _ -> key ~width_of state (`ASCII 'j'))
      analysis (List.init spend_index Fun.id)
  in
  let spend = key ~width_of selected `Enter in
  require (spend.workspace.route = W.Multicurrency_spend) "multicurrency-menu-selects-route";
  require (no_modal spend) "multicurrency-route-has-no-modal";
  let screen = spend.C.screens.multicurrency_spend in
  require
    (Result.is_error (Multicurrency_spend_screen.result screen))
    "multicurrency-open-has-no-answer";
  let rows = R.screen ~width_of (80, 24) spend in
  require (contains rows "Multicurrency Spend") "multicurrency-heading-visible";
  require
    (contains rows "No exchange rate, conversion or home-currency total is inferred.")
    "multicurrency-no-conversion-disclaimer";
  let ran = key ~width_of spend `Enter in
  let snapshot = get (Multicurrency_spend_screen.result ran.C.screens.multicurrency_spend) in
  let total measure totals =
    match
      List.find_opt (fun (row : Multicurrency_spend_report.total) -> row.measure = measure) totals
    with
    | Some row -> row.quanta
    | None -> Z.zero
  in
  require
    (Z.equal (total "jpy" snapshot.Multicurrency_spend_report.ordinary_expense) (Z.of_int 1000)
    && Z.equal (total "eur" snapshot.Multicurrency_spend_report.ordinary_expense) (Z.of_int 5000))
    "multicurrency-explicit-run-answers-each-Measure-exactly";
  let rows = R.screen ~width_of (80, 24) ran in
  require
    (contains rows "1,000 jpy" && contains rows "50.00 eur")
    "multicurrency-each-Measure-painted-at-its-own-scale";
  let home = key ~width_of ran `Escape in
  require (home.workspace.route = W.Home) "multicurrency-escape-cancels-back-home";
  require
    (String.equal (F.read path) bytes_before)
    "multicurrency-flow-leaves-synthetic-book-bytes-unchanged";
  require
    (String.equal (F.read (dir ^ "/accounting-roles.tsv")) roles_before)
    "multicurrency-flow-never-rewrites-the-roles"

let run ~width_of ~directory (back_home : C.state) =
  let contains rows needle =
    List.exists (fun (_, text) -> Base.String.is_substring text ~substring:needle) rows
  in
  (* Test Income & Expense report with Cycle / Month / Year / All-Time *)
  let ie_ctl = C.open_route back_home W.Income_expense in
  require (ie_ctl.workspace.route = W.Income_expense) "route-income-expense";
  let wide_ie = R.screen ~width_of (120, 30) ie_ctl in
  require
    (contains wide_ie "Income & Expense" && contains wide_ie "Expense")
    "income-expense-wide-visible";
  let ie_cycle = key ~width_of ie_ctl (`ASCII '2') in
  let wide_cycle = R.screen ~width_of (120, 30) ie_cycle in
  require
    (contains wide_cycle "Cycle" || contains wide_cycle "Income & Expense")
    "income-expense-2-cycle";
  let ie_prev_cycle = key ~width_of ie_cycle (`ASCII '3') in
  let wide_prev_cycle = R.screen ~width_of (120, 30) ie_prev_cycle in
  require
    (contains wide_prev_cycle "Cycle" || contains wide_prev_cycle "Period")
    "income-expense-3-prev-cycle";
  let ie_year = key ~width_of ie_prev_cycle (`ASCII '4') in
  let wide_year = R.screen ~width_of (120, 30) ie_year in
  require (contains wide_year "Year") "income-expense-4-year";
  let ie_all = key ~width_of ie_year (`ASCII '5') in
  let wide_all = R.screen ~width_of (120, 30) ie_all in
  require (contains wide_all "All Time") "income-expense-5-all-time";
  let ie_shifted = key ~width_of ie_ctl (`ASCII '[') in
  let wide_shifted = R.screen ~width_of (120, 30) ie_shifted in
  require (contains wide_shifted "Income & Expense") "income-expense-bracket-shift";
  (* Formulas and keys live in the [?] overlay, not a permanent pane. *)
  let ie_help = key ~width_of ie_ctl (`ASCII '?') in
  (match visible_form ie_help with
  | Some f ->
      require (Ui_form.id f = "report_help") "income-expense-help-opens";
      require
        (List.exists
           (fun line -> Base.String.is_substring line ~substring:"Accounting Formula")
           f.Ui_form.summary)
        "income-expense-help-shows-formula"
  | None -> failwith "expected income-expense help overlay");
  let ie_help_closed = key ~width_of ie_help `Escape in
  require
    (no_modal ie_help_closed && ie_help_closed.workspace.route = W.Income_expense)
    "income-expense-help-escapes";
  (* The default window is the configured cycle; `c` compares the last windows. *)
  require
    (Income_expense_screen.preset ie_ctl.C.screens.income_expense = Income_expense_report.Cycle)
    "income-expense-defaults-to-cycle";
  let ie_compare = key ~width_of ie_ctl (`ASCII 'c') in
  require
    (Income_expense_screen.comparing ie_compare.C.screens.income_expense)
    "income-expense-c-compares";
  require
    (contains (R.screen ~width_of (140, 40) ie_compare) "Compare:")
    "income-expense-compare-visible";
  let ie_single = key ~width_of ie_compare (`ASCII 'c') in
  require
    (not (Income_expense_screen.comparing ie_single.C.screens.income_expense))
    "income-expense-c-returns-to-summary";
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
  require
    (contains (R.screen ~width_of (120, 36) flow_cyc) "Cycle"
    || contains (R.screen ~width_of (120, 36) flow_cyc) "Transactions Flow")
    "flow-preset-cycle";
  (* 3: Previous Cycle *)
  let flow_prev_cyc = key ~width_of flow_ctl (`ASCII '3') in
  require
    (contains (R.screen ~width_of (120, 36) flow_prev_cyc) "Cycle"
    || contains (R.screen ~width_of (120, 36) flow_prev_cyc) "Period")
    "flow-preset-prev-cycle";
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
  require
    (contains (R.screen ~width_of (120, 36) flow_shift_fwd) "Month of 2026-10")
    "flow-shift-fwd";
  (* Selection navigation with j/k *)
  let flow_j = key ~width_of flow_all (`ASCII 'j') in
  require
    (Transactions_flow_screen.selected_row flow_j.C.screens.transactions_flow >= 0)
    "flow-j-moves-row";
  let flow_k = key ~width_of flow_j (`ASCII 'k') in
  require
    (Transactions_flow_screen.selected_row flow_k.C.screens.transactions_flow = 0)
    "flow-k-moves-row-back";
  (* Detail toggle with Tab *)
  let flow_tab = key ~width_of flow_all `Tab in
  require
    (Transactions_flow_screen.detail_focused flow_tab.C.screens.transactions_flow)
    "flow-tab-toggles-detail";
  let flow_tab_back = key ~width_of flow_tab `Tab in
  require
    (not (Transactions_flow_screen.detail_focused flow_tab_back.C.screens.transactions_flow))
    "flow-tab-toggles-calendar";
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
  F.write_new (sf_dir ^ "/boundary-presets.tsv") "household\t2026-10-01\t2026-11-01\n";
  let sf_ctl = C.open_route (C.initial ~config_home:sf_dir (F.load sf_path)) W.Stock_flow in
  let bv_path = sf_dir ^ "/balance-view.tsv" in
  let configure bytes =
    if Sys.file_exists bv_path then Unix.unlink bv_path;
    F.write_new bv_path bytes
  in
  let refused () =
    require (Result.is_error (stock_flow_result sf_ctl)) "sf-invalid-evidence-refuses";
    let printed = key ~width_of sf_ctl (`ASCII 'p') in
    require
      (no_modal printed && printed.message <> "")
      "sf-invalid-evidence-cannot-print-numeric-report"
  in
  refused ();
  List.iter
    (fun bytes ->
      configure bytes;
      refused ())
    [
      "food\tjpy\nbad-row\n";
      "food\tjpy\nwallet\teur\n";
      "food\tjpy\nfood\tjpy\n";
      "";
    ];
  (* A valid selection with no support at all is listed, not refused; the wallet
     observation is exact but undated, so it is not in this list. *)
  configure "bank\tjpy\n";
  (match stock_flow_result sf_ctl with
  | Ok unsupported ->
      require
        (unsupported.Stock_flow_report.coordinates = []
        && unsupported.Stock_flow_report.unsupported <> [])
        "sf-lists-unsupported-coordinates"
  | Error why -> failwith ("stock-flow refused a listing: " ^ why));
  configure "food\tjpy\n";
  require
    (Stock_flow_screen.preset sf_ctl.C.screens.stock_flow = Income_expense_report.Cycle)
    "sf-defaults-to-the-configured-cycle";
  let report = get (stock_flow_result sf_ctl) in
  require
    (report.measure = "jpy"
    && Z.equal report.reconstructed_start Z.zero
    && Z.equal report.reconstructed_end Z.zero)
    "sf-explicit-zero-origin-boundaries";
  (* One full-width body: End clamps to the last row and the next step works. *)
  let tiny = (80, 14) in
  ignore (R.screen ~width_of:String.length tiny sf_ctl);
  let sf_end = key ~dimensions:tiny ~width_of:String.length sf_ctl `End in
  let sf_end_scroll = Stock_flow_screen.scroll sf_end.C.screens.stock_flow in
  require (sf_end_scroll > 0) "sf-end-scrolls";
  let sf_step_back = key ~dimensions:tiny ~width_of:String.length sf_end (`ASCII 'k') in
  require
    (Stock_flow_screen.scroll sf_step_back.C.screens.stock_flow = sf_end_scroll - 1)
    "sf-k-after-end-steps-back";
  let sf_help = key ~width_of sf_ctl (`ASCII '?') in
  require (visible_form_id sf_help = Some "report_help") "sf-help-opens";
  let sf_help_closed = key ~width_of sf_help `Escape in
  require (no_modal sf_help_closed) "sf-help-escapes";
  let sf_back_home = key ~width_of sf_help_closed (`ASCII 'q') in
  require (sf_back_home.workspace.route = W.Home) "sf-report-return-home";
  run_liquidity ~width_of ~directory;
  run_multicurrency ~width_of ~directory;
  ()
