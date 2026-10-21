(* Shared report frame and the I&E / Transactions Flow screens on it: one scroll
   model with a real clamp, [?] help instead of a permanent pane, active-Measure
   filtering, shared money formatting and a line-per-line print preview. *)

module B = Bakhlo_sexp.Daily_book
module IE = Income_expense_screen
module TF = Transactions_flow_screen
module Frame = Report_frame
module IncExp = Income_expense_report
module Roles = Locus_roles

let get = function Ok x -> x | Error why -> failwith why
let require condition why = if not condition then failwith why
let z = Z.of_int

let fixture =
  "(bakhlo-daily 1) (scope corrected-entries explicit-plans)\n\
   (measures (measure jpy 0) (measure eur 2))\n\
   (labels (not-supplied))\n\
   (approved-loci (provided salary food travel))\n\
   (entries\n\
   \ (entry pay (date 2026-10-02) (memo (none)) (postings (posting salary jpy -123456 \
   (none)) (posting travel jpy 123456 (none))) (reversal-of (none)))\n\
   \ (entry meal (date 2026-10-03) (memo (none)) (postings (posting food jpy 1234 \
   (none)) (posting travel jpy -1234 (none))) (reversal-of (none))))\n\
   (plans)\n\
   (support (zero-origin (travel jpy) (salary jpy) (food jpy)) (openings) (observations) \
   (presence (not-supplied)))\n"

let roles = [ ("salary", Roles.Income); ("food", Roles.Expense); ("travel", Roles.Asset) ]
let book = get (B.of_string fixture)

let boundaries = "household\t2026-10-01\t2026-11-01\n"

let env =
  Screen.env_for_checks ~accounting_roles:roles
    ~config:(fun name ->
      if name = Report_period.boundary_file then Ok (Some boundaries)
      else Error ("undeclared " ^ name))
    ~book ~measure:"jpy" ~today:"2026-10-15" ()

let geometry width height : Screen.geometry =
  { screen = (width, height); body = (width, height - 3); content = (width, height - 4); width_of = String.length }

let paint view = List.map snd (Lazy.force view.Screen.rows)
let contains rows text =
  List.exists (fun line -> Base.String.is_substring line ~substring:text) rows

