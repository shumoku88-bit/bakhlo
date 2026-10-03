open Base

module D = Loam_domain
module Id = D.Identifier.Event
module F = Loam_application.Correction_frontier
module M = Lineage_model

let require condition message = if not condition then failwith message

let identifier constructor name =
  match constructor name with
  | Ok value -> value
  | Error D.Identifier.Empty -> failwith "empty fixture identity"
;;

let id name = identifier Id.of_string name
let event name = D.Event.create ~id:(id name) ~effects:[]
let edge a b : D.Event_correction.t = { target = id a; replacement = id b }

let memory source =
  match D.Event_memory.of_events source with
  | Ok value -> value
  | Error _ -> failwith "duplicate fixture"
;;

let admitted events corrections =
  match F.create ~events ~corrections with
  | Ok value -> value
  | Error _ -> failwith "valid fixture refused"
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

let equal_lineage left right =
  Id.equal (F.root_id left) (F.root_id right)
  && equal_event (F.terminal_event left) (F.terminal_event right)
;;

let show lineages =
  String.concat ~sep:"," (List.map lineages ~f:(fun row ->
    Printf.sprintf "%s=>%s" (Id.to_string (F.root_id row))
      (Id.to_string (D.Event.id (F.terminal_event row)))))
;;

let change unit n =
  D.Effect.create
    ~locus:(identifier D.Identifier.Locus.of_string "here")
    ~measure:(identifier D.Identifier.Measure.of_string unit)
    ~quantity:(D.Quantity.of_quanta n)
;;

let%expect_test "empty and untouched observations form exact singleton lineages" =
  require (List.is_empty (F.lineages (admitted (memory []) []))) "explicit empty input";
  let payload = [ change "jpy" Z.zero; change "usd" (Z.shift_left Z.one 128) ] in
  let observed = D.Event.create ~id:(id "observed") ~effects:payload in
  let source = [ event "empty"; observed ] in
  let answer = admitted (memory source) [] in
  List.iter2_exn source (F.lineages answer) ~f:(fun original row ->
    require (Id.equal (D.Event.id original) (F.root_id row)) "singleton root";
    require (equal_event original (F.terminal_event row)) "exact singleton payload");
  require (Result.is_error (D.Movement.validate payload)) "no ordinary-Movement narrowing";
  Stdlib.Printf.printf "%s\n" (show (F.lineages answer));
  [%expect {| empty=>empty,observed=>observed |}]
;;

let%expect_test "lineages follow root representation order, not terminal or correction order" =
  let source = List.map [ "e"; "c"; "a"; "untouched"; "b"; "d" ] ~f:event in
  let corrections = [ edge "b" "c"; edge "d" "e"; edge "a" "b" ] in
  let answer = admitted (memory source) corrections in
  let reordered = admitted (memory (List.rev source)) (List.rev corrections) in
  require (List.equal equal_lineage (List.rev (F.lineages answer)) (F.lineages reordered)) "root order only";
  require (List.equal equal_event source (D.Event_memory.events (F.retained_events answer))) "all observations retained";
  require (List.equal equal_edge corrections (F.corrections answer)) "all explicit edges retained";
  Stdlib.Printf.printf "lineages=%s\nfrontier=%s\n"
    (show (F.lineages answer))
    (String.concat ~sep:"," (List.map (F.frontier_events answer) ~f:(fun e -> Id.to_string (D.Event.id e))));
  [%expect {|
    lineages=a=>c,untouched=>untouched,d=>e
    frontier=e,c,untouched |}]
;;

let%expect_test "fresh tail extension keeps root and original snapshots without discarding payload" =
  let a = D.Event.create ~id:(id "a") ~effects:[ change "jpy" Z.one ] in
  let b = D.Event.create ~id:(id "b") ~effects:[ change "usd" Z.minus_one ] in
  let c = D.Event.create ~id:(id "c") ~effects:[ change "jpy" Z.zero; change "usd" (Z.shift_left Z.one 160) ] in
  let source = [ a; event "untouched"; b ] in
  let old = admitted (memory source) [ edge "a" "b" ] in
  let newer = admitted (memory (c :: source)) [ edge "b" "c"; edge "a" "b" ] in
  let old_row = List.hd_exn (F.lineages old) in
  let new_row = List.hd_exn (F.lineages newer) in
  require (Id.equal (F.root_id old_row) (F.root_id new_row)) "root survives tail extension";
  require (equal_event (F.terminal_event old_row) b) "old snapshot remains b";
  require (equal_event (F.terminal_event new_row) c) "exact new terminal payload";
  require (List.equal equal_event source (D.Event_memory.events (F.retained_events old))) "old source retained";
  Stdlib.Printf.printf "old=%s\nnew=%s\n" (show (F.lineages old)) (show (F.lineages newer));
  [%expect {|
    old=a=>b,untouched=>untouched
    new=a=>c,untouched=>untouched |}]
