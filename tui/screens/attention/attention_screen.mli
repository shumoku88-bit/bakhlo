(** Attention screen owner: open household matters, their due state and the
    Add / Resolve / Drop editors. Saves only through {!Screen.Save_attention}
    against the memory this editor started from. *)

type t

val config_files : string list
val create : unit -> t
val enter : t -> t
val modal : t -> bool
val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val saved : Screen.env -> Screen.geometry -> (unit, string) result -> t -> t * Screen.request
val view : Screen.env -> Screen.geometry -> t -> Screen.view

(** {2 Queries for checks} *)

val form : t -> Ui_form.t option

val with_form : Ui_form.t -> t -> t
(** Replace the open editor's form content, as typing would. *)

val selected : t -> int
val detail_focused : t -> bool
