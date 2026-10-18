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
      val published : Screen.env -> Screen.geometry -> Screen.publish_outcome -> t -> t * Screen.request
      val reloaded : Screen.env -> t -> t * Screen.request  (* after a successful reload *)
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
  bytes : string;  (** Household file bytes the book was read from: a publication base. *)
  new_id : unit -> string;  (** Fresh identity for a new entry or plan. *)
  measure : string;  (** Shell-selected Measure. *)
  today : string;
  annual : annual;
  accounting_roles : (string * Daily_overlays.accounting_role) list Lazy.t;
      (** Explicit Locus roles from accounting-roles.tsv; none when absent. *)
  attention : (Attention_data.t, string) result;
      (** Attention memory loaded by the Shell; an error is never an empty list. *)
  settlements : (Settlement_data.t, string) result;
      (** Settlement commitments loaded by the Shell; an error is never empty. *)
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

(** A household ledger change the Shell publishes through the single writer
    against its current session; answered by the owner's [published]. *)
type publication =
  | Add_locus of string
  | Set_locus_label of { locus : string; label : string; help : string }
  | Commit_transaction of { transaction : Daily_draft.transaction; base : string }
      (** Publish an entry reviewed against [base]; a different file refuses. *)
  | Observe_quantities of { rows : (string * string * Z.t) list; base : string }
      (** Observe exact quantities together as one reconciliation group. *)
  (* Editor sessions: the Shell reports every outcome itself, as for Record. *)
  | Reverse_entry of { id : string; day : string; base : string }
  | Correct_entry of { transaction : Daily_draft.transaction; base : string }
  | Classify_merchant of {
      id : string; disposition : Bakhlo_application.Event_merchants.disposition; base : string;
      message : string;  (** Success report replacing the generic one. *)
    }
  | Cancel_plan of { id : string; day : string; base : string }
  | Plan_batch of { plans : Bakhlo_sexp.Daily_book.plan list; replace : bool; base : string }
  | Create_plan of { plan : Bakhlo_sexp.Daily_book.plan; base : string }

type publish_outcome =
  | Published  (** Read back; the Shell already reported it and reloaded the book. *)
  | Publish_refused of string  (** Nothing written; the editor keeps its input. *)
  | Publish_conflict  (** The file changed on disk; nothing written. *)
  | Publish_stopped  (** Writes stopped or the outcome is unknown; the Shell reports it. *)

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
  | Save_attention of { expected : Attention_data.t; next : Attention_data.t }
      (** Replace the Attention memory if it still equals [expected]; answered by [saved]. *)
  | Save_settlements of { expected : Settlement_data.t; next : Settlement_data.t }
      (** Replace the commitments if they still equal [expected]; answered by [saved]. *)
  | Publish of publication
  | Stop_writes of string option
      (** Stop all writes until reload; [Some why] also replaces the feedback line. *)
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

val no_reload : env -> 'a -> 'a * request
(** [reloaded] of an owner whose state never depends on the reloaded bytes. *)

val no_publication : env -> geometry -> publish_outcome -> 'a -> 'a * request
(** [published] of an owner that never publishes. *)

val env_for_checks :
  ?accounting_roles:(string * Daily_overlays.accounting_role) list ->
  ?config:(string -> (string option, string) result) ->
  book:Bakhlo_sexp.Daily_book.t -> measure:string -> today:string -> unit -> env
(** A synthetic environment for owner checks: no annual book, empty sidecars,
    writes allowed, undeclared configuration refused. *)
