module D = Bakhlo_domain
(** A corrected-entry S-expression book, independent of UI and filesystem.
    Reads v1..v3; writes v3. Trial budget format v4 is not supported.
    Exchange and dated plan cancellation remain explicit.
    Reading never rewrites a file; conversion uses explicit output/publication
    with the old input kept separately. Full-household migration is not claimed. *)

module Q = Bakhlo_application.Current_quantity_query

type entry = {
  id : string;
  day : string;
  memo : string option;
  effects : D.Effect.t list;
  reversal_of : string option;
  exchange : (string * string) option;
  original_amount : (string * Z.t) option;
  merchant : Bakhlo_application.Event_merchants.disposition option;
}

type plan = {
  id : string;
  day : string;
  measure : string;
  changes : (string * Z.t) list;
  paid_by : string option;
  cancelled_on : string option;
}
(** A retained explicit occurrence. Payment and cancellation are disjoint terminal
    facts; a cancelled plan is not deleted or reinterpreted as a payment. *)

type t

val empty : measure:string -> scale:int -> (t, string) result
(** A v3-ready empty book with one explicitly supplied Measure/scale and no
    admitted Loci, entries, plans, or quantity evidence. *)

val of_string : string -> (t, string) result
(** Reader for the single-file S-expression book (v1..v3, v5). Domain invariants
    are uniformly validated. Does not perform automatic rewriting or migration. *)

val to_string : t -> string
(** Serializes the book in the canonical Monolithic S-expression format (v3).
    Trial-only v4 budget data is deliberately unsupported. *)

type payload = {
  measures : (string * int) list;
  labels : (string * string * string) list option;
  approved : string list option;
  entries : entry list;
  plans : plan list;
  origins : D.Effect_coordinate.t list;
  openings : Q.opening list;
  observations : Bakhlo_application.Current_quantity_groups.group list;
  presence : Q.presence option;
  bounded : (D.Effect_coordinate.t * string) list;
}
(** The whole book as supplied facts, for an explicit importer. *)

val of_payload : payload -> (t, string) result
(** The same whole-book admission as {!of_string}; no defaults or repair. *)

val entries : t -> entry list
(** All retained entries in recorded order (oldest to newest). *)

val entries_rev : t -> entry list
(** All retained entries in reverse recorded order (newest to oldest). O(N). *)

val entry_count : t -> int
(** Total number of entries in the book. O(1). *)

val find_entry : t -> string -> entry option
(** Look up an entry by ID via immutable index. O(log N). *)

val mem_entry : t -> string -> bool
(** Check whether an entry ID exists in the book via immutable index. O(log N). *)

val plans : t -> plan list
(** All retained plans, including paid and cancelled ones, in stored order. *)

val plan_is_open : plan -> bool

val open_plans : t -> plan list
(** Currently unpaid and uncancelled only; not a claim of real-world completeness. *)

val measures : t -> (string * int) list
val approved_loci : t -> string list option
val label : t -> string -> string
val help : t -> string -> string
val set_locus_label : t -> id:string -> label:string -> ?help:string -> unit -> (t, string) result

val image : t -> Q.t
(** Balance answers are always exact. After an in-place record, correction or
    observation the image's admitted source (evidence explanation, cut listings) still describes
    the last whole admission; reload or re-admit before explaining evidence. *)

val format : t -> string -> Z.t -> string

val parse_amount : t -> string -> string -> (Z.t, string) result
(** Positive exact decimal or arithmetic input (+, -, *, /, parentheses) at the explicitly supplied scale. No rounding. *)

type daily_pace = {
  measure : string;
  observed_at : string;
  end_exclusive : string;
  remaining_days : int;
  pool_balances : (D.Effect_coordinate.t * Z.t) list;
  plan_deductions : (string * Z.t) list;
  eligible_pool : Z.t;
  automatic_deductions : Z.t;
  available_through_end : Z.t;
  daily_pace_quanta : Z.t;
}
(** Disposable current-book answer with exact components. Coordinate order follows
    the supplied pool; positive per-occurrence deductions follow retained plan order.
    This is neither stored household state nor spending permission. *)

val daily_pace :
  t ->
  measure:string ->
  pool:D.Effect_coordinate.t list ->
  observed_at:string ->
  end_exclusive:string ->
  (daily_pace, string) result
(** LOAM Home d's current balance-pool guide, not a purpose-budget guide:
    (exact pool quantities - open-plan net drains before exclusive end) / days.
    Dates use the existing real YYYY-MM-DD contract; end must be after observation.
    Caller explicitly supplies one known Measure and unique matching coordinates;
    an explicit empty pool is empty, never a fallback for missing configuration.
    Unknown support or known-present/amount-unknown at ANY selected coordinate
    refuses the whole calculation; no partial total or invented zero. Neither
    catalog membership nor new-write vocabulary selects/authorizes this read pool.
    Overdue open plans still count. Internal transfers and planned inflows deduct
    zero; paid/cancelled plans and other Measures do not count. Signed changes are
    netted within each occurrence, never across different plans.
    Integer-quanta division floors negative deficits (positive divisor), with no
    clamping, floating point, conversion or machine-sized amount arithmetic.
    One immutable book owns both quantities and plans. observed_at is a caller's
    current observation coordinate, NOT an as-of filter or historical replay;
    the function reads no clock. No claim of plan completeness or balance freshness. *)

