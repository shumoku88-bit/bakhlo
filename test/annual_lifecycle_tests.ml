open Base
module B = Bakhlo_sexp.Daily_book
module Scope = Bakhlo_sexp.Annual_scope
module File = Daily_file
module D = Bakhlo_domain
module Y = Bakhlo_sexp.Year_read

let get = function Ok x -> x | Error why -> failwith why
let require x msg = if not x then failwith msg

let temp_dir prefix =
  let path = Stdlib.Filename.temp_file prefix "" in
  Stdlib.Sys.remove path;
  Unix.mkdir path 0o700;
  path

let coordinate locus measure =
  {
    D.Effect_coordinate.locus =
      (match D.Identifier.Locus.of_string locus with Ok l -> l | Error _ -> failwith "invalid-locus");
    measure =
      (match D.Identifier.Measure.of_string measure with Ok m -> m | Error _ -> failwith "invalid-measure");
  }

let posting locus measure n =
  D.Effect.create
    ~locus:(match D.Identifier.Locus.of_string locus with Ok l -> l | Error _ -> failwith "locus")
    ~measure:(match D.Identifier.Measure.of_string measure with Ok m -> m | Error _ -> failwith "measure")
    ~quantity:(D.Quantity.of_quanta (Z.of_int n))
    ~key:None

let rich_book ~entries ~plans ~support =
  let s =
    Printf.sprintf
      "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
       (measures (measure jpy 0) (measure eur 2)) (labels (not-supplied))\n\
       (approved-loci (provided wallet cash bank food salary tax pension living))\n\
       (entries\n%s)\n\
       (plans\n%s)\n\
       (support\n%s)\n"
      entries plans support
  in
  get (B.of_string s)

(*******************************************************************************
  1. Rollover + 2027 payment with overdue 2026 plan;
     Prior bytes unchanged;
     Repeat pay/cancel refused via B
*******************************************************************************)
let%expect_test "rollover with overdue plan payment, unchanged prior, and repeat pay/cancel refused" =
  let root = temp_dir "bakhlo-lifecycle-rollover-" in
  let p26 = Stdlib.Filename.concat root "2026.sexp" in
  let p27 = Stdlib.Filename.concat root "2027.sexp" in

  let entries26 =
    "(entry e_seed (date 2026-01-01) (memo (none))\n\
     (postings (posting wallet jpy 1000 (none)) (posting food jpy -1000 (none)))\n\
     (reversal-of (none)) (exchange (none)))"
  in
  let plans26 =
    "(plan p_overdue (date 2026-10-10) (measure jpy) (changes (wallet -100) (food 100)) (paid-by (none)) (cancelled-on (none)))"
  in
  let support26 =
    "(zero-origin (food jpy) (tax jpy))\n\
     (openings)\n\
     (observations (observation (reflected e_seed) (quantities (wallet jpy 1000))))\n\
     (presence (provided (reflected e_seed) (coordinates (bank jpy))))"
  in
  let book26 = rich_book ~entries:entries26 ~plans:plans26 ~support:support26 in
  let empty26 = File.create_annual_empty ~year:2026 ~path:p26 ~measure:"jpy" ~scale:0 in
  let session26 =
    match File.publish empty26 book26 with
    | File.Written s -> s
    | _ -> failwith "publish-2026-failed"
  in
  let prior_bytes_before = File.read p26 in

  (* Execute rollover from 2026 to 2027 *)
  let session27 = File.rollover ~session:session26 in
  require (Poly.equal session27.annual_year (Some 2027)) "rollover-target-year";
  require (Stdlib.Sys.file_exists p27) "2027-created";

  (* Prior 2026 bytes remain pristine *)
  require (String.equal (File.read p26) prior_bytes_before) "prior-bytes-preserved-after-rollover";

  (* Open plan p_overdue is visible in 2027 *)
  let open_plans_27 = B.open_plans session27.book in
  require (List.exists open_plans_27 ~f:(fun p -> String.equal p.id "p_overdue")) "overdue-plan-survives";

  (* Pay overdue 2026 plan in 2027 *)
  let pay_entry_27 : B.entry = {
    id = "e_pay27";
    day = "2027-01-15";
    memo = Some "pay overdue plan";
    effects = [ posting "wallet" "jpy" (-100); posting "food" "jpy" 100 ];
    reversal_of = None;
    exchange = None;
    original_amount = None;
  } in
  let book27_paid = get (B.put_entry session27.book ~replace:false pay_entry_27 ~plan:(Some "p_overdue")) in
  let saved27 =
    match File.publish session27 book27_paid with
    | File.Written s -> s
    | _ -> failwith "publish-2027-payment-failed"
  in

  (* Prior 2026 bytes remain strictly unchanged after 2027 payment *)
  require (String.equal (File.read p26) prior_bytes_before) "prior-bytes-preserved-after-2027-pay";

  (* Repeat payment of already-paid plan must be refused by Daily_book *)
  let repeat_pay_entry : B.entry = {
    id = "e_pay27_repeat";
    day = "2027-01-20";
    memo = None;
    effects = [ posting "wallet" "jpy" (-100); posting "food" "jpy" 100 ];
    reversal_of = None;
    exchange = None;
    original_amount = None;
  } in
  let repeat_pay_result = B.put_entry saved27.book ~replace:false repeat_pay_entry ~plan:(Some "p_overdue") in
  require (Result.is_error repeat_pay_result) "repeat-payment-refused";

  (* Cancellation of already-paid plan must be refused by Daily_book *)
  let cancel_paid_result =
    B.put_plan saved27.book ~replace:true {
      id = "p_overdue";
      day = "2026-10-10";
      measure = "jpy";
      changes = [ ("wallet", Z.of_int (-100)); ("food", Z.of_int 100) ];
      paid_by = Some "e_pay27";
      cancelled_on = Some "2027-01-25";
    }
  in
  require (Result.is_error cancel_paid_result) "cancel-paid-plan-refused";
  [%expect {| |}]

