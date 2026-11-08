module B = Bakhlo_household.Book
module R = Bakhlo_household.Record

val coordinate : locus:string -> measure:string -> (B.coordinate, string) result
(** Screen wording only; pure Record rules live in the household core. *)

(** What the Record form edits: an Actual, or a Scheduled occurrence it creates or edits. *)
type mode = Actual of R.mode | Plan_new | Plan_edit of B.plan

type payload = Entry_tx of R.transaction | Plan_tx of { plan : B.plan; replace : bool }
type transaction_error = { message : string }

val open_edit : book:B.t -> B.entry -> (R.t, string) result
val open_plan : book:B.t -> B.plan -> (R.t, string) result

val build_transaction :
  new_id:(unit -> string) ->
  book:B.t ->
  mode:R.mode ->
  R.content ->
  (R.transaction, transaction_error) result

val build_plan :
  new_id:(unit -> string) ->
  book:B.t ->
  editing:B.plan option ->
  day:string ->
  draft:R.t ->
  (B.plan * bool, transaction_error) result
