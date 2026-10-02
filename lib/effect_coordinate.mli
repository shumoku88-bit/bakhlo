(** Neutral Locus x Measure coordinate for quantity queries and support evidence.
    Distinct identifier roles and exact spelling are retained. *)
type t =
  { locus : Identifier.Locus.t
  ; measure : Identifier.Measure.t
  }

val equal : t -> t -> bool

(** Mechanical lexicographic order by exact Locus then Measure spelling for
    Map/Set keys. Not temporal order, priority, valuation, or evidence order. *)
val compare : t -> t -> int

include Base.Comparator.S with type t := t
