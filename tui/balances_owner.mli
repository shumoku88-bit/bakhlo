(** balances_owner.mli - Vertical owner for Balances screen.
    Consolidates local state (mode, selected, pane, scroll, config picker, print preview),
    queries, input handling, rendering, and footer into a single feature boundary.
    Emits typed intents (Stay, Back_to_home, Open_commands, Cycle_measure, Observe, Save_balance_view, Reload)
    to Shell without direct writer or central controller dependencies. *)

module B = Bakhlo_sexp.Daily_book
module O = Daily_overlays

type mode = [ `Current | `Accounting ]
type pane = [ `List | `Detail ]
type overlay_frame = {
  origin_x : int;
  origin_y : int;
  pane_width : int;
  pane_height : int;
  rows : (O.style * string) list;
  cursor : (int * int) option;
}

type command =
  | Stay
  | Back_to_home
  | Open_commands
  | Cycle_measure of [ `Next | `Prev ]
  | Observe of { locus : string; measure : string; amount : Z.t option }
  | Save_balance_view of { expected : string option; content : string }
  | Reload

type t

val create : unit -> t

val mode : t -> mode
val pane : t -> pane
val selected : t -> int
val notice : t -> string
val title : t -> string

val set_selected : int -> t -> t

val active_form : t -> Ui_form.t option

val has_overlay : t -> bool
val overlay :
  dimensions:int * int ->
  body_dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  overlay_frame option

val cursor_position :
  dimensions:int * int ->
  body_dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  (int * int) option
val items :
  book:B.t ->
  measure:string ->
  roles:(string * O.accounting_role) list ->
  balance_view_text:(string option, string) result ->
  t ->
  O.balance_item list

val selected_coordinate :
  book:B.t ->
  measure:string ->
  roles:(string * O.accounting_role) list ->
  balance_view_text:(string option, string) result ->
  t ->
  (string * string) option

val selected_account :
  book:B.t ->
  measure:string ->
  roles:(string * O.accounting_role) list ->
  balance_view_text:(string option, string) result ->
  t ->
  (string * string * Z.t option) option
val print_fits : string list -> bool
val print_preview_summary : t -> string list option


val print_preview_form :
  book:B.t ->
  measure:string ->
  roles:(string * O.accounting_role) list ->
  balance_view_text:(string option, string) result ->
  t ->
  Ui_form.t

val detail_viewport :
  dimensions:int * int ->
  width_of:(string -> int) ->
  book:B.t ->
  measure:string ->
  roles:(string * O.accounting_role) list ->
  balance_view_text:(string option, string) result ->
  t ->
  string list * Ui_panel.window

val open_config :
  book:B.t ->
  measure:string ->
  balance_view_text:(string option, string) result ->
  t ->
  t

val notify_saved : t -> t
val notify_save_failed : t -> string -> t

val handle :
  blocked:bool ->
  book:B.t ->
  measure:string ->
  roles:(string * O.accounting_role) list ->
  balance_view_text:(string option, string) result ->
  dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  Ui_input.input ->
  t * command

val screen :
  book:B.t ->
  measure:string ->
  roles:(string * O.accounting_role) list ->
  balance_view_text:(string option, string) result ->
  dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  (O.style * string) list

val footer :
  dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  string list
