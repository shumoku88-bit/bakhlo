(* Scheduled generation: proposes explicit later occurrences without storing recurrence. *)
module B = Bakhlo_household.Daily_book

type t
type outcome = Updated of t | Closed | Publish of B.plan list * string

val create :
  ?cadence_months:int ->
  ?observed_at:string ->
  book:B.t ->
  base_revision:string ->
  source:B.plan ->
  unit ->
  (t, string) result
(** [cadence_months] (1, 2, 3, 6 or 12) preselects a monitored cadence; others refuse.
    A monitored cadence is replenishment mode and requires [observed_at], a canonical
    Gregorian date (0001-01-01 .. 9999-12-31) supplied by the caller; there is no
    fallback and no clock read here. Cadence [None] keeps the general [g] form, which
    ignores [observed_at]. *)

val base_revision : t -> string
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
  dimensions:int * int -> width_of:(string -> int) -> t -> (Daily_overlays.style * string) list

val footer : t -> string list

(** Read-only queries for checks. *)

val source : t -> B.plan
val selected_months : t -> int
