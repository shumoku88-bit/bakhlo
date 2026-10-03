open Base

module D = Loam_domain
module Id = D.Identifier.Event
module F = Loam_application.Correction_frontier
module C = Loam_application.Correction_check

let require condition message = if not condition then failwith message
let identifier constructor name =
  match constructor name with
  | Ok value -> value
  | Error D.Identifier.Empty -> failwith "empty fixture ID"
;;

let id name = identifier Id.of_string name
let edge target replacement : D.Event_correction.t =
  { target = id target; replacement = id replacement }
;;

let event name = Fixtures.observation ~id:(id name) ~effects:[]

let memory events =
  match D.Event_memory.of_events events with
  | Ok value -> value
  | Error _ -> failwith "duplicate fixture"
;;

let admitted events corrections =
  match F.create ~events ~corrections with
  | Ok value -> value
  | Error _ -> failwith "valid fixture refused"
;;

let refused events corrections =
  match F.create ~events ~corrections with
  | Error error -> error
  | Ok _ -> failwith "invalid relation admitted"
;;

let equal_effect left right =
  D.Identifier.Locus.equal (D.Effect.locus left) (D.Effect.locus right)
  && D.Identifier.Measure.equal (D.Effect.measure left) (D.Effect.measure right)
  && D.Quantity.equal (D.Effect.quantity left) (D.Effect.quantity right)
;;

let equal_event left right =
  Id.equal (D.Event.id left) (D.Event.id right)
  && List.equal equal_effect (D.Event.effects left) (D.Event.effects right)
;;

let equal_edge (left : D.Event_correction.t) (right : D.Event_correction.t) =
  Id.equal left.target right.target && Id.equal left.replacement right.replacement
;;

let names events =
  String.concat ~sep:"," (List.map events ~f:(fun event -> Id.to_string (D.Event.id event)))
;;

let equal_missing
    (C.Missing_event { endpoint = left; id = left_id })
    (C.Missing_event { endpoint = right; id = right_id })
  =
  let same_role =
    match left, right with
    | Target, Target | Replacement, Replacement -> true
    | Target, Replacement | Replacement, Target -> false
  in
  same_role && Id.equal left_id right_id
;;

let describe_error = function
  | F.Unresolved_correction { position; errors } ->
    let roles = List.map errors ~f:(fun (C.Missing_event { endpoint; id }) ->
      let role = match endpoint with Target -> "target" | Replacement -> "replacement" in
      Printf.sprintf "%s=%S" role (Id.to_string id)) in
    Printf.sprintf "edge %d unresolved: %s" position (String.concat ~sep:", " roles)
  | Repeated_target { id; first_position; position } ->
    Printf.sprintf "repeated target %S: %d,%d" (Id.to_string id) first_position position
  | Repeated_replacement { id; first_position; position } ->
    Printf.sprintf "repeated replacement %S: %d,%d" (Id.to_string id) first_position position
  | Cycle { path } ->
    Printf.sprintf "cycle: %s" (String.concat ~sep:" -> " (List.map path ~f:Id.to_string))
;;

let%expect_test "empty relation preserves explicitly supplied neutral observations" =
  let empty = admitted (memory []) [] in
  require (List.is_empty (F.frontier_events empty)) "explicit empty frontier";
  let change unit n =
    D.Effect.create ~key:None
      ~locus:(identifier D.Identifier.Locus.of_string "here")
      ~measure:(identifier D.Identifier.Measure.of_string unit)
      ~quantity:(D.Quantity.of_quanta n)
  in
  let payload = [ change "jpy" Z.zero; change "usd" (Z.shift_left Z.one 128) ] in
  let observed = Fixtures.observation ~id:(id "observed") ~effects:payload in
  require (Result.is_error (D.Movement.validate payload)) "Event is not Movement";
  let source = [ event "empty"; observed ] in
  let answer = admitted (memory source) [] in
  require (List.equal equal_event source (F.frontier_events answer)) "no correction changes nothing";
  require (List.equal equal_event source (D.Event_memory.events (F.retained_events answer))) "retention";
  require (List.is_empty (F.corrections answer)) "no inferred edge";
  Stdlib.Printf.printf "empty frontier=0; untouched frontier=%s\n" (names (F.frontier_events answer));
  [%expect {| empty frontier=0; untouched frontier=empty,observed |}]
