(* Shell-owned initialization and retained Record session checks. *)
let run ~width_of () =
  First_run.check ~width_of ();
  Record_session_checks.self_check ~width_of ()
