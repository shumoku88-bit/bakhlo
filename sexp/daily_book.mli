module D = Bakhlo_domain
(** A corrected-entry S-expression book, independent of UI and filesystem.
    Reads v1..v4; writes v4 when budgets are explicitly supplied, otherwise v3.
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

type budget = {
  id : string;
  start_day : string;
  end_exclusive : string;
  measure : string;
  allocations : (string * Z.t) list;
  expense_loci : string list;
  actual_routes : (string * string option) list;
  plan_routes : (string * string * string option) list;
}
(** One explicitly supplied single-Measure period and its nonnegative purpose
    allocations. expense_loci explicitly selects the expense-side coordinates:
    positive signed quantities mean spending, negative ones mean reductions/refunds.
    It is NOT an inferred AccountingRole or a complete household expense catalog.
    Actual routes are locus -> purpose; plan routes independently select
    plan ID x locus -> purpose. Missing route is unresolved; explicit None means
    unmanaged. All Some purposes must have an allocation (explicit zero allowed).
    These current definitions classify the WHOLE selected period, not LOAM's
    dated routing history. No implicit inheritance from plans to actual payments. *)

type t

val source_format_of_string : string -> [ `Monolithic of string | `Records of int | `Unknown ]
(** Detect whether input is Monolithic S-expression (bakhlo-daily v1..v4) or Records S-expression (bakhlo-records v1). *)

val of_string : string -> (t, string) result
(** Safe compatible reader. Parses Monolithic (v1..v4) or Records (v1) format transparently.
    Domain invariants are uniformly validated. Does not perform automatic rewriting or migration. *)

val to_string : t -> string
(** Serializes the book in the canonical Monolithic S-expression format (v4 if budgets exist, otherwise v3).
    Preserves backward compatibility; does not silently switch format on write. *)

val of_records : Records_book.t -> (t, string) result
(** Construct a Daily_book from a Records_book through Core invariant gates. *)

val to_records : ?request_tokens:(string * string) list -> t -> Records_book.t
(** Convert a Daily_book to a Records_book with sequential LSNs and CRC32 framing. *)

val to_records_string : ?request_tokens:(string * string) list -> t -> string
(** Explicitly serialize in the Records S-expression format. *)


val budgets : t -> budget list option
(** None means budget information not supplied (including v1..v3), NOT zero budgets. *)

val entries : t -> entry list

val plans : t -> plan list
(** All retained plans, including paid and cancelled ones, in stored order. *)

val plan_is_open : plan -> bool

val open_plans : t -> plan list
(** Currently unpaid and uncancelled only; not a claim of real-world completeness. *)

val measures : t -> (string * int) list
val approved_loci : t -> string list option
val label : t -> string -> string
val image : t -> Q.t
val format : t -> string -> Z.t -> string

val parse_amount : t -> string -> string -> (Z.t, string) result
(** Positive exact decimal input at the explicitly supplied scale. No rounding. *)

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

val put_budget : t -> replace:bool -> budget -> (t, string) result
(** Create or explicitly replace a same-ID definition, then whole-admit the book.
    Validates real nonempty period, known Measure, unique purposes/loci/routes,
    nonnegative exact allocations and all plan/locus/purpose references. Entries,
    plans, quantities/support and other budgets are unchanged. No clock or I/O. *)

val rebalance_budget :
  t -> id:string -> from_purpose:string -> to_purpose:string -> amount:Z.t -> (t, string) result
(** Move a strictly positive allocation between two distinct existing purposes,
    preserving the total. Source allocation must suffice; no physical transaction
    or inferred funding. This moves allocation, not "safe to spend" authority. *)

type budget_item = { source_id : string; locus : string; quanta : Z.t }

type budget_row = {
  purpose : string;
  allocated : Z.t;
  actuals : budget_item list;
  plans : budget_item list;
  spent : Z.t;
  planned : Z.t;
  remaining : Z.t;
  after_known : Z.t;
}

type budget_review = {
  definition : budget;
  observed_at : string;
  rows : budget_row list;
  unrouted_actual : budget_item list;
  unmanaged_actual : budget_item list;
  unrouted_plans : budget_item list;
  unmanaged_plans : budget_item list;
}

val budget_review : t -> id:string -> observed_at:string -> (budget_review, string) result
(** Recorded current-book components only, NOT physical balance or guaranteed
    complete household budget. Observation must be inside [start, end).
    Actuals select occurrence dates from start through observation inclusive.
    Open plans select all dates before end, INCLUDING overdue before start;
    explicit per-plan attribution makes this carried pressure visible. Closed
    plans are excluded, so fulfillment is not double-counted with its actual.
    Positive net expense is protected PER plan/Purpose; planned refunds do not
    increase available budget before becoming actual. Actual refunds reduce spent.
    remaining = allocation - recorded spent; after_known additionally subtracts
    known managed plan pressure. Unresolved and explicitly unmanaged signed items
    are returned separately, never silently assigned or netted out of sight.
    Rows preserve allocation order; item lists preserve source/line multiplicity.
    No foreign-Measure arithmetic, inferred period, completeness, history replay,
    stored subtotals or automatic correspondence changes on payment/correction. *)

val put_plan : t -> replace:bool -> plan -> (t, string) result
(** Append a new open plan or replace an existing open one with the same ID.
    Caller supplies identity/date/Measure/exact signed changes, with both terminal
    fields None. No ID allocation or I/O. Checks current vocabulary and nonempty,
    nonzero balanced single-Measure Movement, then admits the whole book. Closed
    plans cannot be changed/reopened. Other plans, entries and support are preserved. *)

val cancel_plan : t -> id:string -> day:string -> (t, string) result
(** Close an existing open plan with an explicitly supplied real cancellation date,
    retaining its ID, scheduled date and changes. No payment, deletion or physical
    balance change. Paid/already-cancelled/missing plans refuse. Cancellation does
    not require the historical loci to remain approved for new writes. *)

val put_entry_full : t -> replace:bool -> entry -> plan:string option -> (t, string) result
(** Reference oracle: complete whole-book admission verification without incremental fast path. *)

val put_entry : t -> replace:bool -> entry -> plan:string option -> (t, string) result
(** Checked append or replacement. Uses incremental admission for ordinary new entries,
    and safely falls back to full admission for replacements, reversals, and exchanges. *)

val add_locus : t -> string -> (t, string) result
(** Explicit vocabulary addition only; never supplies zero balance or a role. *)
