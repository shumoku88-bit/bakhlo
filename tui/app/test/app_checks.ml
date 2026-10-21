(* Whole-program synthetic checks with the Notty cell-width function: Shell
   sessions, cross-screen scenarios and the terminal adapter. Run with
   tools/tui --self-check. *)
let width_of = Notty_render.width_of

let () =
  (* Run from the build root given by Dune: synthetic examples/ and scratch/ live there. *)
  if Array.length Sys.argv = 2 then Sys.chdir Sys.argv.(1);
  if not (Sys.file_exists "scratch") then Unix.mkdir "scratch" 0o700;
  try
    Interaction_check_fixture.materialize_example_book ();
    Shell_checks.run ~width_of ();
    Scheduled_session_checks.self_check ~width_of ();
    Actual_workspace_checks.self_check ~width_of ();
    Scenarios.run ~width_of ();
    Terminal_checks.run ()
  with
  | Daily_file.Refused why ->
      prerr_endline ("self-check failed: " ^ why);
      exit 1
  | exn ->
      prerr_endline ("self-check exception: " ^ Printexc.to_string exn);
      exit 1
