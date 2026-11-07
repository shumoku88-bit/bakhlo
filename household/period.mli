(** The household's periods: calendar days, months and years, and the cycles it
    names in [boundary-presets.tsv]. A cycle is never inferred; a day that no
    preset covers, or that two presets cover, has no cycle. The answers are
    pinned language-neutrally in test/periods. *)

type preset = string * string list
(** A named preset and its boundary dates, in file order. Every adjacent pair of
    dates is a half-open window [start, end). *)

type refusal =
  | Not_configured  (** There is no boundary-presets.tsv. *)
  | Malformed  (** A line is not a name and two or more increasing canonical dates. *)
  | No_cycle of string  (** No preset has a window containing this day. *)
  | Ambiguous of string  (** Windows of two presets contain this day. *)
  | Outside_presets  (** The cycle moved past the configured windows. *)
  | Out_of_range  (** A calendar step leaves the years 0001–9999. *)

val code : refusal -> string
(** The language-neutral reason, e.g. ["no-cycle:2027-02-10"]. *)

val message : ?today:string -> refusal -> string
(** The reader-facing reason; a day equal to [today] reads as "today". *)

val parse : string -> (preset list, refusal) result
(** Lines are trimmed (CRLF reads the same); blank lines and [#] lines are skipped;
    names are unique tokens. Any other bad line refuses the whole file. *)

val windows : preset list -> (string * string * string) list
(** Every window as (name, start, end-exclusive), presets in file order. *)

type cycle = { name : string; windows : (string * string) list; index : int }
(** The one preset whose window contains a day: its windows in order and the
    index of that window. *)

val read : string option -> (preset list, refusal) result
(** The configured presets; [None] (no file) is [Not_configured]. *)

val cycle : preset list -> day:string -> (cycle, refusal) result

val window_of : cycle -> string -> (string * string) option
(** The window of the same preset that contains a day. *)

type span = Day | Month | Year | Cycle | Previous_cycle | All

val window :
  config:string option -> day:string -> span -> offset:int -> (string * string, refusal) result
(** The (start, end-exclusive) of the [span] containing [day], moved by [offset] spans.
    [Previous_cycle] is the cycle before the current one. [All] is every day the book
    can hold: 0001-01-01 up to 9999-12-31 (exclusive). Only cycles read [config]. *)

type range = Last_days of int | Month_to_date | Cycle_to_date | Whole_previous_cycle

val range : config:string option -> today:string -> range -> (string * string, refusal) result
(** The first and last day (both inclusive) of a Daily Pace History range. *)
