open Base

module I = Loam_domain.Identifier
module E = Loam_domain.Effect
module M = Loam_domain.Movement
module Q = Loam_domain.Quantity

let measure text =
  match I.Measure.of_string text with
  | Ok value -> value
  | Error Empty -> failwith "empty fixture Measure"
;;

let locus text =
  match I.Locus.of_string text with
  | Ok value -> value
  | Error Empty -> failwith "empty fixture Locus"
;;

let change ?(unit = "jpy") place quantity =
  E.create ~key:None ~locus:(locus place) ~measure:(measure unit) ~quantity:(Q.of_quanta quantity)
;;

let describe_error = function
  | M.Empty -> "empty"
  | M.Zero_quantity { position } -> Stdlib.Printf.sprintf "zero(%d)" position
  | M.Measure_mismatch { position; expected; actual } ->
    Stdlib.Printf.sprintf
      "mixed(%d,%S,%S)"
      position
      (I.Measure.to_string expected)
      (I.Measure.to_string actual)
  | M.Unbalanced { measure; residual } ->
    Stdlib.Printf.sprintf
      "residual(%S,%s)"
      (I.Measure.to_string measure)
      (Z.to_string (Q.quanta residual))
;;

let print_validation effects =
  match M.validate effects with
  | Error errors -> Stdlib.print_endline (String.concat ~sep:"; " (List.map errors ~f:describe_error))
  | Ok movement ->
    Stdlib.Printf.printf
      "validated %S: %d Effects, positive=%s\n"
      (I.Measure.to_string (M.measure movement))
      (List.length (M.effects movement))
      (Z.to_string (Q.quanta (M.positive_total movement)))
;;

let%expect_test "identities preserve exact spelling without catalog inference" =
  (match I.Measure.of_string "" with
   | Error Empty -> Stdlib.print_endline "empty refused"
   | Ok _ -> failwith "empty admitted");
  (match I.Locus.of_string "" with
   | Error Empty -> Stdlib.print_endline "empty refused"
   | Ok _ -> failwith "empty admitted");
  Stdlib.print_endline (Bool.to_string (I.Measure.equal (measure "JPY") (measure "jpy")));
  Stdlib.Printf.printf "%S\n" (I.Locus.to_string (locus " wallet "));
  [%expect {|
    empty refused
    empty refused
    false
    " wallet " |}]
;;

let%expect_test "refusal precedes numeric aggregation across Measures" =
  print_validation [];
  print_validation [ change "wallet" Z.zero ];
  print_validation [ change "wallet" (Z.of_int (-5)); change ~unit:"usd" "food" (Z.of_int 5) ];
  print_validation [ change "wallet" Z.zero; change ~unit:"usd" "food" Z.zero ];
  print_validation [ change "wallet" (Z.of_int (-5)); change "food" (Z.of_int 4) ];
  [%expect {|
    empty
    zero(1)
    mixed(2,"jpy","usd")
    zero(1); zero(2); mixed(2,"jpy","usd")
    residual("jpy",-1) |}]
;;

let%expect_test "split, duplicate, same-Locus, and huge changes remain represented" =
  print_validation
    [ change "wallet" (Z.of_int (-1000))
    ; change "food" (Z.of_int 500)
    ; change "food" (Z.of_int 500)
    ];
  print_validation [ change "wallet" (Z.of_int (-7)); change "wallet" (Z.of_int 7) ];
  let huge = Z.of_string "18446744073709551616" in
  print_validation [ change "wallet" (Z.neg huge); change "food" huge ];
  [%expect {|
    validated "jpy": 3 Effects, positive=1000
    validated "jpy": 2 Effects, positive=7
    validated "jpy": 2 Effects, positive=18446744073709551616 |}]
;;

module Integer_lists = struct
  type t = int list

  let sexp_of_t values = Sexp.List (List.map values ~f:Int.sexp_of_t)
  let quickcheck_generator = Base_quickcheck.Generator.list Base_quickcheck.Generator.int
  let quickcheck_shrinker = Base_quickcheck.Shrinker.list Base_quickcheck.Shrinker.int
end

let require condition message = if not condition then failwith message

let same_change left right =
  I.Locus.equal (E.locus left) (E.locus right)
  && I.Measure.equal (E.measure left) (E.measure right)
  && Q.equal (E.quantity left) (E.quantity right)
;;

let accepted effects =
  match M.validate effects with
  | Ok movement -> movement
  | Error _ -> failwith "expected balanced nonzero movement"
;;

let%expect_test "generated oracle, conservation, perturbation, and representation laws" =
  let scale = Z.shift_left Z.one 128 in
  let check source =
    let quanta = List.map source ~f:(fun n -> Z.mul (Z.of_int n) scale) in
    let effects = List.map quanta ~f:(change "wallet") in
    let expected =
      not (List.is_empty quanta)
      && List.for_all quanta ~f:(fun z -> not (Z.equal z Z.zero))
      && Z.equal (List.fold quanta ~init:Z.zero ~f:Z.add) Z.zero
    in
    require (Bool.equal (Result.is_ok (M.validate effects)) expected) "reference oracle";
    let nonzero = List.filter quanta ~f:(fun z -> not (Z.equal z Z.zero)) in
    match nonzero with
    | [] -> ()
    | _ :: _ ->
      let paired =
        List.concat_map nonzero ~f:(fun z -> [ change "wallet" z; change "food" (Z.neg z) ])
      in
      let movement = accepted paired in
      require (List.equal same_change (M.effects movement) paired) "order and multiplicity";
      require (I.Measure.equal (M.measure movement) (measure "jpy")) "Measure preservation";
      let oracle_positive =
        List.fold paired ~init:Z.zero ~f:(fun total item ->
          let z = Q.quanta (E.quantity item) in
          if Z.sign z > 0 then Z.add total z else total)
      in
      require (Z.equal (Q.quanta (M.positive_total movement)) oracle_positive) "positive total";
      require (Z.sign oracle_positive > 0) "positive side exists";
      ignore (accepted (List.rev paired) : M.t);
      let negated =
        List.map paired ~f:(fun item ->
          E.create ~key:(E.key item) ~locus:(E.locus item) ~measure:(E.measure item) ~quantity:(Q.neg (E.quantity item)))
      in
      ignore (accepted negated : M.t);
      (match M.validate (paired @ [ change "food" Z.one ]) with
       | Error [ Unbalanced { residual; _ } ] -> require (Z.equal (Q.quanta residual) Z.one) "exact residual"
       | _ -> failwith "perturbation accepted or wrong refusal");
      (match M.validate (paired @ [ change ~unit:"usd" "food" Z.one ]) with
       | Error [ Measure_mismatch _ ] -> ()
       | _ -> failwith "mixed Measures were aggregated");
      (match M.validate (paired @ [ change "food" Z.zero ]) with
       | Error [ Zero_quantity _ ] -> ()
       | _ -> failwith "zero change accepted")
  in
  let config =
    { Base_quickcheck.Test.default_config with
      seed = Deterministic "loam-movement-v1"
    ; test_count = 10_000
    ; shrink_count = 10_000
    }
  in
  let checks = ref 0 in
  Base_quickcheck.Test.run_exn (module Integer_lists) ~config ~f:(fun source ->
    check source;
    Int.incr checks);
  require (Int.equal !checks config.test_count) "generated checks actually ran";
  Stdlib.Printf.printf "movement laws passed (%d generated cases)\n" !checks;
  [%expect {| movement laws passed (10000 generated cases) |}]
;;
