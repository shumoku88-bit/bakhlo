open Base
module D = Loam_domain
module H = Loam_application.Current_quantity_groups
module P = Loam_application.Current_quantity_projection
module F = Loam_application.Correction_frontier
module Cut = Loam_application.Reflected_root_cut
module Q = D.Quantity
module T = Fixtures
module CT = Fixtures
module G = Lineage_model
module M = Current_groups_model
module CM = Root_cut_model
let require = T.require
let ok = function Ok value -> value | Error _ -> failwith "valid fixture refused"
let coordinate n = if n < 4 then CT.fixture_coordinate n else CT.coordinate ("unsupported-" ^ Int.to_string n)
let identifier n = T.id (Int.to_string n)
let group (g : M.group) : H.group =
  { reflected_roots = List.map g.roots ~f:identifier
  ; assertions = List.map g.assertions ~f:(fun (c, q) -> CT.assertion (coordinate c) q) }
;;
let equal_group (a : H.group) (b : H.group) =
  List.equal D.Identifier.Event.equal a.reflected_roots b.reflected_roots
  && List.equal CT.same_assertion a.assertions b.assertions
;;
let create frontier groups = match H.create ~frontier ~groups:(List.map groups ~f:group) with
  | Ok image -> image
  | Error _ -> failwith "valid group fixture refused"
;;
let update image incoming = match H.reobserve image (group incoming) with
  | Ok image -> image
  | Error _ -> failwith "valid update fixture refused"
;;
let fixture values =
  let source = List.mapi values ~f:(fun i n ->
    D.Event.create ~id:(identifier i) ~effects:
      [ CT.change (coordinate (i % 4)) (Z.mul (Z.of_int n) (Z.shift_left Z.one 128))
      ; CT.change (coordinate ((i + 1) % 4)) (Z.of_int (n - 1))
      ; CT.change (coordinate 0) Z.one; CT.change (coordinate 0) Z.one
      ; CT.change (coordinate 2) Z.zero ]) in
  let edges = List.filter_mapi values ~f:(fun i n ->
    if n > 0 && i + 1 < List.length values then Some (i, i + 1) else None) in
  let corrections = List.map edges ~f:(fun (a, b) -> T.edge (Int.to_string a) (Int.to_string b)) in
  let nodes = List.init (List.length values) ~f:Fn.id in
  let pairs = match G.analyze ~nodes ~edges with Some pairs -> pairs | None -> failwith "fixture graph" in
  source, corrections, nodes, pairs
;;

let same_error actual expected =
  match actual, expected with
  | H.Invalid_cut { group_position = a; error }, M.Invalid_cut { group_position = b; error = expected } ->
    Int.equal a b && (match error, expected with
      | Cut.Duplicate_root { id; first_position; position }, CM.Duplicate_root { id = n; first_position = first; position = pos } ->
        D.Identifier.Event.equal id (identifier n) && Int.equal first_position first && Int.equal position pos
      | Cut.Unknown_event { id; position }, CM.Unknown_event { id = n; position = pos }
      | Cut.Not_root { id; position }, CM.Not_root { id = n; position = pos } ->
        D.Identifier.Event.equal id (identifier n) && Int.equal position pos
      | (Cut.Duplicate_root _ | Cut.Unknown_event _ | Cut.Not_root _), _ -> false)
  | H.Invalid_assertions { group_position = a; error = P.Duplicate_coordinate { coordinate = c; first_position; position } },
    M.Invalid_assertions { group_position = b; coordinate = n; first_position = first; position = pos } ->
    Int.equal a b && D.Effect_coordinate.equal c (coordinate n) && Int.equal first_position first && Int.equal position pos
  | H.Repeated_coordinate { coordinate = c; first_group_position; first_assertion_position; group_position; assertion_position },
    M.Repeated_coordinate { coordinate = n; first_group_position = first_group; first_assertion_position = first_assertion;
      group_position = current_group; assertion_position = current_assertion } ->
    D.Effect_coordinate.equal c (coordinate n) && Int.equal first_group_position first_group
    && Int.equal first_assertion_position first_assertion && Int.equal group_position current_group
    && Int.equal assertion_position current_assertion
  | (H.Invalid_cut _ | H.Invalid_assertions _ | H.Repeated_coordinate _), _ -> false