let key owner key =
  let owner, _ = IE.handle env (geometry 160 45) owner (`Key (key, [])) in
  owner

let self_check () =
  (* 1. Shared scroll model: immutable, clamped to the real content, so End does
     not poison the next step key. *)
  let frame_geometry = geometry 120 24 in
  let capacity = Frame.capacity frame_geometry in
  let step frame input =
    match Frame.handle ~count:200 ~capacity frame input with Some next -> next | None -> frame
  in
  let frame = step Frame.create (`Key (`End, [])) in
  require (frame.Frame.scroll = 200 - capacity) "frame-end-clamps-to-last";
  let frame = step frame (`Key (`ASCII 'k', [])) in
  require (frame.Frame.scroll = 199 - capacity) "frame-k-after-end-steps-one";
  require
    (Frame.position ~count:200 ~capacity frame = Printf.sprintf "%d–199 / 200" (200 - capacity))
    "frame-position-names-the-visible-window";
  let frame = step frame (`Key (`ASCII 'g', [])) in
  require (frame.Frame.scroll = 0) "frame-g-returns-to-top";
  let frame = step frame (`Key (`Page `Down, [])) in
  require (frame.Frame.scroll = capacity) "frame-page-down-steps-a-page";
  require (not (Frame.handle ~count:200 ~capacity frame (`Key (`ASCII 'x', [])) = Some frame))
    "frame-ignores-unrelated-keys";

  (* 2. Income & Expense: only Measures with activity, shared money format. *)
  let ie = IE.create () in
  let rows = paint (IE.view env (geometry 160 45) ie) in
  require (contains rows "1,234 jpy") "ie-money-uses-thousands-separators";
  require (contains rows "No activity in this window: eur") "ie-names-inactive-measures";
  require (not (contains rows "Currency: eur")) "ie-hides-inactive-measure-blocks";
  require (not (contains rows "Report Details & Formulas")) "ie-has-no-permanent-help-pane";

  (* 3. Income & Expense: [?] opens the shared help overlay and Esc closes it. *)
  let ie_help = key ie (`ASCII '?') in
  require (IE.modal ie_help) "ie-help-is-modal";
  require
    (Option.map Ui_form.id (IE.form ie_help) = Some "report_help")
    "ie-help-form-id";
  let ie_help_closed, _ = IE.handle env (geometry 160 45) ie_help (`Key (`Escape, [])) in
  require (not (IE.modal ie_help_closed)) "ie-help-escapes";
  (* 4. Income & Expense: scrolling works and End then k steps back by one.
     The body is painted first, exactly as the terminal paints before a key. *)
  let ie_small = geometry 160 12 in
  ignore (paint (IE.view env ie_small ie));
  let press owner input = fst (IE.handle env ie_small owner input) in
  let ie_after_end = press ie (`Key (`End, [])) in
  let scroll_end = IE.scroll ie_after_end in
  require (scroll_end > 0) "ie-end-scrolls";
  let ie_back = press ie_after_end (`Key (`ASCII 'k', [])) in
  require (IE.scroll ie_back = scroll_end - 1) "ie-k-after-end-steps-back";

  (* 5. Print preview has one entry per line: no embedded control characters. *)
  let period : IncExp.period =
    {
      preset = IncExp.Month;
      start_day = "2026-10-01";
      end_exclusive = "2026-11-01";
      label = "October";
    }
  in
  let report = IncExp.compute_report ~book ~roles ~period in
  let printed = IncExp.print_summary ~book ~report in
  require
    (not
       (List.exists
          (fun line -> String.contains line '\n' || Base.String.is_substring line ~substring:"\\u000a")
          printed))
    "ie-print-lines-are-real-lines";
  require (List.exists (fun line -> line = "") printed) "ie-print-separates-measures";
  require (List.exists (fun line -> line = "Currency: jpy") printed) "ie-print-currency-line";
  require
    (not (List.exists (fun line -> line = "Currency: eur") printed))
    "ie-print-hides-inactive-measures";

  (* 6. Transactions Flow: selection clamps, End then k steps back. *)
  let tf = TF.create () in
  let narrow = geometry 80 24 in
  ignore (paint (TF.view env narrow tf));
  let tf_end, _ = TF.handle env narrow tf (`Key (`End, [])) in
  let last = TF.selected_row tf_end in
  require (last > 0) "tf-end-selects-last-row";
  let tf_back, _ = TF.handle env narrow tf_end (`Key (`ASCII 'k', [])) in
  require (TF.selected_row tf_back = last - 1) "tf-k-after-end-steps-back";
  require (List.length (paint (TF.view env narrow tf)) > 0) "tf-narrow-renders";

  (* 7. Detail pane only from 100 columns; Enter opens it full width below. *)
  require
    (not (contains (paint (TF.view env narrow tf)) "Flow Detail & Transactions"))
    "tf-narrow-hides-detail-pane";
  let wide = geometry 120 36 in
  require
    (contains (paint (TF.view env wide tf)) "Flow Detail & Transactions")
    "tf-wide-shows-detail-pane";
  let tf_detail, _ = TF.handle env narrow tf (`Key (`Enter, [])) in
  require (TF.detail_focused tf_detail) "tf-enter-opens-detail";
  require
    (contains (paint (TF.view env narrow tf_detail)) "Coordinate Flow Details")
    "tf-narrow-detail-is-full-width";
  let tf_table, _ = TF.handle env narrow tf_detail (`Key (`Escape, [])) in
  require (not (TF.detail_focused tf_table)) "tf-escape-returns-to-table";

  (* 8. Cycle summary: previous-window difference, amount order, bars and the
     side-by-side compare columns. *)
  let window_fixture =
    "(bakhlo-daily 1) (scope corrected-entries explicit-plans)\n\
     (measures (measure jpy 0))\n\
     (labels (not-supplied))\n\
     (approved-loci (provided salary food rent travel))\n\
     (entries\n\
     \ (entry sep-pay (date 2026-09-02) (memo (none)) (postings (posting salary jpy -1000 \
     (none)) (posting travel jpy 1000 (none))) (reversal-of (none)))\n\
     \ (entry sep-food (date 2026-09-03) (memo (none)) (postings (posting food jpy 400 \
     (none)) (posting travel jpy -400 (none))) (reversal-of (none)))\n\
     \ (entry sep-rent (date 2026-09-04) (memo (none)) (postings (posting rent jpy 100 \
     (none)) (posting travel jpy -100 (none))) (reversal-of (none)))\n\
     \ (entry oct-pay (date 2026-10-02) (memo (none)) (postings (posting salary jpy -123456 \
     (none)) (posting travel jpy 123456 (none))) (reversal-of (none)))\n\
     \ (entry oct-food (date 2026-10-03) (memo (none)) (postings (posting food jpy 9000 \
     (none)) (posting travel jpy -9000 (none))) (reversal-of (none)))\n\
     \ (entry oct-rent (date 2026-10-04) (memo (none)) (postings (posting rent jpy 1000 \
     (none)) (posting travel jpy -1000 (none))) (reversal-of (none))))\n\
     (plans)\n\
     (support (zero-origin (travel jpy)) (openings) (observations) (presence (not-supplied)))\n"
  in
  let window_roles =
    [ ("salary", Roles.Income); ("food", Roles.Expense); ("rent", Roles.Expense);
      ("travel", Roles.Asset) ]
  in
  let window_book = get (B.of_string window_fixture) in
  let month offset =
    get
      (IncExp.resolve_period ~today:"2026-10-15" ~preset:IncExp.Month ~offset
         ~boundary_presets_text:(Some boundaries))
  in
  let current =
    IncExp.compute_report ~book:window_book ~roles:window_roles ~period:(month 0)
  in
  let previous =
    IncExp.compute_report ~book:window_book ~roles:window_roles ~period:(month (-1))
  in
  let summary =
    List.map snd
      (IncExp.render_report_lines ~width:80 ~width_of:String.length ~book:window_book
         ~report:current ~previous:(Some previous))
  in
  require (contains summary "Previous: Month of 2026-09") "ie2-previous-labelled";
  require (contains summary "prev 1,000  +122,456") "ie2-income-difference-exact";
  require (contains summary "prev 500  +9,500") "ie2-expense-difference-exact";
  require (contains summary "prev 500  +112,956") "ie2-result-difference-exact";
  require (contains summary "Scheduled 0 jpy") "ie2-scheduled-split-shown";
  let food_line =
    List.find_index (fun line -> Base.String.is_substring line ~substring:"food") summary
  in
  let rent_line =
    List.find_index (fun line -> Base.String.is_substring line ~substring:"rent") summary
  in
  require
    (match (food_line, rent_line) with Some food, Some rent -> food < rent | _ -> false)
    "ie2-breakdown-sorted-by-amount";
  require (contains summary "█") "ie2-bar-present-at-width";
  let narrow_summary =
    List.map snd
      (IncExp.render_report_lines ~width:30 ~width_of:String.length ~book:window_book
         ~report:current ~previous:(Some previous))
  in
  require (not (contains narrow_summary "█")) "ie2-bar-dropped-before-amount";
  require (contains narrow_summary "9,000") "ie2-amount-kept-at-narrow-width";
  require (contains narrow_summary "Δ") "ie2-difference-kept-at-narrow-width";

  (* Compare columns fit the width and keep exact amounts. *)
  let compare_wide =
    List.map snd
      (IncExp.render_compare_lines ~width:160 ~width_of:String.length ~book:window_book
         ~reports:[ (month (-1), previous); (month 0, current) ])
  in
  require (contains compare_wide "Compare: 2 window(s)") "ie2-compare-two-windows";
  require (contains compare_wide "2026-09") "ie2-compare-previous-column";
  require (contains compare_wide "top expense Loci") "ie2-compare-loci-rows";
  require (contains compare_wide "123,456") "ie2-compare-income-exact";
  require (contains compare_wide "1,000") "ie2-compare-previous-income";
  let compare_narrow =
    List.map snd
      (IncExp.render_compare_lines ~width:40 ~width_of:String.length ~book:window_book
         ~reports:[ (month (-1), previous); (month 0, current) ])
  in
  require (contains compare_narrow "Compare: 1 window(s)") "ie2-compare-narrow-fits-one";
  require (not (contains compare_narrow "2026-09")) "ie2-compare-narrow-drops-oldest";
  require (contains compare_narrow "123,456") "ie2-compare-narrow-keeps-amount";
  print_endline
    "PASS: shared report frame scroll clamp and position, I&E active measures / money / help / \
     print lines, Transactions Flow selection clamp and narrow-vs-wide detail."
