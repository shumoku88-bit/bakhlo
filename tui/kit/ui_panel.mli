(** Read-only framed panels. Callers own content, focus, selection identity and actions. *)

type window = { capacity : int; start : int; last : int }

val capacity : height:int -> heading:bool -> int
(** Visible data rows, excluding borders and a heading when height permits one. *)

val move : last:int -> position:int -> int -> int
(** Clamp first, then move without integer overflow, including [min_int]/[max_int]. *)

val window : capacity:int -> count:int -> scroll:int -> selected:int option -> window
(** A selected row follows the viewport; otherwise use the clamped scroll offset. *)

val frame :
  ?heading:string ->
  width_of:(string -> int) -> width:int -> height:int -> focused:bool ->
  title:string -> scroll:int -> selected:int option -> string list ->
  (Ui_render.style * string) list
(** Uses the same capacity/window rules as navigation. No domain or publication decisions. *)

val frame_rows :
  width_of:(string -> int) -> width:int -> height:int -> focused:bool ->
  title:string -> (Ui_render.style * string) list ->
  (Ui_render.style * string) list
(** Non-selected styled content; input metadata is translated by the frame inset. *)

val split_widths : int -> int * int
(** Left and right pane widths of a two-pane browser; equal full widths below 80 cells. *)

val split :
  ?left_heading:string ->
  width_of:(string -> int) -> width:int -> height:int ->
  left_focused:bool -> left_title:string -> left_scroll:int -> left_selected:int option ->
  left_rows:string list ->
  right_focused:bool -> right_title:string -> right_scroll:int -> right_selected:int option ->
  right_rows:string list -> unit ->
  (Ui_render.style * string) list
(** Two framed panes side by side from 80 cells; narrower shows only the focused pane. *)
