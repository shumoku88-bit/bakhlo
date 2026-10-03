let () =
  let arguments =
    match Stdlib.Array.to_list Stdlib.Sys.argv with
    | [] -> []
    | _program :: arguments -> arguments
  in
  let output =
    match arguments with
    | "inspect-actual-fixture" :: arguments ->
      let module C = Loam_cli.Actual_fixture_command in
      (match C.plan arguments with
       | Help -> C.help
       | Refused message -> C.syntax_refusal message
       | Read request ->
         let contents =
           try Ok (Stdlib.In_channel.with_open_bin request.path Stdlib.In_channel.input_all)
           with Stdlib.Sys_error message -> Error message
         in
         C.evaluate request contents)
    | _ -> Loam_cli.Movement_command.render (Loam_cli.Movement_command.evaluate arguments)
  in
  Stdlib.output_string Stdlib.stdout output.stdout;
  Stdlib.output_string Stdlib.stderr output.stderr;
  Stdlib.exit output.exit_code
