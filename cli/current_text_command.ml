module R = Bakhlo_text.Read
module I = Bakhlo_text.Input
module Text = Bakhlo_presentation.Current_quantity_text

type request = { path : string; questions : Quantity_questions.t; explain : bool }
type plan = Help | Read of request | Refused of string

let plan = function
  | [ "--help" ] -> Help
  | arguments -> (
      let explain, arguments =
        match arguments with "--explain" :: rest -> (true, rest) | rest -> (false, rest)
      in
      match arguments with
      | [] -> Refused "expected FILE LOCUS MEASURE [LOCUS MEASURE ...]"
      | path :: coordinates -> (
          match Quantity_questions.plan coordinates with
          | Ok questions -> Read { path; questions; explain }
          | Error Missing_pair -> Refused "expected FILE LOCUS MEASURE [LOCUS MEASURE ...]"
          | Error Empty_identity -> Refused "coordinate identities must not be empty"))

let help : Response.t =
  {
    exit_code = 0;
    stderr = "";
    stdout =
      "Usage: bakhlo inspect-current-text [--explain] FILE LOCUS MEASURE [LOCUS MEASURE ...]\n\
       Experimental bakhlo-read 1 ordinary-actual-quantity; synthetic read only.\n\
       Exact/presence/unknown are conditional on supplied profile evidence.\n\
       All questions use one wholly admitted supplied image; order/duplicates retained.\n\
       With --explain, show supplied premises, Effects and retained correction paths.\n\
       Exit 3 if any unsupported, else 4 if any presence, else 0; stdout.\n\
       Not canonical storage, household authority, spending permission or Saved.\n";
  }

let syntax_refusal message : Response.t =
  {
    exit_code = 2;
    stdout = "";
    stderr = "error: " ^ message ^ ".\nRun 'bakhlo inspect-current-text --help' for usage.\n";
  }

let evaluate (request : request) contents : Response.t =
  match contents with
  | Error message ->
      {
        exit_code = 1;
        stdout = "";
        stderr = Printf.sprintf "Cannot read synthetic text %S: %S\n" request.path message;
      }
  | Ok text -> (
      match R.of_string text with
      | Error (Input (I.Syntax { line; problem })) ->
          syntax_refusal (Printf.sprintf "text line %d: %s" line problem)
      | Error (Input (Unsupported_version { line; version })) ->
          syntax_refusal (Printf.sprintf "text line %d: unsupported version %S" line version)
      | Error (Input (Unsupported_profile { line; profile })) ->
          syntax_refusal (Printf.sprintf "text line %d: unsupported profile %S" line profile)
      | Error (Input (Unsupported_record { line; name })) ->
          syntax_refusal (Printf.sprintf "text line %d: record %S outside profile" line name)
      | Error (Input (Invalid_event { line; event; error })) ->
          {
            exit_code = 1;
            stdout = "";
            stderr = Printf.sprintf "Text line %d: %s" line (Text.event_refusal event error);
          }
      | Error (Source error) -> { exit_code = 1; stdout = ""; stderr = Text.source_refusal error }
      | Error (Support error) -> { exit_code = 1; stdout = ""; stderr = Text.refusal error }
      | Ok image ->
          Quantity_questions.render request.questions ~explain:request.explain
            ~exact_heading:"Conditional text quantity (ordinary-actual-quantity v1; synthetic).\n"
            image)
