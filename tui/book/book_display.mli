(** How book values read on screen: exact quantities and grouped amounts, Locus
    candidates, and the detail lines of Actual entries, Scheduled plans and Previews.
    Read-only; nothing here publishes. *)

module B = Bakhlo_household.Book

type quantity_value = Unsupported | Exact of Z.t

val quantity_value : book:B.t -> measure:string -> string -> quantity_value
(** The Locus's current exact quantity; [Unsupported] when the book cannot tell it,
    never zero. *)

val quantity : book:B.t -> measure:string -> string -> string
(** [quantity_value] as text: the Measure's exact decimals, or "Unknown". *)

val format_money : B.t -> string -> Z.t -> string
(** The Measure's exact decimals with the whole part grouped by three ("-1,234.50"). *)

val locus_candidates : B.t -> string -> string list
(** Approved Loci whose ID or label starts with the query (any case), an exact ID
    first; every approved Locus for a blank query. *)

val entry_lines : B.t -> B.entry -> string list
(** Every Effect with its exact quantity and key, then the entry's facts and the
    Scheduled occurrences it completed. *)

val plan_lines : B.t -> B.plan -> string list
(** Every expected Effect, the due day, IDs and whether it is open, cancelled or
    completed. *)

val preview_lines : B.t -> Draft.transaction -> string list
(** What saving the transaction publishes: new, correction or Scheduled completion,
    then [entry_lines] and the balanced total. *)

val plan_preview_lines : B.t -> replace:bool -> B.plan -> string list
(** What saving the plan publishes: new or same-ID edit, then [plan_lines] and the
    balanced total. *)