;;

let%expect_test "prefix insertion deliberately changes root, not a global identity promise" =
  let old = admitted (memory (List.map [ "a"; "b" ] ~f:event)) [ edge "a" "b" ] in
  let newer = admitted (memory (List.map [ "a"; "b"; "prefix" ] ~f:event))
    [ edge "a" "b"; edge "prefix" "a" ] in
  require (not (Id.equal (F.root_id (List.hd_exn (F.lineages old)))
    (F.root_id (List.hd_exn (F.lineages newer))))) "source relation changes root";
  Stdlib.Printf.printf "old=%s; prefix-added=%s\n" (show (F.lineages old)) (show (F.lineages newer));
  [%expect {| old=a=>b; prefix-added=prefix=>b |}]
;;

let%expect_test "exact tokens stay distinct in root and terminal roles" =
  let source = List.map [ "a"; "A"; " a "; "a\000" ] ~f:event in
  let answer = admitted (memory source) [ edge "A" "a\000"; edge "a" " a " ] in
  let pairs = List.map (F.lineages answer) ~f:(fun row -> F.root_id row, D.Event.id (F.terminal_event row)) in
  require (List.equal (fun (a, b) (c, d) -> Id.equal a c && Id.equal b d)
    pairs [ id "a", id " a "; id "A", id "a\000" ]) "exact role associations";
  Stdlib.Printf.printf "two exact, non-aliased root/terminal associations\n";
  [%expect {| two exact, non-aliased root/terminal associations |}]
;;

let%expect_test "invalid topology never exposes a best-effort lineage" =
  let events = memory (List.map [ "a"; "b"; "c" ] ~f:event) in
  List.iter
    [ [ edge "a" "missing" ]; [ edge "a" "b"; edge "a" "b" ]
    ; [ edge "a" "b"; edge "a" "c" ]; [ edge "a" "c"; edge "b" "c" ]
    ; [ edge "a" "a" ]; [ edge "a" "b"; edge "b" "a" ]
    ] ~f:(fun corrections -> require (Result.is_error (F.create ~events ~corrections)) "no partial lineage");
  Stdlib.Printf.printf "absence/repeat/branch/merge/self/cycle refuse before lineage construction\n";
  [%expect {| absence/repeat/branch/merge/self/cycle refuse before lineage construction |}]
;;

let%expect_test "all four-node graph admissions and associations match transitive-closure model" =
  let nodes = [ 0; 1; 2; 3 ] in
  let source = List.map nodes ~f:(fun n -> event (Int.to_string n)) in
  let events = memory source in
  let accepted =
    List.fold (List.init 65_536 ~f:Fn.id) ~init:0 ~f:(fun count mask ->
      let edges = M.edges_of_mask nodes mask in
      let corrections = List.map edges ~f:(fun (a, b) -> edge (Int.to_string a) (Int.to_string b)) in
      let expected = M.analyze ~nodes ~edges in
      match F.create ~events ~corrections, expected with
      | Error _, None -> count
      | Ok answer, Some pairs ->
        let actual = List.map (F.lineages answer) ~f:(fun row ->
          Int.of_string (Id.to_string (F.root_id row)),
          Int.of_string (Id.to_string (D.Event.id (F.terminal_event row)))) in
        require (List.equal M.equal_edge actual pairs) "model-to-code associations and root order";
        let terminals = List.map (F.lineages answer) ~f:F.terminal_event in
        require (List.equal equal_event
          (List.sort terminals ~compare:(fun a b -> Id.compare (D.Event.id a) (D.Event.id b)))
          (F.frontier_events answer)) "terminal membership equals frontier";
        count + 1
      | Error _, Some _ -> failwith "model admitted but implementation refused"
      | Ok _, None -> failwith "model refused but implementation admitted")
  in
  require (Int.equal accepted 73) "all admitted model cases compared";
  Stdlib.Printf.printf "65536 model/code graphs; %d admitted association sets agree (bounded)\n" accepted;
  [%expect {| 65536 model/code graphs; 73 admitted association sets agree (bounded) |}]
;;

let%expect_test "long lineage traversal completes in both correction orders" =
  let count = 10_000 in
  let source = List.init count ~f:(fun n -> event (Int.to_string n)) in
  let corrections = List.init (count - 1) ~f:(fun n -> edge (Int.to_string n) (Int.to_string (n + 1))) in
  List.iter [ corrections; List.rev corrections ] ~f:(fun edges ->
    let answer = admitted (memory source) edges in
    require (Int.equal (List.length (F.lineages answer)) 1) "one long path";
    let row = List.hd_exn (F.lineages answer) in
    require (Id.equal (F.root_id row) (id "0")) "long root";
    require (equal_event (F.terminal_event row) (List.last_exn source)) "long terminal");
  Stdlib.Printf.printf "%d-node root/terminal mapping completed in both edge orders\n" count;
  [%expect {| 10000-node root/terminal mapping completed in both edge orders |}]