(*******************************************************************************
  2. Reopen balances and Daily Pace equals independently constructed
     monolithic B oracle across Dec/Jan pension cycle
*******************************************************************************)
let%expect_test "reopen balances and Daily Pace equal monolithic B oracle across Dec/Jan pension cycle" =
  let root = temp_dir "bakhlo-lifecycle-pace-" in
  let p26 = Stdlib.Filename.concat root "2026.sexp" in
  let p27 = Stdlib.Filename.concat root "2027.sexp" in

  (* Dec 2026 pension receipt and Dec expenditure *)
  let entries26 =
    "(entry e_pension_dec (date 2026-12-25) (memo (none))\n\
     (postings (posting wallet jpy 200000 (none)) (posting pension jpy -200000 (none)))\n\
     (reversal-of (none)) (exchange (none)))\n\
     (entry e_spend_dec (date 2026-12-28) (memo (none))\n\
     (postings (posting wallet jpy -30000 (none)) (posting living jpy 30000 (none)))\n\
     (reversal-of (none)) (exchange (none)))"
  in
  let plans26 =
    "(plan p_jan_rent (date 2027-01-20) (measure jpy) (changes (wallet -50000) (living 50000)) (paid-by (none)) (cancelled-on (none)))"
  in
  let support26 =
    "(zero-origin (pension jpy) (living jpy))\n\
     (openings)\n\
     (observations (observation (reflected e_pension_dec) (quantities (wallet jpy 200000))))\n\
     (presence (not-supplied))"
  in
  let book26 = rich_book ~entries:entries26 ~plans:plans26 ~support:support26 in
  let empty26 = File.create_annual_empty ~year:2026 ~path:p26 ~measure:"jpy" ~scale:0 in
  let session26 =
    match File.publish empty26 book26 with
    | File.Written s -> s
    | _ -> failwith "publish-2026-pension-failed"
  in

  (* Rollover to 2027 *)
  let session27 = File.rollover ~session:session26 in

  (* Jan 2027 expenditure *)
  let spend_jan : B.entry = {
    id = "e_spend_jan";
    day = "2027-01-05";
    memo = Some "Jan grocery";
    effects = [ posting "wallet" "jpy" (-20000); posting "living" "jpy" 20000 ];
    reversal_of = None;
    exchange = None;
    original_amount = None;
  } in
  let book27 = get (B.put_entry session27.book ~replace:false spend_jan ~plan:None) in
  let _saved27 =
    match File.publish session27 book27 with
    | File.Written s -> s
    | _ -> failwith "publish-2027-spend-failed"
  in

  (* Cold reload 2027 session *)
  let cold_session27 = File.load ~annual_year:2027 p27 in
  require (Option.is_none (File.annual_unavailable cold_session27)) "annual-available";

  (* Construct independent monolithic Daily_book oracle with all entries *)
  let mono_entries =
    "(entry e_pension_dec (date 2026-12-25) (memo (none))\n\
     (postings (posting wallet jpy 200000 (none)) (posting pension jpy -200000 (none)))\n\
     (reversal-of (none)) (exchange (none)))\n\
     (entry e_spend_dec (date 2026-12-28) (memo (none))\n\
     (postings (posting wallet jpy -30000 (none)) (posting living jpy 30000 (none)))\n\
     (reversal-of (none)) (exchange (none)))\n\
     (entry e_spend_jan (date 2027-01-05) (memo (some \"Jan grocery\"))\n\
     (postings (posting wallet jpy -20000 (none)) (posting living jpy 20000 (none)))\n\
     (reversal-of (none)) (exchange (none)))"
  in
  let mono_book = rich_book ~entries:mono_entries ~plans:plans26 ~support:support26 in

  (* Compare balances between cold reloaded annual session and monolithic oracle *)
  let check_balance locus expected_quanta =
    let target = coordinate locus "jpy" in
    let cold_ans = match B.Q.query (B.image cold_session27.book) target with Ok x -> x | Error _ -> failwith "cold-unavailable" in
    let mono_ans = match B.Q.query (B.image mono_book) target with Ok x -> x | Error _ -> failwith "mono-unavailable" in
    match cold_ans, mono_ans with
    | B.Q.Exact c, B.Q.Exact m ->
        require (Z.equal (D.Quantity.quanta (B.Q.quantity c)) (Z.of_int expected_quanta)) "exact-quanta-expected";
        require (Z.equal (D.Quantity.quanta (B.Q.quantity c)) (D.Quantity.quanta (B.Q.quantity m))) "match-mono-quanta"
    | _ -> failwith "expected-exact-balance"
  in
  (* Wallet: 200,000 - 30,000 - 20,000 = 150,000 *)
  check_balance "wallet" 150000;
  (* Living: 30,000 + 20,000 = 50,000 *)
  check_balance "living" 50000;

  (* Compare Daily Pace oracle across the cycle: observed 2027-01-10, end 2027-01-25 *)
  let pool = [ coordinate "wallet" "jpy" ] in
  let pace_cold =
    get (B.daily_pace cold_session27.book ~measure:"jpy" ~pool ~observed_at:"2027-01-10" ~end_exclusive:"2027-01-25")
  in
  let pace_mono =
    get (B.daily_pace mono_book ~measure:"jpy" ~pool ~observed_at:"2027-01-10" ~end_exclusive:"2027-01-25")
  in
  require (Z.equal pace_cold.daily_pace_quanta pace_mono.daily_pace_quanta) "daily-pace-quanta-equals-oracle";
  require (Z.equal pace_cold.available_through_end pace_mono.available_through_end) "daily-pace-available-equals-oracle";
  [%expect {| |}]

