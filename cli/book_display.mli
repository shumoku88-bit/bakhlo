(** How book values read: exact quantities, grouped amounts and Locus candidates. *)

module B = Bakhlo_household.Book

type quantity_value = Unsupported | Exact of Z.t

val quantity_value : book:B.t -> measure:string -> string -> quantity_value
(** The Locus's current exact quantity; [Unsupported] when the book cannot tell it,
    never zero. *)

val format_money : B.t -> string -> Z.t -> string
(** The Measure's exact decimals with the whole part grouped by three ("-1,234.50"). *)

val locus_candidates : B.t -> string -> string list
(** Approved Loci whose ID or label starts with the query (any case), an exact ID
    first; every approved Locus for a blank query. *)
