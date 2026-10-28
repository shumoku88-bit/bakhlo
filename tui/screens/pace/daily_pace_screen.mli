(** Daily Pace screen owner: LOAM Home [d] spending guide, retrospective trend,
    What-If simulation and the explicit pool / cycle-boundary editors.

    Writes only through {!Screen.Save_config} with the bytes captured when an
    editor opened; a review that does not fully fit the terminal refuses. *)

type t

val config_files : string list
(** Configuration files whose captured bytes this screen reads. *)

val create : unit -> t

val enter : t -> t
(** Route entry: trend pane, top of detail, no editor. Retained pool draft survives. *)

val modal : t -> bool
val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val saved : Screen.env -> Screen.geometry -> (unit, string) result -> t -> t * Screen.request
val view : Screen.env -> Screen.geometry -> t -> Screen.view

val open_pool : Screen.env -> t -> t
(** Pool editor over any route (Commands); resumes this Measure's retained draft. *)

val open_cycle : Screen.env -> t -> t * Screen.request
(** Cycle-boundary editor over any route (Commands). *)

(** {2 Queries for checks} *)

val form : t -> Ui_form.t option

val with_form : Ui_form.t -> t -> t
(** Replace the open editor's form content, as typing would. *)

val trend : t -> Daily_pace_trend.t
val detail_focused : t -> bool
val detail_scroll : t -> int
val resolve_pool : Screen.env -> (Bakhlo_domain.Effect_coordinate.t list, string) result
val resolve_window : Screen.env -> (string * string, string) result
val current_pace : Screen.env -> (Bakhlo_household.Book.daily_pace * string * string, string) result
val detail_viewport : Screen.env -> Screen.geometry -> t -> Ui_panel.window
