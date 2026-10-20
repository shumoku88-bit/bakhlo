(* Daily Pace spendable-pool picker (LOAM DailyPacePoolSetup): choose explicit
   exact-current balances of one Measure. Query configuration only; it never
   assigns roles, creates balances or infers membership from names. *)
module B = Bakhlo_sexp.Daily_book

type t

val prepare : book:B.t -> measure:string -> config:(string option, string) result -> t
(** Candidates are Loci whose current [measure] balance is exact, grouped by
    support (zero-origin, opening, observed), each in first appearance order
    over the retained entries, then admitted Loci without one. The
    captured [config] bytes are the save precondition. An unreadable, malformed
    or foreign-Measure file opens with its cause and refuses review. Previously
    chosen balances that are no longer exact-current are dropped and named. *)

val measure : t -> string

val rows_from : string -> string -> (string list, string) result
(** [rows_from measure text]: daily-pace.tsv Loci for [measure], in file order. *)

type step =
  | Stay of t
  | Cancel of t  (** Closed; the caller may retain the draft. *)
  | Save of { picker : t; expected : string option; content : string }
      (** Replace daily-pace.tsv only if it still holds [expected]. *)

val update : width_of:(string -> int) -> width:int -> height:int -> t -> Ui_input.input -> step
(** j/k/arrows move, Space toggles, Enter reviews; in review Enter saves only
    when every review row is visible and unclipped, Esc/e edits. Esc/q cancel. *)

val reviewing : t -> bool
val chosen : t -> string list
val with_notice : t -> string -> t

val rows : width_of:(string -> int) -> width:int -> height:int -> t -> (Daily_overlays.style * string) list
