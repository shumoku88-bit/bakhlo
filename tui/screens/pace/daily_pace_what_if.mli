(* Read-only Daily Pace purchase scenario (LOAM DailyPaceWhatIf): an immediate
   purchase from the configured pool, not already Scheduled, priced against the
   current Daily Pace answer as you type. Never publishes or reserves. *)
module B = Bakhlo_sexp.Daily_book

type projection = {
  current_per_day : Z.t;
  projected_per_day : Z.t;
  change_per_day : Z.t;
  available_after : Z.t;
}

val project : book:B.t -> B.daily_pace -> string -> (projection, string) result
(** Exact quanta at the Measure's scale; a fraction is allowed only where the
    Measure has decimals. Floor division as the pace itself; no clamping. *)

type t

val create : unit -> t

type step = Stay of t | Back

val update : book:B.t -> measure:string -> pace:(B.daily_pace, string) result -> t -> Ui_input.input -> step
(** Digits (and [.] for decimal Measures) and Backspace edit; Esc/q close. *)

val frame :
  width_of:(string -> int) -> screen:int * int -> body:int * int -> book:B.t -> measure:string ->
  pace:(B.daily_pace, string) result -> t -> Ui_overlay.frame option
(** Floating 18 rows high from 62×20 body cells, otherwise covering the body. *)
