open Base
module D = Bakhlo_domain
module A = Bakhlo_application
module L = Text_line

type t = {
  source : A.Actual_source.command;
  zero_origins : D.Effect_coordinate.t list;
  openings : A.Current_quantity_query.opening list;
  groups : A.Current_quantity_groups.group list;
  presence : A.Current_quantity_query.presence option;
}

type error =
  | Syntax of { line : int; problem : string }
  | Unsupported_version of { line : int; version : string }
  | Unsupported_profile of { line : int; profile : string }
  | Unsupported_record of { line : int; name : string }
  | Invalid_event of { line : int; event : D.Identifier.Event.t; error : D.Event.error }

let ( let* ) result f = Result.bind result ~f
let syntax line problem = Error (Syntax { line; problem })

let identity line make text =
  match make text with
  | Ok id -> Ok id
  | Error D.Identifier.Empty -> syntax line "identity must not be empty"

let event_id line = identity line D.Identifier.Event.of_string

let coordinate line locus measure =
  let* locus = identity line D.Identifier.Locus.of_string locus in
  let* measure = identity line D.Identifier.Measure.of_string measure in
  Ok ({ locus; measure } : D.Effect_coordinate.t)

let quantity line text =
  let length = String.length text in
  let start = if length > 0 && (Char.equal text.[0] '+' || Char.equal text.[0] '-') then 1 else 0 in
  let digits = String.sub text ~pos:start ~len:(length - start) in
  if
    String.is_empty digits
    || not (String.for_all digits ~f:(function '0' .. '9' -> true | _ -> false))
  then syntax line "quantity must be an exact signed decimal integer"
  else Ok (D.Quantity.of_quanta (Z.of_string text))

(* Lists reverse only during construction. No absent field is inferred from activity;
   unexpressible evidence families are rejected by the profile, not dropped rows. *)
let empty =
  {
    source =
      {
        events = [];
        validities = [];
        validity_corrections = [];
        corrections = [];
        descriptions = [];
        merchants = [];
        original_amounts = [];
        exchanges = [];
        reversals = [];
        relations = [];
        discharges = [];
      };
    zero_origins = [];
    openings = [];
    groups = [];
    presence = None;
  }

type state =
  | Top of t
  | Event of {
      input : t;
      id : D.Identifier.Event.t;
      date : string option;
      effects : D.Effect.t list;
    }
  | Group of {
      input : t;
      roots : D.Identifier.Event.t list;
      assertions : A.Current_quantity_projection.assertion list;
    }
  | Presence of {
      input : t;
      roots : D.Identifier.Event.t list;
      coordinates : D.Effect_coordinate.t list;
    }
  | Finished of t

let decode_effect line key locus measure decimal =
  let* c = coordinate line locus measure in
  let* quantity = quantity line decimal in
  Ok (D.Effect.create ~key ~locus:c.locus ~measure:c.measure ~quantity)

