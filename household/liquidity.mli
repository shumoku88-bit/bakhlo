(** A conditional path of chosen balances under one explicit assumption: no other
    plan through a named day. Not a forecast; never stored. Pinned in test/reports
    ([LIQUIDITY]). *)

type point = { date : string; scheduled_change : Z.t; balance : Z.t }
(** One day with open plans: their net change to the chosen cells and the balance
    after it. *)

type snapshot = {
  as_of : string;
  assumed_complete_through : string;
  measure : string;
  current_selected : Z.t;  (** The exact sum of the chosen cells today. *)
  points : point list;  (** In day order. *)
}

type refusal =
  | Bad_today  (** Today is not a real YYYY-MM-DD day. *)
  | Bad_horizon  (** Nor is the assumed complete-through day. *)
  | Horizon_before_today
  | No_selection
  | Duplicate_selection
  | Mixed_measures  (** The chosen cells span more than one Measure. *)
  | Unknown_balance of string * string  (** This (Locus, Measure) has no known balance. *)
  | Overdue of { plan : string; due : string; today : string }
      (** An open plan on the chosen cells was due before today. *)

val code : refusal -> string
(** The language-neutral reason, e.g. ["overdue:phone-2027-02"] (test/reports). *)

val message : refusal -> string
(** The reader-facing reason. *)

val compute :
  Book.t ->
  today:string ->
  coords:(string * string) list ->
  assumed_complete_through:string ->
  (snapshot, refusal) result
(** Exact sum of every chosen (Locus, Measure) under one Measure, then every open
    plan change for the chosen Loci of that Measure up to and including
    [assumed_complete_through]. Duplicates, mixed Measures, an unknown balance,
    invalid dates and overdue chosen changes refuse the whole query. Incoming plans raise the path; paid and cancelled plans
    are absent. *)

val final_at_horizon : snapshot -> Z.t
(** Balance after every point; today's when none. *)

val low_water : snapshot -> Z.t
(** Lowest day-boundary balance, today's included. *)
