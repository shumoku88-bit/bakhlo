(** Private arithmetic mechanism for the zero-origin and current-assertion
    projections. No evidence/support/admission authority or public balance API. *)
type t

val empty : t
val add_effects : t -> Loam_domain.Effect.t list -> t

(** Mathematical zero for an absent coordinate. Consumers MUST establish their
    independent support gate before exposing this as a quantity answer. *)
val at : t -> Loam_domain.Effect_coordinate.t -> Loam_domain.Quantity.t
