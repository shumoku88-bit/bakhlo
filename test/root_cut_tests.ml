open Base
module D = Loam_domain
module Id = D.Identifier.Event
module F = Loam_application.Correction_frontier
module C = Loam_application.Reflected_root_cut
module G = Lineage_model
module M = Root_cut_model
module T = Fixtures

let require = T.require
let id = T.id
let event = T.event
let edge = T.edge
let admitted = T.admitted
let memory = T.memory
let equal_event = T.equal_event
let equal_lineage = T.equal_lineage

let cut = T.cut

let show_events events =
  String.concat ~sep:"," (List.map events ~f:(fun e -> Id.to_string (D.Event.id e)))
;;

let show_error = function
  | C.Duplicate_root { id; first_position; position } ->
    Printf.sprintf "duplicate %S at %d (first %d)" (Id.to_string id) position first_position
  | C.Unknown_event { id; position } ->
    Printf.sprintf "unknown %S at %d" (Id.to_string id) position
  | C.Not_root { id; position } ->
    Printf.sprintf "not-root %S at %d" (Id.to_string id) position
;;

let same_error actual expected =
  match actual, expected with
  | C.Duplicate_root { id; first_position; position }, M.Duplicate_root expected ->
    String.equal (Id.to_string id) (Int.to_string expected.id)
    && Int.equal first_position expected.first_position && Int.equal position expected.position
  | C.Unknown_event { id; position }, M.Unknown_event expected ->
    String.equal (Id.to_string id) (Int.to_string expected.id) && Int.equal position expected.position
  | C.Not_root { id; position }, M.Not_root expected ->
    String.equal (Id.to_string id) (Int.to_string expected.id) && Int.equal position expected.position
  | C.Duplicate_root _, (M.Unknown_event _ | M.Not_root _)
  | C.Unknown_event _, (M.Duplicate_root _ | M.Not_root _)
  | C.Not_root _, (M.Duplicate_root _ | M.Unknown_event _) -> false
;;

let require_source = T.require_cut_source

let%expect_test "explicit empty, untouched and complete cuts never imply origin or missing-loader success" =
  let empty = cut (admitted (memory []) []) [] in
  require (List.is_empty (C.remaining_events empty)) "explicit empty basis";
  let source = admitted (memory (List.map [ "one"; "two" ] ~f:event)) [] in
  let none = cut source [] in
  let all = cut source [ id "two"; id "one" ] in
  require_source source none [];
  require_source source all [ id "two"; id "one" ];
  Stdlib.Printf.printf "empty=%s; no-reflection=%s; all-reflected=%s\n"
    (show_events (C.remaining_events empty)) (show_events (C.remaining_events none))
    (show_events (C.remaining_events all));
  [%expect {| empty=; no-reflection=one,two; all-reflected= |}]
;;

let%expect_test "partial cuts retain exact general observations and root order, not terminal order" =
  let c = D.Event.create ~id:(id "c") ~effects:
    [ T.here_change "jpy" (Z.shift_left Z.one 128); T.here_change "usd" Z.zero; T.here_change "jpy" Z.minus_one ] in
  let source = [ event "e"; c; event "a"; event "untouched"; event "b"; event "d" ] in
  let frontier = admitted (memory source) [ edge "b" "c"; edge "d" "e"; edge "a" "b" ] in
  let none = cut frontier [] in
  let partial = cut frontier [ id "d" ] in
  require (List.equal equal_event (C.remaining_events partial) [ c; event "untouched" ]) "unreflected payloads exact";
  require_source frontier partial [ id "d" ];
  let one = cut frontier [ id "untouched"; id "d" ] in
  let reordered = cut frontier [ id "d"; id "untouched" ] in
  require (List.equal equal_lineage (C.remaining_lineages one) (C.remaining_lineages reordered)) "declaration order is not priority";
  Stdlib.Printf.printf "empty-cut=%s; source-frontier=%s; partial=%s\n"
    (show_events (C.remaining_events none)) (show_events (F.frontier_events frontier))
    (show_events (C.remaining_events partial));
  [%expect {| empty-cut=c,untouched,e; source-frontier=e,c,untouched; partial=c,untouched |}]
