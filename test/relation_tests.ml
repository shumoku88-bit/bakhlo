open Base
module D = Bakhlo_domain
module R = Bakhlo_application.Open_relations
module S = Bakhlo_application.Actual_source
module C = Bakhlo_application.Correction_frontier
module Q = Bakhlo_application.Current_quantity_query
module F = Fixtures
module M = Relation_model
module O = Source_oracle
let ok = function Ok value -> value | Error _ -> failwith "valid relation refused"
let id token = F.identifier D.Identifier.Relation.of_string token
let key token = F.identifier D.Identifier.Effect_key.of_string token
let party token = F.identifier D.Identifier.External_party.of_string token
let endpoint = function M.Household -> R.Household | External token -> R.External (party token)
let fact (raw : M.fact) : R.fact =
  { id = id raw.id; source_event = F.id raw.event; source_effect = key raw.key
  ; debtor = endpoint raw.debtor; creditor = endpoint raw.creditor; quantity = D.Quantity.of_quanta raw.quantity }
;;
let raw ?(event = "a") ?(key = "s") ?(debtor = M.Household) ?(creditor = M.External "p") token n : M.fact =
  { id = token; event; key; debtor; creditor; quantity = Z.of_int n }
let change ?token ?(unit = "jpy") ?(locus = "here") quanta =
  let coordinate = F.coordinate ~unit locus in
  D.Effect.create ~key:(Option.map token ~f:key) ~locus:coordinate.locus ~measure:coordinate.measure ~quantity:(D.Quantity.of_quanta quanta)
;;
let originals =
  [ F.observation ~id:(F.id "a") ~effects:[ change ~token:"s" (Z.of_int (-2)); change ~token:"t" (Z.of_int 2) ]
  ; F.observation ~id:(F.id "b") ~effects:[ change ~token:"s" (Z.of_int 2); change (Z.of_int (-2)) ] ]
let command events relations : S.command =
  { events; relations; discharges = []; corrections = []; validity_corrections = []
  ; validities = List.map events ~f:(fun event -> F.base_validity (D.Event.id event) "2026-10-03")
  ; descriptions = []; merchants = []; original_amounts = []; exchanges = []; reversals = [] }
;;
let equal_endpoint a b = match a, b with
  | R.Household, R.Household -> true
  | External a, External b -> D.Identifier.External_party.equal a b
  | Household, External _ | External _, Household -> false
;;
let equal_fact (a : R.fact) (b : R.fact) =
  D.Identifier.Relation.equal a.id b.id && D.Identifier.Event.equal a.source_event b.source_event
  && D.Identifier.Effect_key.equal a.source_effect b.source_effect && equal_endpoint a.debtor b.debtor
  && equal_endpoint a.creditor b.creditor && D.Quantity.equal a.quantity b.quantity
;;
let retained memory facts qualified =
  F.require (List.equal F.equal_event (D.Event_memory.events memory) (D.Event_memory.events (R.source_events qualified))) "source payload changed";
  F.require (List.equal equal_fact facts (R.facts qualified) && List.equal equal_fact facts (List.map (R.admitted qualified) ~f:R.fact)) "declaration/positive view order changed";
  List.iter (R.admitted qualified) ~f:(fun row ->
    let fact = R.fact row in
    let original = Option.value_exn (D.Event_memory.find_by_id memory fact.source_event) in
    let selected = Option.value_exn (List.find (D.Event.effects original) ~f:(fun c -> Option.equal D.Identifier.Effect_key.equal (D.Effect.key c) (Some fact.source_effect))) in
    F.require (F.equal_event original (R.source_event row) && F.equal_effect selected (R.source_effect row)) "resolved source rewritten";
    F.require (equal_fact fact (R.fact (Option.value_exn (R.find_by_id qualified fact.id)))) "identity index lost fields")
