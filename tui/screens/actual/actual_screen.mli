(** Actual route owner: the LOAM three-pane Actuals workspace. The list is
    grouped by day inside a period window (Today / Cycle / Month / All); the
    Screen owns the window because only it can read the configured boundary
    presets the reports use. Edit, reverse, date correction and Merchant
    classification of the selected entry are {!Screen.Record_action} requests;
    Enter on an entry drills into its day. *)

type t = Actual_workspace.t

val config_files : string list
val create : unit -> t

val enter : focus_day:string -> t -> t
(** Each entry starts on the Cycle window containing the Shell's focus day (the
    Calendar's selected day), with that day selected. *)

val modal : t -> bool

val context : Screen.env -> t -> Actual_workspace.context
(** The book, the resolved period window, the day, the roles and the Measure. *)

val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val saved : Screen.env -> Screen.geometry -> (unit, string) result -> t -> t * Screen.request
val view : Screen.env -> Screen.geometry -> t -> Screen.view

val book_changed :
  before:Bakhlo_sexp.Daily_book.t -> after:Bakhlo_sexp.Daily_book.t -> t -> t * string
(** Keep the selection across a publication or a drill return; the string is a notice. *)
