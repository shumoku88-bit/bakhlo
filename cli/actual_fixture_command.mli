type request = { path : string; coordinate : Loam_domain.Effect_coordinate.t }
type plan = Help | Read of request | Refused of string
val plan : string list -> plan
val help : Movement_command.output
val syntax_refusal : string -> Movement_command.output

(** Caller performs the explicit file read. Error never becomes empty input.
    Exit 0 exact, 3 unsupported (stdout); 1 loading/admission, 2 syntax (stderr).
    This is synthetic preview only, not a reader of upstream household formats. *)
val evaluate : request -> (string, string) result -> Movement_command.output
