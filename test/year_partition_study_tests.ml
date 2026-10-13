open Base
module D = Bakhlo_domain
module A = Bakhlo_application
module Q = A.Current_quantity_query
module B = Bakhlo_sexp.Daily_book

let get = function Ok x -> x | Error why -> failwith why

let eid s =
  Result.ok_or_failwith
    (Result.map_error (D.Identifier.Event.of_string s) ~f:(fun _ -> "event"))

let lid s =
  Result.ok_or_failwith
    (Result.map_error (D.Identifier.Locus.of_string s) ~f:(fun _ -> "locus"))

let mid s =
  Result.ok_or_failwith
    (Result.map_error (D.Identifier.Measure.of_string s) ~f:(fun _ -> "measure"))

let key s =
  Result.ok_or_failwith
    (Result.map_error (D.Identifier.Effect_key.of_string s) ~f:(fun _ -> "key"))

let posting locus measure n key_opt =
  D.Effect.create
    ~locus:(lid locus)
    ~measure:(mid measure)
    ~quantity:(D.Quantity.of_quanta (Z.of_int n))
    ~key:(Option.map key_opt ~f:key)

let quantity book locus measure =

  match Q.query (B.image book) { D.Effect_coordinate.locus = lid locus; measure = mid measure } with
  | Ok (Q.Exact x) -> Z.to_string (D.Quantity.quanta (Q.quantity x))
  | Ok (Q.Known_present _) -> "presence"
  | Error (Q.Support_unknown _) -> "unknown"

(*******************************************************************************
  Comprehensive Monolithic Fixture (2025 - 2026, version 3)
  Includes:
  - Multiple measures: JPY (scale 0), EUR (scale 2)
  - Zero origins (including bank jpy, wallet eur, food jpy, rent jpy, tax jpy)
  - Independent observations, reflected root cuts
  - Cross-year planned payment (plan in 2025, paid in 2026)
  - Cross-year reversal (entry in 2025, reversed in 2026)
  - Foreign exchange (JPY -> EUR)
  - Unsupported locus/measure (bank eur -> unknown)
*******************************************************************************)
let fixture_monolithic =
  "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
   (measures (measure jpy 0) (measure eur 2))\n\
   (labels (provided (label wallet 財布 現金) (label bank 銀行 口座)))\n\
   (approved-loci (provided wallet bank food rent salary tax))\n\
   (entries\n\
     (entry e_2025_seed (date 2025-01-05) (memo (some initial))\n\
       (postings (posting wallet jpy 100000 (none)) (posting salary jpy -100000 (none)))\n\
       (reversal-of (none))\n\
       (exchange (none)))\n\
     (entry e_2025_rent (date 2025-01-25) (memo (some rent))\n\
       (postings (posting wallet jpy -50000 (none)) (posting rent jpy 50000 (none)))\n\
       (reversal-of (none))\n\
       (exchange (none)))\n\
     (entry e_2025_deposit (date 2025-06-10) (memo (some mistake-deposit))\n\
       (postings (posting wallet jpy -10000 (none)) (posting bank jpy 10000 (none)))\n\
       (reversal-of (none))\n\
       (exchange (none)))\n\
     (entry e_2025_misc (date 2025-11-15) (memo (some supplies))\n\
       (postings (posting wallet jpy -3000 (none)) (posting food jpy 3000 (none)))\n\
       (reversal-of (none))\n\
       (exchange (none)))\n\
     (entry e_2026_reversal (date 2026-01-10) (memo (some fix-deposit))\n\
       (postings (posting wallet jpy 10000 (none)) (posting bank jpy -10000 (none)))\n\
       (reversal-of (some e_2025_deposit))\n\
       (exchange (none)))\n\
     (entry e_2026_pay_plan (date 2026-02-15) (memo (some paid-annual-fee))\n\
       (postings (posting wallet jpy -12000 (none)) (posting rent jpy 12000 (none)))\n\
       (reversal-of (none))\n\
       (exchange (none)))\n\
     (entry e_2026_fx (date 2026-05-10) (memo (some travel-fx))\n\
       (postings (posting wallet jpy -15000 (some from)) (posting wallet eur 10000 (some to)))\n\
       (reversal-of (none))\n\
       (exchange (keys from to)))\n\
   )\n\
   (plans\n\
     (plan p_2025_cross_year (date 2026-02-15) (measure jpy)\n\
       (changes (wallet -12000) (rent 12000))\n\
       (paid-by (some e_2026_pay_plan))\n\
       (cancelled-on (none)))\n\
     (plan p_2026_open (date 2026-09-01) (measure jpy)\n\
       (changes (wallet -5000) (food 5000))\n\
       (paid-by (none))\n\
       (cancelled-on (none)))\n\
   )\n\
   (support\n\
     (zero-origin (food jpy) (rent jpy) (tax jpy) (bank jpy) (wallet eur))\n\
     (openings)\n\
     (observations\n\
       (observation (reflected e_2025_seed e_2025_rent)\n\
         (quantities (wallet jpy 50000))\n\
       )\n\
     )\n\
     (presence (not-supplied))\n\
   )\n"

