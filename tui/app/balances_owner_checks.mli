(** balances_owner_checks.mli - Dedicated verification for Balances vertical owner. *)

val self_check : width_of:(string -> int) -> directory:string -> unit
