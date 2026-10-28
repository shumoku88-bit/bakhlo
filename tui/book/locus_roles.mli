(** Accounting roles of Loci, as the book holds them. *)

type role = Bakhlo_book_txt.Book_txt.role = Asset | Liability | Equity | Income | Expense

val role_label : role -> string

type t = (string * role) list

val empty : t

val set_role : t -> string -> role option -> t
(** Assign or clear one Locus's role, keeping the list in Locus order. *)
