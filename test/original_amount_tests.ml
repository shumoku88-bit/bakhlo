open Base
module D = Loam_domain
module A = Loam_application.Original_amounts
module C = Loam_application.Correction_frontier
module S = Loam_application.Actual_source
module Q = Loam_application.Current_quantity_query
module F = Fixtures
module G = Lineage_model
module O = Source_oracle

let ok = function Ok value -> value | Error _ -> failwith "valid original amount refused"
let fact root measure quantity : A.fact =
  { root = F.id root; measure = F.identifier D.Identifier.Measure.of_string measure; quantity = D.Quantity.of_quanta quantity }
;;
let equal_fact (a : A.fact) (b : A.fact) =
  D.Identifier.Event.equal a.root b.root && D.Identifier.Measure.equal a.measure b.measure && D.Quantity.equal a.quantity b.quantity
;;
let name node = Int.to_string node
let unit_name node = if node % 2 = 0 then " usd " else "usd"

(* Integer graph/model pairs and supplied integer payloads only, no product indexes. *)
let expected pairs inputs =
  let rec scan position seen = function
    | [] -> Ok ()
    | (root, amount) :: rest ->
      match List.findi seen ~f:(fun _ prior -> Int.equal prior root) with
      | Some (i, _) -> Error (`Repeated (root, i + 1, position))
      | None ->
        if amount <= 0 then Error (`Nonpositive (root, position))
        else if not (List.exists pairs ~f:(fun (r, _) -> Int.equal root r)) then Error (`Not_root (root, position))
        else scan (position + 1) (seen @ [ root ]) rest
  in
  scan 1 [] inputs
;;

let%expect_test "original amounts reuse independent graph semantics for every three-node path and sign subset" =
  let nodes = [ 0; 1; 2 ] in
  let source = List.map nodes ~f:(fun node -> F.event (name node)) in
  let graphs = ref 0 and cases = ref 0 and admitted = ref 0 in
  for mask = 0 to 511 do
    let edges = G.edges_of_mask nodes mask in
    match G.analyze ~nodes ~edges with
    | None -> () (* Graph admission is already independently qualified, not reimplemented here. *)
    | Some pairs ->
      Int.incr graphs;
      let frontier = F.admitted (F.memory source) (List.map edges ~f:(fun (a, b) -> F.edge (name a) (name b))) in
      for states = 0 to 63 do
        Int.incr cases;
        let inputs = List.filter_map nodes ~f:(fun node ->
          match states / Int.pow 4 node % 4 with
          | 0 -> None | 1 -> Some (node, -1) | 2 -> Some (node, 0) | _ -> Some (node, node + 1)) in
        let facts = List.map inputs ~f:(fun (root, amount) -> fact (name root) (unit_name root) (Z.of_int amount)) in
        match expected pairs inputs, A.create ~frontier ~facts with
        | Ok (), Ok image ->
          Int.incr admitted;
          F.require (List.equal equal_fact facts (A.facts image)) "raw facts/order were rewritten";
          let rows = A.currents image in
          F.require (List.equal equal_fact facts (List.map rows ~f:A.retained_fact)) "current row order differs from declarations";
          List.iter2_exn inputs rows ~f:(fun (root, _) row ->
            let (_, terminal) = List.find_exn pairs ~f:(fun (r, _) -> Int.equal root r) in
            F.require (F.equal_event (List.nth_exn source terminal) (A.terminal_event row)) "current association differs from Warshall pairs");
          List.iter nodes ~f:(fun node ->
            let expected = List.find_map inputs ~f:(fun (root, amount) ->
              if List.mem pairs (root, node) ~equal:G.equal_edge then Some (root, amount) else None) in
            match expected, A.find_current image (F.id (name node)) with
            | None, None -> ()
            | Some (root, amount), Some row ->
              F.require (equal_fact (A.retained_fact row) (fact (name root) (unit_name root) (Z.of_int amount))) "terminal lookup lost root/Measure/quantity"
            | _ -> failwith "absent/noncurrent ID became an inferred amount")
        | Error (`Nonpositive (root, at)), Error (Nonpositive_quantity { root = actual; quantity; position }) ->
          F.require (D.Identifier.Event.equal actual (F.id (name root)) && at = position &&
            Z.equal (D.Quantity.quanta quantity) (Z.of_int (snd (List.find_exn inputs ~f:(fun (r, _) -> Int.equal root r))))) "nonpositive witness"
        | Error (`Not_root (root, at)), Error (Not_root { root = actual; position }) ->
          F.require (D.Identifier.Event.equal actual (F.id (name root)) && at = position) "non-root witness"
        | Error (`Repeated _), _ -> failwith "enumerated input unexpectedly duplicates a root"
        | _ -> failwith "amount admission differs from integer oracle"
      done
  done;
  F.require (!graphs = 13 && !cases = 832 && !admitted = 44) "executed graph/amount case counts";
  Stdlib.Printf.printf "13 admitted three-node graphs; 832 sign/subset cases; 44 admitted root amounts; current lookup/order checked\n";
  [%expect {| 13 admitted three-node graphs; 832 sign/subset cases; 44 admitted root amounts; current lookup/order checked |}]
