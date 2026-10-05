module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module R = Bakhlo_loam_read.Read
module I = Bakhlo_loam_read.Input
module E = Bakhlo_loam_read.Envelope
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
      "Usage: bakhlo inspect-loam-quantity FILE LOCUS MEASURE\n\
       Native, read-only LOAM HouseholdImage v2 conditional quantity profile.\n\
       Requires Actual and all four explicitly supplied quantity-support sections.\n\
       Unsupported Actual/settlement rows refuse; other sections retained opaque.\n\
       No root selection, previous-file fallback, migration, recovery or writes.\n\
       Exit 0 exact, 4 known nonzero (amount unknown), 3 unsupported; stdout.\n\
       Not full-household admission, canonical storage, spending rights or Saved.\n" }
let syntax_refusal message : Response.t =
  { exit_code = 2; stdout = ""; stderr = "error: " ^ message ^ ".\nRun 'bakhlo inspect-loam-quantity --help' for usage.\n" }
let evaluate (request : request) contents : Response.t =
  let refused message : Response.t =
    { exit_code = 1; stdout = "";
      stderr = if Stdlib.String.ends_with ~suffix:"\n" message then message else message ^ "\n" } in
  match contents with
  | Error message -> refused (Printf.sprintf "Cannot read input file %S: %S" request.path message)
  | Ok bytes ->
    match R.of_string bytes with
    | Error (Envelope (E.Invalid_utf8 { byte_offset })) -> refused (Printf.sprintf "Invalid UTF-8 at byte %d." byte_offset)
    | Error (Envelope (Framing { byte_offset; problem })) -> refused (Printf.sprintf "HouseholdImage byte %d: %s." byte_offset problem)
    | Error (Input (I.Missing_section name)) -> refused (Printf.sprintf "Read profile unavailable: missing required section %S (not a corruption diagnosis)." name)
    | Error (Input (Unsupported_header { section })) -> refused (Printf.sprintf "%s: unsupported header/version." section)
    | Error (Input (Unsupported_actual_evidence { line })) -> refused (Printf.sprintf "Actual line %d: evidence outside this read profile; no rows discarded." line)
    | Error (Input (Syntax { section; line; problem })) -> refused (Printf.sprintf "%s line %d: %s." section line problem)
    | Error (Input (Invalid_event { line; event; error })) -> refused (Printf.sprintf "Actual line %d: %s" line (Text.event_refusal event error))
    | Error (Source error) -> refused (Text.source_refusal error)
    | Error (Operation_origins (Repeated_request { request_token = _; position })) -> refused (Printf.sprintf "Repeated logical publication-request origin at position %d." position)
    | Error (Operation_origins (Repeated_event { event = _; position })) -> refused (Printf.sprintf "Repeated origin Event at position %d." position)
    | Error (Operation_origins (Unknown_event { event = _; position })) -> refused (Printf.sprintf "Unknown origin Event at position %d." position)
    | Error (Support error) -> refused (Text.refusal error)
    | Ok image ->
      match Q.query (R.quantity_image image) request.coordinate with
      | Ok (Exact answer) -> { exit_code = 0; stderr = "";
          stdout = "Conditional LOAM-input quantity (Actual/four-support read profile; not household authority).\n" ^ Text.exact_row answer }
      | Ok (Known_present answer) -> { exit_code = 4; stderr = ""; stdout = Text.present answer }
      | Error unavailable -> { exit_code = 3; stderr = ""; stdout = Text.unavailable unavailable }
