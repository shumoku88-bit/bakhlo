module Book = Book
(** The household book in memory and its book.txt form; no filesystem or publication
    authority. *)

module Day = Day
(** The household's days and the arithmetic over them. *)

module Period = Period
(** Calendar spans and the cycles named in boundary-presets.tsv. *)

module Income_expense = Income_expense
(** Income and expense of a window by accounting role. *)

module Transactions_flow = Transactions_flow
(** What moved through each (Locus, Measure) in a window. *)

module Liquidity = Liquidity
(** A conditional path of chosen balances through a named day. *)

module Multicurrency_spend = Multicurrency_spend
(** Spending per Measure in a window, never converted. *)

module Trend = Trend
(** Recorded flow per Locus over the cycle history. *)

module Stock_flow = Stock_flow
(** Why the watched balances changed between two days. *)
