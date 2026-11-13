(* Read-only Daily Pace target plan (LOAM DailyPaceTarget): given a target pace
   and optionally a date inside the current cycle, the largest whole daily spend
   that still reaches the target, or a few candidate horizons and the earliest
   reachable day. Assumes no income and no new Scheduled before the date; never
   publishes, reserves or forecasts a later cycle. *)
module B = Bakhlo_household.Book

(* The plan is `bk pace target`'s (Pace.plan and Pace.options): amounts are whole
   units of the pace Measure; the date may be [D], [M-D] or [YYYY-MM-DD]; undated,
   horizons of 3/7/14/21/28/42 days before the cycle's last day. *)

type t

val create : unit -> t

type step = Stay of t | Back

val update : book:B.t -> pace:(B.daily_pace, string) result -> t -> Ui_input.input -> step
(** Tab/Enter/Down and Shift-Tab/Up move between fields; j/k move the charted
    horizon while no date is entered; Esc/q close. Nothing else is input. *)

val frame :
  width_of:(string -> int) ->
  screen:int * int ->
  body:int * int ->
  book:B.t ->
  pace:(B.daily_pace, string) result ->
  t ->
  Ui_overlay.frame option
(** Floating over Daily Pace from 62×20 cells, otherwise covering the body. *)