;;
let%expect_test "all bounded independent relation shapes correspond to whole family and composed source" =
  let memory = F.memory originals in
  let admitted = ref 0 in
  List.iter (M.shapes ()) ~f:(fun raw ->
    let facts = List.map raw ~f:fact in
    let expected = M.admitted M.sources raw in
    let result = R.create ~events:memory ~facts in
    F.require (Bool.equal expected (Result.is_ok result)) "original-list relation model differs";
    F.require (Bool.equal expected (Result.is_ok (S.create (command originals facts)))) "source relation composition differs";
    match result with Error _ -> () | Ok qualified -> Int.incr admitted; retained memory facts qualified);
  F.require (!admitted = 265) "product correspondence count";
  Stdlib.Printf.printf "40401 original-token/list cases: 265 whole relation/source admissions; raw facts, source keys/payloads and ID lookup preserved\n";
  [%expect {| 40401 original-token/list cases: 265 whole relation/source admissions; raw facts, source keys/payloads and ID lookup preserved |}]
;;
let%expect_test "relation diagnostics qualify identity globally, every local fact, then exact source coverage" =
  let memory = F.memory originals in
  let create raw = R.create ~events:memory ~facts:(List.map raw ~f:fact) in
  (match create [ raw ~event:"absent" "r" 0; raw "r" 1 ] with
   | Error (Repeated_id { id = repeated; first_position = 1; position = 2 }) -> F.require (D.Identifier.Relation.equal repeated (id "r")) "global identity witness"
   | _ -> failwith "duplicate gate no longer global");
  (match create [ raw ~event:"absent" ~debtor:M.Household ~creditor:M.Household "r" 0 ] with
   | Error (Unknown_event { id = subject; event; position = 1 }) -> F.require (D.Identifier.Relation.equal subject (id "r") && D.Identifier.Event.equal event (F.id "absent")) "Event witness"
   | _ -> failwith "source Event gate order");
  (match create [ raw ~event:"b" ~key:"t" ~creditor:M.Household "r" 0 ] with
   | Error (Missing_effect { id = subject; event; key = selector; position = 1 }) -> F.require (D.Identifier.Relation.equal subject (id "r") && D.Identifier.Event.equal event (F.id "b") && D.Identifier.Effect_key.equal selector (key "t")) "key witness"
   | _ -> failwith "anonymous counterpart selected by coordinate");
  (match create [ raw ~creditor:M.Household "r" 0 ] with
   | Error (Invalid_endpoints { id = subject; debtor = Household; creditor = Household; position = 1 }) -> F.require (D.Identifier.Relation.equal subject (id "r")) "endpoint witness"
   | _ -> failwith "endpoint gate order");
  (match create [ raw "r" 0 ] with
   | Error (Nonpositive_quantity { id = subject; quantity; position = 1 }) -> F.require (D.Identifier.Relation.equal subject (id "r") && D.Quantity.equal quantity D.Quantity.zero) "quantity witness"
   | _ -> failwith "positive gate");
  (match create [ raw "r" 3 ] with
   | Error (Exceeds_source { quantity; magnitude; position = 1; id = _ }) -> F.require (Z.equal (D.Quantity.quanta quantity) (Z.of_int 3) && Z.equal (D.Quantity.quanta magnitude) (Z.of_int 2)) "individual bound witness"
   | _ -> failwith "negative source used as bound/sign role");
  (match create [ raw "r" 2; raw ~debtor:(M.External "q") ~creditor:M.Household "q" 1 ] with
   | Error (Overcovered_source { event; key = selector; total; magnitude; position = 1 }) -> F.require (D.Identifier.Event.equal event (F.id "a") && D.Identifier.Effect_key.equal selector (key "s") && Z.equal (D.Quantity.quanta total) (Z.of_int 3) && Z.equal (D.Quantity.quanta magnitude) (Z.of_int 2)) "aggregate full-total/first-source witness"
   | _ -> failwith "direction/party partition bypassed aggregate coverage");
  (match create [ raw "r" 2; raw "q" 1; raw ~event:"absent" "later" 1 ] with
   | Error (Unknown_event { position = 3; _ }) -> ()
   | _ -> failwith "aggregate masked later local error");
  List.iter [ [ raw "r" 1; raw "q" 1 ]; [ raw "r" 2; raw ~key:"t" "q" 2 ]; [ raw "r" 2; raw ~event:"b" "q" 2 ] ] ~f:(fun rows ->
    let qualified = ok (create rows) in retained memory (List.map rows ~f:fact) qualified);
  Stdlib.Printf.printf "global IDs -> Event/key/endpoints/positive/individual bounds -> full source totals; equal-field units survive, no sign/coordinate/direction alias\n";
  [%expect {| global IDs -> Event/key/endpoints/positive/individual bounds -> full source totals; equal-field units survive, no sign/coordinate/direction alias |}]