(*******************************************************************************
  3. Exact 0 vs Zero-origin, Known-present, and Unknown root-cut preserved
*******************************************************************************)
let%expect_test "exact 0 vs zero-origin, known-present and unknown root-cut preserved" =
  let root = temp_dir "bakhlo-lifecycle-categories-" in
  let p26 = Stdlib.Filename.concat root "2026.sexp" in
  let p27 = Stdlib.Filename.concat root "2027.sexp" in

  let entries26 =
    "(entry e_seed (date 2026-01-01) (memo (none))\n\
     (postings (posting wallet jpy 100 (none)) (posting cash jpy 50 (none)) (posting food jpy -150 (none)))\n\
     (reversal-of (none)) (exchange (none)))\n\
     (entry e_zero (date 2026-06-01) (memo (none))\n\
     (postings (posting cash jpy -50 (none)) (posting food jpy 50 (none)))\n\
     (reversal-of (none)) (exchange (none)))"
  in
  let plans26 = "" in
  let support26 =
    "(zero-origin (food jpy) (tax jpy))\n\
     (openings)\n\
     (observations (observation (reflected e_seed) (quantities (wallet jpy 100) (cash jpy 50))))\n\
     (presence (provided (reflected e_seed) (coordinates (bank jpy))))"
  in
  let book26 = rich_book ~entries:entries26 ~plans:plans26 ~support:support26 in
  let empty26 = File.create_annual_empty ~year:2026 ~path:p26 ~measure:"jpy" ~scale:0 in
  let session26 =
    match File.publish empty26 book26 with
    | File.Written s -> s
    | _ -> failwith "publish-2026-failed"
  in

  let _session27 = File.rollover ~session:session26 in
  let cold27 = File.load ~annual_year:2027 p27 in
  let img = B.image cold27.book in

  (* 1. Exact zero: cash has reflected cut, 50 - 50 = 0 *)
  (match B.Q.query img (coordinate "cash" "jpy") with
   | Ok (B.Q.Exact ans) ->
       require (Z.equal (D.Quantity.quanta (B.Q.quantity ans)) Z.zero) "cash-exact-zero"
   | _ -> failwith "cash-not-exact-zero");

  (* 2. Zero-origin: tax has zero-origin support and no postings *)
  (match B.Q.query img (coordinate "tax" "jpy") with
   | Ok (B.Q.Exact ans) ->
       require (Z.equal (D.Quantity.quanta (B.Q.quantity ans)) Z.zero) "tax-zero-origin-zero"
   | _ -> failwith "tax-not-zero-origin");

  (* 3. Known-present: bank has presence declaration *)
  (match B.Q.query img (coordinate "bank" "jpy") with
   | Ok (B.Q.Known_present _) -> ()
   | _ -> failwith "bank-not-known-present");

  (* 4. Unknown: salary has no support or postings *)
  (match B.Q.query img (coordinate "salary" "jpy") with
   | Error (B.Q.Support_unknown _) -> ()
   | _ -> failwith "salary-not-unknown");

  (* 5. Reflected root-cut: wallet cut at e_seed prevents double counting (100, not 200) *)
  (match B.Q.query img (coordinate "wallet" "jpy") with
   | Ok (B.Q.Exact ans) ->
       require (Z.equal (D.Quantity.quanta (B.Q.quantity ans)) (Z.of_int 100)) "wallet-root-cut-preserved"
   | _ -> failwith "wallet-not-exact-100");
  [%expect {| |}]

