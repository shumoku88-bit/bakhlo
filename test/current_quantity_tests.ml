open Base
module D = Loam_domain
module Q = D.Quantity
module Coordinate = D.Effect_coordinate
module P = Loam_application.Current_quantity_projection
module F = Loam_application.Correction_frontier
module Cut = Loam_application.Reflected_root_cut
module T = Fixtures
module ZT = Fixtures
module G = Lineage_model
module M = Root_cut_model

let require = T.require
let coordinate = ZT.coordinate
let change = ZT.change
let id = T.id
let event = T.event
let edge = T.edge
let memory = T.memory
let frontier = T.admitted
let cut = T.cut
let same_coordinate = ZT.same_coordinate

let assertion = T.assertion
let model source assertions =
  match P.create ~cut:source ~assertions with
  | Ok value -> value
  | Error (Duplicate_coordinate _) -> failwith "duplicate fixture assertion"
;;

let exact model coordinate =
  match P.query model coordinate with
  | Ok answer ->
    require (same_coordinate (P.coordinate answer) coordinate) "exact answer coordinate";
    require (Q.equal (P.quantity answer) (Q.add (P.asserted_quantity answer) (P.delta answer))) "exact decomposition";
    answer
  | Error (Assertion_unknown _) -> failwith "asserted fixture unsupported"
;;

let unknown model coordinate =
  match P.query model coordinate with
  | Error (Assertion_unknown { coordinate = actual }) -> require (same_coordinate coordinate actual) "typed unknown coordinate"
  | Ok _ -> failwith "unsupported became exact"
;;

let show label model coordinate =
  let answer = exact model coordinate in
  Stdlib.Printf.printf "%s: asserted=%s; delta=%s; quantity=%s\n" label
    (Z.to_string (Q.quanta (P.asserted_quantity answer)))
    (Z.to_string (Q.quanta (P.delta answer))) (Z.to_string (Q.quanta (P.quantity answer)))
;;

let same_assertion = T.same_assertion

let require_source source assertions answer =
  require (List.equal same_assertion assertions (P.assertions answer)) "unmodified assertion order/values";
  let retained = P.source_cut answer in
  T.require_cut_source (Cut.source_frontier source) retained (Cut.reflected_roots source);
  require (List.equal T.equal_lineage (Cut.remaining_lineages source) (Cut.remaining_lineages retained)) "same immutable cut"
;;

let sum_events = Source_oracle.sum_events

let selected_events source corrections reflected =
  List.filter_map (Source_oracle.expected_pairs source corrections) ~f:(fun (root, terminal) ->
    if List.mem reflected root ~equal:D.Identifier.Event.equal then None else Some terminal)
;;

let verify_queries answer assertions expected_events queries =
  List.iter queries ~f:(fun coordinate ->
    match List.find assertions ~f:(fun (a : P.assertion) -> same_coordinate a.coordinate coordinate) with
    | None -> unknown answer coordinate
    | Some assertion ->
      let actual = exact answer coordinate in
      let delta = sum_events expected_events coordinate in
      require (Z.equal (Q.quanta (P.asserted_quantity actual)) (Q.quanta assertion.quantity)) "retained assertion";
      require (Z.equal (Q.quanta (P.delta actual)) delta) "direct original-Effect delta oracle";
      require (Z.equal (Q.quanta (P.quantity actual)) (Z.add (Q.quanta assertion.quantity) delta)) "direct exact result oracle")
;;

let%expect_test "assertion gate keeps empty, active, net-zero and all-reflected inputs unsupported" =
  let wallet = coordinate "wallet" in
  let empty = cut (frontier (memory []) []) [] in
  unknown (model empty []) wallet;
  let active = T.observation ~id:(id "active") ~effects:[ change wallet Z.one ] in
  let net_zero = T.observation ~id:(id "net-zero") ~effects:[ change wallet Z.one; change wallet Z.minus_one ] in
  List.iter [ active; net_zero ] ~f:(fun observation ->
    let f = frontier (memory [ observation ]) [] in
    unknown (model (cut f []) []) wallet;
    unknown (model (cut f [ D.Event.id observation ]) []) wallet);
  let all = cut (frontier (memory [ active ]) []) [ id "active" ] in
  show "explicit-zero" (model all [ assertion wallet Z.zero ]) wallet;
  Stdlib.Printf.printf "activity and empty delta never infer assertion or zero origin\n";
  [%expect {|
    explicit-zero: asserted=0; delta=0; quantity=0
    activity and empty delta never infer assertion or zero origin |}]