;;

let%expect_test "original amounts retain exact positive facts and project only under explicit requalification" =
  let events = [ F.event " a "; F.event "b"; F.event "c"; F.event "x" ] in
  let edges = [ F.edge " a " "b"; F.edge "b" "c" ] in
  let frontier = F.admitted (F.memory events) edges in
  let huge = Z.shift_left Z.one 190 in
  let facts = [ fact "x" "jpy" Z.one; fact " a " " usd\000\027\n " huge ] in
  let image = ok (A.create ~frontier ~facts) in
  let retained = A.source_frontier image in
  F.require (List.equal F.equal_event events (D.Event_memory.events (C.retained_events retained)) &&
    List.equal F.equal_edge edges (C.corrections retained)) "source provenance lost";
  F.require (Option.is_none (A.find_current image (F.id " a ")) && Option.is_none (A.find_current image (F.id "b"))) "superseded lookup leaked current amount";
  F.require (equal_fact (A.retained_fact (Option.value_exn (A.find_current image (F.id "c")))) (List.nth_exn facts 1)) "huge/control/Measure or root rewritten";
  let variants = [ frontier, facts; F.admitted (F.memory (List.rev events)) (List.rev edges), List.rev facts ] in
  List.iter variants ~f:(fun (frontier, facts) ->
    let replay = ok (A.create ~frontier ~facts) in
    List.iter [ "c"; "x" ] ~f:(fun token ->
      F.require (equal_fact (A.retained_fact (Option.value_exn (A.find_current image (F.id token))))
        (A.retained_fact (Option.value_exn (A.find_current replay (F.id token))))) "representation became amount authority"));
  let extended = ok (A.create ~frontier:(F.admitted (F.memory (events @ [ F.event "d" ])) (edges @ [ F.edge "c" "d" ])) ~facts) in
  F.require (Option.is_none (A.find_current extended (F.id "c")) &&
    equal_fact (A.retained_fact (Option.value_exn (A.find_current extended (F.id "d")))) (List.nth_exn facts 1) &&
    List.equal equal_fact facts (A.facts extended) && Option.is_some (A.find_current image (F.id "c"))) "fresh tail rewrote fact or old image";
  (match A.create ~frontier:(F.admitted (F.memory (F.event "z" :: events)) (F.edge "z" " a " :: edges)) ~facts with
   | Error (Not_root { root; position = 2 }) -> F.require (D.Identifier.Event.equal root (F.id " a ")) "prefix-insertion witness"
   | _ -> failwith "lost root status was automatically retargeted");
  (match A.create ~frontier:(F.admitted (F.memory (List.take events 3)) edges) ~facts with
   | Error (Unknown_event { root; position = 1 }) -> F.require (D.Identifier.Event.equal root (F.id "x")) "omission witness"
   | _ -> failwith "source omission silently pruned amount");
  List.iter [ "b"; "c" ] ~f:(fun token ->
    match A.create ~frontier ~facts:[ fact token "usd" Z.one ] with
    | Error (Not_root { root; position = 1 }) -> F.require (D.Identifier.Event.equal root (F.id token)) "non-root role"
    | _ -> failwith "intermediate/terminal accepted as stable root");
  (match A.create ~frontier ~facts:[ List.hd_exn facts; fact "x" "other" Z.minus_one ] with
   | Error (Repeated_root { first_position = 1; position = 2; root = _ }) -> ()
   | _ -> failwith "duplicate did not precede nonpositive/Measure difference");
  (match A.create ~frontier ~facts:[ List.hd_exn facts; List.hd_exn facts ] with
   | Error (Repeated_root _) -> () | _ -> failwith "identical amount silently deduplicated");
  (match A.create ~frontier ~facts:[ fact "missing" "usd" (Z.neg huge) ] with
   | Error (Nonpositive_quantity { quantity; root = _; position = 1 }) -> F.require (Z.equal (D.Quantity.quanta quantity) (Z.neg huge)) "signed refusal was rounded"
   | _ -> failwith "positivity did not precede closure");
  Stdlib.Printf.printf "exact positive facts/retained frontier; optional/superseded lookup; replay/tail/prefix/omission and ordered refusal\n";
  [%expect {| exact positive facts/retained frontier; optional/superseded lookup; replay/tail/prefix/omission and ordered refusal |}]
