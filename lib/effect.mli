(** A neutral signed change. Movement-specific rules do not apply to every Effect. *)
type t

val create
  :  locus:Identifier.Locus.t
  -> measure:Identifier.Measure.t
  -> quantity:Quantity.t
  -> t

val locus : t -> Identifier.Locus.t
val measure : t -> Identifier.Measure.t
val quantity : t -> Quantity.t
