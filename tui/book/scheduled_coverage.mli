(** Replaceable Scheduled monitoring rules (scheduled-coverage.tsv) and their
    read-only month projection: LOAM's Series Calendar.

    A rule names an exact signed-Locus shape (amounts ignored), an anchor date
    and a cadence in months (0 = undecided, expects nothing). It never creates
    plans, recurrence or Series identity; a missing month only says that no
    explicit open or completed plan of that shape is retained there. *)

module B = Bakhlo_household.Book

type rule = {
  name : string;
  anchor : string;
  every_months : int;
  negative : string list;  (** Sorted, unique Locus IDs with negative changes. *)
  positive : string list;
}

val of_string : string -> (rule list, string) result
(** One rule per line: name, anchor, months, negative loci, positive loci
    (comma-separated), tab-separated. Any malformed row, duplicate name or
    duplicate shape refuses the whole file; never a partial rule set. *)

val matches : rule -> B.plan -> bool
(** The plan's signed-Locus shape equals the rule's. *)

val expected_on : rule -> string -> bool
(** Whether a real date's month is a cadence month at or after the anchor month. *)

type cell = {
  month : string;  (** YYYY-MM *)
  expected : bool;
  open_days : string list;  (** Two-digit days of matching current-open plans. *)
  completed_days : string list;  (** Two-digit days of matching paid plans. *)
}

val missing : cell -> bool
(** Expected, with neither an open nor a completed matching plan. *)

type row = { rule : rule; cells : cell list; first_missing : string option }

val project :
  rule list ->
  plans:B.plan list ->
  today:string ->
  months:int ->
  (string list * row list, string) result
(** [months] consecutive months from today's month. Open plans are unpaid and
    uncancelled; completed plans are paid. Cancelled plans cover nothing.
    Rows follow LOAM order: cadence ascending, undecided last, then name. *)

val cadence_label : int -> string
(** "monthly", "every Nm", "yearly" or "undecided". *)

val cell_text : cell -> string
(** Days with [✓] for completed, "Np/N✓" when over eight cells, "!" when missing. *)

val month_label : string -> string
(** Jan..Dec for a YYYY-MM month. *)

val plans_for : rule -> B.plan list -> B.plan list
(** Matching current-open plans, by date then ID. *)

val rule_for : B.plan -> months:int -> (rule, string) result
(** LOAM monitoring rule from an explicit plan: its date anchors, its signed-Locus
    shape selects, the single positive Locus (else the plan ID) names it. Zero
    months refuses here; undecided is an existing rule with zero months. *)

val upsert : rule list -> rule -> (rule list, string) result
(** Same shape: replaced in place, keeping its existing name. New shape: appended,
    unless its name already monitors another shape (refused, never renamed). *)

val to_string : rule list -> string
(** One row per rule, newline-terminated; the empty list is the empty file. *)
