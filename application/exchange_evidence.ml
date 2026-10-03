open Base
module D = Loam_domain
module Id = D.Identifier.Event
module Q = D.Quantity

type fact = { event : Id.t; source : D.Identifier.Effect_key.t; destination : D.Identifier.Effect_key.t }
type selection = { fact : fact; event : D.Event.t; source_effect : D.Effect.t; destination_effect : D.Effect.t }
type t =
  { events : D.Event_memory.t
  ; corrections : D.Event_correction.t list
  ; facts : fact list
  ; by_event : (Id.t, int * selection, Id.comparator_witness) Map.t
  }
type side = Source | Destination
type error =
  | Repeated_event of { event : Id.t; first_position : int; position : int }
  | Correction_mentions_event of { event : Id.t; position : int }
  | Unknown_event of { event : Id.t; position : int }
  | Missing_effect of { event : Id.t; side : side; key : D.Identifier.Effect_key.t; position : int }
  | Same_measure of { event : Id.t; measure : D.Identifier.Measure.t; position : int }
  | Source_not_negative of { event : Id.t; quantity : Q.t; position : int }
  | Destination_not_positive of { event : Id.t; quantity : Q.t; position : int }
  | Third_measure of { event : Id.t; effect_position : int; measure : D.Identifier.Measure.t; position : int }
  | Source_total_not_negative of { event : Id.t; measure : D.Identifier.Measure.t; total : Q.t; position : int }
  | Destination_total_not_positive of { event : Id.t; measure : D.Identifier.Measure.t; total : Q.t; position : int }

let qualify events mentioned position ({ event = id; source; destination } as fact) =
  let ( let* ) result f = Result.bind result ~f in
  let* () = if Set.mem mentioned id then Error (Correction_mentions_event { event = id; position }) else Ok () in
  let* event = match D.Event_memory.find_by_id events id with
    | None -> Error (Unknown_event { event = id; position })
    | Some event -> Ok event in
  let changes = D.Event.effects event in
  let find side key =
    match List.find changes ~f:(fun change -> Option.equal D.Identifier.Effect_key.equal (D.Effect.key change) (Some key)) with
    | None -> Error (Missing_effect { event = id; side; key; position })
    | Some change -> Ok change in
  let* source_effect = find Source source in
  let* destination_effect = find Destination destination in
  let source_measure = D.Effect.measure source_effect and destination_measure = D.Effect.measure destination_effect in
  let source_quantity = D.Effect.quantity source_effect and destination_quantity = D.Effect.quantity destination_effect in
  if D.Identifier.Measure.equal source_measure destination_measure
  then Error (Same_measure { event = id; measure = source_measure; position })
  else if Q.compare source_quantity Q.zero >= 0
  then Error (Source_not_negative { event = id; quantity = source_quantity; position })
  else if Q.compare destination_quantity Q.zero <= 0
  then Error (Destination_not_positive { event = id; quantity = destination_quantity; position })
  else
    match List.findi changes ~f:(fun _ change ->
      let measure = D.Effect.measure change in
      not (D.Identifier.Measure.equal measure source_measure || D.Identifier.Measure.equal measure destination_measure)) with
    | Some (index, change) ->
      Error (Third_measure { event = id; effect_position = index + 1; measure = D.Effect.measure change; position })
    | None ->
      let totals = List.fold changes ~init:Measure_totals.empty ~f:Measure_totals.add in
      let source_total = Measure_totals.at totals source_measure and destination_total = Measure_totals.at totals destination_measure in
      if Q.compare source_total Q.zero >= 0
      then Error (Source_total_not_negative { event = id; measure = source_measure; total = source_total; position })
      else if Q.compare destination_total Q.zero <= 0
      then Error (Destination_total_not_positive { event = id; measure = destination_measure; total = destination_total; position })
      else Ok { fact; event; source_effect; destination_effect }
;;

let create ~events ~corrections ~facts =
  let mentioned =
    List.fold corrections ~init:(Set.empty (module Id))
      ~f:(fun ids ({ target; replacement } : D.Event_correction.t) -> Set.add (Set.add ids target) replacement)
  in
  match
    List.fold_result facts ~init:(1, Map.empty (module Id))
      ~f:(fun (position, seen) (fact : fact) ->
        match Map.find seen fact.event with
        | Some (first_position, _) -> Error (Repeated_event { event = fact.event; first_position; position })
        | None ->
          Result.map (qualify events mentioned position fact) ~f:(fun selected ->
            position + 1, Map.set seen ~key:fact.event ~data:(position, selected)))
  with
  | Error error -> Error error
  | Ok (_, by_event) -> Ok { events; corrections; facts; by_event }
;;

let source_events t = t.events
let corrections t = t.corrections
let facts t = t.facts
let find_by_event t id = Option.map (Map.find t.by_event id) ~f:snd
let fact (selection : selection) = selection.fact
let event (selection : selection) = selection.event
let source_effect selection = selection.source_effect
let destination_effect selection = selection.destination_effect
