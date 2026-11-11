(** Read-only framed panels. Callers own content, focus, selection identity and actions. *)

type window = { capacity : int; start : int; last : int }

val capacity : height:int -> heading:bool -> int
(** Visible data rows, excluding borders and a heading when height permits one. *)

val move : last:int -> position:int -> int -> int
(** Clamp first, then move without integer overflow, including [min_int]/[max_int]. *)

val clamp_index : count:int -> int -> int
(** The nearest index of a [count]-row list; 0 when it is empty. *)

val window : capacity:int -> count:int -> scroll:int -> selected:int option -> window
(** The clamped scroll offset, moved only as far as needed to show a selected row. *)

val frame :
  ?heading:string ->
  width_of:(string -> int) ->
  width:int ->
  height:int ->
  focused:bool ->
  title:string ->
  scroll:int ->
  selected:int option ->
  string list ->
  (Ui_render.style * string) list
(** Uses the same capacity/window rules as navigation. No domain or publication decisions. *)

val frame_rows :
  ?inset:int ->
  ?bottom_label:string ->
  width_of:(string -> int) ->
  width:int ->
  height:int ->
  focused:bool ->
  title:string ->
  (Ui_render.style * string) list ->
  (Ui_render.style * string) list
(** Non-selected styled content; input metadata is translated by the frame inset.
    Default [inset=2] preserves the existing comfortable frame; [inset=0]
    uses the whole inner rectangle, matching LOAM workspaces. *)

val preview :
  width_of:(string -> int) ->
  width:int ->
  height:int ->
  title:string ->
  scroll:int ->
  notice:string ->
  action:string ->
  string list ->
  (Ui_render.style * string) list
(** A scrolled frame over [rows] that uses two rows fewer than [height], followed
    by a clipped [Status] notice row and a clipped [Active] action row. *)

val preview_window : ?selected:int -> height:int -> count:int -> scroll:int -> unit -> window
(** The window of {!preview}'s frame over [count] rows. *)

val review_scroll : window -> Ui_input.input -> int
(** The scroll start after a review key: j/k and Up/Down by line, PgUp/PgDn and
    Ctrl-U/D by page, Home/End to the ends. Any other key keeps [view.start]. *)

val split_left_scroll : height:int -> count:int -> scroll:int -> int -> int
(** The offset {!split} paints its left list from (no heading, [height] tall) once the
    selection is at the given row: [scroll] kept while that row stays in view. A screen
    keeps it and passes it back as [left_scroll]. *)

val split_widths : int -> int * int
(** Left and right pane widths of a two-pane browser; equal full widths below 80 cells. *)

val split :
  ?left_heading:string ->
  width_of:(string -> int) ->
  width:int ->
  height:int ->
  left_focused:bool ->
  left_title:string ->
  left_scroll:int ->
  left_selected:int option ->
  left_rows:string list ->
  right_focused:bool ->
  right_title:string ->
  right_scroll:int ->
  right_selected:int option ->
  right_rows:string list ->
  unit ->
  (Ui_render.style * string) list
(** Two framed panes side by side from 80 cells; narrower shows only the focused pane. *)
