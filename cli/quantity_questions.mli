type t
(** Nonempty ordered coordinate questions, including duplicates. Terminal-only shared
    mechanism for the text and scoped LOAM commands, not a shared household command bus. *)

type error = Missing_pair | Empty_identity

val plan : string list -> (t, error) result
(** Qualify ALL coordinate pairs before shell acquisition. Exact identities, no trimming,
    deduplication, file I/O, source interpretation or quantity support inference. *)

val render :
  t ->
  explain:bool ->
  exact_heading:string ->
  Bakhlo_application.Current_quantity_query.t ->
  Response.t
(** Query the SAME already-admitted image once per question and retain each outcome in
    terminal output, in order. No subtotal, reread, re-admission or partial-source salvage.
    Exit 3 if any unsupported, otherwise 4 if any known-present, otherwise 0.
    Single non-explained questions retain the existing text/stream behavior. *)
