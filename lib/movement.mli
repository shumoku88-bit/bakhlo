(** Validated ordinary movement: nonempty, nonzero Effects, one Measure,
    exact zero signed total. This is NOT admission against an operational world,
    a persisted Event, or permission to publish later. *)

type t

type error =
  | Empty
  | Zero_quantity of { position : int }
  | Measure_mismatch of
      { position : int
      ; expected : Identifier.Measure.t
      ; actual : Identifier.Measure.t
      }
  | Unbalanced of
      { measure : Identifier.Measure.t
      ; residual : Quantity.t
      }

(** Refusals are nonempty and deterministic, with one-based Effect positions.
    Collect shape errors in input order; compute residual only if shape passes.
    Successful validation preserves order and multiplicity without normalization. *)
val validate : Effect.t list -> (t, error list) result

val measure : t -> Identifier.Measure.t
val effects : t -> Effect.t list

(** Derived exact sum of positive Effects, in [measure]. Not canonical state. *)
val positive_total : t -> Quantity.t
