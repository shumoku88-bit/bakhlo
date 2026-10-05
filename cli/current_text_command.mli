type request = { path : string; questions : Quantity_questions.t; explain : bool }
(** Terminal-only development shell for Bakhlo_text.Read. File acquisition belongs
    to bin/main after ALL questions are planned; evaluate admits supplied bytes once.
    No writer. Response streams/exits are NOT shared operation results. *)

type plan = Help | Read of request | Refused of string

val plan : string list -> plan
val help : Response.t
val syntax_refusal : string -> Response.t
val evaluate : request -> (string, string) result -> Response.t