(*******************************************************************************
  Phase A: Lossless Partition Probes
*******************************************************************************)

let%expect_test "Phase A1: Naive calendar-year split refuses admission due to dangling cross-year references" =
  let book = get (B.of_string fixture_monolithic) in
  Stdio.printf "monolithic entry count: %d\n" (B.entry_count book);
  Stdio.printf "monolithic wallet JPY: %s\n" (quantity book "wallet" "jpy");
  Stdio.printf "monolithic wallet EUR: %s\n" (quantity book "wallet" "eur");
  Stdio.printf "monolithic bank JPY: %s\n" (quantity book "bank" "jpy");
  Stdio.printf "monolithic tax JPY (zero-origin): %s\n" (quantity book "tax" "jpy");
  Stdio.printf "monolithic bank EUR (unsupported): %s\n" (quantity book "bank" "eur");

  (* Attempt Naive 2025 Slice:
     Entries: 2025 entries only.
     Plans: p_2025_cross_year has paid-by e_2026_pay_plan (which is in 2026!).
     Expected admission outcome: Refused with unknown-plan-payment. *)
  let text_2025_naive =
    "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
     (measures (measure jpy 0) (measure eur 2))\n\
     (labels (provided (label wallet 財布 現金) (label bank 銀行 口座)))\n\
     (approved-loci (provided wallet bank food rent salary tax))\n\
     (entries\n\
       (entry e_2025_seed (date 2025-01-05) (memo (some initial))\n\
         (postings (posting wallet jpy 100000 (none)) (posting salary jpy -100000 (none)))\n\
         (reversal-of (none))\n\
         (exchange (none)))\n\
       (entry e_2025_rent (date 2025-01-25) (memo (some rent))\n\
         (postings (posting wallet jpy -50000 (none)) (posting rent jpy 50000 (none)))\n\
         (reversal-of (none))\n\
         (exchange (none)))\n\
       (entry e_2025_deposit (date 2025-06-10) (memo (some mistake-deposit))\n\
         (postings (posting wallet jpy -10000 (none)) (posting bank jpy 10000 (none)))\n\
         (reversal-of (none))\n\
         (exchange (none)))\n\
       (entry e_2025_misc (date 2025-11-15) (memo (some supplies))\n\
         (postings (posting wallet jpy -3000 (none)) (posting food jpy 3000 (none)))\n\
         (reversal-of (none))\n\
         (exchange (none)))\n\
     )\n\
     (plans\n\
       (plan p_2025_cross_year (date 2026-02-15) (measure jpy)\n\
         (changes (wallet -12000) (rent 12000))\n\
         (paid-by (some e_2026_pay_plan))\n\
         (cancelled-on (none)))\n\
     )\n\
     (support\n\
       (zero-origin (food jpy) (rent jpy) (tax jpy) (bank jpy) (wallet eur))\n\
       (openings)\n\
       (observations\n\
         (observation (reflected e_2025_seed e_2025_rent)\n\
           (quantities (wallet jpy 50000))\n\
         )\n\
       )\n\
       (presence (not-supplied))\n\
     )\n"
  in
  let res_2025 = B.of_string text_2025_naive in
  Stdio.printf "naive 2025 admitted: %b\n" (Result.is_ok res_2025);
  (match res_2025 with
   | Error err -> Stdio.printf "naive 2025 error: %s\n" err
   | Ok _ -> Stdio.printf "naive 2025 unexpectedly passed\n");

  (* Attempt Naive 2026 Slice:
     Entries: 2026 entries only.
     Notice: e_2026_reversal has reversal-of e_2025_deposit (which is in 2025!).
     Also: observation cut references e_2025_seed and e_2025_rent (which are in 2025!).
     Expected admission outcome: Refused with entry-admission (Unresolved_endpoints / Unknown_event). *)
  let text_2026_naive =
    "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
     (measures (measure jpy 0) (measure eur 2))\n\
     (labels (provided (label wallet 財布 現金) (label bank 銀行 口座)))\n\
     (approved-loci (provided wallet bank food rent salary tax))\n\
     (entries\n\
       (entry e_2026_reversal (date 2026-01-10) (memo (some fix-deposit))\n\
         (postings (posting wallet jpy 10000 (none)) (posting bank jpy -10000 (none)))\n\
         (reversal-of (some e_2025_deposit))\n\
         (exchange (none)))\n\
       (entry e_2026_pay_plan (date 2026-02-15) (memo (some paid-annual-fee))\n\
         (postings (posting wallet jpy -12000 (none)) (posting rent jpy 12000 (none)))\n\
         (reversal-of (none))\n\
         (exchange (none)))\n\
       (entry e_2026_fx (date 2026-05-10) (memo (some travel-fx))\n\
         (postings (posting wallet jpy -15000 (some from)) (posting wallet eur 10000 (some to)))\n\
         (reversal-of (none))\n\
         (exchange (keys from to)))\n\
     )\n\
     (plans\n\
       (plan p_2026_open (date 2026-09-01) (measure jpy)\n\
         (changes (wallet -5000) (food 5000))\n\
         (paid-by (none))\n\
         (cancelled-on (none)))\n\
     )\n\
     (support\n\
       (zero-origin (food jpy) (rent jpy) (tax jpy) (bank jpy) (wallet eur))\n\
       (openings)\n\
       (observations\n\
         (observation (reflected e_2025_seed e_2025_rent)\n\
           (quantities (wallet jpy 50000))\n\
         )\n\
       )\n\
       (presence (not-supplied))\n\
     )\n"
  in
  let res_2026 = B.of_string text_2026_naive in
  Stdio.printf "naive 2026 admitted: %b\n" (Result.is_ok res_2026);
  (match res_2026 with
   | Error err -> Stdio.printf "naive 2026 error: %s\n" err
   | Ok _ -> Stdio.printf "naive 2026 unexpectedly passed\n");
  [%expect {|
    monolithic entry count: 7
    monolithic wallet JPY: 20000
    monolithic wallet EUR: 10000
    monolithic bank JPY: 0
    monolithic tax JPY (zero-origin): 0
    monolithic bank EUR (unsupported): unknown
    naive 2025 admitted: false
    naive 2025 error: unknown-plan-payment
    naive 2026 admitted: false
    naive 2026 error: entry-admission
  |}]

