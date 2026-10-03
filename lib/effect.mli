(** A neutral signed change. [None] is anonymous, [Some key] retains independent
    identity. Keys do not change coordinates/quantities or imply role/order; Event
    admission owns within-Event uniqueness. No normalization or key allocation. *)
type t

val create
  :  key:Identifier.Effect_key.t option
  -> locus:Identifier.Locus.t
  -> measure:Identifier.Measure.t
  -> quantity:Quantity.t
  -> t

val key : t -> Identifier.Effect_key.t option
val locus : t -> Identifier.Locus.t
val measure : t -> Identifier.Measure.t
val quantity : t -> Quantity.t
