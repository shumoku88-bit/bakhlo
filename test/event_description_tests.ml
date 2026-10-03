open Base
module D = Loam_domain
module E = Loam_application.Event_descriptions
module S = Loam_application.Actual_source
module Q = Loam_application.Current_quantity_query
module F = Fixtures
let ok = function Ok value -> value | Error _ -> failwith "valid description specimen refused"
let fact event text : E.fact = { event = F.id event; text }
let equal_fact (a : E.fact) (b : E.fact) = D.Identifier.Event.equal a.event b.event && String.equal a.text b.text

(* Original input strings/prefixes only: no production identities, maps or lookup. *)
let expected inputs =
  let rec scan position prefix = function
    | [] -> Ok ()
    | (event, _) :: rest ->
      match List.findi prefix ~f:(fun _ previous -> String.equal event previous) with
      | Some (index, _) -> Error (`Repeated (event, index + 1, position))
      | None ->
        if not (List.mem [ "a"; "b" ] event ~equal:String.equal) then Error (`Unknown (event, position))
        else scan (position + 1) (prefix @ [ event ]) rest in
  scan 1 [] inputs
;;

let%expect_test "description admission agrees with all three-slot original-token cases" =
  let events = F.memory [ F.event "a"; F.event "b" ] in
  let admitted = ref 0 in
  for mask = 0 to 63 do
    let inputs = List.filter_mapi [ 0; 1; 2 ] ~f:(fun i _ ->
      let text = if i = 0 then "" else " exact memo " in
      match mask / Int.pow 4 i % 4 with
      | 0 -> None | 1 -> Some ("a", text) | 2 -> Some ("b", text) | _ -> Some ("unknown", text)) in
    let facts = List.map inputs ~f:(fun (event, text) -> fact event text) in
    match expected inputs, E.create ~events ~facts with
    | Ok (), Ok image ->
      Int.incr admitted;
      F.require (List.equal equal_fact facts (E.facts image)) "unmodified declarations/order";
      List.iter [ "a"; "b"; "unknown" ] ~f:(fun event ->
        let expected_text = Option.map (List.find inputs ~f:(fun (id, _) -> String.equal id event)) ~f:snd in
        F.require (Option.equal String.equal expected_text (E.find_text image (F.id event))) "original-list lookup oracle")
    | Error (`Repeated (token, first, repeated)), Error (Repeated_description { event; first_position; position }) ->
      F.require (String.equal (D.Identifier.Event.to_string event) token && first = first_position && repeated = position) "first repeated declaration"
    | Error (`Unknown (token, at)), Error (Unknown_description_event { event; position }) ->
      F.require (String.equal (D.Identifier.Event.to_string event) token && at = position) "first unknown reference"
    | _ -> failwith "description admission differs from token oracle"
  done;
  F.require (!admitted = 13) "executed admitted cases";
  Stdlib.Printf.printf "64 three-slot omission/a/b/unknown cases; 13 admitted; ordered closure/uniqueness\n";
  [%expect {| 64 three-slot omission/a/b/unknown cases; 13 admitted; ordered closure/uniqueness |}]
;;

let%expect_test "description text is exact optional recognition, never general Event admission" =
  let events = [ F.event " a "; F.event "a"; F.observation ~id:(F.id "A") ~effects:[ F.change (F.coordinate "wallet") Z.zero ] ] in
  let memory = F.memory events in
  let facts = [ fact "A" ""; fact " a " "  merchant?\000\027\n\t日本語\\n  " ] in
  let image = ok (E.create ~events:memory ~facts) in
  F.require (List.equal F.equal_event events (D.Event_memory.events (E.source_events image))) "retained source, including general zero Effect";
  F.require (List.equal equal_fact facts (E.facts image)) "text/control characters/order untouched";
  F.require (Option.equal String.equal (E.find_text image (F.id "A")) (Some "")) "empty is not absent";
  F.require (Option.is_none (E.find_text image (F.id "a"))) "exact ID and optionality";
  F.require (Option.equal String.equal (E.find_text image (F.id " a ")) (Some (List.nth_exn facts 1).text)) "no trimming or taxonomy";
  F.require (Result.is_ok (E.create ~events:(F.memory []) ~facts:[])) "empty source/optional descriptions";
  (match E.create ~events:memory ~facts:[ fact "a" "same"; fact "a" "same" ] with
   | Error (Repeated_description { first_position = 1; position = 2; event = _ }) -> ()
   | _ -> failwith "identical descriptions silently deduplicated");
  let permuted = ok (E.create ~events:(F.memory (List.rev events)) ~facts:(List.rev facts)) in
  List.iter [ " a "; "a"; "A" ] ~f:(fun token ->
    F.require (Option.equal String.equal (E.find_text image (F.id token)) (E.find_text permuted (F.id token))) "representation order became authority");
  Stdlib.Printf.printf "exact optional/control/empty text; no physics, classification or representation winner\n";
  [%expect {| exact optional/control/empty text; no physics, classification or representation winner |}]
;;