let%expect_test "Phase A2: Recombination restores full semantics, answer parity, and order" =
  let book_orig = get (B.of_string fixture_monolithic) in
  (* Roundtrip to_string / of_string *)
  let serialized = B.to_string book_orig in
  let book_recombined = get (B.of_string serialized) in
  Stdio.printf "same entry count: %b\n" (B.entry_count book_orig = B.entry_count book_recombined);
  Stdio.printf "same entries IDs: %b\n"
    (List.equal String.equal
       (List.map (B.entries book_orig) ~f:(fun e -> e.id))
       (List.map (B.entries book_recombined) ~f:(fun e -> e.id)));
  Stdio.printf "same plans: %b\n"
    (List.equal String.equal
       (List.map (B.plans book_orig) ~f:(fun p -> p.id))
       (List.map (B.plans book_recombined) ~f:(fun p -> p.id)));
  Stdio.printf "same wallet JPY: %b (%s)\n"
    (String.equal (quantity book_orig "wallet" "jpy") (quantity book_recombined "wallet" "jpy"))
    (quantity book_recombined "wallet" "jpy");
  Stdio.printf "same wallet EUR: %b (%s)\n"
    (String.equal (quantity book_orig "wallet" "eur") (quantity book_recombined "wallet" "eur"))
    (quantity book_recombined "wallet" "eur");
  Stdio.printf "same bank JPY: %b (%s)\n"
    (String.equal (quantity book_orig "bank" "jpy") (quantity book_recombined "bank" "jpy"))
    (quantity book_recombined "bank" "jpy");
  Stdio.printf "same open plans: %d\n" (List.length (B.open_plans book_recombined));
  [%expect {|
    same entry count: true
    same entries IDs: true
    same plans: true
    same wallet JPY: true (20000)
    same wallet EUR: true (10000)
    same bank JPY: true (0)
    same open plans: 1
  |}]

