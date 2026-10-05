open Base
module D = Bakhlo_domain
module R = Bakhlo_application.Actual_reversals
module S = Bakhlo_application.Actual_source
module E = Bakhlo_application.Exchange_evidence
module Q = Bakhlo_application.Current_quantity_query
module C = Bakhlo_application.Correction_frontier
module F = Fixtures
module M = Reversal_model
module X = Exchange_model
module O = Source_oracle

let ok = function Ok value -> value | Error _ -> failwith "valid Reversal refused"
let fact target reversal : R.fact = { target = F.id target; reversal = F.id reversal }

let same_fact (a : R.fact) (b : R.fact) =
  D.Identifier.Event.equal a.target b.target && D.Identifier.Event.equal a.reversal b.reversal

let key token = F.identifier D.Identifier.Effect_key.of_string token

let event token changes =
  F.observation ~id:(F.id token)
    ~effects:
      (List.mapi changes ~f:(fun i (c : M.change) ->
           let coordinate = F.coordinate ~unit:c.measure c.locus in
           D.Effect.create
             ~key:(if i % 2 = 0 then Some (key (Int.to_string i)) else None)
             ~locus:coordinate.locus ~measure:coordinate.measure
             ~quantity:(D.Quantity.of_quanta c.quanta)))

let command events reversals exchanges : S.command =
  {
    events;
    reversals;
    exchanges;
    relations = [];
    discharges = [];
    corrections = [];
    validity_corrections = [];
    validities = List.map events ~f:(fun e -> F.base_validity (D.Event.id e) "2026-10-03");
    descriptions = [];
    merchants = [];
    original_amounts = [];
  }

let check_retention memory facts evidence =
  F.require
    (List.equal F.equal_event (D.Event_memory.events memory)
       (D.Event_memory.events (R.source_events evidence)))
    "retained Event payload lost";
  F.require (List.equal same_fact facts (R.facts evidence)) "raw relation order lost";
  F.require
    (List.equal same_fact facts (List.map (R.pairs evidence) ~f:R.fact))
    "pair order differs";
  List.iter (R.pairs evidence) ~f:(fun pair ->
      let f = R.fact pair in
      F.require
        (F.equal_event (R.target_event pair)
           (Option.value_exn (D.Event_memory.find_by_id memory f.target))
        && F.equal_event (R.reversal_event pair)
             (Option.value_exn (D.Event_memory.find_by_id memory f.reversal)))
        "pair rewrote endpoints";
      F.require
        (Option.is_some (R.find_by_target evidence f.target)
        && Option.is_some (R.find_by_reversal evidence f.reversal)
        && Option.is_none (R.find_by_target evidence f.reversal)
        && Option.is_none (R.find_by_reversal evidence f.target))
        "role lookup aliased")

let%expect_test
    "all independent physical pairs and endpoint collections correspond without aggregate matching"
    =
  let exact = ref 0 and sourced = ref 0 in
  let words = M.words () in
  List.iter words ~f:(fun target ->
      List.iter words ~f:(fun reversal ->
          let originals = [ event "t" target; event "r" reversal ] in
          let memory = F.memory originals and facts = [ fact "t" "r" ] in
          let admitted = R.create ~events:memory ~facts in
          F.require
            (Bool.equal (M.exact target reversal) (Result.is_ok admitted))
            "occurrence-removal model differs";
          (match admitted with
          | Error _ -> ()
          | Ok e ->
              Int.incr exact;
              check_retention memory facts e);
          let source = S.create (command originals facts []) in
          F.require
            (Bool.equal
               (M.exact target reversal && M.ordinary target && M.ordinary reversal)
               (Result.is_ok source))
            "ordinary target/source gate differs";
          if Result.is_ok source then Int.incr sourced));
  let originals = List.map [ "0"; "1"; "2"; "3" ] ~f:F.event in
  let memory = F.memory originals in
  let unique = ref 0 in
  let relations = M.relations () in
  List.iter relations ~f:(fun relation ->
      let facts = List.map relation ~f:(fun (a, b) -> fact (Int.to_string a) (Int.to_string b)) in
      let result = R.create ~events:memory ~facts in
      F.require
        (Bool.equal (M.unique_endpoints relation) (Result.is_ok result))
        "global endpoint roles differ";
      match result with
      | Error _ -> ()
      | Ok e ->
          Int.incr unique;
          check_retention memory facts e);
  F.require (!exact = 289 && !sourced = 9 && !unique = 37) "product execution counts";
  Stdlib.Printf.printf
    "7225 pairs: 289 exact, 9 ordinary source; 273 endpoint collections: 37 admitted; retained \
     keys/payloads/roles\n";
  [%expect
    {| 7225 pairs: 289 exact, 9 ordinary source; 273 endpoint collections: 37 admitted; retained keys/payloads/roles |}]

