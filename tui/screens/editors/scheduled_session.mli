(* Scheduled occurrence creation session aligned with LOAM ScheduledCreation.lean.
   Edits one explicit due date plus signed single-Measure postings (2 to 6 rows).
   No Description, recurrence, routing, or Actual evidence. *)

type t

type draft_tx = {
  scheduled_on : string;
  measure : string;
  changes : (string * Z.t) list;
  positive_total : Z.t;
}

type outcome = Updated of t | Closed | Publish of draft_tx

val create : book:Bakhlo_sexp.Daily_book.t -> day:string -> measure:string -> t

val create_from_scheduled :
  book:Bakhlo_sexp.Daily_book.t -> Bakhlo_sexp.Daily_book.plan -> (t, string) result

val is_preview : t -> bool

val offers_expected_pace : t -> bool
(** An ordinary creation offers the published plan's expected pace (LOAM
    finishCreated); a completion's next Scheduled does not. *)

val day : t -> string
val measure : t -> string
val notice : t -> string
val focus : t -> int
val first_action : t -> int
val rows_count : t -> int
val candidates : t -> string list
val with_notice : t -> string -> t
val with_publish_error : t -> string -> t
val dimensions : int * int -> int * int

val handle :
  blocked:bool -> dimensions:int * int -> width_of:(string -> int) -> t -> Ui_input.input -> outcome

val footer : t -> string list

val screen :
  book:Bakhlo_sexp.Daily_book.t ->
  dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  (Daily_overlays.style * string) list
