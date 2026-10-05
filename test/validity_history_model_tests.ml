open Base
module M = Validity_history_model

let%expect_test
    "validity model requires same-Event unique complete terminal dates, not bases or latest arrival"
    =
  let require condition = if not condition then failwith "validity model counterexample" in
  let analyze nodes edges = M.analyze ~nodes ~edges ~revision_events:[ 0; 1 ] in
  require
    (Option.equal (List.equal Int.equal)
       (analyze [ 0; 1; 2; 3 ] [ (0, 2); (1, 3) ])
       (Some [ 2; 3 ]));
  require (Option.equal (List.equal Int.equal) (analyze [ 2; 3 ] []) (Some [ 2; 3 ]));
  List.iter
    [
      ([ 0; 1; 2 ], []);
      ([ 0; 1; 2 ], [ (1, 2) ]);
      ([ 0; 1 ], [ (0, 2) ]);
      ([ 0; 1; 2 ], [ (0, 2); (2, 2) ]);
      ([ 0; 2 ], [ (0, 2) ]);
    ]
    ~f:(fun (nodes, edges) -> require (Option.is_none (analyze nodes edges)));
  let admitted = ref 0 in
  for subset = 0 to 15 do
    for assignment = 0 to 3 do
      for relation = 0 to 255 do
        match
          M.analyze ~nodes:(M.nodes subset) ~edges:(M.edges relation)
            ~revision_events:(M.assignment assignment)
        with
        | None -> ()
        | Some terminals ->
            Int.incr admitted;
            require (List.length terminals = 2);
            require
              (List.for_all terminals ~f:(fun node ->
                   not (Lineage_model.has_outgoing (M.edges relation) node)))
      done
    done
  done;
  require (!admitted = 36);
  Stdlib.Printf.printf
    "16384 four-fact subset/ownership/relation cases; 36 admitted; revision-only allowed\n";
  [%expect
    {| 16384 four-fact subset/ownership/relation cases; 36 admitted; revision-only allowed |}]