let%expect_test "earned Exchange shapes qualify inverse sides but never rescue unclaimed targets" =
  let admissions = ref 0 in
  List.iter (X.shapes ()) ~f:(fun changes ->
      let convert (c : X.change) : M.change =
        { locus = "here"; measure = c.measure; quanta = c.quanta }
      in
      let target =
        F.observation ~id:(F.id "t")
          ~effects:
            (List.map changes ~f:(fun c ->
                 let coord = F.coordinate ~unit:c.measure "here" in
                 D.Effect.create ~key:(Option.map c.key ~f:key) ~locus:coord.locus
                   ~measure:coord.measure ~quantity:(D.Quantity.of_quanta c.quanta)))
      in
      let reversal = event "r" (List.rev (M.inverse (List.map changes ~f:convert))) in
      let claim : E.fact =
        { event = F.id "t"; source = key "source"; destination = key "destination" }
      in
      let result = S.create (command [ reversal; target ] [ fact "t" "r" ] [ claim ]) in
      let expected = X.admitted changes X.selected && X.nonzero changes in
      F.require
        (Bool.equal expected (Result.is_ok result))
        "Exchange target reversal derivation differs";
      if Result.is_ok result then Int.incr admissions;
      let no_claim = S.create (command [ reversal; target ] [ fact "t" "r" ] []) in
      F.require
        (Bool.equal (X.ordinary changes) (Result.is_ok no_claim))
        "pair alone rescued unbalanced target";
      (* Claim ONLY reversal with reverse selectors: its qualification cannot flow backwards. *)
      let keyed_reverse =
        F.observation ~id:(F.id "r")
          ~effects:
            (List.map (D.Event.effects target) ~f:(fun change ->
                 D.Effect.create ~key:(D.Effect.key change) ~locus:(D.Effect.locus change)
                   ~measure:(D.Effect.measure change)
                   ~quantity:(D.Quantity.neg (D.Effect.quantity change))))
      in
      let reverse_claim : E.fact =
        { event = F.id "r"; source = key "destination"; destination = key "source" }
      in
      F.require
        (Result.is_error
           (S.create (command [ keyed_reverse; target ] [ fact "t" "r" ] [ reverse_claim ])))
        "reverse Exchange rescued target");
  F.require (!admissions = 74) "Exchange/Reversal execution count";
  Stdlib.Printf.printf
    "9216 earned Exchange shapes: 74 source pairs, target must independently qualify; reversal \
     first and keys ignored\n";
  [%expect
    {| 9216 earned Exchange shapes: 74 source pairs, target must independently qualify; reversal first and keys ignored |}]

