(** The accounting-role and Attention sections of book.txt in the text formats the
    screens read, and book.txt text for fixtures and tools. Pure. *)

type sidecars = {
  roles : string;  (** [accounting-roles.tsv] text; [""] when there are no roles *)
  attention : string;  (** [attention.loam] text; [""] when there is no Attention *)
}

val no_sidecars : sidecars

val sidecars_of : Daily_book.t -> sidecars
(** The book's roles and Attention in those formats. *)

val with_sidecars : Daily_book.t -> sidecars -> (Daily_book.t, string) result
(** The book with these roles and this Attention; a malformed text refuses. *)

val text : ?sidecars:sidecars -> Daily_book.t -> string
(** The book.txt bytes of a book, with [sidecars] (default none). For fixtures and
    tools; raises [Invalid_argument] with the refusal. *)

val book : string -> Daily_book.t
(** The book of a book.txt text. For fixtures and tools; raises [Invalid_argument]
    with the refusal. *)