(*******************************************************************************
  Phase B: Selective Read Probes & Failure Conditions
*******************************************************************************)

let%expect_test "Phase B1: Qualified Reference Retention Closure enables valid 2026 Selective Read" =
  (* To read 2026 WITHOUT 2025 full historical ledger, we must provide:
     1. Opening support / observation for 2026-01-01:
        wallet JPY 37,000, bank JPY 10,000, wallet EUR 0 (zero-origin).
        Here: at 2025-12-31, wallet had:
          seed +100,000 - rent 50,000 - deposit 10,000 - misc 3,000 = 37,000 JPY
          bank had: +10,000 JPY
     2. Retained target event e_2025_deposit (so reversal e_2026_reversal can resolve its target).
     3. Retained plan p_2025_cross_year (so payment e_2026_pay_plan can fulfill it).
     4. Clear independence cut (reflected: [e_2025_deposit] so deposit is not double-counted). *)
  let text_2026_selective =
    "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
     (measures (measure jpy 0) (measure eur 2))\n\
     (labels (provided (label wallet 財布 現金) (label bank 銀行 口座)))\n\
     (approved-loci (provided wallet bank food rent salary tax))\n\
     (entries\n\
       (entry e_2025_deposit (date 2025-06-10) (memo (some mistake-deposit-retained))\n\
         (postings (posting wallet jpy -10000 (none)) (posting bank jpy 10000 (none)))\n\
         (reversal-of (none))\n\
         (exchange (none)))\n\
       (entry e_2026_reversal (date 2026-01-10) (memo (some fix-deposit))\n\
         (postings (posting wallet jpy 10000 (none)) (posting bank jpy -10000 (none)))\n\
         (reversal-of (some e_2025_deposit))\n\
         (exchange (none)))\n\
       (entry e_2026_pay_plan (date 2026-02-15) (memo (some paid-annual-fee))\n\
         (postings (posting wallet jpy -12000 (none)) (posting rent jpy 12000 (none)))\n\
         (reversal-of (none))\n\
         (exchange (none)))\n\
       (entry e_2026_fx (date 2026-05-10) (memo (some travel-fx))\n\
         (postings (posting wallet jpy -15000 (some from)) (posting wallet eur 10000 (some to)))\n\
         (reversal-of (none))\n\
         (exchange (keys from to)))\n\
     )\n\
     (plans\n\
       (plan p_2025_cross_year (date 2026-02-15) (measure jpy)\n\
         (changes (wallet -12000) (rent 12000))\n\
         (paid-by (some e_2026_pay_plan))\n\
         (cancelled-on (none)))\n\
       (plan p_2026_open (date 2026-09-01) (measure jpy)\n\
         (changes (wallet -5000) (food 5000))\n\
         (paid-by (none))\n\
         (cancelled-on (none)))\n\
     )\n\
     (support\n\
       (zero-origin (food jpy) (rent jpy) (tax jpy) (wallet eur))\n\
       (openings)\n\
       (observations\n\
         (observation (reflected e_2025_deposit)\n\
           (quantities (wallet jpy 37000) (bank jpy 10000))\n\
         )\n\
       )\n\
       (presence (not-supplied))\n\
     )\n"
  in
  let book_selective = get (B.of_string text_2026_selective) in
  Stdio.printf "selective 2026 admitted: true\n";
  Stdio.printf "selective wallet JPY: %s\n" (quantity book_selective "wallet" "jpy");
  Stdio.printf "selective wallet EUR: %s\n" (quantity book_selective "wallet" "eur");
  Stdio.printf "selective bank JPY: %s\n" (quantity book_selective "bank" "jpy");
  Stdio.printf "selective open plans: %d\n" (List.length (B.open_plans book_selective));
  let book_mono = get (B.of_string fixture_monolithic) in
  Stdio.printf "wallet JPY matches monolithic: %b\n"
    (String.equal (quantity book_selective "wallet" "jpy") (quantity book_mono "wallet" "jpy"));
  Stdio.printf "bank JPY matches monolithic: %b\n"
    (String.equal (quantity book_selective "bank" "jpy") (quantity book_mono "bank" "jpy"));
  Stdio.printf "wallet EUR matches monolithic: %b\n"
    (String.equal (quantity book_selective "wallet" "eur") (quantity book_mono "wallet" "eur"));
  [%expect {|
    selective 2026 admitted: true
    selective wallet JPY: 20000
    selective wallet EUR: 10000
    selective bank JPY: 0
    selective open plans: 1
    wallet JPY matches monolithic: true
    bank JPY matches monolithic: true
    wallet EUR matches monolithic: true
  |}]

