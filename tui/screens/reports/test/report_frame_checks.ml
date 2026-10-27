(* Shared report frame and the I&E / Transactions Flow screens on it: one scroll
   model with a real clamp, [?] help instead of a permanent pane, active-Measure
   filtering, shared money formatting and a line-per-line print preview. *)

module B = Bakhlo_household.Daily_book
module IE = Income_expense_screen
module TF = Transactions_flow_screen
module Frame = Report_frame
module IncExp = Income_expense_report
module Roles = Locus_roles

let get = function Ok x -> x | Error why -> failwith why
let require condition why = if not condition then failwith why
let z = Z.of_int

let fixture =
  "BOOK\t1\n\
   MEASURE\tjpy\t0\n\
   MEASURE\teur\t2\n\
   LOCUS\tsalary\tsalary\t\n\
   LOCUS\tfood\tfood\t\n\
   LOCUS\ttravel\ttravel\t\n\
   TX\tpay\t2026-10-02\n\
   EFFECT\tsalary\tjpy\t-123456\n\
   EFFECT\ttravel\tjpy\t123456\n\
   ENDTX\n\
   TX\tmeal\t2026-10-03\n\
   EFFECT\tfood\tjpy\t1234\n\
   EFFECT\ttravel\tjpy\t-1234\n\
   ENDTX\n\
   ZERO-ORIGIN\ttravel\tjpy\n\
   ZERO-ORIGIN\tsalary\tjpy\n\
   ZERO-ORIGIN\tfood\tjpy\n\
   END\n"

let roles = [ ("salary", Roles.Income); ("food", Roles.Expense); ("travel", Roles.Asset) ]
let book = Bakhlo_household.Daily_txt.book fixture
let boundaries = "household\t2026-10-01\t2026-11-01\n"

let env =
  Screen.env_for_checks ~accounting_roles:roles
    ~config:(fun name ->
      if name = Report_period.boundary_file then Ok (Some boundaries)
      else Error ("undeclared " ^ name))
    ~book ~measure:"jpy" ~today:"2026-10-15" ()