(*******************************************************************************
  4. Changes, missing, corrupt prior refuse successor;
     Stale loaded writer refuses
*******************************************************************************)
let%expect_test "changes, missing, corrupt prior refuse successor and stale loaded writer refuses" =
  let root = temp_dir "bakhlo-lifecycle-integrity-" in
  let p26 = Stdlib.Filename.concat root "2026.sexp" in
  let p27 = Stdlib.Filename.concat root "2027.sexp" in

  let entries26 =
    "(entry e_init (date 2026-01-01) (memo (none))\n\
     (postings (posting wallet jpy 100 (none)) (posting food jpy -100 (none)))\n\
     (reversal-of (none)) (exchange (none)))"
  in
  let book26 = rich_book ~entries:entries26 ~plans:"" ~support:"(zero-origin (food jpy)) (openings) (observations) (presence (not-supplied))" in
  let empty26 = File.create_annual_empty ~year:2026 ~path:p26 ~measure:"jpy" ~scale:0 in
  let session26 =
    match File.publish empty26 book26 with
    | File.Written s -> s
    | _ -> failwith "publish-2026-failed"
  in

  let session27 = File.rollover ~session:session26 in
  let p26_bytes = File.read p26 in

  (* A. Stale loaded writer: someone tampers with 2026 externally *)
  File.write_new (p26 ^ ".tmp") (p26_bytes ^ "\n");
  Unix.rename (p26 ^ ".tmp") p26;

  (* Loaded session27 attempt to publish must be refused because predecessor fingerprint changed *)
  let entry27 : B.entry = {
    id = "e_spend27";
    day = "2027-02-01";
    memo = None;
    effects = [ posting "wallet" "jpy" (-10); posting "food" "jpy" 10 ];
    reversal_of = None;
    exchange = None;
    original_amount = None;
  } in
  let book27 = get (B.put_entry session27.book ~replace:false entry27 ~plan:None) in
  let stale_pub_refused =
    match File.publish session27 book27 with
    | File.Written _ -> false
    | File.Conflict | File.Refused_input _ | File.Uncertain -> true
    | exception File.Refused _ -> true
  in
  require stale_pub_refused "stale-writer-publish-refused";

  (* Fresh load of 2027 must detect unavailable / altered predecessor *)
  let load_tampered_refused =
    try
      let s = File.load ~annual_year:2027 p27 in
      Option.is_some (File.annual_unavailable s)
    with File.Refused _ -> true
  in
  require load_tampered_refused "load-tampered-prior-refused";

  (* B. Missing predecessor: remove 2026 *)
  Stdlib.Sys.remove p26;
  let load_missing_refused =
    try
      let s = File.load ~annual_year:2027 p27 in
      Option.is_some (File.annual_unavailable s)
    with File.Refused _ | Unix.Unix_error _ -> true
  in
  require load_missing_refused "load-missing-prior-refused";

  (* C. Corrupt predecessor: invalid sexp in 2026 *)
  File.write_new p26 "(corrupt sexp file not valid";
  let load_corrupt_refused =
    try
      let s = File.load ~annual_year:2027 p27 in
      Option.is_some (File.annual_unavailable s)
    with File.Refused _ -> true
  in
  require load_corrupt_refused "load-corrupt-prior-refused";
  [%expect {| |}]

