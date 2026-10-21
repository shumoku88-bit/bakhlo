type zoom = Day | Month | Year
type t = { selected_day : string; zoom : zoom }
type action = Left | Right | Up | Down | Cycle_zoom | Drill | Today of string | Jump of string
type transition = Moved of t | Open_day of t | Refused of string

val create : string -> (t, string) result
val parts : string -> (int * int * int, string) result

val weekday : string -> (int, string) result
(** Monday is zero. Pure proleptic Gregorian arithmetic; no local timestamps. *)

val shift_days : string -> int -> (string, string) result
val shift_months : string -> int -> (string, string) result
val shift_years : string -> int -> (string, string) result
val apply : t -> action -> transition
val month_slots : string -> (string option list, string) result
val period_contains : t -> string -> bool
val title : t -> string
