(** Ordinary + narrowly qualified Exchange/Reversal Actual subset, NOT full
    normalized household admission or authority. Caller supplies key-qualified Events,
    date history, Event corrections, optional descriptions/Merchant dispositions/root
    original amounts, explicit Exchange selections, Reversal correspondences and
    directional Effect-backed relation units. No discharge/remaining amounts,
    settlement, relation completeness or other structured metadata admission.
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
  ; exchanges : Exchange_evidence.fact list
  ; reversals : Actual_reversals.fact list
  ; relations : Open_relations.fact list
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
  | Exchanges of Exchange_evidence.error
  | Reversals of Actual_reversals.error
  | Relations of Open_relations.error

(** Event constructors already establish local key uniqueness. Within this boundary,
    Event identity first; then whole Exchange selection admission against retained
    memory/raw corrections; then whole exact physical Reversal admission. Next, in
    retained Event order, ALL Effects nonzero in occurrence order. Every Event conserves
    every Measure except qualified Exchange subjects and admitted reversal sides.
    Ordinary targets are checked independently (disjoint roles); qualified Exchange
    targets justify cross-Measure shape. Exact inversion derives ordinary reversal
    balance, or admits the inverse of a qualified Exchange as a Reversal exception
    (NOT per-Measure conservation). Never infer target qualification backwards.
    Reversal-side Exchange claims cannot rescue an unbalanced unclaimed target. Residual diagnostics use exact Measure spelling.
    Invalid claims preempt physical errors; with no claims, prior ordinary order survives.
    No Exchange correction participation. Reversal alone does not alter Event selection:
    non-Exchange-subject endpoints may have separate corrections; evidence stays
    about retained endpoints. Cancellation requires both original Events remain selected.
    Every retained Event, including superseded ones, is checked. Empty/independently
    balanced mixed-Measure Events still pass without claims: no Movement coercion.
    Then validity history/current completeness, Event corrections, descriptions and
    Merchant dispositions against ALL retained Events, in that order; then positive
    original amounts against stable roots in this same frontier; finally whole
    directional relation admission against retained keyed Effects, including
    superseded ones. Distinct relation identity, positive individual quantities
    and aggregate source-magnitude bounds, not sign-derived debtor/creditor roles.
    No current/root restriction or correction/Reversal retargeting; relations do
    not change physical balance, selection or support. No remaining-debt inference.
    Missing descriptions/dispositions/amounts are allowed; absent relation units remain
    unresolved, not known-none. No inference from other families.
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
val exchanges : t -> Exchange_evidence.t
val reversals : t -> Actual_reversals.t
val relations : t -> Open_relations.t
