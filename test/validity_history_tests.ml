open Base
module D = Loam_domain
module V = Loam_application.Actual_validity
module S = Loam_application.Actual_source
module Q = Loam_application.Current_quantity_query
module F = Fixtures
module M = Validity_history_model
let ok = function Ok value -> value | Error _ -> failwith "valid history refused"
let revision_id token = F.identifier D.Identifier.Validity_revision.of_string token
let base token date = F.base_validity (F.id token) date
let revision token event valid_on : V.fact = Revision { id = revision_id token; event = F.id event; valid_on }
let root token : V.reference = Base_ref (F.id token)
let ref_revision token : V.reference = Revision_ref (revision_id token)
let edge target token : V.correction = { target; replacement = revision_id token }
let same_ref (a : V.reference) (b : V.reference) = match a, b with
  | V.Base_ref a, Base_ref b -> D.Identifier.Event.equal a b
  | Revision_ref a, Revision_ref b -> D.Identifier.Validity_revision.equal a b
  | Base_ref _, Revision_ref _ | Revision_ref _, Base_ref _ -> false
let same_fact a b = same_ref (V.reference a) (V.reference b) && D.Identifier.Event.equal (V.event a) (V.event b) && String.equal (V.valid_on a) (V.valid_on b)
let same_edge (a : V.correction) (b : V.correction) = same_ref a.target b.target && D.Identifier.Validity_revision.equal a.replacement b.replacement
let admit events facts corrections = V.create ~events:(F.memory (List.map events ~f:F.event)) ~facts ~corrections

let%expect_test "date history admission and selection correspond to independent four-node semantic model" =
  let admitted = ref 0 in
  let references = [ root "a"; root "b"; ref_revision "a"; ref_revision "b" ] in
  let dates = [ "2026-10-03"; "2025-01-01"; "1900-01-01"; "0001-01-01" ] in
  for subset = 0 to 15 do
    for assignment = 0 to 3 do
      let owners = M.assignment assignment in
      let nodes = M.nodes subset in
      let owner n = if M.event ~revision_events:owners n = 0 then "a" else "b" in
      let facts = List.map nodes ~f:(fun n -> if n < 2 then base (owner n) (List.nth_exn dates n)
        else revision (if n = 2 then "a" else "b") (owner n) (List.nth_exn dates n)) in
      for relation = 0 to 255 do
        let edges = M.edges relation in
        let corrections = List.map edges ~f:(fun (a, b) -> edge (List.nth_exn references a) (if b = 2 then "a" else "b")) in
        match M.analyze ~nodes ~edges ~revision_events:owners, admit [ "a"; "b" ] facts corrections with
        | None, Error _ -> ()
        | Some terminals, Ok image ->
          Int.incr admitted;
          let expected = List.filter_map (List.zip_exn nodes facts) ~f:(fun (n, fact) ->
            if List.mem terminals n ~equal:Int.equal then Some fact else None) in
          F.require (List.equal same_fact expected (V.current_facts image)) "original-order model terminals";
          F.require (List.equal same_fact facts (V.facts image) && List.equal same_edge corrections (V.corrections image)) "retained provenance";
          List.iter [ "a"; "b" ] ~f:(fun token ->
            let selected = List.find expected ~f:(fun fact -> D.Identifier.Event.equal (V.event fact) (F.id token)) in
            F.require (Option.equal same_fact selected (V.find_current image (F.id token))) "current date/ref lookup")
        | _ -> failwith "validity history differs from independent model"
      done
    done
  done;
  F.require (!admitted = 36) "executed 16384 cases";
  Stdlib.Printf.printf "16384 history subset/ownership/edge cases; 36 admitted; dates are not winners\n";
  [%expect {| 16384 history subset/ownership/edge cases; 36 admitted; dates are not winners |}]
;;

