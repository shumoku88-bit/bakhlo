open Base
module D = Loam_domain
module S = Loam_application.Actual_source
module H = Loam_application.Current_quantity_groups
module P = Loam_application.Current_quantity_projection
module V = Loam_application.Actual_validity
module Q = Loam_application.Current_quantity_query

type t = { source : S.command; zero_origins : D.Effect_coordinate.t list; openings : Q.opening list; groups : H.group list; presence : Q.presence option }
type error =
  | Syntax of { line : int; message : string }
  | Invalid_event of { line : int; event : D.Identifier.Event.t; error : D.Event.error }
type block =
  | Between
  | Event of { id : D.Identifier.Event.t; date : string; changes : D.Effect.t list }
  | Group of { roots : D.Identifier.Event.t list; assertions : P.assertion list }
  | Presence of { roots : D.Identifier.Event.t list; coordinates : D.Effect_coordinate.t list }

let fail line message = Error (Syntax { line; message })
let identity line constructor text =
  match constructor text with
  | Ok value -> Ok value
  | Error D.Identifier.Empty -> fail line "identity must not be empty"
;;
let quantity line text =
  let digits = if String.is_empty text then "" else
    match text.[0] with '+' | '-' -> String.drop_prefix text 1 | _ -> text in
  if String.is_empty digits || not (String.for_all digits ~f:Char.is_digit)
  then fail line "expected signed decimal integer"
  else Ok (D.Quantity.of_quanta (Z.of_string text))
;;
let coordinate line locus measure =
  let ( let* ) result f = Result.bind result ~f in
  let* locus = identity line D.Identifier.Locus.of_string locus in
  let* measure = identity line D.Identifier.Measure.of_string measure in
  Ok ({ locus; measure } : D.Effect_coordinate.t)
;;

let parse_change line key locus measure text =
  let ( let* ) result f = Result.bind result ~f in
  let* c = coordinate line locus measure in
  let* quantity = quantity line text in
  Ok (D.Effect.create ~key ~locus:c.locus ~measure:c.measure ~quantity)
;;

let decode text =
  let ( let* ) result f = Result.bind result ~f in
  if not (String.is_suffix text ~suffix:"\n") then fail 1 "fixture must end with newline"
  else match String.split (String.drop_suffix text 1) ~on:'\n' with
    | "LOAM-OCAML-ACTUAL-FIXTURE\t2" :: rows ->
      let rec scan line block (draft : t) = function
        | [] -> fail line "missing END or unterminated block"
        | row :: rest ->
          match block, String.split row ~on:'\t' with
          | Between, [ "END" ] ->
            if not (List.is_empty rest) then fail (line + 1) "rows after END"
            else Ok { source = { events = List.rev draft.source.events; validities = List.rev draft.source.validities;
                corrections = List.rev draft.source.corrections; descriptions = List.rev draft.source.descriptions };
              groups = List.rev draft.groups; zero_origins = List.rev draft.zero_origins; openings = List.rev draft.openings; presence = draft.presence }
          | Between, [ "EVENT"; token; date ] ->
            let* id = identity line D.Identifier.Event.of_string token in
            scan (line + 1) (Event { id; date; changes = [] }) draft rest
          | Event { id; date; changes }, [ "EFFECT"; locus; measure; text ] ->
            let* change = parse_change line None locus measure text in
            scan (line + 1) (Event { id; date; changes = change :: changes }) draft rest
          | Event { id; date; changes }, [ "KEYED-EFFECT"; token; locus; measure; text ] ->
            let* key = identity line D.Identifier.Effect_key.of_string token in
            let* change = parse_change line (Some key) locus measure text in
            scan (line + 1) (Event { id; date; changes = change :: changes }) draft rest
          | Event { id; date; changes }, [ "END-EVENT" ] ->
            let* event = Result.map_error (D.Event.create ~id ~effects:(List.rev changes))
                ~f:(fun error -> Invalid_event { line; event = id; error }) in
            let validity : V.fact = { event = id; valid_on = date } in
            let source = { draft.source with events = event :: draft.source.events; validities = validity :: draft.source.validities } in
            scan (line + 1) Between { draft with source } rest
          | Between, [ "CORRECTION"; target; replacement ] ->
            let* target = identity line D.Identifier.Event.of_string target in
            let* replacement = identity line D.Identifier.Event.of_string replacement in
            let correction : D.Event_correction.t = { target; replacement } in
            let source = { draft.source with corrections = correction :: draft.source.corrections } in
            scan (line + 1) Between { draft with source } rest
          | Between, [ "DESCRIPTION"; token; text ] ->
            let* event = identity line D.Identifier.Event.of_string token in
            let fact : Loam_application.Event_descriptions.fact = { event; text } in
            let source = { draft.source with descriptions = fact :: draft.source.descriptions } in
            scan (line + 1) Between { draft with source } rest
          | Between, [ "ZERO-ORIGIN"; locus; measure ] ->
            let* c = coordinate line locus measure in
            scan (line + 1) Between { draft with zero_origins = c :: draft.zero_origins } rest
          | Between, [ "OPENING"; locus; measure; token ] ->
            let* coordinate = coordinate line locus measure in
            let* opening_event = identity line D.Identifier.Event.of_string token in
            let opening : Q.opening = { coordinate; opening_event } in
            scan (line + 1) Between { draft with openings = opening :: draft.openings } rest
          | Between, [ "GROUP" ] -> scan (line + 1) (Group { roots = []; assertions = [] }) draft rest
          | Group { roots; assertions }, [ "REFLECT"; token ] ->
            let* root = identity line D.Identifier.Event.of_string token in
            scan (line + 1) (Group { roots = root :: roots; assertions }) draft rest
          | Group { roots; assertions }, [ "ASSERT"; locus; measure; text ] ->
            let* coordinate = coordinate line locus measure in
            let* quantity = quantity line text in
            scan (line + 1) (Group { roots; assertions = { coordinate; quantity } :: assertions }) draft rest
          | Group { roots; assertions }, [ "END-GROUP" ] ->
            let group : H.group = { reflected_roots = List.rev roots; assertions = List.rev assertions } in
            scan (line + 1) Between { draft with groups = group :: draft.groups } rest
          | Between, [ "PRESENCE" ] ->
            (match draft.presence with
             | Some _ -> fail line "repeated PRESENCE block"
             | None -> scan (line + 1) (Presence { roots = []; coordinates = [] }) draft rest)
          | Presence { roots; coordinates }, [ "REFLECT"; token ] ->
            let* root = identity line D.Identifier.Event.of_string token in
            scan (line + 1) (Presence { roots = root :: roots; coordinates }) draft rest
          | Presence { roots; coordinates }, [ "PRESENT"; locus; measure ] ->
            let* c = coordinate line locus measure in
            scan (line + 1) (Presence { roots; coordinates = c :: coordinates }) draft rest
          | Presence { roots; coordinates }, [ "END-PRESENCE" ] ->
            let presence : Q.presence = { reflected_roots = List.rev roots; coordinates = List.rev coordinates } in
            scan (line + 1) Between { draft with presence = Some presence } rest
          | (Between | Event _ | Group _ | Presence _), _ -> fail line "unknown, malformed or misplaced fixture row"
      in
      scan 2 Between { source = { events = []; validities = []; corrections = []; descriptions = [] }; groups = []; zero_origins = []; openings = []; presence = None } rows
    | _ -> fail 1 "expected LOAM-OCAML-ACTUAL-FIXTURE version 2 (not household data)"
;;