;;

(* Original-list/model oracle: cut/owner tests use integer coordinates and independent
   closure; quantity walks original Effects. Never reads production aggregation maps. *)
let verify image groups source corrections nodes pairs =
  require (List.equal equal_group (H.groups image) (List.map groups ~f:group)) "exact group/cut/assertion representation";
  require (List.equal T.equal_event source (D.Event_memory.events (F.retained_events (H.source_frontier image)))) "unmodified source observations";
  require (List.equal T.equal_edge corrections (F.corrections (H.source_frontier image))) "unmodified source corrections";
  List.iter [ 0; 1; 2; 3; 4 ] ~f:(fun code ->
    let c = coordinate code in
    let expected_group = List.find groups ~f:(fun (g : M.group) -> List.exists g.assertions ~f:(fun (n, _) -> Int.equal n code)) in
    match expected_group, H.group_for image c, H.query image c with
    | None, None, Error (P.Assertion_unknown { coordinate = actual }) ->
      require (D.Effect_coordinate.equal c actual) "typed unknown identity"
    | Some expected, Some owner, Ok actual ->
      let input = group expected in
      require (List.equal CT.same_assertion (P.assertions owner) input.assertions) "whole owning group's assertions";
      T.require_cut_source (H.source_frontier image) (P.source_cut owner) input.reflected_roots;
      let selected = match CM.cut ~nodes ~pairs ~reflected:expected.roots with Ok selected -> selected | Error _ -> failwith "invalid oracle cut" in
      let selected_events = List.map selected ~f:(fun (_, terminal) -> List.nth_exn source terminal) in
      let asserted = snd (List.find_exn expected.assertions ~f:(fun (n, _) -> Int.equal n code)) in
      let delta = Source_oracle.sum_events selected_events c in
      require (D.Effect_coordinate.equal (P.coordinate actual) c) "answer coordinate";
      require (Z.equal (Q.quanta (P.asserted_quantity actual)) asserted) "exact original assertion";
      require (Z.equal (Q.quanta (P.delta actual)) delta) "independent original-Effect delta";
      require (Z.equal (Q.quanta (P.quantity actual)) (Z.add asserted delta)) "exact oracle quantity";
      require (Q.equal (P.quantity actual) (Q.add (P.asserted_quantity actual) (P.delta actual))) "decomposition"
    | _ -> failwith "ownership/support mismatch")
;;

let check_creation frontier groups source corrections nodes pairs =
  match H.create ~frontier ~groups:(List.map groups ~f:group), M.admit ~nodes ~pairs groups with
  | Error actual, Error expected -> require (same_error actual expected) "ordered construction diagnostic"; None
  | Ok image, Ok _ -> verify image groups source corrections nodes pairs; Some image
  | _ -> failwith "construction admission mismatch"
;;
let check_update image groups incoming source corrections nodes pairs =
  match H.reobserve image (group incoming), M.reobserve ~nodes ~pairs groups incoming with
  | Error actual, Error expected -> require (same_error actual expected) "ordered incoming diagnostic"; verify image groups source corrections nodes pairs; None
  | Ok updated, Ok updated_groups ->
    verify updated updated_groups source corrections nodes pairs;
    verify image groups source corrections nodes pairs;
    let twice = update updated incoming in
    let twice_expected = ok (M.reobserve ~nodes ~pairs updated_groups incoming) in
    List.iter [ 0; 1; 2; 3; 4 ] ~f:(fun code ->
      require (M.equal_premise (M.premise updated_groups code) (M.premise twice_expected code)) "spec lookup replay");
    verify twice twice_expected source corrections nodes pairs;
    Some updated
  | _ -> failwith "re-observation admission mismatch"
;;
let quantity image n = match H.query image (coordinate n) with
  | Ok answer -> Q.quanta (P.quantity answer)
  | Error _ -> failwith "fixture query unsupported"
;;