let%expect_test "tagged references preserve exact revision identity and every retained date" =
  (match D.Identifier.Validity_revision.of_string "" with Error Empty -> () | Ok _ -> failwith "empty revision ID");
  List.iter [ "a"; " a "; "A"; "a\000" ] ~f:(fun a -> List.iter [ "a"; " a "; "A"; "a\000" ] ~f:(fun b ->
    F.require (Bool.equal (D.Identifier.Validity_revision.equal (revision_id a) (revision_id b)) (String.equal a b)) "exact revision identity"));
  let facts = [ base "a" "2026-10-03"; revision "a" "a" "1900-01-01" ] in
  let image = ok (admit [ "a" ] facts [ edge (root "a") "a" ]) in
  F.require (List.length (V.facts image) = 2 && same_ref (V.reference (Option.value_exn (V.find_current image (F.id "a")))) (ref_revision "a")) "base/revision same token aliased";
  F.require (Option.is_none (V.find_current image (F.id "outside"))) "unknown ID manufactured a date";
  F.require (Result.is_ok (admit [ "a" ] [ revision "only" "a" "2000-02-29" ] [])) "invented mandatory base";
  (match admit [ "a" ] [ base "a" "2026-02-30"; revision "new" "a" "2026-10-03" ] [ edge (root "a") "new" ] with
   | Error (Invalid_date { position = 1; text = "2026-02-30" }) -> () | _ -> failwith "invalid superseded date discarded");
  (match admit [ "a"; "b" ] [ revision "same" "a" "2026-10-03"; revision "same" "b" "2026-10-03" ] [] with
   | Error (Repeated_fact { reference = Revision_ref id; first_position = 1; position = 2 }) ->
     F.require (D.Identifier.Validity_revision.equal id (revision_id "same")) "revision uniqueness witness"
   | _ -> failwith "revision identity scoped by Event or equal payload deduplicated");
  Stdlib.Printf.printf "tagged same-token identities; revision-only evidence; superseded dates still validated\n";
  [%expect {| tagged same-token identities; revision-only evidence; superseded dates still validated |}]
;;

let%expect_test "date corrections refuse open cross-Event ambiguous cyclic and incomplete histories in order" =
  let facts = [ base "a" "2026-10-03"; base "b" "2026-10-03";
    revision "r" "a" "1900-01-01"; revision "s" "a" "2000-01-01"; revision "t" "b" "2000-01-01" ] in
  let run = admit [ "a"; "b" ] facts in
  (match run [ edge (root "outside") "missing" ] with
   | Error (Unresolved_correction { position = 1; endpoints = [ Target (Base_ref event); Replacement id ] }) ->
     F.require (D.Identifier.Event.equal event (F.id "outside") && D.Identifier.Validity_revision.equal id (revision_id "missing")) "ordered missing endpoints"
   | _ -> failwith "open dates became Events");
  (match run [ edge (root "a") "t" ] with Error (Cross_event_correction { position = 1; target_event; replacement_event }) ->
     F.require (D.Identifier.Event.equal target_event (F.id "a") && D.Identifier.Event.equal replacement_event (F.id "b")) "same Event witness"
   | _ -> failwith "cross-Event date correction");
  (match run [ edge (root "a") "r"; edge (root "a") "s" ] with Error (Repeated_target { first_position = 1; position = 2; reference = _ }) -> () | _ -> failwith "branch picked winner");
  (match run [ edge (root "a") "r"; edge (ref_revision "s") "r" ] with Error (Repeated_replacement { first_position = 1; position = 2; id = _ }) -> () | _ -> failwith "merge picked winner");
  (match run [ edge (root "a") "r"; edge (root "a") "r" ] with Error (Repeated_target _) -> () | _ -> failwith "equal edge deduplicated");
  (match run [ edge (root "a") "r"; edge (root "a") "missing" ] with Error (Unresolved_correction { position = 2; endpoints = [ Replacement _ ] }) -> () | _ -> failwith "closure before edge uniqueness");
  let cycle = [ edge (ref_revision "r") "s"; edge (ref_revision "s") "r" ] in
  (match run cycle with Error (Cycle { path }) ->
     F.require (List.length path = 3 && same_ref (List.hd_exn path) (List.last_exn path)) "closed cycle witness";
     List.iter (List.zip_exn (List.drop_last_exn path) (List.tl_exn path)) ~f:(fun (a, b) ->
       F.require (List.exists cycle ~f:(fun edge -> same_ref edge.target a && same_ref (V.Revision_ref edge.replacement) b)) "fabricated cycle edge")
   | _ -> failwith "cycles checked after current uniqueness");
  (match run [ edge (ref_revision "r") "r" ] with Error (Cycle { path }) -> F.require (List.length path = 2) "self cycle" | _ -> failwith "self cycle admitted");
  (match admit [ "a" ] [ base "a" "2026-10-03"; revision "r" "a" "1900-01-01" ] [] with
   | Error (Repeated_current_validity { first_position = 1; position = 2; event = _ }) -> () | _ -> failwith "unconnected revision chose latest");
  (match admit [ "b"; "a" ] [] [] with Error (Missing_validity { event }) -> F.require (D.Identifier.Event.equal event (F.id "b")) "completeness order" | _ -> failwith "missing date became empty success");
  Stdlib.Printf.printf "ordered closure/association/uniqueness/cycle/current completeness; no winner defaults\n";
  [%expect {| ordered closure/association/uniqueness/cycle/current completeness; no winner defaults |}]
