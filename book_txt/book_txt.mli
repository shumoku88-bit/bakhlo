(** The line-based book shared with LOAM: [book.txt], format [BOOK 1]
    (docs/COMMON_FORMAT.ja.md). Syntax and file-local admission only: no mapping to
    [Daily_book], no I/O, no clock. Every accepted text is canonical, so
    [to_string (of_string s)] returns [s] byte for byte. *)

type role = Asset | Liability | Equity | Income | Expense

type posting = { locus : string; measure : string; amount : Z.t }
(** One signed quantity in the Measure's smallest unit; never zero. *)

type merchant = Merchant of string | Nonmerchant

type tx = {
  id : string;
  day : string;
  memo : string option;  (** Unescaped; [Some ""] is not representable. *)
  effects : posting list;  (** In file order. *)
  reversal_of : string option;
  original : (string * Z.t) option;  (** Measure and original amount. *)
  merchant : merchant option;  (** [None] is unclassified, not [Nonmerchant]. *)
  exchange : (string * string) option;  (** Source and destination Measure. *)
}

type plan_end = Paid_by of string | Cancelled of string

type plan = {
  id : string;
  day : string;
  measure : string;
  changes : (string * Z.t) list;  (** Locus and signed amount. *)
  ending : plan_end option;  (** [None] is still open. *)
}

type locus = { id : string; label : string; help : string; hidden : bool }

type anchor = {
  last : string option;
      (** Every TX up to this one in file order is reflected; [None] ([ANCHOR -]) is a
          count made before any TX was recorded. *)
  also : string list;  (** Later TXs that are nevertheless reflected. *)
  asserts : ((string * string) * Z.t) list;  (** (Locus, Measure) and counted amount. *)
}

type due = Due_on of string | No_due_date | Due_undetermined
type close_kind = Resolved | Dropped
type item = { id : string; due : due; context : string }
type close = { item : string; day : string; kind : close_kind }

type t = {
  measures : (string * int) list;  (** Measure and scale. *)
  loci : locus list;
  roles : (string * role) list;
  txs : tx list;  (** Recording order, not date order. *)
  plans : plan list;
  zero_origins : (string * string) list;
  openings : ((string * string) * string) list;  (** Coordinate and opening TX. *)
  history_from : ((string * string) * string) list;  (** Coordinate and start day. *)
  anchors : anchor list;
  items : item list;
  closes : close list;
}
(** Lists keep file order. A value built by hand is admitted only by reading its
    printed text back; there is no second admission path. *)

type code =
  | Not_utf8
  | Crlf
  | No_final_newline
  | Bad_header
  | Missing_end
  | After_end
  | Blank_line
  | Unknown_line
  | Section_order
  | Unclosed_block
  | Bad_token
  | Bad_escape
  | Empty_text
  | Bad_date
  | Bad_integer
  | Duplicate_measure
  | Duplicate_locus
  | Duplicate_role
  | Duplicate_tx
  | Duplicate_plan
  | Duplicate_item
  | Unknown_measure
  | Unknown_locus
  | Unknown_tx
  | Unknown_item
  | Bad_role
  | Suspense_role
  | Bad_scale
  | Bad_hidden
  | Zero_amount
  | No_effect
  | Unbalanced
  | Bad_exchange
  | Reversal_not_inverse
  | Reversal_reused
  | Bad_original
  | Paid_by_reused
  | Opening_missing_coordinate
  | Support_overlap
  | Duplicate_support
  | History_unanchored
  | Empty_anchor
  | Also_redundant
  | Duplicate_also
  | Bad_due
  | Bad_close
  | Duplicate_close

val code_name : code -> string
(** The specification's reason code, e.g. ["unbalanced"]. *)

type error = { code : code; line : int }
(** One-based line where the refusal is detected, as the specification fixes it. *)

val of_string : string -> (t, error) result
(** Admit a whole file or refuse it. Checks run in stages (bytes and lines, block
    structure and order, field syntax, definitions and references); the first stage
    with a violation decides, and within it the earliest line is reported. *)

val to_string : t -> string
(** Canonical text. For an admitted value this is the text it was read from. *)

type balance = Known of Z.t | Unknown

val balance : t -> locus:string -> measure:string -> balance
(** Current quantity by the specification's rule: ZERO-ORIGIN or OPENING sum every
    Effect; an ASSERT adds Effects of TXs after its anchor's [last] that are not in
    [also]; no support is [Unknown], never zero. Assumes an admitted value. *)
