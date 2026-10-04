(** Retained directional relation units anchored to exact keyed Effects.
    Positive observed units, NOT remaining debt after fulfillment or completeness. *)
type endpoint = Household | External of Loam_domain.Identifier.External_party.t
type fact =
  { id : Loam_domain.Identifier.Relation.t
  ; source_event : Loam_domain.Identifier.Event.t
  ; source_effect : Loam_domain.Identifier.Effect_key.t
  ; debtor : endpoint
  ; creditor : endpoint
  ; quantity : Loam_domain.Quantity.t
  }
type error =
  | Repeated_id of
      { id : Loam_domain.Identifier.Relation.t; first_position : int; position : int }
  | Unknown_event of
      { id : Loam_domain.Identifier.Relation.t; event : Loam_domain.Identifier.Event.t; position : int }
  | Missing_effect of
      { id : Loam_domain.Identifier.Relation.t; event : Loam_domain.Identifier.Event.t
      ; key : Loam_domain.Identifier.Effect_key.t; position : int }
  | Invalid_endpoints of
      { id : Loam_domain.Identifier.Relation.t; debtor : endpoint; creditor : endpoint; position : int }
  | Nonpositive_quantity of
      { id : Loam_domain.Identifier.Relation.t; quantity : Loam_domain.Quantity.t; position : int }
  | Exceeds_source of
      { id : Loam_domain.Identifier.Relation.t; quantity : Loam_domain.Quantity.t
      ; magnitude : Loam_domain.Quantity.t; position : int }
  | Overcovered_source of
      { event : Loam_domain.Identifier.Event.t; key : Loam_domain.Identifier.Effect_key.t
      ; total : Loam_domain.Quantity.t; magnitude : Loam_domain.Quantity.t; position : int }
type t
type admitted

(** Whole ID uniqueness first. Then each declaration: retained Event -> keyed
    Effect -> exactly one Household/one External -> positive quantity -> individual
    quantity <= absolute source quantity. Finally aggregate ALL admitted units at
    exact (Event, key), regardless of party/direction, <= that same magnitude.
    Aggregate errors use full totals and first original declaration position at that
    source. Equal-field facts with distinct IDs remain independent; identical ID
    repeats refuse. Source sign has no debtor/creditor meaning. No Measure duplication:
    source Effect supplies it. Source/order/payloads preserved, positions one-based.
    No physical balance/nonzero/date/correction admission here; Actual_source owns it.
    Source need not be a current terminal/root; no correction/Reversal inheritance,
    retargeting, implicit fulfillment or quantity/presence support. *)
val create : events:Loam_domain.Event_memory.t -> facts:fact list -> (t, error) result
val source_events : t -> Loam_domain.Event_memory.t
val facts : t -> fact list
val admitted : t -> admitted list
val fact : admitted -> fact
val source_event : admitted -> Loam_domain.Event.t
val source_effect : admitted -> Loam_domain.Effect.t

(** Exact supplied identity lookup. None is unresolved/unsupplied, NOT known-none,
    zero, completeness or proof of no relation at a source. *)
val find_by_id : t -> Loam_domain.Identifier.Relation.t -> admitted option
