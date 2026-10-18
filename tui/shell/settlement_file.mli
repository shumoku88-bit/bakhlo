(* Settlements file: lookup, strict load and checked atomic save under the writer lock. *)
open Settlement_data
val file_path : ?config_home:string -> string -> string
val load_file : string -> (t, string) result
(** Only a missing file means an empty trial; invalid quantities never become zero. *)
val save_file : string -> expected:t -> t -> (unit, string) result
