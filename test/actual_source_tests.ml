open Base
module D = Loam_domain
module S = Loam_application.Actual_source
module V = Loam_application.Actual_validity
module Frontier = Loam_application.Correction_frontier
module F = Fixtures
let ok = function Ok value -> value | Error _ -> failwith "valid base Actual source refused"
let command events corrections : S.command =
  { events; corrections; descriptions = []; validity_corrections = [];
    validities = List.map events ~f:(fun event -> F.base_validity (D.Event.id event) "2026-10-03") }
let event token changes = F.observation ~id:(F.id token) ~effects:changes

let%expect_test "ordinary base admission is not single-Measure Movement narrowing" =
  let huge = Z.shift_left Z.one 160 in
  let c = F.coordinate "wallet" and u = F.coordinate ~unit:"usd" "wallet" in
  let mixed = event "mixed" [ F.change c (Z.neg huge); F.change c huge; F.change u Z.one; F.change u Z.minus_one ] in
  F.require (Result.is_error (D.Movement.validate (D.Event.effects mixed))) "not ordinary Movement";
  let source = ok (S.create (command [ F.event "empty"; mixed ] [])) in
  F.require (List.equal F.equal_event [ F.event "empty"; mixed ]
    (D.Event_memory.events (Frontier.retained_events (S.frontier source)))) "all original occurrences";
  let admitted = ref 0 in
  List.iter [ -2; -1; 0; 1; 2 ] ~f:(fun a -> List.iter [ -2; -1; 0; 1; 2 ] ~f:(fun b ->
    List.iter [ -2; -1; 0; 1; 2 ] ~f:(fun x -> List.iter [ -2; -1; 0; 1; 2 ] ~f:(fun y ->
      let js = [ Z.mul huge (Z.of_int a); Z.mul huge (Z.of_int b) ] in
      let us = [ Z.of_int x; Z.of_int y ] in
      let changes = List.map js ~f:(F.change c) @ List.map us ~f:(F.change u) in
      (* Original values, not production maps/total getters. *)
      let expected = List.for_all (js @ us) ~f:(fun q -> not (Z.equal q Z.zero))
        && Z.equal (List.fold js ~init:Z.zero ~f:Z.add) Z.zero
        && Z.equal (List.fold us ~init:Z.zero ~f:Z.add) Z.zero in
      let actual = Result.is_ok (S.create (command [ event "e" changes ] [])) in
      F.require (Bool.equal actual expected) "625 independent per-Measure predicate cases";
      if actual then Int.incr admitted))));
  F.require (Int.equal !admitted 16) "actual admitted cases";
  Stdlib.Printf.printf "empty and mixed admitted; 625 signed/huge cases, 16 admitted\n";
  [%expect {| empty and mixed admitted; 625 signed/huge cases, 16 admitted |}]
;;

let%expect_test "every retained Event is checked, even a superseded or reflected candidate" =
  let c = F.coordinate "wallet" in
  let bad = event "a" [ F.change c Z.zero ] in
  let b = F.event "b" in
  (match S.create (command [ bad; b ] [ F.edge "a" "b" ]) with
   | Error (Zero_effect { event; event_position = 1; effect_position = 1 }) ->
     F.require (D.Identifier.Event.equal event (F.id "a")) "superseded witness"
   | _ -> failwith "bad superseded Effect silently discarded");
  let offset = event "cross" [ F.change c Z.one; F.change (F.coordinate ~unit:"usd" "other") Z.minus_one ] in
  (match S.create (command [ offset ] []) with
   | Error (Unbalanced_measure { event; event_position = 1; measure; residual }) ->
     F.require (D.Identifier.Event.equal event (F.id "cross") &&
       String.equal (D.Identifier.Measure.to_string measure) "jpy" && D.Quantity.equal residual (D.Quantity.of_quanta Z.one)) "per-Measure witness"
   | _ -> failwith "cross-dimensional numeric cancellation");
  (match S.create (command [ bad; bad ] []) with Error (Events _) -> () | _ -> failwith "identity first");
  let draft = command [ F.event "a" ] [] in
  (match S.create { draft with validities = [] } with Error (Validity (Missing_validity _)) -> () | _ -> failwith "base validity required");
  (match S.create { draft with corrections = [ F.edge "a" "missing" ] } with Error (Corrections _) -> () | _ -> failwith "correction closure");
  let neutral = F.admitted (F.memory [ bad; offset ]) [] in
  F.require (List.equal F.equal_event [ bad; offset ] (Frontier.frontier_events neutral)) "Domain and conditional frontier remain general";
  Stdlib.Printf.printf "raw retained physical/validity/frontier gates; Domain remains general\n";
  [%expect {| raw retained physical/validity/frontier gates; Domain remains general |}]
;;

let%expect_test "base validity and correction provenance survive source admission without date winners" =
  let originals = [ F.event "a"; F.event "b"; F.event "x" ] in
  let facts = [ F.base_validity (F.id "b") "1900-01-01";
    F.base_validity (F.id "x") "2026-10-03"; F.base_validity (F.id "a") "2000-02-29" ] in
  let draft : S.command = { events = originals; validities = facts; validity_corrections = []; corrections = [ F.edge "a" "b" ]; descriptions = [] } in
  let image = ok (S.create draft) in
  F.require (List.equal F.equal_event originals (D.Event_memory.events (Frontier.retained_events (S.frontier image)))) "source not pruned";
  F.require (List.equal F.equal_edge draft.corrections (Frontier.corrections (S.frontier image))) "edges retained";
  F.require (List.equal (fun a b -> D.Identifier.Event.equal (V.event a) (V.event b) && String.equal (V.valid_on a) (V.valid_on b))
    facts (V.facts (S.validity image))) "date declarations/order retained";
  let permuted = ok (S.create { draft with events = List.rev originals; validities = List.rev facts }) in
  List.iter [ image; permuted ] ~f:(fun source ->
    let terminals = Frontier.frontier_events (S.frontier source) |> List.map ~f:D.Event.id in
    F.require (List.mem terminals (F.id "b") ~equal:D.Identifier.Event.equal &&
      not (List.mem terminals (F.id "a") ~equal:D.Identifier.Event.equal)) "correction, not newer date");
  Stdlib.Printf.printf "separate dates retained; correction endpoints select terminals\n";
  [%expect {| separate dates retained; correction endpoints select terminals |}]
;;
