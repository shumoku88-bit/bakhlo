(** Positioned transient pane shared by screen owners and the terminal renderer. *)
type frame = {
  origin_x : int;
  origin_y : int;
  pane_width : int;
  pane_height : int;
  rows : (Ui_render.style * string) list;
  cursor : (int * int) option;
}

val modal_width : body:int * int -> int
(** Width of a centered modal form pane inside the body region. *)

val form :
  width_of:(string -> int) -> screen:int * int -> body:int * int -> ?pane_width:int ->
  Ui_form.t -> frame option
(** Frame a form centered in the body region; [None] when the body is too small
    to show any frame. The caret position follows the painted rows. *)

val form_fits : width_of:(string -> int) -> body:int * int -> Ui_form.t -> bool
(** Every row of a review form is visible at a readable width; confirmations
    must refuse otherwise instead of saving content the user could not see. *)
