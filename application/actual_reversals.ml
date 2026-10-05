open Base
module D = Bakhlo_domain
module Id = D.Identifier.Event

type fact = { target : Id.t; reversal : Id.t }
type role = Target | Reversal
type endpoint = { role : role; event : Id.t }

type error =
  | Repeated_endpoint of {
      event : Id.t;
      first_role : role;
      first_position : int;
      role : role;
      position : int;
    }
  | Unresolved_endpoints of { position : int; endpoints : endpoint list }
  | Not_inverse of { position : int; fact : fact }

type pair = { fact : fact; target : D.Event.t; reversal : D.Event.t }
type indexed = { role : role; position : int; pair : pair }

type t = {
  events : D.Event_memory.t;
  facts : fact list;
  pairs : pair list;
  by_endpoint : (Id.t, indexed, Id.comparator_witness) Map.t;
}

(* Temporary physical rows only; never rewrite/deduplicate retained Effects. *)
let physical change =
  ( ({ locus = D.Effect.locus change; measure = D.Effect.measure change } : D.Effect_coordinate.t),
    D.Effect.quantity change )

let compare_physical (left, lq) (right, rq) =
  let coordinate = D.Effect_coordinate.compare left right in
  if coordinate = 0 then D.Quantity.compare lq rq else coordinate

let inverse target reversal =
  let target = List.map (D.Event.effects target) ~f:physical in
  let reversal =
    List.map (D.Event.effects reversal) ~f:(fun change ->
        let coordinate, quantity = physical change in
        (coordinate, D.Quantity.neg quantity))
  in
  List.equal
    (fun a b -> compare_physical a b = 0)
    (List.sort target ~compare:compare_physical)
    (List.sort reversal ~compare:compare_physical)

let create ~events ~facts =
  let ( let* ) result f = Result.bind result ~f in
  let* _, by_endpoint, reversed =
    List.fold_result facts
      ~init:(1, Map.empty (module Id), [])
      ~f:(fun (position, seen, pairs) (fact : fact) ->
        let fresh role event =
          match Map.find seen event with
          | None -> Ok ()
          | Some first ->
              Error
                (Repeated_endpoint
                   {
                     event;
                     first_role = first.role;
                     first_position = first.position;
                     role;
                     position;
                   })
        in
        let* () = fresh Target fact.target in
        let* () =
          if Id.equal fact.target fact.reversal then
            Error
              (Repeated_endpoint
                 {
                   event = fact.reversal;
                   first_role = Target;
                   first_position = position;
                   role = Reversal;
                   position;
                 })
          else fresh Reversal fact.reversal
        in
        let target = D.Event_memory.find_by_id events fact.target in
        let reversal = D.Event_memory.find_by_id events fact.reversal in
        match (target, reversal) with
        | Some target, Some reversal ->
            if not (inverse target reversal) then Error (Not_inverse { position; fact })
            else
              let pair = { fact; target; reversal } in
              let seen = Map.set seen ~key:fact.target ~data:{ role = Target; position; pair } in
              let seen =
                Map.set seen ~key:fact.reversal ~data:{ role = Reversal; position; pair }
              in
              Ok (position + 1, seen, pair :: pairs)
        | _ ->
            let endpoints =
              List.filter_opt
                [
                  (if Option.is_none target then Some { role = Target; event = fact.target }
                   else None);
                  (if Option.is_none reversal then Some { role = Reversal; event = fact.reversal }
                   else None);
                ]
            in
            Error (Unresolved_endpoints { position; endpoints }))
  in
  Ok { events; facts; pairs = List.rev reversed; by_endpoint }

let source_events t = t.events
let facts t = t.facts
let pairs t = t.pairs
let fact pair = pair.fact
let target_event pair = pair.target
let reversal_event pair = pair.reversal

let find_by_target t id =
  match Map.find t.by_endpoint id with
  | Some { role = Target; pair; position = _ } -> Some pair
  | Some { role = Reversal; _ } | None -> None

let find_by_reversal t id =
  match Map.find t.by_endpoint id with
  | Some { role = Reversal; pair; position = _ } -> Some pair
  | Some { role = Target; _ } | None -> None
