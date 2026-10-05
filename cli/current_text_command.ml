module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module R = Bakhlo_text.Read
module I = Bakhlo_text.Input
module Text = Bakhlo_presentation.Current_quantity_text

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
      "Usage: bakhlo inspect-current-text FILE LOCUS MEASURE\n\
       Experimental bakhlo-read 1 ordinary-actual-quantity; synthetic read only.\n\
       Exact/presence/unknown are conditional on supplied profile evidence.\n\
       Exit 0 exact, 4 known nonzero (amount unknown), 3 unsupported; stdout.\n\
       Not canonical storage, household authority, spending permission or Saved.\n" }
let syntax_refusal message : Response.t =
  { exit_code = 2; stdout = ""; stderr = "error: " ^ message ^ ".\nRun 'bakhlo inspect-current-text --help' for usage.\n" }
let evaluate (request : request) contents : Response.t =
  match contents with
  | Error message -> { exit_code = 1; stdout = "";
      stderr = Printf.sprintf "Cannot read synthetic text %S: %S\n" request.path message }
  | Ok text ->
    match R.of_string text with
    | Error (Input (I.Syntax { line; problem })) -> syntax_refusal (Printf.sprintf "text line %d: %s" line problem)
    | Error (Input (Unsupported_version { line; version })) ->
      syntax_refusal (Printf.sprintf "text line %d: unsupported version %S" line version)
    | Error (Input (Unsupported_profile { line; profile })) ->
      syntax_refusal (Printf.sprintf "text line %d: unsupported profile %S" line profile)
    | Error (Input (Unsupported_record { line; name })) ->
      syntax_refusal (Printf.sprintf "text line %d: record %S outside profile" line name)
    | Error (Input (Invalid_event { line; event; error })) ->
      { exit_code = 1; stdout = ""; stderr = Printf.sprintf "Text line %d: %s" line (Text.event_refusal event error) }
    | Error (Source error) -> { exit_code = 1; stdout = ""; stderr = Text.source_refusal error }
    | Error (Support error) -> { exit_code = 1; stdout = ""; stderr = Text.refusal error }
    | Ok image ->
      match Q.query image request.coordinate with
      | Ok (Exact answer) -> { exit_code = 0; stderr = "";
          stdout = "Conditional text quantity (ordinary-actual-quantity v1; synthetic).\n" ^ Text.exact_row answer }
      | Ok (Known_present answer) -> { exit_code = 4; stderr = ""; stdout = Text.present answer }
      | Error unavailable -> { exit_code = 3; stderr = ""; stdout = Text.unavailable unavailable }
