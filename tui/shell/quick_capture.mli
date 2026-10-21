(* Quick capture: one line in front of Record (LOAM QuickCapture). The line is a
   description, an optional total and optional Locus words; past records with the
   same description are proposed as templates. Nothing is retained or published
   here: a complete line goes to Record's own Preview, anything else to the full
   form prefilled. *)
module B = Bakhlo_sexp.Daily_book

type t

val initial :
  book:B.t ->
  day:string ->
  measure:string ->
  roles:(string * Daily_overlays.accounting_role) list ->
  t
(** [day] dates the record unless a leading date word names another day; a
    month-day word means its latest occurrence not after [day]. *)

val with_roles : (string * Daily_overlays.accounting_role) list -> t -> t
val text : t -> string

type surface = {
  framed : bool;  (** The mode itself, never guessed from the height. *)
  width : int;  (** Physical cells of the rectangle. *)
  height : int;
  top : int;  (** First row of the rectangle. *)
  left : int;  (** First column of the rectangle. *)
}

val surface : int * int -> surface
(** [surface (width, height)] is the LOAM quick capture rectangle over a
    terminal of that size: framed and centered, or the whole area when the
    terminal is too small to frame. *)

type prefill = {
  day : string;
  description : string;
  rows : (string * string) list;  (** Locus token and signed amount text; receiving first. *)
  focus : int;  (** Record field to continue from: the first missing one. *)
}

type step = Stay of t | Cancel | Preview of prefill | Edit of prefill

val update : book:B.t -> t -> Ui_input.input -> step

val append : t -> string -> t
(** A single-line paste. *)

val view :
  book:B.t ->
  width_of:(string -> int) ->
  width:int ->
  height:int ->
  t ->
  (Daily_overlays.style * string) list
