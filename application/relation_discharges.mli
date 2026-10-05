(** Closed read-side exact fulfillment provenance. No crash-residue activation,
    publication/recovery protocol, discharge ID, calendar ordering or physical inference. *)
type fact =
  { event : Bakhlo_domain.Identifier.Event.t
  ; target : Bakhlo_domain.Identifier.Relation.t
  ; quantity : Bakhlo_domain.Quantity.t
  }
type error =
  | Unknown_event of { event : Bakhlo_domain.Identifier.Event.t; position : int }
  | Unknown_target of { target : Bakhlo_domain.Identifier.Relation.t; position : int }
  | Repeated_correspondence of
      { event : Bakhlo_domain.Identifier.Event.t; target : Bakhlo_domain.Identifier.Relation.t
      ; first_position : int; position : int }
  | Self_discharge of
      { event : Bakhlo_domain.Identifier.Event.t; target : Bakhlo_domain.Identifier.Relation.t; position : int }
  | Nonpositive_quantity of
      { event : Bakhlo_domain.Identifier.Event.t; target : Bakhlo_domain.Identifier.Relation.t
      ; quantity : Bakhlo_domain.Quantity.t; position : int }
  | Exceeds_target of
      { event : Bakhlo_domain.Identifier.Event.t; target : Bakhlo_domain.Identifier.Relation.t
      ; quantity : Bakhlo_domain.Quantity.t; target_quantity : Bakhlo_domain.Quantity.t; position : int }
  | Overdischarged_target of
      { target : Bakhlo_domain.Identifier.Relation.t; total : Bakhlo_domain.Quantity.t
      ; target_quantity : Bakhlo_domain.Quantity.t; position : int }
type t
type admitted
type remainder

(** Derive Events/targets ONLY from this opaque relation image: no mixed generation.
    Per declaration: Event closure -> target closure -> pair duplicate (even identical)
    -> Event differs from target source Event -> positive -> <= target quantity.
    Then full positive total per target <= target quantity; first original discharge
    position for an over-discharged target. One Event may fulfill distinct targets;
    no invented global Event budget/Effect matching, Measure duplication or chronology.
    ALL rows must resolve; unlike upstream target-local crash projection, missing
    Events are refused, not inactive. No correction/Reversal retargeting/deactivation.
    Raw facts/order/exact Event/target/source survive; positions one-based.
    Actual_source additionally admits physical/date/correction premises. *)
val create : relations:Open_relations.t -> facts:fact list -> (t, error) result
val source_relations : t -> Open_relations.t
val facts : t -> fact list
val admitted : t -> admitted list
val fact : admitted -> fact
val event : admitted -> Bakhlo_domain.Event.t
val target_relation : admitted -> Open_relations.admitted

(** Snapshot projections in original relation declaration order, not canonical state.
    Known target with no supplied discharges retains its initial quantity; unknown
    identity is None, never zero. NOT a claim of complete real-world fulfillment,
    household authority, physical balance support or permission to record/spend. *)
val remainders : t -> remainder list
val find_remainder : t -> Bakhlo_domain.Identifier.Relation.t -> remainder option
val relation : remainder -> Open_relations.admitted
val discharges : remainder -> admitted list
val discharged_quantity : remainder -> Bakhlo_domain.Quantity.t

(** Original relation quantity minus supplied admitted discharge total. Nonnegative
    by admission; Measure inherited from relation source Effect, not discharge Event. *)
val remaining_quantity : remainder -> Bakhlo_domain.Quantity.t
