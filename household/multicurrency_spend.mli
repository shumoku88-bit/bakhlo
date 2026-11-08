(** Spending per Measure in one window, kept as separate exact families instead of
    one converted total. No FX rate, valuation, home currency or cross-Measure
    arithmetic is inferred. Pinned in test/reports ([MULTICURRENCY]). *)

type total = { measure : string; quanta : Z.t }
(** One touched Measure's exact signed sum. A row exists even when the signed
    classified amounts net to zero; no row is invented for an untouched Measure. *)

type exchange_occurrence = {
  event : string;
  date : string;
  description : string option;
  source : Book.posting;
  destination : Book.posting;
  extra_effects : Book.posting list;
}
(** The retained exchange Event's exact selected source and destination Effects,
    plus its remaining Effects in recorded order. No rate is derived. *)

type unresolved_effect = { event : string; date : string; posting : Book.posting }
(** A nonzero Effect whose Locus has no explicit accounting role in this capture. *)

type original_reason =
  | Unresolved_roles
  | Exchange_event
  | No_positive_expense
      (** Why an OriginalAmount observation is retained but not counted as presented
    Expense: missing role evidence, an exchange Event, or no positively classified
    Expense Effect. A sign is never inferred for the observation. *)

type original_witness = {
  event : string;
  date : string;
  measure : string;
  quanta : Z.t;
  reason : original_reason;
}

type snapshot = {
  start_day : string;
  end_exclusive : string;
  ordinary_expense : total list;
  original_expense : total list;
  exchange_expense : total list;
  exchanges : exchange_occurrence list;
  unresolved_ordinary : unresolved_effect list;
  unresolved_exchange : unresolved_effect list;
  unresolved_original : original_witness list;
  uncounted_original : original_witness list;
}
(** Immutable projection of the explicit window. Totals are lexical by Measure
    token; effect lists follow entry date then stable ID, then recorded order. *)

type refusal =
  | Bad_start  (** The start is not a real YYYY-MM-DD day. *)
  | Bad_end  (** Nor is the exclusive end. *)
  | Empty_window  (** The end is not after the start. *)

val code : refusal -> string
(** The language-neutral reason, e.g. ["empty-window"] (test/reports). *)

val message : refusal -> string
(** The reader-facing reason. *)

val compute : Book.t -> start:string -> stop:string -> (snapshot, refusal) result
(** The entries dated in [\[start, stop)]
    after checking both bounds are real canonical dates and start precedes end.
    The book's roles classify only explicitly; absent roles stay unresolved. Ordinary and
    exchange-associated Expense are independent per-Measure signed sums.
    OriginalAmount evidence is counted once for a non-exchange entry with any
    positive Expense Effect; every other original is retained as an unresolved or
    non-counted witness. Book names both legs of every admitted exchange, so no leg
    is ever dropped or guessed. *)
