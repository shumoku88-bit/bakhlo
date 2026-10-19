(* Synthetic controller integration checks; see docs/RECONSTRUCTION_TEST_MAP.ja.md. *)
open Interaction_check_fixture

(* UI-33: Daily Pace / Trend must refuse a missing, malformed, empty, ambiguous
   or unsupported pool/period instead of inferring a zero balance or a period. *)
let daily_pace_trend_fail_closed_checks ~width_of ~directory () =
  let directory = directory ^ "/daily-pace-fail-closed" in
  Unix.mkdir directory 0o700;
  let path = directory ^ "/book.sexp" in
  F.create_copy ~source:Interaction_check_fixture.example_book ~target:path;
  let home = C.initial ~config_home:directory (F.load path) in
  let pool_path = directory ^ "/daily-pace.tsv" in
  let windows_path = directory ^ "/boundary-presets.tsv" in
  let replace path bytes =
    if Sys.file_exists path then Unix.unlink path;
    F.write_new path bytes
  in
  let remove path = if Sys.file_exists path then Unix.unlink path in
  let today = F.today () in
  let stop = get (Cal.shift_days today 7) in
  let view () = C.open_route { home with session = F.load path } W.Daily_pace in
  (* Painted rows carry frame glyphs and padding; drop them and clip each row to
     its pane so wrapped text still reads as one contiguous string. *)
  let clean text =
    let out = Buffer.create (String.length text) in
    let rec loop index =
      if index >= String.length text then ()
      else if
        index + 3 <= String.length text
        && (let glyph = String.sub text index 3 in
            Base.String.equal glyph "\xe2\x94\x82" || Base.String.equal glyph "\xe2\x80\xa6")
      then loop (index + 3)
      else (
        (match text.[index] with
        | ' ' | '\t' | '\r' | '\n' -> ()
        | char -> Buffer.add_char out char);
        loop (index + 1))
    in
    loop 0;
    Buffer.contents out
  in
  let shows ?(pane = `Left) ~width_of (width, height) state needle =
    let left_width = if width < 80 then width else max 36 (min 58 (width * 52 / 100)) in
    let room = match pane with `Left -> left_width | `Right -> width in
    let rows = R.screen ~width_of (width, height) state in
    let text =
      List.map
        (fun (_, row) ->
          clean (if pane = `Left then Daily_overlays.clip_text ~width_of room row else row))
        rows
      |> String.concat ""
    in
    Base.String.is_substring text ~substring:(clean needle)
  in
  let screen_has ~width_of dimensions state needle message =
    require (shows ~pane:`Right ~width_of dimensions state needle) message
  in
  let modal_form state =
    match visible_form state with
    | Some form -> form
    | None -> raise (F.Refused "expected-modal-form")
  in
  let modal_summary state = String.concat "\n" (modal_form state).Ui_form.summary in
  let submit_what_if state amount =
    let state =
      with_visible_form state (Ui_form.set_focused (Ui_form.set_text (modal_form state) "amount" amount) 1)
    in
    match H.handle ~width_of state (`Key (`Enter, [])) with
    | Some next -> next
    | None -> raise (F.Refused "what-if-submit-exited")
  in
  (* 1. Missing daily-pace.tsv: no pool is not an empty pool. *)
  remove pool_path;
  remove windows_path;
  let missing = view () in
  List.iter
    (fun ((width, height) as dimensions) ->
      let where = Printf.sprintf "%dx%d" width height in
      (* LOAM: an empty Trend owns the whole workspace, not a left pane. *)
      require (shows ~pane:`Right ~width_of dimensions missing "Daily Pace unavailable:")
        ("daily-pace-missing-pool-header-" ^ where);
      (* Below one wrapped reason row the context says unavailable and points to `i`. *)
      require (height >= 10 || shows ~pane:`Right ~width_of dimensions missing "unavailable(i:cause)")
        ("daily-pace-missing-pool-cause-hint-" ^ where);
      require (height < 10 || shows ~pane:`Right ~width_of dimensions missing
         "Daily Pace pool not configured (daily-pace.tsv missing).")
        ("daily-pace-missing-pool-reason-" ^ where);
      require
        (not (shows ~pane:`Right ~width_of dimensions missing "Daily Pace:"))
        ("daily-pace-missing-pool-calculated-" ^ where);
      require
        (not (shows ~pane:`Right ~width_of dimensions missing "jpy/day"))
        ("daily-pace-missing-pool-plot-" ^ where))
    [ (80, 24); (48, 14); (32, 9) ];
  let what_if = key ~width_of missing (`ASCII 'w') in
  require (Ui_form.id (modal_form what_if) = "daily_pace_what_if") "daily-pace-what-if-modal-id";
  require
    (Base.String.is_substring (modal_summary what_if) ~substring:"Daily pace unavailable")
    "daily-pace-missing-what-if-summary";
  require
    (Base.String.is_substring (modal_summary what_if)
       ~substring:"Daily Pace pool not configured (daily-pace.tsv missing).")
    "daily-pace-missing-what-if-reason";
  let refused_what_if = submit_what_if what_if "1000" in
  require
    (Ui_form.notice (modal_form refused_what_if)
     = "Current pace unavailable: Daily Pace pool not configured (daily-pace.tsv missing).")
    "daily-pace-missing-what-if-notice";
  require
    (no_modal (key ~width_of refused_what_if `Escape))
    "daily-pace-missing-what-if-closes";
  (* 2. Malformed pool: a mismatched Measure is refused, never partially read. *)
  replace pool_path "wallet\tusd\n";
  remove windows_path;
  let malformed_pool = view () in
  screen_has ~width_of (80, 24) malformed_pool "Daily Pace unavailable:"
    "daily-pace-malformed-pool-header";
  screen_has ~width_of (80, 24) malformed_pool "Malformed daily-pace.tsv or mismatched Measure"
    "daily-pace-malformed-pool-reason";
  (* 3. Comment-only pool: configured but empty, and still not a calculation. *)
  replace pool_path "# comment\n";
  let empty_pool = view () in
  screen_has ~width_of (80, 24) empty_pool "Daily Pace unavailable:" "daily-pace-empty-pool-header";
  screen_has ~width_of (80, 24) empty_pool "Daily Pace pool is empty." "daily-pace-empty-pool-reason";
  (* 4. Unknown pool balance: refuse the exact coordinate, never assume zero. *)
  replace pool_path "bank\tjpy\n";
  replace windows_path ("cycle\t" ^ today ^ "\t" ^ stop ^ "\n");
  let unknown_balance = view () in
  screen_has ~width_of (80, 24) unknown_balance "Daily Pace unavailable:"
    "daily-pace-unknown-balance-header";
  screen_has ~width_of (80, 24) unknown_balance "Pool locus balance support is unknown: bank jpy"
    "daily-pace-unknown-balance-reason";
  let unknown_what_if = key ~width_of unknown_balance (`ASCII 'w') in
  require
    (Base.String.is_substring (modal_summary unknown_what_if)
       ~substring:"Pool locus balance support is unknown: bank jpy")
    "daily-pace-unknown-balance-what-if-summary";
  let unknown_refused = submit_what_if unknown_what_if "1000" in
  require
    (Ui_form.notice (modal_form unknown_refused)
     = "Current pace unavailable: Pool locus balance support is unknown: bank jpy")
    "daily-pace-unknown-balance-what-if-notice";
  require
    (no_modal (key ~width_of unknown_refused `Escape))
    "daily-pace-unknown-balance-what-if-closes";
  (* 5. Valid pool, missing boundary-presets.tsv: every period refuses. *)
  replace pool_path "wallet\tjpy\n";
  remove windows_path;
  let no_period = view () in
  screen_has ~width_of (80, 24) no_period "Daily Pace unavailable:" "daily-pace-missing-period-header";
  screen_has ~width_of (80, 24) no_period "Period not configured (boundary-presets.tsv missing)."
    "daily-pace-missing-period-reason";
  List.iter
    (fun preset_key ->
      let pressed = key ~width_of no_period (`ASCII preset_key) in
      let where = String.make 1 preset_key in
      require (pressed.workspace.route = W.Daily_pace) ("daily-pace-missing-period-route-" ^ where);
      require (Result.is_error (current_pace_result pressed))
        ("daily-pace-missing-period-refused-" ^ where);
      require (not (shows ~pane:`Right ~width_of (32, 9) pressed "jpy/day"))
        ("daily-pace-missing-period-no-invented-pace-" ^ where))
    [ '1'; '2'; '3'; '4' ];
  (* 6. Malformed boundary-presets.tsv. *)
  replace windows_path "broken\tnot-a-date\n";
  let malformed_windows = view () in
  screen_has ~width_of (80, 24) malformed_windows "Daily Pace unavailable:"
    "daily-pace-malformed-period-header";
  screen_has ~width_of (80, 24) malformed_windows "Malformed boundary-presets.tsv; no period was inferred."
    "daily-pace-malformed-period-reason";
  (* 7. Two presets contain today: ambiguous, not first-match. *)
  replace windows_path (Printf.sprintf "p1\t%s\t%s\np2\t%s\t%s\n" today stop today stop);
  let ambiguous = view () in
  screen_has ~width_of (80, 24) ambiguous "Daily Pace unavailable:" "daily-pace-ambiguous-header";
  screen_has ~width_of (80, 24) ambiguous
    "Multiple boundary presets contain today; selection is ambiguous."
    "daily-pace-ambiguous-reason";
  (* 8. No preset contains today. *)
  replace windows_path "old\t2020-01-01\t2020-02-01\n";
  let stale_period = view () in
  screen_has ~width_of (80, 24) stale_period "Daily Pace unavailable:" "daily-pace-stale-period-header";
  screen_has ~width_of (80, 24) stale_period "No explicit boundary preset contains today."
    "daily-pace-stale-period-reason";
  (* 9. Explicit pool and period: bounded calculation and interaction. *)
  replace windows_path ("cycle\t" ^ today ^ "\t" ^ stop ^ "\n");
  replace pool_path "wallet\tjpy\n";
  let pace = view () in
  let pace_detail = key ~width_of pace (`ASCII 'i') in
  require (Pace.detail_focused pace_detail.C.screens.pace) "daily-pace-i-focuses-detail";
  List.iter
    (fun ((width, height) as dimensions) ->
      List.iter
        (fun state ->
          let rows = R.screen ~width_of dimensions state in
          require (List.length rows <= height
            && List.for_all (fun (_, row) -> width_of row <= width) rows)
            "daily-pace-chart-detail-resize-geometry")
        [ pace; pace_detail ])
    [ (120, 36); (80, 24); (48, 14); (32, 9) ];
  let preset_key char preset =
    let pressed = key ~width_of pace (`ASCII char) in
    require (pressed.workspace.route = W.Daily_pace)
      ("daily-pace-preset-route-" ^ String.make 1 char);
    require ((Pace.trend pressed.C.screens.pace).Trend.preset = preset) ("daily-pace-preset-" ^ String.make 1 char)
  in
  preset_key '1' Trend.Ten_days;
  preset_key '2' Trend.Thirty_days;
  preset_key '3' Trend.Month;
  preset_key '4' Trend.Cycle;
  let dotted = key ~width_of pace (`ASCII 'v') in
  require ((Pace.trend dotted.C.screens.pace).Trend.graph_style = Trend.Dots) "daily-pace-graph-dots";
  require
    ((Pace.trend (key ~width_of dotted (`ASCII 'v')).C.screens.pace).Trend.graph_style = Trend.Line)
    "daily-pace-graph-line";
  let escaped_detail = key ~width_of pace_detail `Escape in
  require
    (not (Pace.detail_focused escaped_detail.C.screens.pace) && escaped_detail.workspace.route = W.Daily_pace)
    "daily-pace-esc-returns-calendar";
  let quit_detail = key ~width_of pace_detail (`ASCII 'q') in
  require
    (not (Pace.detail_focused quit_detail.C.screens.pace) && quit_detail.workspace.route = W.Daily_pace)
    "daily-pace-q-returns-calendar";
  let simulated = submit_what_if (key ~width_of pace (`ASCII 'w')) "2000" in
  require
    (Base.String.is_substring (Ui_form.notice (modal_form simulated)) ~substring:"Simulated pace:")
    "daily-pace-what-if-simulated-pace";
  require
    (Base.String.is_substring (Ui_form.notice (modal_form simulated))
       ~substring:"Remaining available:")
    "daily-pace-what-if-remaining-available";
  let closed_what_if = key ~width_of simulated `Escape in
  require (no_modal closed_what_if) "daily-pace-what-if-closes";
  require
    ((key ~width_of closed_what_if (`ASCII 'q')).workspace.route = W.Home)
    "daily-pace-q-returns-home";
  print_endline
    "PASS: UI-33 Daily Pace / Trend fail-closed and bounded verification (unknown balances, \
     corrupted configs, ambiguous periods, multi-dimensions) passed."

(* Today's sample uses Current; past-day reconstruction is kept separate. *)
let daily_pace_today_sample_checks () =
  let book =
    get
      (B.of_string
         ("(bakhlo-daily 1)\n" ^ "(scope corrected-entries explicit-plans)\n"
        ^ "(measures (measure \"jpy\" 0))\n"
        ^ "(labels (provided))\n"
        ^ "(approved-loci (provided \"wallet\" \"food\"))\n" ^ "(entries)\n" ^ "(plans\n"
        ^ "  (plan \"unpaid-yesterday\" (date \"2026-06-14\") (measure \"jpy\")\n"
        ^ "    (changes (\"wallet\" -500) (\"food\" 500)) (paid-by (none))))\n" ^ "(support\n"
        ^ "  (zero-origin (\"food\" \"jpy\"))\n" ^ "  (openings)\n" ^ "  (observations\n"
        ^ "    (observation (reflected) (quantities (\"wallet\" \"jpy\" 1000))))\n"
        ^ "  (presence (not-supplied)))\n"))
  in
  let today = "2026-06-15" and stop = "2026-06-16" in
  let coord locus : D.Effect_coordinate.t =
    {
      D.Effect_coordinate.locus = C.get_id (D.Identifier.Locus.of_string locus);
      measure = C.get_id (D.Identifier.Measure.of_string "jpy");
    }
  in
  let pool = [ coord "wallet" ] in
  let boundary = Some ("cycle\t" ^ today ^ "\t" ^ stop ^ "\n") in
  let pace =
    get (B.daily_pace book ~measure:"jpy" ~pool ~observed_at:today ~end_exclusive:stop)
  in
  require
    (Z.equal pace.B.eligible_pool (Z.of_int 1000)
    && Z.equal pace.B.automatic_deductions (Z.of_int 500)
    && Z.equal pace.B.available_through_end (Z.of_int 500)
    && pace.B.remaining_days = 1 && Z.equal pace.B.daily_pace_quanta (Z.of_int 500))
    "daily-pace-today-core500";
  let _, _, samples =
    get
      (Trend.compute_samples ~book ~measure:"jpy" ~pool:[ "wallet" ]
         ~boundary_presets_text:boundary ~today ~preset:Trend.Cycle)
  in
  require
    (match samples with
    | [ sample ] ->
        sample.Trend.day = today && sample.Trend.end_exclusive = stop
        && Z.equal sample.Trend.pool_balance pace.B.eligible_pool
        && Z.equal sample.Trend.deductions pace.B.automatic_deductions
        && Z.equal sample.Trend.available_through_end pace.B.available_through_end
        && sample.Trend.remaining_days = pace.B.remaining_days
        && sample.Trend.pace_quanta = Some pace.B.daily_pace_quanta
    | _ -> false)
    "daily-pace-today-matches-core";
  let history_boundary = Some ("cycle\t2026-06-01\t" ^ stop ^ "\n") in
  let _, _, history =
    get
      (Trend.compute_samples ~book ~measure:"jpy" ~pool:[ "wallet" ]
         ~boundary_presets_text:history_boundary ~today ~preset:Trend.Ten_days)
  in
  let yesterday = List.find (fun (sample : Trend.sample) -> sample.day = "2026-06-14") history in
  (* No zero-origin for wallet: past pace stays None, activity preserved, never fabricated. *)
  require (yesterday.Trend.pace_quanta = None) "daily-pace-guarded-past-none";
  require (yesterday.Trend.unavailable <> None) "daily-pace-guarded-past-cause";
  require (yesterday.Trend.activity <> None) "daily-pace-guarded-past-activity";
  (* Known zero-origin for every pool locus: past reconstruction is supported. *)
  let supported_book =
    get
      (B.of_string
         ("(bakhlo-daily 1)\n" ^ "(scope corrected-entries explicit-plans)\n"
        ^ "(measures (measure \"jpy\" 0))\n" ^ "(labels (provided))\n"
        ^ "(approved-loci (provided \"wallet\" \"food\"))\n"
        ^ "(entries (entry seed (date 2026-06-01) (memo (none))"
        ^ " (postings (posting wallet jpy 1000 (none)) (posting food jpy -1000 (none)))"
        ^ " (reversal-of (none))))\n(plans\n"
        ^ "  (plan \"unpaid-yesterday\" (date \"2026-06-14\") (measure \"jpy\")\n"
        ^ "    (changes (\"wallet\" -500) (\"food\" 500)) (paid-by (none))))\n" ^ "(support\n"
        ^ "  (zero-origin (\"wallet\" \"jpy\") (\"food\" \"jpy\"))\n" ^ "  (openings)\n"
        ^ "  (observations)\n"
        ^ "  (presence (not-supplied)))\n"))
  in
  let _, _, supported_history =
    get
      (Trend.compute_samples ~book:supported_book ~measure:"jpy" ~pool:[ "wallet" ]
         ~boundary_presets_text:history_boundary ~today ~preset:Trend.Ten_days)
  in
  let supported_yesterday =
    List.find (fun (sample : Trend.sample) -> sample.day = "2026-06-14") supported_history
  in
  require
    (supported_yesterday.Trend.pace_quanta = Some (Z.of_int 250)
     && Z.equal supported_yesterday.Trend.pool_balance (Z.of_int 1000)
     && Z.equal supported_yesterday.Trend.deductions (Z.of_int 500)
     && supported_yesterday.Trend.unavailable = None)
    "daily-pace-zero-origin-past-supported";
  (* A plan due exactly on the exclusive end is outside the period. *)
  let at_end : B.plan =
    {
      id = "due-at-end";
      day = stop;
      measure = "jpy";
      changes = [ ("wallet", Z.of_int (-700)); ("food", Z.of_int 700) ];
      paid_by = None;
      cancelled_on = None;
    }
  in
  let later_book = get (B.put_plan book ~replace:false at_end) in
  let later_pace =
    get (B.daily_pace later_book ~measure:"jpy" ~pool ~observed_at:today ~end_exclusive:stop)
  in
  require
    (Z.equal later_pace.B.automatic_deductions (Z.of_int 500))
    "daily-pace-end-exclusive-daily-pace";
  let _, _, later_samples =
    get
      (Trend.compute_samples ~book:later_book ~measure:"jpy" ~pool:[ "wallet" ]
         ~boundary_presets_text:boundary ~today ~preset:Trend.Cycle)
  in
  require
    (match later_samples with [ s ] -> Z.equal s.Trend.deductions (Z.of_int 500) | _ -> false)
    "daily-pace-end-exclusive-sample";
  (* A deficit flows through as a negative pace, never clamped to zero. *)
  let extra : B.plan =
    {
      id = "due-today-extra";
      day = today;
      measure = "jpy";
      changes = [ ("wallet", Z.of_int (-1000)); ("food", Z.of_int 1000) ];
      paid_by = None;
      cancelled_on = None;
    }
  in
  let deficit_book = get (B.put_plan book ~replace:false extra) in
  let deficit_pace =
    get (B.daily_pace deficit_book ~measure:"jpy" ~pool ~observed_at:today ~end_exclusive:stop)
  in
  require
    (Z.equal deficit_pace.B.available_through_end (Z.of_int (-500)))
    "daily-pace-deficit-available";
  require
    (Z.equal deficit_pace.B.daily_pace_quanta (Z.of_int (-500)))
    "daily-pace-deficit-pace";
  let _, _, deficit_samples =
    get
      (Trend.compute_samples ~book:deficit_book ~measure:"jpy" ~pool:[ "wallet" ]
         ~boundary_presets_text:boundary ~today ~preset:Trend.Cycle)
  in
  require
    (match deficit_samples with
    | [ s ] ->
        Z.equal s.Trend.available_through_end (Z.of_int (-500))
        && (match s.Trend.pace_quanta with Some q -> Z.equal q (Z.of_int (-500)) | None -> false)
    | _ -> false)
    "daily-pace-deficit-sample";
  print_endline
    "PASS: Daily Pace today sample equals Daily_book.daily_pace (synthetic overdue plan, \
     exclusive end, deficit)."

(* Activity classification is source-agnostic: discretionary vs scheduled-settled
   vs reserved, intra-pool netting, reversal pairing and measure isolation. *)
let daily_pace_activity_checks () =
  let text =
    "(bakhlo-daily 1) (scope corrected-entries explicit-plans)\n\
     (measures (measure jpy 0) (measure eur 2)) (labels (not-supplied))\n\
     (approved-loci (provided wallet food bank))\n\
     (entries\n\
     (entry seed (date 2026-10-01) (memo (none))\n\
     (postings (posting wallet jpy 10000 (none)) (posting food jpy -10000 (none)))\n\
     (reversal-of (none)))\n\
     (entry e_eur (date 2026-10-11) (memo (none))\n\
     (postings (posting wallet eur -999 (none)) (posting food eur 999 (none)))\n\
     (reversal-of (none)))\n\
     (entry e_disc (date 2026-10-12) (memo (none))\n\
     (postings (posting wallet jpy -500 (none)) (posting food jpy 500 (none)))\n\
     (reversal-of (none)))\n\
     (entry e_pay (date 2026-10-13) (memo (none))\n\
     (postings (posting wallet jpy -300 (none)) (posting food jpy 300 (none)))\n\
     (reversal-of (none)))\n\
     (entry e_trans (date 2026-10-14) (memo (none))\n\
     (postings (posting wallet jpy -200 (none)) (posting bank jpy 200 (none)))\n\
     (reversal-of (none)))\n\
     (entry e_t (date 2026-10-15) (memo (none))\n\
     (postings (posting wallet jpy -100 (none)) (posting food jpy 100 (none)))\n\
     (reversal-of (none)))\n\
     (entry e_r (date 2026-10-15) (memo (none))\n\
     (postings (posting wallet jpy 100 (none)) (posting food jpy -100 (none)))\n\
     (reversal-of (some e_t)))\n\
     (entry e_orig (date 2026-10-16) (memo (none))\n\
     (postings (posting wallet jpy -400 (none)) (posting food jpy 400 (none)))\n\
     (reversal-of (none)))\n\
     (entry e_rev (date 2026-10-17) (memo (none))\n\
     (postings (posting wallet jpy 400 (none)) (posting food jpy -400 (none)))\n\
     (reversal-of (some e_orig))))\n\
     (plans\n\
     (plan p_eur (date 2026-10-11) (measure eur) (changes (wallet -999) (food 999)) (paid-by (some e_eur)))\n\
     (plan p_sched (date 2026-10-13) (measure jpy) (changes (wallet -300) (food 300)) (paid-by (some e_pay)))\n\
     (plan p_orig (date 2026-10-16) (measure jpy) (changes (wallet -400) (food 400)) (paid-by (some e_orig))))\n\
     (support (zero-origin (wallet jpy) (food jpy) (bank jpy)) (openings)\n\
     (observations)\n\
     (presence (not-supplied)))"
  in
  let book = get (B.of_string text) in
  let boundary = Some "cycle\t2026-10-10\t2026-10-28\n" in
  let _, _, samples =
    get
      (Trend.compute_samples ~book ~measure:"jpy" ~pool:[ "wallet"; "bank" ]
         ~boundary_presets_text:boundary ~today:"2026-10-18" ~preset:Trend.Cycle)
  in
  let sample day = List.find (fun (s : Trend.sample) -> s.Trend.day = day) samples in
  let activity day =
    match (sample day).Trend.activity with
    | Some a -> a
    | None -> raise (F.Refused ("pace-activity-missing-" ^ day))
  in
  let is_zero (a : Trend.day_activity) =
    Z.equal a.Trend.discretionary_outflow Z.zero
    && Z.equal a.Trend.discretionary_inflow Z.zero
    && Z.equal a.Trend.scheduled_settled_outflow Z.zero
    && Z.equal a.Trend.scheduled_settled_inflow Z.zero
    && Z.equal a.Trend.scheduled_reserved_outflow Z.zero
  in
  let eur = activity "2026-10-11" in
  require (is_zero eur) "pace-activity-eur-plan-ignored-in-jpy";
  let disc = activity "2026-10-12" in
  require
    (Z.equal disc.Trend.discretionary_outflow (Z.of_int 500)
    && Z.equal disc.Trend.scheduled_settled_outflow Z.zero
    && Z.equal disc.Trend.scheduled_reserved_outflow Z.zero)
    "pace-activity-discretionary-outflow";
  let paid = activity "2026-10-13" in
  require
    (Z.equal paid.Trend.scheduled_settled_outflow (Z.of_int 300)
    && Z.equal paid.Trend.scheduled_reserved_outflow (Z.of_int 300)
    && Z.equal paid.Trend.discretionary_outflow Z.zero)
    "pace-activity-paid-plan-scheduled";
  require (is_zero (activity "2026-10-14")) "pace-activity-intra-pool-cancels";
  require (is_zero (activity "2026-10-15")) "pace-activity-same-day-reversal-ignored";
  let rev = activity "2026-10-17" in
  require
    (Z.equal rev.Trend.scheduled_settled_inflow (Z.of_int 400)
    && Z.equal rev.Trend.discretionary_inflow Z.zero
    && Z.equal rev.Trend.discretionary_outflow Z.zero)
    "pace-activity-crossday-reversal-scheduled";
  let rendered_activity day =
    Trend.render_detail ~width:80 ~width_of:String.length ~book ~measure:"jpy"
      ~sample:(Some (sample day)) ~prev_sample:None ~today:"2026-10-18"
      ~preset:Trend.Cycle
    |> List.map snd |> String.concat "\n"
  in
  let reversing_day = rendered_activity "2026-10-17" in
  require
    (Base.String.is_substring reversing_day
       ~substring:"Scheduled-linked inflow/reversal: +400 jpy"
     && not (Base.String.is_substring reversing_day ~substring:"Unscheduled inflow:"))
    "pace-detail-scheduled-reversal-not-discretionary-receipt";
  let paying_day = rendered_activity "2026-10-13" in
  require
    (Base.String.is_substring paying_day ~substring:"Settled: 300 jpy (as planned)"
     && not (Base.String.is_substring paying_day ~substring:"Scheduled-linked inflow/reversal:"))
    "pace-detail-outflow-has-no-false-scheduled-inflow";
  let unknown_pace_day = { (sample "2026-10-17") with
    Trend.pace_quanta = None; unavailable = Some "Historical pace unavailable" } in
  let unknown_detail =
    Trend.render_detail ~width:80 ~width_of:String.length ~book ~measure:"jpy"
      ~sample:(Some unknown_pace_day) ~prev_sample:None ~today:"2026-10-18"
      ~preset:Trend.Cycle |> List.map snd |> String.concat "\n"
  in
  require
    (Base.String.is_substring unknown_detail ~substring:"Daily Pace: unavailable"
     && Base.String.is_substring unknown_detail
          ~substring:"Scheduled-linked inflow/reversal: +400 jpy")
    "pace-detail-independent-known-activity-when-pace-unknown";
  let d12 = sample "2026-10-12" and d13 = sample "2026-10-13" in
  require
    (d12.Trend.pace_quanta <> None && d13.Trend.pace_quanta <> None
    && d12.Trend.pace_quanta <> d13.Trend.pace_quanta)
    "pace-activity-spent-moves-pace";
  let change = get (Trend.compare_change ~prev:d12 ~current:d13) in
  require
    (Z.equal change.Trend.change_per_day (Z.of_int 36)
     && Z.equal change.time_passage_effect (Z.of_int 36)
     && Z.equal change.free_money_effect Z.zero
     && Z.equal change.pool_balance_change (Z.of_int (-300))
     && Z.equal change.protection_release (Z.of_int 300)
     && Z.equal change.free_through_end_change Z.zero)
    "pace-change-exact-integer-decomposition";
  let d14 = sample "2026-10-14" in
  require (Result.is_error (Trend.compare_change ~prev:d12 ~current:d14)) "pace-compare-skipped-day-refused";
  let reset = { d13 with Trend.end_exclusive = "2099-01-01" } in
  require (Result.is_error (Trend.compare_change ~prev:d12 ~current:reset)) "pace-compare-cycle-reset-refused";
  require (Z.equal d12.deductions (Z.of_int 700)
    && Z.equal d13.deductions (Z.of_int 400)
    && Z.equal (sample "2026-10-16").deductions Z.zero
    && Z.equal (sample "2026-10-17").deductions Z.zero)
    "pace-history-payment-date-closes-protection-and-reversal-does-not-reopen";
  let plan id amount : B.plan =
    { id; day = "2026-10-01"; measure = "jpy";
      changes = ["wallet", Z.of_int (-amount); "food", Z.of_int amount];
      paid_by = None; cancelled_on = None } in
  let with_overdue = get (B.put_plan book ~replace:false (plan "overdue" 50)) in
  let with_cancelled = get (B.put_plan with_overdue ~replace:false (plan "cancelled" 999))
    |> fun book -> get (B.cancel_plan book ~id:"cancelled" ~day:"2026-10-17") in
  let resolve ?(boundary = boundary) ?(preset = Trend.Cycle) book =
    let _, _, values = get (Trend.compute_samples ~book ~measure:"jpy" ~pool:["wallet";"bank"]
      ~boundary_presets_text:boundary ~today:"2026-10-18" ~preset) in
    values in
  let find day values = List.find (fun (s : Trend.sample) -> s.day = day) values in
  let protected = resolve with_cancelled in
  require (Z.equal (find "2026-10-12" protected).deductions (Z.of_int 750)
    && Z.equal (find "2026-10-17" protected).deductions (Z.of_int 50))
    "pace-history-overdue-counts-and-cancelled-is-restated-closed";
  let payment = List.find (fun (e : B.entry) -> e.id = "e_pay") (B.entries book) in
  let future = get (B.put_entry book ~replace:false
    { payment with id = "future"; day = "2026-10-25" } ~plan:None) in
  require (Z.equal (find "2026-10-12" (resolve future)).pool_balance (Z.of_int 9500))
    "pace-zero-origin-history-forwards-only-through-point-date";
  let extended = Some "cycle\t2026-10-01\t2026-10-10\t2026-10-28\n" in
  let crossing = resolve ~boundary:extended ~preset:Trend.Thirty_days book in
  let before = find "2026-10-09" crossing and after = find "2026-10-10" crossing in
  require (before.end_exclusive = "2026-10-10" && before.remaining_days = 1
    && Z.equal before.deductions Z.zero && before.pace_quanta = Some (Z.of_int 10000)
    && after.end_exclusive = "2026-10-28" && after.remaining_days = 18)
    "pace-history-each-day-uses-its-explicit-cycle-end";
  let absent = find "2026-09-30" crossing in
  require (absent.pace_quanta = None && absent.unavailable <> None && absent.end_exclusive = "")
    "pace-history-outside-explicit-boundaries-is-unknown";
  let previous = resolve ~boundary:extended ~preset:Trend.Previous_cycle book in
  require (List.length previous = 9
    && (find "2026-10-09" previous).pace_quanta = before.pace_quanta)
    "pace-previous-cycle-uses-same-restated-current-truth";
  print_endline "PASS: Daily Pace activity classification, currency isolation and guarded change (synthetic)."

(* UI-33B: the pace cursor moves within the actually rendered range. After a
   preset or End the stored index rests past the last row, so stepping must
   clamp to the real last sample first: the visible Selected date moves to
   the previous day, not just the stored number. Head/tail stay clamped. *)
let daily_pace_selection_clamp_checks ~width_of ~directory () =
  let directory = directory ^ "/daily-pace-selection" in
  Unix.mkdir directory 0o700;
  let path = directory ^ "/book.sexp" in
  F.create_copy ~source:Interaction_check_fixture.example_book ~target:path;
  let home = C.initial ~config_home:directory (F.load path) in
  let today = F.today () in
  let stop = get (Cal.shift_days today 7) in
  let yesterday = get (Cal.shift_days today (-1)) in
  let boundary_text = "cycle\t" ^ today ^ "\t" ^ stop ^ "\n" in
  F.write_new (directory ^ "/daily-pace.tsv") "wallet\tjpy\n";
  F.write_new (directory ^ "/boundary-presets.tsv") boundary_text;
  let view () = C.open_route { home with session = F.load path } W.Daily_pace in
  let entry = view () in
  let measure = entry.workspace.measure in
  let resolve preset =
    let _, through_day, samples =
      get
        (Trend.compute_samples ~book:home.C.session.book ~measure ~pool:[ "wallet" ]
           ~boundary_presets_text:(Some boundary_text) ~today ~preset)
    in
    (through_day, samples)
  in
  let _, ten_samples = resolve Trend.Ten_days in
  let through_day, samples = resolve Trend.Thirty_days in
  let count = List.length samples in
  let day_at index = (List.nth samples index).Trend.day in
  (* Semantic selection: clamp the stored index to the resolved range, then
     read the date off the sample — never match decorative wording. *)
  let selected_date samples state =
    let last = List.length samples - 1 in
    (List.nth samples (max 0 (min last ((Pace.trend state.C.screens.pace).Trend.selected_index)))).Trend.day
  in
  require (through_day = today && day_at (count - 1) = today) "daily-pace-sel-anchor-tail";
  require (day_at (count - 2) = yesterday) "daily-pace-sel-anchor-prev";
  (* Entry rests on the Ten_days tail: today; h steps to yesterday, l returns. *)
  require (selected_date ten_samples entry = today) "daily-pace-sel-entry-today";
  let context = (Pace.view (X.pace_env entry)
      (X.screen_geometry ~dimensions:(120, 36) ~width_of entry) entry.C.screens.pace).Screen.subtitle in
  require (match context with Screen.Text text ->
    Base.String.is_substring text ~substring:"1:10d*"
    && Base.String.is_substring text ~substring:"5:Previous Cycle"
    | _ -> false) "daily-pace-context-names-period-choices";
  let env = X.pace_env entry in
  let context_at ?(env = env) width screen =
    let geometry = X.screen_geometry ~dimensions:(width, 24) ~width_of entry in
    match (Pace.view env geometry screen).Screen.subtitle with
    | Screen.Text text -> text | _ -> "" in
  let current = context_at 80 entry.C.screens.pace in
  let pace, _, _ = get (Pace.current_pace env) in
  let margin = O.format_money env.book env.measure pace.B.daily_pace_quanta in
  require (Base.String.is_substring current ~substring:"Spent: 0 jpy"
    && Base.String.is_substring current ~substring:("(+" ^ margin ^ " vs pace)")
    && Base.String.is_substring current ~substring:"[1-5] period")
    "daily-pace-current-context-discloses-spent-and-margin";
  List.iter (fun width ->
    let text = context_at width entry.C.screens.pace in
    require (width_of text <= width
      && not (Base.String.is_substring text ~substring:"Spent:"))
      ("daily-pace-context-omits-whole-spent-clause-" ^ string_of_int width)) [32; 48];
  let unavailable_env = { env with Screen.config = (fun _ -> Ok None) } in
  let unavailable = context_at ~env:unavailable_env 80 entry.C.screens.pace in
  require (Base.String.is_substring unavailable ~substring:"unavailable"
    && not (Base.String.is_substring unavailable ~substring:"Spent:"))
    "daily-pace-unavailable-context-does-not-infer-spent";
  let previous_start = get (Cal.shift_days today (-7)) in
  let previous_env = { env with Screen.config = (fun name ->
    if name = "boundary-presets.tsv" then
      Ok (Some ("cycle\t" ^ previous_start ^ "\t" ^ today ^ "\t" ^ stop ^ "\n"))
    else env.config name) } in
  let previous, _ = Pace.handle previous_env
      (X.screen_geometry ~dimensions:(120, 24) ~width_of entry)
      entry.C.screens.pace (`Key (`ASCII '5', [])) in
  require ((Pace.trend previous).Trend.preset = Trend.Previous_cycle)
    "daily-pace-context-previous-cycle-fixture-admitted";
  let previous_context = context_at ~env:previous_env 120 previous in
  require (not (Base.String.is_substring previous_context ~substring:"Spent:"))
    "daily-pace-absent-today-sample-does-not-infer-spent";
  let wide_detail = key ~dimensions:(120, 36) ~width_of entry (`ASCII 'i') in
  let painted_wide = R.screen ~width_of (120, 36) wide_detail |> List.map snd |> String.concat "\n" in
  require (Base.String.is_substring painted_wide ~substring:"Trend"
    && Base.String.is_substring painted_wide ~substring:"History"
    && Base.String.is_substring painted_wide ~substring:"╰ 10/10 "
    && Base.String.is_substring painted_wide ~substring:"Selected day")
    "daily-pace-wide-detail-retains-trend-and-history-position";
  let wide_geometry = X.screen_geometry ~dimensions:(120, 36) ~width_of wide_detail in
  let wide_view = pace_detail_viewport ~dimensions:(120, 36) ~width_of wide_detail in
  require (wide_view.capacity = Ui_panel.capacity
      ~height:(max 7 ((snd wide_geometry.content - 2) / 2)) ~heading:false)
    (* LOAM geometry: half of the panel area below the two context rows. *)
    "daily-pace-wide-detail-navigation-matches-painted-height";
  (* LOAM: below a 15-row panel the History list is hidden; Trend names the
     selected date and says so, and Page then moves one date (max 1 0). *)
  let narrow_dimensions = (48, 14) in
  let narrow_rows = R.screen ~width_of narrow_dimensions entry |> List.map snd in
  require (List.exists (fun text -> Base.String.is_substring text ~substring:"╰ 10/10 • list hidden ") narrow_rows
    && List.exists (fun text -> Base.String.is_substring text ~substring:(today ^ " (today) ◆")) narrow_rows
    && not (List.exists (fun text -> Base.String.is_substring text ~substring:"History") narrow_rows))
    "daily-pace-narrow-retains-selected-history-strip";
  let narrow_page = key ~dimensions:narrow_dimensions ~width_of entry (`Page `Up) in
  require (selected_date ten_samples narrow_page = yesterday)
    "daily-pace-narrow-history-page-matches-one-visible-date";
  let back = key ~width_of entry (`ASCII 'h') in
  require (selected_date ten_samples back = yesterday) "daily-pace-sel-entry-h-prev";
  require (selected_date ten_samples (key ~width_of back (`ASCII 'l')) = today) "daily-pace-sel-entry-l-today";
  let preset = key ~width_of entry (`ASCII '2') in
  require (preset.workspace.route = W.Daily_pace) "daily-pace-sel-preset-route";
  require ((Pace.trend preset.C.screens.pace).Trend.preset = Trend.Thirty_days) "daily-pace-sel-preset-kind";
  require (selected_date samples preset = today) "daily-pace-sel-preset-tail";
  let back = key ~width_of preset (`ASCII 'h') in
  require (selected_date samples back = yesterday) "daily-pace-sel-preset-h-prev";
  let tail = key ~width_of preset `End in
  require (selected_date samples tail = today) "daily-pace-sel-end-tail";
  require
    (selected_date samples (key ~width_of tail (`ASCII 'h')) = yesterday)
    "daily-pace-sel-end-h-prev";
  require
    (selected_date samples (key ~width_of tail (`Arrow `Left)) = yesterday)
    "daily-pace-sel-end-left-prev";
  let painted = R.screen ~width_of (140, 40) tail |> List.map snd |> String.concat "\n" in
  let visible_days = List.filter (fun (sample : Trend.sample) ->
    Base.String.is_substring painted ~substring:sample.day) samples |> List.length in
  let paged = key ~width_of tail (`Page `Up) in
  require (selected_date samples paged = day_at (max 0 (count - 1 - visible_days)))
    "daily-pace-page-matches-visible-history-dates";
  require
    (selected_date samples (key ~width_of paged (`Page `Down)) = today)
    "daily-pace-sel-page-down-restores";
  (* Yesterday survives a 10d -> 30d -> 10d round trip via date preservation. *)
  let back10 = key ~width_of entry (`ASCII 'h') in
  let thirty = key ~width_of back10 (`ASCII '2') in
  require (selected_date samples thirty = yesterday) "daily-pace-sel-roundtrip-30d-keeps-yesterday";
  let ten_again = key ~width_of thirty (`ASCII '1') in
  require (selected_date ten_samples ten_again = yesterday) "daily-pace-sel-roundtrip-10d-keeps-yesterday";
  (* A refused new range never resets the cursor: change_preset is an error. *)
  require
    (Result.is_error
       (Trend.change_preset ~today ~boundary_presets_text:None (Pace.trend thirty.C.screens.pace) Trend.Cycle))
    "daily-pace-sel-refused-preset-keeps-cursor";
  require
    (Result.is_error
       (Trend.move_selection ~today ~preset:Trend.Cycle ~boundary_presets_text:None
          ~position:((Pace.trend thirty.C.screens.pace).Trend.selected_index) 1))
    "daily-pace-sel-missing-range-refuses-step";
  require
    (Result.is_error
       (Trend.move_selection ~today ~preset:Trend.Cycle
          ~boundary_presets_text:(Some (Printf.sprintf "p1\t%s\t%s\np2\t%s\t%s\n" today stop today stop))
          ~position:((Pace.trend thirty.C.screens.pace).Trend.selected_index) 1))
    "daily-pace-sel-ambiguous-range-refuses-step";
  (* Focused full-width detail: End -> Up moves the painted viewport, the
     selected date stays put, and a resize clamps through the new viewport. *)
  let dim = (80, 14) in
  let detail = key ~dimensions:dim ~width_of tail (`ASCII 'i') in
  require (Pace.detail_focused detail.C.screens.pace) "daily-pace-sel-detail-focused";
  let view0 = pace_detail_viewport ~dimensions:dim ~width_of detail in
  require (view0.last > 0) "daily-pace-detail-overflows";
  let sel_before = (Pace.trend detail.C.screens.pace).Trend.selected_index in
  let at_end = key ~dimensions:dim ~width_of detail `End in
  let view_end = pace_detail_viewport ~dimensions:dim ~width_of at_end in
  require (view_end.start = view_end.last && Pace.detail_scroll at_end.C.screens.pace = view_end.last)
    "daily-pace-detail-end-rests-on-last";
  let up = key ~dimensions:dim ~width_of at_end (`Arrow `Up) in
  let view_up = pace_detail_viewport ~dimensions:dim ~width_of up in
  require (view_up.start = view_end.start - 1) "daily-pace-detail-end-up-moves-viewport";
  require ((Pace.trend up.C.screens.pace).Trend.selected_index = sel_before) "daily-pace-detail-scroll-keeps-date";
  let paged_detail = key ~dimensions:dim ~width_of at_end (`Page `Up) in
  require (Pace.detail_scroll at_end.C.screens.pace - Pace.detail_scroll paged_detail.C.screens.pace = min view_end.last (max 1 view_end.capacity))
    "daily-pace-detail-page-uses-capacity";
  let resized_up = key ~dimensions:(80, 24) ~width_of at_end (`Arrow `Up) in
  let view_resized = pace_detail_viewport ~dimensions:(80, 24) ~width_of resized_up in
  require (Pace.detail_scroll resized_up.C.screens.pace <= view_resized.last) "daily-pace-detail-resize-up-clamps-to-painted-last";
  require ((Pace.trend resized_up.C.screens.pace).Trend.selected_index = sel_before)
    "daily-pace-detail-resize-keeps-date";
  require (selected_date samples (key ~width_of tail (`ASCII 'l')) = today) "daily-pace-sel-end-stays";
  let head = key ~width_of tail `Home in
  require (selected_date samples head = day_at 0) "daily-pace-sel-home-head";
  require
    (selected_date samples (key ~width_of head (`ASCII 'h')) = day_at 0)
    "daily-pace-sel-home-stays";
  (* Cursor keys on a refused range keep the fail-closed screen. *)
  let bare = directory ^ "/bare" in
  Unix.mkdir bare 0o700;
  let bare_path = bare ^ "/book.sexp" in
  F.create_copy ~source:Interaction_check_fixture.example_book ~target:bare_path;
  let bare_home = C.initial ~config_home:bare (F.load bare_path) in
  let missing = C.open_route { bare_home with session = F.load bare_path } W.Daily_pace in
  let clean text =
    let out = Buffer.create (String.length text) in
    String.iter
      (fun char ->
        match char with ' ' | '\t' | '\r' | '\n' -> () | _ -> Buffer.add_char out char)
      text;
    Buffer.contents out
  in
  List.iter
    (fun button ->
      let moved = key ~width_of missing button in
      let label =
        match button with
        | `ASCII c -> "key-" ^ String.make 1 c
        | `Arrow `Left -> "left"
        | `Arrow `Right -> "right"
        | `Page `Up -> "pageup"
        | `Page `Down -> "pagedown"
        | `Home -> "home"
        | `End -> "end"
        | _ -> "other"
      in
      require (moved.workspace.route = W.Daily_pace) ("daily-pace-sel-missing-route-" ^ label);
      let text =
        List.map (fun (_, row) -> clean row) (R.screen ~width_of (80, 24) moved)
        |> String.concat ""
      in
      require
        (Base.String.is_substring text ~substring:(clean "Daily Pace unavailable:"))
        ("daily-pace-sel-missing-screen-" ^ label))
    [ `ASCII 'h'; `ASCII 'l'; `Arrow `Left; `Arrow `Right; `Page `Up; `Page `Down; `Home; `End ];
  print_endline
    "PASS: Daily Pace selection clamps to the rendered range (preset/End stepping, head/tail, \
     refused range)."
(* Integer graph geometry, qualified joins and exact currency presentation. *)
let daily_pace_graph_render_checks ~width_of () =
  let book =
    get
      (B.of_string
         ("(bakhlo-daily 1)\n" ^ "(scope corrected-entries explicit-plans)\n"
        ^ "(measures (measure \"jpy\" 0) (measure \"eur\" 2))\n" ^ "(labels (provided))\n"
        ^ "(approved-loci (provided \"wallet\"))\n" ^ "(entries)\n" ^ "(plans)\n" ^ "(support\n"
        ^ "  (zero-origin (\"wallet\" \"jpy\") (\"wallet\" \"eur\"))\n" ^ "(openings)\n"
        ^ "  (observations)\n"
        ^ "  (presence (not-supplied)))\n"))
  in
  let sample ~day ?(q = 4464) ?(stop = "2026-11-01") () =
    {
      Trend.day;
      pace_quanta = Some (Z.of_int q);
      available_through_end = Z.of_int q;
      pool_balance = Z.of_int q;
      deductions = Z.zero;
      remaining_days = 1;
      end_exclusive = stop;
      activity = Some Trend.zero_activity;
      unavailable = None;
    }
  in
  let none_sample ~day ~stop () =
    { (sample ~day ~stop ()) with Trend.pace_quanta = None }
  in
  let days = List.init 10 (fun i -> Printf.sprintf "2026-10-%02d" (18 + i)) in
  let samples = List.mapi (fun i day -> sample ~day ~q:(4464 - i * 23) ()) days in
  let rows ~width ~height =
    Trend.render_chart ~width ~height ~width_of ~book ~today:"2026-10-26" ~measure:"jpy" ~samples
      ~selected_index:8 ~graph_style:Trend.Line
  in
  List.iter
    (fun (width, height, grouped) ->
      let painted = Trend.render_chart ~width ~height ~width_of ~book ~today:"2026-10-26" ~measure:"jpy"
        ~samples ~selected_index:8 ~graph_style:Trend.Line in
      let tag = Printf.sprintf "%dx%d" width height in
      require (List.length painted <= height) ("pace-graph-height-" ^ tag);
      require (List.for_all (fun (_, t) -> width_of t <= width) painted) ("pace-graph-width-" ^ tag);
      let glued = String.concat "\n" (List.map snd painted) in
      require (Base.String.is_substring glued ~substring:"2026-10-26") ("pace-graph-selected-day-" ^ tag);
      require (Base.String.is_substring glued ~substring:"◆") ("pace-graph-selected-glyph-" ^ tag);
      require (Base.String.is_substring glued ~substring:grouped) ("pace-graph-grouped-" ^ tag))
    [ (52, 30, "4,280"); (35, 18, "4,280"); (42, 8, "4,280") ];
  let narrow = rows ~width:26 ~height:3 in
  require (List.length narrow <= 3) "pace-graph-narrow-height";
  require (List.for_all (fun (_, t) -> width_of t <= 26) narrow) "pace-graph-narrow-width";
  require
    ((List.exists (fun (_, t) -> Base.String.is_substring t ~substring:"◆") narrow)
    && List.exists (fun (_, t) -> Base.String.is_substring t ~substring:"2026-10-26") narrow)
    "pace-graph-narrow-summary";
  (* Constant, zero, negative, mixed-sign and 400-digit spans stay bounded
     and keep selecting the intended sample. *)
  let const_samples = List.map (fun day -> sample ~day ()) days in
  let zero_samples = List.map (fun day -> sample ~day ~q:0 ()) days in
  (* LOAM Chart.scaleFor [500] pads to [450,550]. Four intervals ask
     for 25 quanta; niceStep rounds up to 50, yielding 450/500/550.
     The negative series mirrors those exact ticks. *)
  List.iter (fun (q, ticks) ->
    let single = [sample ~day:"2026-10-26" ~q ()] in
    let painted = Trend.render_chart ~width:52 ~height:30 ~width_of ~book
      ~today:"2026-10-26" ~measure:"jpy" ~samples:single ~selected_index:0 ~graph_style:Line in
    let text = String.concat "\n" (List.map snd painted) in
    require (List.for_all (fun tick ->
      Base.String.is_substring text ~substring:(tick ^ " │ ")) ticks)
      "pace-single-point-loam-nice-tick-breathing-room")
    [500, ["450"; "500"; "550"]; -500, ["-550"; "-500"; "-450"]];
  List.iter
    (fun (label, made) ->
      List.iter
        (fun (width, height) ->
          let painted = made ~width ~height in
          require (List.length painted <= height) (label ^ "-height");
          require (List.for_all (fun (_, t) -> width_of t <= width) painted) (label ^ "-width");
          let glued = String.concat "\n" (List.map snd painted) in
          require (Base.String.is_substring glued ~substring:"◆") (label ^ "-selected"))
        [ (52, 30); (35, 18) ])
    [
      ("pace-graph-const", fun ~width ~height ->
          Trend.render_chart ~width ~height ~width_of ~book ~today:"2026-10-26" ~measure:"jpy"
            ~samples:const_samples ~selected_index:9 ~graph_style:Line);
      ("pace-graph-zero", fun ~width ~height ->
          Trend.render_chart ~width ~height ~width_of ~book ~today:"2026-10-26" ~measure:"jpy"
            ~samples:zero_samples ~selected_index:0 ~graph_style:Line);
    ];
  let mixed =
    List.mapi
      (fun i day -> sample ~day ~q:(if i mod 2 = 0 then 3000 - i * 1000 else -2000 + i * 500) ())
      days
  in
  let painted is_line =
    String.concat "\n"
      (List.map snd
         (Trend.render_chart ~width:52 ~height:30 ~width_of ~book ~today:"2026-10-26" ~measure:"jpy"
            ~samples:mixed ~selected_index:3 ~graph_style:(if is_line then Trend.Line else Trend.Dots)))
  in
  let ink text =
    Uutf.String.fold_utf_8
      (fun n _ -> function
        | `Uchar c -> if Uchar.to_int c >= 0x2800 && Uchar.to_int c <= 0x28FF then n + 1 else n
        | `Malformed _ -> n)
      0 text
  in
  require (ink (painted true) > ink (painted false)) "pace-graph-line-inks";
  let huge_digit = Z.of_string (String.make 400 '7') in
  let huge_samples =
    List.mapi
      (fun i day ->
        {
          (sample ~day ()) with
          Trend.pace_quanta = Some (if i = 4 then huge_digit else Z.of_int (1000 + i));
        })
      days
  in
  let huge = Trend.render_chart ~width:52 ~height:30 ~width_of ~book ~today:"2026-10-26" ~measure:"jpy"
    ~samples:huge_samples ~selected_index:4 ~graph_style:Line in
  require (List.length huge <= 30) "pace-graph-huge-height";
  require (List.for_all (fun (_, t) -> width_of t <= 52) huge) "pace-graph-huge-width";
  require
    (Base.String.is_substring (String.concat "\n" (List.map snd huge)) ~substring:"◆")
    "pace-graph-huge-selected";
  let detail = Trend.render_detail ~width:52 ~width_of ~book ~measure:"jpy"
    ~sample:(Some (List.nth huge_samples 4)) ~prev_sample:None ~today:"2026-10-26" ~preset:Trend.Ten_days in
  let detail_digits =
    String.concat "" (List.map snd detail) |> String.split_on_char ',' |> String.concat ""
  in
  require (Base.String.is_substring detail_digits ~substring:(Z.to_string huge_digit))
    "pace-graph-huge-detail-exact";
  List.iter (fun width ->
    let selected = { (List.nth huge_samples 4) with
      Trend.pace_quanta = Some (Z.neg huge_digit);
      activity = Some { Trend.zero_activity with scheduled_settled_inflow = Z.of_int 400 } } in
    let rows = Trend.render_detail ~width ~width_of ~book ~measure:"jpy"
      ~sample:(Some selected) ~prev_sample:None ~today:"2026-10-26" ~preset:Trend.Ten_days in
    require (List.for_all (fun (_, row) -> width_of row <= width) rows) "pace-detail-wrap-width";
    let joined = String.concat "" (List.map snd rows) in
    require (Base.String.is_substring joined ~substring:("-" ^ O.format_money book "jpy" huge_digit ^ " jpy/day")
      && Base.String.is_substring joined ~substring:"Scheduled-linked inflow/reversal: +400 jpy")
      "pace-detail-wrap-keeps-signed-quantity-and-linked-inflow";
    let unknown = { selected with Trend.pace_quanta = None; pool_balance = Z.of_int 12345678 } in
    let rows = Trend.render_detail ~width ~width_of ~book ~measure:"jpy"
      ~sample:(Some unknown) ~prev_sample:None ~today:"2026-10-26" ~preset:Trend.Ten_days in
    require (not (Base.String.is_substring (String.concat "" (List.map snd rows))
      ~substring:"12,345,678")) "pace-unknown-never-paints-dummy-pool")
    [26; 42; 74; 114];
  let euro = Trend.render_chart ~width:52 ~height:30 ~width_of ~book ~today:"2026-10-26"
    ~measure:"eur"
    ~samples:(List.map (fun day -> sample ~day ~q:446400 ()) days)
    ~selected_index:8 ~graph_style:Line in
  require
    (Base.String.is_substring (String.concat "\n" (List.map snd euro)) ~substring:"4,464.00")
    "pace-graph-eur-scale";
  let pair = [sample ~day:"2026-10-18" ~q:4000 (); sample ~day:"2026-10-19" ~q:5000 ()] in
  let render style values =
    Trend.render_chart ~width:52 ~height:8 ~width_of ~book ~today:"2026-10-19"
      ~measure:"jpy" ~samples:values ~selected_index:1 ~graph_style:style |> List.map snd in
  require (render Trend.Line pair <> render Trend.Dots pair) "pace-graph-adjacent-joined";
  let gaps = [
    [List.hd pair; none_sample ~day:"2026-10-19" ~stop:"2026-11-01" ();
      sample ~day:"2026-10-20" ~q:5000 ()];
    [List.hd pair; sample ~day:"2026-10-20" ~q:5000 ()];
    [List.hd pair; sample ~day:"2026-10-19" ~q:5000 ~stop:"2026-12-01" ()];
  ] in
  List.iter (fun values ->
    require (render Trend.Line values = render Trend.Dots values) "pace-graph-gap-not-bridged") gaps;
  (* A leading hole keeps unknown labelled, and the tail selection never clips. *)
  let leading = none_sample ~day:"2026-10-18" ~stop:"2026-11-01" () :: List.tl samples in
  let leading_glued =
    String.concat "\n"
      (List.map snd
         (Trend.render_chart ~width:52 ~height:30 ~width_of ~book ~today:"2026-10-26" ~measure:"jpy"
            ~samples:leading ~selected_index:0 ~graph_style:Line))
  in
  require (Base.String.is_substring leading_glued ~substring:"unavailable") "pace-graph-hole-labelled";
  let spent =
    { Trend.zero_activity with discretionary_outflow = Z.of_int 1000 }
  in
  let current = { (sample ~day:"2026-10-19" ()) with activity = Some spent } in
  let history = [ sample ~day:"2026-10-18" ~q:4233 (); current ] in
  let painted_history width height =
    Trend.render_history ~width ~height ~width_of ~book ~today:"2026-10-19" ~measure:"jpy"
      ~samples:history ~selected_index:1 ~detail_focused:false
  in
  let full = painted_history 70 5 |> List.map snd |> String.concat "\n" in
  require
    (Base.String.is_substring full ~substring:"1,000"
     && Base.String.is_substring full ~substring:"+3,464"
     && not (Base.String.is_substring full ~substring:"+231"))
    "pace-history-same-day-margin-not-prior-day-change";
  List.iter
    (fun (width, height) ->
      let rows = painted_history width height in
      require (List.length rows <= height
        && List.for_all (fun (_, row) -> width_of row <= width) rows)
        "pace-history-geometry")
    [ (0, 0); (1, 1); (26, 2); (46, 4); (70, 4) ];
  print_endline
    "PASS: Daily Pace braille graph fits panes (Line vs Dots, holes/cycle resets, grouped Measure scale)."

let pool_review_checks ~width_of ~directory () =
  let directory = directory ^ "/pool-review" in
  Unix.mkdir directory 0o700;
  let path = directory ^ "/book.sexp" in
  F.create_copy ~source:Interaction_check_fixture.example_book ~target:path;
  let pool_path = directory ^ "/daily-pace.tsv" in
  let windows_path = directory ^ "/boundary-presets.tsv" in
  let before = "wallet\tjpy\n" and after = "bank\tjpy\n" in
  let boundaries = "old\t1900-01-01\t1901-01-01\ncycle\t" ^ F.today ()
    ^ "\t" ^ get (Cal.shift_days (F.today ()) 7) ^ "\n" in
  F.write_new pool_path before;
  F.write_new windows_path boundaries;
  let ledger = F.read path in
  let fresh () = C.open_route (C.initial ~config_home:directory (F.load path)) W.Daily_pace in
  let press state button = key ~dimensions:(80, 24) ~width_of state button in
  let form (state : C.state) =
    match visible_form state with
    | Some form -> form
    | None -> raise (F.Refused "pool-review-expected-form")
  in
  let editing state = Ui_form.id (form state) = "configure_daily_pace" in
  let reviewing state = Ui_form.id (form state) = "review_pool" in
  let text state = Ui_form.get_text (form state) "pool_loci" in
  let submit value state =
    let updated = Ui_form.set_text (form state) "pool_loci" value
      |> fun f -> Ui_form.set_focused f 1 in
    let state = with_visible_form state updated in
    press state `Enter in
  let opened = press (fresh ()) (`ASCII 'c') in
  require (text opened = Some "wallet") "pool-editor-shows-existing";
  let review = submit "bank" opened in
  let displayed = R.overlay_screen ~dimensions:(80, 24) ~width_of review
    |> Option.value ~default:[] |> List.map snd |> String.concat "\n" in
  require (reviewing review && F.read pool_path = before
    && Base.String.is_substring displayed ~substring:"wallet"
    && Base.String.is_substring displayed ~substring:"bank"
    && Base.String.is_substring displayed ~substring:"jpy") "pool-old-new-visible-before-write";
  let escaped = press review `Escape in
  require (editing escaped && text escaped = Some "bank" && F.read pool_path = before)
    "pool-review-escape-retains-input";
  let edited = press (press (submit "bank" escaped) (`Arrow `Right)) `Enter in
  require (editing edited && text edited = Some "bank") "pool-review-edit-retains-input";
  let closed = press edited `Escape in
  require (not (b2_overlay_open closed) && F.read pool_path = before) "pool-cancel-no-write";
  let resumed = press closed (`ASCII 'c') in
  require (text resumed = Some "bank") "pool-cancel-reopen-retains-input";
  let via_commands = X.open_command (press resumed `Escape) Ui_commands.Pace_pool in
  require (text via_commands = Some "bank") "pool-commands-resume-same-draft";
  List.iter (fun dimensions ->
    let refused = key ~dimensions ~width_of review `Enter in
    require (reviewing refused && Ui_form.notice (form refused) <> ""
      && F.read pool_path = before) "pool-narrow-review-no-write";
    let back = key ~dimensions ~width_of refused `Escape in
    require (editing back && text back = Some "bank") "pool-narrow-escape-retains-input")
    [(48, 14); (32, 9)];
  Unix.mkdir (pool_path ^ ".lock") 0o700;
  let failed = press review `Enter in
  require (reviewing failed && Ui_form.notice (form failed) <> ""
    && F.read pool_path = before) "pool-write-failure-preserves-old";
  require (text (press failed `Escape) = Some "bank") "pool-write-failure-retains-draft";
  Unix.rmdir (pool_path ^ ".lock");
  let replace bytes = Unix.unlink pool_path; F.write_new pool_path bytes in
  let concurrent = "wallet\tjpy\nbank\tjpy\n" in
  replace concurrent;
  let stale = press review `Enter in
  require (reviewing stale && F.read pool_path = concurrent
    && Ui_form.notice (form stale) <> "") "pool-stale-preserves-concurrent-setting";
  require (text (press stale `Escape) = Some "bank") "pool-stale-keeps-new-input";
  replace before;
  let saved = press (submit "bank" (press (fresh ()) (`ASCII 'c'))) `Enter in
  require (no_modal saved && F.read pool_path = after) "pool-explicit-save";
  require (text (press saved (`ASCII 'c')) = Some "bank") "pool-success-clears-old-draft";
  let cold = fresh () in
  require (match resolve_pace_pool cold with
    | Ok [coordinate] -> Daily_draft.lstr coordinate.D.Effect_coordinate.locus = "bank"
    | _ -> false) "pool-save-cold-reopen";
  List.iter (fun raw ->
    replace raw;
    let blocked = submit "bank" (press (fresh ()) (`ASCII 'c')) in
    require (editing blocked && F.read pool_path = raw
      && Ui_form.notice (form blocked) <> "") "pool-foreign-or-malformed-not-replaced")
    ["wallet\teur\n"; "wallet\tjpy\nbank\teur\n"; "broken\n"];
  replace before;
  let invalid = submit "wallet, wallet" (press (fresh ()) (`ASCII 'c')) in
  require (editing invalid && text invalid = Some "wallet, wallet"
    && F.read pool_path = before) "pool-invalid-input-retained";
  let many = List.init 20 (fun i -> Printf.sprintf "retained-%02d\tjpy\n" i)
    |> String.concat "" in
  replace many;
  let hidden = submit "bank" (press (fresh ()) (`ASCII 'c')) |> fun s -> press s `Enter in
  require (reviewing hidden && F.read pool_path = many) "pool-hidden-old-rows-cannot-save";
  Unix.unlink pool_path;
  let created = press (submit "bank" (press (fresh ()) (`ASCII 'c'))) `Enter in
  require (no_modal created && F.read pool_path = after) "pool-missing-explicit-create";
  Unix.unlink pool_path;
  Unix.mkdir pool_path 0o700;
  let unreadable = submit "bank" (press (fresh ()) (`ASCII 'c')) in
  require (editing unreadable && Sys.is_directory pool_path) "pool-unreadable-not-replaced";
  Unix.rmdir pool_path;
  require (F.read path = ledger && F.read windows_path = boundaries) "pool-only-config-changes";
  print_endline "PASS: Pool old/new Review, Esc/Edit/cancel drafts, narrow/hidden refusal, \
    lock/stale/Measure protection, cold save and unchanged ledger/boundaries."