(*******************************************************************************
  5. Old year publish refused even when loaded via unscoped numeric path
*******************************************************************************)
let%expect_test "old year publish refused even when loaded via unscoped numeric path" =
  let root = temp_dir "bakhlo-lifecycle-old-publish-" in
  let p26 = Stdlib.Filename.concat root "2026.sexp" in
  let _p27 = Stdlib.Filename.concat root "2027.sexp" in

  let entries26 =
    "(entry e_init (date 2026-01-01) (memo (none))\n\
     (postings (posting wallet jpy 100 (none)) (posting food jpy -100 (none)))\n\
     (reversal-of (none)) (exchange (none)))"
  in
  let book26 = rich_book ~entries:entries26 ~plans:"" ~support:"(zero-origin (food jpy)) (openings) (observations) (presence (not-supplied))" in
  let empty26 = File.create_annual_empty ~year:2026 ~path:p26 ~measure:"jpy" ~scale:0 in
  let session26 =
    match File.publish empty26 book26 with
    | File.Written s -> s
    | _ -> failwith "publish-2026-failed"
  in

  (* Successor 2027 is created *)
  let _session27 = File.rollover ~session:session26 in

  (* Predecessor 2026 is loaded with unscoped path (no ~annual_year parameter) *)
  let unscoped_session26 = File.load p26 in

  (* Attempting to publish an update to 2026 must be refused because successor exists *)
  let new_entry26 : B.entry = {
    id = "e_late26";
    day = "2026-12-31";
    memo = Some "late addition";
    effects = [ posting "wallet" "jpy" (-10); posting "food" "jpy" 10 ];
    reversal_of = None;
    exchange = None;
    original_amount = None;
  } in
  let modified_book26 = get (B.put_entry unscoped_session26.book ~replace:false new_entry26 ~plan:None) in
  let old_publish_refused =
    match File.publish unscoped_session26 modified_book26 with
    | File.Written _ -> false
    | File.Conflict | File.Refused_input _ | File.Uncertain -> true
    | exception File.Refused _ -> true
  in
  require old_publish_refused "publish-to-frozen-predecessor-refused";
  [%expect {| |}]

