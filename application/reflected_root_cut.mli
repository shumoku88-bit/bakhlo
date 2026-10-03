(** Conditional whole-lineage exclusion bound to one qualified supplied frontier.
    Reflected IDs are independent caller declarations, not inferred from activity,
    dates, terminal spelling, or a balance. No current Actual/write authority. *)
type t

type error =
  | Duplicate_root of
      { id : Loam_domain.Identifier.Event.t
      ; first_position : int
      ; position : int
      }
  | Unknown_event of
      { id : Loam_domain.Identifier.Event.t
      ; position : int
      }
  | Not_root of
      { id : Loam_domain.Identifier.Event.t
      ; position : int
      }

(** Scan declarations in order, positions one-based: duplicate of an earlier
    accepted ID first; otherwise require a represented root. Absent IDs refuse as
    [Unknown_event]; represented replacements refuse as [Not_root]. No partial
    successful answer, ignored reference, or deduplication. Empty declarations
    exclude nothing; empty source/declarations are valid explicit input only. *)
val create
  :  frontier:Correction_frontier.t
  -> reflected_roots:Loam_domain.Identifier.Event.t list
  -> (t, error) result

(** Original immutable source, retaining all Events and correction facts. The cut
    cannot be implicitly applied to a different frontier. To reuse declarations,
    call [create] against that frontier and recheck root membership. *)
val source_frontier : t -> Correction_frontier.t

(** Exact supplied declarations in original order, unmodified. *)
val reflected_roots : t -> Loam_domain.Identifier.Event.t list

(** Materialized unreflected rows in original root-Event order. May differ from
    [Correction_frontier.frontier_events] order even for empty declarations.
    Reflected lineages are omitted from this view, never from the source facts. *)
val remaining_lineages : t -> Correction_frontier.lineage list

(** Exact retained terminal Events of [remaining_lineages], in the same order.
    General Event payloads are not narrowed to Movement or arithmetically altered.
    Getter performs no revalidation, graph traversal, or source reconstruction. *)
val remaining_events : t -> Loam_domain.Event.t list
