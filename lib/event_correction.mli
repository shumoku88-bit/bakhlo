type t = { target : Identifier.Event.t; replacement : Identifier.Event.t }
(** Raw explicit relation between two observation identities. Construction does
    not establish endpoint existence, currentness, chronology, or graph admission.
    Neither endpoint is overwritten, removed, or given arrival-order authority. *)
