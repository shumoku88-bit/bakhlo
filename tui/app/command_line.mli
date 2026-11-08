val commands :
  (string list
  * [ `Record | `Pay | `Balances | `Pace | `Plans of [ `List | `More | `Amount | `Cancel ] ]
  * string)
  list
(** The bk commands after the book: their words, what runs and one line about it. *)

val help : string
(** Every command with its line, for [bk help] and an unknown command. *)

val main : run:(string -> unit) -> unit
(** Parse [Sys.argv]: [--book FILE] opens the TUI with [run]; the other commands
    check, copy or recover a book without a terminal. Exits on refusal. *)
