(** [bk r] and [bk pay]: record an Actual or pay a plan with one-line answers.

    The household core decides (Record), the screens' wording and Preview are
    reused (Draft, Book_display) and Book_file saves against the session as it
    was loaded. Nothing is saved before the Preview is confirmed. *)

type io = { read : unit -> string option; print : string -> unit }
(** [read] gives one answer line, [None] at end of input. *)

val run :
  io ->
  [ `Record | `Pay | `Balances | `Pace ] ->
  Book_file.t ->
  today:string ->
  [ `Saved | `Stopped ]
(** [`Balances] and [`Pace] print the Balances (Current) rows and Daily Pace's
    breakdown and save nothing. *)

val terminal : io
(** Standard input and output. *)
