module D = Bakhlo_domain
(** A corrected-entry S-expression book, independent of UI and filesystem.
    Reads the v1 candidate; writes v2 with explicit Exchange evidence. Old input
    versions remain in separate backups. Full-household migration is not claimed. *)

module Q = Bakhlo_application.Current_quantity_query

type entry = {
  id : string;
  day : string;
  memo : string option;
  effects : D.Effect.t list;
  reversal_of : string option;
  exchange : (string * string) option;
}

type plan = {
  id : string;
  day : string;
  measure : string;
  changes : (string * Z.t) list;
  paid_by : string option;
}

type t

val of_string : string -> (t, string) result
val to_string : t -> string
val entries : t -> entry list
val plans : t -> plan list
val measures : t -> (string * int) list
val approved_loci : t -> string list option
val label : t -> string -> string
val image : t -> Q.t
val format : t -> string -> Z.t -> string

val parse_amount : t -> string -> string -> (Z.t, string) result
(** Positive exact decimal input at the explicitly supplied scale. No rounding. *)

val put_entry : t -> replace:bool -> entry -> plan:string option -> (t, string) result
(** Whole checked append or replacement, preserving stable identities and all
    other entries/plans/support. An attached open plan is marked paid atomically.
    Current new-write vocabulary is checked; refunds/Exchange still use Core gates. *)

val add_locus : t -> string -> (t, string) result
(** Explicit vocabulary addition only; never supplies zero balance or a role. *)
