module B = Bakhlo_sexp.Book
module C = Current_sexp_command
module D = Bakhlo_domain

type operation =
  | Canonicalize
  | Append of string
  | Correct of { event : string; target : D.Identifier.Event.t }

type request = { base : string; output : string; operation : operation }
type plan = Help | Stage of request | Refused of string

let make base output operation =
  if base = "" || output = "" then Refused "file paths must not be empty"
  else
    match operation with
    | Append "" | Correct { event = ""; target = _ } -> Refused "event file path must not be empty"
    | Canonicalize | Append _ | Correct _ -> Stage { base; output; operation }

let plan = function
  | [ "--help" ] -> Help
  | [ "--canonicalize"; base; output ] -> make base output Canonicalize
  | [ "--correct"; target; base; event; output ] -> (
      match D.Identifier.Event.of_string target with
      | Error Empty -> Refused "correction identity must not be empty"
      | Ok target -> make base output (Correct { event; target }))
  | [ base; event; output ] when not (String.starts_with ~prefix:"--" base) ->
      make base output (Append event)
  | _ ->
      Refused "expected [--correct EVENT] BASE EVENT_FILE NEW_FILE, or --canonicalize BASE NEW_FILE"

let help : Response.t =
  {
    exit_code = 0;
    stderr = "";
    stdout =
      "Usage: bakhlo stage-current-sexp [--correct EVENT] BASE EVENT_FILE NEW_FILE\n\
       bakhlo stage-current-sexp --canonicalize BASE NEW_FILE\n\
       Development-only explicit candidate staging; Event input is one S-expression.\n\
       Retain original Events/metadata/Effects, explicit corrections, support/cuts and \
       interpretation.\n\
       Whole-admit before output creation; existing targets/symlinks refuse, never overwrite.\n\
       Source files stay unchanged; output is NOT recording, selected authority or durable Saved.\n\
       Exit 5 after uncertain output effects; retain artifacts, no cleanup or blind retry.\n";
  }

let base_path request = request.base
let output_path request = request.output

let event_path request =
  match request.operation with
  | Canonicalize -> None
  | Append path | Correct { event = path; target = _ } -> Some path

let evaluate request ~base ~event =
  match C.read ~path:request.base base with
  | Error response -> Error response
  | Ok base -> (
      let propose path apply =
        match event with
        | None -> Error (C.syntax_refusal "missing supplied Event file")
        | Some (Error message) ->
            Error
              {
                Response.exit_code = 1;
                stdout = "";
                stderr = Printf.sprintf "Cannot read supplied Event file %S: %S\n" path message;
              }
        | Some (Ok event) -> (
            match apply event with
            | Error error -> Error (C.codec_refusal error)
            | Ok candidate -> Ok (B.document candidate))
      in
      match request.operation with
      | Canonicalize -> Ok base
      | Append path -> propose path (fun event -> B.append ~base ~event)
      | Correct { event = path; target } ->
          propose path (fun event -> B.correct ~base ~target ~event))
