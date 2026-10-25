(** The household book in memory: an admitted book.txt ({!Bakhlo_book_txt.Book_txt.book})
    and, for the screens, its TXs as entries. Every change is one Book_txt change,
    admitted by the specification's rules after Bakhlo's own write policies: Loci
    offered for new entries, open plans only, a Merchant set once. Balances come from
    the totals the admitted book keeps. Pure: no file access. *)

module D = Bakhlo_domain
module T = Bakhlo_book_txt.Book_txt

type entry = Records.entry = {
  id : string;
  day : string;
  memo : string option;
  effects : D.Effect.t list;
  reversal_of : string option;
  exchange : (string * string) option;  (** Source and destination Effect keys. *)
  original_amount : (string * Z.t) option;
  merchant : Records.disposition option;
}

type plan = Records.plan = {
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

val of_txt : T.book -> (t, string) result
(** The book of an admitted book.txt. Refuses a TX that would not read back as the same
    entry (an exchange whose legs are not the only Effects of their sign in their
    Measures). *)

val txt : t -> T.book
(** Its book.txt; [T.print] gives the bytes to save. *)

val empty : measure:string -> scale:int -> (t, string) result
(** One Measure with its scale and nothing else. *)

val entries : t -> entry list
(** Recorded order, oldest first. *)

val entries_rev : t -> entry list
val entry_count : t -> int
val find_entry : t -> string -> entry option
val mem_entry : t -> string -> bool

val plans : t -> plan list
(** All plans, paid and cancelled ones included, in stored order. *)

val plan_is_open : plan -> bool
val open_plans : t -> plan list
val measures : t -> (string * int) list

val approved_loci : t -> string list option
(** The Loci offered for new entries (not [HIDDEN]); always [Some]. *)

val label : t -> string -> string
val help : t -> string -> string

val quantity : t -> locus:string -> measure:string -> T.quantity option
(** The current balance and the support it rests on; [None] is unknown, never zero. *)

val has_zero_origin : t -> locus:string -> measure:string -> bool

val openings : t -> ((string * string) * string) list
(** Each opening: its (Locus, Measure) and opening TX. *)

val bounded_history_start : t -> locus:string -> measure:string -> string option
(** The [HISTORY-FROM] day: every change of this coordinate from that day on is a
    recorded TX. *)

val roles : t -> (string * T.role) list
val attention : t -> T.item list * T.close list

val format : t -> string -> Z.t -> string

val parse_amount : t -> string -> string -> (Z.t, string) result
(** Positive exact decimal or arithmetic input (+, -, *, /, parentheses) at the
    Measure's scale. No rounding. *)

val parse_signed_amount : t -> string -> string -> (Z.t, string) result
(** Signed or zero exact decimal input at the Measure's scale. No rounding. *)

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

val daily_pace :
  t ->
  measure:string ->
  pool:D.Effect_coordinate.t list ->
  observed_at:string ->
  end_exclusive:string ->
  (daily_pace, string) result
(** LOAM Home d's current balance-pool guide: (exact pool balances - open-plan net
    drains before the exclusive end) / days. An unknown balance at any selected
    coordinate refuses the whole answer; overdue open plans still count; internal
    transfers and planned inflows deduct zero; integer division floors negative
    deficits. Reads no clock. *)

val pool_at_end_of_day :
  t -> measure:string -> pool:D.Effect_coordinate.t list -> day:string -> (Z.t, string) result
(** The pool at the end of [day], restated from current truth: each coordinate needs
    zero-origin (forward sum) or a history start no later than the next day with a
    current count (count minus later Effects). Anything else refuses the whole answer. *)

val pools_at_end_of_days :
  t -> measure:string -> pool:D.Effect_coordinate.t list -> days:string list -> (Z.t, string) result list
(** {!pool_at_end_of_day} for each day, from one pass over the entries. *)

(** {1 Changes}

    Each refuses with a reason and leaves the book as it was. *)

val put_entry : t -> replace:bool -> entry -> plan:string option -> (t, string) result
(** A new entry at the end, or the entry with this ID in its place. Its Loci must be
    offered for new entries; [plan] pays an open plan (new entries only); a classified
    Merchant cannot be replaced. An empty memo is no memo. *)

val correct_entry_date : t -> id:string -> day:string -> (t, string) result
(** Only the date; a Locus no longer offered may stay. *)

val classify_merchant :
  t -> id:string -> disposition:Records.disposition -> (t, string) result
(** First classification only. *)

val put_plan : t -> replace:bool -> plan -> (t, string) result
(** A new open plan, or an open one replaced. *)

val cancel_plan : t -> id:string -> day:string -> (t, string) result

val add_locus : t -> string -> (t, string) result
(** Offer a Locus for new entries: a new one labelled with its ID, or a hidden one again. *)

val set_locus_label : t -> id:string -> label:string -> ?help:string -> unit -> (t, string) result

val observe_quantities : t -> (string * string * Z.t) list -> (t, string) result
(** One count of current quantities reflecting every recorded TX. Older counts keep
    the coordinates not counted again. Refuses a coordinate with zero-origin or opening
    support, an unknown Measure, a Locus not offered, or a repeated coordinate. *)

val with_bounded_history : t -> (string * string * string) list -> (t, string) result
(** Replace every history start with (Locus, Measure, day) rows; each needs a count. *)

val with_sections :
  t -> roles:(string * T.role) list -> items:T.item list -> closes:T.close list -> (t, string) result
(** Replace the accounting roles and the Attention items and closes. *)
