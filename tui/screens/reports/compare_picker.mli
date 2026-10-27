(** The window a report is compared with, chosen from the earlier windows of the
    same kind, newest first, each with its EXPENSE total. The Screen supplies the
    rows (only it reads the configured presets and the book); the picker owns the
    selection and the painting, like the Actual's period picker. *)

type row = {
  offset : int;  (** Windows before the shown one: 1 is the previous window. *)
  label : string;
  note : string;  (** "previous", "a year earlier" or empty. *)
  total : string;
}

type t

val create : row list -> offset:int -> t
(** Selects the row at [offset], else the first. *)

val selected : t -> row option

type command = Stay | Choose of int | Close

val handle : body:int * int -> t -> Ui_input.input -> t * command
(** [Choose] carries the chosen row's offset. *)

val frame :
  width_of:(string -> int) -> screen:int * int -> body:int * int -> t -> Ui_overlay.frame option

val footer : width:int -> string list
