(** Exact signed integer quanta, independent of Measure or presentation policy.

    This is an arithmetic primitive, not a measured household amount. Callers
    handling Effects/Movements must separately enforce Measure compatibility.
    No rounding, valuation, parsing, or fixed-width overflow is introduced. *)

type t

(** Lossless conversion from and to arbitrary-precision integer quanta. *)
val of_quanta : Z.t -> t
val quanta : t -> Z.t

val zero : t
val add : t -> t -> t
val neg : t -> t
val sub : t -> t -> t
val equal : t -> t -> bool

(** Negative, zero, or positive according to exact integer ordering. *)
val compare : t -> t -> int

(** Exact finite sum. The empty sum is zero; this does not mean that absent
    household evidence establishes a zero balance. *)
val sum : t list -> t
