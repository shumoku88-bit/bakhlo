let read_text path =
  try Ok (Stdlib.In_channel.with_open_bin path Stdlib.In_channel.input_all)
  with Stdlib.Sys_error message -> Error message

(* Fresh candidate-file staging only, NOT a selected household publisher. O_EXCL
   refuses existing files/symlinks. Never remove an artifact after output may begin.
   Local syscall sequencing owns descriptor cleanup; both write/close causes survive. *)
let stage_file path book =
  let module B = Bakhlo_sexp.Book in
  let module C = Bakhlo_cli.Current_sexp_command in
  let bytes = B.to_string book in
  let response code message : Bakhlo_cli.Response.t =
    { exit_code = code; stdout = ""; stderr = message ^ "\n" }
  in
  let detail error operation argument =
    Printf.sprintf "%s: %s (%S)" operation (Unix.error_message error) argument
  in
  let uncertain message =
    response 5
      (Printf.sprintf
         "Candidate output UNCERTAIN %S: %s; any artifact retained, no retry permission." path
         message)
  in
  match B.of_string bytes with
  | Error error -> C.codec_refusal error
  | Ok printed when B.to_string printed <> bytes ->
      response 1 "Candidate printer is not stable; no output created."
  | Ok _ -> (
      let opened =
        try Ok (Unix.openfile path [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_EXCL ] 0o600)
        with Unix.Unix_error (error, operation, argument) ->
          Error (error, detail error operation argument)
      in
      match opened with
      | Error (Unix.EEXIST, message) ->
          response 1 (Printf.sprintf "Candidate output refused %S: %s" path message)
      | Error (_, message) -> uncertain ("create attempt: " ^ message)
      | Ok fd -> (
          let written =
            try
              let rec write offset =
                if offset < String.length bytes then
                  let count = Unix.write_substring fd bytes offset (String.length bytes - offset) in
                  if count = 0 then Error "write returned zero before completion"
                  else write (offset + count)
                else Ok ()
              in
              write 0
            with Unix.Unix_error (error, operation, argument) ->
              Error (detail error operation argument)
          in
          let closed =
            try
              Unix.close fd;
              Ok ()
            with Unix.Unix_error (error, operation, argument) ->
              Error (detail error operation argument)
          in
          match (written, closed) with
          | Error primary, Error cleanup -> uncertain (primary ^ " / close: " ^ cleanup)
          | Error message, Ok () | Ok (), Error message -> uncertain message
          | Ok (), Ok () -> (
              match read_text path with
              | Error message -> uncertain message
              | Ok observed when observed <> bytes -> uncertain "readback bytes changed"
              | Ok _ ->
                  {
                    Bakhlo_cli.Response.exit_code = 0;
                    stderr = "";
                    stdout = "S-expression candidate staged; not recording or durable Saved.\n";
                  })))

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
              inspect-current-sexp [--summary | --explain] FILE LOCUS MEASURE [LOCUS MEASURE ...]\n\
              stage-current-sexp [--correct EVENT] BASE EVENT_FILE NEW_FILE\n\
              stage-current-sexp --canonicalize BASE NEW_FILE\n\
              inspect-loam-quantity [--summary | --explain] FILE LOCUS MEASURE [LOCUS MEASURE ...]\n\
              Structural validation, read-only questions and fresh candidate-file staging.\n\
              Not household authority, operational recording or durable Saved.\n\
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
    | "inspect-current-sexp" :: arguments -> (
        let module C = Bakhlo_cli.Current_sexp_command in
        match C.plan arguments with
        | Help -> C.help
        | Refused message -> C.syntax_refusal message
        | Read request -> C.evaluate request (read_text request.path))
    | "stage-current-sexp" :: arguments -> (
        let module C = Bakhlo_cli.Sexp_candidate_command in
        match C.plan arguments with
        | Help -> C.help
        | Refused message -> Bakhlo_cli.Current_sexp_command.syntax_refusal message
        | Stage request -> (
            let base = read_text (C.base_path request) in
            let event = Option.map read_text (C.event_path request) in
            match C.evaluate request ~base ~event with
            | Error response -> response
            | Ok book -> stage_file (C.output_path request) book))
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
