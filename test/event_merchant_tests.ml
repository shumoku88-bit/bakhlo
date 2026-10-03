open Base
module D = Loam_domain
module M = Loam_application.Event_merchants
module S = Loam_application.Actual_source
module Q = Loam_application.Current_quantity_query
module F = Fixtures
module O = Source_oracle

let ok = function Ok value -> value | Error _ -> failwith "valid Merchant specimen refused"
let party token = F.identifier D.Identifier.External_party.of_string token
let fact event disposition : M.fact = { event = F.id event; disposition }
let disposition = function None -> M.Nonmerchant | Some token -> M.Merchant (party token)
let equal_disposition a b = match a, b with
  | M.Merchant a, M.Merchant b -> D.Identifier.External_party.equal a b
  | Nonmerchant, Nonmerchant -> true
  | Merchant _, Nonmerchant | Nonmerchant, Merchant _ -> false
;;
let equal_fact (a : M.fact) (b : M.fact) =
  D.Identifier.Event.equal a.event b.event && equal_disposition a.disposition b.disposition
;;

(* Original tokens/prefixes only, no product identities, maps or lookup. *)
let expected inputs =
  let rec scan position prefix = function
    | [] -> Ok ()
    | (event, _) :: rest ->
      match List.findi prefix ~f:(fun _ previous -> String.equal event previous) with
      | Some (index, _) -> Error (`Repeated (event, index + 1, position))
      | None ->
        if not (List.mem [ "a"; "b" ] event ~equal:String.equal)
        then Error (`Unknown (event, position))
        else scan (position + 1) (prefix @ [ event ]) rest
  in
  scan 1 [] inputs
;;

let%expect_test "Merchant admission matches 512 original-token/disposition combinations" =
  let events = F.memory [ F.event "a"; F.event "b" ] in
  let choices = [ None; Some ("a", Some "p"); Some ("a", Some "q"); Some ("a", None);
    Some ("b", Some "p"); Some ("b", None); Some ("unknown", Some "p"); Some ("unknown", None) ] in
  let admitted = ref 0 in
  for mask = 0 to 511 do
    let inputs = List.filter_map [ 0; 1; 2 ] ~f:(fun i -> List.nth_exn choices (mask / Int.pow 8 i % 8)) in
    let facts = List.map inputs ~f:(fun (event, value) -> fact event (disposition value)) in
    match expected inputs, M.create ~events ~facts with
    | Ok (), Ok image ->
      Int.incr admitted;
      F.require (List.equal equal_fact facts (M.facts image)) "unmodified dispositions/order";
      List.iter [ "a"; "b"; "unknown" ] ~f:(fun token ->
        let original = Option.map (List.find inputs ~f:(fun (event, _) -> String.equal token event))
            ~f:(fun (_, value) -> disposition value) in
        F.require (Option.equal equal_disposition original (M.find_disposition image (F.id token)))
          "unresolved/nonmerchant/provider differed from original list")
    | Error (`Repeated (token, first, repeated)), Error (Repeated_disposition { event; first_position; position }) ->
      F.require (String.equal (D.Identifier.Event.to_string event) token && first = first_position && repeated = position)
        "first repeated Event, including equal/contradictory payloads"
    | Error (`Unknown (token, at)), Error (Unknown_merchant_event { event; position }) ->
      F.require (String.equal (D.Identifier.Event.to_string event) token && at = position) "first dangling Event"
    | _ -> failwith "Merchant admission differs from token oracle"
  done;
  F.require (!admitted = 52) "executed admitted Merchant cases";
  Stdlib.Printf.printf "512 three-slot omission/provider/nonmerchant/reference cases; 52 admitted; three-way lookup\n";
  [%expect {| 512 three-slot omission/provider/nonmerchant/reference cases; 52 admitted; three-way lookup |}]
;;