;;

let%expect_test "cut refusals are ordered, positional and exact-token aware" =
  let source = List.map [ "a"; "b"; "c"; "A"; " a "; "a\000" ] ~f:event in
  let frontier = admitted (memory source) [ edge "a" "b"; edge "b" "c" ] in
  List.iter
    [ [ "a"; "a"; "missing" ]; [ "a"; "missing"; "a" ]; [ "b"; "b" ]
    ; [ "a"; "c" ]; [ "missing"; "missing" ]
    ] ~f:(fun declarations ->
      match C.create ~frontier ~reflected_roots:(List.map declarations ~f:id) with
      | Ok _ -> failwith "invalid cut admitted"
      | Error error -> Stdlib.Printf.printf "%s\n" (show_error error));
  let exact = cut frontier [ id "A"; id " a "; id "a\000" ] in
  require (List.equal equal_event (C.remaining_events exact) [ event "c" ]) "no alias to root a";
  [%expect {|
    duplicate "a" at 2 (first 1)
    unknown "missing" at 2
    not-root "b" at 1
    not-root "c" at 2
    unknown "missing" at 1 |}]
;;

let%expect_test "reflected root still excludes a fresh terminal that old-terminal filtering would leak" =
  let old_source = admitted (memory (List.map [ "a"; "b"; "other" ] ~f:event)) [ edge "a" "b" ] in
  let old = cut old_source [ id "a" ] in
  let new_source = admitted (memory (List.map [ "a"; "b"; "other"; "c" ] ~f:event))
    [ edge "b" "c"; edge "a" "b" ] in
  let newer = cut new_source (C.reflected_roots old) in
  require_source old_source old [ id "a" ];
  require_source new_source newer [ id "a" ];
  let stale_terminal_filter = List.filter (F.frontier_events new_source) ~f:(fun e ->
    not (Id.equal (D.Event.id e) (id "b"))) in
  require (List.exists stale_terminal_filter ~f:(fun e -> Id.equal (D.Event.id e) (id "c"))) "distinguishing leak witness";
  Stdlib.Printf.printf "root-cut old=%s; new=%s; stale-terminal-filter=%s\n"
    (show_events (C.remaining_events old)) (show_events (C.remaining_events newer))
    (show_events stale_terminal_filter);
  [%expect {| root-cut old=other; new=other; stale-terminal-filter=other,c |}]
;;

let%expect_test "rebinding rechecks prefix changes and absent roots while old cut remains unchanged" =
  let original = admitted (memory (List.map [ "a"; "b" ] ~f:event)) [ edge "a" "b" ] in
  let old = cut original [ id "a" ] in
  let prefix = admitted (memory (List.map [ "prefix"; "a"; "b" ] ~f:event))
    [ edge "prefix" "a"; edge "a" "b" ] in
  let omitted = admitted (memory [ event "b" ]) [] in
  List.iter [ prefix; omitted ] ~f:(fun frontier ->
    match C.create ~frontier ~reflected_roots:(C.reflected_roots old) with
    | Ok _ -> failwith "stale declaration authorized in changed scope"
    | Error error -> Stdlib.Printf.printf "%s\n" (show_error error));
  require (List.is_empty (C.remaining_events old)) "old snapshot unchanged";
  require_source original old [ id "a" ];
  [%expect {|
    not-root "a" at 1
    unknown "a" at 1 |}]
;;

