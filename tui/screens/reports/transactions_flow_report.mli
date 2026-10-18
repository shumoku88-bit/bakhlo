(* Transactions Flow Report: incidence matrix of activity per coordinate, sorted by gross volume. *)
module B = Bakhlo_sexp.Daily_book
module IncExp = Income_expense_report

type row_activity = {
  locus : string;
  measure : string;
  positive : Z.t;
  negative : Z.t;
  net : Z.t;
  gross : Z.t;
  active_events : int;
  contributions : (string * Z.t * string * string) list;
}

type report = {
  period : IncExp.period;
  rows : row_activity list;
}

type t = {
  preset : IncExp.period_preset;
  period_offset : int;
  selected_row : int;
  detail_focused : bool;
  detail_scroll : int;
}

val initial : unit -> t

val compute_report :
  book:B.t ->
  period:IncExp.period ->
  report

val render_summary_lines :
  width:int ->
  width_of:(string -> int) ->
  book:B.t ->
  report:report ->
  selected_row:int ->
  (Daily_overlays.style * string) list

val render_detail_lines :
  width:int ->
  width_of:(string -> int) ->
  book:B.t ->
  report:report ->
  selected_row:int ->
  (Daily_overlays.style * string) list

val print_summary :
  book:B.t ->
  report:report ->
  string list
