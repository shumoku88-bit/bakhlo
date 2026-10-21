(** ui_form.mli - Common modal form component for Bakhlo TUI *)

type button = { label : string; is_cancel : bool }

type field_kind =
  | Text of { value : string; placeholder : string }
  | Choice of { options : string list; selected : int }
  | Buttons of { buttons : button list; selected : int }

type field = { id : string; label : string; kind : field_kind }

type t = {
  id : string;
  payload : string;
  title : string;
  summary : string list;
  fields : field list;
  focused : int;
  notice : string;
}

type event = Updated of t | Submit of t | Cancel

val create :
  id:string ->
  ?payload:string ->
  title:string ->
  ?summary:string list ->
  ?fields:field list ->
  ?notice:string ->
  unit ->
  t

val text_field : id:string -> label:string -> ?value:string -> ?placeholder:string -> unit -> field

val choice_field :
  id:string -> label:string -> options:string list -> ?selected:int -> unit -> field

val buttons_field : id:string -> buttons:button list -> ?selected:int -> unit -> field
val action_buttons : ?id:string -> ?confirm:string -> ?cancel:string -> unit -> field
val id : t -> string
val payload : t -> string
val title : t -> string
val notice : t -> string
val set_notice : t -> string -> t
val focused : t -> int
val set_focused : t -> int -> t
val get_field : t -> string -> field option
val find_field_index : t -> string -> int
val update_field : t -> string -> (field_kind -> field_kind) -> t
val get_text : t -> string -> string option
val set_text : t -> string -> string -> t
val get_choice : t -> string -> int option
val get_choice_value : t -> string -> string option
val set_choice : t -> string -> int -> t
val get_button : t -> string -> int option
val get_selected_button : t -> button option
val get_selected_button_index : t -> int
val handle_input : t -> Ui_input.input -> event

val render_rows :
  width:int -> height:int -> width_of:(string -> int) -> t -> (Ui_render.style * string) list
