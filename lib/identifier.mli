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
