module B = Bakhlo_sexp.Daily_book
(** Pure editing vocabulary and candidate construction. No filesystem or publisher
    capability is available here. The caller supplies dates and fresh identities;
    a reviewed candidate retains its identity until that review is replaced. *)

module D = Bakhlo_domain
module R = Posting_draft

exception Refused of string

val tr : string -> string
val format_message : ('a, unit, string) format -> 'a
val get : ('a, string) result -> 'a
val get_id : ('a, D.Identifier.error) result -> 'a
val lstr : D.Identifier.Locus.t -> string
val mstr : D.Identifier.Measure.t -> string
val quanta : D.Effect.t -> Z.t

type mode = New | Edit of B.entry | Pay of string | Plan_new | Plan_edit of B.plan
type transaction = { entry : B.entry; replace : bool; plan : string option }
type payload = Entry_tx of transaction | Plan_tx of { plan : B.plan; replace : bool }

type draft_content =
  | Multiple of {
      day : string;
      memo : string;
      draft : R.t;
      original_amount : (string * Z.t) option;
    }

type transaction_error = { message : string }

val pair : D.Effect.t list -> (D.Effect.t * D.Effect.t) option

val edit_refusal : book:B.t -> B.entry -> string option
(** Why the Record editor cannot correct this entry, if it cannot. *)

val normalize_date_text : string -> string
val is_leap_year : int -> bool
val days_in_month : year:int -> month:int -> int
val normalize_date : string -> (string, string) result
val next_calendar_day : int * int * int -> int * int * int
val prev_calendar_day : int * int * int -> int * int * int
val shift_calendar_day : string -> int -> (string, string) result
val is_valid_canonical_date : string -> bool
val is_valid_date : string -> bool

val build_transaction :
  new_id:(unit -> string) ->
  book:B.t ->
  mode:mode ->
  draft_content ->
  (transaction, transaction_error) result

val build_plan :
  new_id:(unit -> string) ->
  book:B.t ->
  mode:mode ->
  day:string ->
  draft:R.t ->
  (B.plan * bool, transaction_error) result
