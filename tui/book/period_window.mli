(** Report period windows resolved from the configured boundary presets, shared by
    the reports and the Actual. *)

val boundary_file : string

type preset = Month | Cycle | Previous_cycle | Year | All_time
type period = { preset : preset; start_day : string; end_exclusive : string; label : string }

val parse_boundary_presets : string -> ((string * string * string) list, string) result
(** Every window of boundary-presets.tsv as (name, start, end-exclusive). *)

val resolve :
  today:string ->
  preset:preset ->
  offset:int ->
  boundary_presets_text:string option ->
  (period, string) result
(** The window of [preset] containing [today], moved by [offset] windows. Cycle
    presets resolve only from configured boundaries. *)

val cycle_windows :
  today:string ->
  boundary_presets_text:string option ->
  ((string * string) list * int, string) result
(** The (start, end-exclusive) windows of the first preset with a window containing
    [today], in file order, and the index of that window. *)