;;

let%expect_test "empty supplied delta preserves signed and huge independent assertions" =
  let source = cut (frontier (memory []) []) [] in
  let wallet = coordinate "wallet" in
  let usd = coordinate ~unit:"usd" "wallet" in
  let huge = Z.shift_left Z.one 150 in
  let assertions = [ assertion wallet (Z.of_int (-12)); assertion usd huge ] in
  let answer = model source assertions in
  require_source source assertions answer;
  show "signed" answer wallet;
  require (Z.equal (Q.quanta (P.quantity (exact answer usd))) huge) "huge assertion unchanged";
  unknown answer (coordinate "unasserted");
  [%expect {| signed: asserted=-12; delta=0; quantity=-12 |}]
;;

let%expect_test "general terminal Effects preserve multiplicity, coordinate locality and exact decomposition" =
  let wallet = coordinate "wallet" in
  let usd = coordinate ~unit:"usd" "wallet" in
  let other = coordinate "other" in
  let huge = Z.shift_left Z.one 128 in
  let old = T.observation ~id:(id "a") ~effects:[ change wallet (Z.of_int 999) ] in
  let terminal = T.observation ~id:(id "b") ~effects:
    [ change wallet huge; change wallet Z.one; change wallet Z.one; change usd (Z.of_int (-7)); change other Z.zero ] in
  let source = [ old; terminal; event "empty" ] in
  let corrections = [ edge "a" "b" ] in
  let supplied = cut (frontier (memory source) corrections) [] in
  let assertions = [ assertion wallet (Z.neg huge); assertion usd Z.one; assertion other Z.zero ] in
  let answer = model supplied assertions in
  require (Result.is_error (D.Movement.validate (D.Event.effects terminal))) "general Event not Movement narrowed";
  verify_queries answer assertions (selected_events source corrections []) [ wallet; usd; other; coordinate "missing" ];
  require_source supplied assertions answer;
  show "usd" answer usd;
  show "other" answer other;
  require (Z.equal (Q.quanta (P.quantity (exact answer wallet))) (Z.of_int 2)) "huge cancellation exact";
  [%expect {|
    usd: asserted=1; delta=-7; quantity=-6
    other: asserted=0; delta=0; quantity=0 |}]
;;

let%expect_test "first repeated coordinate refuses even identical exact assertions" =
  let source = cut (frontier (memory []) []) [] in
  let wallet = coordinate "wallet" in
  List.iter [ Z.one; Z.of_int 99 ] ~f:(fun repeated_quantity ->
    match P.create ~cut:source ~assertions:
      [ assertion wallet Z.one; assertion (coordinate ~unit:"usd" "wallet") Z.zero
      ; assertion wallet repeated_quantity; assertion wallet Z.one ] with
    | Ok _ -> failwith "duplicate assertion silently normalized"
    | Error (Duplicate_coordinate { coordinate; first_position; position }) ->
      require (same_coordinate coordinate wallet) "exact repeated coordinate";
      Stdlib.Printf.printf "duplicate first=%d; repeat=%d\n" first_position position);
  [%expect {|
    duplicate first=1; repeat=3
    duplicate first=1; repeat=3 |}]
;;

let%expect_test "shared cut supports exact coordinate tokens without aliases or composite-key collision" =
  let coordinates =
    [ coordinate ~unit:"c" "a/b"; coordinate ~unit:"b/c" "a"
    ; coordinate "wallet"; coordinate ~unit:"JPY" "wallet"
    ; coordinate " wallet "; coordinate "wallet\000" ] in
  let assertions = List.mapi coordinates ~f:(fun i c -> assertion c (Z.of_int i)) in
  let source = cut (frontier (memory [ event "neutral" ]) []) [] in
  let answer = model source assertions in
  List.iteri coordinates ~f:(fun i c -> require (Z.equal (Q.quanta (P.quantity (exact answer c))) (Z.of_int i)) "exact support identity");
  unknown answer (coordinate ~unit:"jpy " "wallet");
  require_source source assertions answer;
  Stdlib.Printf.printf "six exact asserted coordinates share one retained cut\n";
  [%expect {| six exact asserted coordinates share one retained cut |}]
