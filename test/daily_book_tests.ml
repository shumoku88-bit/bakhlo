open Base
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query

let get = function Ok x -> x | Error why -> failwith why

let fixture =
  "(bakhlo-daily 1) (scope corrected-entries explicit-plans)\n\
   (measures (measure jpy 0) (measure eur 2))\n\
   (labels (provided (label wallet 財布 現金)))\n\
   (approved-loci (provided wallet food bank))\n\
   (entries)\n\
   (plans (plan planned (date 2026-10-10) (measure jpy) (changes (wallet -200) (food 200)) \
   (paid-by (none))))\n\
   (support (zero-origin (food jpy)) (openings)\n\
   (observations (observation (reflected) (quantities (wallet jpy 1000)))) (presence \
   (not-supplied)))\n"

let posting locus measure n key =
  D.Effect.create
    ~locus:
      (Result.ok_or_failwith
         (Result.map_error (D.Identifier.Locus.of_string locus) ~f:(fun _ -> "locus")))
    ~measure:
      (Result.ok_or_failwith
         (Result.map_error (D.Identifier.Measure.of_string measure) ~f:(fun _ -> "measure")))
    ~quantity:(D.Quantity.of_quanta (Z.of_int n))
    ~key:
      (Option.map key ~f:(fun key ->
           Result.ok_or_failwith
             (Result.map_error (D.Identifier.Effect_key.of_string key) ~f:(fun _ -> "key"))))

let entry id n : B.entry =
  {
    id;
    day = "2026-10-03";
    memo = Some "食費";
    effects = [ posting "wallet" "jpy" (-n) None; posting "food" "jpy" n None ];
    reversal_of = None;
    exchange = None;
  }

let quantity book locus measure =
  let locus =
    Result.ok_or_failwith
      (Result.map_error (D.Identifier.Locus.of_string locus) ~f:(fun _ -> "locus"))
  in
  let measure =
    Result.ok_or_failwith
      (Result.map_error (D.Identifier.Measure.of_string measure) ~f:(fun _ -> "measure"))
  in
  match Q.query (B.image book) { D.Effect_coordinate.locus; measure } with
  | Ok (Q.Exact x) -> Z.to_string (D.Quantity.quanta (Q.quantity x))
  | Ok (Q.Known_present _) -> "presence"
  | Error (Q.Support_unknown _) -> "unknown"

let%expect_test "daily replacement and plan payment use current entries, preserving support" =
  let base = get (B.of_string fixture) in
  let added = get (B.put_entry base ~replace:false (entry "e" 100) ~plan:None) in
  let edited =
    get (B.put_entry added ~replace:true { (entry "e" 150) with day = "2026-09-01" } ~plan:None)
  in
  let paid = get (B.put_entry edited ~replace:false (entry "payment" 200) ~plan:(Some "planned")) in
  let cold = get (B.of_string (B.to_string paid)) in
  Stdio.printf "%s %s %s %s %d\n" (quantity base "wallet" "jpy") (quantity added "wallet" "jpy")
    (quantity edited "wallet" "jpy") (quantity cold "wallet" "jpy")
    (List.length (B.entries cold));
  Stdio.printf "%s %s\n" (quantity cold "bank" "jpy") (quantity cold "wallet" "eur");
  let p = List.hd_exn (B.plans cold) in
  Stdio.printf "%s %s\n" p.day (Option.value_exn p.paid_by);
  [%expect {|1000 900 850 650 2
unknown unknown
2026-10-10 payment|}]

let%expect_test "daily data preserves explicit exchange and exact foreign quantities" =
  let base = get (B.of_string fixture) in
  let e : B.entry =
    {
      id = "fx";
      day = "2026-10-03";
      memo = None;
      reversal_of = None;
      effects =
        [ posting "wallet" "jpy" (-100) (Some "from"); posting "wallet" "eur" 70 (Some "to") ];
      exchange = Some ("from", "to");
    }
  in
  let book = get (B.put_entry base ~replace:false e ~plan:None) in
  let cold = get (B.of_string (B.to_string book)) in
  Stdio.printf "%s %s\n" (quantity cold "wallet" "jpy") (quantity cold "wallet" "eur");
  Stdio.printf "%b\n"
    (Result.is_error (B.put_entry base ~replace:false { e with exchange = None } ~plan:None));
  Stdio.printf "%b\n" (Result.is_error (B.parse_amount base "eur" "1.234"));
  [%expect {|900 unknown
true
true|}]

let%expect_test "daily roundtrip keeps every support family and byte-exact metadata" =
  let huge = "1234567890123456789012345678901234567890" in
  let text =
    "(bakhlo-daily 1) (scope corrected-entries explicit-plans)\n\
     (measures (measure jpy 0) (measure eur 2)) (labels (not-supplied))\n\
     (approved-loci (provided wallet food bank))\n\
     (entries (entry seed (date 2026-10-03) (memo (some seed))\n\
     (postings (posting wallet jpy 100 (some w)) (posting food jpy -100 (none))) (reversal-of \
     (none))))\n\
     (plans) (support (zero-origin (food jpy)) (openings (wallet jpy seed))\n\
     (observations (observation (reflected) (quantities (bank eur " ^ huge
    ^ "))))\n(presence (provided (reflected) (coordinates (bank jpy)))))"
  in
  let base = get (B.of_string text) in
  let memo = "引用\"\\\t\n\000\194\133" in
  let row = List.hd_exn (B.entries base) in
  let updated = get (B.put_entry base ~replace:true { row with memo = Some memo } ~plan:None) in
  let planned : B.plan =
    {
      id = "metadata-plan";
      day = "2026-10-10";
      measure = "jpy";
      changes = [ ("wallet", Z.of_int (-10)); ("food", Z.of_int 10) ];
      paid_by = None;
      cancelled_on = None;
    }
  in
  let updated = get (B.put_plan updated ~replace:false planned) in
  let updated = get (B.cancel_plan updated ~id:planned.id ~day:"2026-10-04") in
  let bytes = B.to_string updated in
  let cold = get (B.of_string bytes) in
  Stdio.printf "%s %s %s %s\n" (quantity cold "wallet" "jpy") (quantity cold "food" "jpy")
    (quantity cold "bank" "jpy") (quantity cold "wallet" "eur");
  Stdio.printf "%b %b %b\n"
    (String.equal (quantity cold "bank" "eur") huge)
    (String.equal bytes (B.to_string cold))
    (Option.equal String.equal (List.hd_exn (B.entries cold)).memo (Some memo));
  [%expect {|100 -100 presence unknown
true true true|}]

