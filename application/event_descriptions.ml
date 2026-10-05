open Base
module D = Bakhlo_domain
module Id = D.Identifier.Event

type fact = { event : Id.t; text : string }
type t =
  { events : D.Event_memory.t
  ; facts : fact list
  ; by_event : (Id.t, int * string, Id.comparator_witness) Map.t
  }
type error =
  | Repeated_description of { event : Id.t; first_position : int; position : int }
  | Unknown_description_event of { event : Id.t; position : int }

let create ~events ~facts =
  match List.fold_result facts ~init:(1, Map.empty (module Id))
      ~f:(fun (position, seen) { event; text } ->
        match Map.find seen event with
        | Some (first_position, _) -> Error (Repeated_description { event; first_position; position })
        | None ->
          match D.Event_memory.find_by_id events event with
          | None -> Error (Unknown_description_event { event; position })
          | Some _ -> Ok (position + 1, Map.set seen ~key:event ~data:(position, text))) with
  | Error error -> Error error
  | Ok (_, by_event) -> Ok { events; facts; by_event }
;;
let source_events t = t.events
let facts t = t.facts
let find_text t event = Option.map (Map.find t.by_event event) ~f:snd