let%expect_test "independent reflected cuts must not merge across coordinate owners" =
  let source =
    [ D.Event.create ~id:(identifier 0) ~effects:[ CT.change (coordinate 0) (Z.of_int 999) ]
    ; D.Event.create ~id:(identifier 1) ~effects:[ CT.change (coordinate 0) (Z.of_int (-2)); CT.change (coordinate 2) (Z.of_int 20) ]
    ; D.Event.create ~id:(identifier 2) ~effects:[ CT.change (coordinate 0) (Z.of_int 7); CT.change (coordinate 2) (Z.of_int 30) ] ] in
  let corrections = [ T.edge "0" "1" ] in
  let pairs = [ 0, 1; 2, 2 ] in
  let groups : M.group list =
    [ { roots = [ 0 ]; assertions = [ 0, Z.of_int 10 ] }
    ; { roots = [ 0; 2 ]; assertions = [ 2, Z.of_int 100 ] } ] in
  let image = create (T.admitted (T.memory source) corrections) groups in
  verify image groups source corrections [ 0; 1; 2 ] pairs;
  Stdlib.Printf.printf "same Locus/different Measure: %s / %s (independent cuts)\n"
    (Z.to_string (quantity image 0)) (Z.to_string (quantity image 2));
  let incoming : M.group = { roots = [ 2; 0 ]; assertions = [ 0, Z.of_int 10 ] } in
  let updated = update image incoming in
  Stdlib.Printf.printf "explicit re-observation: %s / %s; old remains %s\n"
    (Z.to_string (quantity updated 0)) (Z.to_string (quantity updated 2)) (Z.to_string (quantity image 0));
  [%expect {|
    same Locus/different Measure: 17 / 100 (independent cuts)
    explicit re-observation: 10 / 100; old remains 17 |}]
;;

let%expect_test "root then whole local then cross-group checks have precise ordered refusal witnesses" =
  let source, corrections, nodes, pairs = fixture [ 1; 0; 0 ] in
  let frontier = T.admitted (T.memory source) corrections in
  let empty : M.group = { roots = []; assertions = [] } in
  let old : M.group = { roots = [ 0 ]; assertions = [ 1, Z.zero; 0, Z.one ] } in
  let cases : M.group list list =
    [ [ empty; old; { roots = [ 9 ]; assertions = [ 0, Z.one; 0, Z.one ] } ]
    ; [ empty; old; { roots = [ 1 ]; assertions = [ 0, Z.one ] } ]
    ; [ empty; old; { roots = [ 2; 2 ]; assertions = [] } ]
    ; [ empty; old; { roots = []; assertions = [ 0, Z.one; 3, Z.zero; 3, Z.zero ] } ]
    ; [ empty; old; { roots = []; assertions = [ 2, Z.zero; 0, Z.one; 1, Z.zero ] } ]
    ; [ empty; old; old ]
    ; [ old; old; { roots = [ 9 ]; assertions = [] } ] ] in
  List.iter cases ~f:(fun groups -> require (Option.is_none (check_creation frontier groups source corrections nodes pairs)) "malformed image admitted");
  (match H.create ~frontier ~groups:(List.map (List.nth_exn cases 4) ~f:group) with
   | Error (H.Repeated_coordinate { first_group_position; first_assertion_position; group_position; assertion_position; coordinate = c }) ->
     require (D.Effect_coordinate.equal c (coordinate 0)) "first overlapping assertion";
     Stdlib.Printf.printf "coordinate overlap: first=(%d,%d), repeated=(%d,%d)\n" first_group_position first_assertion_position group_position assertion_position
   | _ -> failwith "wrong overlap diagnostic");
  Stdlib.Printf.printf "seven root/local/global precedence specimens matched independent lists\n";
  [%expect {|
    coordinate overlap: first=(2,2), repeated=(3,2)
    seven root/local/global precedence specimens matched independent lists |}]
;;

