(* Daily Pace Trend: retrospective current-truth spending pace analysis over 10d, 30d, month, cycle. *)
module B = Bakhlo_sexp.Daily_book

type preset =
  | Ten_days
  | Thirty_days
  | Month
  | Cycle
  | Previous_cycle

type day_activity = {
  discretionary_outflow : Z.t;
  discretionary_inflow : Z.t;
  scheduled_settled_outflow : Z.t;
  scheduled_settled_inflow : Z.t;
  scheduled_reserved_outflow : Z.t;
}

type sample = {
  day : string;
  pace_quanta : Z.t option;
  available_through_end : Z.t;
  pool_balance : Z.t;
  deductions : Z.t;
  remaining_days : int;
  end_exclusive : string;
  activity : day_activity option;
  unavailable : string option;
}

type change_breakdown = {
  previous_pace : Z.t;
  current_pace : Z.t;
  change_per_day : Z.t;
  time_passage_effect : Z.t;
  free_money_effect : Z.t;
  pool_balance_change : Z.t;
  protection_release : Z.t;
  free_through_end_change : Z.t;
}

type graph_style = Line | Dots

type t = {
  preset : preset;
  selected_index : int;
  graph_style : graph_style;
  detail_focused : bool;
  detail_scroll : int;
}

val initial : unit -> t
val preset_label : preset -> string
val presets : preset list
val next_graph_style : graph_style -> graph_style
val graph_style_label : graph_style -> string

val format_pace_error : string -> string
(** Reader-facing cause of a refused Daily Pace calculation; unknown causes pass through. *)

val zero_activity : day_activity
(** All-zero daily activity for days with no pool movement. *)

val compute_samples :
  book:B.t ->
  measure:string ->
  pool:string list ->
  boundary_presets_text:string option ->
  today:string ->
  preset:preset ->
  (string * string * sample list, string) result

val compare_change : prev:sample -> current:sample -> (change_breakdown, string) result
(** Guarded adjacent-day decomposition; error names the refusal cause. *)

val render_chart :
  width:int ->
  height:int ->
  width_of:(string -> int) ->
  book:B.t ->
  today:string ->
  measure:string ->
  samples:sample list ->
  selected_index:int ->
  graph_style:graph_style ->
  (Daily_overlays.style * string) list
(** Summary plus braille plot and date axis; history rows live in {!render_history}. *)

val render_history :
  width:int ->
  height:int ->
  width_of:(string -> int) ->
  book:B.t ->
  measure:string ->
  samples:sample list ->
  selected_index:int ->
  (Daily_overlays.style * string) list
(** History table; full width (>= 46) with activity shows Day | Quanta/day | Spent | Pace diff. *)


val move_selection :
  today:string ->
  preset:preset ->
  boundary_presets_text:string option ->
  position:int ->
  int ->
  (int, string) result
(** Bounded pace cursor: real last sample from the resolved range, clamped
    before stepping. Range failure is an explicit error, never a zero sample. *)

val render_detail :
  width:int ->
  width_of:(string -> int) ->
  book:B.t ->
  measure:string ->
  sample:sample option ->
  prev_sample:sample option ->
  today:string ->
  preset:preset ->
  (Daily_overlays.style * string) list
