module S = Loam_application.Actual_source
module Q = Loam_application.Current_quantity_query
module Text = Loam_presentation.Actual_quantity_text

type request = Actual_fixture_command.request
type plan = Actual_fixture_command.plan = Help | Read of request | Refused of string
let plan = Actual_fixture_command.plan
let help : Movement_command.output =
  { exit_code = 0; stderr = ""; stdout =
      "Usage: loam-ocaml inspect-current-fixture FILE LOCUS MEASURE\n\
       Read ONLY a LOAM-OCAML-ACTUAL-FIXTURE v2 synthetic file; never write.\n\
       Ordinary base Actual subset; separated zero-origin/exact assertion support.\n\
       Not full normalized admission, historical completeness or household authority.\n" }
let syntax_refusal message : Movement_command.output =
  { exit_code = 2; stdout = ""; stderr = "error: " ^ message ^ ".\nRun 'loam-ocaml inspect-current-fixture --help' for usage.\n" }
let evaluate (request : request) contents : Movement_command.output =
  match contents with
  | Error message -> Actual_fixture_command.evaluate request (Error message)
  | Ok text ->
    match Actual_fixture_input.decode_current text with
    | Error { line; message } -> syntax_refusal (Printf.sprintf "fixture line %d: %s" line message)
    | Ok { source; zero_origins; groups } ->
      match S.create source with
      | Error error -> { exit_code = 1; stdout = ""; stderr = Text.source_refusal error }
      | Ok source ->
        match Q.create ~source ~zero_origins ~groups with
        | Error error -> { exit_code = 1; stdout = ""; stderr = Text.current_refusal error }
        | Ok image ->
          match Q.query image request.coordinate with
          | Ok answer -> { exit_code = 0; stdout = Text.current_preview answer; stderr = "" }
          | Error unavailable -> { exit_code = 3; stdout = Text.current_unknown unavailable; stderr = "" }
