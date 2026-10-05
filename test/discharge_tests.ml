open Base
module D = Bakhlo_domain
module R = Bakhlo_application.Open_relations
module P = Bakhlo_application.Relation_discharges
module S = Bakhlo_application.Actual_source
module C = Bakhlo_application.Correction_frontier
module Q = Bakhlo_application.Current_quantity_query
module F = Fixtures
module M = Discharge_model
module RM = Relation_model
module O = Source_oracle

let ok = function Ok value -> value | Error _ -> failwith "valid discharge refused"
let id token = F.identifier D.Identifier.Relation.of_string token
let key token = F.identifier D.Identifier.Effect_key.of_string token
let party token = F.identifier D.Identifier.External_party.of_string token
let endpoint = function RM.Household -> R.Household | External token -> R.External (party token)

let relation (raw : RM.fact) : R.fact =
  {
    id = id raw.id;
    source_event = F.id raw.event;
    source_effect = key raw.key;
    debtor = endpoint raw.debtor;
    creditor = endpoint raw.creditor;
    quantity = D.Quantity.of_quanta raw.quantity;
  }

let fact ({ event; target; quantity } : M.fact) : P.fact =
  { event = F.id event; target = id target; quantity = D.Quantity.of_quanta quantity }

let f event target n : M.fact = { event; target; quantity = Z.of_int n }

let change ?token ?(unit = "jpy") ?(locus = "here") quantity =
  let coordinate = F.coordinate ~unit locus in
  D.Effect.create ~key:(Option.map token ~f:key) ~locus:coordinate.locus ~measure:coordinate.measure
    ~quantity:(D.Quantity.of_quanta quantity)

let source token quantity =
  F.observation ~id:(F.id token) ~effects:[ change ~token:"s" quantity; change (Z.neg quantity) ]

let originals = [ source "a" (Z.of_int (-2)); source "b" (Z.of_int 2); F.event "c"; F.event "d" ]

let raw_relations : RM.fact list =
  [
    {
      id = "r";
      event = "a";
      key = "s";
      debtor = Household;
      creditor = External "p";
      quantity = Z.of_int 2;
    };
    {
      id = "q";
      event = "b";
      key = "s";
      debtor = External "p";
      creditor = Household;
      quantity = Z.of_int 2;
    };
  ]

let relations = List.map raw_relations ~f:relation

let command events relations discharges : S.command =
  {
    events;
    relations;
    discharges;
    corrections = [];
    validity_corrections = [];
    validities = List.map events ~f:(fun event -> F.base_validity (D.Event.id event) "2026-10-03");
    descriptions = [];
    merchants = [];
    original_amounts = [];
    exchanges = [];
    reversals = [];
  }

let equal_fact (a : P.fact) (b : P.fact) =
  D.Identifier.Event.equal a.event b.event
  && D.Identifier.Relation.equal a.target b.target
  && D.Quantity.equal a.quantity b.quantity

let equal_endpoint (a : R.endpoint) (b : R.endpoint) =
  match (a, b) with
  | Household, Household -> true
  | External a, External b -> D.Identifier.External_party.equal a b
  | Household, External _ | External _, Household -> false

let equal_relation (a : R.fact) (b : R.fact) =
  D.Identifier.Relation.equal a.id b.id
  && D.Identifier.Event.equal a.source_event b.source_event
  && D.Identifier.Effect_key.equal a.source_effect b.source_effect
  && equal_endpoint a.debtor b.debtor
  && equal_endpoint a.creditor b.creditor
  && D.Quantity.equal a.quantity b.quantity

let check_retention qualified facts result =
  let memory = R.source_events qualified in
  F.require
    (List.equal F.equal_event (D.Event_memory.events memory)
       (D.Event_memory.events (R.source_events (P.source_relations result))))
    "discharge generation changed";
  F.require
    (List.equal equal_relation (R.facts qualified) (R.facts (P.source_relations result)))
    "relation facts changed";
  F.require
    (List.equal equal_fact facts (P.facts result)
    && List.equal equal_fact facts (List.map (P.admitted result) ~f:P.fact))
    "discharge order/payload lost";
  List.iter (P.admitted result) ~f:(fun row ->
      let fact = P.fact row in
      F.require
        (F.equal_event (P.event row)
           (Option.value_exn (D.Event_memory.find_by_id memory fact.event)))
        "Event retargeted";
      let expected = Option.value_exn (R.find_by_id qualified fact.target) in
      F.require
        (equal_relation (R.fact expected) (R.fact (P.target_relation row))
        && F.equal_event (R.source_event expected) (R.source_event (P.target_relation row))
        && F.equal_effect (R.source_effect expected) (R.source_effect (P.target_relation row)))
        "target generation/payload changed");
  F.require
    (List.equal D.Identifier.Relation.equal
       (List.map (R.admitted qualified) ~f:(fun row -> (R.fact row).id))
       (List.map (P.remainders result) ~f:(fun remainder -> (R.fact (P.relation remainder)).id)))
    "target projection order changed"

