open Base
module D = Bakhlo_domain

type command = {
  id : D.Identifier.Event.t;
  valid_on : string;
  effects : D.Effect.t list;
  description : string option;
}

type candidate = {
  base_bytes : string;
  bytes : string;
  image : Bakhlo_application.Current_quantity_query.t;
}

type error =
  | Base of Read.error
  | Event of D.Event.error
  | Movement of D.Movement.error list
  | Candidate of Read.error

let base_bytes candidate = candidate.base_bytes
let bytes candidate = candidate.bytes
let image candidate = candidate.image
let ( let* ) result f = Result.bind result ~f

(* Matches the existing byte lexer, not OCaml's decimal-escape printer or UTF-8
   normalization. Identity/text bytes remain exact; raw ASCII controls are escaped. *)
let quote text =
  "\""
  ^ String.concat_map text ~f:(function
    | '"' -> "\\\""
    | '\\' -> "\\\\"
    | '\n' -> "\\n"
    | '\r' -> "\\r"
    | '\t' -> "\\t"
    | ('\000' .. '\031' | '\127') as c -> Printf.sprintf "\\x%02X" (Char.to_int c)
    | c -> String.of_char c)
  ^ "\""

let event_id id = quote (D.Identifier.Event.to_string id)

let effect_row e =
  let key =
    match D.Effect.key e with
    | None -> "anonymous"
    | Some key -> "key " ^ quote (D.Identifier.Effect_key.to_string key)
  in
  Printf.sprintf "effect %s %s %s %s\n" key
    (quote (D.Identifier.Locus.to_string (D.Effect.locus e)))
    (quote (D.Identifier.Measure.to_string (D.Effect.measure e)))
    (Z.to_string (D.Quantity.quanta (D.Effect.quantity e)))

let rows { id; valid_on; effects; description } target =
  Printf.sprintf "event %s %s\n" (event_id id) (quote valid_on)
  ^ String.concat ~sep:"" (List.map effects ~f:effect_row)
  ^ "end-event\n"
  ^ (match description with
    | None -> ""
    | Some text -> Printf.sprintf "describe %s %s\n" (event_id id) (quote text))
  ^
  match target with
  | None -> ""
  | Some target -> Printf.sprintf "correct %s %s\n" (event_id target) (event_id id)

let insert ~base rows =
  (* Called ONLY after whole Read admission of profile 1. Its final nonblank token
     is exactly the top-level three-byte [end]; subsequent bytes are delimiters.
     Drop only physical delimiters to locate it, never trim a field or base bytes. *)
  let before_trailing =
    String.rstrip base ~drop:(function ' ' | '\t' | '\n' -> true | _ -> false)
  in
  let offset = String.length before_trailing - 3 in
  String.prefix base offset ^ rows ^ String.drop_prefix base offset

let propose ~base target ({ id; valid_on = _; effects; description = _ } as command) =
  let* _ = Result.map_error (Read.of_string base) ~f:(fun error -> Base error) in
  let* _ = Result.map_error (D.Event.create ~id ~effects) ~f:(fun error -> Event error) in
  let* _ = Result.map_error (D.Movement.validate effects) ~f:(fun error -> Movement error) in
  let bytes = insert ~base (rows command target) in
  let* image = Result.map_error (Read.of_string bytes) ~f:(fun error -> Candidate error) in
  Ok { base_bytes = base; bytes; image }

let append_movement ~base command = propose ~base None command
let correct_movement ~base ~target command = propose ~base (Some target) command
