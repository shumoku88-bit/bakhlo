module B = Bakhlo_sexp.Daily_book
module A = Daily_actions
type t
type outcome = Updated of t | Closed of t | Publish of A.transaction * string * t
val create : book:B.t -> day:string -> measure:string -> unit -> t
val of_edit : book:B.t -> B.entry -> (t, string) result
val of_plan : ?day:string -> book:B.t -> B.plan -> (t, string) result
val mode : t -> A.mode
val has_draft : t -> bool
val with_notice : t -> string -> t
val preview : book:B.t -> base_bytes:string -> blocked:bool -> t -> t
val handle : book:B.t -> base_bytes:string -> blocked:bool -> dimensions:int * int ->
  width_of:(string -> int) -> t -> Ui_input.input -> outcome
val screen : book:B.t -> dimensions:int * int -> width_of:(string -> int) -> t ->
  (Daily_overlays.style * string) list
