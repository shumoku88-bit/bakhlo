(** Stock–Flow's text: the core's reconstruction ({!Bakhlo_household.Stock_flow})
    with the window's label and each Measure's money format. *)

module B = Bakhlo_household.Book
module IncExp = Income_expense_report

type t = { preset : IncExp.period_preset; period_offset : int }

val initial : unit -> t

val render_summary_lines :
  width:int ->
  width_of:(string -> int) ->
  book:B.t ->
  period:IncExp.period ->
  report:Bakhlo_household.Stock_flow.snapshot ->
  (Ui_render.style * string) list

val print_summary :
  book:B.t -> period:IncExp.period -> report:Bakhlo_household.Stock_flow.snapshot -> string list
