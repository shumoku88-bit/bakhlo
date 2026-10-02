(** Conditional arithmetic over supplied structurally validated Movements.
    NOT current/historical Actual admission, correction resolution, temporal
    completeness, purchasing power, or publication. See BALANCE_SLICE.md. *)

type t

(** Build an immutable coordinate index once. Every represented occurrence counts;
    no Event identity/deduplication, chronology, or zero-origin inference.
    Coverage is an independent premise, not derived from activity. *)
val create
  :  movements:Loam_domain.Movement.t list
  -> coverage:Loam_domain.Zero_origin_coverage.t
  -> t

(** Exact quantity conditional on the supplied basis and declared zero origin.
    This is not authoritative current household evidence. *)
type answer

type unavailable = Origin_unknown of { coordinate : Loam_domain.Effect_coordinate.t }

(** Coverage gate and indexed lookup only; no rebuilding/scanning the basis,
    formatting, clock, I/O, randomness, or mutable query state. *)
val query : t -> Loam_domain.Effect_coordinate.t -> (answer, unavailable) result

val coordinate : answer -> Loam_domain.Effect_coordinate.t
val quantity : answer -> Loam_domain.Quantity.t
