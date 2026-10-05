module D = Bakhlo_domain

type endpoint = Target | Replacement

type error =
  | Missing_event of
      { endpoint : endpoint
      ; id : D.Identifier.Event.t
      }

type closed =
  { correction : D.Event_correction.t
  ; target_event : D.Event.t
  ; replacement_event : D.Event.t
  }

let run ~events ~(correction : D.Event_correction.t) =
  match
    D.Event_memory.find_by_id events correction.target,
    D.Event_memory.find_by_id events correction.replacement
  with
  | Some target_event, Some replacement_event ->
    Ok { correction; target_event; replacement_event }
  | None, Some _ -> Error [ Missing_event { endpoint = Target; id = correction.target } ]
  | Some _, None ->
    Error [ Missing_event { endpoint = Replacement; id = correction.replacement } ]
  | None, None ->
    Error
      [ Missing_event { endpoint = Target; id = correction.target }
      ; Missing_event { endpoint = Replacement; id = correction.replacement }
      ]
;;

let correction closed = closed.correction
let target_event closed = closed.target_event
let replacement_event closed = closed.replacement_event
