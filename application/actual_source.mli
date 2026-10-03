(** Ordinary anonymous/base-validity Actual subset, NOT full normalized household
    admission or authority. Caller supplies only Events, base validity and corrections;
    no keyed Effects, metadata, validity revisions, Exchange/Reversal or settlement
    admission. The synthetic adapter must reject unsupported evidence, never erase it.
    Domain Event stays general; this is a separate practical admission boundary. *)
type command =
  { events : Loam_domain.Event.t list
  ; validities : Actual_validity.fact list
  ; corrections : Loam_domain.Event_correction.t list
  }
type t
type error =
  | Events of Loam_domain.Event_memory.error
  | Zero_effect of
      { event : Loam_domain.Identifier.Event.t; event_position : int; effect_position : int }
  | Unbalanced_measure of
      { event : Loam_domain.Identifier.Event.t; event_position : int
      ; measure : Loam_domain.Identifier.Measure.t; residual : Loam_domain.Quantity.t }
  | Validity of Actual_validity.error
  | Corrections of Correction_frontier.error

(** Event identity first; then in retained Event order, nonzero Effects in occurrence
    order and exact totals per Measure (diagnostic order is exact Measure spelling).
    Every retained Event, including superseded ones, is checked. Empty Events and
    independently balanced mixed-Measure Events pass: no Movement coercion.
    Then base validity and correction admission. All positions one-based.
    This establishes structural premises only, not factual truth/completeness. *)
val create : command -> (t, error) result
val frontier : t -> Correction_frontier.t
val validity : t -> Actual_validity.t
