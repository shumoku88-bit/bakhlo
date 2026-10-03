(** Private exact per-Measure Effect sums, never support or conversion evidence.
    Mechanical exact-spelling order owns ordinary residual diagnostic order. *)
type t
val empty : t
val add : t -> Loam_domain.Effect.t -> t

(** Mathematical empty sum is zero; this does not establish external known quantity. *)
val at : t -> Loam_domain.Identifier.Measure.t -> Loam_domain.Quantity.t
val first_nonzero : t -> (Loam_domain.Identifier.Measure.t * Loam_domain.Quantity.t) option