let%expect_test "partial re-observation preserves unrelated assertions and their entire original cuts" =
  let source, corrections, nodes, pairs = fixture [ 1; 0; -7 ] in
  let groups : M.group list =
    [ { roots = [ 2; 0 ]; assertions = [ 1, Z.of_int 11; 0, Z.of_int 10 ] }
    ; { roots = [ 0 ]; assertions = [ 2, Z.shift_left Z.one 150 ] }
    ; { roots = [ 2 ]; assertions = [] } ] in
  let image = create (T.admitted (T.memory source) corrections) groups in
  let incoming : M.group = { roots = []; assertions = [ 0, Z.minus_one; 3, Z.zero ] } in
  let updated = Option.value_exn (check_update image groups incoming source corrections nodes pairs) in
  require (Q.equal (P.quantity (ok (H.query image (coordinate 1))))
    (P.quantity (ok (H.query updated (coordinate 1))))) "surviving same-group coordinate";
  require (Z.equal (quantity image 2) (quantity updated 2)) "whole unrelated group";
  Stdlib.Printf.printf "two surviving groups plus incoming; unrelated cuts/assertions and old image retained\n";
  [%expect {| two surviving groups plus incoming; unrelated cuts/assertions and old image retained |}]
;;

let%expect_test "invalid incoming refuses before removal and uses incoming-local positions" =
  let source, corrections, nodes, pairs = fixture [ 1; 0; -1 ] in
  let groups : M.group list = [ { roots = [ 0 ]; assertions = [ 0, Z.one; 1, Z.zero ] } ] in
  let image = create (T.admitted (T.memory source) corrections) groups in
  let incoming : M.group list =
    [ { roots = [ 9 ]; assertions = [ 0, Z.zero ] }
    ; { roots = [ 1 ]; assertions = [ 0, Z.zero ] }
    ; { roots = [ 0; 0 ]; assertions = [ 0, Z.zero ] }
    ; { roots = []; assertions = [ 0, Z.zero; 2, Z.zero; 0, Z.zero ] } ] in
  List.iter incoming ~f:(fun incoming -> require (Option.is_none (check_update image groups incoming source corrections nodes pairs)) "invalid incoming admitted");
  Stdlib.Printf.printf "four invalid updates refuse with old image unchanged\n";
  [%expect {| four invalid updates refuse with old image unchanged |}]
;;

let%expect_test "empty groups remain qualified declarations; empty incoming replaces no coordinate" =
  let source, corrections, nodes, pairs = fixture [ 1; 0; 0 ] in
  let frontier = T.admitted (T.memory source) corrections in
  let empty : M.group = { roots = [ 2; 0 ]; assertions = [] } in
  let supported : M.group = { roots = []; assertions = [ 0, Z.zero ] } in
  let groups = [ empty; supported; empty ] in
  let image = create frontier groups in
  let updated = Option.value_exn (check_update image groups empty source corrections nodes pairs) in
  require (Int.equal (List.length (H.groups updated)) 2) "empty residual groups dropped";
  verify (create frontier [ empty ]) [ empty ] source corrections nodes pairs;
  verify (create frontier []) [] source corrections nodes pairs;
  require (Option.is_none (check_creation frontier [ { empty with roots = [ 9 ] } ] source corrections nodes pairs)) "invalid empty group silently skipped";
  let empty_source = T.admitted (T.memory []) [] in
  verify (create empty_source []) [] [] [] [] [];
  let explicit_zero : M.group = { roots = []; assertions = [ 0, Z.zero ] } in
  verify (create empty_source [ explicit_zero ]) [ explicit_zero ] [] [] [] [];
  Stdlib.Printf.printf "empty evidence stays unknown; explicit zero remains supported; roots still checked\n";
  [%expect {| empty evidence stays unknown; explicit zero remains supported; roots still checked |}]
;;

