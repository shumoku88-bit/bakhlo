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
  (Daily_overlays.style * string) list
(** Uses the same capacity/window rules as navigation. No domain or publication decisions. *)

val frame_rows :
  width_of:(string -> int) -> width:int -> height:int -> focused:bool ->
  title:string -> (Daily_overlays.style * string) list ->
  (Daily_overlays.style * string) list
(** Non-selected styled content; input metadata is translated by the frame inset. *)
