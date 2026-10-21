(* Stock–Flow computation: the one shared support rule (zero-origin or bounded
   history), unknown starts before a bounded start, unsupported coordinates
   listed instead of refusing the report, and a cold reload agreeing. *)
module B = Bakhlo_sexp.Daily_book
module S = Stock_flow_report
module I = Income_expense_report

let get = function Ok x -> x | Error why -> failwith why
let require condition why = if not condition then failwith why
let z = Z.of_int

let fixture ?(version = "1") support =
  get
    (B.of_string
       ("(bakhlo-daily " ^ version ^ ") (scope corrected-entries explicit-plans)\n"
      ^ "(measures (measure jpy 0) (measure eur 2))\n"
      ^ "(labels (not-supplied)) (approved-loci (provided a b c))\n" ^ "(entries\n"
      ^ " (entry before (date 2026-09-30) (memo (none)) (postings (posting a jpy 20 (none)) \
         (posting b jpy -20 (none))) (reversal-of (none)))\n"
      ^ " (entry within (date 2026-10-16) (memo (none)) (postings (posting a jpy 10 (none)) \
         (posting a jpy 20 (none)) (posting b jpy -30 (none))) (reversal-of (none)))\n"
      ^ " (entry end (date 2026-11-01) (memo (none)) (postings (posting a jpy 40 (none)) \
         (posting b jpy -40 (none))) (reversal-of (none))))\n"
      ^ "(plans) (support " ^ support ^ ")"))

let self_check () =
  let zero =
    fixture "(zero-origin (a jpy) (b jpy)) (openings) (observations) (presence (not-supplied))"
  in
  let anchored =
    fixture
      "(zero-origin (b jpy)) (openings) (observations (observation (reflected) (quantities (a jpy 10)))) (presence (not-supplied))"
  in
  let bounded = get (B.with_bounded_history anchored [ ("a", "jpy", "2026-09-15") ]) in
  let present =
    fixture
      "(zero-origin) (openings) (observations) (presence (provided (reflected) (coordinates (c \
       jpy))))"
  in
  let period : I.period =
    { preset = I.Month; start_day = "2026-10-01"; end_exclusive = "2026-11-01"; label = "October" }
  in
  let compute ?(liabilities = []) book tracked_coords =
    S.compute_report ~book ~measure:"jpy" ~tracked_coords ~liability_coords:liabilities ~period
  in
  let only locus (report : S.report) =
    List.find (fun (c : S.coordinate_activity) -> c.locus = locus) report.coordinates
  in
  let refuses book coords =
    require (Result.is_error (compute book coords)) "stock-flow must refuse an invalid question"
  in
  List.iter (refuses zero)
    [ []; [ ("a", "jpy"); ("a", "jpy") ]; [ ("a", "jpy"); ("b", "eur") ] ];
  require
    (Result.is_error
       (S.compute_report ~book:zero ~measure:"jpy" ~tracked_coords:[ ("a", "jpy") ]
          ~liability_coords:[] ~period:{ period with end_exclusive = period.start_day }))
    "an empty date window must refuse";

  (* Zero-origin: forward sums stay exact. *)
  let zero_report = get (compute zero [ ("a", "jpy") ]) in
  let a = only "a" zero_report in
  require (a.S.support = S.Zero_origin) "zero-origin support is named";
  require
    ((a.S.start_balance = Some (z 20))
    && (a.S.end_balance = Some (z 50))
    && Z.equal a.S.increases (z 30)
    && Z.equal a.S.decreases Z.zero
    && (a.S.current_balance = Some (z 90))
    && zero_report.S.unknown_starts = 0)
    "zero-origin start, flow and end stay exact";
  let transfer = get (compute zero [ ("b", "jpy"); ("a", "jpy") ]) in
  require
    (List.map (fun (c : S.coordinate_activity) -> c.locus) transfer.S.coordinates = [ "b"; "a" ])
    "configured coordinate order survives";
  require
    (Z.equal transfer.S.increases_across_events (z 30)
    && Z.equal transfer.S.decreases_across_events (z (-30))
    && Z.equal transfer.S.net_change Z.zero)
    "per-coordinate in/out cancel for an internal transfer";

  (* Bounded history: after the start, before the start, and mixed with
     zero-origin coordinates. *)
  let after = get (compute bounded [ ("a", "jpy") ]) in
  let a = only "a" after in
  require
    ((a.S.support = S.Bounded "2026-09-15")
    && (a.S.start_balance = Some (z 30))
    && (a.S.end_balance = Some (z 60))
    && (a.S.current_balance = Some (z 100))
    && after.S.unknown_starts = 0)
    "a window after the bounded start reconstructs both boundaries";
  let before_period : I.period =
    { period with start_day = "2026-09-01"; end_exclusive = "2026-10-01" }
  in
  let before =
    get
      (S.compute_report ~book:bounded ~measure:"jpy" ~tracked_coords:[ ("a", "jpy") ]
         ~liability_coords:[] ~period:before_period)
  in
  let a = only "a" before in
  require
    ((a.S.support = S.Before_start "2026-09-15")
    && a.S.start_balance = None
    && (a.S.end_balance = Some (z 30))
    && before.S.unknown_starts = 1
    && Z.equal before.S.reconstructed_start Z.zero)
    "a window before the bounded start reports an unknown start, never zero";
  let mixed = get (compute bounded [ ("a", "jpy"); ("b", "jpy") ]) in
  require
    ((only "a" mixed).S.support = S.Bounded "2026-09-15"
    && (only "b" mixed).S.support = S.Zero_origin)
    "bounded and zero-origin coordinates render together";

  (* Unsupported coordinates are listed, not used to refuse the report. *)
  let unsupported = get (compute present [ ("c", "jpy") ]) in
  require
    (unsupported.S.coordinates = []
    && List.exists (fun (locus, _) -> locus = "c") unsupported.S.unsupported)
    "an unsupported coordinate is listed instead of refusing";

  (* Liabilities are reported with their remaining end balance. *)
  let liability = get (compute ~liabilities:[ ("b", "jpy") ] zero [ ("a", "jpy") ]) in
  require
    (List.length liability.S.liabilities = 1
    && (List.hd liability.S.liabilities).S.end_balance = Some (z (-50)))
    "liability coordinates keep their end balance";

  (* A cold reload agrees with the in-memory book. *)
  let reloaded = get (B.of_string (B.to_string zero)) in
  let cold = get (compute reloaded [ ("a", "jpy"); ("b", "jpy") ]) in
  let warm = get (compute zero [ ("a", "jpy"); ("b", "jpy") ]) in
  require
    (List.map (fun (c : S.coordinate_activity) -> (c.locus, c.start_balance, c.end_balance))
       cold.S.coordinates
    = List.map (fun (c : S.coordinate_activity) -> (c.locus, c.start_balance, c.end_balance))
        warm.S.coordinates)
    "a cold reload reconstructs the same boundaries";
  print_endline
    "PASS: Stock-Flow zero-origin and bounded support, unknown starts, listed unsupported \
     coordinates, liabilities and cold-reload agreement (synthetic)."
