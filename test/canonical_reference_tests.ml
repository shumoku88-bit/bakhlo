open Base
module D = Bakhlo_domain
module S = Bakhlo_application.Actual_source
module R = Bakhlo_application.Open_relations
module V = Bakhlo_application.Actual_reversals
module Q = Bakhlo_application.Current_quantity_query
module C = Bakhlo_application.Correction_frontier
module F = Fixtures

(* Synthetic oracle probes, not a canonical store, converter or admission engine.
   Basis-only sources qualify reference evidence, not current household activity. *)
let ok = function Ok value -> value | Error _ -> failwith "canonical fixture refused"
let key token = F.identifier D.Identifier.Effect_key.of_string token

let posting token locus n =
  let coordinate = F.coordinate locus in
  D.Effect.create
    ~key:(Some (key token))
    ~locus:coordinate.locus ~measure:coordinate.measure
    ~quantity:(D.Quantity.of_quanta (Z.of_int n))

let purchase name n =
  F.observation ~id:(F.id name) ~effects:[ posting "cash" "wallet" (-n); posting "cost" "food" n ]

let command events : S.command =
  {
    events;
    validities = List.map events ~f:(fun e -> F.base_validity (D.Event.id e) "2026-10-03");
    corrections = [];
    validity_corrections = [];
    descriptions = [];
    merchants = [];
    original_amounts = [];
    exchanges = [];
    reversals = [];
    relations = [];
    discharges = [];
  }

let relation token n : R.fact =
  {
    id = F.identifier D.Identifier.Relation.of_string token;
    source_event = F.id "original";
    source_effect = key "cash";
    debtor = R.Household;
    creditor = R.External (F.identifier D.Identifier.External_party.of_string "shop");
    quantity = D.Quantity.of_quanta (Z.of_int n);
  }

let observed source roots =
  ok
    (Q.create ~source ~zero_origins:[] ~openings:[]
       ~groups:
         [
           {
             reflected_roots = List.map roots ~f:F.id;
             assertions = [ F.assertion (F.coordinate "wallet") (Z.of_int 1000) ];
           };
         ])

let exact image expected =
  match Q.query image (F.coordinate "wallet") with
  | Ok answer ->
      F.require
        (Z.equal (D.Quantity.quanta (Q.quantity answer)) (Z.of_int expected))
        "canonical quantity changed"
  | _ -> failwith "canonical exact support lost"

let%expect_test
    "canonical original reference: current-only fails, complete basis keeps aggregate bounds" =
  let original = purchase "original" 10 in
  let middle = purchase "middle" 9 and current = purchase "current" 6 in
  let r = relation "claim" 8 in
  let raw =
    {
      (command [ original; middle; current ]) with
      corrections = [ F.edge "original" "middle"; F.edge "middle" "current" ];
      relations = [ r ];
    }
  in
  let history = ok (S.create raw) in
  F.require
    (List.equal F.equal_event (C.frontier_events (S.frontier history)) [ current ])
    "reference changed current selection";
  let basis_raw = { (command [ original ]) with relations = [ r ] } in
  let basis = ok (S.create basis_raw) in
  let resolved source = Option.value_exn (R.find_by_id (S.relations source) r.id) in
  F.require
    (F.equal_event original (R.source_event (resolved basis))
    && F.equal_effect (R.source_effect (resolved basis)) (R.source_effect (resolved history)))
    "basis changed original posting";
  (* Same current amount, but the reference remains to immutable original content. *)
  exact (observed history []) 994;
  exact (observed (ok (S.create (command [ current ]))) []) 994;
  (match S.create { (command [ current ]) with relations = [ r ] } with
  | Error (Relations (Unknown_event _)) -> ()
  | _ -> failwith "missing original reference ignored");
  (match
     S.create
       { (command [ current ]) with relations = [ { r with source_event = F.id "current" } ] }
   with
  | Error (Relations (Exceeds_source _)) -> ()
  | _ -> failwith "quantity-8 claim silently retargeted to quantity-6 posting");
  List.iter [ raw; basis_raw ] ~f:(fun input ->
      F.require
        (Result.is_ok (S.create { input with relations = [ r; relation "second" 2 ] }))
        "exact aggregate bound lost";
      match S.create { input with relations = [ r; relation "second" 3 ] } with
      | Error (Relations (Overcovered_source { total; magnitude; _ })) ->
          F.require
            (Z.equal (D.Quantity.quanta total) (Z.of_int 11)
            && Z.equal (D.Quantity.quanta magnitude) (Z.of_int 10))
            "aggregate source bound changed"
      | _ -> failwith "basis weakened aggregate admission");
  Stdio.printf "history=3 rows; reference basis=1 complete original row; current=1 row\n";
  Stdio.printf "wallet=994; original claim=8/10; missing and retargeted sources refuse\n";
  Stdio.printf "history/basis: 8+2 admits, 8+3 refuses; combined C admission is not established\n";
  [%expect
    {|history=3 rows; reference basis=1 complete original row; current=1 row
wallet=994; original claim=8/10; missing and retargeted sources refuse
history/basis: 8+2 admits, 8+3 refuses; combined C admission is not established|}]

