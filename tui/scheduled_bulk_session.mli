module B = Bakhlo_sexp.Daily_book

type t
type outcome = Updated of t | Closed | Publish of B.plan list * string

val create : book:B.t -> base_bytes:string -> from_day:string -> B.plan -> (t, string) result
val base_bytes : t -> string
val with_publish_error : t -> string -> t
val dimensions : int * int -> int * int
val handle : blocked:bool -> dimensions:int * int -> width_of:(string -> int) -> t -> Ui_input.input -> outcome
val screen : dimensions:int * int -> width_of:(string -> int) -> t -> (Daily_overlays.style * string) list
val footer : t -> string list
