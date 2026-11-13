(** How book values read: exact quantities, grouped amounts and Locus candidates. *)

module B = Bakhlo_household.Book

type quantity_value = Unsupported | Exact of Z.t

val quantity_value : book:B.t -> measure:string -> string -> quantity_value
(** The Locus's current exact quantity; [Unsupported] when the book cannot tell it,
    never zero. *)

val format_money : B.t -> string -> Z.t -> string
(** The Measure's exact decimals with the whole part grouped by three ("-1,234.50"). *)

val month_name : string -> string
(** A month number as the screens print it: ["11"] reads ["Nov"]; anything other
    than ["01"].. ["12"] is returned as it is. *)

val recent_measure : B.t -> except:string list -> string
(** The Measure offered when a second one is asked for: the one the latest saved
    record used (in a row or as its original amount) apart from [except], else the
    book's first Measure not in [except], else [""]. Abroad in shekels, an exchange
    or an original amount offers ils rather than the book's first foreign Measure. *)

val locus_candidates : B.t -> string -> string list
(** Approved Loci whose ID or label starts with the query (any case), an exact ID
    first; every approved Locus for a blank query. *)
