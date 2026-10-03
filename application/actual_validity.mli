(** Independent retained Actual occurrence-date claims and corrections, not Event
    corrections, recording timestamps, historical completeness or factual truth.
    Practical ISO validation applies to ALL retained dates, even superseded ones. *)
type reference =
  | Base_ref of Loam_domain.Identifier.Event.t
  | Revision_ref of Loam_domain.Identifier.Validity_revision.t
type fact =
  | Base of { event : Loam_domain.Identifier.Event.t; valid_on : string }
  | Revision of
      { id : Loam_domain.Identifier.Validity_revision.t
      ; event : Loam_domain.Identifier.Event.t; valid_on : string }
type correction = { target : reference; replacement : Loam_domain.Identifier.Validity_revision.t }
type endpoint = Target of reference | Replacement of Loam_domain.Identifier.Validity_revision.t
type t
type error =
  | Invalid_date of { position : int; text : string }
  | Repeated_fact of { reference : reference; first_position : int; position : int }
  | Unknown_validity_event of { event : Loam_domain.Identifier.Event.t; position : int }
  | Unresolved_correction of { position : int; endpoints : endpoint list }
  | Cross_event_correction of
      { position : int; target_event : Loam_domain.Identifier.Event.t
      ; replacement_event : Loam_domain.Identifier.Event.t }
  | Repeated_target of { reference : reference; first_position : int; position : int }
  | Repeated_replacement of
      { id : Loam_domain.Identifier.Validity_revision.t; first_position : int; position : int }
  | Cycle of { path : reference list }
  | Repeated_current_validity of
      { event : Loam_domain.Identifier.Event.t; first_position : int; position : int }
  | Missing_validity of { event : Loam_domain.Identifier.Event.t }

val reference : fact -> reference
val event : fact -> Loam_domain.Identifier.Event.t
val valid_on : fact -> string

(** Per retained fact: real ISO date, tagged-reference uniqueness, Event closure.
    Per correction: ordered missing endpoints, same Event, target/replacement uniqueness.
    Cycles last; then current terminal uniqueness (positions in ORIGINAL fact list) and
    retained-Event-order completeness. Closed disjoint same-Event paths; all positions
    one-based. Base/revision with the same token are distinct. No list/date winner,
    trimming, inferred base/identity/date or partial result. Revision-only paths are
    allowed if one current fact per retained Event is established. *)
val create
  : events:Loam_domain.Event_memory.t
  -> facts:fact list
  -> corrections:correction list
  -> (t, error) result
val source_events : t -> Loam_domain.Event_memory.t
val facts : t -> fact list
val corrections : t -> correction list

(** Current facts keep their original base/revision reference and representation order;
    superseded facts remain available via [facts]. Exact retained-ID lookup is indexed. *)
val current_facts : t -> fact list
val find_current : t -> Loam_domain.Identifier.Event.t -> fact option
