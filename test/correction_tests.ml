open Base

module D = Loam_domain
module Id = D.Identifier.Event
module E = D.Event
module Memory = D.Event_memory
module Check = Loam_application.Correction_check

let require condition message = if not condition then failwith message

let identifier constructor spelling =
  match constructor spelling with
  | Ok value -> value
  | Error D.Identifier.Empty -> failwith "empty fixture identity"
;;

let id spelling = identifier Id.of_string spelling

let change ?(unit = "jpy") place quanta =
  D.Effect.create ~key:None
    ~locus:(identifier D.Identifier.Locus.of_string place)
    ~measure:(identifier D.Identifier.Measure.of_string unit)
    ~quantity:(D.Quantity.of_quanta quanta)
;;

let event name effects = Fixtures.observation ~id:(id name) ~effects

let memory events =
  match Memory.of_events events with
  | Ok value -> value
  | Error (Duplicate_id _) -> failwith "duplicate fixture identity"
;;

let correction target replacement : D.Event_correction.t =
  { target = id target; replacement = id replacement }
;;

let equal_change left right =
  D.Identifier.Locus.equal (D.Effect.locus left) (D.Effect.locus right)
  && D.Identifier.Measure.equal (D.Effect.measure left) (D.Effect.measure right)
  && D.Quantity.equal (D.Effect.quantity left) (D.Effect.quantity right)
;;

let equal_event left right =
  Id.equal (E.id left) (E.id right)
  && List.equal equal_change (E.effects left) (E.effects right)
;;

let closed events correction =
  match Check.run ~events ~correction with
  | Ok value -> value
  | Error _ -> failwith "fixture endpoints missing"
;;

let equal_correction (left : D.Event_correction.t) (right : D.Event_correction.t) =
  Id.equal left.target right.target && Id.equal left.replacement right.replacement
;;

let require_missing events correction expected =
  match Check.run ~events ~correction with
  | Ok _ -> failwith "missing observation became a closed answer"
  | Error errors ->
    let equal_error
        (Check.Missing_event { endpoint = left_endpoint; id = left_id })
        (Check.Missing_event { endpoint = right_endpoint; id = right_id })
      =
      let same_endpoint =
        match left_endpoint, right_endpoint with
        | Target, Target | Replacement, Replacement -> true
        | Target, Replacement | Replacement, Target -> false
      in
      same_endpoint && Id.equal left_id right_id
    in
    require (not (List.is_empty errors)) "nonempty refusal";
    require (List.equal equal_error errors expected) "missing endpoint roles/order/identities"
;;

let%expect_test "Event identities are exact nonempty tokens, not arrival rank or other roles" =
  (match Id.of_string "" with
   | Error D.Identifier.Empty -> ()
   | Ok _ -> failwith "empty identity admitted");
  let ids = List.map [ "event"; "Event"; " event "; "event\000"; "event/2" ] ~f:id in
  List.iter ids ~f:(fun left ->
    List.iter ids ~f:(fun right ->
      require
        (Bool.equal (Int.equal (Id.compare left right) 0) (Id.equal left right))
        "mechanical comparator equality"));
  require (not (Id.equal (id "event") (id " event "))) "no trimming";
  require (String.equal (Id.to_string (id " event ")) " event ") "exact spelling";
  let events = memory (List.map ids ~f:(fun id -> Fixtures.observation ~id ~effects:[])) in
  List.iter ids ~f:(fun requested ->
    match Memory.find_by_id events requested with
    | Some found -> require (Id.equal (E.id found) requested) "exact indexed identity"
    | None -> failwith "opaque identity lost by indexing");
  require (Option.is_none (Memory.find_by_id events (id "event "))) "no lookup alias";
  Stdlib.Printf.printf "empty refused; exact spelling retained\n";
  [%expect {| empty refused; exact spelling retained |}]
;;

