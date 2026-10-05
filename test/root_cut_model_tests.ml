open Base
module G = Lineage_model
module C = Root_cut_model

let require condition message = if not condition then failwith message

let%expect_test "finite cut model selects complete roots and remains stable under fresh tails" =
  let nodes = [ 0; 1; 2; 3 ] in
  let cases, accepted =
    List.fold (List.init 65_536 ~f:Fn.id) ~init:(0, 0) ~f:(fun counts graph_mask ->
        let edges = G.edges_of_mask nodes graph_mask in
        match G.analyze ~nodes ~edges with
        | None -> counts
        | Some pairs ->
            List.fold (List.init 16 ~f:Fn.id) ~init:counts ~f:(fun (cases, accepted) mask ->
                let reflected = C.declaration_of_mask nodes mask in
                match C.cut ~nodes ~pairs ~reflected with
                | Error _ ->
                    require
                      (List.exists reflected ~f:(fun node -> G.has_incoming edges node))
                      "only non-root declarations fail in this bound";
                    (cases + 1, accepted)
                | Ok selected ->
                    require
                      (List.equal G.equal_edge selected (C.select ~reflected pairs))
                      "cut partition";
                    List.iter pairs ~f:(fun (root, terminal) ->
                        let updated_edges = (terminal, 4) :: edges in
                        match G.analyze ~nodes:(nodes @ [ 4 ]) ~edges:updated_edges with
                        | None -> failwith "fresh terminal extension refused by graph model"
                        | Some updated_pairs -> (
                            let expected =
                              List.map selected ~f:(fun (r, t) ->
                                  if Int.equal r root then (r, 4) else (r, t))
                            in
                            match C.cut ~nodes:(nodes @ [ 4 ]) ~pairs:updated_pairs ~reflected with
                            | Error _ -> failwith "same roots refused after terminal extension"
                            | Ok actual ->
                                require
                                  (List.equal G.equal_edge actual expected)
                                  "terminal update commutes with root selection"));
                    (cases + 1, accepted + 1)))
  in
  require (Int.equal cases 1_168 && Int.equal accepted 304) "finite model execution counts";
  let pairs = [ (0, 2); (3, 3) ] in
  require (Result.is_error (C.cut ~nodes ~pairs ~reflected:[ 1 ])) "intermediate not root";
  require (Result.is_error (C.cut ~nodes ~pairs ~reflected:[ 2 ])) "terminal not root";
  require (Result.is_error (C.cut ~nodes ~pairs ~reflected:[ 4 ])) "unknown not ignored";
  require (Result.is_error (C.cut ~nodes ~pairs ~reflected:[ 0; 0 ])) "duplicate not normalized";
  Stdlib.Printf.printf
    "%d graph/declaration cases; %d admitted cuts; fresh-tail model checks passed (bounded)\n" cases
    accepted;
  [%expect
    {| 1168 graph/declaration cases; 304 admitted cuts; fresh-tail model checks passed (bounded) |}]