(*******************************************************************************
  6. Collision rollover refused
*******************************************************************************)
let%expect_test "collision rollover refused when successor already exists" =
  let root = temp_dir "bakhlo-lifecycle-collision-" in
  let p26 = Stdlib.Filename.concat root "2026.sexp" in
  let p27 = Stdlib.Filename.concat root "2027.sexp" in

  let entries26 =
    "(entry e_init (date 2026-01-01) (memo (none))\n\
     (postings (posting wallet jpy 100 (none)) (posting food jpy -100 (none)))\n\
     (reversal-of (none)) (exchange (none)))"
  in
  let book26 = rich_book ~entries:entries26 ~plans:"" ~support:"(zero-origin (food jpy)) (openings) (observations) (presence (not-supplied))" in
  let empty26 = File.create_annual_empty ~year:2026 ~path:p26 ~measure:"jpy" ~scale:0 in
  let session26 =
    match File.publish empty26 book26 with
    | File.Written s -> s
    | _ -> failwith "publish-2026-failed"
  in

  (* First rollover succeeds *)
  let _session27 = File.rollover ~session:session26 in
  let p27_bytes_first = File.read p27 in

  (* Second rollover collision attempt must be refused without altering existing 2027 *)
  let collision_refused =
    try
      ignore (File.rollover ~session:session26);
      false
    with File.Refused _ | Unix.Unix_error _ -> true
  in
  require collision_refused "collision-rollover-refused";
  require (String.equal (File.read p27) p27_bytes_first) "existing-2027-preserved-on-collision";
  [%expect {| |}]

(*******************************************************************************
  7. Chain 2028: closed paid plans remain closed in successor year
*******************************************************************************)
let%expect_test "chain 2028: closed paid plans remain closed across multi-year chain" =
  let root = temp_dir "bakhlo-lifecycle-chain-" in
  let p26 = Stdlib.Filename.concat root "2026.sexp" in
  let p27 = Stdlib.Filename.concat root "2027.sexp" in
  let p28 = Stdlib.Filename.concat root "2028.sexp" in

  let entries26 =
    "(entry e_seed (date 2026-01-01) (memo (none))\n\
     (postings (posting wallet jpy 500 (none)) (posting food jpy -500 (none)))\n\
     (reversal-of (none)) (exchange (none)))"
  in
  let plans26 =
    "(plan p_closed_in_27 (date 2026-11-01) (measure jpy) (changes (wallet -100) (food 100)) (paid-by (none)) (cancelled-on (none)))\n\
     (plan p_stays_open (date 2026-12-01) (measure jpy) (changes (wallet -50) (food 50)) (paid-by (none)) (cancelled-on (none)))"
  in
  let book26 = rich_book ~entries:entries26 ~plans:plans26 ~support:"(zero-origin (food jpy)) (openings) (observations) (presence (not-supplied))" in
  let empty26 = File.create_annual_empty ~year:2026 ~path:p26 ~measure:"jpy" ~scale:0 in
  let session26 =
    match File.publish empty26 book26 with
    | File.Written s -> s
    | _ -> failwith "publish-2026-failed"
  in

  (* 2026 -> 2027 *)
  let session27 = File.rollover ~session:session26 in
  let pay27 : B.entry = {
    id = "e_pay27";
    day = "2027-03-01";
    memo = None;
    effects = [ posting "wallet" "jpy" (-100); posting "food" "jpy" 100 ];
    reversal_of = None;
    exchange = None;
    original_amount = None;
  } in
  let book27 = get (B.put_entry session27.book ~replace:false pay27 ~plan:(Some "p_closed_in_27")) in
  let session27_saved =
    match File.publish session27 book27 with
    | File.Written s -> s
    | _ -> failwith "publish-2027-failed"
  in

  (* 2027 -> 2028 *)
  let session28 = File.rollover ~session:session27_saved in
  let open_plans_28 = B.open_plans session28.book in

  (* p_closed_in_27 must NOT be open in 2028 *)
  require (not (List.exists open_plans_28 ~f:(fun p -> String.equal p.id "p_closed_in_27"))) "closed-plan-stays-closed";

  (* p_stays_open must still be open in 2028 *)
  require (List.exists open_plans_28 ~f:(fun p -> String.equal p.id "p_stays_open")) "surviving-open-plan-carries-forward";

  (* annual_sources reports the complete chain: 2026, 2027, 2028 *)
  let sources = File.annual_sources session28 in
  require (List.length sources = 3) "three-sources-in-chain";
  let source_paths = List.map sources ~f:fst in
  require (List.mem source_paths p26 ~equal:String.equal) "chain-contains-2026";
  require (List.mem source_paths p27 ~equal:String.equal) "chain-contains-2027";
  require (List.mem source_paths p28 ~equal:String.equal) "chain-contains-2028";
  [%expect {| |}]

