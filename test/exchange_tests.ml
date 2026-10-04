open Base
module D = Loam_domain
module E = Loam_application.Exchange_evidence
module S = Loam_application.Actual_source
module Q = Loam_application.Current_quantity_query
module F = Fixtures
module M = Exchange_model
module O = Source_oracle

let ok = function Ok value -> value | Error _ -> failwith "valid Exchange refused"
let key token = F.identifier D.Identifier.Effect_key.of_string token
let fact event source destination : E.fact = { event = F.id event; source = key source; destination = key destination }
let effect_of ({ key = token; measure; quanta } : M.change) =
  D.Effect.create ~key:(Option.map token ~f:key)
    ~locus:(F.identifier D.Identifier.Locus.of_string "here")
    ~measure:(F.identifier D.Identifier.Measure.of_string measure) ~quantity:(D.Quantity.of_quanta quanta)
;;
let event token changes = F.observation ~id:(F.id token) ~effects:(List.map changes ~f:effect_of)
let command events exchanges : S.command =
  { events; exchanges; reversals = []; relations = []; discharges = []; corrections = []; validity_corrections = []
  ; validities = List.map events ~f:(fun event -> F.base_validity (D.Event.id event) "2026-10-03")
  ; descriptions = []; merchants = []; original_amounts = []
  }
;;
let equal_fact (a : E.fact) (b : E.fact) =
  D.Identifier.Event.equal a.event b.event && D.Identifier.Effect_key.equal a.source b.source &&
  D.Identifier.Effect_key.equal a.destination b.destination
;;

let%expect_test "all independent Exchange shapes correspond to selection, source and ordinary gates" =
  let exchanged = ref 0 and sourced = ref 0 and ordinary = ref 0 in
  let claim = fact "e" "source" "destination" in
  let shapes = M.shapes () in
  List.iter shapes ~f:(fun changes ->
    let original = event "e" changes in
    let memory = F.memory [ original ] in
    let admitted = E.create ~events:memory ~corrections:[] ~facts:[ claim ] in
    F.require (Bool.equal (M.admitted changes M.selected) (Result.is_ok admitted)) "selection differs from original-token list/sum model";
    (match admitted with
     | Error _ -> ()
     | Ok evidence ->
       Int.incr exchanged;
       let selected = Option.value_exn (E.find_by_event evidence (F.id "e")) in
       F.require (List.equal equal_fact [ claim ] (E.facts evidence) && F.equal_event original (E.event selected) &&
         equal_fact claim (E.fact selected)) "facts/Event selection payload lost";
       F.require (F.equal_effect (List.hd_exn (D.Event.effects original)) (E.source_effect selected) &&
         F.equal_effect (List.nth_exn (D.Event.effects original) 1) (E.destination_effect selected)) "key selection altered Effect";
       F.require (Option.is_none (E.find_by_event evidence (F.id "unknown"))) "missing evidence became Exchange");
    let with_claim = S.create (command [ original ] [ claim ]) in
    let without = S.create (command [ original ] []) in
    F.require (Bool.equal (M.admitted changes M.selected && M.nonzero changes) (Result.is_ok with_claim)) "Exchange balance exemption bypassed shape/nonzero";
    F.require (Bool.equal (M.ordinary changes) (Result.is_ok without)) "ordinary per-Measure admission drifted";
    if Result.is_ok with_claim then Int.incr sourced;
    if Result.is_ok without then Int.incr ordinary);
  F.require (List.length shapes = 9216 && !exchanged = 122 && !sourced = 74 && !ordinary = 80) "executed product correspondence counts";
  Stdlib.Printf.printf "9216 original-Effect shapes: 122 Exchange, 74 nonzero source, 80 ordinary admissions; no generic exemption\n";
  [%expect {| 9216 original-Effect shapes: 122 Exchange, 74 nonzero source, 80 ordinary admissions; no generic exemption |}]
;;

