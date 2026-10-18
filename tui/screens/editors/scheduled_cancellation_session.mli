module B = Bakhlo_sexp.Daily_book

type t
type outcome = Updated of t | Closed | Publish of string * string * string
val create : book:B.t -> base_bytes:string -> day:string -> B.plan -> t
val base_bytes : t -> string
val day : t -> string
val is_preview : t -> bool
val with_publish_error : t -> t
val dimensions : int * int -> int * int
val handle : blocked:bool -> dimensions:int * int -> width_of:(string -> int) -> t -> Ui_input.input -> outcome
val footer : t -> string list
val screen : dimensions:int * int -> width_of:(string -> int) -> t -> (Daily_overlays.style * string) list