let%expect_test "four-node relation/subset cuts and fresh-tail seams agree with independent model" =
  let nodes = [ 0; 1; 2; 3 ] in
  let source = List.map nodes ~f:(fun n -> event (Int.to_string n)) in
  let pairs_of_cut answer = List.map (C.remaining_lineages answer) ~f:(fun row ->
    Int.of_string (Id.to_string (F.root_id row)),
    Int.of_string (Id.to_string (D.Event.id (F.terminal_event row)))) in
  let cases, accepted =
    List.fold (List.init 65_536 ~f:Fn.id) ~init:(0, 0) ~f:(fun counts graph_mask ->
      let edges = G.edges_of_mask nodes graph_mask in
      match G.analyze ~nodes ~edges with
      | None -> counts
      | Some pairs ->
        let corrections = List.map edges ~f:(fun (a, b) -> edge (Int.to_string a) (Int.to_string b)) in
        let frontier = admitted (memory source) corrections in
        List.fold (List.init 16 ~f:Fn.id) ~init:counts ~f:(fun (cases, accepted) mask ->
          let reflected = M.declaration_of_mask nodes mask in
          let declarations = List.map reflected ~f:(fun n -> id (Int.to_string n)) in
          match C.create ~frontier ~reflected_roots:declarations, M.cut ~nodes ~pairs ~reflected with
          | Error actual, Error expected ->
            require (same_error actual expected) "model refusal/position seam";
            cases + 1, accepted
          | Ok answer, Ok expected ->
            require_source frontier answer declarations;
            require (List.equal G.equal_edge (pairs_of_cut answer) expected) "model selected pair seam";
            List.iter pairs ~f:(fun (root, terminal) ->
              let extended = admitted (memory (source @ [ event "4" ]))
                (edge (Int.to_string terminal) "4" :: corrections) in
              let updated_cut = cut extended declarations in
              let updated_expected = List.map expected ~f:(fun (r, t) -> if Int.equal r root then r, 4 else r, t) in
              require (List.equal G.equal_edge (pairs_of_cut updated_cut) updated_expected) "fresh terminal proof/model/code seam");
            cases + 1, accepted + 1
          | Error _, Ok _ -> failwith "model cut admitted but implementation refused"
          | Ok _, Error _ -> failwith "model cut refused but implementation admitted"))
  in
  require (Int.equal cases 1_168 && Int.equal accepted 304) "actual compared cases";
  Stdlib.Printf.printf "%d relation/declaration cases; %d admitted cuts agree; fresh tails agree (bounded)\n" cases accepted;
  [%expect {| 1168 relation/declaration cases; 304 admitted cuts agree; fresh tails agree (bounded) |}]
;;

let%expect_test "whole-root exclusion of a 10000-node chain keeps its source and needs no new graph walk" =
  let count = 10_000 in
  let source = List.init count ~f:(fun n -> event (Int.to_string n)) in
  let corrections = List.init (count - 1) ~f:(fun n -> edge (Int.to_string n) (Int.to_string (n + 1))) in
  let frontier = admitted (memory source) (List.rev corrections) in
  let answer = cut frontier [ id "0" ] in
  require (List.is_empty (C.remaining_events answer)) "whole chain reflected";
  require_source frontier answer [ id "0" ];
  require (List.equal equal_event (C.remaining_events (cut frontier [])) [ List.last_exn source ]) "exact chain terminal";
  Stdlib.Printf.printf "%d-node chain cut completes; all sources retained\n" count;
  [%expect {| 10000-node chain cut completes; all sources retained |}]
;;

module Inputs = struct
  type t = int list * int list
  let sexp_of_t (path, declarations) = Sexp.List [ T.Path_inputs.sexp_of_t path; T.Path_inputs.sexp_of_t declarations ]
  let quickcheck_generator =
    let open Base_quickcheck.Generator in
    let path = bind (int_inclusive 0 24) ~f:(fun length -> list_with_length (int_inclusive (-4) 4) ~length) in
    let declarations = bind (int_inclusive 0 12) ~f:(fun length -> list_with_length (int_inclusive (-2) 27) ~length) in
    both path declarations
  let quickcheck_shrinker = Base_quickcheck.Shrinker.both T.Path_inputs.quickcheck_shrinker T.Path_inputs.quickcheck_shrinker
end