let%expect_test "neutral Events retain empty, zero, mixed-Measure and nonconserving observations" =
  let empty = event "empty" [] in
  let huge = Z.of_string "18446744073709551616" in
  let effects = [ change "wallet" Z.zero; change ~unit:"usd" "wallet" huge; change "wallet" huge ] in
  let observed = event "observed" effects in
  require (List.equal equal_change effects (E.effects observed)) "retained representation";
  require (Result.is_error (D.Movement.validate effects)) "not ordinary Movement admission";
  Stdlib.Printf.printf
    "empty Effects=%d; observed Effects=%d\n"
    (List.length (E.effects empty))
    (List.length (E.effects observed));
  [%expect {| empty Effects=0; observed Effects=3 |}]
;;

let%expect_test "memory refuses duplicate identity even for equal payloads" =
  let original = event "same" [ change "wallet" Z.one ] in
  let different = event "same" [ change "wallet" Z.minus_one ] in
  List.iter [ original; different ] ~f:(fun repeated ->
    match Memory.of_events [ event "other" []; original; repeated; original ] with
    | Error (Duplicate_id { id = duplicate; first_position; position }) ->
      Stdlib.Printf.printf
        "duplicate %S: original=%d repeated=%d\n"
        (Id.to_string duplicate)
        first_position
        position
    | Ok _ -> failwith "duplicate identity normalized/overwritten");
  [%expect {|
    duplicate "same": original=2 repeated=3
    duplicate "same": original=2 repeated=3 |}]
;;

let%expect_test "closed answer retains both observations, edge, and source order" =
  let original = event "original" [ change "wallet" (Z.of_int (-10)) ] in
  let replacement = event "replacement" [ change "wallet" (Z.of_int (-20)) ] in
  let source = [ replacement; original ] in
  let events = memory source in
  let edge = correction "original" "replacement" in
  let answer = closed events edge in
  require (equal_event (Check.target_event answer) original) "target observation";
  require (equal_event (Check.replacement_event answer) replacement) "replacement observation";
  require (equal_correction (Check.correction answer) edge) "retained explicit edge";
  require (List.equal equal_event source (Memory.events events)) "source unchanged";
  let reversed = closed (memory (List.rev source)) edge in
  require (equal_event (Check.target_event reversed) original) "order-independent target";
  require (equal_event (Check.replacement_event reversed) replacement) "order-independent replacement";
  Stdlib.Printf.printf
    "target=%S; replacement=%S; retained Events=%d\n"
    (Id.to_string (E.id (Check.target_event answer)))
    (Id.to_string (E.id (Check.replacement_event answer)))
    (List.length (Memory.events events));
  [%expect {| target="original"; replacement="replacement"; retained Events=2 |}]
;;

let%expect_test "missing endpoints are ordered typed refusals, never synthetic Events" =
  let present = memory [ event "present" [] ] in
  require_missing present (correction "missing" "present")
    [ Missing_event { endpoint = Target; id = id "missing" } ];
  require_missing present (correction "present" "missing")
    [ Missing_event { endpoint = Replacement; id = id "missing" } ];
  require_missing present (correction "left" "right")
    [ Missing_event { endpoint = Target; id = id "left" }
    ; Missing_event { endpoint = Replacement; id = id "right" }
    ];
  require_missing (memory []) (correction "same" "same")
    [ Missing_event { endpoint = Target; id = id "same" }
    ; Missing_event { endpoint = Replacement; id = id "same" }
    ];
  require (Option.is_none (Memory.find_by_id present (id "missing"))) "absent lookup";
  Stdlib.Printf.printf "target/replacement absence stays distinct, including one ID in both roles\n";
  [%expect {| target/replacement absence stays distinct, including one ID in both roles |}]
;;

let%expect_test "endpoint closure is not graph admission or terminal selection" =
  let a = event "a" [] in
  let b = event "b" [] in
  let c = event "c" [] in
  let events = memory [ a; b; c ] in
  let self = closed events (correction "a" "a") in
  require (equal_event (Check.target_event self) (Check.replacement_event self)) "self closure";
  List.iter [ correction "a" "b"; correction "b" "a"; correction "a" "c"; correction "b" "c" ]
    ~f:(fun edge -> ignore (closed events edge : Check.closed));
  let first = closed events (correction "a" "b") in
  ignore (closed events (correction "b" "c") : Check.closed);
  require (equal_event (Check.replacement_event first) b) "do not follow to terminal c";
  require (List.equal equal_event (Memory.events events) [ a; b; c ]) "no graph application";
  Stdlib.Printf.printf "self/cycle/competition/merge can close; no currentness is established\n";
  [%expect {| self/cycle/competition/merge can close; no currentness is established |}]
