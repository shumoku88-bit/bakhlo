(** A pure, stateless application operation for the existing Movement check.
    No argv, formatting, clocks, filesystem, environment, or publication. *)

type command = { effects : Loam_domain.Effect.t list }

(** A structured, immutable answer constructed only after domain validation.
    This is not a persisted Event or permission to publish. *)
type preview

val run : command -> (preview, Loam_domain.Movement.error list) result

(** Semantic values, without layout. Effects preserve original order/multiplicity.
    The positive total is materialized once per successful command; reading or
    formatting the answer does not rerun validation or the aggregate calculation. *)
val measure : preview -> Loam_domain.Identifier.Measure.t
val effects : preview -> Loam_domain.Effect.t list
val positive_total : preview -> Loam_domain.Quantity.t
