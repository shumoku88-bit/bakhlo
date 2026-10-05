open Base
module G = Lineage_model
module M = Current_groups_model

let require condition message = if not condition then failwith message

let%expect_test "finite multi-group model preserves whole unrelated premises under re-observation" =
  let nodes = [ 0; 1; 2 ] in
  let pairs =
    match G.analyze ~nodes ~edges:[ (0, 1) ] with
    | None -> failwith "model path refused"
    | Some pairs -> pairs
  in
  let cases, admitted, updates =
    List.fold (List.init 4 ~f:Fn.id) ~init:(0, 0, 0) ~f:(fun counts first_cut ->
        List.fold (List.init 4 ~f:Fn.id) ~init:counts ~f:(fun counts second_cut ->
            List.fold (List.init 16 ~f:Fn.id) ~init:counts
              ~f:(fun (cases, admitted, updates) ownership ->
                let groups = M.old_groups first_cut second_cut ownership in
                match M.admit ~nodes ~pairs groups with
                | Error _ -> (cases + 1, admitted, updates)
                | Ok _ ->
                    let updated_count =
                      List.fold (List.init 4 ~f:Fn.id) ~init:0 ~f:(fun count roots ->
                          List.fold (List.init 4 ~f:Fn.id) ~init:count ~f:(fun count coordinates ->
                              let incoming = M.incoming roots coordinates in
                              match M.reobserve ~nodes ~pairs groups incoming with
                              | Error _ -> failwith "valid model update refused"
                              | Ok updated ->
                                  List.iter [ 0; 1; 2 ] ~f:(fun c ->
                                      let incoming_premise = M.premise [ incoming ] c in
                                      let expected =
                                        if Option.is_some incoming_premise then incoming_premise
                                        else M.premise groups c
                                      in
                                      require
                                        (M.equal_premise (M.premise updated c) expected)
                                        "whole premise replacement law");
                                  (match M.reobserve ~nodes ~pairs updated incoming with
                                  | Error _ -> failwith "model replay refused"
                                  | Ok twice ->
                                      List.iter [ 0; 1; 2 ] ~f:(fun c ->
                                          require
                                            (M.equal_premise (M.premise updated c)
                                               (M.premise twice c))
                                            "lookup idempotence"));
                                  count + 1))
                    in
                    (cases + 1, admitted + 1, updates + updated_count))))
  in
  require (Int.equal cases 256 && Int.equal admitted 144 && Int.equal updates 2_304) "finite counts";
  Stdlib.Printf.printf "%d ownership/cut cases; %d admitted; %d update/replay cases (bounded)\n"
    cases admitted updates;
  [%expect {| 256 ownership/cut cases; 144 admitted; 2304 update/replay cases (bounded) |}]
