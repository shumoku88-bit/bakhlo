module B = Bakhlo_household.Daily_book

type t
type outcome = Updated of t | Closed | Publish of string * string * string

val create : book:B.t -> base_revision:string -> day:string -> B.plan -> t
val base_revision : t -> string
val day : t -> string
val is_preview : t -> bool
val with_publish_error : t -> t
val dimensions : int * int -> int * int

val handle :
  blocked:bool -> dimensions:int * int -> width_of:(string -> int) -> t -> Ui_input.input -> outcome

val footer : t -> string list

val screen :
  dimensions:int * int -> width_of:(string -> int) -> t -> (Ui_render.style * string) list
