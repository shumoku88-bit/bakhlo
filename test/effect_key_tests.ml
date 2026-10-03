open Base
module D = Loam_domain
module F = Fixtures
module Q = Loam_application.Current_quantity_query
module H = Loam_application.Current_quantity_groups
module P = Loam_application.Current_quantity_projection
module S = Loam_application.Actual_source
let key text = F.identifier D.Identifier.Effect_key.of_string text
let change token (c : D.Effect_coordinate.t) quanta =
  D.Effect.create ~key:(Option.map token ~f:key) ~locus:c.locus ~measure:c.measure ~quantity:(D.Quantity.of_quanta quanta)
let ok = function Ok x -> x | Error _ -> failwith "valid keyed specimen refused"

(* Original token-prefix oracle, not Effect getters, production maps or admission. *)
let first_duplicate tokens =
  let rec scan position prefix = function
    | [] -> None
    | token :: rest ->
      match token with
      | None -> scan (position + 1) (prefix @ [ token ]) rest
      | Some spelling ->
        match List.findi prefix ~f:(fun _ previous -> Option.equal String.equal previous token) with
        | Some (index, _) -> Some (spelling, index + 1, position)
        | None -> scan (position + 1) (prefix @ [ token ]) rest in
  scan 1 [] tokens
;;

let%expect_test "optional exact Effect keys do not impose identity on anonymous multiplicity" =
  let spellings = [ "key"; " key "; "KEY"; "key\000"; "a/b" ] in
  (match D.Identifier.Effect_key.of_string "" with Error Empty -> () | Ok _ -> failwith "empty key admitted");
  List.iter spellings ~f:(fun a -> List.iter spellings ~f:(fun b ->
    F.require (Bool.equal (D.Identifier.Effect_key.equal (key a) (key b)) (String.equal a b)) "exact equality";
    F.require (Bool.equal (D.Identifier.Effect_key.compare (key a) (key b) = 0) (String.equal a b)) "mechanical comparator");
    F.require (String.equal (D.Identifier.Effect_key.to_string (key a)) a) "no normalization");
  let c = F.coordinate "wallet" and huge = Z.shift_left Z.one 180 in
  let effects = List.map spellings ~f:(fun spelling -> change (Some spelling) c huge) @ [ change None c huge; change None c huge ] in
  let event = ok (D.Event.create ~id:(F.id "e") ~effects) in
  F.require (List.equal F.equal_effect effects (D.Event.effects event)) "keys/amounts/order retained";
  List.iter [ []; [ change None c Z.zero ]; [ change (Some "k") c Z.minus_one; change None (F.coordinate ~unit:"usd" "wallet") huge ] ] ~f:(fun effects ->
    F.require (Result.is_ok (D.Event.create ~id:(F.id "general") ~effects)) "empty/zero/mixed/nonconserving Domain Event narrowed");
  Stdlib.Printf.printf "exact opaque optional keys; anonymous multiplicity; general Event shapes retained\n";
  [%expect {| exact opaque optional keys; anonymous multiplicity; general Event shapes retained |}]
;;

let%expect_test "all four-Effect key patterns agree with original-token duplicate oracle" =
  let coordinates = [ F.coordinate "wallet"; F.coordinate "wallet"; F.coordinate "other"; F.coordinate ~unit:"usd" "wallet" ] in
  let amounts = [ Z.zero; Z.shift_left Z.one 160; Z.minus_one; Z.of_int 7 ] in
  let admitted = ref 0 in
  for mask = 0 to 80 do
    let tokens = List.init 4 ~f:(fun i -> match mask / Int.pow 3 i % 3 with 0 -> None | 1 -> Some "a" | _ -> Some "b") in
    let effects = List.mapi tokens ~f:(fun i token -> change token (List.nth_exn coordinates i) (List.nth_exn amounts i)) in
    match first_duplicate tokens, D.Event.create ~id:(F.id "e") ~effects with
    | None, Ok event ->
      Int.incr admitted;
      F.require (List.equal F.equal_effect effects (D.Event.effects event)) "no reordering/deduplication";
      F.require (Result.is_ok (D.Event.create ~id:(F.id "e") ~effects:(List.rev effects))) "admission permutation"
    | Some (spelling, first, repeated), Error (Duplicate_effect_key { key; first_position; position }) ->
      F.require (String.equal (D.Identifier.Effect_key.to_string key) spelling && first = first_position && repeated = position) "first exact duplicate/whole-Effect positions"
    | _ -> failwith "key admission disagrees with list oracle"
  done;
  F.require (!admitted = 21) "executed admitted cases";
  let identical = change (Some "a") (F.coordinate "wallet") Z.one in
  (match D.Event.create ~id:(F.id "e") ~effects:[ identical; identical ] with
   | Error (Duplicate_effect_key { first_position = 1; position = 2; key = _ }) -> ()
   | Ok _ | Error (Duplicate_effect_key _) -> failwith "identical keyed payload deduplicated");
  Stdlib.Printf.printf "81 key patterns; 21 admitted; identity independent of coordinates/quantities\n";
  [%expect {| 81 key patterns; 21 admitted; identity independent of coordinates/quantities |}]