let%expect_test "all groups bind to one source; explicit reuse on prefix or omitted source rechecks roots" =
  let source, corrections, nodes, pairs = fixture [ 1; 0; -1 ] in
  let groups : M.group list = [ { roots = [ 0 ]; assertions = [ 0, Z.one ] }; { roots = [ 2 ]; assertions = [ 1, Z.zero ] } ] in
  let image = create (T.admitted (T.memory source) corrections) groups in
  let prefixed = T.admitted (T.memory (T.event "-1" :: source)) (T.edge "-1" "0" :: corrections) in
  (match H.create ~frontier:prefixed ~groups:(List.map groups ~f:group) with
   | Error (H.Invalid_cut { group_position = 1; error = Cut.Not_root { id; position = 1 } }) -> require (D.Identifier.Event.equal id (identifier 0)) "old root became intermediate"
   | _ -> failwith "prefix reuse did not recheck roots");
  let omitted = T.admitted (T.memory [ List.nth_exn source 2 ]) [] in
  (match H.create ~frontier:omitted ~groups:(List.map groups ~f:group) with
   | Error (H.Invalid_cut { group_position = 1; error = Cut.Unknown_event { id; position = 1 } }) -> require (D.Identifier.Event.equal id (identifier 0)) "omitted root"
   | _ -> failwith "omitted reuse did not recheck roots");
  verify image groups source corrections nodes pairs;
  Stdlib.Printf.printf "prefix/omission refuse rebinding; old source-bound image unchanged\n";
  [%expect {| prefix/omission refuse rebinding; old source-bound image unchanged |}]
;;

let%expect_test "256 ownership/cut admissions and 2304 re-observations match independent model and exact quantities" =
  let source, corrections, nodes, pairs = fixture [ 1; 0; -7 ] in
  let frontier = T.admitted (T.memory source) corrections in
  let cases, admitted, updates = List.fold (List.init 4 ~f:Fn.id) ~init:(0, 0, 0) ~f:(fun counts first ->
    List.fold (List.init 4 ~f:Fn.id) ~init:counts ~f:(fun counts second ->
      List.fold (List.init 16 ~f:Fn.id) ~init:counts ~f:(fun (cases, admitted, updates) ownership ->
        let groups = M.old_groups first second ownership in
        match check_creation frontier groups source corrections nodes pairs with
        | None -> cases + 1, admitted, updates
        | Some image ->
          let count = List.fold (List.init 4 ~f:Fn.id) ~init:0 ~f:(fun count roots ->
            List.fold (List.init 4 ~f:Fn.id) ~init:count ~f:(fun count coordinates ->
              require (Option.is_some (check_update image groups (M.incoming roots coordinates) source corrections nodes pairs)) "valid finite update";
              count + 1)) in
          cases + 1, admitted + 1, updates + count))) in
  require (Int.equal cases 256 && Int.equal admitted 144 && Int.equal updates 2_304) "actual bounded seam counts";
  Stdlib.Printf.printf "%d admissions (%d accepted); %d update/replay seams with original-Effect Zarith\n" cases admitted updates;
  [%expect {| 256 admissions (144 accepted); 2304 update/replay seams with original-Effect Zarith |}]
;;

module Inputs = struct
  type t = int list * ((int list * (int * int) list) list * (int list * (int * int) list))
  let sexp_of_t input =
    let values, (groups, incoming) = input in
    let group (roots, assertions) = Sexp.List [ T.Path_inputs.sexp_of_t roots;
      Sexp.List (List.map assertions ~f:(fun (c, q) -> Sexp.List [ Int.sexp_of_t c; Int.sexp_of_t q ])) ] in
    Sexp.List [ T.Path_inputs.sexp_of_t values; Sexp.List (List.map groups ~f:group); group incoming ]
  let quickcheck_generator =
    let open Base_quickcheck.Generator in
    let sized max generator = bind (int_inclusive 0 max) ~f:(fun length -> list_with_length generator ~length) in
    let group = both (sized 4 (int_inclusive (-1) 9)) (sized 6 (both (int_inclusive 0 3) (int_inclusive (-8) 8))) in
    both (sized 8 (int_inclusive (-4) 4)) (both (sized 4 group) group)
  let quickcheck_shrinker =
    let open Base_quickcheck.Shrinker in
    let group = both (list int) (list (both int int)) in
    both (list int) (both (list group) group)
end