(*******************************************************************************
  8. Ancestor artifact refusal
*******************************************************************************)
let%expect_test "ancestor unfinished recovery artifact blocks successor load and rollover" =
  let root = temp_dir "bakhlo-lifecycle-ancestor-artifact-" in
  let p26 = Stdlib.Filename.concat root "2026.sexp" in
  let p27 = Stdlib.Filename.concat root "2027.sexp" in

  let entries26 =
    "(entry e_init (date 2026-01-01) (memo (none))\n\
     (postings (posting wallet jpy 100 (none)) (posting food jpy -100 (none)))\n\
     (reversal-of (none)) (exchange (none)))"
  in
  let book26 = rich_book ~entries:entries26 ~plans:"" ~support:"(zero-origin (food jpy)) (openings) (observations) (presence (not-supplied))" in
  let empty26 = File.create_annual_empty ~year:2026 ~path:p26 ~measure:"jpy" ~scale:0 in
  let session26 =
    match File.publish empty26 book26 with
    | File.Written s -> s
    | _ -> failwith "publish-2026-failed"
  in

  let _session27 = File.rollover ~session:session26 in

  (* Create an unfinished recovery artifact on predecessor 2026 *)
  let artifact26 = p26 ^ ".pending-interrupted123" in
  File.write_new artifact26 "unfinished pending bytes";

  (* Successor 2027 load or validation must refuse because ancestor has unfinished work *)
  let ancestor_blocked =
    try
      let s = File.load ~annual_year:2027 p27 in
      Option.is_some (File.annual_unavailable s)
    with File.Refused _ -> true
  in
  require ancestor_blocked "ancestor-artifact-refuses-successor";

  (* Cleanup artifact restores availability *)
  Stdlib.Sys.remove artifact26;
  let reloaded27 = File.load ~annual_year:2027 p27 in
  require (Option.is_none (File.annual_unavailable reloaded27)) "cleaned-ancestor-restores-successor";
  [%expect {| |}]

(*******************************************************************************
  9. Publication checkpoints uncertainty and recovery cold behavior on envelope
*******************************************************************************)
let%expect_test "publication checkpoints uncertainty and recovery on annual envelope" =
  let root = temp_dir "bakhlo-lifecycle-recovery-" in
  let p26 = Stdlib.Filename.concat root "2026.sexp" in
  let p27 = Stdlib.Filename.concat root "2027.sexp" in

  let entries26 =
    "(entry e_init (date 2026-01-01) (memo (none))\n\
     (postings (posting wallet jpy 100 (none)) (posting food jpy -100 (none)))\n\
     (reversal-of (none)) (exchange (none)))"
  in
  let book26 = rich_book ~entries:entries26 ~plans:"" ~support:"(zero-origin (food jpy)) (openings) (observations) (presence (not-supplied))" in
  let empty26 = File.create_annual_empty ~year:2026 ~path:p26 ~measure:"jpy" ~scale:0 in
  let session26 =
    match File.publish empty26 book26 with
    | File.Written s -> s
    | _ -> failwith "publish-2026-failed"
  in

  let session27 = File.rollover ~session:session26 in
  let entry27 : B.entry = {
    id = "e_cand27";
    day = "2027-01-10";
    memo = None;
    effects = [ posting "wallet" "jpy" (-20); posting "food" "jpy" 20 ];
    reversal_of = None;
    exchange = None;
    original_amount = None;
  } in
  let cand_book = get (B.put_entry session27.book ~replace:false entry27 ~plan:None) in

  (* Interrupt publish at Attempt_synced checkpoint *)
  let checkpoint_tripped = ref false in
  let outcome =
    File.publish
      ~checkpoint:(fun step ->
        if Poly.equal step File.Selected_replaced then (
          checkpoint_tripped := true;
          raise (File.Refused "simulated-checkpoint-failure")))
      session27
      cand_book
  in
  require (!checkpoint_tripped) "checkpoint-was-reached";
  (match outcome with
   | File.Uncertain -> ()
   | File.Written _ -> failwith "publication-should-be-uncertain"
   | _ -> ());

  (* Inspect recovery detects the candidate attempt on 2027.sexp *)
  let report = File.inspect_recovery p27 in
  require (List.length report.items > 0) "recovery-detected-attempt-artifact";

  (* Candidate attempt item can be resolved or confirmed *)
  let item = List.hd_exn report.items in
  let attempt_id = match item.attempt_id with Some id -> id | None -> failwith "missing-attempt-id" in
  ignore (File.confirm_current ~session:(File.load p27) ~attempt_id);

  (* After confirmation, cold reload succeeds and has the entry *)
  let reloaded27 = File.load ~annual_year:2027 p27 in
  require (B.entry_count reloaded27.book = 2) "recovered-cold-entry-count";
  [%expect {| |}]

