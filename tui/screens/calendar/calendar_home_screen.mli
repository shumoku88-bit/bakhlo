type t
val config_files : string list
val create : unit -> t
val browser : t -> Record_browser.t
val with_browser : t -> Record_browser.t -> t
val detail_focused : t -> bool
val scroll : t -> int
val back_to_list : t -> t option
val modal : t -> bool
(** Ambient text overlay keeps the current route underneath. *)
val ambient : t -> bool
(** Notify every route entry; Selected Day keeps this browser when synchronized. *)
val entered : Screen.route -> focus_day:string -> t -> t
(** Preserve legacy empty-route selection resets with current Shell focus. *)
val synchronize : route:Screen.route -> book:Bakhlo_sexp.Daily_book.t -> calendar:Daily_calendar.t -> t -> t
val rows : book:Bakhlo_sexp.Daily_book.t -> calendar:Daily_calendar.t -> t -> Record_browser.row list
val selected_row : book:Bakhlo_sexp.Daily_book.t -> calendar:Daily_calendar.t -> t -> Record_browser.row option
val start_search : ?value:string -> t -> t
val start_jump : string -> t -> t
val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val ambient_handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val view : Screen.env -> Screen.geometry -> t -> Screen.view
val reloaded : Screen.env -> t -> t * Screen.request
val book_changed : before:Bakhlo_sexp.Daily_book.t -> after:Bakhlo_sexp.Daily_book.t -> t -> t * string
