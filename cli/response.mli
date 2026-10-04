(** Terminal process adapter result; only the shell writes streams or exits.
    Not a household answer, service-health model or versioned machine protocol.
    Other clients consume structured Domain/Application values, not stdout parsing;
    exit success does not establish recording, durable Saved or household truth. *)
type t = { exit_code : int; stdout : string; stderr : string }
