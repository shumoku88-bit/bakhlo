(** Observe Quantities editor owner (opens over any route): exact observed
    quantities published together as one reconciliation group. A changed or
    uncertain generation stops writes; nothing is retried. *)

type t

val config_files : string list
val create : unit -> t
val modal : t -> bool
val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val published : Screen.env -> Screen.geometry -> Screen.publish_outcome -> t -> t * Screen.request
val reloaded : Screen.env -> t -> t * Screen.request
val view : Screen.env -> Screen.geometry -> t -> Screen.view

val open_editor : ?locus:string -> ?measure:string -> ?amount:string -> Screen.env -> t -> t
(** Empty draft (Home/Calendar [o], Commands) or one coordinate from Balances. *)

(** {2 Queries for checks} *)

val form : t -> Ui_form.t option
val with_form : Ui_form.t -> t -> t
