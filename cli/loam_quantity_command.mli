(** Terminal-only explicit-file consumer of the pure scoped LOAM reader.
    Caller owns file acquisition; no root selection, fallback, recovery or writes. *)
type request = { path : string; coordinate : Bakhlo_domain.Effect_coordinate.t }
type plan = Help | Read of request | Refused of string
val plan : string list -> plan
val help : Response.t
val syntax_refusal : string -> Response.t
val evaluate : request -> (string, string) result -> Response.t
