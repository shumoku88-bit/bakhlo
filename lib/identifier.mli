(** Distinct opaque identities, not household catalogs or display labels.
    Only empty strings are rejected. Preserve exact bytes: no case folding,
    trimming, aliasing, or inferred membership. Adapters own safe representation. *)

type error = Empty

module Measure : sig
  type t

  val of_string : string -> (t, error) result
  val to_string : t -> string
  val equal : t -> t -> bool
end

module Locus : sig
  type t

  val of_string : string -> (t, error) result
  val to_string : t -> string
  val equal : t -> t -> bool
end

(** Caller-supplied observation identity, distinct from Measure/Locus. No identity
    allocation or temporal/kind/revision meaning is inferred from the token. *)
module Event : sig
  type t

  val of_string : string -> (t, error) result
  val to_string : t -> string
  val equal : t -> t -> bool

  (** Mechanical exact-spelling order for immutable memory indexing, not authority. *)
  val compare : t -> t -> int

  include Base.Comparator.S with type t := t
end