let%expect_test "daily refunds, syntax and unknown fields cannot disappear" =
  let base = get (B.of_string fixture) in
  let added = get (B.put_entry base ~replace:false (entry "e" 100) ~plan:None) in
  let refund =
    {
      (entry "refund" 100) with
      effects = [ posting "wallet" "jpy" 100 None; posting "food" "jpy" (-100) None ];
      reversal_of = Some "e";
    }
  in
  let book = get (B.put_entry added ~replace:false refund ~plan:None) in
  Stdio.printf "%s %b\n" (quantity book "wallet" "jpy")
    (Result.is_error (B.put_entry book ~replace:true (entry "e" 120) ~plan:None));
  Stdio.printf "%b %b %b\n"
    (Result.is_error (B.of_string (fixture ^ "(unknown-family 1)")))
    (Result.is_error (B.of_string "(bakhlo-daily 1)"))
    (Result.is_error
       (B.put_entry added ~replace:false (entry "unlinked" 100) ~plan:(Some "missing")));
  let vocabulary = get (B.add_locus book "日用品") in
  Stdio.printf "%s\n" (quantity vocabulary "日用品" "jpy");
  [%expect {|1000 true
true true true
unknown|}]

let plan id : B.plan =
  {
    id;
    day = "2026-10-10";
    measure = "jpy";
    changes = [ ("wallet", Z.of_int (-200)); ("food", Z.of_int 200) ];
    paid_by = None;
    cancelled_on = None;
  }

let cold book = get (B.of_string (B.to_string book))

let%expect_test "plans create, replace and cancel without physical activity or lost rows" =
  let base = get (B.of_string fixture) in
  let added = get (B.put_plan base ~replace:false (plan "other")) in
  let changed : B.plan =
    {
      (plan "other") with
      day = "2026-11-01";
      changes =
        [
          ("wallet", Z.of_int (-300));
          ("food", Z.of_int 100);
          ("food", Z.of_int 50);
          ("bank", Z.of_int 150);
        ];
    }
  in
  let replaced = cold (get (B.put_plan added ~replace:true changed)) in
  let cancelled = cold (get (B.cancel_plan replaced ~id:"other" ~day:"2026-10-04")) in
  List.iter [ base; added; replaced; cancelled ] ~f:(fun book ->
      Stdio.printf "%d %d %s %s\n"
        (List.length (B.plans book))
        (List.length (B.open_plans book))
        (quantity book "wallet" "jpy") (quantity book "bank" "jpy"));
  List.iter (B.plans cancelled) ~f:(fun p ->
      Stdio.printf "%s %s %d %b %s\n" p.id p.day (List.length p.changes) (B.plan_is_open p)
        (Option.value p.cancelled_on ~default:"open"));
  Stdio.printf "%b %d %b\n"
    (Poly.equal (List.last_exn (B.plans cancelled)).changes changed.changes)
    (List.length (B.entries cancelled))
    (String.equal (B.to_string base) (B.to_string (get (B.of_string fixture))));
  [%expect
    {|1 1 1000 unknown
2 2 1000 unknown
2 2 1000 unknown
2 1 1000 unknown
planned 2026-10-10 2 true open
other 2026-11-01 4 false 2026-10-04
true 0 true|}]

let%expect_test "plan payment stays atomic, terminal plans cannot change or reopen" =
  let base = get (B.of_string fixture) in
  let other = get (B.put_plan base ~replace:false (plan "other")) in
  let paid =
    cold (get (B.put_entry other ~replace:false (entry "payment" 180) ~plan:(Some "planned")))
  in
  let edited = cold (get (B.put_entry paid ~replace:true (entry "payment" 190) ~plan:None)) in
  let cancelled = cold (get (B.cancel_plan edited ~id:"other" ~day:"2026-10-04")) in
  Stdio.printf "%s %s %s %d\n" (quantity paid "wallet" "jpy") (quantity edited "wallet" "jpy")
    (Option.value_exn (List.hd_exn (B.plans cancelled)).paid_by)
    (List.length (B.open_plans cancelled));
  let attempt name result =
    Stdio.printf "%s: %s\n" name
      (match result with Ok _ -> "unexpected success" | Error why -> why)
  in
  attempt "edit paid" (B.put_plan cancelled ~replace:true (plan "planned"));
  attempt "cancel paid" (B.cancel_plan cancelled ~id:"planned" ~day:"2026-10-04");
  attempt "pay twice"
    (B.put_entry cancelled ~replace:false (entry "again" 200) ~plan:(Some "planned"));
  attempt "edit cancelled" (B.put_plan cancelled ~replace:true (plan "other"));
  attempt "cancel twice" (B.cancel_plan cancelled ~id:"other" ~day:"2026-10-05");
  attempt "pay cancelled"
    (B.put_entry cancelled ~replace:false (entry "again" 200) ~plan:(Some "other"));
  attempt "reuse cancelled ID" (B.put_plan cancelled ~replace:false (plan "other"));
  Stdio.printf "%d %s\n" (List.length (B.entries cancelled)) (quantity cancelled "wallet" "jpy");
  [%expect
    {|820 810 payment 0
edit paid: plan-already-paid
cancel paid: plan-already-paid
pay twice: plan-already-paid
edit cancelled: plan-cancelled
cancel twice: plan-cancelled
pay cancelled: plan-cancelled
reuse cancelled ID: duplicate-plan
1 810|}]

