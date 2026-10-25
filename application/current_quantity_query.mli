type opening = {
  coordinate : Bakhlo_domain.Effect_coordinate.t;
  opening_event : Bakhlo_domain.Identifier.Event.t;
}
(** Three separated support families over ONE admitted Actual subset source.
    Not full normalized admission, historical completeness or household authority. *)

type t

type error =
  | Zero_origins of Bakhlo_domain.Zero_origin_coverage.error
  | Duplicate_opening_coordinate of {
      coordinate : Bakhlo_domain.Effect_coordinate.t;
      first_position : int;
      position : int;
    }
  | Opening_event_not_current of { opening : opening; position : int }
  | Opening_event_missing_coordinate of { opening : opening; position : int }
  | Groups of Current_quantity_groups.error
  | Opening_overlaps_origin of {
      coordinate : Bakhlo_domain.Effect_coordinate.t;
      opening_position : int;
    }
  | Assertion_overlaps_origin of {
      coordinate : Bakhlo_domain.Effect_coordinate.t;
      group_position : int;
      assertion_position : int;
    }
  | Assertion_overlaps_opening of {
      opening : opening;
      group_position : int;
      assertion_position : int;
    }

type unavailable = Support_unknown of { coordinate : Bakhlo_domain.Effect_coordinate.t }
type exact

type premise =
  | Zero_origin
  | Opening of opening
  | Current_assertion of Current_quantity_projection.answer

val create :
  source:Actual_source.t ->
  zero_origins:Bakhlo_domain.Effect_coordinate.t list ->
  openings:opening list ->
  groups:Current_quantity_groups.group list ->
  (t, error) result
(** Qualify origins, whole openings, then whole groups. Openings require unique
    coordinates (duplicate first), a CURRENT terminal Event and a matching Effect; never
    silently retarget superseded witnesses. Then scan opening/origin overlap and
    group/assertion overlap in declaration order. All positions one-based; global
    admission, no partial result or family priority, even for equal quantities.
    Origin/opening sum ALL qualified terminals, not just a witness; assertions keep their
    independent cuts. No inferred support, merged cuts, second opening scalar/date or
    separately bound source projections. *)

val source : t -> Actual_source.t
val zero_origins : t -> Bakhlo_domain.Effect_coordinate.t list
val openings : t -> opening list
val source_groups : t -> Current_quantity_groups.t

val with_added_effects : t -> Bakhlo_domain.Effect.t list -> t
(** Incrementally update exact totals with newly admitted terminal effects.
    Preserves exact coordinates, coverage, and premise indices without full rebuild. *)

val with_replaced_effects :
  t ->
  event:Bakhlo_domain.Identifier.Event.t ->
  old_effects:Bakhlo_domain.Effect.t list ->
  new_effects:Bakhlo_domain.Effect.t list ->
  t option
(** Exact update when an admitted root keeps its identity and only its Effects change.
    None when it cannot be exact without rebuilding: the root witnesses an opening. The caller must
    have re-admitted the changed Event locally; [source] is NOT rebuilt. *)

val reobserve_in_place :
  t ->
  reflected_roots:Bakhlo_domain.Identifier.Event.t list ->
  is_reflected:(Bakhlo_domain.Identifier.Event.t -> bool) ->
  Current_quantity_projection.assertion list ->
  (t, error) result
(** Replace the asserted coordinates with one new group reflecting every admitted
    root ([reflected_roots], in admission order, with membership [is_reflected]),
    rechecking the support separations of [create] for them. The caller guarantees
    those are exactly its admitted roots; [source] is NOT rebuilt. *)

val query : t -> Bakhlo_domain.Effect_coordinate.t -> (exact, unavailable) result
(** Indexed lookup of the exact current quantity. Stale/absent support remains unknown,
    never zero; no traversal, chronology or I/O. *)

val coordinate : exact -> Bakhlo_domain.Effect_coordinate.t
val quantity : exact -> Bakhlo_domain.Quantity.t
val premise : exact -> premise