let%expect_test
    "all independent closed discharge shapes preserve exact per-target arithmetic and raw \
     correspondence" =
  F.require (RM.admitted RM.sources raw_relations) "earned independent relation model premise";
  let qualified = ok (R.create ~events:(F.memory originals) ~facts:relations) in
  let admitted = ref 0 in
  List.iter (M.shapes ()) ~f:(fun rows ->
      let facts = List.map rows ~f:fact in
      let expected = M.admitted M.events M.targets rows in
      let result = P.create ~relations:qualified ~facts in
      F.require (Bool.equal expected (Result.is_ok result)) "original-list discharge model differs";
      F.require
        (Bool.equal expected (Result.is_ok (S.create (command originals relations facts))))
        "source discharge gate differs";
      match result with
      | Error _ -> ()
      | Ok image ->
          Int.incr admitted;
          check_retention qualified facts image;
          List.iter M.targets ~f:(fun target ->
              let remainder = Option.value_exn (P.find_remainder image (id target.id)) in
              F.require
                (Z.equal
                   (D.Quantity.quanta (P.discharged_quantity remainder))
                   (M.total rows target.id)
                && Option.equal Z.equal
                     (Some (D.Quantity.quanta (P.remaining_quantity remainder)))
                     (M.remaining M.targets rows target.id)
                && List.equal equal_fact
                     (List.map (M.rows rows target.id) ~f:fact)
                     (List.map (P.discharges remainder) ~f:P.fact))
                "target index/arithmetic/bucket order differs"));
  F.require (!admitted = 109) "executed product correspondence count";
  Stdlib.Printf.printf
    "5776 closed discharge/source cases: 109 admitted; original provenance and target-order \
     partial/full/no-row remainders correspond to list/Zarith model\n";
  [%expect
    {| 5776 closed discharge/source cases: 109 admitted; original provenance and target-order partial/full/no-row remainders correspond to list/Zarith model |}]

let%expect_test
    "discharge closure, pair identity and full target bounds have ordered exact witnesses" =
  let qualified = ok (R.create ~events:(F.memory originals) ~facts:relations) in
  let create rows = P.create ~relations:qualified ~facts:(List.map rows ~f:fact) in
  (match create [ f "missing" "unknown" 0 ] with
  | Error (Unknown_event { event; position = 1 }) ->
      F.require (D.Identifier.Event.equal event (F.id "missing")) "closure Event witness"
  | _ -> failwith "unknown Event made inert");
  (match create [ f "c" "unknown" 0 ] with
  | Error (Unknown_target { target; position = 1 }) ->
      F.require (D.Identifier.Relation.equal target (id "unknown")) "target witness"
  | _ -> failwith "unrelated target ignored");
  (match create [ f "c" "r" 1; f "c" "r" 0 ] with
  | Error (Repeated_correspondence { event; target; first_position = 1; position = 2 }) ->
      F.require
        (D.Identifier.Event.equal event (F.id "c") && D.Identifier.Relation.equal target (id "r"))
        "pair witness"
  | _ -> failwith "duplicate normalized silently/local order");
  (match create [ f "a" "r" 0 ] with
  | Error (Self_discharge { event; target; position = 1 }) ->
      F.require
        (D.Identifier.Event.equal event (F.id "a") && D.Identifier.Relation.equal target (id "r"))
        "self witness"
  | _ -> failwith "self gate order");
  (match create [ f "c" "r" 0 ] with
  | Error (Nonpositive_quantity { quantity; position = 1; _ }) ->
      F.require (D.Quantity.equal quantity D.Quantity.zero) "zero witness"
  | _ -> failwith "zero accepted");
  (match create [ f "c" "r" 3 ] with
  | Error (Exceeds_target { quantity; target_quantity; position = 1; _ }) ->
      F.require
        (Z.equal (D.Quantity.quanta quantity) (Z.of_int 3)
        && Z.equal (D.Quantity.quanta target_quantity) (Z.of_int 2))
        "individual bound witness"
  | _ -> failwith "individual bound bypassed");
  (match create [ f "c" "q" 1; f "c" "r" 2; f "d" "r" 1 ] with
  | Error (Overdischarged_target { target; total; target_quantity; position = 2 }) ->
      F.require
        (D.Identifier.Relation.equal target (id "r")
        && Z.equal (D.Quantity.quanta total) (Z.of_int 3)
        && Z.equal (D.Quantity.quanta target_quantity) (Z.of_int 2))
        "full total/original position"
  | _ -> failwith "aggregate gate order");
  (match create [ f "c" "r" 2; f "d" "r" 1; f "missing" "q" 1 ] with
  | Error (Unknown_event { position = 3; _ }) -> ()
  | _ -> failwith "aggregate masked local error");
  let image = ok (create [ f "c" "r" 2; f "c" "q" 2 ]) in
  F.require
    (List.for_all (P.remainders image) ~f:(fun remainder ->
         D.Quantity.equal (P.remaining_quantity remainder) D.Quantity.zero))
    "global Event budget invented";
  let empty = ok (create []) in
  F.require
    (Option.is_none (P.find_remainder empty (id "unknown"))
    && List.for_all (P.remainders empty) ~f:(fun remainder ->
        Z.equal (D.Quantity.quanta (P.remaining_quantity remainder)) (Z.of_int 2)))
    "absence/unknown fabricated zero";
  Stdlib.Printf.printf
    "Event/target -> pair -> self/positive/individual -> aggregate full totals; one empty Event \
     fulfills two distinct targets, no global Event budget; unknown != zero\n";
  [%expect
    {| Event/target -> pair -> self/positive/individual -> aggregate full totals; one empty Event fulfills two distinct targets, no global Event budget; unknown != zero |}]