let%expect_test "Exchange keys, correction interference and diagnostics preserve exact retained meaning" =
  let huge = Z.shift_left Z.one 180 in
  let changes : M.change list =
    [ { key = Some " source\027\n "; measure = " jpy "; quanta = Z.neg huge }
    ; { key = Some "destination"; measure = "usd"; quanta = Z.one }
    ; { key = None; measure = " jpy "; quanta = Z.minus_one }
    ] in
  let original = event " e " changes in
  let others = [ F.event "o"; F.event "p" ] in
  let claim = fact " e " " source\027\n " "destination" in
  let memory = F.memory (original :: others) in
  let qualified = ok (E.create ~events:memory ~corrections:[ F.edge "o" "p" ] ~facts:[ claim ]) in
  F.require (List.equal F.equal_event (original :: others) (D.Event_memory.events (E.source_events qualified)) &&
    List.equal F.equal_edge [ F.edge "o" "p" ] (E.corrections qualified)) "retained memory/relation was pruned";
  let permuted = ok (E.create ~events:(F.memory (List.rev (original :: others))) ~corrections:[ F.edge "o" "p" ] ~facts:[ claim ]) in
  F.require (F.equal_event (E.event (Option.value_exn (E.find_by_event qualified claim.event)))
    (E.event (Option.value_exn (E.find_by_event permuted claim.event)))) "representation became Exchange authority";
  let reordered = event " e " (List.rev changes) in
  let reordered_selection = Option.value_exn (E.find_by_event
    (ok (E.create ~events:(F.memory [ reordered ]) ~corrections:[] ~facts:[ claim ])) claim.event) in
  F.require (F.equal_effect (E.source_effect reordered_selection) (List.hd_exn (D.Event.effects original)) &&
    F.equal_effect (E.destination_effect reordered_selection) (List.nth_exn (D.Event.effects original) 1) &&
    F.equal_event reordered (E.event reordered_selection)) "key selection used positions or normalized Effects";
  (match E.create ~events:memory ~corrections:[] ~facts:[ { claim with source = key "source"; destination = key "absent" } ] with
   | Error (Missing_effect { side = Source; key = missing; position = 1; event = _ }) -> F.require (D.Identifier.Effect_key.equal missing (key "source")) "source-first exact key witness"
   | _ -> failwith "missing/trimmed source key silently recovered");
  (match E.create ~events:memory ~corrections:[] ~facts:[ { claim with destination = key "absent" } ] with
   | Error (Missing_effect { side = Destination; position = 1; event = _; key = _ }) -> ()
   | _ -> failwith "missing destination erased");
  (match E.create ~events:memory ~corrections:[] ~facts:[ { claim with destination = claim.source } ] with
   | Error (Same_measure _) -> () | _ -> failwith "same Effect accepted as both sides");
  (match E.create ~events:memory ~corrections:[] ~facts:[ claim; { claim with source = key "missing" } ] with
   | Error (Repeated_event { first_position = 1; position = 2; event = _ }) -> ()
   | _ -> failwith "duplicate did not precede key resolution");
  (match E.create ~events:memory ~corrections:[] ~facts:[ claim; claim ] with
   | Error (Repeated_event _) -> () | _ -> failwith "identical exchange silently deduplicated");
  (match E.create ~events:memory ~corrections:[] ~facts:[ fact "missing" "s" "d"; fact "missing" "s" "d" ] with
   | Error (Unknown_event { position = 1; event = _ }) -> () | _ -> failwith "later duplicate preempted first closure failure");
  List.iter (List.cartesian_product [ " e "; "o"; "missing" ] [ " e "; "o"; "missing" ]) ~f:(fun (a, b) ->
    let edge = F.edge a b in
    let result = E.create ~events:memory ~corrections:[ edge ] ~facts:[ claim ] in
    if String.equal a " e " || String.equal b " e " then
      (match result with Error (Correction_mentions_event { position = 1; event = id }) ->
         F.require (D.Identifier.Event.equal id claim.event) "correction endpoint witness"
       | _ -> failwith "target/replacement/open correction allowed")
    else F.require (Result.is_ok result) "Exchange boundary unexpectedly graph-admitted unrelated raw relation");
  let second = event "second"
    [ M.{ key = Some " source\027\n "; measure = " jpy "; quanta = Z.of_int (-3) }
    ; M.{ key = Some "destination"; measure = "usd"; quanta = Z.of_int 2 } ] in
  let second_claim = { claim with event = F.id "second" } in
  let dual = ok (S.create (command [ original; second ] [ second_claim; claim ])) in
  F.require (List.equal equal_fact [ second_claim; claim ] (E.facts (S.exchanges dual)) &&
    D.Quantity.equal (D.Effect.quantity (E.source_effect (Option.value_exn (E.find_by_event (S.exchanges dual) (F.id "second")))))
      (D.Quantity.of_quanta (Z.of_int (-3)))) "fact order or Event-local shared keys lost";
  let raw = { (command (original :: others) [ claim ]) with corrections = [ F.edge "o" "missing" ] } in
  (match S.create raw with Error (Corrections _) -> () | _ -> failwith "full source skipped raw correction admission");
  (match S.create { raw with corrections = [ F.edge " e " "o" ]; exchanges = [ claim ] } with
   | Error (Exchanges (Correction_mentions_event _)) -> () | _ -> failwith "source correction retargeted exchange");
  F.require (List.equal equal_fact [ claim ] (E.facts qualified)) "old admitted memory mutated";
  let source = M.{ key = Some "source"; measure = "jpy"; quanta = Z.minus_one } in
  let destination = M.{ key = Some "destination"; measure = "usd"; quanta = Z.one } in
  let extra unit quantity : M.change = { key = None; measure = unit; quanta = Z.of_int quantity } in
  let plain = fact "e" "source" "destination" in
  let admit changes = E.create ~events:(F.memory [ event "e" changes ]) ~corrections:[] ~facts:[ plain ] in
  (match admit [ { source with quanta = Z.one }; { destination with quanta = Z.minus_one } ] with
   | Error (Source_not_negative { quantity; event = _; position = 1 }) -> F.require (D.Quantity.equal quantity (D.Quantity.of_quanta Z.one)) "source selected-sign witness"
   | _ -> failwith "destination/total errors preempted selected source sign");
  (match admit [ source; { destination with quanta = Z.zero } ] with
   | Error (Destination_not_positive { quantity; event = _; position = 1 }) -> F.require (D.Quantity.equal quantity D.Quantity.zero) "destination selected-sign witness"
   | _ -> failwith "net sign replaced selected destination sign");
  (match admit [ { source with quanta = Z.one }; { destination with measure = "jpy"; quanta = Z.minus_one } ] with
   | Error (Same_measure _) -> () | _ -> failwith "sign errors preempted dimensional distinction");
  (match admit [ source; destination; extra "eur" 0 ] with Error (Third_measure { effect_position = 3; position = 1; event = _; measure = _ }) -> () | _ -> failwith "third Measure disappeared");
  (match admit [ source; destination; extra "jpy" 1 ] with Error (Source_total_not_negative { total; event = _; measure = _; position = 1 }) -> F.require (D.Quantity.equal total D.Quantity.zero) "source net-zero witness" | _ -> failwith "selected sign replaced net sign");
  (match admit [ source; destination; extra "usd" (-2) ] with Error (Destination_total_not_positive _) -> () | _ -> failwith "destination total allowed net reversal");
  let with_zero = event "e" [ source; destination; extra "usd" 0 ] in
  F.require (Result.is_ok (admit [ source; destination; extra "usd" 0 ])) "selection gate narrowed unselected neutral Effect";
  (match S.create (command [ with_zero ] [ plain ]) with Error (Zero_effect { event_position = 1; effect_position = 3; event = _ }) -> () | _ -> failwith "Exchange bypassed retained zero policy");
  let unclaimed = event "unclaimed" [ source; destination ] in
  (match S.create (command [ event "e" [ source; destination ]; unclaimed ] [ plain ]) with
   | Error (Unbalanced_measure { event; event_position = 2; measure; residual }) ->
     F.require (D.Identifier.Event.equal event (F.id "unclaimed") && String.equal (D.Identifier.Measure.to_string measure) "jpy" && D.Quantity.equal residual (D.Quantity.of_quanta Z.minus_one)) "unclaimed residual/order changed"
   | _ -> failwith "one claim exempted an unrelated Event");
  Stdlib.Printf.printf "exact/control keys and huge amounts; ordered closure/duplicates/sign totals; correction participation refuses, no global/zero exemption\n";
  [%expect {| exact/control keys and huge amounts; ordered closure/duplicates/sign totals; correction participation refuses, no global/zero exemption |}]