;;

let%expect_test "source original amounts never become Effects, FX, balance or four-family support" =
  let wallet = F.coordinate "wallet" and offset = F.coordinate "offset" in
  let opening = F.coordinate ~unit:"usd" "opening" and other = F.coordinate ~unit:"usd" "other" in
  let quiet = F.coordinate "quiet" and stale = F.coordinate "stale" in
  let keyed = D.Effect.create ~key:(Some (F.identifier D.Identifier.Effect_key.of_string "physical"))
    ~locus:wallet.locus ~measure:wallet.measure ~quantity:(D.Quantity.of_quanta (Z.of_int 10)) in
  let events = [ F.event "a";
    F.observation ~id:(F.id "b") ~effects:[ keyed; F.change offset (Z.of_int (-10)); F.change opening Z.one; F.change other Z.minus_one ];
    F.observation ~id:(F.id "x") ~effects:[ F.change wallet Z.minus_one; F.change offset Z.one; F.change stale Z.one; F.change stale Z.minus_one ] ] in
  let huge = Z.shift_left Z.one 190 in
  let originals = [ fact "a" " eur " huge; fact "x" "jpy" Z.one ] in
  let raw : S.command =
    { events; corrections = [ F.edge "a" "b" ]; validity_corrections = []
    ; validities = List.map events ~f:(fun event -> F.base_validity (D.Event.id event) "2026-10-03")
    ; descriptions = [ { event = F.id "a"; text = "bill" } ]
    ; merchants = [ { event = F.id "a"; disposition = Merchant (F.identifier D.Identifier.External_party.of_string "provider") } ]
    ; original_amounts = originals
    ; exchanges = []
    } in
  let source = ok (S.create raw) in
  let amounts = S.original_amounts source in
  F.require (List.equal equal_fact originals (A.facts amounts) &&
    List.equal F.equal_event events (D.Event_memory.events (C.retained_events (A.source_frontier amounts))) &&
    F.equal_event (A.terminal_event (Option.value_exn (A.find_current amounts (F.id "b")))) (List.nth_exn events 1))
    "source lost raw association or terminal Effect/key payload";
  let pairs = O.expected_pairs events raw.corrections in
  let terminals = List.map pairs ~f:snd in
  let remaining = List.filter_map pairs ~f:(fun (root, event) -> if D.Identifier.Event.equal root (F.id "a") then None else Some event) in
  List.iter [ source; ok (S.create { raw with original_amounts = [] }) ] ~f:(fun source ->
    let query = ok (Q.create ~source ~zero_origins:[ offset ] ~openings:[ { coordinate = opening; opening_event = F.id "b" } ]
      ~groups:[ { reflected_roots = [ F.id "a" ]; assertions = [ F.assertion wallet (Z.of_int 100) ] } ]
      ~presence:(Some { reflected_roots = [ F.id "a" ]; coordinates = [ quiet; stale ] })) in
    List.iter [ offset, O.sum_events terminals offset, `Origin; opening, O.sum_events terminals opening, `Opening;
      wallet, Z.add (Z.of_int 100) (O.sum_events remaining wallet), `Assertion ] ~f:(fun (coordinate, expected, premise) ->
      match Q.query query coordinate with
      | Ok (Exact answer) ->
        F.require (Z.equal expected (D.Quantity.quanta (Q.quantity answer))) "original amount entered arithmetic";
        (match premise, Q.premise answer with
         | `Origin, Zero_origin -> ()
         | `Opening, Opening { coordinate; opening_event } -> F.require (F.same_coordinate coordinate opening && D.Identifier.Event.equal opening_event (F.id "b")) "opening witness changed"
         | `Assertion, Current_assertion asserted ->
           let module P = Loam_application.Current_quantity_projection in
           F.require (Z.equal (D.Quantity.quanta (P.delta asserted)) (O.sum_events remaining wallet)) "independent cut/delta changed"
         | _ -> failwith "original amount changed exact premise")
      | _ -> failwith "original amount changed exact support");
    F.require (not (O.touches_events remaining quiet) && O.touches_events remaining stale && Z.equal (O.sum_events remaining stale) Z.zero) "touch oracle fixture";
    (match Q.query query quiet, Q.query query stale, Q.query query (F.coordinate ~unit:" eur " "wallet") with
     | Ok (Known_present _), Error (Support_unknown _), Error (Support_unknown _) -> ()
     | _ -> failwith "original amount became presence or missing-Measure quantity"));
  let dated = ok (S.create { raw with validities = List.rev_map raw.validities ~f:(function
    | Base { event; valid_on = _ } -> Loam_application.Actual_validity.Base { event; valid_on = "1900-01-01" }
    | Revision { id; event; valid_on } -> Revision { id; event; valid_on });
    descriptions = []; merchants = [] }) in
  F.require (equal_fact (A.retained_fact (Option.value_exn (A.find_current amounts (F.id "b"))))
    (A.retained_fact (Option.value_exn (A.find_current (S.original_amounts dated) (F.id "b"))))) "date/text/Merchant selected amount";
  let unbalanced = F.observation ~id:(F.id "a") ~effects:[ F.change wallet Z.one ] in
  (match S.create { raw with events = [ unbalanced ]; corrections = []; validities = [ F.base_validity (F.id "a") "2026-10-03" ];
    original_amounts = [ fact "a" "jpy" Z.one ] } with
   | Error (Unbalanced_measure _) -> () | _ -> failwith "original amount closed physical imbalance");
  (match S.create { raw with original_amounts = [ fact "a" "eur" Z.zero ]; merchants = [ { event = F.id "unknown"; disposition = Nonmerchant } ] } with
   | Error (Merchants _) -> () | _ -> failwith "original amount bypassed prior source gates");
  Stdlib.Printf.printf "root/terminal scalar retained independently; all four supports unchanged; no missing-Measure support/physical balance\n";
  [%expect {| root/terminal scalar retained independently; all four supports unchanged; no missing-Measure support/physical balance |}]
;;
