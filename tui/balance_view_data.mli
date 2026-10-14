(** balance_view_data.mli - Balance view configuration (balance-view.tsv) *)

type coordinate = {
  locus : string;
  measure : string;
}

type t = coordinate list

val empty : t
val of_string : string -> t
val to_string : t -> string
val file_path : ?config_home:string -> string -> string
val load_file : string -> t
val save_file : string -> t -> (unit, string) result
