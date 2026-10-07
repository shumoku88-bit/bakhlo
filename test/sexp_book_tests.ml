open Base
module D = Bakhlo_domain
module A = Bakhlo_application
module B = Bakhlo_sexp.Book
module Q = A.Current_quantity_query

let ok = function Ok value -> value | Error _ -> failwith "expected qualified S-expression"
let require condition message = if not condition then failwith message

let initial =
  {|; Synthetic initial evidence, not a household authority.
(bakhlo 1 ordinary-quantity)
(collections (provided measures observations zero-origin) (empty events event-corrections) (not-supplied))
(measure "jpy" (decimal-scale 0))
(observation (reflected-roots) (assertion (locus "wallet") (measure "jpy") (quanta 1000)))
(zero-origin (locus "food") (measure "jpy"))
|}

let purchase =
  {|(event "purchase"
  (day (date "2000-01-10")) (description (text "元の説明\n日本語"))
  (effect (key (named "cash")) (locus "wallet") (measure "jpy") (quanta -100))
  (effect (key (unkeyed)) (locus "food") (measure "jpy") (quanta 100)))|}

let correction =
  {|(event "replacement"
  (day (date "1900-01-01")) (description (not-supplied))
  (effect (key (named "cash")) (locus "wallet") (measure "jpy") (quanta -150))
  (effect (key (unkeyed)) (locus "food") (measure "jpy") (quanta 150)))|}

let id value = ok (D.Identifier.Event.of_string value)

let coordinate locus measure : D.Effect_coordinate.t =
  {
    locus = ok (D.Identifier.Locus.of_string locus);
    measure = ok (D.Identifier.Measure.of_string measure);
  }

let value book locus measure =
  match ok (Q.query (B.image book) (coordinate locus measure)) with
  | Q.Exact value -> D.Quantity.quanta (Q.quantity value)
  | Q.Known_present _ -> failwith "unknown amount is not arithmetic"

let unknown book locus measure =
  match Q.query (B.image book) (coordinate locus measure) with
  | Error (Q.Support_unknown _) -> true
  | Ok (Q.Exact _ | Q.Known_present _) -> false

let frontier book = A.Actual_source.frontier (Q.source (B.image book))
let retained book = D.Event_memory.events (A.Correction_frontier.retained_events (frontier book))

let roundtrip book =
  let encoded = B.to_string book in
  let reopened = ok (B.of_string encoded) in
  require (String.equal (B.to_string reopened) encoded) "canonical writer not stable";
  reopened

let error_kind = function
  | B.Syntax _ -> "syntax"
  | B.Wire _ -> "wire"
  | B.Event _ -> "event"
  | B.Movement _ -> "movement"
  | B.Source _ -> "source"
  | B.Support _ -> "support"

let refused text =
  match B.of_string text with
  | Error error -> error_kind error
  | Ok _ -> failwith "malformed book admitted"

let%expect_test "S-expression book retains initial support and original correction evidence" =
  let base = ok (B.of_string initial) in
  let proposed = ok (B.append ~base ~event:purchase) in
  let added = B.document proposed |> roundtrip in
  let proposed = ok (B.correct ~base:added ~target:(id "purchase") ~event:correction) in
  let current = B.document proposed |> roundtrip in
  require
    (String.equal (B.original_bytes base) initial && phys_equal (B.base proposed) added)
    "base binding/bytes changed";
  require
    (List.length (retained current) = 2
    && List.length (A.Correction_frontier.corrections (frontier current)) = 1)
    "original Event/correction dropped";
  let source = Q.source (B.image current) in
  require
    (Option.equal String.equal
       (A.Event_descriptions.find_text (A.Actual_source.descriptions source) (id "purchase"))
       (Some "元の説明\n日本語"))
    "original description bytes changed";
  require
    (Option.is_none
       (A.Event_descriptions.find_text (A.Actual_source.descriptions source) (id "replacement")))
    "missing replacement description inherited";
  let first = List.hd_exn (retained current) in
  require
    (Option.equal D.Identifier.Effect_key.equal
       (D.Effect.key (List.hd_exn (D.Event.effects first)))
       (Some (ok (D.Identifier.Effect_key.of_string "cash"))))
    "original key lost";
  let day event =
    Option.value_exn (A.Actual_validity.find_current (A.Actual_source.validity source) (id event))
    |> A.Actual_validity.valid_on
  in
  require
    (String.equal (day "purchase") "2000-01-10" && String.equal (day "replacement") "1900-01-01")
    "original date erased/date chosen by chronology";
  let physical =
    List.map (retained current) ~f:(fun event ->
        ( D.Identifier.Event.to_string (D.Event.id event),
          List.map (D.Event.effects event) ~f:(fun change ->
              ( D.Identifier.Locus.to_string (D.Effect.locus change),
                D.Identifier.Measure.to_string (D.Effect.measure change),
                Z.to_string (D.Quantity.quanta (D.Effect.quantity change)) )) ))
  in
  require
    (Poly.equal physical
       [
         ("purchase", [ ("wallet", "jpy", "-100"); ("food", "jpy", "100") ]);
         ("replacement", [ ("wallet", "jpy", "-150"); ("food", "jpy", "150") ]);
       ])
    "retained history/order/quanta changed";
  List.iter [ base; added; current ] ~f:(fun book ->
      Stdlib.Printf.printf "wallet=%s food=%s bank-unknown=%b\n"
        (Z.to_string (value book "wallet" "jpy"))
        (Z.to_string (value book "food" "jpy"))
        (unknown book "bank" "jpy"));
  [%expect
    {|
    wallet=1000 food=0 bank-unknown=true
    wallet=900 food=100 bank-unknown=true
    wallet=850 food=150 bank-unknown=true |}]

