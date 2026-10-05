open Base
module Q = Bakhlo_domain.Quantity

let quantity text = Q.of_quanta (Z.of_string text)
let print_quantity value = Stdlib.print_endline (Z.to_string (Q.quanta value))

let%expect_test "exact quanta beyond fixed-width integer ranges" =
  let large = quantity "18446744073709551616" in
  let one = quantity "1" in
  print_quantity (Q.add large one);
  print_quantity (Q.sub large one);
  print_quantity (Q.neg large);
  print_quantity (Q.sum [ large; one; Q.neg large ]);
  [%expect {|
    18446744073709551617
    18446744073709551615
    -18446744073709551616
    1 |}]

let%expect_test "ordering, identity, and empty mathematical sum" =
  let negative = quantity "-18446744073709551616" in
  let positive = Q.neg negative in
  let print_bool value = Stdlib.print_endline (Bool.to_string value) in
  print_bool Int.(Q.compare negative Q.zero < 0);
  print_bool Int.(Q.compare Q.zero positive < 0);
  print_bool (Int.equal (Q.compare positive positive) 0);
  print_bool (Q.equal (Q.add positive Q.zero) positive);
  print_quantity (Q.sum []);
  [%expect {|
    true
    true
    true
    true
    0 |}]

module Integer_lists = struct
  type t = int list

  let sexp_of_t values = Sexp.List (List.map values ~f:Int.sexp_of_t)
  let quickcheck_generator = Base_quickcheck.Generator.list Base_quickcheck.Generator.int
  let quickcheck_shrinker = Base_quickcheck.Shrinker.list Base_quickcheck.Shrinker.int
end

let require condition message = if not condition then failwith message

let%expect_test "generated exact additive laws" =
  (* Include machine-sized values and values far beyond that range, without
     computing the scaled values in machine arithmetic. Shrink the source ints. *)
  let scale = Z.shift_left Z.one 128 in
  let check source =
    let values =
      List.concat_map source ~f:(fun n ->
          let z = Z.of_int n in
          [ Q.of_quanta z; Q.of_quanta (Z.mul z scale) ])
    in
    List.iter values ~f:(fun value ->
        require (Q.equal (Q.of_quanta (Q.quanta value)) value) "round trip";
        require (Q.equal (Q.add value Q.zero) value) "additive identity";
        require (Q.equal (Q.neg (Q.neg value)) value) "double negation";
        require (Q.equal (Q.add value (Q.neg value)) Q.zero) "additive inverse";
        require (Q.equal (Q.sub value value) Q.zero) "self subtraction");
    let total = Q.sum values in
    require (Q.equal (Q.sum (List.map values ~f:Q.neg)) (Q.neg total)) "sum negation";
    require (Q.equal (Q.sum (List.rev values)) total) "sum order";
    match values with
    | a :: b :: c :: _ ->
        require (Q.equal (Q.add a b) (Q.add b a)) "commutativity";
        require (Q.equal (Q.add (Q.add a b) c) (Q.add a (Q.add b c))) "associativity";
        require (Q.equal (Q.sub a b) (Q.add a (Q.neg b))) "subtraction"
    | _ -> ()
  in
  let config =
    {
      Base_quickcheck.Test.default_config with
      seed = Deterministic "loam-quantity-v1";
      test_count = 10_000;
      shrink_count = 10_000;
    }
  in
  let checks = ref 0 in
  Base_quickcheck.Test.run_exn
    (module Integer_lists)
    ~config
    ~f:(fun source ->
      check source;
      Int.incr checks);
  require (Int.equal !checks config.test_count) "generated checks actually ran";
  Stdlib.Printf.printf "additive laws passed (%d generated cases)\n" !checks;
  [%expect {| additive laws passed (10000 generated cases) |}]