let%expect_test "plan writes reject unsupported drafts without modifying the base" =
  let base = get (B.of_string fixture) in
  let before = B.to_string base in
  let attempt name result =
    Stdio.printf "%s: %s\n" name
      (match result with Ok _ -> "unexpected success" | Error why -> why)
  in
  let put p = B.put_plan base ~replace:false p in
  attempt "duplicate" (put (plan "planned"));
  attempt "missing edit" (B.put_plan base ~replace:true (plan "missing"));
  attempt "empty ID" (put (plan ""));
  attempt "invalid date" (put { (plan "new") with day = "2026-02-30" });
  attempt "unknown currency" (put { (plan "new") with measure = "usd" });
  attempt "unapproved"
    (put { (plan "new") with changes = [ ("missing", Z.of_int (-1)); ("food", Z.one) ] });
  attempt "empty" (put { (plan "new") with changes = [] });
  attempt "zero" (put { (plan "new") with changes = [ ("wallet", Z.zero); ("food", Z.zero) ] });
  attempt "unbalanced"
    (put { (plan "new") with changes = [ ("wallet", Z.of_int (-2)); ("food", Z.one) ] });
  attempt "payment injection" (put { (plan "new") with paid_by = Some "missing" });
  attempt "cancellation injection" (put { (plan "new") with cancelled_on = Some "2026-10-04" });
  attempt "missing cancel" (B.cancel_plan base ~id:"missing" ~day:"2026-10-04");
  attempt "invalid cancel date" (B.cancel_plan base ~id:"planned" ~day:"2026-02-30");
  let no_policy =
    get
      (B.of_string
         (String.substr_replace_all fixture ~pattern:"(approved-loci (provided wallet food bank))"
            ~with_:"(approved-loci (not-supplied))"))
  in
  attempt "policy missing" (B.put_plan no_policy ~replace:false (plan "new"));
  let historical =
    get
      (B.of_string
         (String.substr_replace_all fixture ~pattern:"(approved-loci (provided wallet food bank))"
            ~with_:"(approved-loci (provided bank))"))
  in
  Stdio.printf "cancel historical: %b\n"
    (Result.is_ok (B.cancel_plan historical ~id:"planned" ~day:"2026-10-04"));
  Stdio.printf "unchanged: %b\n" (String.equal before (B.to_string base));
  [%expect
    {|duplicate: duplicate-plan
missing edit: unknown-plan
empty ID: invalid-plan-id
invalid date: invalid-date
unknown currency: measure-scale-not-supplied
unapproved: locus-unapproved
empty: invalid-plan-movement
zero: invalid-plan-movement
unbalanced: invalid-plan-movement
payment injection: plan-terminal-not-input
cancellation injection: plan-terminal-not-input
missing cancel: unknown-plan
invalid cancel date: invalid-date
policy missing: locus-policy-not-supplied
cancel historical: true
unchanged: true|}]

let%expect_test
    "plan codec preserves exact foreign amounts, rejects ambiguous terminals and old-version fields"
    =
  let base = get (B.of_string fixture) in
  let huge = Z.of_string "1234567890123456789012345678901234567890" in
  let foreign =
    { (plan "foreign") with measure = "eur"; changes = [ ("wallet", Z.neg huge); ("food", huge) ] }
  in
  let book = cold (get (B.put_plan base ~replace:false foreign)) in
  let text = B.to_string book in
  Stdio.printf "v3: %b, exact: %b\n"
    (String.is_substring text ~substring:"(bakhlo-daily 3)")
    (Z.equal (snd (List.last_exn (List.last_exn (B.plans book)).changes)) huge);
  let legacy_v2 =
    text
    |> String.substr_replace_all ~pattern:"(bakhlo-daily 3)" ~with_:"(bakhlo-daily 2)"
    |> String.substr_replace_all ~pattern:"(cancelled-on (none))" ~with_:""
  in
  Stdio.printf "legacy open: %d %d\n"
    (List.length (B.open_plans (get (B.of_string fixture))))
    (List.length (B.open_plans (get (B.of_string legacy_v2))));
  let paid = get (B.put_entry base ~replace:false (entry "paid" 200) ~plan:(Some "planned")) in
  let invalid =
    String.substr_replace_all (B.to_string paid) ~pattern:"(cancelled-on (none))"
      ~with_:"(cancelled-on (some 2026-10-04))"
  in
  Stdio.printf "both: %s\n"
    (match B.of_string invalid with Ok _ -> "unexpected success" | Error why -> why);
  let cancelled = get (B.cancel_plan base ~id:"planned" ~day:"2026-10-04") in
  let cancelled_text = B.to_string cancelled in
  Stdio.printf "missing field: %b, bad date: %b, v2 field: %b, v1 field: %b\n"
    (Result.is_error
       (B.of_string (String.substr_replace_all text ~pattern:"(cancelled-on (none))" ~with_:"")))
    (Result.is_error
       (B.of_string
          (String.substr_replace_all cancelled_text ~pattern:"2026-10-04" ~with_:"2026-02-30")))
    (Result.is_error
       (B.of_string
          (String.substr_replace_all cancelled_text ~pattern:"(bakhlo-daily 3)"
             ~with_:"(bakhlo-daily 2)")))
    (Result.is_error
       (B.of_string
          (String.substr_replace_all fixture ~pattern:"(paid-by (none))"
             ~with_:"(paid-by (none)) (cancelled-on (none))")));
  [%expect
    {|v3: true, exact: true
legacy open: 1 2
both: plan-paid-and-cancelled
missing field: true, bad date: true, v2 field: true, v1 field: true|}]