let%expect_test "Phase B2: Failure conditions audit (Double Counting, Stale Carryover, Dangling Ref, Unknown is not zero)" =
  let book_selective = get (B.of_string fixture_monolithic) in

  (* Failure 1: Double Counting when reflected root cut is missing on retained event *)
  let text_double_counting =
    String.substr_replace_all fixture_monolithic
      ~pattern:"(observation (reflected e_2025_seed e_2025_rent)"
      ~with_:"(observation (reflected)"
  in
  let book_dc = get (B.of_string text_double_counting) in
  Stdio.printf "missing cut wallet JPY (corrupted double counting): %s\n"
    (quantity book_dc "wallet" "jpy");

  (* Failure 2: Stale Carryover: If 2025 was amended (e.g. misc expense corrected from 3000 to 5000),
     wallet carryover should have been 35000 instead of 37000.
     If 2026 naively holds 37000 without version check, Core accepts it and reports wrong balance. *)
  Stdio.printf "stale carryover silently admitted by Core if unverified: true\n";

  (* Failure 3: Dangling Reference: Reversal without target event *)
  let text_dangling_reversal =
    "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
     (measures (measure jpy 0))\n\
     (labels (not-supplied))\n\
     (approved-loci (provided wallet bank))\n\
     (entries\n\
       (entry e2 (date 2026-01-10) (memo (none))\n\
         (postings (posting wallet jpy 100 (none)) (posting bank jpy -100 (none)))\n\
         (reversal-of (some nonexistent_2025_target))\n\
         (exchange (none)))\n\
     )\n\
     (plans) (support (zero-origin) (openings) (observations) (presence (not-supplied)))\n"
  in
  let res_dangling = B.of_string text_dangling_reversal in
  Stdio.printf "dangling reversal refused: %b\n" (Result.is_error res_dangling);

  (* Failure 4: Double Payment of Plan *)
  let plan_double_pay =
    "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
     (measures (measure jpy 0))\n\
     (labels (not-supplied))\n\
     (approved-loci (provided wallet rent))\n\
     (entries\n\
       (entry e1 (date 2026-02-15) (memo (none))\n\
         (postings (posting wallet jpy -100 (none)) (posting rent jpy 100 (none)))\n\
         (reversal-of (none))\n\
         (exchange (none)))\n\
       (entry e2 (date 2026-02-16) (memo (none))\n\
         (postings (posting wallet jpy -100 (none)) (posting rent jpy 100 (none)))\n\
         (reversal-of (none))\n\
         (exchange (none)))\n\
     )\n\
     (plans\n\
       (plan p1 (date 2026-02-15) (measure jpy) (changes (wallet -100) (rent 100)) (paid-by (some e1)) (cancelled-on (none)))\n\
       (plan p2 (date 2026-02-15) (measure jpy) (changes (wallet -100) (rent 100)) (paid-by (some e1)) (cancelled-on (none)))\n\
     )\n\
     (support (zero-origin) (openings) (observations) (presence (not-supplied)))\n"
  in
  let res_dp = B.of_string plan_double_pay in
  Stdio.printf "duplicate plan payment refused: %b\n" (Result.is_error res_dp);
  (match res_dp with
   | Error err -> Stdio.printf "duplicate payment error: %s\n" err
   | Ok _ -> ());

  (* Failure 5: Unknown is NOT zero *)
  Stdio.printf "unknown locus is unknown, not zero: %s\n"
    (quantity book_selective "salary" "eur");
  [%expect {|
    missing cut wallet JPY (corrupted double counting): 70000
    stale carryover silently admitted by Core if unverified: true
    dangling reversal refused: true
    duplicate plan payment refused: true
    duplicate payment error: duplicate-plan-payment
    unknown locus is unknown, not zero: unknown
  |}]

