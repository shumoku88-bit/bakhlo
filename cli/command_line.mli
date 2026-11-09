type command = Line_commands.command
(** What a bk command runs. *)

val commands : (string list * (string list -> command option) * string) list
(** The bk commands after the book: their words, what runs given the words after
    them ([None] when they take none) and one line about it. *)

val line_command : string list -> command option
(** The command the words after the book name, as [bk] reads them. *)

val help : string
(** Every command with its line, for [bk help] and an unknown command. *)

val main : unit -> unit
(** Parse [Sys.argv]: [--book FILE] prints today's pace and the commands, [--book FILE
    COMMAND] runs one; [--commands] lists each command's words (for Tab completion);
    [--check], [--copy-from] and [--restore-copy-from] check, copy or recover a book. Exits on refusal. *)