let%expect_test
    "Reversal exact bytes, huge multiplicity, closure and refusal positions survive replay" =
  let token = " t\027\n " and reverse = " r " in
  let huge = Z.shift_left Z.one 180 in
  let changes : M.change list =
    [
      { locus = " here "; measure = " jpy "; quanta = huge };
      { locus = " here "; measure = " jpy "; quanta = huge };
      { locus = "elsewhere"; measure = " jpy "; quanta = Z.neg (Z.mul (Z.of_int 2) huge) };
    ]
  in
  let t = event token changes in
  let r =
    F.observation ~id:(F.id reverse)
      ~effects:
        (List.map
           (List.rev (D.Event.effects t))
           ~f:(fun c ->
             D.Effect.create ~key:None ~locus:(D.Effect.locus c) ~measure:(D.Effect.measure c)
               ~quantity:(D.Quantity.neg (D.Effect.quantity c))))
  in
  let originals = [ r; t; F.event "other" ] and facts = [ fact token reverse ] in
  let memory = F.memory originals in
  let evidence = ok (R.create ~events:memory ~facts) in
  check_retention memory facts evidence;
  check_retention
    (F.memory (List.rev originals))
    facts
    (ok (R.create ~events:(F.memory (List.rev originals)) ~facts));
  check_retention memory facts (ok (R.create ~events:memory ~facts));
  F.require
    (Option.is_none (R.find_by_target evidence (F.id "t"))
    && Option.is_none (R.find_by_reversal evidence (F.id "unknown")))
    "identity normalized/defaulted";
  let expect_repeat facts first_role first_position role position id =
    match R.create ~events:memory ~facts with
    | Error (Repeated_endpoint e) ->
        F.require
          (Poly.equal e.first_role first_role
          && e.first_position = first_position && Poly.equal e.role role && e.position = position
          && D.Identifier.Event.equal e.event (F.id id))
          "wrong ordered repeated witness"
    | _ -> failwith "endpoint reuse accepted"
  in
  expect_repeat (facts @ facts) R.Target 1 R.Target 2 token;
  expect_repeat (facts @ [ fact reverse "missing" ]) R.Reversal 1 R.Target 2 reverse;
  expect_repeat (facts @ [ fact "other" token ]) R.Target 1 R.Reversal 2 token;
  expect_repeat [ fact "missing" "missing" ] R.Target 1 R.Reversal 1 "missing";
  (match R.create ~events:memory ~facts:[ fact "x" "y" ] with
  | Error
      (Unresolved_endpoints
         {
           position = 1;
           endpoints = [ { role = Target; event = a }; { role = Reversal; event = b } ];
         }) ->
      F.require
        (D.Identifier.Event.equal a (F.id "x") && D.Identifier.Event.equal b (F.id "y"))
        "missing endpoint order"
  | _ -> failwith "closure gate drift");
  let mismatched =
    event reverse
      [
        { locus = " here "; measure = " jpy "; quanta = Z.neg (Z.mul (Z.of_int 2) huge) };
        { locus = "elsewhere"; measure = " jpy "; quanta = Z.mul (Z.of_int 2) huge };
      ]
  in
  (match R.create ~events:(F.memory [ t; mismatched ]) ~facts with
  | Error (Not_inverse { position = 1; fact = supplied }) ->
      F.require (same_fact supplied (List.hd_exn facts)) "inverse error facts"
  | _ -> failwith "coordinate totals replaced multiset matching");
  List.iter
    [ ("here", " jpy "); (" here ", "jpy") ]
    ~f:(fun (locus, measure) ->
      let wrong =
        event reverse
          (List.map (M.inverse changes) ~f:(fun c ->
               if String.equal c.locus " here " then { c with locus; measure } else c))
      in
      F.require
        (Result.is_error (R.create ~events:(F.memory [ t; wrong ]) ~facts))
        "coordinate bytes normalized");
  (match R.create ~events:memory ~facts:[ fact token "missing" ] with
  | Error (Unresolved_endpoints { position = 1; endpoints = [ { role = Reversal; event } ] }) ->
      F.require (D.Identifier.Event.equal event (F.id "missing")) "single unresolved role"
  | _ -> failwith "single endpoint closure drift");
  let zero : M.change list = [ { locus = "here"; measure = "jpy"; quanta = Z.zero } ] in
  let originals = [ event "z" zero; event "zr" zero ] and zero_facts = [ fact "z" "zr" ] in
  F.require
    (Result.is_ok (R.create ~events:(F.memory originals) ~facts:zero_facts))
    "standalone matcher became physical source";
  (match S.create (command originals zero_facts []) with
  | Error (Zero_effect { event; event_position = 1; effect_position = 1 }) ->
      F.require (D.Identifier.Event.equal event (F.id "z")) "zero witness"
  | _ -> failwith "inverse bypassed zero gate");
  (match S.create (command (List.rev originals) zero_facts []) with
  | Error (Zero_effect { event; event_position = 1; effect_position = 1 }) ->
      F.require (D.Identifier.Event.equal event (F.id "zr")) "reversal-side nonzero check skipped"
  | _ -> failwith "reversal exemption bypassed physical zero");
  F.require
    (Result.is_error (R.create ~events:(F.memory [ r ]) ~facts))
    "omitted target auto-retargeted";
  check_retention memory facts evidence;
  Stdlib.Printf.printf
    "exact control identities/180-bit repeated quantities; keys/order irrelevant, multiplicity \
     essential; ordered reuse/closure/zero guards and immutable old evidence\n";
  [%expect
    {| exact control identities/180-bit repeated quantities; keys/order irrelevant, multiplicity essential; ordered reuse/closure/zero guards and immutable old evidence |}]

