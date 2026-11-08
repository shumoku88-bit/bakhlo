(** Income and expense of a window by accounting role, with the expense split into
    what settled a plan and the rest. Pinned in test/reports ([INCOME-EXPENSE]). *)

type line = { locus : string; amount : Z.t }
(** One Locus's sum in the window: income turned positive, expense as recorded. *)

type summary = {
  measure : string;
  income : line list;  (** INCOME Loci with an effect, in Locus order. *)
  expense : line list;  (** EXPENSE Loci with an effect, in Locus order. *)
  total_income : Z.t;
  total_expense : Z.t;
  scheduled : Z.t;  (** Expense of entries that settle a plan ({!Book.settles_plan}). *)
  other : Z.t;  (** The rest of the expense. *)
  net : Z.t;  (** Income minus expense. *)
}

type unresolved = { day : string; locus : string; measure : string; amount : Z.t }
(** An effect on a Locus without a role, as recorded. *)

type t = {
  summaries : summary list;  (** Every Measure of the book, in Measure order. *)
  unresolved : unresolved list;  (** By Measure, then in recorded order. *)
}

val compute : Book.t -> start:string -> stop:string -> t
(** The entries dated in [\[start, stop)], by the book's own roles. *)

type spending = {
  totals : (string * Z.t) list;  (** EXPENSE per touched Measure, in Measure order; zeros kept. *)
  partial : bool;  (** Some effect is on a Locus without a role. *)
}

val spending : Book.t -> Book.entry list -> spending
(** The EXPENSE of any rows, by the book's roles: the Actual's day header and period
    totals ([EXPENSE-TOTAL]). Apply it to the book once and reuse the result. *)
