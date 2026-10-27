(** Multicurrency Spend: one explicit half-open Actual window, kept as separate
    exact families instead of one converted total. No FX rate, valuation, home
    currency or cross-Measure arithmetic is inferred. *)

type total = { measure : string; quanta : Z.t }
(** One touched Measure's exact signed sum. A row exists even when the signed
    classified amounts net to zero; no row is invented for an untouched Measure. *)

type exchange_occurrence = {
  event : string;
  date : string;
  description : string option;
  source : Bakhlo_domain.Effect.t;
  destination : Bakhlo_domain.Effect.t;
  extra_effects : Bakhlo_domain.Effect.t list;
}
(** The retained exchange Event's exact selected source and destination Effects,
    plus its remaining Effects in recorded order. No rate is derived. *)

type unresolved_effect = { event : string; date : string; posting : Bakhlo_domain.Effect.t }
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

val compute :
  book:Bakhlo_household.Daily_book.t ->
  roles:(string * Daily_overlays.accounting_role) list ->
  start_day:string ->
  end_exclusive:string ->
  (snapshot, string) result
(** Project current retained entries whose day lies in [start_day, end_exclusive)
    after checking both bounds are real canonical dates and start precedes end.
    Roles classify only explicitly; absent roles stay unresolved. Ordinary and
    exchange-associated Expense are independent per-Measure signed sums.
    OriginalAmount evidence is counted once for a non-exchange entry with any
    positive Expense Effect; every other original is retained as an unresolved or
    non-counted witness. An exchange whose selected Effect key is missing refuses
    the whole window instead of dropping or guessing a leg. *)

val render_lines :
  book:Bakhlo_household.Daily_book.t -> snapshot -> (Daily_overlays.style * string) list
(** Full result text in fixed section order, with every unresolved and non-counted
    witness present and every amount exact and grouped at its own Measure scale.
    Logical lines are unwrapped for the caller to wrap. *)