let%expect_test
    "Reversal is retained correspondence, not correction or automatic current cancellation" =
  let make name n =
    event name
      [
        { locus = "wallet"; measure = "jpy"; quanta = Z.of_int n };
        { locus = "offset"; measure = "jpy"; quanta = Z.of_int (-n) };
      ]
  in
  let a = make "a" (-3) and r = make "r" 3 and c = make "c" (-2) in
  let originals = [ a; r; c ] and facts = [ fact "a" "r" ] in
  let raw =
    {
      (command originals facts []) with
      corrections = [ F.edge "a" "c" ];
      descriptions = [ { event = F.id "a"; text = "original" } ];
      merchants = [ { event = F.id "a"; disposition = Nonmerchant } ];
      original_amounts =
        [
          {
            root = F.id "a";
            measure = (F.coordinate ~unit:"eur" "wallet").measure;
            quantity = D.Quantity.of_quanta (Z.of_int 17);
          };
        ];
    }
  in
  let source = ok (S.create raw) in
  let selected = C.frontier_events (S.frontier source) in
  F.require (List.equal F.equal_event selected [ r; c ]) "Reversal changed correction frontier";
  let pair = Option.value_exn (R.find_by_target (S.reversals source) (F.id "a")) in
  F.require
    (F.equal_event a (R.target_event pair) && F.equal_event r (R.reversal_event pair))
    "historical pair retargeted";
  let image =
    ok
      (Q.create ~source
         ~zero_origins:[ F.coordinate "wallet" ]
         ~openings:[] ~groups:[] ~presence:None)
  in
  (match Q.query image (F.coordinate "wallet") with
  | Ok (Exact answer) ->
      F.require
        (Z.equal
           (D.Quantity.quanta (Q.quantity answer))
           (O.sum_events selected (F.coordinate "wallet"))
        && Z.equal (D.Quantity.quanta (Q.quantity answer)) Z.one)
        "selected inverse auto-deleted or forced to zero"
  | _ -> failwith "origin lost");
  let without = ok (S.create { raw with reversals = [] }) in
  F.require
    (List.equal F.equal_event selected (C.frontier_events (S.frontier without)))
    "relation selected winners";
  let prefix = make "prefix" (-7) in
  let extended =
    ok
      (S.create
         {
           raw with
           events = prefix :: originals;
           corrections = F.edge "prefix" "a" :: raw.corrections;
           validities = F.base_validity (F.id "prefix") "1900-01-01" :: raw.validities;
           original_amounts = [];
         })
  in
  F.require
    (F.equal_event a
       (R.target_event (Option.value_exn (R.find_by_target (S.reversals extended) (F.id "a")))))
    "root-only/current-only restriction invented";
  check_retention (F.memory originals) facts (S.reversals source);
  Stdlib.Printf.printf
    "retained inverse pair survives ordinary correction/prefix; frontier r/c sums +1, not forced \
     zero; metadata/root amount remain independent\n";
  [%expect
    {| retained inverse pair survives ordinary correction/prefix; frontier r/c sums +1, not forced zero; metadata/root amount remain independent |}]

