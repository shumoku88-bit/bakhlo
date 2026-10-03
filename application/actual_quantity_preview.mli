(** Read-only synthetic Actual subset: independent base occurrence validity,
    one retained source/frontier, exact assertion groups. Not normalized household
    Actual admission: no household nonzero/per-Measure balance policy, validity
    revisions, exchange/reversal/description or other support families, history
    completeness or authority claim. General Events stay neutral. *)
type validity = Actual_validity.fact = { event : Loam_domain.Identifier.Event.t; valid_on : string }
type command =
  { events : Loam_domain.Event.t list
  ; validities : validity list
  ; corrections : Loam_domain.Event_correction.t list
  ; groups : Current_quantity_groups.group list
  }
type t

type error =
  | Events of Loam_domain.Event_memory.error
  | Invalid_date of { position : int; text : string }
  | Repeated_validity of
      { event : Loam_domain.Identifier.Event.t; first_position : int; position : int }
  | Unknown_validity_event of { event : Loam_domain.Identifier.Event.t; position : int }
  | Missing_validity of { event : Loam_domain.Identifier.Event.t }
  | Corrections of Correction_frontier.error
  | Groups of Current_quantity_groups.error

(** Order: Event identity, declaration-order real ISO date/duplicate/reference checks,
    Event-order completeness, correction admission, group admission. One base validity
    for EVERY retained Event, including superseded ones; dates are never chronology,
    winner or assertion cut. Explicit empty source is valid; load failure is not. *)
val run : command -> (t, error) result
val validities : t -> validity list
val source_groups : t -> Current_quantity_groups.t
val query
  : t -> Loam_domain.Effect_coordinate.t
  -> (Current_quantity_projection.answer, Current_quantity_projection.unavailable) result
