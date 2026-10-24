(** Trend / Locus comparison screen owner (read-only).

    A full-chart owner of recorded EFFECT flow for one explicit Measure. The
    owner never writes a file, never reads the clock and never keeps a stale
    chart: a kept projection is reused only for the same book value and equal
    configuration, roles, Measure and query, so moving the selection never
    projects again while any change does. The selection is an immutable period;
    the effective point index is derived from the current projection. It is
    painted like LOAM's full-screen Trend. *)

type t

val config_files : string list
(** Configuration files this screen reads; the boundary presets only. *)

val create : unit -> t

val enter : focus_day:string -> t -> t
(** Capture the Shell's focus day as the observation day of the chart. *)

val modal : t -> bool
(** [true] while the session-only annotation editor is open. *)

val saved : Screen.env -> Screen.geometry -> (unit, string) result -> t -> t * Screen.request
(** The owner writes no file; a save outcome changes nothing. *)

val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val view : Screen.env -> Screen.geometry -> t -> Screen.view

(** {2 Queries for checks} *)

val result : Screen.env -> t -> (Trend_locus_report.snapshot, string) result
(** The current projection of the current book and configuration; an error
    never returns a stale chart. *)

val selected : Screen.env -> t -> int
(** The effective selected point index of the current projection; the last
    point until the user scrubs. *)

val selected_period : t -> (string * string) option
(** The selected period, kept across a grain or query change. *)

val visible_window : Screen.env -> t -> int * int
(** The shown points [[start, stop)]: every point, except that Day over all
    history shows 31 and moves only when the selection leaves them. *)

val grain : t -> Trend_locus_report.grain

val scope : t -> Trend_locus_report.scope
(** The effective scope; other grains always report {!All_history}. *)

val coordinates : Screen.env -> t -> Trend_locus_report.coordinate list
(** The plotted coordinates; the default catalog selection until the user
    chooses one in the series picker. *)

val overlay_count : t -> int
(** The number of session-only annotations drawn. *)

val overlays : t -> (string * string * int list) list
(** The session-only annotations: captured month, name and marked day numbers. *)

val guides : t -> bool
(** Whether the vertical day guides are drawn. *)

val notice : t -> string
(** The last notice shown by this screen. *)

val catalog : Screen.env -> t -> Trend_locus_report.coordinate list
val picker_open : t -> bool

val picker_target : t -> int option
(** The slot the series picker edits. *)

val picker_cursor : t -> int option
(** The candidate the series picker points at. *)

val editor_open : t -> bool
val editor_name : t -> string
val editor_days : t -> string

val editor_field : t -> [ `Name | `Days ]
(** The state of the inline annotation editor, for checks that drive its keys. *)
