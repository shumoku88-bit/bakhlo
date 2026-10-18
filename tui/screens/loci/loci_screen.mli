(** Manage Loci screen owner: admitted Locus tokens with roles, labels and
    current quantities. Admission and display names are ledger publications
    ({!Screen.Publish}); accounting roles are a checked save of
    accounting-roles.tsv ({!Screen.Save_config}). *)

type t

val config_files : string list
val create : unit -> t
val enter : t -> t
val modal : t -> bool
val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val saved : Screen.env -> Screen.geometry -> (unit, string) result -> t -> t * Screen.request
val published : Screen.env -> Screen.geometry -> Screen.publish_outcome -> t -> t * Screen.request
val view : Screen.env -> Screen.geometry -> t -> Screen.view

(** {2 Queries for checks} *)

val form : t -> Ui_form.t option
val with_form : Ui_form.t -> t -> t
val selected : t -> int
val admitted_loci : Bakhlo_sexp.Daily_book.t -> string list
(** Approved loci, or the loci in use when no approval list is supplied. *)
val detail_focused : t -> bool
