(** locus_roles.mli - Accounting roles for Loci and the accounting-roles.tsv text format (no file access) *)

type role = Daily_overlays.accounting_role = Asset | Liability | Equity | Income | Expense

val role_to_string : role -> string
val role_of_string : string -> role option
val role_label : role -> string

type t = (string * role) list

val empty : t
val set_role : t -> string -> role option -> t
val of_string : string -> (t, string) result
(** Refuses a malformed row, an unknown role or a repeated Locus (with its line). *)

val to_string : t -> string

val file_name : string
(** Configuration file holding explicit Locus accounting roles. *)
