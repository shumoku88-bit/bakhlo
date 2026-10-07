open Base

module Sexp = Sexplib0.Sexp

type syntax_error = {
  line : int;
  column : int;
  message : string;
}

type error =
  | Syntax of syntax_error
  | Missing_format_marker
  | Invalid_format_marker
  | Unsupported_format_version of string
  | Duplicate_format_marker

type t = { forms : Sexp.t list }

let format_marker = Sexp.List [ Sexp.Atom "bakhlo"; Sexp.Atom "1" ]

let marker_version = function
  | Sexp.List [ Sexp.Atom "bakhlo"; Sexp.Atom version ] -> Some version
  | _ -> None

let has_bakhlo_head = function
  | Sexp.List (Sexp.Atom "bakhlo" :: _) -> true
  | _ -> false

let syntax_error error =
  let position = Parsexp.Parse_error.position error in
  Syntax
    {
      line = position.line;
      column = position.col;
      message = Parsexp.Parse_error.message error;
    }

let of_string text =
  match Parsexp.Many.parse_string text with
  | Error error -> Error (syntax_error error)
  | Ok [] -> Error Missing_format_marker
  | Ok (first :: forms) -> (
      match marker_version first with
      | None ->
          if has_bakhlo_head first then Error Invalid_format_marker
          else Error Missing_format_marker
      | Some version ->
          if not (String.equal version "1") then Error (Unsupported_format_version version)
          else if List.exists forms ~f:has_bakhlo_head then Error Duplicate_format_marker
          else Ok { forms })

let to_string document =
  let render form = Sexp.to_string_hum ~indent:2 ~max_width:100 form in
  String.concat ~sep:"\n\n" (List.map (format_marker :: document.forms) ~f:render) ^ "\n"
