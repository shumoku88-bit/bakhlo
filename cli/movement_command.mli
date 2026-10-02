(** Pure argument evaluation and rendering for validation-only movement checks.
    No files, data roots, durable identity, or household writes are involved. *)

type field = Locus | Measure

type syntax_error =
  | Command_required
  | Unknown_command of string
  | Unexpected_argument of string
  | Incomplete_effect of { position : int }
  | Invalid_identifier of
      { position : int
      ; field : field
      ; reason : Loam_domain.Identifier.error
      }
  | Invalid_quantity of
      { position : int
      ; text : string
      }

type refusal =
  | Syntax of syntax_error
  | Movement of Loam_domain.Movement.error list

type outcome =
  | Help
  | Validated of Loam_application.Movement_check.preview
  | Refused of refusal

(** Arguments exclude argv[0]. Decimal integers only; each --effect takes
    LOCUS MEASURE QUANTA. Does not infer defaults or silently ignore arguments.
    Typed Effects are submitted to the same application operation available to
    other clients; parsing does not own Movement semantics. *)
val evaluate : string list -> outcome

type output =
  { exit_code : int
  ; stdout : string
  ; stderr : string
  }

(** Pure human-readable output, not a versioned wire protocol. Opaque identifiers
    and invalid arguments are quoted/escaped; exact values are in quanta.
    Exit 0: help/validated; 1: domain refusal; 2: syntax refusal. *)
val render : outcome -> output
