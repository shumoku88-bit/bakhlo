module Id = Identifier.Event

type t = { events : Event.t list; by_id : (Id.t, int * Event.t, Id.comparator_witness) Base.Map.t }
type error = Duplicate_id of { id : Id.t; first_position : int; position : int }

let of_events events =
  match
    Base.List.fold_result events
      ~init:(1, Base.Map.empty (module Id))
      ~f:(fun (position, by_id) event ->
        let id = Event.id event in
        match Base.Map.find by_id id with
        | Some (first_position, _) -> Error (Duplicate_id { id; first_position; position })
        | None -> Ok (position + 1, Base.Map.set by_id ~key:id ~data:(position, event)))
  with
  | Error error -> Error error
  | Ok (_, by_id) -> Ok { events; by_id }

let events memory = memory.events

let find_by_id memory id =
  match Base.Map.find memory.by_id id with None -> None | Some (_, event) -> Some event
