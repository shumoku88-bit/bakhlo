type request = { path : string; coordinate : Loam_domain.Effect_coordinate.t }
type plan = Help | Read of request | Refused of string
val plan : string list -> plan
val help : Response.t
val syntax_refusal : string -> Response.t

(** Explicit caller-owned read result. Version 2 only; reject source before support
    qualification/query. Exit 0 exact, 4 known nonzero/amount-unknown, 3 unsupported
    (stdout); 1 load/admission or 2 syntax
    (stderr). No writes, fallback, support inference or household authority. *)
val evaluate : request -> (string, string) result -> Response.t
