(** Liquidity report: conditional selected-balance path under one explicit,
    ephemeral assumption. Not evidence, not canonical liquidity, never stored. *)

type point = { date : string; scheduled_change : Z.t; balance : Z.t }

type snapshot = {
  as_of : string;
  assumed_complete_through : string;
  measure : string;
  current_selected : Z.t;
  points : point list;
}

val compute :
  book:Bakhlo_household.Book.t ->
  today:string ->
  coords:(string * string) list ->
  assumed_complete_through:string ->
  (snapshot, string) result
(** Exact sum of every selected coordinate under one Measure, then every
    currently open plan change for the selected Loci of that Measure up to and
    including [assumed_complete_through]. Duplicates, mixed Measures, unknown
    support, invalid dates and overdue selected changes refuse the whole query.
    Conditional inflows raise the path; paid/cancelled plans are absent. *)

val final_at_horizon : snapshot -> Z.t
(** Balance after every retained point; the current baseline when none. *)

val low_water : snapshot -> Z.t
(** Lowest day-boundary balance including the current baseline. *)

val render_lines : book:Bakhlo_household.Book.t -> snapshot -> (Ui_render.style * string) list
(** Full exact Measure-scaled result text; at most 12 point rows plus an
    omitted-count note, while both totals still use every point. *)