let%expect_test "external identity is exact and role-free; dispositions do not narrow general Events" =
  (match D.Identifier.External_party.of_string "" with Error Empty -> () | Ok _ -> failwith "empty party accepted");
  let spellings = [ "p"; " p "; "P"; "nonmerchant"; "\000\027\n\t日本語\\n" ] in
  List.iter spellings ~f:(fun token ->
    F.require (String.equal token (D.Identifier.External_party.to_string (party token))) "party token was normalized");
  F.require (not (D.Identifier.External_party.equal (party "p") (party " p ")) &&
    not (D.Identifier.External_party.equal (party "p") (party "P"))) "exact distinct parties aliased";
  let originals = [ F.event " a "; F.event "a";
    F.observation ~id:(F.id "A") ~effects:[ F.change (F.coordinate "wallet") Z.zero ]; F.event "empty" ] in
  let facts = [ fact " a " (Merchant (party (List.last_exn spellings))); fact "a" Nonmerchant;
    fact "A" (Merchant (party (List.last_exn spellings))) ] in
  let image = ok (M.create ~events:(F.memory originals) ~facts) in
  F.require (List.equal F.equal_event originals (D.Event_memory.events (M.source_events image))) "source physics were narrowed";
  F.require (List.equal equal_fact facts (M.facts image)) "exact source/facts lost";
  F.require (Option.equal equal_disposition (M.find_disposition image (F.id "a")) (Some Nonmerchant) &&
    Option.is_none (M.find_disposition image (F.id "empty"))) "explicit nonmerchant became unresolved or vice versa";
  let permuted = ok (M.create ~events:(F.memory (List.rev originals)) ~facts:(List.rev facts)) in
  List.iter [ " a "; "a"; "A"; "empty" ] ~f:(fun token ->
    F.require (Option.equal equal_disposition (M.find_disposition image (F.id token))
      (M.find_disposition permuted (F.id token))) "representation became classification authority");
  F.require (Result.is_ok (M.create ~events:(F.memory []) ~facts:[])) "optional empty memory refused";
  Stdlib.Printf.printf "exact/control/shared role-free parties; general zero/empty Events; optional explicit nonmerchant\n";
  [%expect {| exact/control/shared role-free parties; general zero/empty Events; optional explicit nonmerchant |}]
;;