;;

let%expect_test "disjoint multi-hop paths select terminals and untouched Events without pruning sources" =
  let source = List.map [ "c"; "a"; "d"; "untouched"; "b"; "e" ] ~f:event in
  let events = memory source in
  let corrections = [ edge "b" "c"; edge "d" "e"; edge "a" "b" ] in
  let answer = admitted events corrections in
  require (List.equal equal_edge corrections (F.corrections answer)) "raw edges retained";
  require (List.equal equal_event source (D.Event_memory.events (F.retained_events answer))) "all observations retained";
  require (List.equal equal_event (F.frontier_events answer) (List.map [ "c"; "untouched"; "e" ] ~f:event)) "frontier";
  let reordered = admitted (memory (List.rev source)) (List.rev corrections) in
  require (List.equal equal_event (F.frontier_events reordered) (List.rev (F.frontier_events answer))) "order is representation only";
  require (List.equal equal_event source (D.Event_memory.events events)) "query did not mutate input";
  Stdlib.Printf.printf "frontier=%s; retained=%d; corrections=%d\n"
    (names (F.frontier_events answer)) (List.length source) (List.length (F.corrections answer));
  [%expect {| frontier=c,untouched,e; retained=6; corrections=3 |}]
;;

let%expect_test "closure errors precede uniqueness for that edge, and all cycles are checked last" =
  let events = memory (List.map [ "a"; "b" ] ~f:event) in
  List.iter
    [ [ edge "a" "b"; edge "a" "missing" ]
    ; [ edge "left" "right" ]
    ; [ edge "same" "same" ]
    ; [ edge "a" "a"; edge "left" "right" ]
    ] ~f:(fun edges -> Stdlib.Printf.printf "%s\n" (describe_error (refused events edges)));
  [%expect {|
    edge 2 unresolved: replacement="missing"
    edge 1 unresolved: target="left", replacement="right"
    edge 1 unresolved: target="same", replacement="same"
    edge 2 unresolved: target="left", replacement="right" |}]
;;

let%expect_test "closed branches, merges and identical repeated edges never pick a winner" =
  let events = memory (List.map [ "a"; "b"; "c"; "d" ] ~f:event) in
  List.iter
    [ [ edge "a" "b"; edge "a" "b" ]
    ; [ edge "a" "b"; edge "a" "c" ]
    ; [ edge "a" "c"; edge "b" "c" ]
    ; [ edge "c" "d"; edge "a" "b"; edge "a" "c" ]
    ] ~f:(fun edges -> Stdlib.Printf.printf "%s\n" (describe_error (refused events edges)));
  [%expect {|
    repeated target "a": 1,2
    repeated target "a": 1,2
    repeated replacement "c": 1,2
    repeated target "a": 2,3 |}]
;;

let%expect_test "cycle witnesses include self, long and disconnected cycles" =
  let events = memory (List.map [ "a"; "b"; "c"; "d"; "e" ] ~f:event) in
  List.iter
    [ [ edge "a" "a" ]
    ; [ edge "a" "b"; edge "b" "a" ]
    ; [ edge "a" "b"; edge "b" "c"; edge "c" "a" ]
    ; [ edge "d" "e"; edge "b" "c"; edge "c" "a"; edge "a" "b" ]
    ] ~f:(fun edges -> Stdlib.Printf.printf "%s\n" (describe_error (refused events edges)));
  [%expect {|
    cycle: a -> a
    cycle: a -> b -> a
    cycle: a -> b -> c -> a
    cycle: b -> c -> a -> b |}]
;;

let%expect_test "exact opaque identities have no alias or chronological ordering" =
  let source = List.map [ " event "; "event"; "Event"; "event\000" ] ~f:event in
  let answer = admitted (memory source) [ edge "Event" " event "; edge "event" "event\000" ] in
  require (List.equal equal_event (F.frontier_events answer) [ event " event "; event "event\000" ]) "exact identity";
  Stdlib.Printf.printf "frontier count=%d; all four observations retained\n" (List.length (F.frontier_events answer));
  [%expect {| frontier count=2; all four observations retained |}]
;;

