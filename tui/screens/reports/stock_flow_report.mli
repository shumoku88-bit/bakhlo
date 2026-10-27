(* Stock-Flow Report: single-measure tracked balance motion over explicit
   boundaries, reconstructed on zero-origin, bounded history or an opening
   entry. *)
module B = Bakhlo_household.Daily_book
module IncExp = Income_expense_report

type support =
  | Zero_origin
  | Bounded of string  (** Bounded history start. *)
  | Before_start of string  (** Bounded start lies after the window start. *)
  | Opening of string  (** Opening entry dated here: the balance is exact from then. *)
  | Opening_after of string  (** The window ends before the opening entry. *)
  | Opening_on of string  (** Opening entry is dated on the window's first day. *)
  | Opening_inside of string  (** The window contains the opening entry. *)
  | Observation_undated  (** An exact confirmation with no dated boundary. *)
  | Unsupported of string

type coordinate_activity = {
  locus : string;
  support : support;
  start_balance : Z.t option;
  increases : Z.t;
  decreases : Z.t;
  net_change : Z.t option;  (** End minus start; unknown when a boundary is. *)
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
  net_change : Z.t option;
      (** The tracked motion. Unknown when an opening entry was left out of the
      flows: Start and End still carry it, so the motion is not the sum of the
      in-window flows. *)
  current_tracked : Z.t;  (** Sum of the known current quantities. *)
  coordinates : coordinate_activity list;
  liabilities : coordinate_activity list;
  unsupported : (string * string) list;  (** Locus and its support state. *)
  excluded_openings : (string * string) list;
      (** The id and the day of each opening entry left out of the flows. *)
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
(** Reconstructs the window on the supported routes: zero-origin, bounded
    history ([Daily_book.pool_at_end_of_day]) or an opening entry, whose balance
    is exact from the opening entry's own day and anchored on Core's current
    quantity. A coordinate whose history starts after the window start reports
    an unknown start (never zero) and stays in the table; a coordinate without
    support is listed instead of refusing the report. *)

val render_summary_lines :
  width:int ->
  width_of:(string -> int) ->
  book:B.t ->
  report:report ->
  (Daily_overlays.style * string) list

val print_summary : book:B.t -> report:report -> string list
