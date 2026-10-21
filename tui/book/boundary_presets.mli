(** [boundary-presets.tsv]: named presets, each a tab-separated name followed by at
    least two strictly increasing canonical dates; every adjacent pair of dates is a
    half-open window [start, end). Lines are trimmed (so CRLF files read the same);
    blank lines and lines starting with [#] are skipped. Every screen reads the file
    through this module, so they agree on what is valid. *)

type preset = string * string list
(** Name and its boundary dates, in file order. *)

val parse : string -> (preset list, unit) result
(** [Error ()] when any remaining line is malformed: a missing, repeated or
    non-token name, fewer than two dates, a non-canonical date or a non-increasing
    sequence. Callers word the refusal; nothing is inferred from a bad file. *)

val windows : preset list -> (string * string * string) list
(** Every window as (name, start, end-exclusive), presets in file order. *)

val containing : string -> preset list -> (string * string * string) list
(** The windows that contain the day (at most one per preset). *)
