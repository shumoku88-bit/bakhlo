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

type mode = New | Edit of B.entry | Pay of string | Plan_new | Plan_edit of B.plan
type form_row = { key : string option; locus : string; amount : string }

val split_sign : string -> bool * string

val form : mode:mode -> measure:string -> form_row list -> t
(** Leading ASCII signs are direction, not part of the expression. An edited
    posting keeps its key only while its Locus is unchanged. *)

val open_plan_draft : book:B.t -> B.plan -> (t, string) result

type transaction = { entry : B.entry; replace : bool; plan : string option }

type draft_content =
  | Multiple of { day : string; memo : string; draft : t; original_amount : (string * Z.t) option }

type error =
  | Day_format
  | Day_invalid
  | Postings of string
  | Movement of movement_fault
  | Original_measure
  | Admission of { reason : string; id : string }

val code : error -> string

val build_transaction :
  new_id:(unit -> string) -> book:B.t -> mode:mode -> draft_content -> (transaction, error) result

val build_plan :
  new_id:(unit -> string) ->
  book:B.t ->
  mode:mode ->
  day:string ->
  draft:t ->
  (B.plan * bool, error) result

val parse_original_quanta :
  scale:int -> string -> (Z.t, [ `Invalid | `Precision | `Non_positive ]) result
(** The Original field's existing decimal notation: ASCII sign, trimmed whole
    and fraction, commas removed, no expressions or full-width normalization. *)

val original_code : [ `Invalid | `Precision | `Non_positive ] -> string
