let () =
  let arguments =
    match Stdlib.Array.to_list Stdlib.Sys.argv with
    | [] -> []
    | _program :: arguments -> arguments
  in
  let output =
    Loam_cli.Movement_command.render (Loam_cli.Movement_command.evaluate arguments)
  in
  Stdlib.output_string Stdlib.stdout output.stdout;
  Stdlib.output_string Stdlib.stderr output.stderr;
  Stdlib.exit output.exit_code
