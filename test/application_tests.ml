open Base

module A = Bakhlo_application.Movement_check
module D = Bakhlo_domain
module Text = Bakhlo_presentation.Movement_text

let identifier constructor value =
  match constructor value with
  | Ok identity -> identity
  | Error D.Identifier.Empty -> failwith "empty fixture identity"
;;

let change ?(unit = "jpy") place quanta =
  D.Effect.create ~key:None
    ~locus:(identifier D.Identifier.Locus.of_string place)
    ~measure:(identifier D.Identifier.Measure.of_string unit)
    ~quantity:(D.Quantity.of_quanta quanta)
;;

let require condition message = if not condition then failwith message

let answer effects =
  match A.run { effects } with
  | Ok preview -> preview
  | Error _ -> failwith "invalid fixture Movement"
;;

let equal_change left right =
  D.Identifier.Locus.equal (D.Effect.locus left) (D.Effect.locus right)
  && D.Identifier.Measure.equal (D.Effect.measure left) (D.Effect.measure right)
  && D.Quantity.equal (D.Effect.quantity left) (D.Effect.quantity right)
;;

let equal_preview left right =
  D.Identifier.Measure.equal (A.measure left) (A.measure right)
  && List.equal equal_change (A.effects left) (A.effects right)
  && D.Quantity.equal (A.positive_total left) (A.positive_total right)
;;

let equal_error left right =
  match left, right with
  | D.Movement.Empty, D.Movement.Empty -> true
  | Zero_quantity { position = left }, Zero_quantity { position = right } ->
    Int.equal left right
  | ( Measure_mismatch { position = lp; expected = le; actual = la }
    , Measure_mismatch { position = rp; expected = re; actual = ra } ) ->
    Int.equal lp rp
    && D.Identifier.Measure.equal le re
    && D.Identifier.Measure.equal la ra
  | Unbalanced { measure = lm; residual = lr }, Unbalanced { measure = rm; residual = rr } ->
    D.Identifier.Measure.equal lm rm && D.Quantity.equal lr rr
  (* Enumerate the left-hand constructors: a new error must update this oracle,
     not silently fall through an unrestricted catch-all. *)
  | (Empty | Zero_quantity _ | Measure_mismatch _ | Unbalanced _), _ -> false
;;

let%expect_test "application command exposes exact structured values without argv or layout" =
  let huge = Z.of_string "18446744073709551616" in
  let effects =
    [ change "wallet" (Z.neg huge)
    ; change "food" (Z.pred huge)
    ; change "food" Z.one
    ]
  in
  let preview = answer effects in
  require (List.equal equal_change effects (A.effects preview)) "input representation";
  Stdlib.Printf.printf
    "Measure=%S, Effects=%d, positive_quanta=%s\n"
    (D.Identifier.Measure.to_string (A.measure preview))
    (List.length (A.effects preview))
    (Z.to_string (D.Quantity.quanta (A.positive_total preview)));
  [%expect {| Measure="jpy", Effects=3, positive_quanta=18446744073709551616 |}]
;;

let%expect_test "application refusals retain all existing typed distinctions and fields" =
  let check effects predicate =
    match A.run { effects } with
    | Error errors -> require (predicate errors) "unexpected structured refusal"
    | Ok _ -> failwith "invalid fixture accepted"
  in
  check [] (function [ D.Movement.Empty ] -> true | _ -> false);
  check [ change "wallet" Z.zero ] (function
    | [ D.Movement.Zero_quantity { position = 1 } ] -> true
    | _ -> false);
  check [ change "wallet" (Z.of_int (-2)); change ~unit:"usd" "food" Z.zero ] (function
    | [ D.Movement.Zero_quantity { position = 2 }
      ; Measure_mismatch { position = 2; expected; actual }
      ] ->
      String.equal (D.Identifier.Measure.to_string expected) "jpy"
      && String.equal (D.Identifier.Measure.to_string actual) "usd"
    | _ -> false);
  check [ change "wallet" (Z.of_int (-2)); change "food" Z.one ] (function
    | [ D.Movement.Unbalanced { measure; residual } ] ->
      String.equal (D.Identifier.Measure.to_string measure) "jpy"
      && D.Quantity.equal residual (D.Quantity.of_quanta Z.minus_one)
    | _ -> false);
  Stdlib.Printf.printf "typed empty, zero, mixed-Measure, and residual refusals matched\n";
  [%expect {| typed empty, zero, mixed-Measure, and residual refusals matched |}]