let%expect_test "Merchant source connection preserves four supports, history and noninheritance" =
  let wallet = F.coordinate "wallet" and offset = F.coordinate "offset" in
  let opening = F.coordinate ~unit:"usd" "opening" and counterpart = F.coordinate ~unit:"usd" "counterpart" in
  let quiet = F.coordinate "quiet" and stale = F.coordinate "stale" in
  let huge = Z.shift_left Z.one 160 in
  let keyed = D.Effect.create ~key:(Some (F.identifier D.Identifier.Effect_key.of_string "physical"))
    ~locus:wallet.locus ~measure:wallet.measure ~quantity:(D.Quantity.of_quanta huge) in
  let events = [ F.event "a";
    F.observation ~id:(F.id "b") ~effects:[ keyed; F.change offset (Z.neg huge);
      F.change opening Z.one; F.change counterpart Z.minus_one ];
    F.observation ~id:(F.id "x") ~effects:[ F.change wallet Z.minus_one; F.change offset Z.one;
      F.change stale Z.one; F.change stale Z.minus_one ] ] in
  let facts = [ fact "a" (Merchant (party " provider ")); fact "x" Nonmerchant ] in
  let command : S.command =
    { events; validities = List.map events ~f:(fun event -> F.base_validity (D.Event.id event) "2026-10-03")
    ; validity_corrections = []; corrections = [ F.edge "a" "b" ]
    ; descriptions = [ { event = F.id "b"; text = "merchant inferred?" }; { event = F.id "a"; text = "nonmerchant" } ]
    ; merchants = facts
    ; original_amounts = []
    } in
  let source = ok (S.create command) in
  let image source = ok (Q.create ~source ~zero_origins:[ offset ]
    ~openings:[ { coordinate = opening; opening_event = F.id "b" } ]
    ~groups:[ { reflected_roots = [ F.id "a" ]; assertions = [ F.assertion wallet huge ] } ]
    ~presence:(Some { reflected_roots = [ F.id "a" ]; coordinates = [ quiet; stale ] })) in
  let dated = { command with
    validities = command.validities @ [ Revision { id = F.identifier D.Identifier.Validity_revision.of_string "date-a";
      event = F.id "a"; valid_on = "1900-01-01" } ];
    validity_corrections = [ { target = Base_ref (F.id "a"); replacement = F.identifier D.Identifier.Validity_revision.of_string "date-a" } ] } in
  let permuted = { dated with events = List.rev events; validities = List.rev dated.validities;
    descriptions = List.rev dated.descriptions; merchants = List.rev facts } in
  let pairs = O.expected_pairs events command.corrections in
  let terminals = List.map pairs ~f:snd in
  let unreflected = List.filter_map pairs ~f:(fun (root, event) -> if D.Identifier.Event.equal root (F.id "a") then None else Some event) in
  List.iter [ source; ok (S.create { command with merchants = [] }); ok (S.create permuted) ] ~f:(fun source ->
    let query = image source in
    List.iter [ offset, O.sum_events terminals offset, `Origin;
      opening, O.sum_events terminals opening, `Opening;
      wallet, Z.add huge (O.sum_events unreflected wallet), `Assertion ] ~f:(fun (coordinate, expected, premise) ->
      match Q.query query coordinate with
      | Ok (Exact answer) ->
        F.require (Z.equal expected (D.Quantity.quanta (Q.quantity answer))) "Merchant entered arithmetic";
        (match premise, Q.premise answer with
         | `Origin, Zero_origin -> ()
         | `Opening, Opening { coordinate; opening_event } ->
           F.require (F.same_coordinate coordinate opening && D.Identifier.Event.equal opening_event (F.id "b")) "opening retargeted"
         | `Assertion, Current_assertion assertion ->
           let module P = Loam_application.Current_quantity_projection in
           F.require (Z.equal huge (D.Quantity.quanta (P.asserted_quantity assertion)) &&
             Z.equal (O.sum_events unreflected wallet) (D.Quantity.quanta (P.delta assertion))) "independent assertion/cut changed"
         | _ -> failwith "Merchant changed exact premise")
      | _ -> failwith "Merchant changed exact answerability");
    F.require (not (O.touches_events unreflected quiet) && O.touches_events unreflected stale &&
      Z.equal (O.sum_events unreflected stale) Z.zero) "touch oracle fixture";
    (match Q.query query quiet, Q.query query stale, Q.query query (F.coordinate "missing") with
     | Ok (Known_present present), Error (Support_unknown _), Error (Support_unknown _) ->
       F.require (F.same_coordinate quiet (Q.present_coordinate present)) "presence coordinate changed"
     | _ -> failwith "classification became exact/presence/unknown support"));
  let retained = S.merchants (Q.source (image source)) in
  F.require (List.equal equal_fact facts (M.facts retained) &&
    List.equal F.equal_event events (D.Event_memory.events (M.source_events retained))) "composed source lost provenance";
  F.require (Option.is_none (M.find_disposition retained (F.id "b"))) "description or corrected root inferred Merchant";
  let tail = F.event "c" in
  let extended = ok (S.create { command with events = events @ [ tail ];
    validities = command.validities @ [ F.base_validity (F.id "c") "0001-01-01" ];
    corrections = command.corrections @ [ F.edge "b" "c" ]; merchants = facts @ [ fact "b" Nonmerchant ] }) in
  F.require (Option.is_none (M.find_disposition (S.merchants extended) (F.id "c")) &&
    Option.equal equal_disposition (M.find_disposition (S.merchants extended) (F.id "b")) (Some Nonmerchant) &&
    List.equal equal_fact facts (M.facts (S.merchants source))) "tail inherited/rewrote dispositions or old source";
  let prefix = { command with events = List.take events 2; validities = List.take command.validities 2 } in
  (match S.create prefix with
   | Error (Merchants (Unknown_merchant_event { event; position = 2 })) -> F.require (D.Identifier.Event.equal event (F.id "x")) "prefix witness"
   | _ -> failwith "prefix erased dangling classification");
  (match S.create { command with descriptions = [ { event = F.id "unknown"; text = "text" } ]; merchants = [ fact "unknown" Nonmerchant ] } with
   | Error (Descriptions _) -> () | _ -> failwith "Merchant bypassed prior descriptions gate");
  let unbalanced = F.observation ~id:(F.id "bad") ~effects:[ F.change wallet Z.one ] in
  (match S.create { events = [ unbalanced ]; validities = [ F.base_validity (F.id "bad") "2026-10-03" ];
    validity_corrections = []; corrections = []; descriptions = []; merchants = [ fact "bad" (Merchant (party "p")) ]; original_amounts = [] } with
   | Error (Unbalanced_measure { event; event_position = 1; measure; residual }) ->
     F.require (D.Identifier.Event.equal event (F.id "bad") && D.Identifier.Measure.equal measure wallet.measure &&
       D.Quantity.equal residual (D.Quantity.of_quanta Z.one)) "physical refusal witness"
   | _ -> failwith "Merchant justified unbalanced ordinary Event");
  Stdlib.Printf.printf "source-bound classification; four supports unchanged; date/text/key independence; tails/prefixes requalify\n";
  [%expect {| source-bound classification; four supports unchanged; date/text/key independence; tails/prefixes requalify |}]
;;