;;

module Integer_lists = struct
  type t = int list

  let sexp_of_t values = Sexp.List (List.map values ~f:Int.sexp_of_t)
  let quickcheck_generator = Base_quickcheck.Generator.list Base_quickcheck.Generator.int
  let quickcheck_shrinker = Base_quickcheck.Shrinker.list Base_quickcheck.Shrinker.int
end

let%expect_test "generated lookup and closure agree with an independent source-list oracle" =
  let scale = Z.shift_left Z.one 128 in
  let missing = id "absent" in
  let check source =
    let observations =
      List.mapi source ~f:(fun index n ->
        let z = Z.mul (Z.of_int n) scale in
        event ("event:" ^ Int.to_string index)
          [ change "wallet" z; change ~unit:"usd" "wallet" (Z.neg z); change "wallet" z ])
    in
    let events = memory observations in
    let reversed = memory (List.rev observations) in
    require (List.equal equal_event observations (Memory.events events)) "memory representation";
    let requested = missing :: List.map observations ~f:E.id in
    List.iter requested ~f:(fun requested_id ->
      let oracle = List.find observations ~f:(fun event -> Id.equal (E.id event) requested_id) in
      require (Option.equal equal_event (Memory.find_by_id events requested_id) oracle) "lookup oracle";
      require (Option.equal equal_event (Memory.find_by_id reversed requested_id) oracle) "lookup reorder");
    let rotated = match observations with [] -> [] | first :: rest -> rest @ [ first ] in
    List.iter2_exn observations rotated ~f:(fun target replacement ->
      let edge : D.Event_correction.t = { target = E.id target; replacement = E.id replacement } in
      let check_answer answer =
        require (equal_event (Check.target_event answer) target) "target payload";
        require (equal_event (Check.replacement_event answer) replacement) "replacement payload";
        require (equal_correction (Check.correction answer) edge) "edge preservation"
      in
      check_answer (closed events edge);
      check_answer (closed events edge);
      check_answer (closed reversed edge);
      require_missing events { target = E.id target; replacement = missing }
        [ Missing_event { endpoint = Replacement; id = missing } ];
      require_missing events { target = missing; replacement = E.id replacement }
        [ Missing_event { endpoint = Target; id = missing } ]);
    require_missing events { target = missing; replacement = missing }
      [ Missing_event { endpoint = Target; id = missing }
      ; Missing_event { endpoint = Replacement; id = missing }
      ];
    (match observations with
     | [] -> ()
     | first :: _ ->
       let duplicate = Fixtures.observation ~id:(E.id first) ~effects:[] in
       (match Memory.of_events (observations @ [ duplicate ]) with
        | Error (Duplicate_id { id = repeated; first_position; position }) ->
          require (Id.equal repeated (E.id first)) "duplicate identity";
          require (Int.equal first_position 1) "original position";
          require (Int.equal position (List.length observations + 1)) "repeated position"
        | Ok _ -> failwith "generated duplicate admitted"));
    require (List.equal equal_event observations (Memory.events events)) "resolution is immutable"
  in
  let config =
    { Base_quickcheck.Test.default_config with
      seed = Deterministic "loam-correction-endpoints-v1"
    ; test_count = 10_000
    ; shrink_count = 10_000
    }
  in
  let checks = ref 0 in
  Base_quickcheck.Test.run_exn (module Integer_lists) ~config ~f:(fun source ->
    check source;
    Int.incr checks);
  require (Int.equal !checks config.test_count) "generated cases actually ran";
  Stdlib.Printf.printf "identity lookup/closure passed (%d generated cases)\n" !checks;
  [%expect {| identity lookup/closure passed (10000 generated cases) |}]
;;
