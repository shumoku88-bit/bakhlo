(** A pure, stateless application operation for the existing Movement check.
    No argv, formatting, clocks, filesystem, environment, or publication. *)

type command = { effects : Bakhlo_domain.Effect.t list }

type preview
(** A structured, immutable answer constructed only after domain validation.
    This is not a persisted Event or permission to publish. *)

val run : command -> (preview, Bakhlo_domain.Movement.error list) result

val measure : preview -> Bakhlo_domain.Identifier.Measure.t
(** Semantic values, without layout. Effects preserve original order/multiplicity.
    The positive total is materialized once per successful command; reading or
    formatting the answer does not rerun validation or the aggregate calculation. *)

val effects : preview -> Bakhlo_domain.Effect.t list
val positive_total : preview -> Bakhlo_domain.Quantity.t