;;

let%expect_test "date history reconstruction preserves provenance current lookup and immutable old images" =
  let facts = [ revision "s" "a" "1900-01-01"; base "b" "2000-02-29"; base "a" "2026-10-03"; revision "r" "a" "2025-01-01" ] in
  let edges = [ edge (ref_revision "r") "s"; edge (root "a") "r" ] in
  let image = ok (admit [ "a"; "b" ] facts edges) in
  let permuted = ok (admit [ "b"; "a" ] (List.rev facts) (List.rev edges)) in
  List.iter [ "a"; "b" ] ~f:(fun id -> F.require (Option.equal same_fact (V.find_current image (F.id id)) (V.find_current permuted (F.id id))) "representation winner");
  let extended = ok (admit [ "a"; "b" ] (facts @ [ revision "t" "a" "0001-01-01" ]) (edges @ [ edge (ref_revision "s") "t" ])) in
  F.require (same_ref (V.reference (Option.value_exn (V.find_current extended (F.id "a")))) (ref_revision "t")) "fresh date tail not selected";
  F.require (List.equal same_fact facts (V.facts image) && List.equal same_edge edges (V.corrections image)) "old history mutated";
  F.require (List.equal F.equal_event [ F.event "a"; F.event "b" ] (D.Event_memory.events (V.source_events image))) "source association";
  (match admit [ "a"; "b" ] (List.filter facts ~f:(fun fact -> not (same_ref (V.reference fact) (ref_revision "r")))) edges with
   | Error (Unresolved_correction _) -> () | _ -> failwith "omitted intermediate did not requalify");
  Stdlib.Printf.printf "permutation invariant lookup; fresh date tails; retained old facts/edges; prefixes requalify\n";
  [%expect {| permutation invariant lookup; fresh date tails; retained old facts/edges; prefixes requalify |}]
;;

let%expect_test "10000-revision path and cycle complete without stack recursion" =
  let token i = Int.to_string i in
  let revisions = List.init 10000 ~f:(fun i -> revision (token i) "a" "1900-01-01") in
  let edges = edge (root "a") "0" :: List.init 9999 ~f:(fun i -> edge (ref_revision (token i)) (token (i + 1))) in
  List.iter [ edges; List.rev edges ] ~f:(fun edges ->
    let image = ok (admit [ "a" ] (base "a" "2026-10-03" :: revisions) edges) in
    F.require (same_ref (V.reference (Option.value_exn (V.find_current image (F.id "a")))) (ref_revision "9999")) "long terminal");
  let cyclic = List.tl_exn edges @ [ edge (ref_revision "9999") "0" ] in
  (match admit [ "a" ] revisions cyclic with Error (Cycle { path }) ->
     F.require (List.length path = 10001 && same_ref (List.hd_exn path) (List.last_exn path)) "long cycle witness"
   | _ -> failwith "long cycle swallowed");
  Stdlib.Printf.printf "10000-revision chain both edge orders; 10000-revision cycle witnessed\n";
  [%expect {| 10000-revision chain both edge orders; 10000-revision cycle witnessed |}]
