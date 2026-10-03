module D = Loam_domain
module A = Loam_application.Actual_quantity_preview
module Text = Loam_presentation.Actual_quantity_text

type request = { path : string; coordinate : D.Effect_coordinate.t }
type plan = Help | Read of request | Refused of string
let plan = function
  | [ "--help" ] -> Help
  | [ path; locus; measure ] ->
    (match D.Identifier.Locus.of_string locus, D.Identifier.Measure.of_string measure with
     | Ok locus, Ok measure -> Read { path; coordinate = { locus; measure } }
     | Error D.Identifier.Empty, _ | _, Error D.Identifier.Empty -> Refused "coordinate identities must not be empty")
  | _ -> Refused "expected FILE LOCUS MEASURE"
let help : Movement_command.output =
  { exit_code = 0; stderr = ""; stdout =
      "Usage: loam-ocaml inspect-actual-fixture FILE LOCUS MEASURE\n\
       Read ONLY a LOAM-OCAML-ACTUAL-FIXTURE v1 synthetic file; never write.\n\
       Base occurrence validity + exact assertion support; not full household admission.\n" }
let syntax_refusal message : Movement_command.output =
  { exit_code = 2; stdout = ""; stderr = "error: " ^ message ^ ".\nRun 'loam-ocaml inspect-actual-fixture --help' for usage.\n" }
let evaluate (request : request) contents : Movement_command.output =
  match contents with
  | Error message -> { exit_code = 1; stdout = "";
      stderr = Printf.sprintf "Cannot read synthetic fixture %S: %S\n" request.path message }
  | Ok text ->
    match Actual_fixture_input.decode text with
    | Error { line; message } -> syntax_refusal (Printf.sprintf "fixture line %d: %s" line message)
    | Ok command ->
      match A.run command with
      | Error error -> { exit_code = 1; stdout = ""; stderr = Text.refusal error }
      | Ok preview ->
        match A.query preview request.coordinate with
        | Ok answer -> { exit_code = 0; stdout = Text.preview answer; stderr = "" }
        | Error unavailable -> { exit_code = 3; stdout = Text.unknown unavailable; stderr = "" }