let%expect_test
    "huge exact partial discharges and source Measure survive control identities and immutable \
     rebuilding" =
  let huge = Z.shift_left Z.one 180 in
  let source_id = " source\027\n "
  and target_id = " target\027\n "
  and event_id = " later\027\n " in
  let source_event = source source_id (Z.neg huge) in
  let later =
    F.observation ~id:(F.id event_id)
      ~effects:[ change ~unit:"usd" huge; change ~unit:"usd" (Z.neg huge) ]
  in
  let second = F.event "second" in
  let target =
    {
      (relation (List.hd_exn raw_relations)) with
      id = id target_id;
      source_event = F.id source_id;
      quantity = D.Quantity.of_quanta huge;
    }
  in
  let qualified =
    ok (R.create ~events:(F.memory [ source_event; later; second ]) ~facts:[ target ])
  in
  let first : P.fact =
    { event = F.id event_id; target = id target_id; quantity = D.Quantity.of_quanta (Z.pred huge) }
  in
  let last : P.fact =
    { event = F.id "second"; target = id target_id; quantity = D.Quantity.of_quanta Z.one }
  in
  let partial = ok (P.create ~relations:qualified ~facts:[ first ]) in
  let remainder = Option.value_exn (P.find_remainder partial (id target_id)) in
  F.require
    (Z.equal (D.Quantity.quanta (P.remaining_quantity remainder)) Z.one
    && D.Identifier.Measure.equal
         (D.Effect.measure (R.source_effect (P.relation remainder)))
         (F.coordinate "here").measure)
    "precision/Measure inferred from discharge Event";
  let full = ok (P.create ~relations:qualified ~facts:[ first; last ]) in
  F.require
    (D.Quantity.equal
       (P.remaining_quantity (Option.value_exn (P.find_remainder full (id target_id))))
       D.Quantity.zero)
    "huge full remainder";
  (match
     P.create ~relations:qualified
       ~facts:[ { first with quantity = D.Quantity.of_quanta huge }; last ]
   with
  | Error (Overdischarged_target { total; target_quantity; position = 1; _ }) ->
      F.require
        (Z.equal (D.Quantity.quanta total) (Z.succ huge)
        && Z.equal (D.Quantity.quanta target_quantity) huge)
        "huge total overflow/rounding"
  | _ -> failwith "huge over-discharge accepted");
  F.require (Option.is_none (P.find_remainder partial (id "target"))) "target trimmed";
  check_retention qualified [ first ] partial;
  let collision_memory = F.memory [ source "b" (Z.of_int 2); F.event "a:r"; F.event "a" ] in
  let collision_targets =
    List.map [ "q"; "r:q" ] ~f:(fun token ->
        { (List.nth_exn relations 1) with id = id token; quantity = D.Quantity.of_quanta Z.one })
  in
  let collision_relations = ok (R.create ~events:collision_memory ~facts:collision_targets) in
  let collision_facts = [ fact (f "a:r" "q" 1); fact (f "a" "r:q" 1) ] in
  check_retention collision_relations collision_facts
    (ok (P.create ~relations:collision_relations ~facts:collision_facts));
  check_retention qualified [ first; last ]
    (ok (P.create ~relations:qualified ~facts:[ first; last ]));
  let shuffled =
    ok (R.create ~events:(F.memory [ second; later; source_event ]) ~facts:[ target ])
  in
  check_retention shuffled [ last; first ]
    (ok (P.create ~relations:shuffled ~facts:[ last; first ]));
  let smaller =
    ok
      (R.create ~events:(R.source_events qualified)
         ~facts:[ { target with quantity = D.Quantity.of_quanta Z.one } ])
  in
  F.require
    (Result.is_error (P.create ~relations:smaller ~facts:[ first ]))
    "changed target silently pruned discharges";
  let missing = ok (R.create ~events:(F.memory [ source_event; second ]) ~facts:[ target ]) in
  (match P.create ~relations:missing ~facts:[ first ] with
  | Error (Unknown_event { position = 1; _ }) -> ()
  | _ -> failwith "missing later Event treated as inert");
  F.require (Z.equal (D.Quantity.quanta (P.remaining_quantity remainder)) Z.one) "old image mutated";
  Stdlib.Printf.printf
    "exact 180-bit partial/full/overflow arithmetic, control identities and JPY target vs USD \
     discharge Event; requalification/omission refuse without mutating old remainder\n";
  [%expect
    {| exact 180-bit partial/full/overflow arithmetic, control identities and JPY target vs USD discharge Event; requalification/omission refuse without mutating old remainder |}]

