(** Process adapter result; only the shell writes streams or exits. *)
type t = { exit_code : int; stdout : string; stderr : string }