let%expect_test "long-chain validation is tail-recursive in both edge orders" =
  let count = 10_000 in
  let ids = List.init count ~f:(fun i -> id ("long:" ^ Int.to_string i)) in
  let source = List.map ids ~f:(fun id -> Fixtures.observation ~id ~effects:[]) in
  let events = memory source in
  let edges = List.map2_exn (List.drop_last_exn ids) (List.tl_exn ids)
    ~f:(fun target replacement -> ({ target; replacement } : D.Event_correction.t)) in
  let expected = [ List.last_exn source ] in
  List.iter [ edges; List.rev edges ] ~f:(fun corrections ->
    require (List.equal equal_event expected (F.frontier_events (admitted events corrections))) "long terminal");
  let cycle = edges @ [ { D.Event_correction.target = List.last_exn ids; replacement = List.hd_exn ids } ] in
  (match refused events cycle with
   | Cycle { path } -> require (Int.equal (List.length path) (count + 1)) "full long witness"
   | Unresolved_correction _ | Repeated_target _ | Repeated_replacement _ -> failwith "wrong long-cycle refusal");
  Stdlib.Printf.printf "%d-node chain/reversed edges/cycle completed\n" count;
  [%expect {| 10000-node chain/reversed edges/cycle completed |}]
;;

module Small_graphs = struct
  type t = (int * int) list
  let sexp_of_t pairs = Sexp.List (List.map pairs ~f:(fun (a, b) -> Sexp.List [ Int.sexp_of_t a; Int.sexp_of_t b ]))
  let quickcheck_generator =
    let open Base_quickcheck.Generator in
    bind (int_inclusive 0 10) ~f:(fun length ->
      list_with_length (both (int_inclusive 0 5) (int_inclusive 0 5)) ~length)
  let quickcheck_shrinker =
    Base_quickcheck.Shrinker.list
      (Base_quickcheck.Shrinker.both Base_quickcheck.Shrinker.int Base_quickcheck.Shrinker.int)
end

(* Independent oracle: pairwise source-list tests and bounded replacement walks,
   not the production indexes, completed-set traversal, or constructor result. *)
let oracle source corrections =
  let present requested = List.exists source ~f:(fun event -> Id.equal (D.Event.id event) requested) in
  let unique field = List.for_alli corrections ~f:(fun i left ->
    List.for_alli corrections ~f:(fun j right -> Int.equal i j || not (Id.equal (field left) (field right)))) in
  let closed = List.for_all corrections ~f:(fun (c : D.Event_correction.t) -> present c.target && present c.replacement) in
  let no_cycles = List.for_all source ~f:(fun start ->
    let rec walk fuel current =
      match List.find corrections ~f:(fun (c : D.Event_correction.t) -> Id.equal c.target current) with
      | None -> true
      | Some c -> fuel > 0 && not (Id.equal c.replacement (D.Event.id start)) && walk (fuel - 1) c.replacement
    in
    walk (List.length source) (D.Event.id start)) in
  closed
  && unique (fun (c : D.Event_correction.t) -> c.target)
  && unique (fun (c : D.Event_correction.t) -> c.replacement)
  && no_cycles
;;

let%expect_test "all 512 directed graphs on three Events agree with the bounded oracle" =
  let source = List.map [ "a"; "b"; "c" ] ~f:event in
  let events = memory source in
  let possible =
    List.concat_map [ "a"; "b"; "c" ] ~f:(fun target ->
      List.map [ "a"; "b"; "c" ] ~f:(fun replacement -> edge target replacement))
  in
  List.iter (List.init 512 ~f:Fn.id) ~f:(fun mask ->
    let corrections =
      List.filteri possible ~f:(fun i _ -> not (Int.equal (mask land (1 lsl i)) 0))
    in
    require
      (Bool.equal (Result.is_ok (F.create ~events ~corrections)) (oracle source corrections))
      "three-Event admission oracle");
  Stdlib.Printf.printf "512 three-Event graphs checked (bounded evidence only)\n";
  [%expect {| 512 three-Event graphs checked (bounded evidence only) |}]
;;

