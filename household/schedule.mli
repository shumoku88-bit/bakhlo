(** Plans in series: batch amount changes and replenishment.

    A series is the open plans of one Measure with the same signed Loci (paid
    from, received by), whatever their amounts; nothing about it is stored. *)

module B = Book

type shape = { negative : string list; positive : string list }
(** Sorted, unique Loci with negative and with positive changes. *)

val shape : B.plan -> shape

val series_of : B.t -> B.plan -> (B.plan list, string) result
(** The open plans in [source]'s series, by day then ID; [source-not-open] when
    [source] is paid, cancelled or not in the book. *)

val series : B.t -> B.plan list list
(** Every open plan in its series; series by their first day, plans by day then ID. *)

val simple_amount : B.plan -> Z.t option
(** The amount of a two-row plan between two Loci; [None] for a split plan. *)

val change_amount : B.plan list -> amount:Z.t -> (B.plan list, string) result
(** The plans whose amount becomes [amount] (positive), signs kept. Refuses
    [split-plan:<id>] for a plan that is not two rows, and [unchanged] when
    every plan already has that amount. *)

type slot = Dated of string | Missing of { year : int; month : int; day : int }

val slot : anchor:string -> every_months:int -> int -> slot option
(** The [k]-th occurrence after [anchor]: the anchor's day in the month
    [k * every_months] later, or [Missing] when that month has no such day.
    [None] outside 0001..9999 or for an invalid anchor. *)
