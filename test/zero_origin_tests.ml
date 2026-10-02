open Base

module D = Loam_domain
module C = D.Effect_coordinate
module Coverage = D.Zero_origin_coverage
module P = Loam_application.Zero_origin_projection
module Q = D.Quantity

let require condition message = if not condition then failwith message

let identifier constructor spelling =
  match constructor spelling with
  | Ok value -> value
  | Error D.Identifier.Empty -> failwith "empty fixture identifier"
;;

let coordinate ?(unit = "jpy") place : C.t =
  { locus = identifier D.Identifier.Locus.of_string place
  ; measure = identifier D.Identifier.Measure.of_string unit
  }
;;

let change (coordinate : C.t) quanta =
  D.Effect.create
    ~locus:coordinate.locus
    ~measure:coordinate.measure
    ~quantity:(Q.of_quanta quanta)
;;

let movement effects =
  match D.Movement.validate effects with
  | Ok value -> value
  | Error _ -> failwith "invalid fixture Movement"
;;

let coverage coordinates =
  match Coverage.of_coordinates coordinates with
  | Ok value -> value
  | Error (Duplicate_coordinate _) -> failwith "duplicate fixture coverage"
;;

let same_coordinate (left : C.t) (right : C.t) =
  D.Identifier.Locus.equal left.locus right.locus
  && D.Identifier.Measure.equal left.measure right.measure
;;

let exact model coordinate =
  match P.query model coordinate with
  | Ok answer ->
    require (same_coordinate (P.coordinate answer) coordinate) "answer coordinate";
    Q.quanta (P.quantity answer)
  | Error (Origin_unknown _) -> failwith "supported fixture unavailable"
;;

let unknown model coordinate =
  match P.query model coordinate with
  | Error (Origin_unknown { coordinate = actual }) ->
    require (same_coordinate actual coordinate) "unknown coordinate"
  | Ok _ -> failwith "unknown origin became an exact answer"
;;

let print_quantity label model coordinate =
  Stdlib.Printf.printf "%s=%s\n" label (Z.to_string (exact model coordinate))
;;

let%expect_test "neutral coordinate keys preserve spelling and cannot collide by concatenation" =
  let coordinates =
    [ coordinate ~unit:"c" "a/b"
    ; coordinate ~unit:"b/c" "a"
    ; coordinate ~unit:"JPY" "wallet"
    ; coordinate "wallet"
    ; coordinate " wallet "
    ; coordinate "wallet\000"
    ]
  in
  let support = coverage coordinates in
  List.iter coordinates ~f:(fun left ->
    require (Coverage.covers support left) "exact coordinate membership";
    List.iter coordinates ~f:(fun right ->
      require
        (Bool.equal (Int.equal (C.compare left right) 0) (same_coordinate left right))
        "comparator equality matches both opaque roles";
      require
        (Bool.equal (C.equal left right) (same_coordinate left right))
        "coordinate equality"));
  require (not (Coverage.covers support (coordinate ~unit:"jpy " "wallet"))) "no trim";
  Stdlib.Printf.printf "six exact coordinates remain distinct\n";
  [%expect {| six exact coordinates remain distinct |}]
;;

let%expect_test "independent origin evidence rejects the first repeated coordinate" =
  let wallet = coordinate "wallet" in
  require (not (Coverage.covers Coverage.empty wallet)) "empty supports nothing";
  (match Coverage.of_coordinates [ wallet; coordinate ~unit:"usd" "wallet"; wallet; wallet ] with
   | Error (Duplicate_coordinate { position; coordinate = repeated }) ->
     require (same_coordinate repeated wallet) "repeated coordinate";
     Stdlib.Printf.printf "duplicate at position %d\n" position
   | Ok _ -> failwith "duplicate factual evidence silently normalized");
  [%expect {| duplicate at position 3 |}]
;;

let%expect_test "unknown origin differs from covered zero even when activity exists" =
  let wallet = coordinate "wallet" in
  let empty = P.create ~movements:[] ~coverage:Coverage.empty in
  unknown empty wallet;
  let supported = P.create ~movements:[] ~coverage:(coverage [ wallet ]) in
  print_quantity "covered-empty-basis" supported wallet;
  let activity = movement [ change wallet (Z.of_int (-10)); change (coordinate "food") (Z.of_int 10) ] in
  let unsupported = P.create ~movements:[ activity ] ~coverage:Coverage.empty in
  unknown unsupported wallet;
  let cancelled = movement [ change wallet Z.minus_one; change wallet Z.one ] in
  let net_zero = P.create ~movements:[ cancelled ] ~coverage:Coverage.empty in
  unknown net_zero wallet;
  Stdlib.Printf.printf "empty, active, and net-zero unsupported origins remain unknown\n";
  [%expect {|
    covered-empty-basis=0
    empty, active, and net-zero unsupported origins remain unknown |}]
;;

let%expect_test "quantities are coordinate-local across Measures and negative results" =
  let wallet = coordinate "wallet" in
  let usd = coordinate ~unit:"usd" "wallet" in
  let movements =
    [ movement [ change wallet (Z.of_int (-10)); change (coordinate "food") (Z.of_int 10) ]
    ; movement [ change usd (Z.of_int 5); change (coordinate ~unit:"usd" "merchant") (Z.of_int (-5)) ]
    ]
  in
  let model = P.create ~movements ~coverage:(coverage [ wallet; usd; coordinate "untouched" ]) in
  print_quantity "wallet-jpy" model wallet;
  print_quantity "wallet-usd" model usd;
  print_quantity "untouched-jpy" model (coordinate "untouched");
  unknown model (coordinate "food");
  [%expect {|
    wallet-jpy=-10
    wallet-usd=5
    untouched-jpy=0 |}]