;;

let%expect_test "Exchange source connects to all four support meanings without rates or implicit support" =
  let wallet = F.coordinate "wallet" and usd = F.coordinate ~unit:"usd" "wallet" in
  let offset = F.coordinate "offset" and quiet = F.coordinate "quiet" and stale = F.coordinate "stale" in
  let huge = Z.shift_left Z.one 180 in
  let selected token (coordinate : D.Effect_coordinate.t) quantity = D.Effect.create ~key:(Some (key token)) ~locus:coordinate.locus
    ~measure:coordinate.measure ~quantity:(D.Quantity.of_quanta quantity) in
  let exchanged = F.observation ~id:(F.id "e") ~effects:[ selected "source" wallet (Z.neg huge); selected "destination" usd Z.one; F.change wallet Z.minus_one ] in
  let ordinary = F.observation ~id:(F.id "x") ~effects:[ F.change wallet Z.one; F.change offset Z.minus_one; F.change stale Z.one; F.change stale Z.minus_one ] in
  let events = [ exchanged; ordinary ] in
  let raw = { (command events [ fact "e" "source" "destination" ]) with
    descriptions = [ { event = F.id "e"; text = "recognition only" } ];
    merchants = [ { event = F.id "e"; disposition = Nonmerchant } ];
    original_amounts = [ { root = F.id "e"; measure = F.identifier D.Identifier.Measure.of_string "eur"; quantity = D.Quantity.of_quanta (Z.of_int 17) } ] } in
  let source = ok (S.create raw) in
  let image source reflected = ok (Q.create ~source ~zero_origins:[ offset ] ~openings:[ { coordinate = usd; opening_event = F.id "e" } ]
    ~groups:[ { reflected_roots = reflected; assertions = [ F.assertion wallet (Z.of_int 100) ] } ]
    ~presence:(Some { reflected_roots = [ F.id "e" ]; coordinates = [ quiet; stale ] })) in
  let permuted = { raw with events = List.rev events; validities = List.rev raw.validities; descriptions = []; merchants = []; original_amounts = [] } in
  List.iter [ source; ok (S.create permuted) ] ~f:(fun source ->
    List.iter [ []; [ F.id "e" ] ] ~f:(fun reflected ->
      let query = image source reflected in
      let remaining = if List.is_empty reflected then events else [ ordinary ] in
      List.iter [ offset, O.sum_events events offset, `Origin; usd, O.sum_events events usd, `Opening;
        wallet, Z.add (Z.of_int 100) (O.sum_events remaining wallet), `Assertion ] ~f:(fun (coordinate, expected, premise) ->
        match Q.query query coordinate with
        | Ok (Exact answer) ->
          F.require (Z.equal expected (D.Quantity.quanta (Q.quantity answer))) "Measure-specific original-Effect arithmetic changed";
          (match premise, Q.premise answer with
           | `Origin, Zero_origin -> ()
           | `Opening, Opening { coordinate; opening_event } -> F.require (F.same_coordinate coordinate usd && D.Identifier.Event.equal opening_event (F.id "e")) "opening witness changed"
           | `Assertion, Current_assertion asserted -> let module P = Loam_application.Current_quantity_projection in
             F.require (Z.equal (D.Quantity.quanta (P.delta asserted)) (O.sum_events remaining wallet)) "assertion independent cut changed"
           | _ -> failwith "Exchange changed support premise")
        | _ -> failwith "Exchange converted an exact supported coordinate");
      F.require (not (O.touches_events [ ordinary ] quiet) && O.touches_events [ ordinary ] stale && Z.equal (O.sum_events [ ordinary ] stale) Z.zero) "touch oracle fixture";
      (match Q.query query quiet, Q.query query stale with Ok (Known_present _), Error (Support_unknown _) -> () | _ -> failwith "Exchange changed touch-vs-delta presence")));
  let unsupported = ok (Q.create ~source ~zero_origins:[] ~openings:[] ~groups:[] ~presence:None) in
  (match Q.query unsupported wallet, Q.query unsupported usd with Error (Support_unknown _), Error (Support_unknown _) -> () | _ -> failwith "exchange activity created support");
  let selected = Option.value_exn (E.find_by_event (S.exchanges source) (F.id "e")) in
  F.require (F.equal_event exchanged (E.event selected) && List.equal F.equal_event events (D.Event_memory.events (E.source_events (S.exchanges source)))) "source/query lost neutral Event/claim";
  let revision = F.identifier D.Identifier.Validity_revision.of_string "date-e" in
  let redated = ok (S.create { raw with validities = raw.validities @ [ Revision { id = revision; event = F.id "e"; valid_on = "1900-01-01" } ];
    validity_corrections = [ { target = Base_ref (F.id "e"); replacement = revision } ] }) in
  F.require (F.equal_event exchanged (E.event (Option.value_exn (E.find_by_event (S.exchanges redated) (F.id "e"))))) "date history inferred Exchange replacement";
  (match D.Movement.validate (D.Event.effects exchanged) with Error _ -> () | Ok _ -> failwith "Exchange became narrower ordinary Movement");
  Stdlib.Printf.printf "exact signed Measure-specific sums/cuts/opening; known-present/unknown distinct; metadata/date independent, no rate or activity-derived support\n";
  [%expect {| exact signed Measure-specific sums/cuts/opening; known-present/unknown distinct; metadata/date independent, no rate or activity-derived support |}]
;;