;;
let%expect_test "exact relation/source identity, huge signed magnitudes and neutral Event shapes retain independence" =
  let huge = Z.shift_left Z.one 180 in
  let event_id = " a\027\n " and selector = " s\027\n " in
  let original = F.observation ~id:(F.id event_id) ~effects:[ change ~token:selector ~unit:" jpy " (Z.neg huge); change ~unit:"usd" huge ] in
  let memory = F.memory [ original ] in
  let supplied : R.fact = { id = id " r\027\n "; source_event = F.id event_id; source_effect = key selector
    ; debtor = External (party " p\027\n "); creditor = Household; quantity = D.Quantity.of_quanta huge } in
  let evidence = ok (R.create ~events:memory ~facts:[ supplied ]) in
  retained memory [ supplied ] evidence;
  (match D.Identifier.Relation.of_string "" with Error D.Identifier.Empty -> () | Ok _ -> failwith "empty relation identity");
  let smaller = { supplied with quantity = D.Quantity.of_quanta (Z.pred huge) } in
  let last = { supplied with id = id "last"; quantity = D.Quantity.of_quanta Z.one } in
  retained memory [ smaller; last ] (ok (R.create ~events:memory ~facts:[ smaller; last ]));
  (match R.create ~events:memory ~facts:[ supplied; last ] with
   | Error (Overcovered_source { total; magnitude; position = 1; _ }) ->
     F.require (Z.equal (D.Quantity.quanta total) (Z.succ huge) && Z.equal (D.Quantity.quanta magnitude) huge) "huge aggregate overflow/rounding"
   | _ -> failwith "huge magnitude overcoverage accepted");
  let reordered = F.observation ~id:(D.Event.id original) ~effects:(List.rev (D.Event.effects original)) in
  retained (F.memory [ reordered ]) [ supplied ] (ok (R.create ~events:(F.memory [ reordered ]) ~facts:[ supplied ]));
  F.require (Option.is_none (R.find_by_id (ok (R.create ~events:memory ~facts:[])) supplied.id)) "clean absence became a unit";
  let selected = R.source_effect (Option.value_exn (R.find_by_id evidence supplied.id)) in
  F.require (D.Identifier.Measure.equal (D.Effect.measure selected) (F.coordinate ~unit:" jpy " "here").measure) "Measure duplicated/normalized";
  F.require (Option.is_none (R.find_by_id evidence (id "r"))) "relation identity trimmed/defaulted";
  F.require (Result.is_error (R.create ~events:memory ~facts:[ { supplied with source_effect = key "s" } ])) "key normalized";
  (* Source tuples whose concatenated spellings collide must stay distinct. *)
  let make event token = F.observation ~id:(F.id event) ~effects:[ change ~token Z.minus_one; change Z.one ] in
  let sources = [ make "a:b" "c"; make "a" "b:c" ] in
  let facts = List.map [ raw ~event:"a:b" ~key:"c" "x" 1; raw ~event:"a" ~key:"b:c" "y" 1 ] ~f:fact in
  retained (F.memory sources) facts (ok (R.create ~events:(F.memory sources) ~facts));
  let zero = F.observation ~id:(F.id "a") ~effects:[ change ~token:"s" Z.zero ] in
  (match R.create ~events:(F.memory [ zero ]) ~facts:[ fact (raw "r" 1) ] with
   | Error (Exceeds_source { magnitude; position = 1; _ }) -> F.require (D.Quantity.equal magnitude D.Quantity.zero) "zero-source bound"
   | _ -> failwith "zero source created positive unit");
  (match S.create (command [ original ] [ supplied ]) with
   | Error (Unbalanced_measure { event; event_position = 1; _ }) ->
     F.require (D.Identifier.Event.equal event (D.Event.id original)) "relation bypassed physical source gate"
   | _ -> failwith "relation granted physical balance exemption");
  let with_zero = F.observation ~id:(F.id "a") ~effects:[ change ~token:"s" Z.minus_one; change Z.one; change Z.zero ] in
  (match S.create (command [ with_zero ] [ fact (raw "r" 1) ]) with
   | Error (Zero_effect { event_position = 1; effect_position = 3; _ }) -> ()
   | _ -> failwith "unrelated zero Effect hidden by valid relation");
  retained memory [ supplied ] evidence;
  Stdlib.Printf.printf "exact/control identities, 180-bit magnitude and derived Measure; typed source pairs avoid concatenation; general Event standalone != Actual admission\n";
  [%expect {| exact/control identities, 180-bit magnitude and derived Measure; typed source pairs avoid concatenation; general Event standalone != Actual admission |}]
