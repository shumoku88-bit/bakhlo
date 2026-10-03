open Base
module D = Loam_domain
module Id = D.Identifier.Event
module H = Current_quantity_groups

type validity = Actual_validity.fact = { event : Id.t; valid_on : string }
type command =
  { events : D.Event.t list
  ; validities : validity list
  ; corrections : D.Event_correction.t list
  ; groups : H.group list
  }
type t = { validities : validity list; source_groups : H.t }
type error =
  | Events of D.Event_memory.error
  | Invalid_date of { position : int; text : string }
  | Repeated_validity of { event : Id.t; first_position : int; position : int }
  | Unknown_validity_event of { event : Id.t; position : int }
  | Missing_validity of { event : Id.t }
  | Corrections of Correction_frontier.error
  | Groups of H.error

(* Preserve the legacy preview's error contract while sharing independent admission. *)
let validity_error = function
  | Actual_validity.Invalid_date { position; text } -> Invalid_date { position; text }
  | Repeated_validity { event; first_position; position } -> Repeated_validity { event; first_position; position }
  | Unknown_validity_event { event; position } -> Unknown_validity_event { event; position }
  | Missing_validity { event } -> Missing_validity { event }
;;

let run (command : command) =
  let ( let* ) result f = Result.bind result ~f in
  let* events = Result.map_error (D.Event_memory.of_events command.events) ~f:(fun error -> Events error) in
  let* validity = Result.map_error (Actual_validity.create ~events ~facts:command.validities) ~f:validity_error in
  let* frontier = Result.map_error (Correction_frontier.create ~events ~corrections:command.corrections)
      ~f:(fun error -> Corrections error) in
  let* source_groups = Result.map_error (H.create ~frontier ~groups:command.groups) ~f:(fun error -> Groups error) in
  Ok { validities = Actual_validity.facts validity; source_groups }
;;
let validities t = t.validities
let source_groups t = t.source_groups
let query t coordinate = H.query t.source_groups coordinate