let%expect_test "S-expression observations retain independent reflected cuts and forward references"
    =
  let source =
    {|(bakhlo 1 ordinary-quantity)
(collections (provided measures events event-corrections observations) (empty) (not-supplied zero-origin))
(event-correction (target "purchase") (replacement "replacement"))
(observation (reflected-roots "purchase") (assertion (locus "wallet") (measure "jpy") (quanta 1000)))
(observation (reflected-roots) (assertion (locus "food") (measure "jpy") (quanta 50)))
(measure "jpy" (decimal-scale 0))
|}
    ^ purchase ^ "\n" ^ correction
    ^ {|
(event "extra" (day (date "1999-12-31")) (description (text ""))
  (effect (key (unkeyed)) (locus "wallet") (measure "jpy") (quanta -4))
  (effect (key (unkeyed)) (locus "food") (measure "jpy") (quanta 4)))
|}
  in
  let book = ok (B.of_string source) |> roundtrip in
  require
    (Z.equal (value book "wallet" "jpy") (Z.of_int 996)
    && Z.equal (value book "food" "jpy") (Z.of_int 204))
    "independent cut borrowed/forgotten";
  let source = Q.source (B.image book) in
  require
    (Option.equal String.equal
       (A.Event_descriptions.find_text (A.Actual_source.descriptions source) (id "extra"))
       (Some ""))
    "empty description became missing";
  let malformed =
    String.substr_replace_first (B.to_string book) ~pattern:"(reflected-roots \"purchase\")"
      ~with_:"(reflected-roots \"absent\")"
  in
  Stdlib.print_endline (refused malformed);
  [%expect {| support |}]

let%expect_test
    "S-expression supply states, signed huge quanta, identity bytes and multiplicity survive" =
  let source =
    {|(bakhlo 1 ordinary-quantity)
(collections (provided measures events observations) (empty event-corrections) (not-supplied zero-origin))
(measure "jpy" (decimal-scale 0))
(measure "usd" (decimal-scale 2))
(observation (reflected-roots)
  (assertion (locus " wallet ") (measure "jpy") (quanta -1532495540865888858358347027150309183618739122183602177))
  (assertion (locus " wallet ") (measure "usd") (quanta 0)))
(event "\x00same-role" (day (date "2000-01-01")) (description (text "引用\"・逆斜線\\・改行\n・\x00\x7F\xFF"))
  (effect (key (unkeyed)) (locus "old-only") (measure "jpy") (quanta 1))
  (effect (key (unkeyed)) (locus "old-only") (measure "jpy") (quanta -1)))
|}
  in
  let book = ok (B.of_string source) in
  let reopened = roundtrip book in
  require
    (Z.equal (value reopened " wallet " "jpy") (Z.neg (Z.add (Z.shift_left Z.one 180) Z.one)))
    "huge signed quanta changed";
  require
    (Z.equal (value reopened " wallet " "usd") Z.zero
    && unknown reopened "wallet" "jpy" && unknown reopened "old-only" "jpy")
    "unit separation/identity/zero-net unknown changed";
  require
    (Poly.equal (B.supply reopened B.Zero_origin) B.Not_supplied
    && Poly.equal (B.supply reopened B.Event_corrections) B.Empty)
    "absence state erased";
  require
    (List.length (D.Event.effects (List.hd_exn (retained reopened))) = 2)
    "net-zero occurrences erased";
  require (String.equal (B.to_string reopened) (B.to_string book)) "control/text bytes lost";
  let event = List.hd_exn (retained reopened) in
  require
    (String.equal (D.Identifier.Event.to_string (D.Event.id event)) "\000same-role")
    "control identity changed";
  let description =
    A.Event_descriptions.find_text
      (A.Actual_source.descriptions (Q.source (B.image reopened)))
      (D.Event.id event)
  in
  require
    (Option.equal String.equal description (Some "引用\"・逆斜線\\・改行\n・\000\127\255"))
    "literal text bytes changed";
  require
    (Stdlib.String.is_valid_utf_8 (B.to_string reopened))
    "non-UTF8 source bytes must be escaped";
  let scales =
    List.map (B.measures reopened) ~f:(fun { B.id; decimal_scale } ->
        (D.Identifier.Measure.to_string id, Z.to_string decimal_scale))
  in
  require (Poly.equal scales [ ("jpy", "0"); ("usd", "2") ]) "interpretation metadata erased";
  Stdlib.print_endline "exact units/bytes/absence/multiplicity retained";
  [%expect {| exact units/bytes/absence/multiplicity retained |}]

