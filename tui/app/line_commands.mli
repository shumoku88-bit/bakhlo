(** [bk r] and [bk pay]: record an Actual or pay a plan with one-line answers.

    The household core decides (Record), the screens' wording is reused (Draft),
    lists and the Preview name Loci by display name and Book_file saves against the session as it
    was loaded. Nothing is saved before the Preview is confirmed. *)

type io = { read : unit -> string option; print : string -> unit }
(** [read] gives one answer line, [None] at end of input. *)

val run :
  io ->
  [ `Record
  | `Pay
  | `Balances
  | `Pace
  | `Plans of [ `List | `More | `Amount | `Cancel ]
  | `Find of string list
  | `Edit of string list
  | `Date of string list
  | `Refund of string list
  | `Shop of string list
  | `Check
  | `Loci of [ `List | `Add | `Name | `Role ]
  | `Pace_pool
  | `Pace_cycle
  | `Pace_if of string list
  | `Pace_target
  | `Fx
  | `Todo of [ `List | `Add | `Done | `Drop ]
  | `Register of string list
  | `Month of string list
  | `Report_ie of string list
  | `Day of string list ] ->
  Book_file.t ->
  today:string ->
  [ `Saved | `Stopped ]
(** [`Balances] and [`Pace] print the Balances (Current) rows and Daily Pace's
    breakdown and save nothing. [`Plans] lists plans in series, or fills,
    re-prices or cancels one series after a Preview. *)

val terminal : io
(** Standard input and output. *)
