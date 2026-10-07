type request = { path : string; questions : Quantity_questions.t; view : Quantity_questions.view }
type plan = Help | Read of request | Refused of string

val plan : string list -> plan
val help : Response.t
val syntax_refusal : string -> Response.t
val codec_refusal : Bakhlo_sexp.Book.error -> Response.t
val read : path:string -> (string, string) result -> (Bakhlo_sexp.Book.t, Response.t) result
val evaluate : request -> (string, string) result -> Response.t
