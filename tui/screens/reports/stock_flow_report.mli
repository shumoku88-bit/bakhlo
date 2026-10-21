(* Stock-Flow Report: single-measure tracked balance motion over explicit
   boundaries, with the shared zero-origin / bounded-history support rule. *)
module B = Bakhlo_sexp.Daily_book
module IncExp = Income_expense_report

type support =
  | Zero_origin
  | Bounded of string  (** Bounded history start. *)
  | Before_start of string  (** Bounded start lies after the window start. *)
  | Unsupported of string

type coordinate_activity = {
  locus : string;
  support : support;
  start_balance : Z.t option;
  increases : Z.t;
  decreases : Z.t;
  net_change : Z.t;
  end_balance : Z.t option;
  current_balance : Z.t option;
}

type snapshot = {
  period : IncExp.period;
  measure : string;
  reconstructed_start : Z.t;  (** Sum of the known starts only. *)
  reconstructed_end : Z.t;  (** Sum of the known ends only. *)
  unknown_starts : int;
  increases_across_events : Z.t;
  decreases_across_events : Z.t;
  net_change : Z.t;
  current_tracked : Z.t;  (** Sum of the known current quantities. *)
  coordinates : coordinate_activity list;
  liabilities : coordinate_activity list;
  unsupported : (string * string) list;  (** Locus and its support state. *)
}

type report = snapshot
type t = { preset : IncExp.period_preset; period_offset : int }

val initial : unit -> t

val compute_report :
  book:B.t ->
  measure:string ->
  tracked_coords:(string * string) list ->
  liability_coords:(string * string) list ->
  period:IncExp.period ->
  (report, string) result
(** Reconstructs the window from the one shared support rule
    ([Daily_book.pool_at_end_of_day]). A coordinate whose bounded history starts
    after the window start reports an unknown start (never zero) and stays in the
    table; a coordinate without support is listed instead of refusing the report. *)

val render_summary_lines :
  width:int ->
  width_of:(string -> int) ->
  book:B.t ->
  report:report ->
  (Daily_overlays.style * string) list

val print_summary : book:B.t -> report:report -> string list
