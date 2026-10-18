(** The whole contract between the Shell and a screen owner.

    A screen owner is an ordinary module with private state. It receives this
    read-only environment and the current geometry, interprets its own input,
    renders itself and returns a {!request} for anything outside its state.
    It never receives the Shell state, never writes a file, never publishes
    and never inspects another screen. Conventional owner functions:

    {[
      val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
      val view : Screen.env -> Screen.geometry -> t -> Screen.view
      val modal : t -> bool
      val saved : Screen.env -> Screen.geometry -> (unit, string) result -> t -> t * Screen.request
    ]} *)

type annual = {
  year : int option;  (** Explicitly named annual book, if any. *)
  unavailable : string option Lazy.t;
      (** Qualified prior-year opening evidence is missing (verified on demand). *)
  history : ((string * string) option, string) result Lazy.t;
      (** Verified linked history as [first_day, end_exclusive]. *)
}

type env = {
  book : Bakhlo_sexp.Daily_book.t;
  measure : string;  (** Shell-selected Measure. *)
  today : string;
  annual : annual;
  accounting_roles : (string * Daily_overlays.accounting_role) list Lazy.t;
      (** Explicit Locus roles from accounting-roles.tsv; none when absent. *)
  blocked : bool;  (** Writes stopped after a conflict, recovery or uncertain outcome. *)
  config : string -> (string option, string) result;
      (** Bytes of a configuration file captured for this event: [Ok None] is
          missing, never empty; an error is never a default. *)
}

type geometry = {
  screen : int * int;  (** Whole terminal. *)
  body : int * int;  (** Region above feedback and footer; overlays float here. *)
  content : int * int;  (** The screen's own rows below the Shell header. *)
  width_of : string -> int;
}

(** Precondition the Shell checks against the current household file before
    writing a configuration file. *)
type admission =
  | Unconditional
  | Household_readable  (** The household file still parses. *)
  | Vocabulary_unchanged
      (** Admitted Loci and Measures of the current file equal the screen's book. *)

type request =
  | Stay
  | Ignored  (** Not this screen's input; the Shell applies its global keys. *)
  | Message of string  (** Replace the Shell feedback line; [""] clears it. *)
  | Home
  | Commands
  | Reload
  | Cycle_measure of [ `Next | `Prev ]  (** Change the Shell-selected Measure. *)
  | Observe of { locus : string; measure : string; amount : Z.t option }
      (** Open the Observe editor for this coordinate; [amount] is a known current value. *)
  | Save_config of {
      file : string;
      expected : string option;  (** Captured bytes; a different file refuses. *)
      content : string;
      admission : admission;
    }  (** Answered by the owner's [saved] function. *)

type view = {
  title : string;  (** Header path segment after "Bakhlo  /  ". *)
  subtitle : string option;  (** Second header line; [None] keeps the Shell date line. *)
  rows : (Ui_render.style * string) list Lazy.t;
      (** Sized to [geometry.content]; forced only when this screen is the route. *)
  footer : string list;
  overlay : Ui_overlay.frame option;
  cursor : (int * int) option;
}
