(** Private exact per-Measure Effect sums, never support or conversion evidence.
    Mechanical exact-spelling order owns ordinary residual diagnostic order. *)
type t
val empty : t
val add : t -> Bakhlo_domain.Effect.t -> t

(** Mathematical empty sum is zero; this does not establish external known quantity. *)
val at : t -> Bakhlo_domain.Identifier.Measure.t -> Bakhlo_domain.Quantity.t
val first_nonzero : t -> (Bakhlo_domain.Identifier.Measure.t * Bakhlo_domain.Quantity.t) option