;;

let%expect_test "repeated projection and client ordering do not alter the semantic answer" =
  let preview =
    answer [ change "wallet" (Z.of_int (-10)); change "food" (Z.of_int 10) ]
  in
  let total_before = A.positive_total preview in
  let representation_before = A.effects preview in
  let first = Text.preview preview in
  let second = Text.preview preview in
  let client_order = List.rev (A.effects preview) in
  require (String.equal first second) "deterministic text projection";
  require (List.equal equal_change representation_before (A.effects preview)) "immutable answer";
  require (D.Quantity.equal total_before (A.positive_total preview)) "stable aggregate";
  Stdlib.Printf.printf
    "client_first=%S; answer_first=%S; positive_quanta=%s\n"
    (D.Identifier.Locus.to_string (D.Effect.locus (List.hd_exn client_order)))
    (D.Identifier.Locus.to_string (D.Effect.locus (List.hd_exn (A.effects preview))))
    (Z.to_string (D.Quantity.quanta (A.positive_total preview)));
  [%expect {| client_first="food"; answer_first="wallet"; positive_quanta=10 |}]
;;

module Integer_lists = struct
  type t = int list

  let sexp_of_t values = Sexp.List (List.map values ~f:Int.sexp_of_t)
  let quickcheck_generator = Base_quickcheck.Generator.list Base_quickcheck.Generator.int
  let quickcheck_shrinker = Base_quickcheck.Shrinker.list Base_quickcheck.Shrinker.int
end

let%expect_test "generated application replay preserves domain answers and refusals" =
  let scale = Z.shift_left Z.one 128 in
  let check_effects effects =
    let command : A.command = { effects } in
    let first = A.run command in
    let second = A.run command in
    require
      (Result.equal equal_preview (List.equal equal_error) first second)
      "deterministic command replay";
    require (List.equal equal_change effects command.effects) "command unchanged";
    match D.Movement.validate effects, first with
    | Error expected, Error actual ->
      require (List.equal equal_error expected actual) "refusal semantics/order";
      require (not (List.is_empty actual)) "nonempty refusal"
    | Ok movement, Ok preview ->
      require
        (D.Identifier.Measure.equal (D.Movement.measure movement) (A.measure preview))
        "Measure preservation";
      require (List.equal equal_change effects (A.effects preview)) "representation preservation";
      require
        (D.Quantity.equal (D.Movement.positive_total movement) (A.positive_total preview))
        "aggregate preservation"
    | _ -> failwith "application changed validation outcome"
  in
  let check source =
    let quanta = List.map source ~f:(fun n -> Z.mul (Z.of_int n) scale) in
    check_effects (List.map quanta ~f:(change "wallet"));
    let paired =
      List.concat_map quanta ~f:(fun z -> [ change "wallet" z; change "food" (Z.neg z) ])
    in
    check_effects paired;
    check_effects (paired @ [ change ~unit:"usd" "food" Z.one ])
  in
  let config =
    { Base_quickcheck.Test.default_config with
      seed = Deterministic "loam-application-v1"
    ; test_count = 10_000
    ; shrink_count = 10_000
    }
  in
  let checks = ref 0 in
  Base_quickcheck.Test.run_exn (module Integer_lists) ~config ~f:(fun source ->
    check source;
    Int.incr checks);
  require (Int.equal !checks config.test_count) "generated cases actually ran";
  Stdlib.Printf.printf "application replay passed (%d generated cases)\n" !checks;
  [%expect {| application replay passed (10000 generated cases) |}]
;;
