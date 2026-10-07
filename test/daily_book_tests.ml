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
