(* Daily Pace Trend: retrospective current-truth spending pace analysis over 10d, 30d, month, cycle. *)
module B = Bakhlo_sexp.Daily_book

type preset =
  | Ten_days
  | Thirty_days
  | Month
  | Cycle
  | Previous_cycle

type sample = {
  day : string;
  pace_quanta : Z.t option;
  available_through_end : Z.t;
  pool_balance : Z.t;
  deductions : Z.t;
  remaining_days : int;
  end_exclusive : string;
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

val compute_samples :
  book:B.t ->
  measure:string ->
  pool:string list ->
  boundary_presets_text:string option ->
  today:string ->
  preset:preset ->
  (string * string * sample list, string) result

val move_selection :
  today:string ->
  preset:preset ->
  boundary_presets_text:string option ->
  position:int ->
  int ->
  (int, string) result
(** Bounded pace cursor: real last sample from the resolved range, clamped
    before stepping. Range failure is an explicit error, never a zero sample. *)

val render_trend :
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
