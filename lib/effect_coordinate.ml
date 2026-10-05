module Key = struct
  type t = { locus : Identifier.Locus.t; measure : Identifier.Measure.t }

  let compare left right =
    let loci =
      Base.String.compare
        (Identifier.Locus.to_string left.locus)
        (Identifier.Locus.to_string right.locus)
    in
    if loci <> 0 then loci
    else
      Base.String.compare
        (Identifier.Measure.to_string left.measure)
        (Identifier.Measure.to_string right.measure)

  (* Required diagnostic representation for Base's comparator, not UI output. *)
  let sexp_of_t coordinate =
    Base.Sexp.List
      [
        Atom (Identifier.Locus.to_string coordinate.locus);
        Atom (Identifier.Measure.to_string coordinate.measure);
      ]
end

include Key
include Base.Comparator.Make (Key)

let equal left right =
  Identifier.Locus.equal left.locus right.locus
  && Identifier.Measure.equal left.measure right.measure