;;

module Path_inputs = struct
  type t = int list
  let sexp_of_t values = Sexp.List (List.map values ~f:Int.sexp_of_t)
  let quickcheck_generator =
    let open Base_quickcheck.Generator in
    bind (int_inclusive 0 40) ~f:(fun length -> list_with_length (int_inclusive (-4) 4) ~length)
  let quickcheck_shrinker = Base_quickcheck.Shrinker.list Base_quickcheck.Shrinker.int
end

(* Independent source-list/fuel oracle for generated paths; no map, terminal
   getter, or production-derived root set supplies the expected association. *)
let expected_pairs source corrections =
  let roots = List.filter source ~f:(fun original ->
    not (List.exists corrections ~f:(fun (c : D.Event_correction.t) ->
      Id.equal c.replacement (D.Event.id original)))) in
  let rec follow fuel current =
    match List.find corrections ~f:(fun (c : D.Event_correction.t) -> Id.equal c.target current) with
    | None ->
      (match List.find source ~f:(fun original -> Id.equal (D.Event.id original) current) with
       | Some original -> original
       | None -> failwith "oracle endpoint absent")
    | Some c ->
      if fuel <= 0 then failwith "oracle cycle/fuel exhausted"
      else follow (fuel - 1) c.replacement
  in
  List.map roots ~f:(fun root -> D.Event.id root, follow (List.length source) (D.Event.id root))
;;

let%expect_test "generated disjoint paths preserve exact associations under replay, permutation and extension" =
  let check values =
    let source = List.mapi values ~f:(fun i n ->
      let q = Z.mul (Z.of_int n) (Z.shift_left Z.one 128) in
      D.Event.create ~id:(id ("node:" ^ Int.to_string i))
        ~effects:[ change "jpy" q; change "usd" (Z.neg q); change "jpy" Z.zero ]) in
    let corrections = List.filter_mapi values ~f:(fun i n ->
      if n > 0 && i + 1 < List.length values
      then Some (edge ("node:" ^ Int.to_string i) ("node:" ^ Int.to_string (i + 1)))
      else None) in
    let expected = expected_pairs source corrections in
    let events = memory source in
    let answer = admitted events corrections in
    let check_answer original edges answer expected =
      let actual = List.map (F.lineages answer) ~f:(fun row -> F.root_id row, F.terminal_event row) in
      require (List.equal (fun (a, b) (c, d) -> Id.equal a c && equal_event b d)
        actual expected) "source-list association oracle";
      require (List.equal equal_event original (D.Event_memory.events (F.retained_events answer))) "source retention";
      require (List.equal equal_edge edges (F.corrections answer)) "edge retention";
      let terminals = List.map (F.lineages answer) ~f:F.terminal_event in
      let compare a b = Id.compare (D.Event.id a) (D.Event.id b) in
      require (List.equal equal_event (List.sort terminals ~compare)
        (List.sort (F.frontier_events answer) ~compare)) "all frontier terminals"
    in
    check_answer source corrections answer expected;
    check_answer source corrections (admitted events corrections) expected;
    check_answer (List.rev source) (List.rev corrections)
      (admitted (memory (List.rev source)) (List.rev corrections)) (List.rev expected);
    List.iter expected ~f:(fun (root, terminal) ->
      let fresh = D.Event.create ~id:(id "fresh") ~effects:[ change "kg" Z.minus_one ] in
      let extended_edges = corrections @ [ { D.Event_correction.target = D.Event.id terminal; replacement = D.Event.id fresh } ] in
      let extended_source = source @ [ fresh ] in
      let extended = admitted (memory extended_source) extended_edges in
      let extended_expected = List.map expected ~f:(fun (r, t) -> if Id.equal r root then r, fresh else r, t) in
      check_answer extended_source extended_edges extended extended_expected);
    check_answer source corrections answer expected
  in
  let config =
    { Base_quickcheck.Test.default_config with
      seed = Deterministic "loam-root-lineage-v1"
    ; test_count = 10_000
    ; shrink_count = 10_000
    }
  in
  let checks = ref 0 in
  Base_quickcheck.Test.run_exn (module Path_inputs) ~config ~f:(fun input ->
    check input;
    Int.incr checks);
  require (Int.equal !checks config.test_count) "generated cases actually ran";
  Stdlib.Printf.printf "root/terminal oracle passed (%d generated cases)\n" !checks;
  [%expect {| root/terminal oracle passed (10000 generated cases) |}]
;;
