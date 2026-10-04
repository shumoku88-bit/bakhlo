open Base
module D = Loam_domain
module R = Open_relations
module Id = D.Identifier.Relation
module Q = D.Quantity

type fact = { event : D.Identifier.Event.t; target : Id.t; quantity : Q.t }
type error =
  | Unknown_event of { event : D.Identifier.Event.t; position : int }
  | Unknown_target of { target : Id.t; position : int }
  | Repeated_correspondence of
      { event : D.Identifier.Event.t; target : Id.t; first_position : int; position : int }
  | Self_discharge of { event : D.Identifier.Event.t; target : Id.t; position : int }
  | Nonpositive_quantity of { event : D.Identifier.Event.t; target : Id.t; quantity : Q.t; position : int }
  | Exceeds_target of
      { event : D.Identifier.Event.t; target : Id.t; quantity : Q.t; target_quantity : Q.t; position : int }
  | Overdischarged_target of { target : Id.t; total : Q.t; target_quantity : Q.t; position : int }
type admitted = { fact : fact; event : D.Event.t; target : R.admitted }
type remainder = { relation : R.admitted; discharges : admitted list; discharged : Q.t }
type bucket = { total : Q.t; reversed : admitted list }

module Pair = struct
  module Key = struct
    type t = { event : D.Identifier.Event.t; target : Id.t }
    let compare left right =
      let event = D.Identifier.Event.compare left.event right.event in
      if event = 0 then Id.compare left.target right.target else event
    ;;
    let sexp_of_t pair = Sexp.List
      [ Atom (D.Identifier.Event.to_string pair.event); Atom (Id.to_string pair.target) ]
  end
  include Key
  include Comparator.Make (Key)
end

type t =
  { relations : R.t; facts : fact list; admitted : admitted list; remainders : remainder list
  ; by_target : (Id.t, remainder, Id.comparator_witness) Map.t }

let create ~relations ~facts =
  let ( let* ) result f = Result.bind result ~f in
  let events = R.source_events relations in
  let* (_, _, buckets, reversed) =
    List.fold_result facts ~init:(1, Map.empty (module Pair), Map.empty (module Id), [])
      ~f:(fun (position, seen, buckets, reversed) (fact : fact) ->
        let* event = match D.Event_memory.find_by_id events fact.event with
          | None -> Error (Unknown_event { event = fact.event; position })
          | Some event -> Ok event in
        let* target = match R.find_by_id relations fact.target with
          | None -> Error (Unknown_target { target = fact.target; position })
          | Some target -> Ok target in
        let pair : Pair.t = { event = fact.event; target = fact.target } in
        let* () = match Map.find seen pair with
          | Some first_position -> Error (Repeated_correspondence
              { event = fact.event; target = fact.target; first_position; position })
          | None -> Ok () in
        let target_fact = R.fact target in
        let* () =
          if D.Identifier.Event.equal fact.event target_fact.source_event then
            Error (Self_discharge { event = fact.event; target = fact.target; position })
          else if Q.compare fact.quantity Q.zero <= 0 then
            Error (Nonpositive_quantity { event = fact.event; target = fact.target; quantity = fact.quantity; position })
          else if Q.compare fact.quantity target_fact.quantity > 0 then
            Error (Exceeds_target { event = fact.event; target = fact.target; quantity = fact.quantity;
              target_quantity = target_fact.quantity; position })
          else Ok () in
        let row = { fact; event; target } in
        let prior = Option.value (Map.find buckets fact.target) ~default:{ total = Q.zero; reversed = [] } in
        let bucket = { total = Q.add prior.total fact.quantity; reversed = row :: prior.reversed } in
        Ok (position + 1, Map.set seen ~key:pair ~data:position,
          Map.set buckets ~key:fact.target ~data:bucket, row :: reversed))
  in
  let admitted = List.rev reversed in
  let* _ = List.fold_result admitted ~init:1 ~f:(fun position row ->
    let total = (Map.find_exn buckets row.fact.target).total in
    let target_quantity = (R.fact row.target).quantity in
    if Q.compare total target_quantity > 0 then
      Error (Overdischarged_target { target = row.fact.target; total; target_quantity; position })
    else Ok (position + 1)) in
  let remainders = List.map (R.admitted relations) ~f:(fun relation ->
    let bucket = Map.find buckets (R.fact relation).id in
    match bucket with
    | None -> { relation; discharges = []; discharged = Q.zero }
    | Some bucket -> { relation; discharges = List.rev bucket.reversed; discharged = bucket.total }) in
  let by_target = List.fold remainders ~init:(Map.empty (module Id)) ~f:(fun index remainder ->
    Map.set index ~key:(R.fact remainder.relation).id ~data:remainder) in
  Ok { relations; facts; admitted; remainders; by_target }
;;
let source_relations t = t.relations
let facts t = t.facts
let admitted t = t.admitted
let fact row = row.fact
let event row = row.event
let target_relation row = row.target
let remainders t = t.remainders
let find_remainder t id = Map.find t.by_target id
let relation remainder = remainder.relation
let discharges remainder = remainder.discharges
let discharged_quantity remainder = remainder.discharged
let remaining_quantity remainder = Q.sub (R.fact remainder.relation).quantity remainder.discharged