let pace_coordinate locus measure : D.Effect_coordinate.t =
  {
    locus =
      Result.ok_or_failwith
        (Result.map_error (D.Identifier.Locus.of_string locus) ~f:(fun _ -> "locus"));
    measure =
      Result.ok_or_failwith
        (Result.map_error (D.Identifier.Measure.of_string measure) ~f:(fun _ -> "measure"));
  }

let pace book ?(measure = "jpy") ?(loci = [ "wallet" ]) ?(observed_at = "2026-10-07")
    ?(end_exclusive = "2026-10-14") () =
  B.daily_pace book ~measure
    ~pool:(List.map loci ~f:(fun locus -> pace_coordinate locus measure))
    ~observed_at ~end_exclusive

let print_pace (answer : B.daily_pace) =
  Stdio.printf "%d %s %s %s %s\n" answer.remaining_days
    (Z.to_string answer.eligible_pool)
    (Z.to_string answer.automatic_deductions)
    (Z.to_string answer.available_through_end)
    (Z.to_string answer.daily_pace_quanta)

let%expect_test
    "daily pace nets each open occurrence, protects overdue and excludes inflows and boundary" =
  let text =
    String.substr_replace_all fixture ~pattern:"(wallet jpy 1000)"
      ~with_:"(wallet jpy 30000) (bank jpy 0)"
  in
  let base = get (B.of_string text) in
  let base =
    get
      (B.put_plan base ~replace:true
         {
           (plan "planned") with
           changes = [ ("wallet", Z.of_int (-5000)); ("food", Z.of_int 5000) ];
         })
  in
  let add book id day measure changes =
    get
      (B.put_plan book ~replace:false
         {
           (plan id) with
           day;
           measure;
           changes = List.map changes ~f:(fun (locus, n) -> (locus, Z.of_int n));
         })
  in
  let book = add base "overdue" "2026-10-01" "jpy" [ ("wallet", -4000); ("food", 4000) ] in
  let book = add book "internal" "2026-10-08" "jpy" [ ("wallet", -10000); ("bank", 10000) ] in
  let book = add book "income" "2026-10-08" "jpy" [ ("wallet", 9000); ("food", -9000) ] in
  let book = add book "net-zero" "2026-10-08" "jpy" [ ("wallet", -123); ("wallet", 123) ] in
  let book = add book "at-end" "2026-10-14" "jpy" [ ("wallet", -10000); ("food", 10000) ] in
  let book = add book "after-end" "2026-10-15" "jpy" [ ("wallet", -10000); ("food", 10000) ] in
  let book = add book "foreign" "2026-10-08" "eur" [ ("wallet", -10000); ("food", 10000) ] in
  let book = add book "cancelled" "2026-10-08" "jpy" [ ("wallet", -10000); ("food", 10000) ] in
  let book = cold (get (B.cancel_plan book ~id:"cancelled" ~day:"2026-10-07")) in
  let before = B.to_string book in
  let answer = get (pace book ~loci:[ "wallet"; "bank" ] ()) in
  print_pace answer;
  List.iter answer.pool_balances ~f:(fun (coordinate, n) ->
      Stdio.printf "%s=%s\n" (D.Identifier.Locus.to_string coordinate.locus) (Z.to_string n));
  List.iter answer.plan_deductions ~f:(fun (id, n) -> Stdio.printf "%s=%s\n" id (Z.to_string n));
  print_pace (get (pace book ()));
  let permuted = get (pace book ~loci:[ "bank"; "wallet" ] ()) in
  Stdio.printf "pool order independent: %b, no mutation: %b\n"
    (Z.equal answer.daily_pace_quanta permuted.daily_pace_quanta)
    (String.equal before (B.to_string book));
  [%expect
    {|7 30000 9000 21000 3000
wallet=30000
bank=0
planned=5000
overdue=4000
7 30000 19000 11000 1571
pool order independent: true, no mutation: true|}]

let%expect_test
    "daily pace follows current plan edits, cancellations, payment edits and actual refunds" =
  let base = get (B.of_string fixture) in
  print_pace (get (pace base ()));
  let changed =
    get
      (B.put_plan base ~replace:true
         {
           (plan "planned") with
           changes = [ ("wallet", Z.of_int (-300)); ("food", Z.of_int 100); ("food", Z.of_int 200) ];
         })
  in
  print_pace (get (pace (cold changed) ()));
  let cancelled = get (B.cancel_plan changed ~id:"planned" ~day:"2026-10-07") in
  print_pace (get (pace (cold cancelled) ()));
  let paid =
    get (B.put_entry changed ~replace:false (entry "payment" 300) ~plan:(Some "planned"))
  in
  print_pace (get (pace (cold paid) ()));
  let edited =
    get
      (B.put_entry paid ~replace:true { (entry "payment" 350) with day = "2026-10-06" } ~plan:None)
  in
  print_pace (get (pace (cold edited) ()));
  let refund =
    {
      (entry "refund" 350) with
      effects = [ posting "wallet" "jpy" 350 None; posting "food" "jpy" (-350) None ];
      reversal_of = Some "payment";
    }
  in
  let refunded = get (B.put_entry edited ~replace:false refund ~plan:None) in
  print_pace (get (pace (cold refunded) ()));
  Stdio.printf "payment still linked: %s\n"
    (Option.value_exn (List.hd_exn (B.plans refunded)).paid_by);
  let mixed =
    get
      (B.put_plan base ~replace:true
         {
           (plan "planned") with
           changes =
             [ ("wallet", Z.of_int (-300)); ("wallet", Z.of_int 100); ("food", Z.of_int 200) ];
         })
  in
  print_pace (get (pace mixed ()));
  [%expect
    {|7 1000 200 800 114
7 1000 300 700 100
7 1000 0 1000 142
7 700 0 700 100
7 650 0 650 92
7 1000 0 1000 142
payment still linked: payment
7 1000 200 800 114|}]

