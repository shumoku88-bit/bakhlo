type group = {
  reflected_roots : Bakhlo_domain.Identifier.Event.t list;
  assertions : Current_quantity_projection.assertion list;
}
(** Multiple anonymous exact-assertion groups bound to ONE supplied qualified
    frontier. Different cuts stay independent; one live owner per coordinate.
    Not selected Actual, other support-family routing, history, or publication. *)

type t

type error =
  | Invalid_cut of { group_position : int; error : Reflected_root_cut.error }
  | Invalid_assertions of { group_position : int; error : Current_quantity_projection.error }
  | Repeated_coordinate of {
      coordinate : Bakhlo_domain.Effect_coordinate.t;
      first_group_position : int;
      first_assertion_position : int;
      group_position : int;
      assertion_position : int;
    }

val create : frontier:Correction_frontier.t -> groups:group list -> (t, error) result
(** In group order: whole cut check, whole local assertion check, then cross-group
    ownership scan in assertion order. Positions one-based; equal repeated groups
    also refuse. Root sets may overlap; coordinate owners may not. Empty groups
    still qualify their declared roots. Original facts/order are retained.
    Separately bound projection values cannot be passed as groups: every group
    is qualified against this SAME explicit frontier, with no snapshot heuristic. *)

val source_frontier : t -> Correction_frontier.t
val groups : t -> group list

val group_for : t -> Bakhlo_domain.Effect_coordinate.t -> Current_quantity_projection.t option
(** Unique already-qualified group; None means no exact assertion owner. *)

val query :
  t ->
  Bakhlo_domain.Effect_coordinate.t ->
  (Current_quantity_projection.answer, Current_quantity_projection.unavailable) result
(** Indexed ownership then existing indexed quantity lookup. No root traversal,
    evidence reduction, arithmetic rebuild, mutable state or zero default. *)

val reobserve : t -> group -> (t, error) result
(** Explicit immutable re-observation on the SAME source. First qualify incoming
    (error group position 1); refuse BEFORE pruning old assertions. Remove only
    incoming coordinates from old groups, drop empty residual groups, preserve
    every surviving cut/assertion and their order, then append incoming. Untouched
    projections are reused; only reduced groups rebuild using the same cut.
    Empty incoming replaces no coordinate but still drops old empty groups and
    appends itself. Old image/source remain unchanged; no persisted history/write.
    This operation, not group list order in [create], intentionally replaces owners. *)
