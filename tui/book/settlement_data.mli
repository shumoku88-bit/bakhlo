type row = {
  id : string;
  label : string option;
  debtor : string;
  creditor : string;
  measure : string;
  committed : Z.t;
  settled : Z.t;
  extinguished : Z.t;
  source_event : string;
  source_effect : string;
  effective_on : string option;
}

type scope = Open_only | All
type t = { rows : row list }

val empty : t
val outstanding : row -> Z.t
val is_open : row -> bool
val visible_rows : t -> scope -> row list
val find_row : t -> string -> row option
val next_id : t -> string

val add_row :
  t ->
  id:string ->
  ?label:string ->
  debtor:string ->
  creditor:string ->
  measure:string ->
  committed:Z.t ->
  ?source_event:string ->
  ?source_effect:string ->
  ?effective_on:string ->
  unit ->
  (t, string) result

val settle_row : t -> id:string -> amount:Z.t -> (t, string) result
val reduce_row : t -> id:string -> amount:Z.t -> (t, string) result
val retract_row : t -> id:string -> (t, string) result
val of_string : string -> (t, string) result