let%expect_test "daily pace never substitutes a partial balance or uses mixed duplicate coordinates"
    =
  let base = get (B.of_string fixture) in
  let attempt name result =
    Stdio.printf "%s: %s\n" name
      (match result with Ok _ -> "unexpected success" | Error why -> why)
  in
  attempt "partial pool" (pace base ~loci:[ "wallet"; "bank" ] ());
  attempt "foreign unsupported" (pace base ~measure:"eur" ());
  attempt "duplicate" (pace base ~loci:[ "wallet"; "wallet" ] ());
  attempt "unknown measure" (pace base ~measure:"usd" ());
  attempt "mixed"
    (B.daily_pace base ~measure:"jpy"
       ~pool:[ pace_coordinate "wallet" "jpy"; pace_coordinate "wallet" "eur" ]
       ~observed_at:"2026-10-07" ~end_exclusive:"2026-10-14");
  let presence =
    get
      (B.of_string
         (String.substr_replace_all fixture ~pattern:"(presence (not-supplied))"
            ~with_:"(presence (provided (reflected) (coordinates (bank jpy))))"))
  in
  attempt "nonzero unknown amount" (pace presence ~loci:[ "wallet"; "bank" ] ());
  print_pace (get (pace base ~loci:[] ()));
  let no_policy =
    get
      (B.of_string
         (String.substr_replace_all fixture ~pattern:"(approved-loci (provided wallet food bank))"
            ~with_:"(approved-loci (not-supplied))"))
  in
  print_pace (get (pace no_policy ()));
  let missing_locus = get (B.add_locus base "new") in
  attempt "catalog is not zero" (pace missing_locus ~loci:[ "new" ] ());
  [%expect
    {|partial pool: daily-pace-balance-support-unknown:bank:jpy
foreign unsupported: daily-pace-balance-support-unknown:wallet:eur
duplicate: daily-pace-duplicate-coordinate
unknown measure: unknown-measure
mixed: daily-pace-pool-measure-mismatch
nonzero unknown amount: daily-pace-balance-amount-unknown:bank:jpy
7 0 0 0 0
7 1000 200 800 114
catalog is not zero: daily-pace-balance-support-unknown:new:jpy|}]

let%expect_test
    "daily pace uses calendar days including leap centuries and refuses invalid horizons" =
  let base = get (B.of_string fixture) in
  List.iter
    [
      ("2026-12-31", "2027-01-01");
      ("2024-02-28", "2024-03-01");
      ("1900-02-28", "1900-03-01");
      ("2000-02-28", "2000-03-01");
      ("2100-02-28", "2100-03-01");
      ("2026-10-01", "2026-11-01");
      ("0001-01-01", "0401-01-01");
      ("0001-01-01", "9999-12-31");
    ]
    ~f:(fun (observed_at, end_exclusive) ->
      Stdio.printf "%s..%s: %d\n" observed_at end_exclusive
        (get (pace base ~observed_at ~end_exclusive ())).remaining_days);
  List.iter
    [
      ("same", "2026-10-07", "2026-10-07");
      ("reversed", "2026-10-07", "2026-10-06");
      ("impossible", "2026-02-30", "2026-03-01");
      ("not leap", "1900-02-29", "1900-03-01");
      ("bad end", "2026-10-07", "2026-13-01");
      ("year zero", "0000-01-01", "0001-01-01");
      ("no trim", "2026-10-07 ", "2026-10-14");
      ("bad spelling", "2026-1-01", "2026-10-14");
    ]
    ~f:(fun (name, observed_at, end_exclusive) ->
      Stdio.printf "%s: %s\n" name
        (match pace base ~observed_at ~end_exclusive () with
        | Ok _ -> "unexpected success"
        | Error why -> why));
  [%expect
    {|2026-12-31..2027-01-01: 1
2024-02-28..2024-03-01: 2
1900-02-28..1900-03-01: 1
2000-02-28..2000-03-01: 2
2100-02-28..2100-03-01: 1
2026-10-01..2026-11-01: 31
0001-01-01..0401-01-01: 146097
0001-01-01..9999-12-31: 3652058
same: daily-pace-non-positive-horizon
reversed: daily-pace-non-positive-horizon
impossible: invalid-date
not leap: invalid-date
bad end: invalid-date
year zero: invalid-date
no trim: invalid-date
bad spelling: invalid-date|}]

