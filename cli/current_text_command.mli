(** Terminal-only development shell for Bakhlo_text.Read. File acquisition belongs
    to bin/main; no writer. Response streams/exits are NOT shared operation results. *)
type request = { path : string; coordinate : Bakhlo_domain.Effect_coordinate.t }
type plan = Help | Read of request | Refused of string
val plan : string list -> plan
val help : Response.t
val syntax_refusal : string -> Response.t
val evaluate : request -> (string, string) result -> Response.t
