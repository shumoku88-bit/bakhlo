module B = Bakhlo_sexp.Daily_book
module S = Stock_flow_report
module I = Income_expense_report

let get = function Ok x -> x | Error why -> failwith why
let require condition why = if not condition then failwith why

let self_check () =
  let fixture support =
    get
      (B.of_string
         ("(bakhlo-daily 1) (scope corrected-entries explicit-plans)\n"
        ^ "(measures (measure jpy 0) (measure eur 2))\n"
        ^ "(labels (not-supplied)) (approved-loci (provided a b c))\n" ^ "(entries\n"
        ^ " (entry before (date 2026-09-30) (memo (none)) (postings (posting a jpy 20 (none)) \
           (posting b jpy -20 (none))) (reversal-of (none)))\n"
        ^ " (entry within (date 2026-10-16) (memo (none)) (postings (posting a jpy 10 (none)) \
           (posting a jpy 20 (none)) (posting b jpy -30 (none))) (reversal-of (none)))\n"
        ^ " (entry end (date 2026-11-01) (memo (none)) (postings (posting a jpy 40 (none)) \
           (posting b jpy -40 (none))) (reversal-of (none))))\n" ^ "(plans) (support " ^ support
        ^ ")"))
  in
  let zero =
    fixture "(zero-origin (a jpy) (b jpy)) (openings) (observations) (presence (not-supplied))"
  in
  let observed =
    fixture
      "(zero-origin) (openings) (observations (observation (reflected) (quantities (a jpy 100)))) \
       (presence (not-supplied))"
  in
  let present =
    fixture
      "(zero-origin) (openings) (observations) (presence (provided (reflected) (coordinates (c \
       jpy))))"
  in
  let period : I.period =
    { preset = I.Month; start_day = "2026-10-01"; end_exclusive = "2026-11-01"; label = "October" }
  in
  let compute book tracked_coords = S.compute_report ~book ~measure:"jpy" ~tracked_coords ~period in
  let refuses book coords =
    require (Result.is_error (compute book coords)) "stock-flow must refuse unsupported question"
  in
  List.iter (refuses zero)
    [ []; [ ("c", "jpy") ]; [ ("a", "jpy"); ("a", "jpy") ]; [ ("a", "jpy"); ("b", "eur") ] ];
  refuses present [ ("c", "jpy") ];
  require
    (Daily_overlays.quantity_value ~book:observed ~measure:"jpy" "a"
    = Daily_overlays.Exact (Z.of_int 190))
    "observation fixture must have exact current quantity";
  refuses observed [ ("a", "jpy") ];
  let r = get (compute zero [ ("a", "jpy") ]) in
  require
    (Z.equal r.reconstructed_start (Z.of_int 20)
    && Z.equal r.reconstructed_end (Z.of_int 50)
    && Z.equal r.current_tracked (Z.of_int 90)
    && Z.equal r.increases_across_events (Z.of_int 30)
    && Z.equal r.decreases_across_events Z.zero)
    "zero-origin forward history and half-open flow must remain exact";
  let transfer = get (compute zero [ ("b", "jpy"); ("a", "jpy") ]) in
  require
    (List.map (fun (c : S.coordinate_activity) -> c.locus) transfer.coordinates = [ "b"; "a" ])
    "configured coordinate order must survive";
  require
    (Z.equal transfer.increases_across_events Z.zero
    && Z.equal transfer.decreases_across_events Z.zero
    && Z.equal transfer.net_change Z.zero)
    "internal selected transfers must cancel before event sign partition";
  require
    (Result.is_error
       (S.compute_report ~book:zero ~measure:"jpy"
          ~tracked_coords:[ ("a", "jpy") ]
          ~period:{ period with end_exclusive = period.start_day }))
    "empty date window must refuse";
  print_endline
    "PASS: Stock-Flow exact current/history separation, explicit single-measure selection, \
     zero-origin boundaries and per-Event transfer cancellation."
