(** Pure proleptic Gregorian date arithmetic over YYYY-MM-DD; no local timestamps. *)

val parts : string -> (int * int * int, string) result

val weekday : string -> (int, string) result
(** Monday is zero. *)

val index : string -> (int, string) result
(** Days since 0000-12-31; invalid dates refuse. *)

val shift_days : string -> int -> (string, string) result
val shift_months : string -> int -> (string, string) result
val shift_years : string -> int -> (string, string) result
