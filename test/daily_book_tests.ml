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

let%expect_test "flexible amount input accepts half/full-width and comma grouping, preserving exact quanta and errors" =
  let base = get (B.of_string fixture) in
  (* JPY: scale 0 *)
  let check_jpy s =
    match B.parse_amount base "jpy" s with
    | Ok n -> Stdio.printf "ok %s\n" (Z.to_string n)
    | Error err -> Stdio.printf "err %s\n" err
  in
  let check_eur s =
    match B.parse_amount base "eur" s with
    | Ok n -> Stdio.printf "ok %s\n" (Z.to_string n)
    | Error err -> Stdio.printf "err %s\n" err
  in
  check_jpy "1000";
  check_jpy "1,000";
  check_jpy "１０００";
  check_jpy "１，０００";
  check_jpy "1,234,567";
  check_jpy "１，２３４，５６７";
  check_eur "1,234.56";
  check_eur "１，２３４．５６";
  check_eur "1,234.5";
  check_eur "1,234";
  check_eur "１，２３４";
  (* Invalid grouping / delimiters *)
  check_jpy "12,34";
  check_jpy "1,2";
  check_jpy "1,00";
  check_jpy "1,2345";
  check_jpy ",1000";
  check_jpy "1000,";
  check_jpy "1,,000";
  check_jpy "1234,567";
  check_eur "1,234.5,6";
  (* Precision violations *)
  check_eur "1.234";
  check_eur "１．２３４";
  check_jpy "1000.5";
  check_jpy "１０００．５";
  check_jpy "1000.0";
  (* Non-positive amounts *)
  check_jpy "0";
  check_jpy "０";
  check_jpy "0,000";
  check_eur "0.00";
  (* Negative and invalid characters *)
  check_jpy "-1000";
  check_jpy "-1,000";
  check_jpy "ー１０００";
  check_jpy "1000yen";
  [%expect {|
ok 1000
ok 1000
ok 1000
ok 1000
ok 1234567
ok 1234567
ok 123456
ok 123456
ok 123450
ok 123400
ok 123400
err invalid-amount
err invalid-amount
err invalid-amount
err invalid-amount
err invalid-amount
err invalid-amount
err invalid-amount
err invalid-amount
err invalid-amount
err amount-precision
err amount-precision
err amount-precision
err amount-precision
err amount-precision
err non-positive-amount
err non-positive-amount
err non-positive-amount
err non-positive-amount
err invalid-amount
err invalid-amount
err invalid-amount
err invalid-amount
|}]

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

let%expect_test "obsolete budget-only schema cannot be admitted" =
  let base = B.to_string (get (B.of_string fixture)) in
  let v4 = String.substr_replace_first ~pattern:"(bakhlo-daily 3)"
      ~with_:"(bakhlo-daily 4)" base in
  let with_budget = base ^ "\n(budgets (provided))\n" in
  Stdio.printf "%b %b\n" (Result.is_error (B.of_string v4))
    (Result.is_error (B.of_string with_budget));
  [%expect {| true true |}]
