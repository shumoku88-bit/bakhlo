module B = Bakhlo_household.Book
module A = Daily_draft

type t
type outcome = Updated of t | Closed | Publish of A.transaction * string

val create : base_revision:string -> B.entry -> t
val base_revision : t -> string
val day : t -> string
val is_preview : t -> bool
val edit : t -> t
val dimensions : int * int -> int * int

val handle :
  blocked:bool -> dimensions:int * int -> width_of:(string -> int) -> t -> Ui_input.input -> outcome

val footer : t -> string list

val screen :
  dimensions:int * int -> width_of:(string -> int) -> t -> (Ui_render.style * string) list
