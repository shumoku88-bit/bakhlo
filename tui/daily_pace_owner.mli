(** daily_pace_owner.mli - Vertical owner for Daily Pace screen.
    Consolidates local state (preset, selected date, graph style, pane, detail scroll,
    what-if, pool configuration, cycle boundaries configuration), queries, input handling,
    rendering, and footer into a single feature boundary.
    Emits typed intents (Stay, Back_to_home, Open_commands, Cycle_measure, Save_pool, Save_cycle, Reload)
    to Shell without direct writer or central controller dependencies. *)

module B = Bakhlo_sexp.Daily_book
module O = Daily_overlays
module Trend = Daily_pace_trend

type pane = [ `Calendar | `Detail ]

type command =
  | Stay
  | Back_to_home
  | Open_commands
  | Cycle_measure of [ `Next | `Prev ]
  | Save_pool of { expected : string option; content : string }
  | Save_cycle of { expected : string option; content : string }
  | Reload

type t

val create : unit -> t

val pane : t -> pane
val preset : t -> Trend.preset
val selected_index : t -> int
val notice : t -> string
val graph_style : t -> Trend.graph_style
val trend : t -> Trend.t
val detail_scroll : t -> int

val set_preset : Trend.preset -> t -> t
val set_selected_index : int -> t -> t

val has_overlay : t -> bool
val overlay :
  dimensions:int * int ->
  body_dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  Ui_overlay.frame option

val cursor_position :
  dimensions:int * int ->
  body_dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  (int * int) option

val active_form : t -> Ui_form.t option
val set_pool_form : Ui_form.t -> t -> t
val set_what_if_amount : string -> t -> t

val open_pool_editor :
  book:B.t ->
  measure:string ->
  daily_pace_tsv:(string option, string) result ->
  boundary_presets_tsv:(string option, string) result ->
  today:string ->
  t ->
  t
val pool_editor_form :
  measure:string ->
  daily_pace_tsv:(string option, string) result ->
  boundary_presets_tsv:(string option, string) result ->
  today:string ->
  Ui_form.t


val open_cycle_editor :
  boundary_presets_tsv:(string option, string) result ->
  today:string ->
  t ->
  t

val open_what_if :
  book:B.t ->
  measure:string ->
  daily_pace_tsv:(string option, string) result ->
  boundary_presets_tsv:(string option, string) result ->
  annual_bounds:(string * string) option ->
  today:string ->
  t ->
  t

val notify_pool_saved : t -> t
val notify_pool_save_failed : t -> string -> t
val notify_cycle_saved : t -> t
val notify_cycle_save_failed : t -> string -> t

val header_summary :
  book:B.t ->
  measure:string ->
  daily_pace_tsv:(string option, string) result ->
  boundary_presets_tsv:(string option, string) result ->
  annual_bounds:(string * string) option ->
  today:string ->
  width:int ->
  width_of:(string -> int) ->
  t ->
  string
val resolve_pace_pool :
  measure:string ->
  (string option, string) result ->
  (string list, string) result

val resolve_pace_window :
  today:string ->
  (string option, string) result ->
  (string * string, string) result

val detail_viewport :
  dimensions:int * int ->
  width_of:(string -> int) ->
  book:B.t ->
  measure:string ->
  daily_pace_tsv:(string option, string) result ->
  boundary_presets_tsv:(string option, string) result ->
  annual_bounds:(string * string) option ->
  today:string ->
  t ->
  Ui_panel.window


val current_pace :
  book:B.t ->
  measure:string ->
  daily_pace_tsv:(string option, string) result ->
  boundary_presets_tsv:(string option, string) result ->
  annual_bounds:(string * string) option ->
  today:string ->
  (B.daily_pace * string * string, string) result

val handle :
  blocked:bool ->
  book:B.t ->
  measure:string ->
  daily_pace_tsv:(string option, string) result ->
  boundary_presets_tsv:(string option, string) result ->
  annual_bounds:(string * string) option ->
  today:string ->
  dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  Ui_input.input ->
  t * command

val screen :
  book:B.t ->
  measure:string ->
  daily_pace_tsv:(string option, string) result ->
  boundary_presets_tsv:(string option, string) result ->
  annual_bounds:(string * string) option ->
  today:string ->
  dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  (O.style * string) list

val footer :
  dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  string list