let geometry width height : Screen.geometry =
  {
    screen = (width, height);
    body = (width, height - 3);
    content = (width, height - 4);
    width_of = String.length;
  }

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
  require
    (not (Frame.handle ~count:200 ~capacity frame (`Key (`ASCII 'x', [])) = Some frame))
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
  require (Option.map Ui_form.id (IE.form ie_help) = Some "report_help") "ie-help-form-id";
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
          (fun line ->
            String.contains line '\n' || Base.String.is_substring line ~substring:"\\u000a")
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
    "BOOK\t1\n\
     MEASURE\tjpy\t0\n\
     LOCUS\tsalary\tsalary\t\n\
     LOCUS\tfood\tfood\t\n\
     LOCUS\trent\trent\t\n\
     LOCUS\ttravel\ttravel\t\n\
     TX\tsep-pay\t2026-09-02\n\
     EFFECT\tsalary\tjpy\t-1000\n\
     EFFECT\ttravel\tjpy\t1000\n\
     ENDTX\n\
     TX\tsep-food\t2026-09-03\n\
     EFFECT\tfood\tjpy\t400\n\
     EFFECT\ttravel\tjpy\t-400\n\
     ENDTX\n\
     TX\tsep-rent\t2026-09-04\n\
     EFFECT\trent\tjpy\t100\n\
     EFFECT\ttravel\tjpy\t-100\n\
     ENDTX\n\
     TX\tsep-late\t2026-09-20\n\
     EFFECT\trent\tjpy\t50000\n\
     EFFECT\ttravel\tjpy\t-50000\n\
     ENDTX\n\
     TX\toct-pay\t2026-10-02\n\
     EFFECT\tsalary\tjpy\t-123456\n\
     EFFECT\ttravel\tjpy\t123456\n\
     ENDTX\n\
     TX\toct-food\t2026-10-03\n\
     EFFECT\tfood\tjpy\t9000\n\
     EFFECT\ttravel\tjpy\t-9000\n\
     ENDTX\n\
     TX\toct-rent\t2026-10-04\n\
     EFFECT\trent\tjpy\t1000\n\
     EFFECT\ttravel\tjpy\t-1000\n\
     ENDTX\n\
     ZERO-ORIGIN\ttravel\tjpy\n\
     END\n"
  in
  let window_roles =
    [
      ("salary", Roles.Income);
      ("food", Roles.Expense);
      ("rent", Roles.Expense);
      ("travel", Roles.Asset);
    ]
  in
  let window_book = Bakhlo_household.Daily_txt.book window_fixture in
  let month offset =
    get
      (IncExp.resolve_period ~today:"2026-10-15" ~preset:IncExp.Month ~offset
         ~boundary_presets_text:(Some boundaries))
  in
  let current = IncExp.compute_report ~book:window_book ~roles:window_roles ~period:(month 0) in
  let previous = IncExp.compute_report ~book:window_book ~roles:window_roles ~period:(month (-1)) in
  (* The current month is 15 days old; the previous month is compared up to the
     same elapsed day, not to its whole length. *)
  let elapsed, total = IncExp.elapsed ~today:"2026-10-15" (month 0) in
  require ((elapsed, total) = (15, 31)) "ie2-elapsed-days";
  let previous_partial =
    IncExp.compute_report ~book:window_book ~roles:window_roles
      ~period:(IncExp.truncate_to_days previous.period elapsed)
  in
  require
    (Z.equal
       (List.find
          (fun (ms : IncExp.measure_summary) -> ms.measure = "jpy")
          previous_partial.summaries)
         .IncExp.total_expense
       (Z.of_int 500))
    "ie2-partial-previous-excludes-late-entry";
  require
    (Z.equal
       (List.find (fun (ms : IncExp.measure_summary) -> ms.measure = "jpy") previous.summaries)
         .IncExp.total_expense
       (Z.of_int 50500))
    "ie2-whole-previous-keeps-late-entry";
  let summary =
    List.map snd
      (IncExp.render_report_lines ~width:80 ~width_of:String.length ~book:window_book
         ~report:current ~today:"2026-10-15"
         ~comparison:
           (Some
              {
                IncExp.window = previous.period;
                same_age = previous_partial;
                whole = Some previous;
              }))
  in
  require (contains summary "2026-10-01 .. 2026-10-31  ·  day 15 of 31") "ie2-partial-label";
  require
    (contains summary "vs  2026-09-01 .. 2026-09-30  (first 15 days)")
    "ie2-partial-previous-label";

  (* A window that has not started is an empty window, not "day 0 of M". *)
  let future = month 1 in
  let future_elapsed, future_total = IncExp.elapsed ~today:"2026-10-15" future in
  require (future_elapsed = 0 && future_total > 0) "ie2-future-window-is-unstarted";
  let future_report = IncExp.compute_report ~book:window_book ~roles:window_roles ~period:future in
  let empty_previous =
    IncExp.compute_report ~book:window_book ~roles:window_roles
      ~period:(IncExp.truncate_to_days previous.period 0)
  in
  require
    (List.for_all
       (fun (ms : IncExp.measure_summary) ->
         Z.equal ms.total_income Z.zero && Z.equal ms.total_expense Z.zero)
       empty_previous.summaries)
    "ie2-empty-previous-has-no-flow";
  let future_summary =
    List.map snd
      (IncExp.render_report_lines ~width:80 ~width_of:String.length ~book:window_book
         ~report:future_report ~today:"2026-10-15"
         ~comparison:
           (Some { IncExp.window = previous.period; same_age = empty_previous; whole = None }))
  in
  require (contains future_summary "not started") "ie2-future-window-labelled";
  require (not (contains future_summary "day 0 of")) "ie2-no-day-zero-label";
  require (not (contains future_summary "(whole ")) "ie2-no-whole-previous-when-unstarted";
  require (contains summary "vs 1,000  +122,456") "ie2-income-difference-exact";
  require (contains summary "vs 500  +9,500") "ie2-expense-difference-exact";
  require (contains summary "vs 500  +112,956") "ie2-result-difference-exact";
  require (contains summary "(whole 50,500)") "ie2-whole-previous-secondary";
  require (contains summary "Scheduled 0 jpy") "ie2-scheduled-split-shown";
  let food_line =
    List.find_index (fun line -> Base.String.is_substring line ~substring:" food ") summary
  in
  let rent_line =
    List.find_index (fun line -> Base.String.is_substring line ~substring:" rent ") summary
  in
  require
    (match (food_line, rent_line) with Some food, Some rent -> food < rent | _ -> false)
    "ie2-breakdown-sorted-by-amount";
  require (contains summary "█") "ie2-bar-present-at-width";
  let narrow_summary =
    List.map snd
      (IncExp.render_report_lines ~width:30 ~width_of:String.length ~book:window_book
         ~report:current ~today:"2026-10-15"
         ~comparison:
           (Some { IncExp.window = previous.period; same_age = previous; whole = Some previous }))
  in
  require (not (contains narrow_summary "█")) "ie2-bar-dropped-before-amount";
  require (contains narrow_summary "9,000") "ie2-amount-kept-at-narrow-width";
  require (contains narrow_summary "Δ") "ie2-difference-kept-at-narrow-width";

  (* Under each Locus bar, the compared window's amount and bar on one scale; a
     Locus spent on only in the compared window follows at this window's zero. *)
  let pair_fixture =
    "BOOK\t1\n\
     MEASURE\tjpy\t0\n\
     LOCUS\tfood\tfood\t\n\
     LOCUS\tbooks\tbooks\t\n\
     LOCUS\twallet\twallet\t\n\
     TX\tsep-books\t2026-09-03\n\
     EFFECT\tbooks\tjpy\t700\n\
     EFFECT\twallet\tjpy\t-700\n\
     ENDTX\n\
     TX\toct-food\t2026-10-03\n\
     EFFECT\tfood\tjpy\t350\n\
     EFFECT\twallet\tjpy\t-350\n\
     ENDTX\n\
     ZERO-ORIGIN\twallet\tjpy\n\
     END\n"
  in
  let pair_book = Bakhlo_household.Daily_txt.book pair_fixture in
  let pair_roles = [ ("food", Roles.Expense); ("books", Roles.Expense); ("wallet", Roles.Asset) ] in
  let pair_report period =
    IncExp.compute_report ~book:pair_book ~roles:pair_roles ~period:(month period)
  in
  let sep = pair_report (-1) in
  let paired =
    List.map snd
      (IncExp.render_report_lines ~width:100 ~width_of:String.length ~book:pair_book
         ~report:(pair_report 0) ~today:"2026-10-31"
         ~comparison:(Some { IncExp.window = sep.period; same_age = sep; whole = Some sep }))
  in
  let index_of needle =
    List.find_index (fun line -> Base.String.is_substring line ~substring:needle) paired
  in
  let line_at i = Option.value ~default:"" (Option.bind i (List.nth_opt paired)) in
  let food = index_of " food " and books = index_of " books " in
  let next i = Option.map (fun i -> i + 1) i in
  require (contains paired "█ this  ░ compared") "ie2-pair-legend";
  require
    (Base.String.is_substring (line_at food) ~substring:"350"
    && Base.String.is_substring (line_at food) ~substring:"█")
    "ie2-pair-this-window-bar";
  require
    (Base.String.is_substring (line_at (next food)) ~substring:" 0"
    && not (Base.String.is_substring (line_at (next food)) ~substring:"░"))
    "ie2-pair-compared-exact-zero";
  require
    (match (food, books) with Some f, Some b -> f < b | _ -> false)
    "ie2-pair-only-compared-follows";
  require
    (Base.String.is_substring (line_at books) ~substring:" 0"
    && Base.String.is_substring (line_at (next books)) ~substring:"700"
    && Base.String.is_substring (line_at (next books)) ~substring:"░")
    "ie2-pair-only-compared-bar";
  (* One scale: the compared 700 is the longest bar, this window's 350 half of it. *)
  let cells glyph line =
    List.length (Base.String.substr_index_all line ~may_overlap:false ~pattern:glyph)
  in
  let food_cells = cells "█" (line_at food) and books_cells = cells "░" (line_at (next books)) in
  require (books_cells > 0 && abs ((2 * food_cells) - books_cells) <= 1) "ie2-pair-one-scale";
  let unpaired =
    List.map snd
      (IncExp.render_report_lines ~width:100 ~width_of:String.length ~book:pair_book
         ~report:(pair_report 0) ~today:"2026-10-31" ~comparison:None)
  in
  require (not (contains unpaired "░")) "ie2-no-comparison-no-compared-bars";
  require (contains unpaired "no such earlier window") "ie2-no-comparison-named";

  (* Compare columns fit the width and keep exact amounts. *)
  let compare_wide =
    List.map snd
      (IncExp.render_compare_lines ~width:160 ~width_of:String.length ~book:window_book
         ~today:"2026-10-15"
         ~reports:[ (month (-1), previous); (month 0, current) ])
  in
  require (contains compare_wide "Compare: 2 window(s)") "ie2-compare-two-windows";
  require (contains compare_wide "09-01") "ie2-compare-previous-column";
  require (contains compare_wide "(partial)") "ie2-compare-current-marked-partial";
  require (contains compare_wide "top expense Loci") "ie2-compare-loci-rows";
  require (contains compare_wide "123,456") "ie2-compare-income-exact";
  require (contains compare_wide "1,000") "ie2-compare-previous-income";
  let compare_narrow =
    List.map snd
      (IncExp.render_compare_lines ~width:40 ~width_of:String.length ~book:window_book
         ~today:"2026-10-15"
         ~reports:[ (month (-1), previous); (month 0, current) ])
  in
  require (contains compare_narrow "Compare: 1 window(s)") "ie2-compare-narrow-fits-one";
  require (not (contains compare_narrow "09-01")) "ie2-compare-narrow-drops-oldest";
  require (contains compare_narrow "123,456") "ie2-compare-narrow-keeps-amount";
  print_endline
    "PASS: shared report frame scroll clamp and position, I&E active measures / money / help / \
     print lines, Transactions Flow selection clamp and narrow-vs-wide detail."
