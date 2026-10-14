(** locus_roles.mli - Accounting roles for Loci and persistence for accounting-roles.tsv *)

type role = Daily_overlays.accounting_role =
  | Asset
  | Liability
  | Equity
  | Income
  | Expense

val role_to_string : role -> string
val role_of_string : string -> role option
val role_label : role -> string
val all_roles : (role * string) list

type t = (string * role) list

val empty : t
val get_role : t -> string -> role option
val set_role : t -> string -> role option -> t

val of_string : string -> t
val to_string : t -> string

val file_path : ?config_home:string -> string -> string
val load_file : string -> t
val save_file : string -> t -> (unit, string) result
