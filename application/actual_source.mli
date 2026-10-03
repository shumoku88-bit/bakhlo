(** Ordinary Actual subset, NOT full normalized household admission
    or authority. Caller supplies key-qualified Events, retained occurrence-date
    history, Event corrections, optional recognizer descriptions and Merchant
    dispositions and stable-root original amounts; no other structured metadata,
    Exchange/Reversal or settlement admission.
    The synthetic adapter must reject unsupported evidence, never erase it.
    Domain Event stays general; this is a separate practical admission boundary. *)
type command =
  { events : Loam_domain.Event.t list
  ; validities : Actual_validity.fact list
  ; validity_corrections : Actual_validity.correction list
  ; corrections : Loam_domain.Event_correction.t list
  ; descriptions : Event_descriptions.fact list
  ; merchants : Event_merchants.fact list
  ; original_amounts : Original_amounts.fact list
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
  | Descriptions of Event_descriptions.error
  | Merchants of Event_merchants.error
  | Original_amounts of Original_amounts.error

(** Event constructors already establish local key uniqueness. Within this boundary,
    Event identity first; then in retained Event order, nonzero Effects in occurrence
    order and exact totals per Measure (diagnostic order is exact Measure spelling).
    Every retained Event, including superseded ones, is checked. Empty Events and
    independently balanced mixed-Measure Events pass: no Movement coercion.
    Then validity history/current completeness, Event corrections, descriptions and
    Merchant dispositions against ALL retained Events, in that order; then positive
    original amounts against stable roots in this same frontier.
    Missing descriptions/dispositions/amounts are allowed; no inference from other families.
    Text/Merchant facts do not inherit. Amount facts keep roots; only their current
    terminal association is projected. None of these families creates quantity/presence support.
    All positions one-based.
    This establishes structural premises only, not factual truth/completeness. *)
val create : command -> (t, error) result
val frontier : t -> Correction_frontier.t
val validity : t -> Actual_validity.t
val descriptions : t -> Event_descriptions.t
val merchants : t -> Event_merchants.t
val original_amounts : t -> Original_amounts.t
