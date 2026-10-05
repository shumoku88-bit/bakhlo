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

(** Role-free external identity, not a display name, catalog entry, merchant,
    payee, creditor or Locus. Relations supply meaning; tokens never infer roles. *)
module External_party : sig
  type t

  val of_string : string -> (t, error) result
  val to_string : t -> string
  val equal : t -> t -> bool
end

(** Opaque identity scoped within an Event, only when independently referenced.
    Not a coordinate/list position, globally unique identity or allocated default. *)
module Effect_key : sig
  type t

  val of_string : string -> (t, error) result
  val to_string : t -> string
  val equal : t -> t -> bool
  val compare : t -> t -> int

  include Base.Comparator.S with type t := t
end

(** Independent relation-unit identity, not Event, Effect key, endpoint pair or
    scalar. Equal fields can belong to distinct units. No registry/allocation. *)
module Relation : sig
  type t

  val of_string : string -> (t, error) result
  val to_string : t -> string
  val equal : t -> t -> bool
  val compare : t -> t -> int

  include Base.Comparator.S with type t := t
end

(** Identity of a supplied later Actual occurrence-date claim, not an Event,
    Effect key, base-date identity or timestamp. No revision identity allocation. *)
module Validity_revision : sig
  type t

  val of_string : string -> (t, error) result
  val to_string : t -> string
  val equal : t -> t -> bool
  val compare : t -> t -> int

  include Base.Comparator.S with type t := t
end

(** Caller-supplied observation identity, distinct from the other identity roles.
    No allocation or temporal/kind/revision meaning is inferred from the token. *)
module Event : sig
  type t

  val of_string : string -> (t, error) result
  val to_string : t -> string
  val equal : t -> t -> bool

  val compare : t -> t -> int
  (** Mechanical exact-spelling order for immutable memory indexing, not authority. *)

  include Base.Comparator.S with type t := t
end
