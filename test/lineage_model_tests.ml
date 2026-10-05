open Base
module M = Lineage_model

let require condition message = if not condition then failwith message

let%expect_test "finite structural model partitions every admitted four-node graph" =
  let nodes = [ 0; 1; 2; 3 ] in
  let admitted =
    List.fold (List.init 65_536 ~f:Fn.id) ~init:0 ~f:(fun count mask ->
        let edges = M.edges_of_mask nodes mask in
        match M.analyze ~nodes ~edges with
        | None -> count
        | Some pairs ->
            let reach = M.closure ~nodes ~edges in
            require (M.unique fst pairs && M.unique snd pairs) "distinct roots and terminals";
            List.iter nodes ~f:(fun node ->
                let owners =
                  List.filter pairs ~f:(fun (root, terminal) ->
                      (Int.equal root node || M.contains reach root node)
                      && (Int.equal node terminal || M.contains reach node terminal))
                in
                require (Int.equal (List.length owners) 1) "one complete lineage per node");
            let terminals = List.filter nodes ~f:(fun node -> not (M.has_outgoing edges node)) in
            require
              (List.equal Int.equal
                 (List.sort (List.map pairs ~f:snd) ~compare:Int.compare)
                 terminals)
              "terminal coverage";
            count + 1)
  in
  require (Int.equal admitted 73) "expected finite disjoint-path count";
  Stdlib.Printf.printf "65536 graphs; %d disjoint-path relations; complete partitions (bounded)\n"
    admitted;
  [%expect {| 65536 graphs; 73 disjoint-path relations; complete partitions (bounded) |}]

let%expect_test "model distinguishes roots from intermediate and terminal identities" =
  let nodes = [ 0; 1; 2; 3 ] in
  let edges = [ (0, 1); (1, 2) ] in
  (match M.analyze ~nodes ~edges with
  | Some pairs ->
      require (List.equal M.equal_edge pairs [ (0, 2); (3, 3) ]) "correct associations";
      let reach = M.closure ~nodes ~edges in
      require (M.contains reach 1 2) "intermediate reaches terminal";
      require (M.has_incoming edges 1) "reachable intermediate is not root";
      require (M.has_outgoing edges 1) "intermediate is not terminal";
      require (not (List.mem pairs (1, 2) ~equal:M.equal_edge)) "wrong-root association detected"
  | None -> failwith "valid model refused");
  require (Option.is_none (M.analyze ~nodes ~edges:[ (0, 1); (0, 2) ])) "branch refused";
  require (Option.is_none (M.analyze ~nodes ~edges:[ (0, 2); (1, 2) ])) "merge refused";
  require (Option.is_none (M.analyze ~nodes ~edges:[ (0, 1); (1, 0) ])) "cycle refused";
  require (Option.is_none (M.analyze ~nodes ~edges:[ (0, 4) ])) "missing node refused";
  require (Option.is_none (M.analyze ~nodes ~edges:[ (0, 1); (0, 1) ])) "parallel repeat refused";
  Stdlib.Printf.printf "0->1->2 maps 0=>2, not 1=>2; untouched 3=>3\n";
  [%expect {| 0->1->2 maps 0=>2, not 1=>2; untouched 3=>3 |}]
