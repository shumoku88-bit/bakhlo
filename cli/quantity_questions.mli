type t
(** Nonempty ordered coordinate questions, including duplicates. Terminal-only shared
    mechanism for the text and scoped LOAM commands, not a shared household command bus. *)

type error = Missing_pair | Empty_identity
type view = Inspect | Explain | Summary

val select_view : string list -> (view * string list, string) result
(** Consume at most ONE leading --explain/--summary. Conflicting/repeated views refuse
    before file acquisition; ordinary exact path/coordinate bytes are not normalized. *)

val plan : string list -> (t, error) result
(** Qualify ALL coordinate pairs before shell acquisition. Exact identities, no trimming,
    deduplication, file I/O, source interpretation or quantity support inference. *)

val render :
  t ->
  view:view ->
  exact_heading:string ->
  Bakhlo_application.Current_quantity_query.t ->
  Response.t
(** Query the SAME already-admitted image once per question and retain each outcome in
    terminal output, in order. No subtotal, reread, re-admission or partial-source salvage.
    Exit 3 if any unsupported, otherwise 4 if any known-present, otherwise 0.
    Inspect/Explain retain existing behavior. Summary consumes only the independently
    projected answer, not raw source/provenance, and keeps the same 0/4/3 outcomes. *)

val input_refusal : view -> Response.t -> Response.t
(** For an already-classified INPUT FAILURE only. Preserve the caller's failure exit,
    with no question stdout. Summary withholds raw paths/diagnostic payload; other views
    retain owner diagnostics. Not a universal error/authorization policy or a log scrubber. *)
