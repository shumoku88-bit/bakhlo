open Base
open Loam_domain

module Check = Loam_application.Movement_check
module Text = Loam_presentation.Movement_text

type field = Locus | Measure

type syntax_error =
  | Command_required
  | Unknown_command of string
  | Unexpected_argument of string
  | Incomplete_effect of { position : int }
  | Invalid_identifier of
      { position : int
      ; field : field
      ; reason : Identifier.error
      }
  | Invalid_quantity of
      { position : int
      ; text : string
      }

type refusal =
  | Syntax of syntax_error
  | Movement of Movement.error list

type outcome =
  | Help
  | Validated of Check.preview
  | Refused of refusal

type output =
  { exit_code : int
  ; stdout : string
  ; stderr : string
  }

let parse_quantity ~position text =
  let digits =
    if String.is_empty text
    then ""
    else (
      match String.get text 0 with
      | '+' | '-' -> String.drop_prefix text 1
      | _ -> text)
  in
  if String.is_empty digits || not (String.for_all digits ~f:Char.is_digit)
  then Error (Invalid_quantity { position; text })
  else Ok (Quantity.of_quanta (Z.of_string text))
;;

let parse_effect ~position locus measure quantity =
  let ( let* ) result f = Result.bind result ~f in
  let* locus =
    Result.map_error (Identifier.Locus.of_string locus) ~f:(fun reason ->
      Invalid_identifier { position; field = Locus; reason })
  in
  let* measure =
    Result.map_error (Identifier.Measure.of_string measure) ~f:(fun reason ->
      Invalid_identifier { position; field = Measure; reason })
  in
  let* quantity = parse_quantity ~position quantity in
  Ok (Effect.create ~locus ~measure ~quantity)
;;

let evaluate arguments =
  let rec collect position reversed = function
    | [] ->
      (match Check.run { effects = List.rev reversed } with
       | Ok preview -> Validated preview
       | Error errors -> Refused (Movement errors))
    | "--effect" :: locus :: measure :: quantity :: rest ->
      (match parse_effect ~position locus measure quantity with
       | Error error -> Refused (Syntax error)
       | Ok change -> collect (position + 1) (change :: reversed) rest)
    | "--effect" :: _ -> Refused (Syntax (Incomplete_effect { position }))
    | argument :: _ -> Refused (Syntax (Unexpected_argument argument))
  in
  match arguments with
  | [ "--help" ] | [ "help" ] | [ "check-movement"; "--help" ] -> Help
  | [] -> Refused (Syntax Command_required)
  | "check-movement" :: effects -> collect 1 [] effects
  | command :: _ -> Refused (Syntax (Unknown_command command))
;;

let usage =
  "Usage: loam-ocaml check-movement --effect LOCUS MEASURE QUANTA [--effect ...]\n\
   \n\
   Validate an ordinary single-Measure movement without recording it.\n\
   QUANTA is an exact signed decimal integer, not display currency units.\n\
   No household data is read or written.\n"
;;

let describe_syntax_error = function
  | Command_required -> "a command is required."
  | Unknown_command command -> Stdlib.Printf.sprintf "unknown command %S." command
  | Unexpected_argument argument ->
    Stdlib.Printf.sprintf "unexpected argument %S." argument
  | Incomplete_effect { position } ->
    Stdlib.Printf.sprintf "Effect %d: --effect requires LOCUS MEASURE QUANTA." position
  | Invalid_identifier { position; field; reason = Identifier.Empty } ->
    let name = match field with Locus -> "Locus" | Measure -> "Measure" in
    Stdlib.Printf.sprintf "Effect %d: %s identity must not be empty." position name
  | Invalid_quantity { position; text } ->
    Stdlib.Printf.sprintf "Effect %d: expected a signed decimal integer, got %S." position text
;;

let render = function
  | Help -> { exit_code = 0; stdout = usage; stderr = "" }
  | Validated preview -> { exit_code = 0; stdout = Text.preview preview; stderr = "" }
  | Refused (Movement errors) ->
    { exit_code = 1; stdout = ""; stderr = Text.refusal errors }
  | Refused (Syntax error) ->
    { exit_code = 2
    ; stdout = ""
    ; stderr =
        "error: " ^ describe_syntax_error error ^ "\nRun 'loam-ocaml --help' for usage.\n"
    }
;;
