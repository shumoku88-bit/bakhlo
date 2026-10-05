(** Independent positive presented/charged amounts, not Event Effects, valuation,
    exchange rates, acquisition/tax basis, gains or quantity/presence support.
    Facts address stable correction roots; projections never rewrite those facts. *)
type fact =
  { root : Bakhlo_domain.Identifier.Event.t
  ; measure : Bakhlo_domain.Identifier.Measure.t
  ; quantity : Bakhlo_domain.Quantity.t
  }
type t

type error =
  | Repeated_root of
      { root : Bakhlo_domain.Identifier.Event.t; first_position : int; position : int }
  | Nonpositive_quantity of
      { root : Bakhlo_domain.Identifier.Event.t; quantity : Bakhlo_domain.Quantity.t; position : int }
  | Unknown_event of { root : Bakhlo_domain.Identifier.Event.t; position : int }
  | Not_root of { root : Bakhlo_domain.Identifier.Event.t; position : int }

(** Against ONE qualified frontier. Per declaration: duplicate, positivity, retained
    membership, root membership; first failure, one-based positions. Identical duplicates
    refuse. Partial/empty evidence is valid; Measures need not occur in Event Effects.
    No completeness, external truth or permission to record/publish is established. *)
val create : frontier:Correction_frontier.t -> facts:fact list -> (t, error) result
val source_frontier : t -> Correction_frontier.t
val facts : t -> fact list

(** One derived association of a retained root fact and its exact current terminal.
    Unforgeable through the public API; no new scalar or rewritten subject. *)
type current
val currents : t -> current list
val retained_fact : current -> fact
val terminal_event : current -> Bakhlo_domain.Event.t

(** Original fact order in [currents], not Event order/chronology. Exact terminal-ID
    lookup; absent/noncurrent IDs return None, never inferred zero or stale associations.
    A fresh tail requires explicit requalification; it preserves facts, not old terminals. *)
val find_current : t -> Bakhlo_domain.Identifier.Event.t -> current option