let%expect_test "S-expression wire errors never default, filter, normalize or partly admit" =
  let replace pattern with_ = String.substr_replace_first initial ~pattern ~with_ in
  let cases =
    [
      "(bakhlo 1 ordinary-quantity)";
      replace "(empty events event-corrections)" "(empty events)";
      replace "(not-supplied)" "(not-supplied events)";
      replace "(decimal-scale 0)" "(decimal-scale 0) (decimal-scale 1)";
      replace "(decimal-scale 0)" "(decimal-scale -1)";
      replace "(reflected-roots)" "";
      replace "(quanta 1000)" "(quanta 1000) (quanta 1000)";
      replace "(quanta 1000)" "(quanta 1e3)";
      replace "(quanta 1000)" "(quanta 1.5)";
      replace "(measure \"jpy\") (quanta 1000)" "(measure \"usd\") (quanta 1000)";
      initial ^ "(scheduled-occurrence \"s\")";
      initial ^ "(measure \"jpy\" (decimal-scale 0))";
      replace "(empty events event-corrections)" "(provided events event-corrections)";
      replace "(decimal-scale 0)" "(decimal-scale 0) (future-field anything)";
    ]
  in
  List.iter cases ~f:(fun input ->
      require (String.equal (refused input) "wire") "unexpected refusal stage");
  Stdlib.print_endline (refused "(bakhlo 1 ordinary-quantity");
  Stdlib.print_endline
    (refused (replace "(zero-origin (locus \"food\")" "(zero-origin (locus \"wallet\")"));
  Stdlib.print_endline "14 wire refusals; none turned into empty or partial success";
  [%expect
    {|
    syntax
    support
    14 wire refusals; none turned into empty or partial success |}]

let%expect_test "S-expression proposals whole-admit and preserve original base on refusal" =
  let base = ok (B.of_string initial) in
  let added = B.document (ok (B.append ~base ~event:purchase)) in
  let bad = String.substr_replace_first purchase ~pattern:"(quanta -100)" ~with_:"(quanta -99)" in
  let result = B.append ~base ~event:bad in
  require
    (match result with Error (B.Movement _) -> true | Ok _ | Error _ -> false)
    "unbalanced Movement admitted";
  let duplicate_key =
    String.substr_replace_first purchase ~pattern:"(key (unkeyed))" ~with_:"(key (named \"cash\"))"
  in
  require
    (match B.append ~base ~event:duplicate_key with
    | Error (B.Event _) -> true
    | Ok _ | Error _ -> false)
    "duplicate Effect key erased";
  let missing_day =
    String.substr_replace_first purchase ~pattern:"(day (date \"2000-01-10\"))"
      ~with_:"(day (not-supplied))"
  in
  require
    (match B.append ~base ~event:missing_day with
    | Error (B.Source _) -> true
    | Ok _ | Error _ -> false)
    "missing date invented";
  let missing =
    String.substr_replace_first purchase ~pattern:"(description (text \"元の説明\\n日本語\"))" ~with_:""
  in
  require
    (match B.append ~base ~event:missing with Error (B.Wire _) -> true | Ok _ | Error _ -> false)
    "missing description defaulted";
  require
    (match B.correct ~base:added ~target:(id "missing") ~event:correction with
    | Error (B.Source _) -> true
    | Ok _ | Error _ -> false)
    "unknown correction target repaired";
  require
    (match B.append ~base:added ~event:purchase with
    | Error (B.Source _) -> true
    | Ok _ | Error _ -> false)
    "duplicate Event deduplicated";
  require
    (String.equal (B.original_bytes base) initial
    && Z.equal (value added "wallet" "jpy") (Z.of_int 900))
    "refusal mutated base";
  Stdlib.print_endline "whole proposal refusal; originals/base remain intact";
  [%expect {| whole proposal refusal; originals/base remain intact |}]

