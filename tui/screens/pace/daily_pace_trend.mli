(* Daily Pace Trend: retrospective current-truth spending pace analysis over 10d, 30d, month, cycle. *)
module B = Bakhlo_sexp.Daily_book

type preset = Ten_days | Thirty_days | Month | Cycle | Previous_cycle

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
(** Restated current-truth history, not an as-known-at-day log. Each date uses
    its explicit window in today's uniquely selected named cycle preset.
    Past quantities require historical support; unsupported dates stay unknown.
    Retained paid occurrences reserve their net Pool drain until their Actual
    payment date; cancelled occurrences are closed throughout the reconstruction.
    Overdue open occurrences count without a lower due-date bound. *)

val day_number : string -> int
(** Proleptic Gregorian day ordinal of a valid ISO date; 0 when invalid. *)

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
(** Selected date/pace plus change/activity or partial-support summary, braille
    plot and full-date axis; tiny panes retain the exact selected amount when
    it fits. History rows live in {!render_history}. *)

val render_history :
  width:int ->
  height:int ->
  width_of:(string -> int) ->
  book:B.t ->
  today:string ->
  measure:string ->
  samples:sample list ->
  selected_index:int ->
  detail_focused:bool ->
  (Daily_overlays.style * string) list
(** LOAM History rows for an inner [height]: blank, heading and a trailing
    window of [height - 2] dates; empty below one date row. Partial history's
    narrow Value / status fallback keeps its selected marker during detail focus. *)

val change_preset :
  today:string -> boundary_presets_text:string option -> t -> preset -> (t, string) result
(** Preset switch preserving the selected calendar date when the old range
    resolves; clamps to the new range, falls back to today when the old
    date is unavailable. A refused new range is an error, never a reset. *)

val move_selection :
  today:string ->
  preset:preset ->
  boundary_presets_text:string option ->
  position:int ->
  int ->
  (int, string) result
(** Clamp to the resolved range before stepping; range failure stays explicit. *)

val render_detail :
  width:int ->
  width_of:(string -> int) ->
  book:B.t ->
  measure:string ->
  samples:sample list ->
  selected_index:int ->
  today:string ->
  preset:preset ->
  (Daily_overlays.style * string) list
(** LOAM Selected day lines, already wrapped to [width]: full history when every
    day is supported, otherwise Supported k/n with unknown dates as gaps. *)
