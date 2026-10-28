val main : run:(string -> unit) -> unit
(** Parse [Sys.argv]: [--book FILE] opens the TUI with [run]; the other commands
    check, copy or recover a book without a terminal. Exits on refusal. *)
