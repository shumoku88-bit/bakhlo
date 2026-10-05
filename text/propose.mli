type command = {
  id : Bakhlo_domain.Identifier.Event.t;
  valid_on : string;
  effects : Bakhlo_domain.Effect.t list;
  description : string option;
}
(** Pure ordinary-Movement proposals for the EXPERIMENTAL read profile only.
    Explicit supplied Event ID/date/effects/optional description; no clock, allocation,
    inferred support, I/O, recording permission or canonical format adoption.
    Base whole-admission precedes command admission; the complete resulting document
    is admitted again. Only NEW rows are encoded: every base byte is retained around
    an insertion before its final [end]. Richer/unsupported bases refuse wholesale.
    Correction retains the target and its evidence, adding a new Event and explicit
    edge; existing source gates require a retained terminal target and fresh ID.
    Dates/descriptions do not inherit. Opening/support changes are not automatic;
    an invalidated opening refuses rather than being retargeted or dropped. *)

type candidate
(** Immutable whole-admitted proposal, NOT a snapshot token or authority to publish.
    A publisher must bind [base_bytes] to its coherent expected generation, revalidate
    current evidence and own publication/receipt/lifecycle effects separately.
    Bytes/image expose owner evidence, not least-disclosure or authorization. *)

type error =
  | Base of Read.error
  | Event of Bakhlo_domain.Event.error
  | Movement of Bakhlo_domain.Movement.error list
  | Candidate of Read.error

val append_movement : base:string -> command -> (candidate, error) result

val correct_movement :
  base:string -> target:Bakhlo_domain.Identifier.Event.t -> command -> (candidate, error) result

val base_bytes : candidate -> string
val bytes : candidate -> string
val image : candidate -> Bakhlo_application.Current_quantity_query.t