let%expect_test "one source retains descriptions without inheritance or four-support interference" =
  let coordinate = F.coordinate "wallet" and offset = F.coordinate "offset" and opening = F.coordinate ~unit:"usd" "opening" in
  let huge = Z.shift_left Z.one 160 in
  let events = [ F.event "a";
    F.observation ~id:(F.id "b") ~effects:[ F.change coordinate huge; F.change offset (Z.neg huge);
      F.change opening Z.one; F.change opening Z.minus_one ];
    F.observation ~id:(F.id "x") ~effects:[ F.change coordinate (Z.neg huge); F.change offset huge;
      F.change (F.coordinate "stale") Z.one; F.change (F.coordinate "stale") Z.minus_one ] ] in
  let command : S.command = { events; corrections = [ F.edge "a" "b" ];
    validity_corrections = []; merchants = []; original_amounts = []; exchanges = []; reversals = [];
    validities = List.map events ~f:(fun event -> F.base_validity (D.Event.id event) "2026-10-03");
    descriptions = [ fact "x" ""; fact "a" " retained root text "; fact "b" "terminal text" ] } in
  let source = ok (S.create command) in
  let image source = Q.create ~source ~zero_origins:[ offset ] ~openings:[ { coordinate = opening; opening_event = F.id "b" } ]
    ~groups:[ { reflected_roots = [ F.id "a" ]; assertions = [ F.assertion coordinate huge ] } ]
    ~presence:(Some { reflected_roots = [ F.id "a" ]; coordinates = [ F.coordinate "quiet"; F.coordinate "stale" ] }) in
  let with_text = ok (image source) and without = ok (image (ok (S.create { command with descriptions = [] }))) in
  List.iter [ coordinate, `Assertion; offset, `Origin; opening, `Opening ] ~f:(fun (c, expected) ->
    match Q.query with_text c, Q.query without c with
    | Ok (Exact a), Ok (Exact b) ->
      F.require (D.Quantity.equal (Q.quantity a) (Q.quantity b)) "text entered arithmetic";
      List.iter [ a; b ] ~f:(fun answer ->
        F.require (F.same_coordinate c (Q.coordinate answer)) "answer coordinate changed";
        match expected, Q.premise answer with
        | `Origin, Zero_origin -> ()
        | `Opening, Opening { coordinate; opening_event } ->
          F.require (F.same_coordinate coordinate opening && D.Identifier.Event.equal opening_event (F.id "b")) "opening witness changed"
        | `Assertion, Current_assertion asserted ->
          let module P = Loam_application.Current_quantity_projection in
          F.require (Z.equal (D.Quantity.quanta (P.asserted_quantity asserted)) huge &&
            Z.equal (D.Quantity.quanta (P.delta asserted)) (Z.neg huge)) "independent assertion/cut changed"
        | _ -> failwith "text changed exact premise")
    | _ -> failwith "text changed exact support");
  (match Q.query with_text (F.coordinate "quiet"), Q.query without (F.coordinate "quiet"), Q.query with_text (F.coordinate "missing"), Q.query without (F.coordinate "missing") with
   | Ok (Known_present _), Ok (Known_present _), Error (Support_unknown _), Error (Support_unknown _) -> ()
   | _ -> failwith "text became presence/unknown support");
  (match Q.query with_text (F.coordinate "stale"), Q.query without (F.coordinate "stale") with
   | Error (Support_unknown _), Error (Support_unknown _) -> () | _ -> failwith "text restored stale presence");
  let descriptions = S.descriptions (Q.source with_text) in
  F.require (List.equal equal_fact command.descriptions (E.facts descriptions)) "composed query lost retained metadata";
  F.require (List.equal F.equal_event events (D.Event_memory.events (E.source_events descriptions))) "description source lost superseded observations";
  let tail = F.event "c" in
  let tail_command = { command with events = events @ [ tail ]; corrections = command.corrections @ [ F.edge "b" "c" ];
    validities = command.validities @ [ F.base_validity (F.id "c") "1900-01-01" ] } in
  let extended = ok (S.create tail_command) in
  F.require (Option.is_none (E.find_text (S.descriptions extended) (F.id "c")) &&
    Option.equal String.equal (E.find_text (S.descriptions extended) (F.id "b")) (Some "terminal text")) "correction auto-inherited text";
  F.require (List.equal equal_fact command.descriptions (E.facts (S.descriptions source))) "old source mutated";
  let prefix = { command with events = [ F.event "a" ]; corrections = []; validities = [ List.hd_exn command.validities ] } in
  (match S.create prefix with Error (Descriptions (Unknown_description_event { event; position = 1 })) ->
     F.require (D.Identifier.Event.equal event (F.id "x")) "retained fact outside prefix"
   | _ -> failwith "arbitrary source omission did not requalify descriptions");
  (match S.create { command with descriptions = [ fact "unknown" "text" ]; corrections = [ F.edge "a" "absent" ] } with
   | Error (Corrections _) -> () | _ -> failwith "baseline source ordering changed");
  Stdlib.Printf.printf "source-bound text retained; no arithmetic/support or tail inheritance; prefixes requalify\n";
  [%expect {| source-bound text retained; no arithmetic/support or tail inheritance; prefixes requalify |}]
;;
