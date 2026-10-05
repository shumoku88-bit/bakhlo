type t
(** One supplied observation identity and unmodified neutral Effects. Only retained
    Effect keys must be unique WITHIN this Event. Not ordinary Movement/Actual
    admission, truth, completeness or a global Effect-key namespace. *)

type error =
  | Duplicate_effect_key of { key : Identifier.Effect_key.t; first_position : int; position : int }

val create : id:Identifier.Event.t -> effects:Effect.t list -> (t, error) result
(** First repeated exact key refuses, including identical payloads/different coordinates.
    Positions count ALL Effect occurrences, one-based. Anonymous multiplicity and distinct
    keys at one coordinate remain valid; a key may recur in another Event. Empty/zero/
    mixed-Measure/nonconserving Events remain representable. No key/time/role inference,
    normalization, identity allocation or partial Event on failure. *)

val id : t -> Identifier.Event.t
val effects : t -> Effect.t list
