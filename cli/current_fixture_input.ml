open Base
module D = Loam_domain
module S = Loam_application.Actual_source
module H = Loam_application.Current_quantity_groups
module P = Loam_application.Current_quantity_projection
module V = Loam_application.Actual_validity

type t = { source : S.command; zero_origins : D.Effect_coordinate.t list; groups : H.group list }
type error = { line : int; message : string }
type block =
  | Between
  | Event of { id : D.Identifier.Event.t; date : string; changes : D.Effect.t list }
  | Group of { roots : D.Identifier.Event.t list; assertions : P.assertion list }

let fail line message = Error { line; message }
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
                corrections = List.rev draft.source.corrections };
              groups = List.rev draft.groups; zero_origins = List.rev draft.zero_origins }
          | Between, [ "EVENT"; token; date ] ->
            let* id = identity line D.Identifier.Event.of_string token in
            scan (line + 1) (Event { id; date; changes = [] }) draft rest
          | Event { id; date; changes }, [ "EFFECT"; locus; measure; text ] ->
            let* c = coordinate line locus measure in
            let* quantity = quantity line text in
            let change = D.Effect.create ~locus:c.locus ~measure:c.measure ~quantity in
            scan (line + 1) (Event { id; date; changes = change :: changes }) draft rest
          | Event { id; date; changes }, [ "END-EVENT" ] ->
            let event = D.Event.create ~id ~effects:(List.rev changes) in
            let validity : V.fact = { event = id; valid_on = date } in
            let source = { draft.source with events = event :: draft.source.events; validities = validity :: draft.source.validities } in
            scan (line + 1) Between { draft with source } rest
          | Between, [ "CORRECTION"; target; replacement ] ->
            let* target = identity line D.Identifier.Event.of_string target in
            let* replacement = identity line D.Identifier.Event.of_string replacement in
            let correction : D.Event_correction.t = { target; replacement } in
            let source = { draft.source with corrections = correction :: draft.source.corrections } in
            scan (line + 1) Between { draft with source } rest
          | Between, [ "ZERO-ORIGIN"; locus; measure ] ->
            let* c = coordinate line locus measure in
            scan (line + 1) Between { draft with zero_origins = c :: draft.zero_origins } rest
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
          | (Between | Event _ | Group _), _ -> fail line "unknown, malformed or misplaced fixture row"
      in
      scan 2 Between { source = { events = []; validities = []; corrections = [] }; groups = []; zero_origins = [] } rows
    | _ -> fail 1 "expected LOAM-OCAML-ACTUAL-FIXTURE version 2 (not household data)"
;;
