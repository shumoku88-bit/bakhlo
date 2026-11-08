(** balance_view_data.mli - Balance view configuration (balance-view.tsv) *)

type coordinate = { locus : string; measure : string }
type t = coordinate list

val of_string : string -> (t, string) result
val to_string : t -> string
