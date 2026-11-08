val commands :
  (string list
  * (string list ->
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
    | `Fx ]
    option)
  * string)
  list
(** The bk commands after the book: their words, what runs given the words after
    them ([None] when they take none) and one line about it. *)

val help : string
(** Every command with its line, for [bk help] and an unknown command. *)

val main : run:(string -> unit) -> unit
(** Parse [Sys.argv]: [--book FILE] opens the TUI with [run]; the other commands
    check, copy or recover a book without a terminal. Exits on refusal. *)
