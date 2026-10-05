type request = { path : string; questions : Quantity_questions.t; view : Quantity_questions.view }
(** Terminal-only explicit-file consumer of the pure scoped LOAM reader.
    Caller owns one file acquisition after ALL questions are planned; evaluate admits once.
    No root selection, fallback, recovery or writes. *)

type plan = Help | Read of request | Refused of string

val plan : string list -> plan
val help : Response.t
val syntax_refusal : string -> Response.t
val evaluate : request -> (string, string) result -> Response.t
