(** A report period as the reports and the Actual show it: {!Bakhlo_household.Period}'s
    window with its label. The rules live in Period. *)

val boundary_file : string

type preset = Month | Cycle | Previous_cycle | Year | All_time
type period = { preset : preset; start_day : string; end_exclusive : string; label : string }

val resolve :
  today:string ->
  preset:preset ->
  offset:int ->
  boundary_presets_text:string option ->
  (period, string) result
(** The window of [preset] containing [today], moved by [offset] windows, or the
    reader-facing reason it has none. *)