let%expect_test
    "correction, Reversal and date selection never transfer or deactivate retained discharge \
     provenance" =
  let a = source "a" (Z.of_int (-2)) and b = source "b" (Z.of_int 3) in
  let c =
    F.observation ~id:(F.id "c")
      ~effects:[ change ~locus:"physical" Z.one; change ~locus:"counterpart" Z.minus_one ]
  in
  let d =
    F.observation ~id:(F.id "d")
      ~effects:[ change ~locus:"physical" Z.minus_one; change ~locus:"counterpart" Z.one ]
  in
  let e = F.event "e" in
  let facts = [ fact (f "c" "r" 1) ] in
  let raw =
    {
      (command [ a; b; c; d; e ] [ List.hd_exn relations ] facts) with
      corrections = [ F.edge "a" "b"; F.edge "c" "e" ];
      reversals = [ { target = F.id "c"; reversal = F.id "d" } ];
      descriptions = [ { event = F.id "c"; text = "retained fulfillment Event" } ];
      merchants = [ { event = F.id "c"; disposition = Nonmerchant } ];
      original_amounts =
        [
          {
            root = F.id "a";
            measure = (F.coordinate ~unit:"eur" "here").measure;
            quantity = D.Quantity.of_quanta (Z.of_int 5);
          };
        ];
      validities =
        [
          F.base_validity (F.id "a") "2026-10-03";
          F.base_validity (F.id "b") "2026-10-04";
          F.base_validity (F.id "c") "1900-01-01";
          F.base_validity (F.id "d") "1900-01-01";
          F.base_validity (F.id "e") "1900-01-01";
        ];
    }
  in
  let image = ok (S.create raw) in
  let projected = Option.value_exn (P.find_remainder (S.discharges image) (id "r")) in
  F.require
    (Z.equal (D.Quantity.quanta (P.remaining_quantity projected)) Z.one
    && F.equal_event c (P.event (List.hd_exn (P.discharges projected)))
    && F.equal_event a (R.source_event (P.relation projected)))
    "retained endpoints retargeted/deactivated";
  F.require
    (List.equal F.equal_event (C.frontier_events (S.frontier image)) [ b; d; e ])
    "discharges changed frontier";
  let prefixed = source "prefix" (Z.of_int 5) in
  let extended =
    ok
      (S.create
         {
           raw with
           events = prefixed :: raw.events;
           corrections = F.edge "prefix" "a" :: raw.corrections;
           validities = F.base_validity (F.id "prefix") "1900-01-01" :: raw.validities;
           original_amounts = [];
         })
  in
  F.require
    (Z.equal
       (D.Quantity.quanta
          (P.remaining_quantity
             (Option.value_exn (P.find_remainder (S.discharges extended) (id "r")))))
       Z.one)
    "prefix/current-root restriction invented";
  let without = ok (S.create { raw with discharges = [] }) in
  F.require
    (List.equal F.equal_event
       (C.frontier_events (S.frontier image))
       (C.frontier_events (S.frontier without)))
    "discharge selected winners";
  check_retention (S.relations image) facts (S.discharges image);
  Stdlib.Printf.printf
    "noncurrent relation source and corrected/reversed discharge Event remain original provenance; \
     earlier dates do not infer chronology; prefix rebuild preserves remainder 1\n";
  [%expect
    {| noncurrent relation source and corrected/reversed discharge Event remain original provenance; earlier dates do not infer chronology; prefix rebuild preserves remainder 1 |}]

