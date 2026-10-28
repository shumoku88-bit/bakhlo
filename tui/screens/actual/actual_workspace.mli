(* ActualWorkspace: the Actuals workspace (UI-03 / UI-04). The list is grouped
   by day inside a period window; the Screen owns the window and the Shell's
   environment, the workspace owns the state and the painting. *)

module B = Bakhlo_household.Book
module Roles = Locus_roles

type period = Today | Cycle | Month | Year | All
type sort_order = Newest | Oldest | Largest
type pane = Loci | Transactions | Details
type window = { start_day : string; end_exclusive : string; label : string }

type scope = {
  window : window;
  today : string;
  focus_day : string;
      (** The day the window was opened on: today, or the day of a chosen window. *)
  roles : (string * Roles.role) list;
  measure : string;
}

type context = {
  book : B.t;
  scope : scope;
  warning : string option;
      (** The window could not be resolved; the list still works and says so. *)
}

type t
type command = Stay | Open_selected of B.entry | Record_new | Back | Redraw

val create : ?focus_day:string -> unit -> t
(** Opens on the Cycle window containing [focus_day] (default: today), with that
    day's group selected. *)

val period : t -> period
val period_offset : t -> int
val focus_day : t -> string option
val sort_order : t -> sort_order
val pane : t -> pane
val locus_row : t -> int
val transaction_row : t -> int
val detail_scroll : t -> int
val search_query : t -> string
val search_editing : t -> bool
val notice : t -> string

val set_period : period -> t -> t
(** The period filter and its window start again at the current window. *)

val set_period_offset : int -> t -> t
(** The previous or next window of the same period. *)

val set_focus_day : string -> t -> t
(** Opens the same period on the window containing this day. *)

val set_window : period -> focus_day:string -> t -> t
(** Opens [period] on the window containing [focus_day], selecting that day's
    group or the latest day before it. *)

val period_name : period -> string
(** The name the period bar and the picker show. *)

val weekday_name : string -> string
(** "Mon" .. "Sun"; empty for a date that does not parse. *)

val set_scope : scope -> t -> t
(** The scope of the current render, kept for a drill return. *)

val selected_locus : ctx:context -> t -> string option
val selected_entry : ctx:context -> t -> B.entry option
val visible_entries : ctx:context -> t -> B.entry list
val returned_from_detail : before_book:B.t -> after_book:B.t -> t -> t * string

val handle :
  ctx:context ->
  dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  Ui_input.input ->
  t * command

val screen :
  ctx:context ->
  total:string option ->
  draft_retained:bool ->
  dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  (Ui_render.style * string) list

type expense_roles

val expense_roles : ctx:context -> expense_roles
(** The accounting roles of [ctx], ready for EXPENSE totals. *)

val expense_total : expense_roles -> B.entry list -> string option
(** The EXPENSE total per Measure of these entries in the shared money format,
    marked [+?] when an effect has no role. *)

val window_total : ctx:context -> string option
(** The window's EXPENSE total per Measure, in the shared money format; [total]
    is that text, already formatted for the title. *)

val footer : dimensions:int * int -> width_of:(string -> int) -> t -> string list
val search_line : width:int -> width_of:(string -> int) -> t -> Ui_render.style * string
val cursor_position : dimensions:int * int -> width_of:(string -> int) -> t -> (int * int) option

val detail_window :
  ctx:context -> dimensions:int * int -> width_of:(string -> int) -> t -> Ui_panel.window
(** Details pane viewport for the content dimensions the workspace is given. *)