let%expect_test
    "daily pace keeps huge foreign quanta and floors rather than hides negative deficits" =
  let huge = "1234567890123456789012345678901234567890" in
  let text =
    String.substr_replace_all fixture ~pattern:"(wallet jpy 1000)"
      ~with_:("(wallet jpy 1000) (wallet eur " ^ huge ^ ")")
  in
  let base = get (B.of_string text) in
  let foreign =
    {
      (plan "foreign") with
      day = "2026-10-08";
      measure = "eur";
      changes = [ ("wallet", Z.of_int (-500)); ("food", Z.of_int 500) ];
    }
  in
  let book = cold (get (B.put_plan base ~replace:false foreign)) in
  let answer = get (pace book ~measure:"eur" ~end_exclusive:"2026-10-10" ()) in
  print_pace answer;
  Stdio.printf "formatted: %s eur/day\n" (B.format book "eur" answer.daily_pace_quanta);
  let deficit =
    get
      (B.put_plan base ~replace:true
         {
           (plan "planned") with
           changes = [ ("wallet", Z.of_int (-1001)); ("food", Z.of_int 1001) ];
         })
  in
  print_pace (get (pace deficit ()));
  let negative =
    get
      (B.of_string
         (String.substr_replace_all fixture ~pattern:"(wallet jpy 1000)" ~with_:"(wallet jpy -1000)"))
  in
  print_pace (get (pace negative ()));
  [%expect
    {|3 1234567890123456789012345678901234567890 500 1234567890123456789012345678901234567390 411522630041152263004115226300411522463
formatted: 4115226300411522630041152263004115224.63 eur/day
7 1000 1001 -1 -1
7 -1000 200 -1200 -172|}]

let budget id : B.budget =
  {
    id;
    start_day = "2026-10-01";
    end_exclusive = "2026-11-01";
    measure = "jpy";
    allocations = [ ("living", Z.of_int 20000); ("reserve", Z.zero) ];
    expense_loci = [ "food" ];
    actual_routes = [ ("food", Some "living") ];
    plan_routes = [ ("planned", "food", Some "living") ];
  }

let review book = get (B.budget_review book ~id:"cycle" ~observed_at:"2026-10-07")

let print_budget (answer : B.budget_review) =
  List.iter answer.rows ~f:(fun (row : B.budget_row) ->
      Stdio.printf "%s %s %s %s %s %s\n" row.purpose (Z.to_string row.allocated)
        (Z.to_string row.spent) (Z.to_string row.planned) (Z.to_string row.remaining)
        (Z.to_string row.after_known));
  Stdio.printf "unrouted %d/%d unmanaged %d/%d\n"
    (List.length answer.unrouted_actual)
    (List.length answer.unrouted_plans)
    (List.length answer.unmanaged_actual)
    (List.length answer.unmanaged_plans)

let%expect_test
    "budget allocations, recorded spending and open pressure survive codec and rebalance" =
  let base = get (B.of_string fixture) in
  let base =
    get
      (B.put_plan base ~replace:true
         {
           (plan "planned") with
           changes = [ ("wallet", Z.of_int (-3000)); ("food", Z.of_int 3000) ];
         })
  in
  let base = get (B.put_entry base ~replace:false (entry "spent" 5000) ~plan:None) in
  let before = B.to_string base in
  let book = cold (get (B.put_budget base ~replace:false (budget "cycle"))) in
  print_budget (review book);
  let answer = review book in
  let living = List.hd_exn answer.rows in
  Stdio.printf "sources: %s %s; v4: %b\n" (List.hd_exn living.actuals).source_id
    (List.hd_exn living.plans).source_id
    (String.is_substring (B.to_string book) ~substring:"(bakhlo-daily 4)");
  let moved =
    cold
      (get
         (B.rebalance_budget book ~id:"cycle" ~from_purpose:"living" ~to_purpose:"reserve"
            ~amount:(Z.of_int 4000)))
  in
  print_budget (review moved);
  Stdio.printf "physical unchanged: %b; old input unchanged: %b; daily unchanged: %b\n"
    (String.equal (quantity base "wallet" "jpy") (quantity moved "wallet" "jpy"))
    (String.equal before (B.to_string base))
    (Z.equal (get (pace base ())).daily_pace_quanta (get (pace moved ())).daily_pace_quanta);
  [%expect
    {|living 20000 5000 3000 15000 12000
reserve 0 0 0 0 0
unrouted 0/0 unmanaged 0/0
sources: spent planned; v4: true
living 16000 5000 3000 11000 8000
reserve 4000 0 0 4000 4000
unrouted 0/0 unmanaged 0/0
physical unchanged: true; old input unchanged: true; daily unchanged: true|}]

let%expect_test "budget routes remain independent and missing is not explicitly unmanaged" =
  let base = get (B.of_string fixture) in
  let base = get (B.put_entry base ~replace:false (entry "spent" 500) ~plan:None) in
  let split = { (budget "cycle") with plan_routes = [ ("planned", "food", Some "reserve") ] } in
  let book = cold (get (B.put_budget base ~replace:false split)) in
  print_budget (review book);
  let missing =
    cold (get (B.put_budget book ~replace:true { split with actual_routes = []; plan_routes = [] }))
  in
  print_budget (review missing);
  let unknown = review missing in
  Stdio.printf "unrouted sources: %s=%s %s=%s\n" (List.hd_exn unknown.unrouted_actual).source_id
    (Z.to_string (List.hd_exn unknown.unrouted_actual).quanta)
    (List.hd_exn unknown.unrouted_plans).source_id
    (Z.to_string (List.hd_exn unknown.unrouted_plans).quanta);
  let unmanaged =
    cold
      (get
         (B.put_budget missing ~replace:true
            {
              split with
              actual_routes = [ ("food", None) ];
              plan_routes = [ ("planned", "food", None) ];
            }))
  in
  print_budget (review unmanaged);
  let paid = get (B.put_entry book ~replace:false (entry "payment" 200) ~plan:(Some "planned")) in
  print_budget (review (cold paid));
  [%expect
    {|living 20000 500 0 19500 19500
reserve 0 0 200 0 -200
unrouted 0/0 unmanaged 0/0
living 20000 0 0 20000 20000
reserve 0 0 0 0 0
unrouted 1/1 unmanaged 0/0
unrouted sources: spent=500 planned=200
living 20000 0 0 20000 20000
reserve 0 0 0 0 0
unrouted 0/0 unmanaged 1/1
living 20000 700 0 19300 19300
reserve 0 0 0 0 0
unrouted 0/0 unmanaged 0/0|}]

