(** Pure text projection for the existing CLI, not a UI framework or wire format.
    Domain/application values are independent of this module. No accounting
    validation, aggregate recomputation, I/O, or implicit time in formatting. *)

val preview : Loam_application.Movement_check.preview -> string
val refusal : Loam_domain.Movement.error list -> string