let%expect_test "generated cut admission, exact payload selection, replay and rebinding match a source-list oracle" =
  let check (values, selectors) =
    let source = List.mapi values ~f:(fun i n ->
      let q = Z.mul (Z.of_int n) (Z.shift_left Z.one 140) in
      D.Event.create ~id:(id (Int.to_string i))
        ~effects:[ T.here_change "jpy" q; T.here_change "usd" (Z.neg q); T.here_change "jpy" Z.zero ]) in
    let nodes = List.init (List.length source) ~f:Fn.id in
    let corrections = List.filter_mapi values ~f:(fun i n ->
      if n > 0 && i + 1 < List.length source
      then Some (edge (Int.to_string i) (Int.to_string (i + 1))) else None) in
    let rooted = Source_oracle.expected_pairs source corrections in
    let model_pairs = List.map rooted ~f:(fun (root, terminal) ->
      Int.of_string (Id.to_string root), Int.of_string (Id.to_string (D.Event.id terminal))) in
    let frontier = admitted (memory source) corrections in
    let check_declarations reflected =
      let declarations = List.map reflected ~f:(fun n -> id (Int.to_string n)) in
      match C.create ~frontier ~reflected_roots:declarations, M.cut ~nodes ~pairs:model_pairs ~reflected with
      | Error actual, Error expected -> require (same_error actual expected) "source-list admission oracle"
      | Ok answer, Ok pairs ->
        let expected = List.filter rooted ~f:(fun (root, _) ->
          List.exists pairs ~f:(fun (r, _) -> String.equal (Id.to_string root) (Int.to_string r))) in
        require_source frontier answer declarations;
        require (List.equal equal_event (C.remaining_events answer) (List.map expected ~f:snd)) "exact source-list payload oracle";
        let replay = cut frontier declarations in
        let permuted = cut (admitted (memory (List.rev source)) (List.rev corrections)) (List.rev declarations) in
        require (List.equal equal_lineage (C.remaining_lineages answer) (C.remaining_lineages replay)) "replay";
        require (List.equal equal_lineage (List.rev (C.remaining_lineages answer)) (C.remaining_lineages permuted)) "representation permutation";
        List.iter rooted ~f:(fun (root, terminal) ->
          let fresh = D.Event.create ~id:(id "fresh") ~effects:[ T.here_change "kg" Z.minus_one ] in
          let extended_frontier = admitted (memory (source @ [ fresh ]))
            (corrections @ [ { D.Event_correction.target = D.Event.id terminal; replacement = D.Event.id fresh } ]) in
          let extended = cut extended_frontier declarations in
          let extended_expected = List.map expected ~f:(fun (r, t) -> if Id.equal r root then fresh else t) in
          require (List.equal equal_event (C.remaining_events extended) extended_expected) "terminal-only update law seam";
          require_source extended_frontier extended declarations);
        require_source frontier answer declarations
      | Error _, Ok _ -> failwith "oracle admitted but implementation refused"
      | Ok _, Error _ -> failwith "oracle refused but implementation admitted"
    in
    check_declarations selectors;
    let valid = List.filter_mapi rooted ~f:(fun i (root, _) ->
      if List.mem selectors i ~equal:Int.equal then Some (Int.of_string (Id.to_string root)) else None) in
    check_declarations valid;
    List.iter (List.hd valid |> Option.to_list) ~f:(fun root -> check_declarations (valid @ [ root ]));
    check_declarations [ -1 ];
    let non_root = List.find nodes ~f:(fun node -> not (List.exists model_pairs ~f:(fun (root, _) -> Int.equal node root))) in
    List.iter (Option.to_list non_root) ~f:(fun node -> check_declarations [ node ])
  in
  let config =
    { Base_quickcheck.Test.default_config with
      seed = Deterministic "loam-reflected-root-cut-v1"
    ; test_count = 10_000
    ; shrink_count = 10_000
    }
  in
  let checks = ref 0 in
  Base_quickcheck.Test.run_exn (module Inputs) ~config ~f:(fun input -> check input; Int.incr checks);
  require (Int.equal !checks config.test_count) "generated cases actually ran";
  Stdlib.Printf.printf "cut oracle passed (%d generated cases)\n" !checks;
  [%expect {| cut oracle passed (10000 generated cases) |}]
;;
