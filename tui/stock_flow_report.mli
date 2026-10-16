(* Stock-Flow Report: reconciliation of tracked balance changes (Stock) with window activity (Flow). *)
module B = Bakhlo_sexp.Daily_book
module IncExp = Income_expense_report

type coordinate_activity = {
  locus : string;
  measure : string;
  start_balance : Z.t;
  increases : Z.t;
  decreases : Z.t;
  net_change : Z.t;
  end_balance : Z.t;
  current_balance : Z.t;
}

type measure_summary = {
  measure : string;
  reconstructed_start : Z.t;
  reconstructed_end : Z.t;
  increases : Z.t;
  decreases : Z.t;
  net_change : Z.t;
  current_tracked : Z.t;
  net_income : Z.t;
  reconciliation_gap : Z.t;
  coordinates : coordinate_activity list;
}

type report = {
  period : IncExp.period;
  summaries : measure_summary list;
}

type t = {
  preset : IncExp.period_preset;
  period_offset : int;
  selected_measure : int;
  detail_focused : bool;
  detail_scroll : int;
}

val initial : unit -> t

val compute_report :
  book:B.t ->
  roles:(string * Daily_overlays.accounting_role) list ->
  tracked_coords:(string * string) list ->
  period:IncExp.period ->
  report

val render_summary_lines :
  width:int ->
  width_of:(string -> int) ->
  book:B.t ->
  report:report ->
  selected_measure:int ->
  (Daily_overlays.style * string) list

val render_detail_lines :
  width:int ->
  width_of:(string -> int) ->
  book:B.t ->
  report:report ->
  selected_measure:int ->
  (Daily_overlays.style * string) list

val print_summary :
  book:B.t ->
  report:report ->
  string list
