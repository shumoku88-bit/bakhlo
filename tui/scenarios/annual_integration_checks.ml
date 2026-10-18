(* Synthetic controller integration checks; see docs/RECONSTRUCTION_TEST_MAP.ja.md. *)
open Interaction_check_fixture

let annual_lifecycle_checks ~width_of ~directory () =
  let directory = directory ^ "/annual-lifecycle" in
  Unix.mkdir directory 0o700;
  let year = int_of_string (String.sub (F.today ()) 0 4) in
  let prior_year = year - 1 in
  let path y = directory ^ "/" ^ Bakhlo_sexp.Annual_scope.file_name y in
  let prior = get (B.of_string (Printf.sprintf
      "(bakhlo-daily 3) (scope corrected-entries explicit-plans)
       (measures (measure jpy 0)) (labels (not-supplied))
       (approved-loci (provided wallet food))
       (entries)
       (plans (plan overdue (date %04d-12-20) (measure jpy)
         (changes (wallet -30) (food 30)) (paid-by (none)) (cancelled-on (none))))
       (support (zero-origin (food jpy)) (openings)
         (observations (observation (reflected) (quantities (wallet jpy 1000))))
         (presence (not-supplied)))" prior_year)) in
  F.write_new (path prior_year) (B.to_string prior);
  let base = C.initial ~config_home:directory (F.load ~annual_year:prior_year (path prior_year)) in
  let bytes = F.read (path prior_year) in
  let review = X.open_command base M.Annual_rollover in
  let kept = key ~width_of review `Enter in
  require (not (Sys.file_exists (path year)) && no_modal kept)
    "annual-keep-created-year";
  let selected = key ~width_of review (`Arrow `Right) in
  let narrow = key ~width_of ~dimensions:(48,14) selected `Enter in
  require (not (Sys.file_exists (path year))) "annual-hidden-review-created";
  let kept_after_resize = key ~width_of narrow `Enter in
  require (not (Sys.file_exists (path year)) && no_modal kept_after_resize)
    "annual-resize-kept-dangerous-choice";
  let created = key ~width_of selected `Enter in
  require (created.session.F.annual_year = Some year && F.read (path prior_year) = bytes)
    "annual-rollover-not-created-or-prior-mutated";
  let cold = C.initial ~config_home:directory (F.load (path year)) in
  require ((C.open_route cold W.Balances).workspace.route = W.Balances)
    "annual-qualified-balances-blocked";
  F.write_new (directory ^ "/daily-pace.tsv") "wallet\tjpy\n";
  F.write_new (directory ^ "/boundary-presets.tsv")
    (Printf.sprintf "explicit-cycle\t%04d-12-15\t%04d-12-15\n" prior_year year);
  let pace, _, _ = get (current_pace_result cold) in
  require (Z.equal pace.B.eligible_pool (Z.of_int 1000)
           && Z.equal pace.automatic_deductions (Z.of_int 30)
           && Z.equal pace.available_through_end (Z.of_int 970))
    "annual-pace-lost-prior-evidence-or-overdue-plan";
  let scheduled = C.open_route cold W.Scheduled in
  let paying = C.pay_selected scheduled |> C.submit in
  let paid = key ~width_of paying `Enter in
  let reopened = F.load (path year) in
  require (List.for_all (fun (p:B.plan) -> p.paid_by <> None) (B.plans reopened.book)
           && B.entry_count reopened.book = 1 && F.read (path prior_year) = bytes)
    "annual-overdue-plan-not-paid-exactly-once";
  require (not paid.record_visible) "annual-payment-draft-not-cleared";
  let current = C.initial ~config_home:directory reopened in
  let period = get (Report_period.checked (X.screen_env ~config_files:[ Report_period.boundary_file ] current) Income_expense_report.All_time 0) in
  require (period.start_day = Printf.sprintf "%04d-01-01" prior_year
           && period.end_exclusive = Printf.sprintf "%04d-01-01" (year + 1))
    "annual-selected-history-boundaries";
  let stale_bytes = bytes ^ "\n" in
  let oc = open_out_bin (path prior_year) in
  output_string oc stale_bytes; close_out oc;
  require (C.annual_unavailable current <> None
           && (C.open_route current W.Balances).workspace.route = W.Home)
    "annual-stale-provenance-still-answers";
  print_endline "PASS: annual explicit rollover Keep/tiny gates, cold balances/Pace, overdue payment and stale provenance."


let route_checks ~width_of ~directory (home : C.state) =
  (* An annual book is not a qualified carry-forward. Its normal Actual and
     Scheduled tools remain available, but current-quantity projections must
     not be displayed as household balances. *)
  let annual_path = directory ^ "/2027.sexp" in
  let annual_session =
    F.create_annual_empty ~year:2027 ~path:annual_path ~measure:"jpy" ~scale:0
  in
  let annual = C.initial ~config_home:directory annual_session in
  require
    (String.starts_with ~prefix:"2027-" annual.workspace.calendar.selected_day)
    "annual-calendar-started-outside-selected-year";
  let shows state needle =
    List.exists
      (fun (_, content) -> Base.String.is_substring content ~substring:needle)
      (R.screen ~width_of (100, 28) state)
  in
  require
    (List.map (fun (b : F.annual_book_summary) ->
       (b.year, b.entries, b.open_plans))
       (F.list_annual_books ~directory) = [ (2027, 0, 0) ])
    "annual-list-did-not-discover-one-valid-book";
  let corrupt_annual = directory ^ "/2028.sexp" in
  F.write_new corrupt_annual "not a Daily S-expression";
  require
    (try ignore (F.list_annual_books ~directory); false
     with F.Refused _ -> true)
    "annual-list-silently-skipped-corrupt-book";
  require
    (B.entry_count (F.load ~annual_year:2027 annual_path).book = 0)
    "annual-list-touched-healthy-year";
  require
    (match current_pace_result annual with Error _ -> true | Ok _ -> false)
    "annual-pace-must-not-publish-unqualified-quantity";
  List.iter
    (fun route ->
      let blocked = C.open_route annual route in
      require
        (blocked.workspace.route = W.Home && blocked.message <> "")
        "annual-derived-report-route-not-blocked";
      let forced = { annual with workspace = W.enter annual.workspace route } in
      require
        (shows forced "No zero opening or carried balance is inferred.")
        "annual-derived-report-could-display-partial-balance")
    [ W.Balances; W.Daily_pace; W.Stock_flow; W.Income_expense;
      W.Transactions_flow ];
  require ((C.open_route annual W.Actual).workspace.route = W.Actual)
    "annual-actual-browsing-blocked";
  require ((C.open_route annual W.Scheduled).workspace.route = W.Scheduled)
    "annual-scheduled-browsing-blocked";
  require ((C.open_route home W.Balances).workspace.route = W.Balances)
    "ordinary-book-balances-regressed";
  ()
