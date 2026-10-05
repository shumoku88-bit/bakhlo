(** Decoded, UNADMITTED read-profile input. Not canonical household storage.
    Required sections: Actual and all four quantity-support images. Optional
    absence is a profile refusal, not corruption or invented empty support.
    Actual v1-v4 representable rows only; settlement/unknown rows refuse. *)
type operation_origin =
  { request_token : string
  ; event : Bakhlo_domain.Identifier.Event.t
  }
type t =
  { source : Bakhlo_application.Actual_source.command
  ; operation_origins : operation_origin list
  ; zero_origins : Bakhlo_domain.Effect_coordinate.t list
  ; openings : Bakhlo_application.Current_quantity_query.opening list
  ; groups : Bakhlo_application.Current_quantity_groups.group list
  ; presence : Bakhlo_application.Current_quantity_query.presence
  }
type error =
  | Missing_section of string
  | Unsupported_header of { section : string }
  | Unsupported_actual_evidence of { line : int }
  | Syntax of { section : string; line : int; problem : string }
  | Invalid_event of { line : int; event : Bakhlo_domain.Identifier.Event.t; error : Bakhlo_domain.Event.error }
val decode : Envelope.t -> (t, error) result
