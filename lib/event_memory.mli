type t
(** Immutable identity-unique supplied Event collection and matching lookup index.
    Representation order is retained but never selects authority/chronology.
    NOT an admitted current Actual image or proof of source completeness. *)

type error = Duplicate_id of { id : Identifier.Event.t; first_position : int; position : int }

val of_events : Event.t list -> (t, error) result
(** Reject the first repeated identity regardless of payload equality; positions
    are one-based input diagnostics. This is not a publisher retry policy.
    Empty input is a valid supplied collection, not a missing/failed data fallback. *)

val events : t -> Event.t list
val find_by_id : t -> Identifier.Event.t -> Event.t option