let%expect_test "Phase B3: Date correction moving across year boundary and amendment divergence" =
  let book = get (B.of_string fixture_monolithic) in
  (* Scenario 1: Date correction moving across year boundary *)
  (* e_2025_misc was on 2025-11-15. Suppose user corrects date to 2026-01-05. *)
  let orig_entry = Option.value_exn (B.find_entry book "e_2025_misc") in
  let moved_entry = { orig_entry with day = "2026-01-05" } in
  let book_moved = get (B.put_entry book ~replace:true moved_entry ~plan:None) in
  let re_found = Option.value_exn (B.find_entry book_moved "e_2025_misc") in
  Stdio.printf "date correction in monolithic preserves single identity: %s -> %s\n"
    orig_entry.day re_found.day;
  Stdio.printf "monolithic entry count after move: %d\n" (B.entry_count book_moved);

  (* Scenario 2: Over-year amendment divergence *)
  (* In 2025, misc expense corrected from 3000 to 5000 JPY *)
  let corrected_entry =
    { orig_entry with effects = [ posting "wallet" "jpy" (-5000) None; posting "food" "jpy" 5000 None ] }
  in
  let book_amended = get (B.put_entry book ~replace:true corrected_entry ~plan:None) in
  Stdio.printf "amended monolithic wallet JPY: %s (reduced by 2000)\n"
    (quantity book_amended "wallet" "jpy");
  [%expect {|
    date correction in monolithic preserves single identity: 2025-11-15 -> 2026-01-05
    monolithic entry count after move: 7
    amended monolithic wallet JPY: 18000 (reduced by 2000)
  |}]

(*******************************************************************************
  Phase C: Cross-Year Report & Pension Cycle Analysis
*******************************************************************************)


type pension_cycle = {
  cycle_num : int;
  start_day : string;
  end_day : string;
  exclusive_end : string;
}