val put_plan : t -> replace:bool -> plan -> (t, string) result
(** Append a new open plan or replace an existing open one with the same ID.
    Caller supplies identity/date/Measure/exact signed changes, with both terminal
    fields None. No ID allocation or I/O. Checks current vocabulary and nonempty,
    nonzero balanced single-Measure Movement, then checks the plan stage only. Closed
    plans cannot be changed/reopened. Other plans, entries and support are preserved. *)

val cancel_plan : t -> id:string -> day:string -> (t, string) result
(** Close an existing open plan with an explicitly supplied real cancellation date,
    retaining its ID, scheduled date and changes. No payment, deletion or physical
    balance change. Paid/already-cancelled/missing plans refuse. Cancellation does
    not require the historical loci to remain approved for new writes. *)

val correct_entry_date : t -> id:string -> day:string -> (t, string) result
(** Change only the validity date of one retained entry. The Event identity,
    Effects (including keys), Reversal/exchange links, amount, memo and Merchant
    disposition are preserved. Historical Loci need not remain approved because
    no Effect changes or is newly admitted. *)

val put_entry_full : t -> replace:bool -> entry -> plan:string option -> (t, string) result
(** Reference oracle: complete whole-book admission verification without incremental fast path. *)

val put_entry : t -> replace:bool -> entry -> plan:string option -> (t, string) result
(** Checked append or replacement. Every new entry, and every correction that keeps
    its Reversal link and is no opening witness under no presence evidence, is
    admitted with its Reversal partners only and updates balances in place; anything
    else falls back to whole-book admission. Refusals match {!Full.put_entry}. *)

(** Reference oracle: the same candidates, each re-admitted as a whole book. Every
    ordinary mutation must agree with its counterpart here (refusal reason or
    observable book); see test/daily_book_oracle_tests.ml. Never used by the UI. *)
module Full : sig
  val put_entry : t -> replace:bool -> entry -> plan:string option -> (t, string) result
  val put_plan : t -> replace:bool -> plan -> (t, string) result
  val cancel_plan : t -> id:string -> day:string -> (t, string) result
  val correct_entry_date : t -> id:string -> day:string -> (t, string) result

  val classify_merchant :
    t ->
    id:string ->
    disposition:Bakhlo_application.Event_merchants.disposition ->
    (t, string) result

  val add_locus : t -> string -> (t, string) result
  val observe_quantities : t -> (string * string * Z.t) list -> (t, string) result
  val set_locus_label : t -> id:string -> label:string -> ?help:string -> unit -> (t, string) result
end

val classify_merchant :
  t -> id:string -> disposition:Bakhlo_application.Event_merchants.disposition -> (t, string) result
(** Classify the independent Event Merchant disposition for an existing Actual entry.
    First classification only; replacement or reclassification is refused. *)

val add_locus : t -> string -> (t, string) result
(** Explicit vocabulary addition only; never supplies zero balance or a role. *)

val parse_signed_amount : t -> string -> string -> (Z.t, string) result
(** Signed or zero exact decimal input at the explicitly supplied scale. No rounding. *)

val observe_quantities : t -> (string * string * Z.t) list -> (t, string) result
(** Observe one reconciliation group of current quantities for one or more coordinates
    (locus, measure, quantity_quanta) observed together against the current stable-root cut.
    The new group reflects every admitted entry, so it is built in place; older groups
    keep their answers for the coordinates they still own. Matches {!Full}.
    Unmentioned prior observations are preserved; re-observed coordinates are replaced.
    Refuses if any coordinate overlaps zero-origin or opening support, or if Locus/Measure
    is invalid, or if duplicate coordinates are supplied. *)

val has_zero_origin : t -> locus:string -> measure:string -> bool
(** Whether the coordinate has admitted zero-origin support. Does not imply
    support for any nonzero opening or observation family. *)

val bounded_history_start : t -> locus:string -> measure:string -> string option
(** Explicit bounded-history claim: every real change of this coordinate from the
    start of the returned day is represented by retained Actual entries. Never
    inferred from equal endpoints, an opening or a current observation. *)

val with_bounded_history : t -> (string * string * string) list -> (t, string) result
(** Replace the whole bounded-history image with (locus, measure, start day) rows.
    Refuses duplicate coordinates, invalid dates and unknown Measures. Such a book
    prints as monolithic v5 and has no Records v1 or annual form (both refuse). *)

val pool_at_end_of_day :
  t -> measure:string -> pool:D.Effect_coordinate.t list -> day:string -> (Z.t, string) result
(** Exact pool total at the end of [day] (= start of the next day), restated from
    current truth. Each coordinate needs exactly one route: zero-origin (forward
    sum) or bounded history starting no later than the next day with an exact
    current observation (current minus later Effects). Missing support, overlap
    with zero-origin/opening or an unanchored bounded coordinate refuses the whole
    answer; no partial total or invented zero. *)

val entry_to_sexp : entry -> Sexplib0.Sexp.t
val entry_of_sexp : Sexplib0.Sexp.t -> (entry, string) result
val plan_to_sexp : plan -> Sexplib0.Sexp.t

val plan_of_sexp : Sexplib0.Sexp.t -> (plan, string) result
(** The book's own v3 entry/plan syntax, for operation logs. Decoding checks
    syntax only; admission happens when the operation is applied. *)

val render_line : Sexplib0.Sexp.t -> string
(** One-line rendering with the book printer's quoting; never contains a newline. *)
