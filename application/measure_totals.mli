type t
(** Private exact per-Measure Effect sums, never support or conversion evidence.
    Mechanical exact-spelling order owns ordinary residual diagnostic order. *)

val empty : t
val add : t -> Bakhlo_domain.Effect.t -> t

val at : t -> Bakhlo_domain.Identifier.Measure.t -> Bakhlo_domain.Quantity.t
(** Mathematical empty sum is zero; this does not establish external known quantity. *)

val first_nonzero : t -> (Bakhlo_domain.Identifier.Measure.t * Bakhlo_domain.Quantity.t) option
