module B = Bakhlo_sexp.Book
module Text = Bakhlo_presentation.Current_quantity_text

type request = { path : string; questions : Quantity_questions.t; view : Quantity_questions.view }
type plan = Help | Read of request | Refused of string

let syntax_refusal message : Response.t =
  { exit_code = 2; stdout = ""; stderr = "error: " ^ message ^ ".\n" }

let plan = function
  | [ "--help" ] -> Help
  | arguments -> (
      match Quantity_questions.select_view arguments with
      | Error message -> Refused message
      | Ok (view, path :: coordinates) -> (
          match Quantity_questions.plan coordinates with
          | Ok questions -> Read { path; questions; view }
          | Error Missing_pair -> Refused "expected FILE LOCUS MEASURE [LOCUS MEASURE ...]"
          | Error Empty_identity -> Refused "coordinate identities must not be empty")
      | Ok (_, []) -> Refused "expected FILE LOCUS MEASURE [LOCUS MEASURE ...]")

let help : Response.t =
  {
    exit_code = 0;
    stderr = "";
    stdout =
      "Usage: bakhlo inspect-current-sexp [--summary | --explain] FILE LOCUS MEASURE [LOCUS \
       MEASURE ...]\n\
       Development-only bakhlo 1/2/3 ordinary-quantity; whole supplied-book admission.\n\
       Explicit Measure/scale, retained Actual/corrections, independent observations/zero origins.\n\
       Other fields/families refuse; not full household admission, authority or Saved.\n\
       Quantities are exact signed quanta, not inferred balances or currency conversion.\n\
       Exit 3 if any unsupported, else 4 if any presence, else 0; stdout.\n";
  }

let codec_refusal error : Response.t =
  let refused stderr = { Response.exit_code = 1; stdout = ""; stderr } in
  match error with
  | B.Syntax error -> syntax_refusal ("S-expression syntax: " ^ Parsexp.Parse_error.message error)
  | B.Wire { at; problem } -> syntax_refusal ("S-expression " ^ at ^ ": " ^ problem)
  | B.Event { event; error } -> refused (Text.event_refusal event error)
  | B.Movement _ -> refused "Ordinary Movement proposal refused.\n"
  | B.Source error -> refused (Text.source_refusal error)
  | B.Support error -> refused (Text.refusal error)

let read ~path contents =
  match contents with
  | Error message ->
      Error
        {
          Response.exit_code = 1;
          stdout = "";
          stderr = Printf.sprintf "Cannot read supplied S-expression file %S: %S\n" path message;
        }
  | Ok bytes -> (
      match B.of_string bytes with Ok book -> Ok book | Error error -> Error (codec_refusal error))

let evaluate (request : request) contents =
  match read ~path:request.path contents with
  | Error response -> Quantity_questions.input_refusal request.view response
  | Ok book ->
      Quantity_questions.render request.questions ~view:request.view
        ~exact_heading:
          (Printf.sprintf
             "Conditional S-expression quantity (ordinary-quantity v%d; supplied evidence).\n"
             (B.version book))
        (B.image book)