let%expect_test
    "budget query follows occurrence corrections, refunds, overdue plans and closed terminals" =
  let base = get (B.of_string fixture) in
  let base = get (B.put_budget base ~replace:false (budget "cycle")) in
  let base = get (B.put_plan base ~replace:true { (plan "planned") with day = "2026-09-30" }) in
  let recorded = get (B.put_entry base ~replace:false (entry "spent" 500) ~plan:None) in
  print_budget (review recorded);
  let future =
    get
      (B.put_entry recorded ~replace:true
         { (entry "spent" 700) with day = "2026-10-08" }
         ~plan:None)
  in
  print_budget (review future);
  let outside =
    get
      (B.put_entry recorded ~replace:true
         { (entry "spent" 700) with day = "2026-09-30" }
         ~plan:None)
  in
  print_budget (review outside);
  let paid =
    get
      (B.put_entry recorded ~replace:false
         { (entry "payment" 200) with day = "2026-10-07" }
         ~plan:(Some "planned"))
  in
  print_budget (review paid);
  let refund =
    {
      (entry "refund" 500) with
      day = "2026-10-07";
      reversal_of = Some "spent";
      effects = [ posting "wallet" "jpy" 500 None; posting "food" "jpy" (-500) None ];
    }
  in
  let refunded = get (B.put_entry paid ~replace:false refund ~plan:None) in
  print_budget (review (cold refunded));
  let cancelled = get (B.cancel_plan recorded ~id:"planned" ~day:"2026-10-07") in
  print_budget (review (cold cancelled));
  let end_plan =
    get (B.put_plan recorded ~replace:true { (plan "planned") with day = "2026-11-01" })
  in
  print_budget (review end_plan);
  [%expect
    {|living 20000 500 200 19500 19300
reserve 0 0 0 0 0
unrouted 0/0 unmanaged 0/0
living 20000 0 200 20000 19800
reserve 0 0 0 0 0
unrouted 0/0 unmanaged 0/0
living 20000 0 200 20000 19800
reserve 0 0 0 0 0
unrouted 0/0 unmanaged 0/0
living 20000 700 0 19300 19300
reserve 0 0 0 0 0
unrouted 0/0 unmanaged 0/0
living 20000 200 0 19800 19800
reserve 0 0 0 0 0
unrouted 0/0 unmanaged 0/0
living 20000 500 0 19500 19500
reserve 0 0 0 0 0
unrouted 0/0 unmanaged 0/0
living 20000 500 0 19500 19500
reserve 0 0 0 0 0
unrouted 0/0 unmanaged 0/0|}]

let%expect_test "budget protects net expense per plan without spending prospective refunds" =
  let base = get (B.of_string fixture) in
  let incoming =
    { (plan "incoming") with changes = [ ("wallet", Z.of_int 200); ("food", Z.of_int (-200)) ] }
  in
  let mixed =
    {
      (plan "mixed") with
      changes = [ ("wallet", Z.of_int (-50)); ("food", Z.of_int (-50)); ("food", Z.of_int 100) ];
    }
  in
  let base = get (B.put_plan base ~replace:false incoming) in
  let base = get (B.put_plan base ~replace:false mixed) in
  let b =
    {
      (budget "cycle") with
      plan_routes =
        [
          ("planned", "food", Some "living");
          ("incoming", "food", Some "living");
          ("mixed", "food", Some "living");
        ];
    }
  in
  let book = cold (get (B.put_budget base ~replace:false b)) in
  print_budget (review book);
  let row = List.hd_exn (review book).rows in
  Stdio.printf "retained lines: %d\n" (List.length row.plans);
  [%expect
    {|living 20000 0 250 20000 19750
reserve 0 0 0 0 0
unrouted 0/0 unmanaged 0/0
retained lines: 4|}]

