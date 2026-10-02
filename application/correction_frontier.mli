(** Disjoint-path frontier conditional on one supplied Event memory and relation.
    NOT current Actual, source completeness, relation truth, chronology, or write
    permission. Original observations and edges are retained; no apply operation. *)
type t

type error =
  | Unresolved_correction of
      { position : int
      ; errors : Correction_check.error list
      }
  | Repeated_target of
      { id : Loam_domain.Identifier.Event.t
      ; first_position : int
      ; position : int
      }
  | Repeated_replacement of
      { id : Loam_domain.Identifier.Event.t
      ; first_position : int
      ; position : int
      }
  | Cycle of { path : Loam_domain.Identifier.Event.t list }

(** All endpoints must exist, targets/replacements must each be unique, and the
    relation must be acyclic. An identical repeated edge is refused, not deduped.
    Empty corrections preserve all explicitly supplied Events, never a failed
    loader fallback. Fail fast: edge order, closure then target then replacement
    uniqueness; cycles checked last. Missing-role errors are nonempty/ordered.
    Cycle path follows actual edges and repeats its first ID at the end. *)
val create
  :  events:Loam_domain.Event_memory.t
  -> corrections:Loam_domain.Event_correction.t list
  -> (t, error) result

val retained_events : t -> Loam_domain.Event_memory.t
val corrections : t -> Loam_domain.Event_correction.t list

(** Exactly supplied Events not targeted by any correction, in original Event
    order, with unmodified payloads. Validated within the supplied scope only. *)
val frontier_events : t -> Loam_domain.Event.t list