;;

let%expect_test "reflected reclassification cannot leak while unreflected terminal update changes delta" =
  let wallet = coordinate "wallet" in
  let usd = coordinate ~unit:"usd" "wallet" in
  let observed name effects = T.observation ~id:(id name) ~effects in
  let old_source = [ observed "a" [ change wallet (Z.of_int 100) ]; observed "b" [ change wallet (Z.of_int 150) ]
    ; observed "x" [ change wallet (Z.of_int (-10)) ] ] in
  let old_cut = cut (frontier (memory old_source) [ edge "a" "b" ]) [ id "a" ] in
  let assertions = [ assertion wallet (Z.of_int 1000); assertion usd Z.zero ] in
  let old = model old_cut assertions in
  let reflected_source = old_source @ [ observed "c" [ change usd (Z.shift_left Z.one 160) ] ] in
  let reflected_cut = cut (frontier (memory reflected_source) [ edge "b" "c"; edge "a" "b" ]) [ id "a" ] in
  let reflected = model reflected_cut assertions in
  let unreflected_source = reflected_source @ [ observed "y" [ change wallet (Z.of_int (-20)); change usd (Z.of_int 3) ] ] in
  let unreflected_cut = cut (frontier (memory unreflected_source) [ edge "x" "y"; edge "a" "b"; edge "b" "c" ]) [ id "a" ] in
  let unreflected = model unreflected_cut assertions in
  require (Q.equal (P.quantity (exact old wallet)) (P.quantity (exact reflected wallet))) "reflected root stability";
  require (Z.equal (Q.quanta (P.quantity (exact reflected usd))) Z.zero) "reflected reclassification excluded";
  show "old" old wallet;
  show "reflected-tail" reflected wallet;
  show "unreflected-tail" unreflected wallet;
  show "unreflected-usd" unreflected usd;
  require_source old_cut assertions old;
  [%expect {|
    old: asserted=1000; delta=-10; quantity=990
    reflected-tail: asserted=1000; delta=-10; quantity=990
    unreflected-tail: asserted=1000; delta=-20; quantity=980
    unreflected-usd: asserted=0; delta=3; quantity=3 |}]
;;

let%expect_test "replay and representation permutation preserve quantities; assertion translation is local" =
  let wallet = coordinate "wallet" in
  let usd = coordinate ~unit:"usd" "wallet" in
  let payload = [ change wallet Z.minus_one; change wallet Z.one; change usd (Z.of_int 4) ] in
  let original = T.observation ~id:(id "one") ~effects:payload in
  let source = [ event "empty"; original ] in
  let supplied = cut (frontier (memory source) []) [] in
  let assertions = [ assertion wallet Z.zero; assertion usd (Z.of_int (-4)) ] in
  let answer = model supplied assertions in
  let reordered = model (cut (frontier (memory [ T.observation ~id:(id "one") ~effects:(List.rev payload); event "empty" ]) []) []) (List.rev assertions) in
  let translated = model supplied [ assertion wallet (Z.shift_left Z.one 140); assertion usd (Z.of_int (-4)) ] in
  List.iter [ wallet; usd ] ~f:(fun c ->
    require (Q.equal (P.quantity (exact answer c)) (P.quantity (exact reordered c))) "representation order not meaning";
    require (Q.equal (P.quantity (exact answer c)) (P.quantity (exact (model supplied assertions) c))) "replay");
  require (Q.equal (P.delta (exact answer wallet)) (P.delta (exact translated wallet))) "translation changes no delta";
  require (Q.equal (P.quantity (exact answer usd)) (P.quantity (exact translated usd))) "translation coordinate-local";
  require (Z.equal (Q.quanta (P.quantity (exact translated wallet))) (Z.shift_left Z.one 140)) "exact signed-Int translation seam";
  require_source supplied assertions answer;
  Stdlib.Printf.printf "replay/permutation and exact assertion translation passed\n";
  [%expect {| replay/permutation and exact assertion translation passed |}]
;;

let fixture_coordinate = T.fixture_coordinate

