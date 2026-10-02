(** A supplied observation identity and retained anonymous neutral Effects.
    NOT ordinary Movement admission, current Actual, or truth/completeness proof.
    This subset cannot represent independently keyed Effects; do not drop keys
    or other independent metadata when adapting external evidence. *)
type t

(** Empty/zero/mixed-Measure/nonconserving observations are representable here.
    No inference, normalization, timestamp, or identity allocation. *)
val create : id:Identifier.Event.t -> effects:Effect.t list -> t

val id : t -> Identifier.Event.t
val effects : t -> Effect.t list
