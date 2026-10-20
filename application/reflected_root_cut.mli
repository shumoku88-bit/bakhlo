type t
(** Conditional whole-lineage exclusion bound to one qualified supplied frontier.
    Reflected IDs are independent caller declarations, not inferred from activity,
    dates, terminal spelling, or a balance. No current Actual/write authority. *)

type error =
  | Duplicate_root of {
      id : Bakhlo_domain.Identifier.Event.t;
      first_position : int;
      position : int;
    }
  | Unknown_event of { id : Bakhlo_domain.Identifier.Event.t; position : int }
  | Not_root of { id : Bakhlo_domain.Identifier.Event.t; position : int }

val create :
  frontier:Correction_frontier.t ->
  reflected_roots:Bakhlo_domain.Identifier.Event.t list ->
  (t, error) result
(** Scan declarations in order, positions one-based: duplicate of an earlier
    accepted ID first; otherwise require a represented root. Absent IDs refuse as
    [Unknown_event]; represented replacements refuse as [Not_root]. No partial
    successful answer, ignored reference, or deduplication. Empty declarations
    exclude nothing; empty source/declarations are valid explicit input only. *)

val source_frontier : t -> Correction_frontier.t
(** Original immutable source, retaining all Events and correction facts. The cut
    cannot be implicitly applied to a different frontier. To reuse declarations,
    call [create] against that frontier and recheck root membership. *)

val reflected_roots : t -> Bakhlo_domain.Identifier.Event.t list
(** Exact supplied declarations in original order, unmodified. *)

val is_reflected : t -> Bakhlo_domain.Identifier.Event.t -> bool
(** Indexed membership in the supplied declarations; no traversal. *)

val reflecting_all :
  frontier:Correction_frontier.t ->
  reflected_roots:Bakhlo_domain.Identifier.Event.t list ->
  is_reflected:(Bakhlo_domain.Identifier.Event.t -> bool) ->
  t
(** A cut reflecting every root the caller has admitted, so nothing remains. NOT
    checked against [frontier]: the caller guarantees [reflected_roots] are exactly
    its current admitted roots and [is_reflected] is their membership. [frontier]
    is provenance only and may predate in-place additions. *)

val remaining_lineages : t -> Correction_frontier.lineage list
(** Materialized unreflected rows in original root-Event order. May differ from
    [Correction_frontier.frontier_events] order even for empty declarations.
    Reflected lineages are omitted from this view, never from the source facts. *)

val remaining_events : t -> Bakhlo_domain.Event.t list
(** Exact retained terminal Events of [remaining_lineages], in the same order.
    General Event payloads are not narrowed to Movement or arithmetically altered.
    Getter performs no revalidation, graph traversal, or source reconstruction. *)
