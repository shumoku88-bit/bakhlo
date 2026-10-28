val tr : string -> string
(** English source messages form the catalog keys. User data is never translated.
    Only English is currently available; a later locale can supply this one catalog. *)

val format_message : ('a, unit, string) format -> 'a
(** [tr] of the template, then the values inserted as they are. *)
