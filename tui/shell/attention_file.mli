(* Attention memory file: lookup, strict load and checked atomic save under the writer lock. *)
open Attention_data

val file_path : ?config_home:string -> string -> string

val load_file : string -> (t, string) result
(** Only a missing file means an empty trial; unreadable or invalid inputs refuse. *)

val save_file : string -> expected:t -> t -> (unit, string) result
(** Recheck the loaded state under the existing cooperative writer lock. *)