let%expect_test
    "discharge accounting remains independent from exact/presence support and Exchange metadata" =
  let a =
    F.observation ~id:(F.id "a")
      ~effects:
        [
          change ~token:"s" ~locus:"wallet" (Z.of_int (-3));
          change ~token:"d" ~unit:"usd" ~locus:"wallet" (Z.of_int 2);
        ]
  in
  let reverse =
    F.observation ~id:(F.id "reverse")
      ~effects:
        (List.map (D.Event.effects a) ~f:(fun c ->
             D.Effect.create ~key:(D.Effect.key c) ~locus:(D.Effect.locus c)
               ~measure:(D.Effect.measure c)
               ~quantity:(D.Quantity.neg (D.Effect.quantity c))))
  in
  let c =
    F.observation ~id:(F.id "c")
      ~effects:[ change ~locus:"offset" (Z.of_int 4); change ~locus:"food" (Z.of_int (-4)) ]
  in
  let target = { (List.hd_exn relations) with quantity = D.Quantity.of_quanta (Z.of_int 3) } in
  let raw =
    {
      (command [ a; reverse; c ] [ target ] [ fact (f "c" "r" 1); fact (f "reverse" "r" 2) ]) with
      exchanges = [ { event = F.id "a"; source = key "s"; destination = key "d" } ];
      reversals = [ { target = F.id "a"; reversal = F.id "reverse" } ];
    }
  in
  let with_discharge = ok (S.create raw) and without = ok (S.create { raw with discharges = [] }) in
  let build source =
    ok
      (Q.create ~source
         ~zero_origins:[ F.coordinate "offset" ]
         ~openings:[ { coordinate = F.coordinate ~unit:"usd" "wallet"; opening_event = F.id "a" } ]
         ~groups:
           [
             {
               reflected_roots = [ F.id "a" ];
               assertions = [ F.assertion (F.coordinate "wallet") (Z.of_int 10) ];
             };
           ]
         ~presence:
           (Some
              { reflected_roots = []; coordinates = [ F.coordinate "quiet"; F.coordinate "food" ] }))
  in
  let image = build with_discharge and baseline = build without in
  List.iter
    [ F.coordinate "offset"; F.coordinate ~unit:"usd" "wallet"; F.coordinate "wallet" ]
    ~f:(fun coordinate ->
      match (Q.query image coordinate, Q.query baseline coordinate) with
      | Ok (Exact a), Ok (Exact b) ->
          F.require
            (D.Quantity.equal (Q.quantity a) (Q.quantity b))
            "fulfillment altered physical quantity/support"
      | _ -> failwith "exact support lost");
  (match (Q.query image (F.coordinate "quiet"), Q.query image (F.coordinate "food")) with
  | Ok (Known_present _), Error _ -> ()
  | _ -> failwith "discharge altered presence touch");
  let projected = Option.value_exn (P.find_remainder (S.discharges with_discharge) (id "r")) in
  F.require
    (D.Quantity.equal (P.remaining_quantity projected) D.Quantity.zero
    && Z.equal (D.Quantity.quanta (P.discharged_quantity projected)) (Z.of_int 3))
    "conditional full remainder";
  let no_support =
    ok (Q.create ~source:with_discharge ~zero_origins:[] ~openings:[] ~groups:[] ~presence:None)
  in
  F.require
    (Result.is_error (Q.query no_support (F.coordinate "wallet")))
    "fulfilled relation manufactured physical zero";
  F.require
    (Z.equal (O.sum_events raw.events (F.coordinate "wallet")) Z.zero
    && O.touches_events raw.events (F.coordinate "wallet"))
    "independent original-Effect seam";
  Stdlib.Printf.printf
    "full relation remainder 0 does not provide physical support; Exchange/Reversal facts, four \
     independent supports and cancelling-Effect touch unchanged\n";
  [%expect
    {| full relation remainder 0 does not provide physical support; Exchange/Reversal facts, four independent supports and cancelling-Effect touch unchanged |}]
