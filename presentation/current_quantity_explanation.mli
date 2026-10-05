val explain :
  Bakhlo_application.Current_quantity_query.t ->
  Bakhlo_domain.Effect_coordinate.t ->
  ( Bakhlo_application.Current_quantity_query.outcome,
    Bakhlo_application.Current_quantity_query.unavailable )
  result
  * string
(** Terminal-only evidence view, not a new shared answer ontology or authority.
    Queries one immutable admitted image and returns its EXISTING typed outcome
    alongside rendering. No revalidation, file I/O, clock, support inference or
    authoritative recomputation; explanation traversals are additional to lookup. *)
