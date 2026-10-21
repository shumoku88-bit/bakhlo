(* Stock-Flow Report: single-measure tracked balance motion review matching LOAM. *)
module B = Bakhlo_sexp.Daily_book
module IncExp = Income_expense_report

type coordinate_activity = {
  locus : string;
  start_balance : Z.t;
  increases : Z.t;
  decreases : Z.t;
  net_change : Z.t;
  end_balance : Z.t;
  current_balance : Z.t;
}

type snapshot = {
  period : IncExp.period;
  measure : string;
  reconstructed_start : Z.t;
  reconstructed_end : Z.t;
  increases_across_events : Z.t;
  decreases_across_events : Z.t;
  net_change : Z.t;
  current_tracked : Z.t;
  coordinates : coordinate_activity list;
}

type report = snapshot
type t = { preset : IncExp.period_preset; period_offset : int }

val initial : unit -> t

val compute_report :
  book:B.t ->
  measure:string ->
  tracked_coords:(string * string) list ->
  period:IncExp.period ->
  (report, string) result

val render_summary_lines :
  width:int ->
  width_of:(string -> int) ->
  book:B.t ->
  report:report ->
  (Daily_overlays.style * string) list

val render_detail_lines :
  width:int ->
  width_of:(string -> int) ->
  book:B.t ->
  report:report ->
  (Daily_overlays.style * string) list

val print_summary : book:B.t -> report:report -> string list
