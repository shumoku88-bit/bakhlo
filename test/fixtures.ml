open Base
module D = Loam_domain
module Id = D.Identifier.Event
module F = Loam_application.Correction_frontier
module C = Loam_application.Reflected_root_cut
module P = Loam_application.Current_quantity_projection

(* Test construction/retention helpers only, not expected arithmetic or graph admission. *)
let require condition message = if not condition then failwith message
let identifier constructor name =
  match constructor name with
  | Ok value -> value
  | Error D.Identifier.Empty -> failwith "empty fixture identity"
;;
let id name = identifier Id.of_string name
let observation ~id ~effects =
  match D.Event.create ~id ~effects with
  | Ok event -> event
  | Error (Duplicate_effect_key _) -> failwith "invalid keyed Event fixture"
;;
let event name = observation ~id:(id name) ~effects:[]
let edge a b : D.Event_correction.t = { target = id a; replacement = id b }
let memory source =
  match D.Event_memory.of_events source with
  | Ok value -> value
  | Error _ -> failwith "duplicate fixture"
;;
let admitted events corrections =
  match F.create ~events ~corrections with
  | Ok value -> value
  | Error _ -> failwith "valid fixture refused"
;;
let actual_source events corrections =
  let validities = List.map events ~f:(fun event ->
    ({ event = D.Event.id event; valid_on = "2026-10-03" } : Loam_application.Actual_validity.fact)) in
  match Loam_application.Actual_source.create { events; validities; corrections; descriptions = [] } with
  | Ok source -> source
  | Error _ -> failwith "invalid ordinary Actual fixture"
;;
let equal_effect left right =
  Option.equal D.Identifier.Effect_key.equal (D.Effect.key left) (D.Effect.key right)
  && D.Identifier.Locus.equal (D.Effect.locus left) (D.Effect.locus right)
  && D.Identifier.Measure.equal (D.Effect.measure left) (D.Effect.measure right)
  && D.Quantity.equal (D.Effect.quantity left) (D.Effect.quantity right)
;;
let equal_event left right =
  Id.equal (D.Event.id left) (D.Event.id right)
  && List.equal equal_effect (D.Event.effects left) (D.Event.effects right)
;;
let equal_edge (left : D.Event_correction.t) (right : D.Event_correction.t) =
  Id.equal left.target right.target && Id.equal left.replacement right.replacement
;;
let equal_lineage left right =
  Id.equal (F.root_id left) (F.root_id right)
  && equal_event (F.terminal_event left) (F.terminal_event right)
;;
let cut frontier reflected_roots =
  match C.create ~frontier ~reflected_roots with
  | Ok cut -> cut
  | Error _ -> failwith "valid cut refused"
;;
let require_cut_source frontier answer declarations =
  let source = C.source_frontier answer in
  require (List.equal equal_event
    (D.Event_memory.events (F.retained_events frontier))
    (D.Event_memory.events (F.retained_events source))) "unmodified original observations";
  require (List.equal equal_edge (F.corrections frontier) (F.corrections source)) "unmodified original corrections";
  require (List.equal equal_lineage (F.lineages frontier) (F.lineages source)) "unmodified rooted source";
  require (List.equal Id.equal declarations (C.reflected_roots answer)) "unmodified declaration order";
  require (List.equal equal_event (C.remaining_events answer)
    (List.map (C.remaining_lineages answer) ~f:F.terminal_event)) "rows/events agree"
;;
let coordinate ?(unit = "jpy") place : D.Effect_coordinate.t =
  { locus = identifier D.Identifier.Locus.of_string place
  ; measure = identifier D.Identifier.Measure.of_string unit }
;;
let change (coordinate : D.Effect_coordinate.t) quanta =
  D.Effect.create ~key:None ~locus:coordinate.locus ~measure:coordinate.measure ~quantity:(D.Quantity.of_quanta quanta)
;;
let here_change unit quanta = change (coordinate ~unit "here") quanta
let same_coordinate (left : D.Effect_coordinate.t) (right : D.Effect_coordinate.t) =
  D.Identifier.Locus.equal left.locus right.locus
  && D.Identifier.Measure.equal left.measure right.measure
;;
let assertion coordinate quanta : P.assertion = { coordinate; quantity = D.Quantity.of_quanta quanta }
let same_assertion (a : P.assertion) (b : P.assertion) =
  same_coordinate a.coordinate b.coordinate && D.Quantity.equal a.quantity b.quantity
;;
let fixture_coordinate n = coordinate ~unit:(if n < 2 then "jpy" else "usd") (if Int.equal (n % 2) 0 then "wallet" else "other")

module Path_inputs = struct
  type t = int list
  let sexp_of_t values = Sexp.List (List.map values ~f:Int.sexp_of_t)
  let quickcheck_generator =
    let open Base_quickcheck.Generator in
    bind (int_inclusive 0 40) ~f:(fun length -> list_with_length (int_inclusive (-4) 4) ~length)
  let quickcheck_shrinker = Base_quickcheck.Shrinker.list Base_quickcheck.Shrinker.int
end
