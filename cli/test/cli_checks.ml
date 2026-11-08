(* Every bk command against synthetic books, with scripted answers. The checks write
   their books under scratch/ in a fresh temporary directory, never under _build
   (Dune removes files it did not produce) and never near a household book. *)
let rec remove_tree path =
  match (Unix.lstat path).st_kind with
  | Unix.S_DIR ->
      Array.iter (fun name -> remove_tree (Filename.concat path name)) (Sys.readdir path);
      Unix.rmdir path
  | _ -> Unix.unlink path

let () =
  (* The writer refuses symlinked components; macOS temporary directories are links. *)
  let dir = Unix.realpath (Filename.temp_dir "bakhlo-cli-checks" "") in
  Unix.mkdir (Filename.concat dir "scratch") 0o700;
  Sys.chdir dir;
  Printexc.record_backtrace true;
  try
    Line_commands_checks.run_all ();
    remove_tree dir
  with exn ->
    prerr_endline
      ("bk check failed: " ^ Printexc.to_string exn ^ " (synthetic files kept in " ^ dir ^ ")");
    prerr_string (Printexc.get_backtrace ());
    exit 1
