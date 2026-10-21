(** Liquidity screen: two unconditional unknowns, one editable ephemeral
    assumption, and a conditional path only after an explicit Run. *)

type t

val config_files : string list
(** balance-view.tsv only. *)

val create : unit -> t

val enter : focus_day:string -> t -> t
(** First entry seeds the selected day's Gregorian month end and focuses Run;
    later entries preserve the edited draft. *)

val assumption : t -> string
(** The current assumed complete-through date text; [""] when emptied. *)

val run_focused : t -> bool

val result : Screen.env -> t -> (Liquidity_report.snapshot, string) result
(** Derived from the current environment for the requested draft only; an
    [Error] before Run, after any edit, and after book reload/change. *)

val modal : t -> bool
val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val saved : Screen.env -> Screen.geometry -> (unit, string) result -> t -> t * Screen.request
val reloaded : Screen.env -> t -> t * Screen.request

val book_changed :
  before:Bakhlo_sexp.Daily_book.t -> after:Bakhlo_sexp.Daily_book.t -> t -> t * string

val view : Screen.env -> Screen.geometry -> t -> Screen.view
