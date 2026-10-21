(** Actual route owner: the LOAM three-pane Actuals workspace. Edit, reverse,
    date correction and Merchant classification of the selected entry are
    {!Screen.Record_action} requests; Enter on an entry drills into its day. *)

type t = Actual_workspace.t

val config_files : string list
val create : unit -> t

val enter : focus_day:string -> t -> t
(** Each entry starts from the Shell's focus day. *)

val modal : t -> bool
val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val saved : Screen.env -> Screen.geometry -> (unit, string) result -> t -> t * Screen.request
val view : Screen.env -> Screen.geometry -> t -> Screen.view

val book_changed :
  before:Bakhlo_sexp.Daily_book.t -> after:Bakhlo_sexp.Daily_book.t -> t -> t * string
(** Keep the selection across a publication or a drill return; the string is a notice. *)
