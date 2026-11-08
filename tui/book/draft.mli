module B = Bakhlo_household.Book
module R = Bakhlo_household.Record

val coordinate : locus:string -> measure:string -> (B.coordinate, string) result
(** Screen wording only; pure Record rules live in the household core. *)

type payload = Entry_tx of R.transaction | Plan_tx of { plan : B.plan; replace : bool }
type transaction_error = { message : string }

val edit_refusal : book:B.t -> B.entry -> string option

val build_transaction :
  new_id:(unit -> string) ->
  book:B.t ->
  mode:R.mode ->
  R.draft_content ->
  (R.transaction, transaction_error) result

val build_plan :
  new_id:(unit -> string) ->
  book:B.t ->
  mode:R.mode ->
  day:string ->
  draft:R.t ->
  (B.plan * bool, transaction_error) result