;;

let%expect_test "projection counts represented multiplicity without changing source Movements" =
  let huge = Z.of_string "18446744073709551616" in
  let wallet = coordinate "wallet" in
  let food = coordinate "food" in
  let split = movement [ change wallet (Z.neg huge); change food (Z.pred huge); change food Z.one ] in
  let same_locus = movement [ change wallet Z.minus_one; change wallet Z.one ] in
  let source_before = D.Movement.effects split in
  let movements = [ split; split; same_locus ] in
  let model = P.create ~movements ~coverage:(coverage [ wallet; food ]) in
  let first = exact model food in
  require (Z.equal first (exact model food)) "repeat query";
  require
    (Z.equal first (exact (P.create ~movements:(List.rev movements) ~coverage:(coverage [ food; wallet ])) food))
    "construction order";
  let same_change left right =
    D.Identifier.Locus.equal (D.Effect.locus left) (D.Effect.locus right)
    && D.Identifier.Measure.equal (D.Effect.measure left) (D.Effect.measure right)
    && Q.equal (D.Effect.quantity left) (D.Effect.quantity right)
  in
  require (List.equal same_change source_before (D.Movement.effects split)) "source unchanged";
  print_quantity "wallet-jpy" model wallet;
  print_quantity "food-jpy" model food;
  Stdlib.Printf.printf "source split retains %d Effects\n" (List.length (D.Movement.effects split));
  [%expect {|
    wallet-jpy=-36893488147419103232
    food-jpy=36893488147419103232
    source split retains 3 Effects |}]
;;

module Integer_lists = struct
  type t = int list

  let sexp_of_t values = Sexp.List (List.map values ~f:Int.sexp_of_t)
  let quickcheck_generator = Base_quickcheck.Generator.list Base_quickcheck.Generator.int
  let quickcheck_shrinker = Base_quickcheck.Shrinker.list Base_quickcheck.Shrinker.int
end

let%expect_test "generated indexed projection agrees with original-Effect Zarith oracle" =
  let coordinates =
    List.concat_map [ "wallet0"; "wallet1"; "wallet2"; "food0"; "food1"; "food2"; "untouched" ]
      ~f:(fun place -> [ coordinate place; coordinate ~unit:"usd" place ])
  in
  let complete = coverage coordinates in
  let partial = coverage (List.filteri coordinates ~f:(fun index _ -> index % 2 = 0)) in
  let scale = Z.shift_left Z.one 128 in
  let check source =
    let batches =
      List.mapi source ~f:(fun index n ->
        let n = if Int.equal n 0 then Z.one else Z.of_int n in
        let z = Z.mul n scale in
        let unit = if index % 2 = 0 then "jpy" else "usd" in
        let suffix = Int.to_string (index % 3) in
        let wallet = coordinate ~unit ("wallet" ^ suffix) in
        let destination = if index % 3 = 0 then wallet else coordinate ~unit ("food" ^ suffix) in
        let half = Z.neg (Z.divexact z (Z.of_int 2)) in
        [ change wallet z; change destination half; change destination half ])
    in
    (* Duplicate one represented occurrence; no Event deduplication is assumed. *)
    let batches = batches @ List.take batches 1 in
    let original_effects = List.concat batches in
    let movements = List.map batches ~f:movement in
    let model = P.create ~movements ~coverage:complete in
    let reversed = P.create ~movements:(List.rev movements) ~coverage:complete in
    let partially_supported = P.create ~movements ~coverage:partial in
    let unsupported = P.create ~movements ~coverage:Coverage.empty in
    List.iteri coordinates ~f:(fun index target ->
      let oracle =
        List.fold original_effects ~init:Z.zero ~f:(fun total item ->
          let matches =
            D.Identifier.Locus.equal (D.Effect.locus item) target.locus
            && D.Identifier.Measure.equal (D.Effect.measure item) target.measure
          in
          if matches then Z.add total (Q.quanta (D.Effect.quantity item)) else total)
      in
      require (Z.equal (exact model target) oracle) "direct oracle";
      require (Z.equal (exact model target) oracle) "query replay";
      require (Z.equal (exact reversed target) oracle) "input order";
      unknown unsupported target;
      if index % 2 = 0
      then require (Z.equal (exact partially_supported target) oracle) "coverage locality"
      else unknown partially_supported target)
  in
  let config =
    { Base_quickcheck.Test.default_config with
      seed = Deterministic "loam-zero-origin-v1"
    ; test_count = 10_000
    ; shrink_count = 10_000
    }
  in
  let checks = ref 0 in
  Base_quickcheck.Test.run_exn (module Integer_lists) ~config ~f:(fun source ->
    check source;
    Int.incr checks);
  require (Int.equal !checks config.test_count) "generated cases actually ran";
  Stdlib.Printf.printf "conditional projection passed (%d generated cases)\n" !checks;
  [%expect {| conditional projection passed (10000 generated cases) |}]
;;