let%expect_test
    "Exchange Reversal does not create support and independent cuts/touches retain four-family \
     meanings" =
  let target =
    F.observation ~id:(F.id "e")
      ~effects:
        [
          D.Effect.create
            ~key:(Some (key "s"))
            ~locus:(F.coordinate "wallet").locus ~measure:(F.coordinate "wallet").measure
            ~quantity:(D.Quantity.of_quanta (Z.of_int (-100)));
          D.Effect.create
            ~key:(Some (key "d"))
            ~locus:(F.coordinate "wallet").locus
            ~measure:(F.coordinate ~unit:"usd" "wallet").measure
            ~quantity:(D.Quantity.of_quanta (Z.of_int 2));
          F.change (F.coordinate "wallet") Z.minus_one;
          F.change (F.coordinate "touch") Z.minus_one;
        ]
  in
  let reversal =
    F.observation ~id:(F.id "r")
      ~effects:
        (List.rev_map (D.Event.effects target) ~f:(fun c ->
             D.Effect.create ~key:None ~locus:(D.Effect.locus c) ~measure:(D.Effect.measure c)
               ~quantity:(D.Quantity.neg (D.Effect.quantity c))))
  in
  let other =
    F.observation ~id:(F.id "o")
      ~effects:
        [
          F.change (F.coordinate "offset") (Z.of_int 5);
          F.change (F.coordinate "food") (Z.of_int (-5));
          F.change (F.coordinate "stale") Z.one;
          F.change (F.coordinate "stale") Z.minus_one;
        ]
  in
  let claim : E.fact = { event = F.id "e"; source = key "s"; destination = key "d" } in
  let source = ok (S.create (command [ target; reversal; other ] [ fact "e" "r" ] [ claim ])) in
  (match S.create (command [ reversal; target; other ] [ fact "e" "r" ] []) with
  | Error (Unbalanced_measure { event; event_position = 2; measure; residual }) ->
      F.require
        (D.Identifier.Event.equal event (F.id "e")
        && D.Identifier.Measure.equal measure (F.coordinate "wallet").measure
        && Z.equal (D.Quantity.quanta residual) (Z.of_int (-102)))
        "target balance guard borrowed reversal exemption"
  | _ -> failwith "unbalanced target pair admitted");
  (match
     S.create
       {
         (command [ target; reversal; other ] [ fact "e" "r" ] [ claim ]) with
         corrections = [ F.edge "e" "r" ];
       }
   with
  | Error (Exchanges (Correction_mentions_event { position = 1; event })) ->
      F.require (D.Identifier.Event.equal event (F.id "e")) "Exchange/correction ordered witness"
  | _ -> failwith "Reversal weakened Exchange correction prohibition");
  let corrected =
    ok
      (S.create
         {
           (command [ target; reversal; other ] [ fact "e" "r" ] [ claim ]) with
           corrections = [ F.edge "r" "o" ];
         })
  in
  F.require
    (List.equal F.equal_event (C.frontier_events (S.frontier corrected)) [ target; other ]
    && F.equal_event reversal
         (R.reversal_event (Option.value_exn (R.find_by_target (S.reversals corrected) (F.id "e"))))
    )
    "non-Exchange subject correction invented exclusion/retargeting";
  let empty = ok (Q.create ~source ~zero_origins:[] ~openings:[] ~groups:[] ~presence:None) in
  F.require
    (Result.is_error (Q.query empty (F.coordinate "wallet")))
    "inverse pair manufactured zero support";
  let build roots presence_roots =
    ok
      (Q.create ~source
         ~zero_origins:[ F.coordinate "offset" ]
         ~openings:[ { coordinate = F.coordinate ~unit:"usd" "wallet"; opening_event = F.id "e" } ]
         ~groups:
           [
             {
               reflected_roots = List.map roots ~f:F.id;
               assertions = [ F.assertion (F.coordinate "wallet") (Z.of_int 10) ];
             };
           ]
         ~presence:
           (Some
              {
                reflected_roots = List.map presence_roots ~f:F.id;
                coordinates = List.map [ "quiet"; "stale"; "touch" ] ~f:F.coordinate;
              }))
  in
  let first = build [ "e" ] [] and both = build [ "r"; "e" ] [ "e"; "r" ] in
  let exact image coordinate expected =
    match Q.query image coordinate with
    | Ok (Exact answer) ->
        F.require
          (Z.equal (D.Quantity.quanta (Q.quantity answer)) (Z.of_int expected))
          "four-support quantity drift"
    | _ -> failwith "exact support lost"
  in
  exact first (F.coordinate "offset") 5;
  exact first (F.coordinate ~unit:"usd" "wallet") 0;
  exact first (F.coordinate "wallet") 111;
  exact both (F.coordinate "wallet") 10;
  F.require
    ((not (O.touches_events [ target; reversal; other ] (F.coordinate "quiet")))
    && O.touches_events [ target; reversal ] (F.coordinate "touch")
    && Z.equal (O.sum_events [ target; reversal ] (F.coordinate "touch")) Z.zero)
    "original Effect touch oracle";
  (match
     ( Q.query first (F.coordinate "quiet"),
       Q.query first (F.coordinate "touch"),
       Q.query both (F.coordinate "touch"),
       Q.query both (F.coordinate "stale") )
   with
  | Ok (Known_present _), Error _, Ok (Known_present _), Error _ -> ()
  | _ -> failwith "cancelling Reversal activity ceased to invalidate presence");
  exact first (F.coordinate "wallet") 111;
  Stdlib.Printf.printf
    "unknown at net zero; origin 5, opening 0, one-endpoint assertion 111/both 10; pair touches \
     invalidate presence independently of zero; old image immutable\n";
  [%expect
    {| unknown at net zero; origin 5, opening 0, one-endpoint assertion 111/both 10; pair touches invalidate presence independently of zero; old image immutable |}]
