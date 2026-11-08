(** Daily Pace from the settings files beside the book; read-only, exact quanta. *)

module B = Bakhlo_household.Book

val pool_of :
  config:(string -> (string option, string) result) ->
  measure:string ->
  (B.coordinate list, string) result
(** The pool in daily-pace.tsv for [measure]; a malformed file refuses as a whole. *)

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