let%expect_test "v2 Locus vocabulary is independent policy, never origin or display inference" =
  let header =
    String.substr_replace_first initial ~pattern:"(bakhlo 1 ordinary-quantity)"
      ~with_:"(bakhlo 2 ordinary-quantity)"
  in
  let policy = "(locus-admission (approved \"wallet\" \"food\"))\n" in
  let base = ok (B.of_string (header ^ policy)) in
  let proposed = ok (B.admit_locus ~base ~locus:" 日用品🧺 ") in
  let added = B.document proposed |> roundtrip in
  let vocabulary book =
    Option.map (B.locus_admission book) ~f:(List.map ~f:D.Identifier.Locus.to_string)
  in
  require
    (Poly.equal (vocabulary added) (Some [ "wallet"; "food"; " 日用品🧺 " ]))
    "identity normalized or approval lost";
  require
    (phys_equal (B.base proposed) base
    && B.version added = 2
    && String.equal (B.original_bytes base) (header ^ policy))
    "base changed/upgraded implicitly";
  require
    (List.is_empty (retained added)
    && unknown added " 日用品🧺 " "jpy"
    && unknown added "日用品🧺" "jpy"
    && Z.equal (value added "wallet" "jpy") (Z.of_int 1000))
    "vocabulary invented Event/zero/alias";
  let event =
    String.substr_replace_first purchase ~pattern:"(locus \"food\")" ~with_:"(locus \" 日用品🧺 \")"
  in
  let moved = B.document (ok (B.append ~base:added ~event)) |> roundtrip in
  require
    (Z.equal (value moved "wallet" "jpy") (Z.of_int 900) && unknown moved " 日用品🧺 " "jpy")
    "activity invented support";
  require
    (Poly.equal (Q.zero_origins (B.image moved)) (Q.zero_origins (B.image base))
    && Poly.equal
         (A.Current_quantity_groups.groups (Q.source_groups (B.image moved)))
         (A.Current_quantity_groups.groups (Q.source_groups (B.image base))))
    "support/cuts changed";
  let expect_wire = function
    | Error (B.Wire _) -> ()
    | Ok _ | Error _ -> failwith "policy refusal bypassed"
  in
  expect_wire (B.append ~base ~event);
  expect_wire (B.admit_locus ~base:added ~locus:" 日用品🧺 ");
  expect_wire (B.admit_locus ~base ~locus:"");
  expect_wire (B.admit_locus ~base:(ok (B.of_string initial)) ~locus:"new");
  let blocked =
    B.to_string moved
    |> String.substr_replace_first
         ~pattern:"(locus-admission (approved \"wallet\" \"food\" \" 日用品🧺 \"))"
         ~with_:"(locus-admission (approved))"
    |> B.of_string |> ok |> roundtrip
  in
  require
    (Option.equal (List.equal D.Identifier.Locus.equal) (B.locus_admission blocked) (Some [])
    && List.length (retained blocked) = 1
    && Z.equal (value blocked "wallet" "jpy") (Z.of_int 900))
    "retained history depended on current write permission";
  expect_wire (B.append ~base:blocked ~event:correction);
  expect_wire (B.correct ~base:blocked ~target:(id "purchase") ~event:correction);
  let absent = ok (B.of_string (header ^ "(locus-admission (not-supplied))\n")) in
  require (Option.is_none (B.locus_admission absent)) "absent policy became empty/success";
  expect_wire (B.admit_locus ~base:absent ~locus:"new");
  expect_wire (B.append ~base:absent ~event:purchase);
  List.iter
    [
      header;
      header ^ policy ^ policy;
      header ^ "(locus-admission)";
      header ^ "(locus-admission (approved \"wallet\" \"wallet\"))";
      header ^ "(locus-admission (approved \"\"))";
      header ^ "(locus-admission (approved) (not-supplied))";
      header ^ "(locus-admission (approved) (role expense))";
      initial ^ policy;
    ]
    ~f:(fun bytes -> require (String.equal (refused bytes) "wire") "wire fallback");
  require (B.version (roundtrip (ok (B.of_string initial))) = 1) "legacy silently converted";
  Stdlib.print_endline
    "v2 explicit vocabulary; add/record/reopen; retained history; no zero/role/alias; policy/wire \
     refusals";
  [%expect
    {| v2 explicit vocabulary; add/record/reopen; retained history; no zero/role/alias; policy/wire refusals |}]