let%expect_test "generated graph admission and frontier agree with a list/fuel oracle" =
  let payload i =
    let q = Z.mul (Z.shift_left Z.one 128) (Z.of_int i) in
    List.map [ "jpy", q; "usd", Z.neg q; "jpy", Z.zero ] ~f:(fun (unit, quantity) ->
      D.Effect.create ~key:None ~locus:(identifier D.Identifier.Locus.of_string "here")
        ~measure:(identifier D.Identifier.Measure.of_string unit) ~quantity:(D.Quantity.of_quanta quantity)) in
  let source = List.init 5 ~f:(fun i -> Fixtures.observation ~id:(id (Int.to_string i)) ~effects:(payload i)) in
  let events = memory source in
  let reversed = memory (List.rev source) in
  let make_edge (a, b) = edge (Int.to_string a) (Int.to_string b) in
  let check corrections =
    let expected = oracle source corrections in
    let run events edges =
      match F.create ~events ~corrections:edges with
      | Error error ->
        require (not expected) "oracle accepts but implementation refuses";
        (match error with
         | Cycle { path } ->
           require (List.length path >= 2) "nontrivial closed witness";
           require (Id.equal (List.hd_exn path) (List.last_exn path)) "closed witness";
           List.iter2_exn (List.drop_last_exn path) (List.tl_exn path) ~f:(fun a b ->
             require (List.exists edges ~f:(fun (c : D.Event_correction.t) -> Id.equal c.target a && Id.equal c.replacement b)) "witness follows actual edges")
         | Unresolved_correction { position; errors } ->
           let edge = List.nth_exn edges (position - 1) in
           let absent role requested =
             if List.exists source ~f:(fun event -> Id.equal (D.Event.id event) requested)
             then [] else [ C.Missing_event { endpoint = role; id = requested } ] in
           let missing = absent Target edge.target @ absent Replacement edge.replacement in
           require (not (List.is_empty errors)) "nonempty endpoint errors";
           require (List.equal equal_missing errors missing) "ordered missing roles"
         | Repeated_target { id; first_position; position } ->
           require (first_position < position) "prior target position";
           require (Id.equal id (List.nth_exn edges (first_position - 1)).target && Id.equal id (List.nth_exn edges (position - 1)).target) "target witness"
         | Repeated_replacement { id; first_position; position } ->
           require (first_position < position) "prior replacement position";
           require (Id.equal id (List.nth_exn edges (first_position - 1)).replacement && Id.equal id (List.nth_exn edges (position - 1)).replacement) "replacement witness")
      | Ok answer ->
        require expected "invalid graph admitted";
        let original = D.Event_memory.events events in
        let frontier = List.filter original ~f:(fun event ->
          not (List.exists edges ~f:(fun (c : D.Event_correction.t) -> Id.equal c.target (D.Event.id event)))) in
        require (List.equal equal_event frontier (F.frontier_events answer)) "frontier oracle and payloads";
        require (List.equal equal_event original (D.Event_memory.events (F.retained_events answer))) "all evidence retained";
        require (List.equal equal_edge edges (F.corrections answer)) "raw relation retained"
    in
    run events corrections;
    run events corrections;
    run reversed (List.rev corrections);
    require (List.equal equal_event source (D.Event_memory.events events)) "input unchanged"
  in
  let config =
    { Base_quickcheck.Test.default_config with
      seed = Deterministic "loam-correction-frontier-v1"
    ; test_count = 10_000
    ; shrink_count = 10_000
    }
  in
  let checks = ref 0 in
  Base_quickcheck.Test.run_exn (module Small_graphs) ~config ~f:(fun pairs ->
    check (List.map pairs ~f:make_edge);
    (* Also check a guaranteed-valid subset of two disjoint paths per case. *)
    let candidates = [ edge "0" "1"; edge "1" "2"; edge "3" "4" ] in
    let valid = List.filteri candidates ~f:(fun i _ -> (List.length pairs + i) % 2 = 0) in
    check valid;
    (match valid with [] -> () | first :: _ -> check (valid @ [ first ]));
    Int.incr checks);
  require (Int.equal !checks config.test_count) "cases actually executed";
  Stdlib.Printf.printf "frontier/list-fuel oracle passed (%d generated cases)\n" !checks;
  [%expect {| frontier/list-fuel oracle passed (10000 generated cases) |}]
;;
