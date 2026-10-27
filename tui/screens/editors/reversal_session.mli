type t
(** Local date input and fixed-snapshot exact-inverse review; no I/O or identity allocation. *)

type outcome =
  | Updated of t
  | Closed
  | Publish of string * string * string
      (** [Publish (target_id, reversal_day, base_revision)] is an intent, not a saved entry. *)

val create :
  book:Bakhlo_household.Daily_book.t ->
  base_revision:string ->
  day:string ->
  Bakhlo_household.Daily_book.entry ->
  t

val is_preview : t -> bool
val base_revision : t -> string
val day : t -> string

val with_publish_error : t -> t
(** Return to date input without replacing the captured target or publication base. *)

val dimensions : int * int -> int * int

val handle :
  blocked:bool -> dimensions:int * int -> width_of:(string -> int) -> t -> Ui_input.input -> outcome

val footer : t -> string list

val screen :
  dimensions:int * int -> width_of:(string -> int) -> t -> (Daily_overlays.style * string) list
