type t = { locus : Identifier.Locus.t; measure : Identifier.Measure.t }
(** Neutral Locus x Measure coordinate for quantity queries and support evidence.
    Distinct identifier roles and exact spelling are retained. *)

val equal : t -> t -> bool

val compare : t -> t -> int
(** Mechanical lexicographic order by exact Locus then Measure spelling for
    Map/Set keys. Not temporal order, priority, valuation, or evidence order. *)

include Base.Comparator.S with type t := t