let%expect_test "generated raw ownership diagnostics and explicit replacement obey independent list and quantity oracles" =
  let to_model (roots, assertions) : M.group =
    { roots; assertions = List.map assertions ~f:(fun (c, q) -> c, Z.mul (Z.of_int q) (Z.shift_left Z.one 140)) } in
  let check (values, (drafts, incoming_draft)) =
    let source, corrections, nodes, pairs = fixture values in
    let frontier = T.admitted (T.memory source) corrections in
    let raw_groups = List.map drafts ~f:to_model in
    (match check_creation frontier raw_groups source corrections nodes pairs with
     | None -> ()
     | Some image -> ignore (check_update image raw_groups (to_model incoming_draft) source corrections nodes pairs : H.t option));
    (* Separately construct globally unique specimens from coordinate ownership,
       rather than silently normalize malformed input in the product. *)
    let roots = List.map pairs ~f:fst in
    let group_count = Int.max 1 (List.length drafts) in
    let valid_groups = List.init group_count ~f:(fun position ->
      let flags, assertions = Option.value (List.nth drafts position) ~default:([], []) in
      let selected_roots = List.filter roots ~f:(fun root -> List.mem flags root ~equal:Int.equal) in
      let assigned = List.filter [ 0; 1; 2; 3 ] ~f:(fun c ->
        List.exists assertions ~f:(fun (d, _) -> Int.equal c d) && Int.equal ((c + List.length values) % group_count) position) in
      let assertions = List.map assigned ~f:(fun c ->
        let q = snd (List.find_exn assertions ~f:(fun (d, _) -> Int.equal c d)) in
        c, Z.mul (Z.of_int q) (Z.shift_left Z.one 140)) in
      ({ roots = selected_roots; assertions } : M.group)) in
    let image = create frontier valid_groups in
    verify image valid_groups source corrections nodes pairs;
    ignore (check_update image valid_groups (to_model incoming_draft) source corrections nodes pairs : H.t option);
    let incoming_flags, incoming_assertions = incoming_draft in
    let incoming : M.group =
      { roots = List.filter roots ~f:(fun r -> List.mem incoming_flags r ~equal:Int.equal)
      ; assertions = List.filter_map [ 3; 2; 1; 0 ] ~f:(fun c ->
          Option.map (List.find incoming_assertions ~f:(fun (d, _) -> Int.equal c d))
            ~f:(fun (_, q) -> c, Z.mul (Z.of_int q) (Z.shift_left Z.one 150))) } in
    let updated = Option.value_exn (check_update image valid_groups incoming source corrections nodes pairs) in
    let permuted_groups = List.rev_map valid_groups ~f:(fun (g : M.group) ->
      ({ roots = List.rev g.roots; assertions = List.rev g.assertions } : M.group)) in
    let permuted_frontier = T.admitted (T.memory (List.rev_map source ~f:(fun e ->
      D.Event.create ~id:(D.Event.id e) ~effects:(List.rev (D.Event.effects e))))) (List.rev corrections) in
    let permuted = create permuted_frontier permuted_groups in
    let replay = create frontier valid_groups in
    List.iter [ 0; 1; 2; 3; 4 ] ~f:(fun c ->
      match H.query image (coordinate c), H.query permuted (coordinate c), H.query replay (coordinate c) with
      | Ok a, Ok b, Ok r -> require (Q.equal (P.quantity a) (P.quantity b) && Q.equal (P.quantity a) (P.quantity r)) "image permutation/replay"
      | Error _, Error _, Error _ -> ()
      | _ -> failwith "permutation/replay support mismatch");
    List.iter incoming.assertions ~f:(fun (c, _) ->
      let owner = Option.value_exn (H.group_for updated (coordinate c)) in
      require (List.equal D.Identifier.Event.equal (Cut.reflected_roots (P.source_cut owner)) (List.map incoming.roots ~f:identifier)) "incoming whole cut wins")
  in
  let config = { Base_quickcheck.Test.default_config with seed = Deterministic "loam-current-groups-v1"; test_count = 10_000; shrink_count = 10_000 } in
  let checks = ref 0 in
  Base_quickcheck.Test.run_exn (module Inputs) ~config ~f:(fun input -> check input; Int.incr checks);
  require (Int.equal !checks config.test_count) "generated cases actually executed";
  Stdlib.Printf.printf "multi-group original-list/Effect oracle passed (%d generated cases)\n" !checks;
  [%expect {| multi-group original-list/Effect oracle passed (10000 generated cases) |}]
;;
