module S = Loam_application.Actual_source
module Q = Loam_application.Current_quantity_query
module D = Loam_domain
module Text = Loam_presentation.Current_quantity_text

type request = { path : string; coordinate : D.Effect_coordinate.t }
type plan = Help | Read of request | Refused of string
let plan = function
  | [ "--help" ] -> Help
  | [ path; locus; measure ] ->
    (match D.Identifier.Locus.of_string locus, D.Identifier.Measure.of_string measure with
     | Ok locus, Ok measure -> Read { path; coordinate = { locus; measure } }
     | Error D.Identifier.Empty, _ | _, Error D.Identifier.Empty -> Refused "coordinate identities must not be empty")
  | _ -> Refused "expected FILE LOCUS MEASURE"
let help : Response.t =
  { exit_code = 0; stderr = ""; stdout =
      "Usage: loam-ocaml inspect-current-fixture FILE LOCUS MEASURE\n\
       Read ONLY a LOAM-OCAML-ACTUAL-FIXTURE v2 synthetic file; never write.\n\
       Ordinary base Actual subset; separated origin/opening/assertion/presence support.\n\
       Exit 0 exact, 4 known nonzero (amount unknown), 3 unsupported; stdout.\n\
       Not full normalized admission, historical completeness or household authority.\n" }
let syntax_refusal message : Response.t =
  { exit_code = 2; stdout = ""; stderr = "error: " ^ message ^ ".\nRun 'loam-ocaml inspect-current-fixture --help' for usage.\n" }
let evaluate (request : request) contents : Response.t =
  match contents with
  | Error message -> { exit_code = 1; stdout = "";
      stderr = Printf.sprintf "Cannot read synthetic fixture %S: %S\n" request.path message }
  | Ok text ->
    match Current_fixture_input.decode text with
    | Error { line; message } -> syntax_refusal (Printf.sprintf "fixture line %d: %s" line message)
    | Ok { source; zero_origins; openings; groups; presence } ->
      match S.create source with
      | Error error -> { exit_code = 1; stdout = ""; stderr = Text.source_refusal error }
      | Ok source ->
        match Q.create ~source ~zero_origins ~openings ~groups ~presence with
        | Error error -> { exit_code = 1; stdout = ""; stderr = Text.refusal error }
        | Ok image ->
          match Q.query image request.coordinate with
          | Ok (Exact answer) -> { exit_code = 0; stdout = Text.answer answer; stderr = "" }
          | Ok (Known_present answer) -> { exit_code = 4; stdout = Text.present answer; stderr = "" }
          | Error unavailable -> { exit_code = 3; stdout = Text.unavailable unavailable; stderr = "" }
