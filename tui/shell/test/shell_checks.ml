(* Unit checks of editor sessions and reports that still live in the Shell layer. *)
let run ~width_of () =
  First_run.check ~width_of ();
  Record_session_checks.self_check ~width_of ();
  Scheduled_session_checks.self_check ~width_of ();
  Actual_workspace_checks.self_check ~width_of ()
