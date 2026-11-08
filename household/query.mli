(** Finding records with hledger-like terms; every term must match.

    A plain word: a Locus (display name or ID) or the memo contains it (ASCII case
    ignored). [acct:] / [memo:] (or [desc:]): only Loci / only the memo. A period
    ([2026], [2026-10], [2026-10-05], [A..B] with B excluded and either end open),
    alone or after [date:]. [amt:] with an amount, a range [A..B] (B excluded, either
    end open) or [>], [>=], [<], [<=]: some row's size in its Measure's units meets it. *)

type t

val parse : string list -> (t, string) result
(** Refuses [bad-date:<text>], [bad-amount:<text>], [empty-term:<term>] and
    [unknown-field:<name>]. *)

val days : string -> (string option * string option) option
(** A period word as (first day, first day after), either open: [2026], [2026-10],
    [2026-10-05], [A..B]; [None] if it is not one. *)

val matches : Book.t -> t -> Book.entry -> bool

val find : Book.t -> t -> Book.entry list
(** Matching records in recorded order. *)
