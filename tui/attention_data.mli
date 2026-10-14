(** attention_data.mli - Attention model, serialization, and lifecycle operations *)

type due =
  | Due_on of string
  | No_due_date
  | Due_undetermined

type closure_kind =
  | Resolved
  | Dropped

type item = {
  id : string;
  context : string;
  due : due;
}

type closure = {
  attention : string;
  known_on : string;
  kind : closure_kind;
}

type t = {
  items : item list;
  closures : closure list;
}

val empty : t

val open_items : t -> item list
val closed_items : t -> item list
val is_closed : t -> string -> bool
val find_item : t -> string -> item option
val next_id : t -> string

val add_item : t -> id:string -> context:string -> due:due -> (t, string) result
val close_item : t -> id:string -> known_on:string -> kind:closure_kind -> (t, string) result

val due_label : due -> string
val closure_kind_label : closure_kind -> string

val escape_text : string -> string
val unescape_text : string -> (string, string) result

val of_string : string -> (t, string) result
val to_string : t -> string

val file_path : ?config_home:string -> string -> string
val load_file : string -> (t, string) result
(** Only a missing file means an empty trial; unreadable or invalid inputs refuse. *)
val save_file : string -> expected:t -> t -> (unit, string) result
(** Recheck the loaded state under the existing cooperative writer lock. *)
