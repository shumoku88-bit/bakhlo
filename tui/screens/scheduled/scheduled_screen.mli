(** Scheduled route owner: explicit current-open plans as a filtered List or
    a six-month Months view, with a plan detail pane. Record actions on the
    selected plan are requests to the Shell; this screen never writes. *)

type t

val config_files : string list
val create : Scheduled_months.t -> t
(** The Months window is captured from the Shell's validated focus day. *)

val enter : focus_day:string -> t -> t
val modal : t -> bool
val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val view : Screen.env -> Screen.geometry -> t -> Screen.view
val saved : Screen.env -> Screen.geometry -> (unit, string) result -> t -> t * Screen.request
val reloaded : Screen.env -> t -> t * Screen.request
val book_changed :
  before:Bakhlo_sexp.Daily_book.t -> after:Bakhlo_sexp.Daily_book.t -> t -> t * string

(** Read-only queries for checks. *)

val months_view : t -> bool
val detail_focused : t -> bool
val scroll : t -> int
val months : t -> Scheduled_months.t
val browser : t -> Record_browser.t
(** The current view's browser (List or Months). *)

val list_browser : t -> Record_browser.t
val rows : Bakhlo_sexp.Daily_book.t -> t -> Record_browser.row list
val synced : Bakhlo_sexp.Daily_book.t -> t -> t
val selected_plan : Bakhlo_sexp.Daily_book.t -> t -> Bakhlo_sexp.Daily_book.plan option
val detail_window : Screen.env -> Screen.geometry -> t -> int * Ui_panel.window
val with_query : Bakhlo_sexp.Daily_book.t -> t -> string -> t
