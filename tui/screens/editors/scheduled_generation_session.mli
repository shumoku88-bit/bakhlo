(* Scheduled generation: proposes explicit later occurrences without storing recurrence. *)
module B = Bakhlo_sexp.Daily_book

type t

type outcome =
  | Updated of t
  | Closed
  | Publish of B.plan list * string

val create :
  ?cadence_months:int -> book:B.t -> base_bytes:string -> source:B.plan -> unit -> (t, string) result
(** [cadence_months] (1, 2, 3, 6 or 12) preselects a monitored cadence; others refuse. *)
val base_bytes : t -> string
val with_publish_error : t -> string -> t
val dimensions : int * int -> int * int
val handle :
  new_id:(unit -> string) ->
  blocked:bool ->
  dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  Ui_input.input ->
  outcome
val screen :
  dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  (Daily_overlays.style * string) list
val footer : t -> string list

(** Read-only queries for checks. *)

val source : t -> B.plan
val selected_months : t -> int
