type t
(** Selected Day browser, input and rendering. Record actions request the existing Shell writer. *)

val config_files : string list
val create : unit -> t
val enter : Screen.route -> focus_day:string -> t -> t
val drill : entry:string -> parent:string -> t -> t
val modal : t -> bool
val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val view : Screen.env -> Screen.geometry -> t -> Screen.view
val saved : Screen.env -> Screen.geometry -> (unit, string) result -> t -> t * Screen.request
val reloaded : Screen.env -> t -> t * Screen.request

val book_changed :
  before:Bakhlo_household.Daily_book.t -> after:Bakhlo_household.Daily_book.t -> t -> t * string

val browser : t -> Record_browser.t
val with_browser : t -> Record_browser.t -> t
val detail_focused : t -> bool
val scroll : t -> int
val rows : Bakhlo_household.Daily_book.t -> t -> Record_browser.row list
val synced : Bakhlo_household.Daily_book.t -> t -> t
val selected_row : Bakhlo_household.Daily_book.t -> t -> Record_browser.row option
