(** The Actual's period picker: every window of one period, newest first, with its
    entry count and EXPENSE total, so a cycle, month or year is chosen from a list
    rather than stepped to. The Actual's Screen supplies the windows (only it reads
    the configured presets); the picker owns the selection and the painting. *)

type window = { start_day : string; end_exclusive : string }

type row = {
  window : window;
  label : string;
  now : bool;  (** The window contains today. *)
  count : int;
  total : string option;  (** EXPENSE per Measure; [None] when nothing to show. *)
}

type t

val label : Actual_workspace.period -> window -> string
(** The window as the period bar and the list name it. *)

val windows :
  book:Bakhlo_sexp.Daily_book.t ->
  today:string ->
  reference:string ->
  cycle:((string * string) list, string) result ->
  Actual_workspace.period ->
  (window list, string) result
(** Every window of the period in ascending order: months and years from the
    earliest to the latest of the ledger, today and [reference]; the days that
    have entries, today and [reference]; the configured windows of the cycle that
    contains [reference]. An error names why the period has no windows. *)

val rows :
  ctx:Actual_workspace.context -> today:string -> Actual_workspace.period -> window list -> row list
(** One pass over the ledger: each entry counts in the window that contains it.
    Newest first. *)

val create : Actual_workspace.period -> rows:(row list, string) result -> reference:string -> t
(** Selects the row whose window contains [reference]. *)

val period : t -> Actual_workspace.period
val selected : t -> row option

val reference : today:string -> row -> string
(** The day a chosen window opens on: today inside it, else its last day. *)

type command = Stay | Kind of Actual_workspace.period | Choose of row | Refuse of string | Close

val handle : body:int * int -> t -> Ui_input.input -> t * command
(** [body] is the region the frame is centered in, for paging and scrolling.
    [Kind] asks the Screen for the windows of another period. *)

val frame :
  width_of:(string -> int) -> screen:int * int -> body:int * int -> t -> Ui_overlay.frame option

val footer : width:int -> string list
