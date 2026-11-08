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
    | `Fx
    | `Todo of [ `List | `Add | `Done | `Drop ]
    | `Register of string list
    | `Month of string list
    | `Report_ie of string list
    | `Day of string list ]
    option)
  * string)
  list
(** The bk commands after the book: their words, what runs given the words after
    them ([None] when they take none) and one line about it. *)

val help : string
(** Every command with its line, for [bk help] and an unknown command. *)

val main : unit -> unit
(** Parse [Sys.argv]: [--book FILE] prints today's pace and the commands, [--book FILE
    COMMAND] runs one; [--check], [--copy-from] and [--restore-copy-from] check, copy
    or recover a book. Exits on refusal. *)
