(** Positioned transient pane shared by screen owners and the terminal renderer. *)
type frame = {
  origin_x : int;
  origin_y : int;
  pane_width : int;
  pane_height : int;
  rows : (Daily_overlays.style * string) list;
  cursor : (int * int) option;
}