;;

let%expect_test "keys are Event-local retained provenance and invisible to four-family arithmetic/touch" =
  let wallet = F.coordinate "wallet" and offset = F.coordinate "offset" in
  let opening_c = F.coordinate ~unit:"usd" "opening" and stale = F.coordinate "stale" in
  let huge = Z.shift_left Z.one 160 in
  let events =
    [ F.observation ~id:(F.id "a") ~effects:[ change (Some "k") wallet huge; change None wallet (Z.neg huge) ];
      F.observation ~id:(F.id "b") ~effects:[ change (Some "k") wallet (Z.mul huge (Z.of_int 2)); change (Some "j") offset (Z.mul huge (Z.of_int (-2)));
        change (Some "u") opening_c (Z.of_int 3); change (Some "v") opening_c (Z.of_int (-3)) ];
      F.observation ~id:(F.id "x") ~effects:[ change None wallet (Z.neg huge); change (Some "k") offset huge; change None stale Z.one; change None stale Z.minus_one ] ] in
  let unkeyed = List.map events ~f:(fun e -> F.observation ~id:(D.Event.id e) ~effects:(List.map (D.Event.effects e) ~f:(fun fx ->
    D.Effect.create ~key:None ~locus:(D.Effect.locus fx) ~measure:(D.Effect.measure fx) ~quantity:(D.Effect.quantity fx)))) in
  let edges = [ F.edge "a" "b" ] in
  let groups : H.group list = [ { reflected_roots = [ F.id "a" ]; assertions = [ F.assertion wallet (Z.mul huge (Z.of_int 10)) ] } ] in
  let openings : Q.opening list = [ { coordinate = opening_c; opening_event = F.id "b" } ] in
  let presence : Q.presence = { reflected_roots = [ F.id "a" ]; coordinates = [ F.coordinate "quiet"; stale ] } in
  let image events = ok (Q.create ~source:(F.actual_source events edges) ~zero_origins:[ offset ] ~openings ~groups ~presence:(Some presence)) in
  let keyed = image events and anonymous = image unkeyed in
  List.iter [ wallet; offset; opening_c ] ~f:(fun c -> match Q.query keyed c, Q.query anonymous c with
    | Ok (Exact a), Ok (Exact b) -> F.require (D.Quantity.equal (Q.quantity a) (Q.quantity b)) "keys affected arithmetic"
    | _ -> failwith "exact support changed");
  (match Q.query keyed wallet with Ok (Exact a) ->
     (match Q.premise a with Current_assertion p -> F.require (Z.equal (D.Quantity.quanta (P.quantity p)) (Z.mul huge (Z.of_int 9))) "independent cut" | Zero_origin | Opening _ -> failwith "premise changed")
   | _ -> failwith "anchor unavailable");
  (match Q.query keyed (F.coordinate "quiet"), Q.query anonymous (F.coordinate "quiet"), Q.query keyed stale, Q.query anonymous stale with
   | Ok (Known_present _), Ok (Known_present _), Error (Support_unknown _), Error (Support_unknown _) -> ()
   | _ -> failwith "key presence affected touch/support");
  let retained = D.Event_memory.events (Loam_application.Correction_frontier.retained_events (S.frontier (Q.source keyed))) in
  F.require (List.equal F.equal_event events retained) "superseded/current keys retained, not retargeted";
  Stdlib.Printf.printf "same key in different Events; all source keys retained; quantities and presence unchanged\n";
  [%expect {| same key in different Events; all source keys retained; quantities and presence unchanged |}]
;;