let%expect_test "4864 graph/cut/support cases agree with independent closure and original-Effect arithmetic" =
  let nodes = [ 0; 1; 2; 3 ] in
  let coordinates = List.map nodes ~f:fixture_coordinate in
  let source = List.map nodes ~f:(fun n ->
    T.observation ~id:(id (Int.to_string n)) ~effects:
      [ change (fixture_coordinate n) (Z.mul (Z.of_int (n - 2)) (Z.shift_left Z.one 128))
      ; change (fixture_coordinate 0) Z.one; change (fixture_coordinate 0) Z.one
      ; change (fixture_coordinate 3) Z.zero ]) in
  let cases =
    List.fold (List.init 65_536 ~f:Fn.id) ~init:0 ~f:(fun count mask ->
      let edges = G.edges_of_mask nodes mask in
      match G.analyze ~nodes ~edges with
      | None -> count
      | Some pairs ->
        let corrections = List.map edges ~f:(fun (a, b) -> edge (Int.to_string a) (Int.to_string b)) in
        let supplied_frontier = frontier (memory source) corrections in
        List.fold (List.init 16 ~f:Fn.id) ~init:count ~f:(fun count root_mask ->
          let reflected = M.declaration_of_mask nodes root_mask in
          match M.cut ~nodes ~pairs ~reflected with
          | Error _ -> count
          | Ok selected ->
            let supplied = cut supplied_frontier (List.map reflected ~f:(fun n -> id (Int.to_string n))) in
            let expected_events = List.map selected ~f:(fun (_, terminal) -> List.nth_exn source terminal) in
            List.fold (List.init 16 ~f:Fn.id) ~init:count ~f:(fun count assertion_mask ->
              let asserted = M.declaration_of_mask nodes assertion_mask in
              let assertions = List.map asserted ~f:(fun n -> assertion (fixture_coordinate n) (Z.of_int (n - 1))) in
              let answer = model supplied assertions in
              verify_queries answer assertions expected_events coordinates;
              require_source supplied assertions answer;
              count + 1)))
  in
  require (Int.equal cases 4_864) "actual graph/cut/support cases compared";
  Stdlib.Printf.printf "%d bounded graph/cut/support cases matched direct Zarith quantities\n" cases;
  [%expect {| 4864 bounded graph/cut/support cases matched direct Zarith quantities |}]
;;

module Inputs = struct
  type t = int list * (int list * (int * int) list)
  let sexp_of_t (values, (flags, assertions)) =
    Sexp.List [ T.Path_inputs.sexp_of_t values; T.Path_inputs.sexp_of_t flags;
      Sexp.List (List.map assertions ~f:(fun (code, q) -> Sexp.List [ Int.sexp_of_t code; Int.sexp_of_t q ])) ]
  let quickcheck_generator =
    let open Base_quickcheck.Generator in
    let values = bind (int_inclusive 0 24) ~f:(fun length -> list_with_length (int_inclusive (-9) 9) ~length) in
    let flags = bind (int_inclusive 0 12) ~f:(fun length -> list_with_length (int_inclusive (-2) 27) ~length) in
    let assertions = bind (int_inclusive 0 12) ~f:(fun length -> list_with_length (both (int_inclusive 0 3) (int_inclusive (-10) 10)) ~length) in
    both values (both flags assertions)
  let quickcheck_shrinker =
    let open Base_quickcheck.Shrinker in
    both (list int) (both (list int) (list (both int int)))
end

