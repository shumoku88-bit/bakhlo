(** Exchange editor owner (opens over any route): one direct exchange between
    two Measures, reviewed and published against the bytes it was reviewed
    from. No rate or valuation is inferred. *)

type t

val config_files : string list
val create : unit -> t
val modal : t -> bool
val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val published : Screen.env -> Screen.geometry -> Screen.publish_outcome -> t -> t * Screen.request
val view : Screen.env -> Screen.geometry -> t -> Screen.view

val open_editor : default_date:string -> t -> t
(** Commands entry, dated by the Shell's focus day. *)

(** {2 Queries for checks} *)

val form : t -> Ui_form.t option
val with_form : Ui_form.t -> t -> t
