(** Daily Pace from the settings files beside the book; read-only, exact quanta.
    `bk pace` and the Daily Pace screen both answer from here. *)

module B = Bakhlo_household.Book

val window_of :
  config:(string -> (string option, string) result) ->
  today:string ->
  (string * string, string) result
(** The current cycle in boundary-presets.tsv: its start and exclusive end. *)

val pool_of :
  config:(string -> (string option, string) result) ->
  measure:string ->
  (B.coordinate list, string) result
(** The pool in daily-pace.tsv for [measure]; a malformed file refuses as a whole. *)

val pool_accounts : measure:string -> string -> (string list, string) result
(** The accounts daily-pace.tsv chooses, in its order; none for a file with no
    rows. A malformed file, a repeated account or another Measure refuses. *)

val format_pace_error : string -> string
(** Why there is no pace today, in words, with the account when the core names it. *)

val today :
  book:B.t ->
  measure:string ->
  today:string ->
  config:(string -> (string option, string) result) ->
  (B.daily_pace * string * string, string) result
(** Today's answer, its cycle start and exclusive end ([config name] is a file's
    bytes, [None] when absent), or why there is none (never zero). *)

type projection = {
  current_per_day : Z.t;
  projected_per_day : Z.t;
  change_per_day : Z.t;
  available_after : Z.t;
}

val split_sign : string -> bool * string
(** A What-if amount: a leading [+] is an income ([true]), [-] or no sign a purchase. *)

val project : book:B.t -> B.daily_pace -> string -> (projection, string) result
(** Today's pace after a purchase ([+amount]: an income), floored like the pace. *)

type plan = {
  target_per_day : Z.t;
  target_date : string;
  purchase : Z.t;
  days : int;
  daily_spend : Z.t;
  reachable : bool;
  path : Z.t list;
}

type options = { horizons : plan list; earliest : plan option }

val available_after : book:B.t -> B.daily_pace -> string -> (Z.t, string) result
(** What is left to spend after spending [purchase] today (whole units; empty: nothing). *)

val resolve_date : B.daily_pace -> string -> (string, string) result
(** A target date as typed: [D] or [M-D] names the first such day after today and
    before the cycle end; any other spelling comes back unchanged to be checked. *)

val plan :
  book:B.t ->
  B.daily_pace ->
  target:string ->
  date:string ->
  purchase:string ->
  (plan, string) result
(** The largest whole daily spend until [date] that keeps [target] a day. *)

val options :
  book:B.t -> B.daily_pace -> target:string -> purchase:string -> (options, string) result
(** The same over 3/7/14/21/28/42 days, and the earliest day the target is reached. *)