let%expect_test "generated assertion admission, unknown and exact quantities obey direct source-list oracles" =
  let check (values, (flags, drafts)) =
    let source = List.mapi values ~f:(fun i n ->
      let value = Z.mul (Z.of_int n) (Z.shift_left Z.one 130) in
      T.observation ~id:(id (Int.to_string i)) ~effects:
        [ change (fixture_coordinate (i % 4)) value; change (fixture_coordinate ((i + 1) % 4)) (Z.neg value)
        ; change (fixture_coordinate 0) Z.one; change (fixture_coordinate 0) Z.one; change (fixture_coordinate 3) Z.zero ]) in
    let corrections = List.filter_mapi values ~f:(fun i n ->
      if n > 0 && i + 1 < List.length source then Some (edge (Int.to_string i) (Int.to_string (i + 1))) else None) in
    let roots = List.map (Source_oracle.expected_pairs source corrections) ~f:fst in
    let reflected = List.filteri roots ~f:(fun i _ -> List.mem flags i ~equal:Int.equal) in
    let supplied = cut (frontier (memory source) corrections) (List.rev reflected) in
    let expected_events = selected_events source corrections reflected in
    let all_queries = List.map [ 0; 1; 2; 3 ] ~f:fixture_coordinate @ [ coordinate "unsupported" ] in
    let assertions = List.map drafts ~f:(fun (code, q) -> assertion (fixture_coordinate code) (Z.mul (Z.of_int q) (Z.shift_left Z.one 128))) in
    let duplicate = List.find_mapi assertions ~f:(fun i (a : P.assertion) ->
      match List.findi (List.take assertions i) ~f:(fun _ (prior : P.assertion) -> same_coordinate prior.coordinate a.coordinate) with
      | None -> None
      | Some (first, _) -> Some (a.coordinate, first + 1, i + 1)) in
    (match P.create ~cut:supplied ~assertions, duplicate with
     | Error (Duplicate_coordinate { coordinate; first_position; position }), Some (expected, first, repeated) ->
       require (same_coordinate coordinate expected && Int.equal first_position first && Int.equal position repeated) "source-list first-duplicate oracle"
     | Ok answer, None -> verify_queries answer assertions expected_events all_queries
     | Error _, None -> failwith "unique assertions refused"
     | Ok _, Some _ -> failwith "duplicate assertions admitted");
    (* A distinct, deliberately unique specimen, not production normalization. *)
    let unique_assertions = List.filteri assertions ~f:(fun i (a : P.assertion) ->
      not (List.exists (List.take assertions i) ~f:(fun (prior : P.assertion) -> same_coordinate prior.coordinate a.coordinate))) in
    let answer = model supplied unique_assertions in
    verify_queries answer unique_assertions expected_events all_queries;
    require_source supplied unique_assertions answer;
    let permuted_cut = cut (frontier (memory (List.rev source)) (List.rev corrections)) reflected in
    let permuted = model permuted_cut (List.rev unique_assertions) in
    verify_queries permuted unique_assertions expected_events all_queries;
    verify_queries (model supplied unique_assertions) unique_assertions expected_events all_queries;
    let shifted = List.map unique_assertions ~f:(fun (a : P.assertion) -> assertion a.coordinate (Z.add (Q.quanta a.quantity) (Z.shift_left Z.one 145))) in
    verify_queries (model supplied shifted) shifted expected_events all_queries;
    List.iter (Source_oracle.expected_pairs source corrections) ~f:(fun (root, terminal) ->
      let fresh = T.observation ~id:(id "fresh") ~effects:
        [ change (fixture_coordinate 0) (Z.shift_left Z.one 170); change (fixture_coordinate 2) Z.minus_one ] in
      let new_source = source @ [ fresh ] in
      let new_corrections = corrections @ [ { D.Event_correction.target = D.Event.id terminal; replacement = D.Event.id fresh } ] in
      let new_cut = cut (frontier (memory new_source) new_corrections) reflected in
      let updated = model new_cut unique_assertions in
      verify_queries updated unique_assertions (selected_events new_source new_corrections reflected) all_queries;
      if List.mem reflected root ~equal:D.Identifier.Event.equal then
        List.iter unique_assertions ~f:(fun (a : P.assertion) ->
          require (Q.equal (P.quantity (exact answer a.coordinate)) (P.quantity (exact updated a.coordinate))) "reflected-contribution noninterference law seam"));
    require_source supplied unique_assertions answer
  in
  let config =
    { Base_quickcheck.Test.default_config with
      seed = Deterministic "loam-current-quantity-v1"
    ; test_count = 10_000
    ; shrink_count = 10_000
    }
  in
  let checks = ref 0 in
  Base_quickcheck.Test.run_exn (module Inputs) ~config ~f:(fun input -> check input; Int.incr checks);
  require (Int.equal !checks config.test_count) "generated cases actually executed";
  Stdlib.Printf.printf "current quantity source-list oracle passed (%d generated cases)\n" !checks;
  [%expect {| current quantity source-list oracle passed (10000 generated cases) |}]
;;
