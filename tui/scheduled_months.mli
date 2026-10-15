module B = Bakhlo_sexp.Daily_book

type t

val create : today:string -> (t, string) result
(** Capture the validated current month as the earliest permitted window. *)

val first_month : t -> string
(** Canonical YYYY-MM-01. *)

val shift : t -> int -> (t, string) result
(** Refuse windows before the captured current month or after 9999-12. *)

val follow : t -> string -> t
(** Keep a selected canonical date in the six-month window; overdue dates return
    to the captured current month. Invalid dates leave the window unchanged. *)

val visible_months : t -> string list
(** Up to six consecutive canonical month starts, capped at 9999-12. *)

val screen :
  book:B.t -> plans:B.plan list -> dimensions:int * int ->
  width_of:(string -> int) -> selected:B.plan option -> t ->
  (Daily_overlays.style * string) list
(** Read-only body-sized surface. Plans are all current-open explicit occurrences,
    ordered by canonical date and ID, independently of retained List filters. *)
