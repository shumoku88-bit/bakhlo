module B = Bakhlo_sexp.Daily_book

type t
type outcome = Updated of t | Closed of B.plan option | Add of B.plan | Defer of B.plan
val create : book:B.t -> base_revision:string -> B.plan -> t
val base_revision : t -> string
val with_notice : t -> string -> t
val dimensions : int * int -> int * int
val handle : dimensions:int * int -> width_of:(string -> int) -> t -> Ui_input.input -> outcome
val footer : t -> string list
val screen : dimensions:int * int -> width_of:(string -> int) -> t -> (Daily_overlays.style * string) list
