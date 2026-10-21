(* Whole-program synthetic checks with the Notty cell-width function: Shell
   sessions, cross-screen scenarios and the terminal adapter. Run with
   tools/tui --self-check. *)
let width_of = Notty_render.width_of

(* The checks write their synthetic books under scratch/ relative to the working
   directory. That directory must be outside _build: Dune removes files it did not
   produce there while other rules run. The path is resolved because the writer
   refuses symlinked components (macOS temporary directories are symlinks). *)
let enter_fresh_directory ~examples_from =
  let fixture = Filename.concat examples_from "examples/daily-book.sexp" in
  let bytes = In_channel.with_open_bin fixture In_channel.input_all in
  let dir = Unix.realpath (Filename.temp_dir "bakhlo-app-checks" "") in
  Unix.mkdir (Filename.concat dir "examples") 0o700;
  Unix.mkdir (Filename.concat dir "scratch") 0o700;
  Out_channel.with_open_bin (Filename.concat dir "examples/daily-book.sexp") (fun channel ->
      Out_channel.output_string channel bytes);
  Sys.chdir dir;
  dir

let rec remove_tree path =
  match (Unix.lstat path).st_kind with
  | Unix.S_DIR ->
      Array.iter (fun name -> remove_tree (Filename.concat path name)) (Sys.readdir path);
      Unix.rmdir path
  | _ -> Unix.unlink path

let () =
  (* Dune passes the build root, which holds the synthetic examples/ fixture. *)
  let examples_from = if Array.length Sys.argv = 2 then Unix.realpath Sys.argv.(1) else "." in
  let dir = enter_fresh_directory ~examples_from in
  try
    Interaction_check_fixture.materialize_example_book ();
    Shell_checks.run ~width_of ();
    Scheduled_session_checks.self_check ~width_of ();
    Actual_workspace_checks.self_check ~width_of ();
    Scenarios.run ~width_of ();
    Terminal_checks.run ();
    (* Kept on failure for inspection; removed once everything passed. *)
    remove_tree dir
  with
  | Daily_file.Refused why ->
      prerr_endline ("self-check failed: " ^ why ^ " (synthetic files kept in " ^ dir ^ ")");
      exit 1
  | exn ->
      prerr_endline
        ("self-check exception: " ^ Printexc.to_string exn ^ " (synthetic files kept in " ^ dir
       ^ ")");
      exit 1
