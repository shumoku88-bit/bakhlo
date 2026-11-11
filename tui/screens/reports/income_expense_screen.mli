(** Income & Expense report screen owner (read-only). *)

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
val scroll : t -> int

val table : t -> bool
(** The last windows side by side ([t]). *)

val back : t -> int
(** The compared window: this many windows before the shown one. *)

val picker : t -> Compare_picker.t option