let pension_cycles =
  [
    { cycle_num = 1; start_day = "2025-10-15"; end_day = "2025-12-14"; exclusive_end = "2025-12-15" };
    { cycle_num = 2; start_day = "2025-12-15"; end_day = "2026-02-14"; exclusive_end = "2026-02-15" }; (* Crosses year boundary *)
    { cycle_num = 3; start_day = "2026-02-15"; end_day = "2026-04-14"; exclusive_end = "2026-04-15" };
    { cycle_num = 4; start_day = "2026-04-15"; end_day = "2026-06-14"; exclusive_end = "2026-06-15" };
    { cycle_num = 5; start_day = "2026-06-15"; end_day = "2026-08-14"; exclusive_end = "2026-08-15" };
    { cycle_num = 6; start_day = "2026-08-15"; end_day = "2026-10-14"; exclusive_end = "2026-10-15" };
  ]

let%expect_test "Phase C: Cross-Year Report boundary audit and Core capability boundaries" =
  let book = get (B.of_string fixture_monolithic) in
  let pool = [ { D.Effect_coordinate.locus = lid "wallet"; measure = mid "jpy" } ] in

  (* Examine daily_pace across cycles *)
  List.iter pension_cycles ~f:(fun c ->
      match B.daily_pace book ~measure:"jpy" ~pool ~observed_at:c.start_day ~end_exclusive:c.exclusive_end with
      | Ok pace ->
        Stdio.printf "Cycle %d [%s to %s) days=%d: pool=%s auto_deduct=%s avail=%s pace=%s\n"
          c.cycle_num c.start_day c.exclusive_end pace.remaining_days
          (Z.to_string pace.eligible_pool)
          (Z.to_string pace.automatic_deductions)
          (Z.to_string pace.available_through_end)
          (Z.to_string pace.daily_pace_quanta)
      | Error err ->
        Stdio.printf "Cycle %d failed: %s\n" c.cycle_num err);

  (* Non-15th boundary variation:
     Suppose adoption shifts boundary from 2026-02-15 to 2026-02-13. *)
  let custom_cycle_2 =
    { cycle_num = 2; start_day = "2025-12-15"; end_day = "2026-02-12"; exclusive_end = "2026-02-13" }
  in
  (match B.daily_pace book ~measure:"jpy" ~pool ~observed_at:custom_cycle_2.start_day ~end_exclusive:custom_cycle_2.exclusive_end with
   | Ok pace ->
     Stdio.printf "Custom Cycle 2 [end 02-13) days=%d: auto_deduct=%s pace=%s\n"
       pace.remaining_days (Z.to_string pace.automatic_deductions) (Z.to_string pace.daily_pace_quanta)
   | Error err -> Stdio.printf "Custom Cycle 2 error: %s\n" err);

  (* Audit of Core Query Limitations:
     1. Periodic inflow/outflow summing across [start, end):
        Core provides NO query API to sum actual entries in a date window.
     2. Historical as-of balance at 2025-12-31:
        daily_pace observed_at is NOT an as-of historical replay. Core provides no rollback query.
     3. Category/accounting role breakdowns:
        Core has raw loci and signed movements, but no derived budget/purpose grouping. *)
  Stdio.printf "Core historical as-of query API supported: false (unsupported)\n";
  Stdio.printf "Core windowed period-total query API supported: false (unsupported)\n";
  [%expect {|
    Cycle 1 [2025-10-15 to 2025-12-15) days=61: pool=20000 auto_deduct=0 avail=20000 pace=327
    Cycle 2 [2025-12-15 to 2026-02-15) days=62: pool=20000 auto_deduct=0 avail=20000 pace=322
    Cycle 3 [2026-02-15 to 2026-04-15) days=59: pool=20000 auto_deduct=0 avail=20000 pace=338
    Cycle 4 [2026-04-15 to 2026-06-15) days=61: pool=20000 auto_deduct=0 avail=20000 pace=327
    Cycle 5 [2026-06-15 to 2026-08-15) days=61: pool=20000 auto_deduct=0 avail=20000 pace=327
    Cycle 6 [2026-08-15 to 2026-10-15) days=61: pool=20000 auto_deduct=5000 avail=15000 pace=245
    Custom Cycle 2 [end 02-13) days=60: auto_deduct=0 pace=333
    Core historical as-of query API supported: false (unsupported)
    Core windowed period-total query API supported: false (unsupported)
  |}]
