module B = Bakhlo_household.Book
(** Income & Expense Report: period-based P/L analysis by month, cycle, year, or all-time. *)

module Roles = Locus_roles

type period_preset = Period_window.preset = Month | Cycle | Previous_cycle | Year | All_time

type period = Period_window.period = {
  preset : period_preset;
  start_day : string;
  end_exclusive : string;
  label : string;
}

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

type comparison = {
  window : period;  (** The compared window, whole. *)
  same_age : report;
      (** It up to as many days as this window has run; all of it when this one is over. *)
  whole : report option;  (** All of it, while this window is partial and has started. *)
}

type t = { preset : period_preset; period_offset : int }

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
val measure_active : measure_summary -> bool
val elapsed : today:string -> period -> int * int
val truncate_to_days : period -> int -> period

val span : period -> string
(** A window by its first and last day. *)

val render_report_lines :
  width:int ->
  width_of:(string -> int) ->
  book:B.t ->
  report:report ->
  today:string ->
  comparison:comparison option ->
  (Ui_render.style * string) list

val render_compare_lines :
  width:int ->
  width_of:(string -> int) ->
  book:B.t ->
  today:string ->
  reports:(period * report) list ->
  (Ui_render.style * string) list

val print_summary : book:B.t -> report:report -> string list
