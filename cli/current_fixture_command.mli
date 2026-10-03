type request = Actual_fixture_command.request
type plan = Actual_fixture_command.plan = Help | Read of request | Refused of string
val plan : string list -> plan
val help : Movement_command.output
val syntax_refusal : string -> Movement_command.output

(** Explicit caller-owned read result. Version 2 only; reject source before support
    qualification/query. Exit 0 exact, 3 unknown (stdout); 1 load/admission or 2 syntax
    (stderr). No writes, fallback, support inference or household authority. *)
val evaluate : request -> (string, string) result -> Movement_command.output
