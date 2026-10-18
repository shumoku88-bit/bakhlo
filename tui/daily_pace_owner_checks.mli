(** daily_pace_owner_checks.mli - Dedicated verification for Daily Pace vertical owner. *)

val self_check : width_of:(string -> int) -> directory:string -> unit