;;
let%expect_test "relations remain on retained keyed Effects through correction, prefixes and source rebuilding" =
  let facts = List.map [ raw "r" 1; raw "q" 1 ] ~f:fact in
  let raw = { (command originals facts) with corrections = [ F.edge "a" "b" ]
    ; descriptions = [ { event = F.id "a"; text = "original" } ]
    ; merchants = [ { event = F.id "a"; disposition = Merchant (party "p") } ]
    ; original_amounts = [ { root = F.id "a"; measure = (F.coordinate ~unit:"eur" "here").measure; quantity = D.Quantity.of_quanta (Z.of_int 5) } ] } in
  let source = ok (S.create raw) in
  let relations = S.relations source in
  retained (F.memory originals) facts relations;
  F.require (List.equal F.equal_event (C.frontier_events (S.frontier source)) [ List.nth_exn originals 1 ]) "relation changed correction selection";
  let row = Option.value_exn (R.find_by_id relations (id "r")) in
  F.require (F.equal_event (R.source_event row) (List.hd_exn originals) && Z.sign (D.Quantity.quanta (D.Effect.quantity (R.source_effect row))) < 0) "source auto-retargeted to same spelling key on terminal";
  let tail = F.observation ~id:(F.id "c") ~effects:[ change ~token:"s" (Z.of_int 7); change (Z.of_int (-7)) ] in
  let extended = ok (S.create { raw with events = originals @ [ tail ]; corrections = raw.corrections @ [ F.edge "b" "c" ]; validities = raw.validities @ [ F.base_validity (F.id "c") "1900-01-01" ] }) in
  retained (F.memory (originals @ [ tail ])) facts (S.relations extended);
  F.require (F.equal_effect (R.source_effect row) (R.source_effect (Option.value_exn (R.find_by_id (S.relations extended) (id "r"))))) "fresh tail changed observation";
  let prefixed = ok (S.create { raw with events = tail :: originals; corrections = F.edge "c" "a" :: raw.corrections; validities = F.base_validity (F.id "c") "1900-01-01" :: raw.validities; original_amounts = [] }) in
  retained (F.memory (tail :: originals)) facts (S.relations prefixed);
  retained (F.memory (List.rev originals)) (List.rev facts)
    (ok (R.create ~events:(F.memory (List.rev originals)) ~facts:(List.rev facts)));
  (match R.create ~events:(F.memory [ List.nth_exn originals 1 ]) ~facts with
   | Error (Unknown_event { position = 1; _ }) -> ()
   | _ -> failwith "omitted source silently pruned/remapped");
  retained (F.memory originals) facts relations;
  Stdlib.Printf.printf "superseded source remains exact, no same-key transfer; fresh tails/prefixes/permutation requalify, omission refuses and old evidence is immutable\n";
  [%expect {| superseded source remains exact, no same-key transfer; fresh tails/prefixes/permutation requalify, omission refuses and old evidence is immutable |}]
