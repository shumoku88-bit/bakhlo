module B = Bakhlo_sexp.Daily_book
module M = Bakhlo_application.Event_merchants

type choice = Merchant | Nonmerchant
type mode = Editing | Preview

type t

type outcome =
  | Updated of t
  | Closed
  | Publish of string * M.disposition * string
(** [Publish (target_id, disposition, base_bytes)] is an intent, not a saved entry. *)

val create : base_bytes:string -> B.entry -> t
val base_bytes : t -> string
val target : t -> string
val choice : t -> choice
val party_input : t -> string
val is_preview : t -> bool
val edit : t -> t
val with_publish_error : t -> string -> t

val dimensions : int * int -> int * int
val handle :
  blocked:bool ->
  dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  Ui_input.input ->
  outcome

val footer : t -> string list
val screen :
  dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  (Daily_overlays.style * string) list