let%expect_test "v3 exchange keeps currencies distinct and local-currency spending stays ordinary" =
  let travel =
    {|(bakhlo 3 ordinary-quantity)
(collections
  (provided measures observations zero-origin)
  (empty events event-corrections exchanges)
  (not-supplied))
(locus-admission (approved "bank-jpy" "cash-eur" "food"))
(measure "jpy" (decimal-scale 0))
(measure "eur" (decimal-scale 2))
(observation (reflected-roots)
  (assertion (locus "bank-jpy") (measure "jpy") (quanta 10000)))
(zero-origin (locus "cash-eur") (measure "eur"))
(zero-origin (locus "food") (measure "eur"))
|}
  in
  let exchange_event =
    {|(event "exchange-out"
  (day (date "2026-10-20"))
  (description (text "cash exchange"))
  (effect (key (named "exchange-source")) (locus "bank-jpy") (measure "jpy") (quanta -10000))
  (effect (key (named "exchange-destination")) (locus "cash-eur") (measure "eur") (quanta 6000)))|}
  in
  let base = ok (B.of_string travel) in
  let exchanged =
    B.document
      (ok
         (B.append_exchange ~base ~event:exchange_event ~source:"exchange-source"
            ~destination:"exchange-destination"))
    |> roundtrip
  in
  require
    (Z.equal (value exchanged "bank-jpy" "jpy") Z.zero
    && Z.equal (value exchanged "cash-eur" "eur") (Z.of_int 6000))
    "exchange quantities changed or currencies collapsed";
  let spend =
    {|(event "local-spend"
  (day (date "2026-10-21"))
  (description (text "local meal"))
  (effect (key (unkeyed)) (locus "cash-eur") (measure "eur") (quanta -1500))
  (effect (key (unkeyed)) (locus "food") (measure "eur") (quanta 1500)))|}
  in
  let spent = B.document (ok (B.append ~base:exchanged ~event:spend)) |> roundtrip in
  let return_event =
    {|(event "exchange-back"
  (day (date "2026-10-30"))
  (description (text "return exchange"))
  (effect (key (named "exchange-source")) (locus "cash-eur") (measure "eur") (quanta -4500))
  (effect (key (named "exchange-destination")) (locus "bank-jpy") (measure "jpy") (quanta 8000)))|}
  in
  let returned =
    B.document
      (ok
         (B.append_exchange ~base:spent ~event:return_event ~source:"exchange-source"
            ~destination:"exchange-destination"))
    |> roundtrip
  in
  require
    (Z.equal (value returned "bank-jpy" "jpy") (Z.of_int 8000)
    && Z.equal (value returned "cash-eur" "eur") Z.zero
    && Z.equal (value returned "food" "eur") (Z.of_int 1500))
    "travel flow did not preserve exact per-Measure quantities";
  let source = Q.source (B.image returned) in
  require
    (List.length (A.Exchange_evidence.facts (A.Actual_source.exchanges source)) = 2)
    "exchange evidence not retained";
  let v2 =
    travel
    |> String.substr_replace_first ~pattern:"(bakhlo 3 ordinary-quantity)"
         ~with_:"(bakhlo 2 ordinary-quantity)"
    |> String.substr_replace_first ~pattern:"(empty events event-corrections exchanges)"
         ~with_:"(empty events event-corrections)"
  in
  require
    (match B.append_exchange ~base:(ok (B.of_string v2))
       ~event:exchange_event ~source:"exchange-source" ~destination:"exchange-destination" with
    | Error (B.Wire _) -> true
    | Ok _ | Error _ -> false)
    "older book silently upgraded for exchange";
  Stdlib.Printf.printf "bank-jpy=%s cash-eur=%s food-eur=%s exchanges=2\n"
    (Z.to_string (value returned "bank-jpy" "jpy"))
    (Z.to_string (value returned "cash-eur" "eur"))
    (Z.to_string (value returned "food" "eur"));
  [%expect {| bank-jpy=8000 cash-eur=0 food-eur=1500 exchanges=2 |}]
