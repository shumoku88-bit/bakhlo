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
      { id : Bakhlo_domain.Identifier.Event.t
      ; first_position : int
      ; position : int
      }
  | Repeated_replacement of
      { id : Bakhlo_domain.Identifier.Event.t
      ; first_position : int
      ; position : int
      }
  | Cycle of { path : Bakhlo_domain.Identifier.Event.t list }

(** All endpoints must exist, targets/replacements must each be unique, and the
    relation must be acyclic. An identical repeated edge is refused, not deduped.
    Empty corrections preserve all explicitly supplied Events, never a failed
    loader fallback. Fail fast: edge order, closure then target then replacement
    uniqueness; cycles checked last. Missing-role errors are nonempty/ordered.
    Cycle path follows actual edges and repeats its first ID at the end. *)
val create
  :  events:Bakhlo_domain.Event_memory.t
  -> corrections:Bakhlo_domain.Event_correction.t list
  -> (t, error) result

val retained_events : t -> Bakhlo_domain.Event_memory.t
val corrections : t -> Bakhlo_domain.Event_correction.t list

(** Exactly supplied Events not targeted by any correction, in original Event
    order, with unmodified payloads. Validated within the supplied scope only. *)
val frontier_events : t -> Bakhlo_domain.Event.t list

(** One qualified root/terminal association within the supplied relation.
    No public constructor can substitute unrelated observations. This is not
    occurrence time, root-cut evidence, global snapshot identity, or current Actual. *)
type lineage

(** Materialized once during successful [create]. Exactly one row per disjoint
    path, in original root-Event order (not necessarily [frontier_events] order).
    Untouched Events are singleton paths. All original observations/edges remain
    available through [retained_events]/[corrections]; no source is pruned. *)
val lineages : t -> lineage list

(** Original Event with no incoming correction. Stable under a fresh terminal
    extension, not arbitrary prefix insertion, deletion, or source-scope changes. *)
val root_id : lineage -> Bakhlo_domain.Identifier.Event.t

(** Exact retained Event reached from that root with no outgoing correction.
    Traversal follows explicit edges only, never spelling, time, or list position. *)
val terminal_event : lineage -> Bakhlo_domain.Event.t
