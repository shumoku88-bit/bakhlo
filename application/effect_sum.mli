type t
(** Private arithmetic mechanism for the zero-origin and current-assertion
    projections. No evidence/support/admission authority or public balance API. *)

val empty : t
val add_effects : t -> Bakhlo_domain.Effect.t list -> t

val at : t -> Bakhlo_domain.Effect_coordinate.t -> Bakhlo_domain.Quantity.t
(** Mathematical zero for an absent coordinate. Consumers MUST establish their
    independent support gate before exposing this as a quantity answer. *)
