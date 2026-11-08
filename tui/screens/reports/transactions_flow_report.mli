(* Transactions Flow Report: incidence matrix of activity per coordinate, sorted by gross volume. *)
module B = Bakhlo_household.Book
module IncExp = Income_expense_report
module TF = Bakhlo_household.Transactions_flow

type row_activity = TF.row = {
  locus : string;
  measure : string;
  increase : Z.t;
  decrease : Z.t;
  net : Z.t;
  gross : Z.t;
  moves : TF.move list;
}

type report = { period : IncExp.period; rows : row_activity list }

type t = {
  preset : IncExp.period_preset;
  period_offset : int;
  selected_row : int;
  detail_focused : bool;
  detail_scroll : int;
}

val initial : unit -> t
val compute_report : book:B.t -> period:IncExp.period -> report

val render_summary_lines :
  width:int ->
  width_of:(string -> int) ->
  book:B.t ->
  report:report ->
  selected_row:int ->
  (Ui_render.style * string) list

val render_detail_lines :
  book:B.t -> report:report -> selected_row:int -> (Ui_render.style * string) list

val print_summary : book:B.t -> report:report -> string list
