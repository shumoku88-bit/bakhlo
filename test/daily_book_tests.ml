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

let party s =
  Result.ok_or_failwith
    (Result.map_error (D.Identifier.External_party.of_string s) ~f:(fun _ -> "party"))

let entry id n : B.entry =
  {
    id;
    day = "2026-10-03";
    memo = Some "食費";
    effects = [ posting "wallet" "jpy" (-n) None; posting "food" "jpy" n None ];
    reversal_of = None;
    exchange = None;
    original_amount = None;
    merchant = None;
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

(* Deliberately restricted to entry facts: not equality of canonical books. *)
let entry_view book =
  let module R = Bakhlo_sexp.Records_book in
  List.map
    (R.entries (B.to_records book))
    ~f:(fun e -> Sexplib0.Sexp.to_string (R.encode_payload (R.Entry e)))

let%expect_test "daily identical entry facts need independent observation cuts" =
  let base = get (B.of_string fixture) in
  let unreflected = get (B.put_entry base ~replace:false (entry "e" 100) ~plan:None) in
  let unreflected = get (B.of_string (B.to_string unreflected)) in
  let reflected =
    get
      (B.of_string
         (String.substr_replace_all (B.to_string unreflected) ~pattern:"(reflected)"
            ~with_:"(reflected e)"))
  in
  let unsupported_base =
    get
      (B.of_string
         (String.substr_replace_all fixture
            ~pattern:"(observations (observation (reflected) (quantities (wallet jpy 1000))))"
            ~with_:"(observations)"))
  in
  let unsupported = get (B.put_entry unsupported_base ~replace:false (entry "e" 100) ~plan:None) in
  Stdio.printf "same entries: %b\n"
    (List.equal String.equal (entry_view unreflected) (entry_view reflected)
    && List.equal String.equal (entry_view unreflected) (entry_view unsupported));
  Stdio.printf "wallet: %s / %s\n"
    (quantity unreflected "wallet" "jpy")
    (quantity reflected "wallet" "jpy");
  Stdio.printf "missing support: %s\n" (quantity unsupported "wallet" "jpy");
  [%expect {|same entries: true
wallet: 900 / 1000
missing support: unknown|}]

let%expect_test "daily identical actual facts do not infer scheduled completion" =
  let base = get (B.of_string fixture) in
  let actual = entry "payment" 200 in
  let unlinked = get (B.put_entry base ~replace:false actual ~plan:None) in
  let completed = get (B.put_entry base ~replace:false actual ~plan:(Some "planned")) in
  let unlinked = get (B.of_string (B.to_string unlinked)) in
  let completed = get (B.of_string (B.to_string completed)) in
  Stdio.printf "same entries: %b\n"
    (List.equal String.equal (entry_view unlinked) (entry_view completed));
  Stdio.printf "wallet: %s / %s\n"
    (quantity unlinked "wallet" "jpy")
    (quantity completed "wallet" "jpy");
  Stdio.printf "open plans: %d / %d\n"
    (List.length (B.open_plans unlinked))
    (List.length (B.open_plans completed));
  [%expect {|same entries: true
wallet: 800 / 800
open plans: 1 / 0|}]

let%expect_test "daily data preserves explicit exchange and exact foreign quantities" =
  let base = get (B.of_string fixture) in
  let e : B.entry =
    {
      id = "fx";
      day = "2026-10-03";
      memo = None;
      reversal_of = None;
      original_amount = None;
      merchant = None;
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

let%expect_test "calculator expressions are exact and do not round or accept malformed inputs" =
  let book = get (B.of_string fixture) in
  let check measure text =
    match B.parse_amount book measure text with
    | Ok n -> Stdio.printf "%s => %s\n" text (Z.to_string n)
    | Error why -> Stdio.printf "%s => %s\n" text why
  in
  check "jpy" "500+300";
  check "jpy" "2+3*4";
  check "jpy" "(2+3)*4";
  check "jpy" "10-3-2";
  check "jpy" "１，０００＋５００";
  check "jpy" "2×(3＋4)";
  check "eur" "12.50+3.75";
  check "eur" "10/4";
  check "eur" "0.001*1000";
  check "jpy" "2500/3";
  check "eur" "10/3";
  check "jpy" "500/0";
  check "jpy" "500+";
  check "jpy" "1000-1200";
  check "jpy" "1,00+2";
  check "jpy" "3+2)";
  check "jpy" "2/0*0";
  [%expect {|
500+300 => 800
2+3*4 => 14
(2+3)*4 => 20
10-3-2 => 5
１，０００＋５００ => 1500
2×(3＋4) => 14
12.50+3.75 => 1625
10/4 => 250
0.001*1000 => 100
2500/3 => indivisible-amount
10/3 => indivisible-amount
500/0 => division-by-zero
500+ => invalid-amount
1000-1200 => non-positive-amount
1,00+2 => invalid-amount
3+2) => invalid-amount
2/0*0 => division-by-zero
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

let%expect_test "canonical daily reflected correction preserves root cut, not old quantity or date" =
  let base = get (B.of_string fixture) in
  let original = get (B.put_entry base ~replace:false (entry "e" 100) ~plan:None) in
  let reflected =
    get
      (B.of_string
         (String.substr_replace_all (B.to_string original) ~pattern:"(reflected)"
            ~with_:"(reflected e)"))
  in
  let corrected book =
    cold
      (get
         (B.put_entry book ~replace:true
            { (entry "e" 6) with day = "1900-01-01"; memo = Some "corrected" } ~plan:None))
  in
  let unreflected = corrected original and reflected = corrected reflected in
  let fresh = cold (get (B.put_entry reflected ~replace:false (entry "fresh" 20) ~plan:None)) in
  Stdio.printf "wallet: old=%s; corrected unreflected=%s, reflected=%s, fresh=%s\n"
    (quantity original "wallet" "jpy") (quantity unreflected "wallet" "jpy")
    (quantity reflected "wallet" "jpy") (quantity fresh "wallet" "jpy");
  let selected = Option.value_exn (B.find_entry fresh "e") in
  Stdio.printf "current identity/date: %s %s; rows=%d; food=%s; bank=%s\n"
    selected.id selected.day (B.entry_count fresh) (quantity fresh "food" "jpy")
    (quantity fresh "bank" "jpy");
  let text = B.to_string fresh in
  let reflected_row = "(reflected \"e\")" in
  Fixtures.require (String.is_substring text ~substring:reflected_row) "missing cut fixture";
  Stdio.printf "bad cuts refuse: missing=%b, duplicate=%b; original snapshot unchanged=%b\n"
    (Result.is_error
       (B.of_string
          (String.substr_replace_all text ~pattern:reflected_row ~with_:"(reflected missing)")))
    (Result.is_error
       (B.of_string
          (String.substr_replace_all text ~pattern:reflected_row ~with_:"(reflected e e)")))
    (String.equal "2026-10-03" (Option.value_exn (B.find_entry original "e")).day);
  [%expect {|wallet: old=900; corrected unreflected=994, reflected=1000, fresh=980
current identity/date: e 1900-01-01; rows=2; food=26; bank=unknown
bad cuts refuse: missing=true, duplicate=true; original snapshot unchanged=true|}]

let%expect_test "canonical daily refund correction refuses broken inversion without losing actual refund" =
  let base = get (B.of_string fixture) in
  let original = get (B.put_entry base ~replace:false (entry "e" 10) ~plan:None) in
  let refund = { (entry "refund" (-10)) with reversal_of = Some "e" } in
  let reversed = cold (get (B.put_entry original ~replace:false refund ~plan:None)) in
  let before = B.to_string reversed in
  let dated =
    cold
      (get
         (B.put_entry reversed ~replace:true
            { (entry "e" 10) with day = "1900-01-01"; memo = Some "corrected date" } ~plan:None))
  in
  Stdio.printf "target amount correction refuses=%b; refund amount correction refuses=%b\n"
    (Result.is_error (B.put_entry reversed ~replace:true (entry "e" 6) ~plan:None))
    (Result.is_error
       (B.put_entry reversed ~replace:true { refund with effects = (entry "refund" (-6)).effects }
          ~plan:None));
  Stdio.printf "date-only correction admits: %s; target=%s; rows=%d; wallet=%s\n"
    (Option.value_exn (B.find_entry dated "e")).day
    (Option.value_exn (Option.value_exn (B.find_entry dated "refund")).reversal_of)
    (B.entry_count dated) (quantity dated "wallet" "jpy");
  Stdio.printf "refused source unchanged=%b; bank=%s\n"
    (String.equal before (B.to_string reversed)) (quantity dated "bank" "jpy");
  [%expect {|target amount correction refuses=true; refund amount correction refuses=true
date-only correction admits: 1900-01-01; target=e; rows=2; wallet=1000
refused source unchanged=true; bank=unknown|}]

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

let%expect_test "parse_signed_amount admits zero, negative, positive at configured scale" =
  let book = get (B.of_string fixture) in
  let check m text =
    match B.parse_signed_amount book m text with
    | Ok n -> Stdio.printf "%s %s -> %s\n" m text (Z.to_string n)
    | Error why -> Stdio.printf "%s %s -> error:%s\n" m text why
  in
  check "jpy" "100";
  check "jpy" "+100";
  check "jpy" "-100";
  check "jpy" "0";
  check "jpy" "-0";
  check "jpy" "100.5";
  check "eur" "10.50";
  check "eur" "+0.05";
  check "eur" "-12.34";
  check "eur" "0";
  check "eur" "10.123";
  check "unknown" "100";
  [%expect {|
    jpy 100 -> 100
    jpy +100 -> 100
    jpy -100 -> -100
    jpy 0 -> 0
    jpy -0 -> 0
    jpy 100.5 -> error:amount-precision
    eur 10.50 -> 1050
    eur +0.05 -> 5
    eur -12.34 -> -1234
    eur 0 -> 0
    eur 10.123 -> error:amount-precision
    unknown 100 -> error:unknown-measure
  |}]

let%expect_test "observe_quantities updates current balance and persists across roundtrip" =
  let base = get (B.of_string fixture) in
  Stdio.printf "initial wallet: %s\n" (quantity base "wallet" "jpy");
  let obs1 = get (B.observe_quantities base [ ("wallet", "jpy", Z.of_int 5000) ]) in
  Stdio.printf "after obs1: %s\n" (quantity obs1 "wallet" "jpy");
  let obs2 = get (B.observe_quantities obs1 [ ("bank", "jpy", Z.of_int 120000) ]) in
  Stdio.printf "after obs2 (wallet, bank): %s, %s\n" (quantity obs2 "wallet" "jpy") (quantity obs2 "bank" "jpy");
  let re_obs = get (B.observe_quantities obs2 [ ("wallet", "jpy", Z.of_int 4200) ]) in
  Stdio.printf "after re_obs (wallet, bank): %s, %s\n" (quantity re_obs "wallet" "jpy") (quantity re_obs "bank" "jpy");
  let cold_book = get (B.of_string (B.to_string re_obs)) in
  Stdio.printf "cold after re_obs (wallet, bank): %s, %s\n" (quantity cold_book "wallet" "jpy") (quantity cold_book "bank" "jpy");
  let err_unapproved = B.observe_quantities base [ ("unapproved_locus", "jpy", Z.of_int 100) ] in
  let err_unknown_measure = B.observe_quantities base [ ("wallet", "unknown", Z.of_int 100) ] in
  let err_zero_origin = B.observe_quantities base [ ("food", "jpy", Z.of_int 100) ] in
  Stdio.printf "unapproved: %s\n" (match err_unapproved with Error e -> e | Ok _ -> "ok");
  Stdio.printf "unknown measure: %s\n" (match err_unknown_measure with Error e -> e | Ok _ -> "ok");
  Stdio.printf "zero origin collision: %s\n" (match err_zero_origin with Error e -> e | Ok _ -> "ok");
  [%expect {|
    initial wallet: 1000
    after obs1: 5000
    after obs2 (wallet, bank): 5000, 120000
    after re_obs (wallet, bank): 4200, 120000
    cold after re_obs (wallet, bank): 4200, 120000
    unapproved: locus-not-approved
    unknown measure: measure-scale-not-supplied
    zero origin collision: support-admission
  |}]

let%expect_test "observation after an incremental record reflects that record once" =
  let base = get (B.of_string fixture) in
  let spent = get (B.put_entry base ~replace:false (entry "after_obs" 100) ~plan:None) in
  Stdio.printf "after spend: %s\n" (quantity spent "wallet" "jpy");
  let observed = get (B.observe_quantities spent [ ("wallet", "jpy", Z.of_int 900) ]) in
  let cold = get (B.of_string (B.to_string observed)) in
  Stdio.printf "observed: %s, cold: %s\n" (quantity observed "wallet" "jpy")
    (quantity cold "wallet" "jpy");
  [%expect {|
    after spend: 900
    observed: 900, cold: 900
  |}]

let%expect_test "set_locus_label validates, updates labels and preserves across roundtrip" =
  let base = get (B.of_string fixture) in
  Stdio.printf "initial label wallet: %s, help: %s\n" (B.label base "wallet") (B.help base "wallet");
  let updated = get (B.set_locus_label base ~id:"wallet" ~label:"Personal Wallet" ~help:"Primary cash wallet" ()) in
  Stdio.printf "after set_locus_label: %s, help: %s\n" (B.label updated "wallet") (B.help updated "wallet");
  let cold = get (B.of_string (B.to_string updated)) in
  Stdio.printf "cold after roundtrip: %s, help: %s\n" (B.label cold "wallet") (B.help cold "wallet");
  let updated2 = get (B.set_locus_label updated ~id:"wallet" ~label:"Cash Wallet" ()) in
  Stdio.printf "after label only update: %s, help: %s\n" (B.label updated2 "wallet") (B.help updated2 "wallet");
  let err_unapproved = B.set_locus_label base ~id:"nonexistent" ~label:"Test" () in
  let err_empty_label = B.set_locus_label base ~id:"wallet" ~label:"   " () in
  let err_control_char = B.set_locus_label base ~id:"wallet" ~label:"Wallet\n1" () in
  Stdio.printf "unapproved: %s\n" (match err_unapproved with Error e -> e | Ok _ -> "ok");
  Stdio.printf "empty label: %s\n" (match err_empty_label with Error e -> e | Ok _ -> "ok");
  Stdio.printf "control char: %s\n" (match err_control_char with Error e -> e | Ok _ -> "ok");
  [%expect {|
    initial label wallet: 財布, help: 現金
    after set_locus_label: Personal Wallet, help: Primary cash wallet
    cold after roundtrip: Personal Wallet, help: Primary cash wallet
    after label only update: Cash Wallet, help: Primary cash wallet
    unapproved: locus-not-approved
    empty label: invalid-label
    control char: invalid-label
  |}]

let%expect_test "original amount retains positive facts across monolithic and records codecs without inferring rates or support" =
  let base = get (B.of_string fixture) in
  let e : B.entry = {
    id = "orig_tx";
    day = "2026-10-03";
    memo = Some "Paris coffee";
    effects = [ posting "wallet" "jpy" (-1200) None; posting "food" "jpy" 1200 None ];
    reversal_of = None;
    exchange = None;
    original_amount = Some ("eur", Z.of_int 750);
    merchant = None;
  } in
  let book = get (B.put_entry base ~replace:false e ~plan:None) in
  let stored = Option.value_exn (B.find_entry book "orig_tx") in
  Stdio.printf "found orig: %s %s\n" (fst (Option.value_exn stored.original_amount)) (Z.to_string (snd (Option.value_exn stored.original_amount)));
  let mono_bytes = B.to_string book in
  Stdio.printf "mono has orig: %b\n" (Base.String.is_substring mono_bytes ~substring:"(original-amount (amount \"eur\" 750))");
  let cold_mono = get (B.of_string mono_bytes) in
  let cold_stored = Option.value_exn (B.find_entry cold_mono "orig_tx") in
  Stdio.printf "cold mono match: %b\n" (Option.equal (fun (m1, q1) (m2, q2) -> String.equal m1 m2 && Z.equal q1 q2) stored.original_amount cold_stored.original_amount);
  let rec_bytes = B.to_records_string book in
  let cold_rec = get (B.of_string rec_bytes) in
  let cold_rec_stored = Option.value_exn (B.find_entry cold_rec "orig_tx") in
  Stdio.printf "cold rec match: %b\n" (Option.equal (fun (m1, q1) (m2, q2) -> String.equal m1 m2 && Z.equal q1 q2) stored.original_amount cold_rec_stored.original_amount);
  (* Support and balance unaffected *)
  Stdio.printf "wallet jpy: %s, food jpy: %s\n" (quantity book "wallet" "jpy") (quantity book "food" "jpy");
  Stdio.printf "wallet eur unchanged: %s\n" (quantity book "wallet" "eur");
  (* Reversals keep target original amount, inverse has None *)
  let refund : B.entry = {
    id = "orig_refund";
    day = "2026-10-04";
    memo = Some "Refund";
    effects = [ posting "wallet" "jpy" 1200 None; posting "food" "jpy" (-1200) None ];
    reversal_of = Some "orig_tx";
    exchange = None;
    original_amount = None;
    merchant = None;
  } in
  let rev_book = get (B.put_entry book ~replace:false refund ~plan:None) in
  let target_in_rev = Option.value_exn (B.find_entry rev_book "orig_tx") in
  let rev_in_rev = Option.value_exn (B.find_entry rev_book "orig_refund") in
  Stdio.printf "rev target orig: %b, rev entry orig: %b\n" (Option.is_some target_in_rev.original_amount) (Option.is_some rev_in_rev.original_amount);
  (* Syntax / domain validation: non-positive amount *)
  let bad_zero = Base.String.substr_replace_first mono_bytes ~pattern:"(original-amount (amount \"eur\" 750))" ~with_:"(original-amount (amount \"eur\" 0))" in
  let bad_neg = Base.String.substr_replace_first mono_bytes ~pattern:"(original-amount (amount \"eur\" 750))" ~with_:"(original-amount (amount \"eur\" -10))" in
  Stdio.printf "bad zero: %s\n" (match B.of_string bad_zero with Error e -> e | Ok _ -> "ok");
  Stdio.printf "bad neg: %s\n" (match B.of_string bad_neg with Error e -> e | Ok _ -> "ok");
  (* Unregistered Measure is explicitly refused by admit *)
  let unreg_entry : B.entry = { e with id = "unreg_tx"; original_amount = Some ("usd", Z.of_int 100) } in
  let unreg_res = B.put_entry base ~replace:false unreg_entry ~plan:None in
  Stdio.printf "unregistered measure refused: %s\n" (match unreg_res with Error e -> e | Ok _ -> "ok");
  let bad_unreg_sexp = Base.String.substr_replace_first mono_bytes ~pattern:"(original-amount (amount \"eur\" 750))" ~with_:"(original-amount (amount \"usd\" 100))" in
  Stdio.printf "unregistered measure sexp refused: %s\n" (match B.of_string bad_unreg_sexp with Error e -> e | Ok _ -> "ok");
  (* Registered scale 0 (JPY) is allowed and formats without decimals *)
  let scale0_entry : B.entry = { e with id = "scale0_tx"; original_amount = Some ("jpy", Z.of_int 5000) } in
  let scale0_book = get (B.put_entry base ~replace:false scale0_entry ~plan:None) in
  let scale0_stored = Option.value_exn (B.find_entry scale0_book "scale0_tx") in
  Stdio.printf "scale 0 stored: %s %s\n" (fst (Option.value_exn scale0_stored.original_amount)) (B.format scale0_book (fst (Option.value_exn scale0_stored.original_amount)) (snd (Option.value_exn scale0_stored.original_amount)));
  let scale0_cold = get (B.of_string (B.to_string scale0_book)) in
  Stdio.printf "scale 0 roundtrip: %b\n" (Option.is_some (B.find_entry scale0_cold "scale0_tx"));
  [%expect {|
    found orig: eur 750
    mono has orig: true
    cold mono match: true
    cold rec match: true
    wallet jpy: -200, food jpy: 1200
    wallet eur unchanged: unknown
    rev target orig: true, rev entry orig: false
    bad zero: non-positive-amount
    bad neg: non-positive-amount
    unregistered measure refused: measure-scale-not-supplied
    unregistered measure sexp refused: measure-scale-not-supplied
    scale 0 stored: jpy 5000
    scale 0 roundtrip: true
  |}]
let%expect_test "event merchant classification LOAM-compatible end-to-end semantics" =
  let module M = Bakhlo_application.Event_merchants in
  let base = get (B.of_string fixture) in
  let e1 : B.entry = {
    id = "e_merch";
    day = "2026-10-03";
    memo = Some "Lunch at cafe";
    effects = [ posting "wallet" "jpy" (-1200) None; posting "food" "jpy" 1200 None ];
    reversal_of = None;
    exchange = None;
    original_amount = None;
    merchant = None;
  } in
  let e2 : B.entry = {
    id = "e_nonmerch";
    day = "2026-10-03";
    memo = Some "Peer transfer";
    effects = [ posting "wallet" "jpy" (-500) None; posting "food" "jpy" 500 None ];
    reversal_of = None;
    exchange = None;
    original_amount = None;
    merchant = None;
  } in
  let book = get (B.put_entry base ~replace:false e1 ~plan:None) in
  let book = get (B.put_entry book ~replace:false e2 ~plan:None) in

  (* 1. Initial state is Unresolved (None), distinct from Nonmerchant *)
  let stored_unresolved = Option.value_exn (B.find_entry book "e_merch") in
  Stdio.printf "unresolved is None: %b\n" (Option.is_none stored_unresolved.merchant);

  let party_shop = party "coffee-shop" in
  let classified_shop = get (B.classify_merchant book ~id:"e_merch" ~disposition:(M.Merchant party_shop)) in
  let entry_shop = Option.value_exn (B.find_entry classified_shop "e_merch") in
  (match entry_shop.merchant with
  | Some (M.Merchant p) -> Stdio.printf "classified merchant: %s\n" (D.Identifier.External_party.to_string p)
  | _ -> Stdio.printf "unexpected merchant state\n");

  (* 3. Nonmerchant classification *)
  let classified_both = get (B.classify_merchant classified_shop ~id:"e_nonmerch" ~disposition:M.Nonmerchant) in
  let entry_nonmerch = Option.value_exn (B.find_entry classified_both "e_nonmerch") in
  (match entry_nonmerch.merchant with
  | Some M.Nonmerchant -> Stdio.printf "classified nonmerchant: true\n"
  | _ -> Stdio.printf "unexpected nonmerchant state\n");

  (* 4. S-expression & Records codec roundtrip *)
  let mono_bytes = B.to_string classified_both in
  Stdio.printf "mono has merchant party: %b\n"
    (Base.String.is_substring mono_bytes ~substring:"(merchant (party \"coffee-shop\"))");
  Stdio.printf "mono has nonmerchant: %b\n"
    (Base.String.is_substring mono_bytes ~substring:"(merchant (nonmerchant))");
  let cold_mono = get (B.of_string mono_bytes) in
  let cold_e1 = Option.value_exn (B.find_entry cold_mono "e_merch") in
  let cold_e2 = Option.value_exn (B.find_entry cold_mono "e_nonmerch") in
  Stdio.printf "cold mono e1 match: %b; cold mono e2 match: %b\n"
    (Poly.equal cold_e1.merchant entry_shop.merchant) (Poly.equal cold_e2.merchant entry_nonmerch.merchant);

  let rec_bytes = B.to_records_string classified_both in
  Stdio.printf "rec has merchant party: %b\n"
    (Base.String.is_substring rec_bytes ~substring:"(merchant(party coffee-shop))"
     || Base.String.is_substring rec_bytes ~substring:"(merchant (party coffee-shop))");
  Stdio.printf "rec has nonmerchant: %b\n"
    (Base.String.is_substring rec_bytes ~substring:"(merchant(nonmerchant))"
     || Base.String.is_substring rec_bytes ~substring:"(merchant (nonmerchant))");
  let cold_rec = get (B.of_string rec_bytes) in
  let rec_e1 = Option.value_exn (B.find_entry cold_rec "e_merch") in
  let rec_e2 = Option.value_exn (B.find_entry cold_rec "e_nonmerch") in
  Stdio.printf "cold rec e1 match: %b; cold rec e2 match: %b\n"
    (Poly.equal rec_e1.merchant entry_shop.merchant) (Poly.equal rec_e2.merchant entry_nonmerch.merchant);

  (* Old formats without merchant read as None (Unresolved) *)
  let old_v1 = "(bakhlo-daily 1) (scope corrected-entries explicit-plans) (measures (measure jpy 0)) (labels (provided)) (approved-loci (provided wallet food)) (entries (entry \"e_old\" (date \"2026-10-01\") (memo (none)) (postings (posting wallet jpy -100 (none)) (posting food jpy 100 (none))) (reversal-of (none)))) (plans) (support (zero-origin) (openings) (observations) (presence (not-supplied)))" in
  let loaded_v1 = get (B.of_string old_v1) in
  let old_e = Option.value_exn (B.find_entry loaded_v1 "e_old") in
  Stdio.printf "old v1 entry merchant is None: %b\n" (Option.is_none old_e.merchant);

  (* 5. Duplicate refusal: reclassification / replacement explicitly rejected *)
  let repeat_res = B.classify_merchant classified_both ~id:"e_merch" ~disposition:M.Nonmerchant in
  Stdio.printf "repeat classification refused: %s\n"
    (match repeat_res with Error e -> e | Ok _ -> "ok");

  let replace_res = B.put_entry classified_both ~replace:true { entry_shop with merchant = Some M.Nonmerchant } ~plan:None in
  Stdio.printf "put_entry replacing merchant refused: %s\n"
    (match replace_res with Error e -> e | Ok _ -> "ok");

  (* Same merchant preserved on edit is accepted *)
  let memo_edit_res = B.put_entry classified_both ~replace:true { entry_shop with memo = Some "Updated memo" } ~plan:None in
  Stdio.printf "put_entry preserving merchant succeeds: %b\n" (Result.is_ok memo_edit_res);

  (* 6. Unknown event refusal *)
  let unknown_res = B.classify_merchant classified_both ~id:"nonexistent" ~disposition:M.Nonmerchant in
  Stdio.printf "unknown event refused: %s\n"
    (match unknown_res with Error e -> e | Ok _ -> "ok");

  (* 7. Invalid party ID refusal *)
  let bad_tab_party = party "bad\tshop" in
  let bad_tab_res = B.classify_merchant book ~id:"e_merch" ~disposition:(M.Merchant bad_tab_party) in
  Stdio.printf "party with tab refused: %s\n"
    (match bad_tab_res with Error e -> e | Ok _ -> "ok");
  (* 8. Reversal noninheritance: reversing classified entry produces unresolved reversal *)
  let refund : B.entry = {
    id = "refund_merch";
    day = "2026-10-04";
    memo = Some "Refund";
    effects = [ posting "wallet" "jpy" 1200 None; posting "food" "jpy" (-1200) None ];
    reversal_of = Some "e_merch";
    exchange = None;
    original_amount = None;
    merchant = None;
  } in
  let rev_book = get (B.put_entry classified_both ~replace:false refund ~plan:None) in
  let target_in_rev = Option.value_exn (B.find_entry rev_book "e_merch") in
  let refund_in_rev = Option.value_exn (B.find_entry rev_book "refund_merch") in
  Stdio.printf "target in rev retains merchant: %b; reversal entry merchant is None: %b\n"
    (Option.is_some target_in_rev.merchant) (Option.is_none refund_in_rev.merchant);

  (* 9. Quantities and Daily Pace completely unaffected by Merchant classification *)
  Stdio.printf "wallet jpy before: %s, after: %s\n"
    (quantity book "wallet" "jpy") (quantity classified_both "wallet" "jpy");
  let pace_before = B.daily_pace book ~measure:"jpy" ~pool:[ pace_coordinate "wallet" "jpy" ] ~observed_at:"2026-10-03" ~end_exclusive:"2026-10-05" in
  let pace_after = B.daily_pace classified_both ~measure:"jpy" ~pool:[ pace_coordinate "wallet" "jpy" ] ~observed_at:"2026-10-03" ~end_exclusive:"2026-10-05" in
  Stdio.printf "pace equal: %b\n"
    (Z.equal (get pace_before).daily_pace_quanta (get pace_after).daily_pace_quanta);
  [%expect {|
    unresolved is None: true
    classified merchant: coffee-shop
    classified nonmerchant: true
    mono has merchant party: true
    mono has nonmerchant: true
    cold mono e1 match: true; cold mono e2 match: true
    rec has merchant party: true
    rec has nonmerchant: true
    cold rec e1 match: true; cold rec e2 match: true
    old v1 entry merchant is None: true
    repeat classification refused: loam: Event Merchant is already classified; replacement is not qualified
    put_entry replacing merchant refused: loam: Event Merchant is already classified; replacement is not qualified
    put_entry preserving merchant succeeds: true
    unknown event refused: loam: Merchant classification requires an existing Event
    party with tab refused: loam: Merchant party token must be a non-empty single text field
    target in rev retains merchant: true; reversal entry merchant is None: true
    wallet jpy before: -700, after: -700
    pace equal: true
  |}]

let%expect_test "bounded history support restates past pools and keeps its own encoding" =
  let base = get (B.of_string fixture) in
  let dated id day n = { (entry id n) with day } in
  let book = get (B.put_entry base ~replace:false (dated "a" "2026-10-03" 100) ~plan:None) in
  let book = get (B.put_entry book ~replace:false (dated "b" "2026-10-05" 50) ~plan:None) in
  let show = function Ok n -> Z.to_string n | Error why -> "error:" ^ why in
  let at book loci day =
    show
      (B.pool_at_end_of_day book ~measure:"jpy"
         ~pool:(List.map loci ~f:(fun locus -> pace_coordinate locus "jpy"))
         ~day)
  in
  Stdio.printf "unsupported wallet: %s\n" (at book [ "wallet" ] "2026-10-04");
  Stdio.printf "zero-origin food: %s %s\n" (at book [ "food" ] "2026-10-02")
    (at book [ "food" ] "2026-10-03");
  let bounded = get (B.with_bounded_history book [ ("wallet", "jpy", "2026-10-04") ]) in
  Stdio.printf "start: %s\n"
    (Option.value ~default:"none" (B.bounded_history_start bounded ~locus:"wallet" ~measure:"jpy"));
  List.iter [ "2026-10-02"; "2026-10-03"; "2026-10-04"; "2026-10-05"; "2026-10-06" ] ~f:(fun day ->
      Stdio.printf "wallet %s: %s\n" day (at bounded [ "wallet" ] day));
  Stdio.printf "wallet+food 2026-10-04: %s; with bank: %s\n"
    (at bounded [ "wallet"; "food" ] "2026-10-04")
    (at bounded [ "wallet"; "bank" ] "2026-10-04");
  let printed = B.to_string bounded in
  let cold = get (B.of_string printed) in
  Stdio.printf "v5: %b; stable: %b; cold wallet 2026-10-04: %s\n"
    (String.is_substring printed ~substring:"(bakhlo-daily 5)")
    (String.equal (B.to_string cold) printed)
    (at cold [ "wallet" ] "2026-10-04");
  let cleared = get (B.with_bounded_history bounded []) in
  Stdio.printf "cleared prints v3: %b\n"
    (String.is_substring (B.to_string cleared) ~substring:"(bakhlo-daily 3)");
  let conflict = get (B.with_bounded_history book [ ("food", "jpy", "2026-10-01") ]) in
  Stdio.printf "conflict: %s\n" (at conflict [ "food" ] "2026-10-04");
  let unanchored = get (B.with_bounded_history book [ ("bank", "jpy", "2026-10-01") ]) in
  Stdio.printf "unanchored: %s\n" (at unanchored [ "bank" ] "2026-10-04");
  let refusal rows =
    match B.with_bounded_history book rows with Ok _ -> "ok" | Error why -> why
  in
  Stdio.printf "duplicate: %s; date: %s; measure: %s\n"
    (refusal [ ("wallet", "jpy", "2026-10-04"); ("wallet", "jpy", "2026-10-05") ])
    (refusal [ ("wallet", "jpy", "2026-02-30") ])
    (refusal [ ("wallet", "usd", "2026-10-04") ]);
  let replace_header version text =
    String.substr_replace_first text ~pattern:"(bakhlo-daily 5)"
      ~with_:("(bakhlo-daily " ^ version ^ ")")
  in
  let parse text = match B.of_string text with Ok _ -> "ok" | Error why -> why in
  Stdio.printf "v4 header: %s; v3 with field: %s\n" (parse (replace_header "4" printed))
    (parse (replace_header "3" printed));
  let empty_v5 =
    String.substr_replace_first
      (B.to_string (get (B.with_bounded_history book [ ("wallet", "jpy", "2026-10-04") ])))
      ~pattern:"(\"wallet\" \"jpy\" \"2026-10-04\")" ~with_:""
  in
  Stdio.printf "empty v5: %s\n" (parse empty_v5);
  Stdio.printf "records: %s\n"
    (match B.to_records_string bounded with
    | _ -> "written"
    | exception Invalid_argument _ -> "refused");
  [%expect {|
    unsupported wallet: error:history-support-missing:wallet:jpy
    zero-origin food: 0 100
    start: 2026-10-04
    wallet 2026-10-02: error:history-precedes-bounded-start:wallet:jpy
    wallet 2026-10-03: 900
    wallet 2026-10-04: 900
    wallet 2026-10-05: 850
    wallet 2026-10-06: 850
    wallet+food 2026-10-04: 1000; with bank: error:history-support-missing:bank:jpy
    v5: true; stable: true; cold wallet 2026-10-04: 900
    cleared prints v3: true
    conflict: error:history-support-conflict:food:jpy
    unanchored: error:history-bounded-anchor-missing:bank:jpy
    duplicate: duplicate-bounded-history-coordinate; date: invalid-date; measure: measure-scale-not-supplied
    v4 header: unsupported-book-header; v3 with field: unsupported-field
    empty v5: empty-bounded-history
    records: refused
    |}]