;;

let%expect_test "date revision is independent of Event correction and all four supports" =
  let wallet = F.coordinate "wallet" and offset = F.coordinate "offset" and opening = F.coordinate ~unit:"usd" "opening" in
  let changes n = [ F.change wallet (Z.of_int n); F.change offset (Z.of_int (-n)) ] in
  let events = [ F.observation ~id:(F.id "a") ~effects:(changes 3);
    F.observation ~id:(F.id "b") ~effects:(changes 5 @ [ F.change opening Z.one; F.change opening Z.minus_one ]);
    F.observation ~id:(F.id "x") ~effects:(changes 7 @ [ F.change (F.coordinate "stale") Z.one; F.change (F.coordinate "stale") Z.minus_one ]) ] in
  let raw : S.command = { events; validities = List.map [ "a"; "b"; "x" ] ~f:(fun id -> base id "2026-10-03");
    validity_corrections = []; merchants = []; original_amounts = []; exchanges = []; reversals = []; relations = []; corrections = [ F.edge "a" "b" ]; descriptions = [ { event = F.id "a"; text = "root text" } ] } in
  let before = ok (S.create raw) in
  let after = ok (S.create { raw with validities = raw.validities @ [ revision "date-a" "a" "1900-01-01"; revision "date-b" "b" "0001-01-01" ];
    validity_corrections = [ edge (root "a") "date-a"; edge (root "b") "date-b" ] }) in
  let image source = ok (Q.create ~source ~zero_origins:[ offset ] ~openings:[ { coordinate = opening; opening_event = F.id "b" } ]
    ~groups:[ { reflected_roots = [ F.id "a" ]; assertions = [ F.assertion wallet (Z.of_int 100) ] } ]
    ~presence:(Some { reflected_roots = [ F.id "a" ]; coordinates = [ F.coordinate "quiet"; F.coordinate "stale" ] })) in
  let a = image before and b = image after in
  List.iter [ wallet, 107; offset, -12; opening, 0 ] ~f:(fun (c, expected) -> match Q.query a c, Q.query b c with
    | Ok (Exact left), Ok (Exact right) -> F.require (D.Quantity.equal (Q.quantity left) (Q.quantity right) && Z.equal (D.Quantity.quanta (Q.quantity right)) (Z.of_int expected)) "date revision changed arithmetic"
    | _ -> failwith "date revision changed exact support");
  (match Q.query a (F.coordinate "quiet"), Q.query b (F.coordinate "quiet"), Q.query a (F.coordinate "stale"), Q.query b (F.coordinate "stale") with
   | Ok (Known_present _), Ok (Known_present _), Error (Support_unknown _), Error (Support_unknown _) -> () | _ -> failwith "date revision changed touch support");
  F.require (String.equal (V.valid_on (Option.value_exn (V.find_current (S.validity after) (F.id "b")))) "0001-01-01") "revised date not exposed";
  F.require (String.equal (V.valid_on (Option.value_exn (V.find_current (S.validity before) (F.id "b")))) "2026-10-03") "old source mutated";
  F.require (List.equal F.equal_event events (D.Event_memory.events (Loam_application.Correction_frontier.retained_events (S.frontier after)))) "date correction discarded Event provenance";
  Stdlib.Printf.printf "separate date/Event frontiers; quantity/presence unchanged; raw provenance and old source retained\n";
  [%expect {| separate date/Event frontiers; quantity/presence unchanged; raw provenance and old source retained |}]
;;
