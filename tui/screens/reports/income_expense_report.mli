(* Income & Expense Report: period-based P/L analysis by month, cycle, year, or all-time. *)
module B = Bakhlo_sexp.Daily_book
module Roles = Locus_roles

type period_preset = Month | Cycle | Previous_cycle | Year | All_time
type period = { preset : period_preset; start_day : string; end_exclusive : string; label : string }
type line_item = { locus : string; label : string; amount : Z.t }

type measure_summary = {
  measure : string;
  income_items : line_item list;
  total_income : Z.t;
  expense_items : line_item list;
  total_expense : Z.t;
  scheduled_expense : Z.t;
  ordinary_expense : Z.t;
  net_savings : Z.t;
}

type report = {
  period : period;
  summaries : measure_summary list;
  unresolved_effects : (string * string * string * Z.t) list;
}

type t = {
  preset : period_preset;
  period_offset : int;
  selected_row : int;
  detail_focused : bool;
  detail_scroll : int;
}

val initial : unit -> t
val preset_label : period_preset -> string
val presets : period_preset list
val parse_boundary_presets : string -> ((string * string * string) list, string) result

val resolve_period :
  today:string ->
  preset:period_preset ->
  offset:int ->
  boundary_presets_text:string option ->
  (period, string) result

val compute_report : book:B.t -> roles:(string * Roles.role) list -> period:period -> report

val render_report_lines :
  width:int ->
  width_of:(string -> int) ->
  book:B.t ->
  report:report ->
  (Daily_overlays.style * string) list

val print_summary : book:B.t -> report:report -> string list
