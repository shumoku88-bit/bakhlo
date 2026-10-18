(** Transactions Flow report screen owner (read-only). *)

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
val preset : t -> Income_expense_report.period_preset
val detail_focused : t -> bool
val selected_row : t -> int