let step line state tokens =
  match tokens with
  | [] -> Ok state
  | tokens -> (
      match state with
      | Finished _ -> syntax line "content after end"
      | Top input -> (
          match tokens with
          | [ L.Word "event"; Quoted id; Quoted date ] ->
              let* id = event_id line id in
              Ok (Event { input; id; date = Some date; effects = [] })
          | [ Word "event"; Quoted id; Word "none" ] ->
              let* id = event_id line id in
              Ok (Event { input; id; date = None; effects = [] })
          | [ Word "correct"; Quoted target; Quoted replacement ] ->
              let* target = event_id line target in
              let* replacement = event_id line replacement in
              let source =
                {
                  input.source with
                  corrections = { target; replacement } :: input.source.corrections;
                }
              in
              Ok (Top { input with source })
          | [ Word "describe"; Quoted event; Quoted text ] ->
              let* event = event_id line event in
              let source =
                { input.source with descriptions = { event; text } :: input.source.descriptions }
              in
              Ok (Top { input with source })
          | [ Word "origin"; Quoted locus; Quoted measure ] ->
              let* c = coordinate line locus measure in
              Ok (Top { input with zero_origins = c :: input.zero_origins })
          | [ Word "opening"; Quoted locus; Quoted measure; Quoted event ] ->
              let* coordinate = coordinate line locus measure in
              let* opening_event = event_id line event in
              Ok (Top { input with openings = { coordinate; opening_event } :: input.openings })
          | [ Word "group" ] -> Ok (Group { input; roots = []; assertions = [] })
          | [ Word "presence" ] -> (
              match input.presence with
              | None -> Ok (Presence { input; roots = []; coordinates = [] })
              | Some _ -> syntax line "presence block must not repeat")
          | [ Word "end" ] -> Ok (Finished input)
          | Word name :: _ ->
              if
                List.mem
                  [
                    "event";
                    "correct";
                    "describe";
                    "origin";
                    "opening";
                    "group";
                    "presence";
                    "end";
                    "effect";
                    "end-event";
                    "reflect";
                    "assert";
                    "end-group";
                    "present";
                    "end-presence";
                  ]
                  name ~equal:String.equal
              then syntax line "malformed top-level record"
              else Error (Unsupported_record { line; name })
          | Quoted _ :: _ -> syntax line "expected a record keyword"
          | [] -> syntax line "expected a record")
      | Event { input; id; date; effects } -> (
          match tokens with
          | [ Word "effect"; Word "anonymous"; Quoted locus; Quoted measure; Word decimal ] ->
              let* value = decode_effect line None locus measure decimal in
              Ok (Event { input; id; date; effects = value :: effects })
          | [ Word "effect"; Word "key"; Quoted key; Quoted locus; Quoted measure; Word decimal ] ->
              let* key = identity line D.Identifier.Effect_key.of_string key in
              let* value = decode_effect line (Some key) locus measure decimal in
              Ok (Event { input; id; date; effects = value :: effects })
          | [ Word "end-event" ] -> (
              match D.Event.create ~id ~effects:(List.rev effects) with
              | Error error -> Error (Invalid_event { line; event = id; error })
              | Ok event ->
                  let validities =
                    match date with
                    | None -> input.source.validities
                    | Some valid_on ->
                        A.Actual_validity.Base { event = id; valid_on } :: input.source.validities
                  in
                  let source =
                    { input.source with events = event :: input.source.events; validities }
                  in
                  Ok (Top { input with source }))
          | _ -> syntax line "expected effect or end-event")
      | Group { input; roots; assertions } -> (
          match tokens with
          | [ Word "reflect"; Quoted id ] ->
              let* root = event_id line id in
              Ok (Group { input; roots = root :: roots; assertions })
          | [ Word "assert"; Quoted locus; Quoted measure; Word decimal ] ->
              let* coordinate = coordinate line locus measure in
              let* quantity = quantity line decimal in
              Ok (Group { input; roots; assertions = { coordinate; quantity } :: assertions })
          | [ Word "end-group" ] ->
              let group : A.Current_quantity_groups.group =
                { reflected_roots = List.rev roots; assertions = List.rev assertions }
              in
              Ok (Top { input with groups = group :: input.groups })
          | _ -> syntax line "expected reflect, assert or end-group")
      | Presence { input; roots; coordinates } -> (
          match tokens with
          | [ Word "reflect"; Quoted id ] ->
              let* root = event_id line id in
              Ok (Presence { input; roots = root :: roots; coordinates })
          | [ Word "present"; Quoted locus; Quoted measure ] ->
              let* c = coordinate line locus measure in
              Ok (Presence { input; roots; coordinates = c :: coordinates })
          | [ Word "end-presence" ] ->
              let presence : A.Current_quantity_query.presence =
                { reflected_roots = List.rev roots; coordinates = List.rev coordinates }
              in
              Ok (Top { input with presence = Some presence })
          | _ -> syntax line "expected reflect, present or end-presence"))

let finish input =
  let source = input.source in
  {
    input with
    source =
      {
        source with
        events = List.rev source.events;
        validities = List.rev source.validities;
        corrections = List.rev source.corrections;
        descriptions = List.rev source.descriptions;
      };
    zero_origins = List.rev input.zero_origins;
    openings = List.rev input.openings;
    groups = List.rev input.groups;
  }

let decode text =
  if not (String.is_suffix text ~suffix:"\n") then syntax 1 "final newline required"
  else
    let lines = String.split text ~on:'\n' in
    let lex line text =
      match L.decode text with Ok tokens -> Ok tokens | Error problem -> syntax line problem
    in
    let rec body line state = function
      | [] -> (
          match state with
          | Finished input -> Ok (finish input)
          | Top _ -> syntax line "missing end"
          | Event _ -> syntax line "missing end-event"
          | Group _ -> syntax line "missing end-group"
          | Presence _ -> syntax line "missing end-presence")
      | text :: rest ->
          let* tokens = lex line text in
          let* state = step line state tokens in
          body (line + 1) state rest
    in
    let rec header line = function
      | [] -> syntax line "missing bakhlo-read header"
      | text :: rest -> (
          let* tokens = lex line text in
          match tokens with
          | [] -> header (line + 1) rest
          | [ Word "bakhlo-read"; Word version; Word profile ] ->
              if not (String.equal version "1") then Error (Unsupported_version { line; version })
              else if not (String.equal profile "ordinary-actual-quantity") then
                Error (Unsupported_profile { line; profile })
              else body (line + 1) (Top empty) rest
          | _ -> syntax line "expected bakhlo-read VERSION PROFILE")
    in
    header 1 lines