let%expect_test
    "budgets refuse ambiguous definitions and stale plan references without modifying the base" =
  let base = get (B.of_string fixture) in
  let attempt name result =
    Stdio.printf "%s: %s\n" name
      (match result with Ok _ -> "unexpected success" | Error why -> why)
  in
  let put b = B.put_budget base ~replace:false b in
  let b = budget "cycle" in
  attempt "empty ID" (put { b with id = "" });
  attempt "empty period" (put { b with end_exclusive = b.start_day });
  attempt "invalid date" (put { b with start_day = "2026-02-30" });
  attempt "unknown currency" (put { b with measure = "usd" });
  attempt "negative allocation" (put { b with allocations = [ ("living", Z.neg Z.one) ] });
  attempt "duplicate purpose" (put { b with allocations = b.allocations @ [ ("living", Z.zero) ] });
  attempt "empty purpose" (put { b with allocations = [ ("", Z.zero) ] });
  attempt "duplicate locus" (put { b with expense_loci = [ "food"; "food" ] });
  attempt "untracked" (put { b with actual_routes = [ ("bank", Some "living") ] });
  attempt "unknown purpose" (put { b with actual_routes = [ ("food", Some "missing") ] });
  attempt "duplicate actual route"
    (put { b with actual_routes = b.actual_routes @ b.actual_routes });
  attempt "duplicate plan route" (put { b with plan_routes = b.plan_routes @ b.plan_routes });
  attempt "unknown plan" (put { b with plan_routes = [ ("missing", "food", Some "living") ] });
  attempt "plan measure" (put { b with measure = "eur" });
  attempt "plan missing locus"
    (put
       {
         b with
         expense_loci = [ "bank" ];
         actual_routes = [];
         plan_routes = [ ("planned", "bank", Some "living") ];
       });
  let book = get (put b) in
  let before = B.to_string book in
  attempt "duplicate budget" (B.put_budget book ~replace:false b);
  attempt "unknown edit" (B.put_budget book ~replace:true { b with id = "missing" });
  attempt "stale plan locus"
    (B.put_plan book ~replace:true
       { (plan "planned") with changes = [ ("wallet", Z.of_int (-200)); ("bank", Z.of_int 200) ] });
  attempt "stale plan currency"
    (B.put_plan book ~replace:true { (plan "planned") with measure = "eur" });
  attempt "same purpose"
    (B.rebalance_budget book ~id:b.id ~from_purpose:"living" ~to_purpose:"living" ~amount:Z.one);
  attempt "zero transfer"
    (B.rebalance_budget book ~id:b.id ~from_purpose:"living" ~to_purpose:"reserve" ~amount:Z.zero);
  attempt "too much"
    (B.rebalance_budget book ~id:b.id ~from_purpose:"living" ~to_purpose:"reserve"
       ~amount:(Z.of_int 20001));
  attempt "unknown destination"
    (B.rebalance_budget book ~id:b.id ~from_purpose:"living" ~to_purpose:"missing" ~amount:Z.one);
  attempt "before period" (B.budget_review book ~id:b.id ~observed_at:"2026-09-30");
  attempt "exclusive end" (B.budget_review book ~id:b.id ~observed_at:"2026-11-01");
  attempt "invalid observation" (B.budget_review book ~id:b.id ~observed_at:"2026-02-30");
  Stdio.printf "unchanged: %b\n" (String.equal before (B.to_string book));
  [%expect
    {|empty ID: invalid-budget-id
empty period: invalid-budget-period
invalid date: invalid-date
unknown currency: measure-scale-not-supplied
negative allocation: negative-budget-allocation
duplicate purpose: duplicate-budget-purpose
empty purpose: invalid-budget-purpose
duplicate locus: duplicate-budget-locus
untracked: untracked-budget-locus
unknown purpose: unknown-budget-purpose
duplicate actual route: duplicate-budget-actual-route
duplicate plan route: duplicate-budget-plan-route
unknown plan: unknown-budget-plan
plan measure: budget-plan-measure-mismatch
plan missing locus: budget-plan-locus-missing
duplicate budget: duplicate-budget
unknown edit: unknown-budget
stale plan locus: budget-plan-locus-missing
stale plan currency: budget-plan-measure-mismatch
same purpose: same-budget-purpose
zero transfer: non-positive-budget-transfer
too much: insufficient-budget-allocation
unknown destination: unknown-budget-purpose
before period: budget-observation-outside-period
exclusive end: budget-observation-outside-period
invalid observation: invalid-date
unchanged: true|}]

let%expect_test "budget supply, codec and huge multicurrency quantities stay explicit" =
  let base = get (B.of_string fixture) in
  Stdio.printf "old unavailable: %b\n" (Option.is_none (B.budgets base));
  Stdio.printf "%s\n"
    (match B.budget_review base ~id:"cycle" ~observed_at:"2026-10-07" with
    | Ok _ -> "unexpected success"
    | Error why -> why);
  let text =
    B.to_string base
    |> String.substr_replace_all ~pattern:"(bakhlo-daily 3)" ~with_:"(bakhlo-daily 4)"
  in
  let empty = get (B.of_string (text ^ "(budgets (provided))")) in
  Stdio.printf "explicit empty: %b\n" (Poly.equal (B.budgets (cold empty)) (Some []));
  let huge = Z.of_string "1234567890123456789012345678901234567890" in
  let foreign =
    {
      (budget "eur-cycle") with
      measure = "eur";
      allocations = [ ("foreign", huge) ];
      actual_routes = [ ("food", Some "foreign") ];
      plan_routes = [];
    }
  in
  let base = get (B.put_budget base ~replace:false (budget "cycle")) in
  let book = cold (get (B.put_budget base ~replace:false foreign)) in
  let fx_spent =
    {
      (entry "eur-spent" 0) with
      effects = [ posting "wallet" "eur" (-123) None; posting "food" "eur" 123 None ];
    }
  in
  let book = cold (get (B.put_entry book ~replace:false fx_spent ~plan:None)) in
  let answer = get (B.budget_review book ~id:"eur-cycle" ~observed_at:"2026-10-07") in
  let row = List.hd_exn answer.rows in
  Stdio.printf "foreign: %s %s %s; jpy spent: %s\n" (Z.to_string row.allocated)
    (Z.to_string row.spent) (Z.to_string row.remaining)
    (Z.to_string (List.hd_exn (review book).rows).spent);
  let printed = B.to_string book in
  Stdio.printf
    "stable: %b, old-version field refused: %b, missing field refused: %b, unknown field refused: %b\n"
    (String.equal printed (B.to_string (cold book)))
    (Result.is_error
       (B.of_string
          (String.substr_replace_all printed ~pattern:"(bakhlo-daily 4)" ~with_:"(bakhlo-daily 3)")))
    (Result.is_error (B.of_string text))
    (Result.is_error (B.of_string (printed ^ "(mystery 1)")));
  [%expect
    {|old unavailable: true
budgets-not-supplied
explicit empty: true
foreign: 1234567890123456789012345678901234567890 123 1234567890123456789012345678901234567767; jpy spent: 0
stable: true, old-version field refused: true, missing field refused: true, unknown field refused: true|}]
