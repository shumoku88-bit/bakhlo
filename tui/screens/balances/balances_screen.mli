(** Balances screen owner: Current visible accounts and the Accounting role
    view, per-coordinate detail, the visible-account picker and print preview.
    Unknown balances stay unknown; the picker saves only through
    {!Screen.Save_config} with the bytes captured when it opened. *)

type t

val config_files : string list
val create : unit -> t
val modal : t -> bool
val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val saved : Screen.env -> Screen.geometry -> (unit, string) result -> t -> t * Screen.request
val view : Screen.env -> Screen.geometry -> t -> Screen.view

val open_config : Screen.env -> t -> t * Screen.request
(** Visible-account picker for the Shell-selected Measure (Commands entry). *)

(** {2 Queries for checks} *)

val mode : t -> [ `Current | `Accounting ]
val title : t -> string
val selected : t -> int
val set_selected : int -> t -> t
val detail_focused : t -> bool
val form : t -> Ui_form.t option
val items : Screen.env -> t -> Daily_overlays.balance_item list
val detail_viewport : Screen.env -> Screen.geometry -> t -> string list * Ui_panel.window
val print_fits : string list -> bool
val print_preview_form : Screen.env -> t -> Ui_form.t
val print_preview_summary : t -> string list option
