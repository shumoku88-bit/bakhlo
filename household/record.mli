module B = Book
(** Pure Record form rules. Rows retain order, multiplicity and keys; no clock,
    I/O or publisher. Book admission remains the authority on saving. *)

type row = { key : string option; locus : string; negative : bool; amount : string }
type t = { measure : string; rows : row list }

type movement_fault =
  | Empty
  | Zero of int
  | Measure_differs of { position : int; expected : string; actual : string }
  | Unbalanced

val movement_fault : B.posting list -> movement_fault option
(** First fault in row order: zero precedes a differing Measure on the same row. *)

val movement_code : movement_fault -> string
val of_effects : B.t -> B.posting list -> (t, string) result
val edit_refusal : book:B.t -> B.entry -> string option

(** What an Actual form does: a new entry, a correction of one, or the payment of a plan. *)
type mode = New | Edit of B.entry | Pay of string

type form_row = { key : string option; locus : string; amount : string }

val split_sign : string -> bool * string

val form : editing:B.entry option -> measure:string -> form_row list -> t
(** Leading ASCII signs are direction, not part of the expression. A posting of
    the [editing] entry keeps its key only while its Locus is unchanged. *)

val open_plan_draft : book:B.t -> B.plan -> (t, string) result

type transaction = { entry : B.entry; replace : bool; plan : string option }
type content = { day : string; memo : string; draft : t; original_amount : (string * Z.t) option }

type error =
  | Day_format
  | Postings of string
  | Movement of movement_fault
  | Original_measure
  | Admission of { reason : string; id : string }

val code : error -> string

val build_transaction :
  new_id:(unit -> string) -> book:B.t -> mode:mode -> content -> (transaction, error) result

val build_plan :
  new_id:(unit -> string) ->
  book:B.t ->
  editing:B.plan option ->
  day:string ->
  draft:t ->
  (B.plan * bool, error) result
