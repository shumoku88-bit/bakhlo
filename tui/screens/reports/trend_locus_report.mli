(* Trend / Locus report: exact recorded Effect flow per Locus x Measure over an
   explicitly configured cycle history. Pure, read-only, no clock, no I/O. *)
module B = Bakhlo_sexp.Daily_book
module Roles = Locus_roles

type grain = Cycle | Month | Day
type scope = All_history | Current_cycle | Current_month | Last_30_days
type coordinate = { locus : string; measure : string }

type point = {
  start_day : string;
  end_exclusive : string;  (** Exclusive; all points are [start_day, end_exclusive). *)
  observed_days : int;  (** Every calendar day in the clipped window, recorded or not. *)
  complete : bool;
      (** Full natural calendar/cycle window; the observation Day remains partial.
          Never an evidence or household-coverage claim. *)
  total : Z.t;  (** Exact sum of recorded signed Effects in the window. *)
  value : Z.t;  (** Day: total. Cycle/Month: Euclidean floor total/observed_days. *)
}

type series = { coordinate : coordinate; label : string; points : point array }

type snapshot = {
  measure : string;
  observed_at : string;
  source : string;  (** Named explicit boundary preset that supplied the history. *)
  scope_start : string;
  scope_end_exclusive : string;
  grain : grain;
  scope : scope;  (** Effective scope: grains other than Day always project All_history. *)
  series : series array;
}

val catalog : book:B.t -> measure:string -> coordinate list
(** Admitted Loci plus Loci of recorded Effects in Measures exactly [measure],
    paired with that Measure, deduplicated and sorted for a deterministic order.
    Labels are not part of the coordinate. *)

val history_start :
  observed_at:string -> boundary_presets_text:string option -> (string, string) result
(** The first boundary of the explicit preset containing the observation day. *)

val initial_series :
  book:B.t ->
  measure:string ->
  roles:(string * Roles.role) list ->
  start_day:string ->
  end_exclusive:string ->
  coordinate list
(** The three Expense-role Loci with the most recorded entries in the shown
    history; ties go to the larger recorded movement, then the token. Fewer are
    returned when fewer exist; nothing is inferred from a name or a sign. *)

val project :
  book:B.t ->
  observed_at:string ->
  boundary_presets_text:string option ->
  grain:grain ->
  scope:scope ->
  coordinates:coordinate list ->
  (snapshot, string) result
(** Exact recorded Effect flow for 1..5 unique Loci of one common, configured
    Measure, clipped to [historyStart, observed_at+1). [historyStart] is the first
    boundary of the unique explicit preset containing [observed_at]; every scope
    is clipped to it. Missing, malformed, ambiguous or non-containing boundary
    configuration is unavailable, never an inferred month, history start, zero or
    stale chart. When [grain] is not [Day] the requested [scope] is ignored and
    the effective scope is [All_history]. Cycle points are natural adjacent
    boundary windows; Month points are calendar buckets; Day points are single
    days. Refunds and reversals contribute their own signed recorded Effects;
    future and out-of-window Effects are excluded. Zero is an exact empty
    recorded sum, not a balance or support assertion. *)

val grain_label : grain -> string
val scope_label : scope -> string
