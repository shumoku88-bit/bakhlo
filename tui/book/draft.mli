module B = Bakhlo_household.Book
(** Pure editing vocabulary and candidate construction. No filesystem or publisher
    capability is available here. The caller supplies dates and fresh identities;
    a reviewed candidate retains its identity until that review is replaced. *)

module D = Bakhlo_domain
module R = Posting_draft

val coordinate : locus:string -> measure:string -> (B.coordinate, string) result
(** The balance coordinate of a Locus and a Measure token; an empty one is refused. *)

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

val pair : B.posting list -> (B.posting * B.posting) option

val edit_refusal : book:B.t -> B.entry -> string option
(** Why the Record editor cannot correct this entry, if it cannot. *)

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
