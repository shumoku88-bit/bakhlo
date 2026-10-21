(* Why today's Daily Pace is what it is (LOAM DailyPaceWhy): each Pool balance
   with how its current quantity is supported, each protected Scheduled
   occurrence before cycle end, and the division that yields the pace. Only the
   terms of the same [Daily_book.daily_pace] answer; no arithmetic of its own. *)
module B = Bakhlo_sexp.Daily_book

val lines :
  width_of:(string -> int) ->
  width:int ->
  book:B.t ->
  B.daily_pace ->
  (Daily_overlays.style * string) list
(** Every explanation row before scrolling. *)

type t

val create : unit -> t

type step = Stay of t | Back

val update :
  width_of:(string -> int) ->
  body:int * int ->
  book:B.t ->
  pace:(B.daily_pace, string) result ->
  t ->
  Ui_input.input ->
  step
(** j/k/arrows, Page/Ctrl-d/u and Home/End scroll; Esc, q and ? close. *)

val frame :
  width_of:(string -> int) ->
  screen:int * int ->
  body:int * int ->
  book:B.t ->
  pace:(B.daily_pace, string) result ->
  t ->
  Ui_overlay.frame option
(** Floating from 62×20 body cells, otherwise covering the body. An unavailable
    answer is explained, never shown as zero. *)
