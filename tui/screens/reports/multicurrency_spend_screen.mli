(** Multicurrency Spend screen: explicit Start/End window sources and an
    immutable report answer cached only after an explicit Run. *)

type t

val config_files : string list
val create : unit -> t

val enter : Screen.env -> focus_day:string -> t -> t
(** First entry seeds Calendar Month around [focus_day] and focuses Run; later
    entries keep the date drafts, refresh boundary presets and clear the answer. *)

val resume : focus_day:string -> t -> t
(** The registry's env-free entry point: the first [handle]/[view] resolves the
    pending entry against the environment. *)

val window : t -> string * string
val source_label : t -> string

val result : t -> (Multicurrency_spend_report.snapshot, string) result
(** The cached answer only after an explicit Run; an [Error] before Run, after
    any edit/source change/reset/reload/book change, and after a failed Run. *)

val modal : t -> bool
val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val saved : Screen.env -> Screen.geometry -> (unit, string) result -> t -> t * Screen.request
val reloaded : Screen.env -> t -> t * Screen.request

val book_changed :
  before:Bakhlo_sexp.Daily_book.t -> after:Bakhlo_sexp.Daily_book.t -> t -> t * string

val view : Screen.env -> Screen.geometry -> t -> Screen.view
