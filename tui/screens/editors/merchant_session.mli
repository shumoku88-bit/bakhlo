module B = Bakhlo_household.Daily_book

type choice = Merchant | Nonmerchant
type mode = Editing | Preview
type t

type outcome =
  | Updated of t
  | Closed
  | Publish of string * B.disposition * string
      (** [Publish (target_id, disposition, base_revision)] is an intent, not a saved entry. *)

val create : base_revision:string -> B.entry -> t
val base_revision : t -> string
val target : t -> string
val choice : t -> choice
val party_input : t -> string
val is_preview : t -> bool
val edit : t -> t
val with_publish_error : t -> string -> t
val dimensions : int * int -> int * int

val handle :
  blocked:bool -> dimensions:int * int -> width_of:(string -> int) -> t -> Ui_input.input -> outcome

val footer : t -> string list

val screen :
  dimensions:int * int -> width_of:(string -> int) -> t -> (Ui_render.style * string) list
