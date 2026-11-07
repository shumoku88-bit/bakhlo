(** The household's days: YYYY-MM-DD in the proleptic Gregorian calendar, typed dates
    normalized to that form, and arithmetic over them. No clock, no local timestamps. *)

val normalize : string -> (string, string) result
(** A typed date as YYYY-MM-DD: [-], [/] or [.] between a four-digit year and a one- or
    two-digit month and day, full-width digits and separators accepted; years
    0001–9999, real days only. Refuses with ["invalid-date"]. *)

val is_valid : string -> bool
(** Already YYYY-MM-DD and a real day, as book.txt requires. *)

val is_leap_year : int -> bool
val days_in_month : year:int -> month:int -> int
val parts : string -> (int * int * int, string) result

val weekday : string -> (int, string) result
(** Monday is zero. *)

val index : string -> (int, string) result
(** Days since 0000-12-31; invalid dates refuse. *)

val shift_days : string -> int -> (string, string) result
val shift_months : string -> int -> (string, string) result
val shift_years : string -> int -> (string, string) result