let%expect_test
    "canonical source predicate: relation admission alone cannot certify original movement" =
  let valid = purchase "original" 10 in
  (* Alternative raw input, not a retained fragment or a substitute operational Event.
     Identical referenced posting, different unreferenced posting, invalid whole row. *)
  let invalid =
    F.observation ~id:(F.id "original")
      ~effects:[ posting "cash" "wallet" (-10); posting "cost" "food" 9 ]
  in
  let facts = [ relation "claim" 8 ] in
  List.iter [ valid; invalid ] ~f:(fun event ->
      F.require
        (Result.is_ok (R.create ~events:(F.memory [ event ]) ~facts))
        "relation-local probe refused");
  F.require
    (Result.is_ok (S.create { (command [ valid ]) with relations = facts }))
    "balanced original refused";
  (match S.create { (command [ invalid ]) with relations = facts } with
  | Error (Unbalanced_measure { residual; _ }) ->
      F.require (Z.equal (D.Quantity.quanta residual) Z.minus_one) "wrong original residual"
  | _ -> failwith "unreferenced posting's balance guard disappeared");
  Stdio.printf "same referenced -10 posting: relation predicate admits both alternatives\n";
  Stdio.printf "whole source: [-10,+10] admits; [-10,+9] refuses residual -1\n";
  [%expect
    {|same referenced -10 posting: relation predicate admits both alternatives
whole source: [-10,+10] admits; [-10,+9] refuses residual -1|}]

let%expect_test "canonical refund correction: original inverse evidence is not current cancellation"
    =
  let original = purchase "original" 10 and refund = purchase "refund" (-10) in
  let current = purchase "current" 6 in
  let reversal : V.fact = { target = F.id "original"; reversal = F.id "refund" } in
  let raw =
    {
      (command [ original; refund; current ]) with
      corrections = [ F.edge "original" "current" ];
      reversals = [ reversal ];
    }
  in
  let history = ok (S.create raw) in
  exact (observed history []) 1004;
  let basis = ok (S.create { (command [ original; refund ]) with reversals = [ reversal ] }) in
  let pair = Option.value_exn (V.find_by_target (S.reversals basis) (F.id "original")) in
  F.require
    (F.equal_event original (V.target_event pair) && F.equal_event refund (V.reversal_event pair))
    "retained refund retargeted";
  F.require
    (List.equal F.equal_event (C.frontier_events (S.frontier history)) [ refund; current ])
    "refund or corrected activity auto-removed";
  (match S.create { (command [ refund; current ]) with reversals = [ reversal ] } with
  | Error (Reversals (Unresolved_endpoints _)) -> ()
  | _ -> failwith "omitted refund target admitted");
  (match
     S.create
       {
         (command [ refund; current ]) with
         reversals = [ { reversal with target = F.id "current" } ];
       }
   with
  | Error (Reversals (Not_inverse _)) -> ()
  | _ -> failwith "refund evidence retargeted to a non-inverse current row");
  Stdio.printf "history admits correction: current -6 + actual refund 10; wallet=1004\n";
  Stdio.printf "original -10/refund +10 basis stays exact; omission/retargeting refuse\n";
  [%expect
    {|history admits correction: current -6 + actual refund 10; wallet=1004
original -10/refund +10 basis stays exact; omission/retargeting refuse|}]

let%expect_test "canonical reflected correction: keeping basis without root ownership double counts"
    =
  let original = purchase "original" 10 and current = purchase "current" 6 in
  let history =
    ok
      (S.create
         { (command [ original; current ]) with corrections = [ F.edge "original" "current" ] })
  in
  exact (observed history [ "original" ]) 1000;
  exact (observed history []) 994;
  (match
     Bakhlo_application.Reflected_root_cut.create ~frontier:(S.frontier history)
       ~reflected_roots:[ F.id "current" ]
   with
  | Error (Not_root _) -> ()
  | _ -> failwith "terminal spelling accepted as reflected root");
  let flat = ok (S.create (command [ current ])) in
  (match
     Bakhlo_application.Reflected_root_cut.create ~frontier:(S.frontier flat)
       ~reflected_roots:[ F.id "original" ]
   with
  | Error (Unknown_event _) -> ()
  | _ -> failwith "flattening silently inferred root identity");
  (* A naive union of basis and current is valid as TWO activities, not as C. *)
  let union = ok (S.create (command [ original; current ])) in
  exact (observed union [ "original" ]) 994;
  exact (observed union []) 984;
  Stdio.printf "history: reflected original=1000, unreflected=994; terminal cut refuses\n";
  Stdio.printf "current-only loses original root; naive basis union gives 994/984, not 1000/994\n";
  [%expect
    {|history: reflected original=1000, unreflected=994; terminal cut refuses
current-only loses original root; naive basis union gives 994/984, not 1000/994|}]
