(** One narrow effect-selected cross-Measure exchange claim per retained Event.
    Not a generic Event kind, FX rate, valuation, fee/basis/home-currency semantics
    or quantity/presence support. Keys are Event-local, never coordinates/positions. *)
type fact =
  { event : Loam_domain.Identifier.Event.t
  ; source : Loam_domain.Identifier.Effect_key.t
  ; destination : Loam_domain.Identifier.Effect_key.t
  }
type t
type side = Source | Destination
type error =
  | Repeated_event of
      { event : Loam_domain.Identifier.Event.t; first_position : int; position : int }
  | Correction_mentions_event of { event : Loam_domain.Identifier.Event.t; position : int }
  | Unknown_event of { event : Loam_domain.Identifier.Event.t; position : int }
  | Missing_effect of
      { event : Loam_domain.Identifier.Event.t; side : side
      ; key : Loam_domain.Identifier.Effect_key.t; position : int }
  | Same_measure of
      { event : Loam_domain.Identifier.Event.t; measure : Loam_domain.Identifier.Measure.t; position : int }
  | Source_not_negative of
      { event : Loam_domain.Identifier.Event.t; quantity : Loam_domain.Quantity.t; position : int }
  | Destination_not_positive of
      { event : Loam_domain.Identifier.Event.t; quantity : Loam_domain.Quantity.t; position : int }
  | Third_measure of
      { event : Loam_domain.Identifier.Event.t; effect_position : int
      ; measure : Loam_domain.Identifier.Measure.t; position : int }
  | Source_total_not_negative of
      { event : Loam_domain.Identifier.Event.t; measure : Loam_domain.Identifier.Measure.t
      ; total : Loam_domain.Quantity.t; position : int }
  | Destination_total_not_positive of
      { event : Loam_domain.Identifier.Event.t; measure : Loam_domain.Identifier.Measure.t
      ; total : Loam_domain.Quantity.t; position : int }

(** Per declaration: duplicate, any correction endpoint mentions, Event membership,
    source then destination key, distinct Measures, source negative, destination positive,
    no third Measure, source total negative, destination total positive. First failure,
    one-based fact/Effect positions; identical duplicate facts refuse.
    Extra keyed/anonymous Effects in either selected Measure retain multiplicity.
    This selection gate does NOT forbid unselected zero Effects; Actual source does.
    Raw corrections are retained/interference-checked, NOT graph-admitted by this boundary.
    Empty/partial claims valid; source remains general. No correction replacement,
    external truth, completeness, publication or implicit support is established. *)
val create
  :  events:Loam_domain.Event_memory.t
  -> corrections:Loam_domain.Event_correction.t list
  -> facts:fact list
  -> (t, error) result
val source_events : t -> Loam_domain.Event_memory.t
val corrections : t -> Loam_domain.Event_correction.t list
val facts : t -> fact list

type selection
val find_by_event : t -> Loam_domain.Identifier.Event.t -> selection option
val fact : selection -> fact
val event : selection -> Loam_domain.Event.t
val source_effect : selection -> Loam_domain.Effect.t
val destination_effect : selection -> Loam_domain.Effect.t