(*******************************************************************************
  10. Deterministic fork/pipe collision and SIGKILL fixture
*******************************************************************************)
let%expect_test "deterministic fork collision and SIGKILL release fixture" =
  let root = temp_dir "bakhlo-lifecycle-fork-" in
  let p26 = Stdlib.Filename.concat root "2026.sexp" in
  let p27 = Stdlib.Filename.concat root "2027.sexp" in

  let entries26 =
    "(entry e_init (date 2026-01-01) (memo (none))\n\
     (postings (posting wallet jpy 100 (none)) (posting food jpy -100 (none)))\n\
     (reversal-of (none)) (exchange (none)))"
  in
  let book26 = rich_book ~entries:entries26 ~plans:"" ~support:"(zero-origin (food jpy)) (openings) (observations) (presence (not-supplied))" in
  let empty26 = File.create_annual_empty ~year:2026 ~path:p26 ~measure:"jpy" ~scale:0 in
  let session26 =
    match File.publish empty26 book26 with
    | File.Written s -> s
    | _ -> failwith "publish-2026-failed"
  in

  let session27 = File.rollover ~session:session26 in
  let entry27 : B.entry = {
    id = "e_cand_fork";
    day = "2027-01-20";
    memo = None;
    effects = [ posting "wallet" "jpy" (-15); posting "food" "jpy" 15 ];
    reversal_of = None;
    exchange = None;
    original_amount = None;
  } in
  let cand_book = get (B.put_entry session27.book ~replace:false entry27 ~plan:None) in

  let r_pipe, w_pipe = Unix.pipe () in
  match Unix.fork () with
  | 0 ->
      Unix.close r_pipe;
      (* Child holds lock on 2027.sexp *)
      File.with_writer p27 (fun () ->
        let oc = Unix.out_channel_of_descr w_pipe in
        Stdlib.output_string oc "LOCKED\n";
        Stdlib.flush oc;
        for _ = 1 to 60 do Unix.sleep 1 done);
  | pid ->
      Unix.close w_pipe;
      let ic = Unix.in_channel_of_descr r_pipe in
      let _ = Stdlib.input_line ic in
      Unix.close r_pipe;

      (* While child holds lock, publish attempt must collide/conflict *)
      let collided =
        match File.publish session27 cand_book with
        | File.Conflict | File.Refused_input _ | File.Uncertain -> true
        | File.Written _ -> false
        | exception (File.Refused _ | Unix.Unix_error _) -> true
      in
      require collided "concurrent-lock-collision-detected";

      (* Kill child process with SIGKILL *)
      Unix.kill pid Stdlib.Sys.sigkill;
      let _ = Unix.waitpid [] pid in

      (* Now lock is released; publish must succeed *)
      let published =
        match File.publish session27 cand_book with
        | File.Written _ -> true
        | _ -> false
      in
      require published "publish-succeeds-after-sigkill";
      [%expect {| |}]
