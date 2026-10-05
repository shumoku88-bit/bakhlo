let read_text path =
  try Ok (Stdlib.In_channel.with_open_bin path Stdlib.In_channel.input_all)
  with Stdlib.Sys_error message -> Error message

let () =
  let arguments =
    match Stdlib.Array.to_list Stdlib.Sys.argv with [] -> [] | _program :: arguments -> arguments
  in
  let output =
    match arguments with
    | [ "--help" ] | [ "help" ] ->
        ({
           exit_code = 0;
           stderr = "";
           stdout =
             "Usage: bakhlo COMMAND ...\n\
              check-movement --effect LOCUS MEASURE QUANTA [--effect ...]\n\
              inspect-current-fixture FILE LOCUS MEASURE\n\
              inspect-current-text [--summary | --explain] FILE LOCUS MEASURE [LOCUS MEASURE ...]\n\
              inspect-loam-quantity [--summary | --explain] FILE LOCUS MEASURE [LOCUS MEASURE ...]\n\
              Structural validation and read-only conditional quantity queries.\n\
              Not household admission or authority; no writes.\n\
              Use COMMAND --help for details.\n";
         }
          : Bakhlo_cli.Response.t)
    | "inspect-current-fixture" :: arguments -> (
        let module C = Bakhlo_cli.Current_fixture_command in
        match C.plan arguments with
        | Help -> C.help
        | Refused message -> C.syntax_refusal message
        | Read request -> C.evaluate request (read_text request.path))
    | "inspect-loam-quantity" :: arguments -> (
        let module C = Bakhlo_cli.Loam_quantity_command in
        match C.plan arguments with
        | Help -> C.help
        | Refused message -> C.syntax_refusal message
        | Read request -> C.evaluate request (read_text request.path))
    | "inspect-current-text" :: arguments -> (
        let module C = Bakhlo_cli.Current_text_command in
        match C.plan arguments with
        | Help -> C.help
        | Refused message -> C.syntax_refusal message
        | Read request -> C.evaluate request (read_text request.path))
    | _ -> Bakhlo_cli.Movement_command.render (Bakhlo_cli.Movement_command.evaluate arguments)
  in
  Stdlib.output_string Stdlib.stdout output.stdout;
  Stdlib.output_string Stdlib.stderr output.stderr;
  Stdlib.exit output.exit_code
