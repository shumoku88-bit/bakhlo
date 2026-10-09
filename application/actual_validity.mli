(** Independent retained Actual occurrence-date claims and corrections, not Event
    corrections, recording timestamps, historical completeness or factual truth.
    Practical ISO validation applies to ALL retained dates, even superseded ones. *)
type reference =
  | Base_ref of Bakhlo_domain.Identifier.Event.t
  | Revision_ref of Bakhlo_domain.Identifier.Validity_revision.t

type fact =
  | Base of { event : Bakhlo_domain.Identifier.Event.t; valid_on : string }
  | Revision of {
      id : Bakhlo_domain.Identifier.Validity_revision.t;
      event : Bakhlo_domain.Identifier.Event.t;
      valid_on : string;
    }

type correction = { target : reference; replacement : Bakhlo_domain.Identifier.Validity_revision.t }
type endpoint = Target of reference | Replacement of Bakhlo_domain.Identifier.Validity_revision.t
type t

type error =
  | Invalid_date of { position : int; text : string }
  | Repeated_fact of { reference : reference; first_position : int; position : int }
  | Unknown_validity_event of { event : Bakhlo_domain.Identifier.Event.t; position : int }
  | Unresolved_correction of { position : int; endpoints : endpoint list }
  | Cross_event_correction of {
      position : int;
      target_event : Bakhlo_domain.Identifier.Event.t;
      replacement_event : Bakhlo_domain.Identifier.Event.t;
    }
  | Repeated_target of { reference : reference; first_position : int; position : int }
  | Repeated_replacement of {
      id : Bakhlo_domain.Identifier.Validity_revision.t;
      first_position : int;
      position : int;
    }
  | Cycle of { path : reference list }
  | Repeated_current_validity of {
      event : Bakhlo_domain.Identifier.Event.t;
      first_position : int;
      position : int;
    }
  | Missing_validity of { event : Bakhlo_domain.Identifier.Event.t }

val valid_date : string -> bool
(** The same strict real YYYY-MM-DD predicate used by [create].
    Validating a standalone proposed date needs no dummy Event or correction
    history; complete history/source admission still runs for retained facts. *)

val reference : fact -> reference
val event : fact -> Bakhlo_domain.Identifier.Event.t
val valid_on : fact -> string

val create :
  events:Bakhlo_domain.Event_memory.t ->
  facts:fact list ->
  corrections:correction list ->
  (t, error) result
(** Per retained fact: real ISO date, tagged-reference uniqueness, Event closure.
    Per correction: ordered missing endpoints, same Event, target/replacement uniqueness.
    Cycles last; then current terminal uniqueness (positions in ORIGINAL fact list) and
    retained-Event-order completeness. Closed disjoint same-Event paths; all positions
    one-based. Base/revision with the same token are distinct. No list/date winner,
    trimming, inferred base/identity/date or partial result. Revision-only paths are
    allowed if one current fact per retained Event is established. *)

val source_events : t -> Bakhlo_domain.Event_memory.t
val facts : t -> fact list
val corrections : t -> correction list

val current_facts : t -> fact list
(** Current facts keep their original base/revision reference and representation order;
    superseded facts remain available via [facts]. Exact retained-ID lookup is indexed. *)

val find_current : t -> Bakhlo_domain.Identifier.Event.t -> fact option