;;
let%expect_test "relation units do not alter Exchange/Reversal/date metadata or independently supplied quantity/presence" =
  let e = F.observation ~id:(F.id "e") ~effects:[ change ~token:"s" ~locus:"wallet" (Z.of_int (-3)); change ~token:"d" ~unit:"usd" ~locus:"wallet" (Z.of_int 2) ] in
  let reversed = F.observation ~id:(F.id "r") ~effects:(List.map (D.Event.effects e) ~f:(fun c -> D.Effect.create ~key:(D.Effect.key c)
    ~locus:(D.Effect.locus c) ~measure:(D.Effect.measure c) ~quantity:(D.Quantity.neg (D.Effect.quantity c)))) in
  let other = F.observation ~id:(F.id "o") ~effects:[ change ~token:"s" ~locus:"offset" (Z.of_int 4); change ~locus:"food" (Z.of_int (-4)) ] in
  let facts = List.map [ raw ~event:"e" "loan" 2; raw ~event:"r" ~debtor:(M.External "q") ~creditor:M.Household "inverse-unit" 1 ] ~f:fact in
  let raw = { (command [ e; reversed; other ] facts) with
    exchanges = [ { event = F.id "e"; source = key "s"; destination = key "d" } ]; reversals = [ { target = F.id "e"; reversal = F.id "r" } ];
    descriptions = [ { event = F.id "e"; text = "not relation direction" } ]; merchants = [ { event = F.id "e"; disposition = Merchant (party "q") } ];
    original_amounts = [ { root = F.id "e"; measure = (F.coordinate ~unit:"eur" "here").measure; quantity = D.Quantity.of_quanta (Z.of_int 20) } ];
    validity_corrections = [ { target = Base_ref (F.id "e"); replacement = F.identifier D.Identifier.Validity_revision.of_string "date" } ];
    validities = (command [ e; reversed; other ] facts).validities @ [ Revision { id = F.identifier D.Identifier.Validity_revision.of_string "date"; event = F.id "e"; valid_on = "1900-01-01" } ] } in
  let source = ok (S.create raw) and without = ok (S.create { raw with relations = [] }) in
  let build source = ok (Q.create ~source ~zero_origins:[ F.coordinate "offset" ]
    ~openings:[ { coordinate = F.coordinate ~unit:"usd" "wallet"; opening_event = F.id "e" } ]
    ~groups:[ { reflected_roots = [ F.id "e" ]; assertions = [ F.assertion (F.coordinate "wallet") (Z.of_int 10) ] } ]
    ~presence:(Some { reflected_roots = []; coordinates = [ F.coordinate "quiet"; F.coordinate "food" ] })) in
  let image = build source and baseline = build without in
  List.iter [ F.coordinate "offset"; F.coordinate ~unit:"usd" "wallet"; F.coordinate "wallet" ] ~f:(fun coordinate ->
    match Q.query image coordinate, Q.query baseline coordinate with
    | Ok (Exact a), Ok (Exact b) -> F.require (D.Quantity.equal (Q.quantity a) (Q.quantity b)) "relation changed exact support/delta"
    | _ -> failwith "exact support lost");
  (match Q.query image (F.coordinate "quiet"), Q.query image (F.coordinate "food") with
   | Ok (Known_present _), Error _ -> () | _ -> failwith "relation touched presence");
  let empty = ok (Q.create ~source ~zero_origins:[] ~openings:[] ~groups:[] ~presence:None) in
  F.require (Result.is_error (Q.query empty (F.coordinate "wallet"))) "relation inferred zero/support at cancelled physical quantity";
  let selected = C.frontier_events (S.frontier source) in
  F.require (List.equal F.equal_event selected (C.frontier_events (S.frontier without))
    && Z.equal (O.sum_events selected (F.coordinate "wallet")) Z.zero
    && O.touches_events selected (F.coordinate "wallet")) "retained Effect sum/touch correspondence";
  F.require (List.length (Bakhlo_application.Exchange_evidence.facts (S.exchanges source)) = 1
    && List.length (Bakhlo_application.Actual_reversals.facts (S.reversals source)) = 1
    && Option.is_some (Bakhlo_application.Actual_validity.find_current (S.validity source) (F.id "e"))
    && Option.is_some (Bakhlo_application.Original_amounts.find_current (S.original_amounts source) (F.id "e"))) "adjacent evidence lost";
  Stdlib.Printf.printf "relations on both Exchange/Reversal endpoints remain independent; date/text/Merchant/root amounts, four supports and original Effect touch/sums unchanged; unsupported at net zero\n";
  [%expect {| relations on both Exchange/Reversal endpoints remain independent; date/text/Merchant/root amounts, four supports and original Effect touch/sums unchanged; unsupported at net zero |}]
;;
