type request
(** Explicit supplied files only. No selected store, filesystem authority or implicit init. *)

type plan = Help | Stage of request | Refused of string

val plan : string list -> plan
val help : Response.t
val base_path : request -> string
val event_path : request -> string option
val output_path : request -> string

val evaluate :
  request ->
  base:(string, string) result ->
  event:(string, string) result option ->
  (Bakhlo_sexp.Book.t, Response.t) result
(** Pure whole preparation. The outer shell may stage only this admitted book into
    a fresh file; it must not overwrite, acknowledge recording or claim durable Saved. *)
