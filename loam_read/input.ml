open Base
module D = Bakhlo_domain
module A = Bakhlo_application
module Q = A.Current_quantity_query
module V = A.Actual_validity

type operation_origin = { request_token : string; event : D.Identifier.Event.t }

type t = {
  source : A.Actual_source.command;
  operation_origins : operation_origin list;
  zero_origins : D.Effect_coordinate.t list;
  openings : Q.opening list;
  groups : A.Current_quantity_groups.group list;
  presence : Q.presence;
}

type error =
  | Missing_section of string
  | Unsupported_header of { section : string }
  | Unsupported_actual_evidence of { line : int }
  | Syntax of { section : string; line : int; problem : string }
  | Invalid_event of { line : int; event : D.Identifier.Event.t; error : D.Event.error }

let ( let* ) result f = Result.bind result ~f
let fail section line problem = Error (Syntax { section; line; problem })

let token section line text =
  if
    String.is_empty text
    || String.exists text ~f:(function '\t' | '\r' | '\n' -> true | _ -> false)
  then fail section line "invalid unescaped identity/date token"
  else Ok text

let identity section line make text =
  let* text = token section line text in
  match make text with
  | Ok id -> Ok id
  | Error D.Identifier.Empty -> fail section line "empty identity"

let event_id section line = identity section line D.Identifier.Event.of_string

let quantity section line text =
  let start =
    if (not (String.is_empty text)) && (Char.equal text.[0] '+' || Char.equal text.[0] '-') then 1
    else 0
  in
  let digits = String.drop_prefix text start in
  if String.is_empty digits || not (String.for_all digits ~f:Char.is_digit) then
    fail section line "expected signed decimal integer quanta"
  else Ok (D.Quantity.of_quanta (Z.of_string text))

let coordinate section line locus measure =
  let* locus = identity section line D.Identifier.Locus.of_string locus in
  let* measure = identity section line D.Identifier.Measure.of_string measure in
  Ok ({ locus; measure } : D.Effect_coordinate.t)

let frame parts section headers =
  match
    List.find parts ~f:(fun ({ name; body = _ } : Envelope.section) -> String.equal name section)
  with
  | None -> Error (Missing_section section)
  | Some { name = _; body } -> (
      if not (String.is_suffix body ~suffix:"\n") then fail section 1 "missing final newline"
      else
        match String.split (String.drop_suffix body 1) ~on:'\n' with
        | header :: rows when List.mem headers header ~equal:String.equal ->
            Ok (header, List.mapi rows ~f:(fun i row -> (i + 2, row)))
        | [] | _ :: _ -> Error (Unsupported_header { section }))

let empty_source : A.Actual_source.command =
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
  }

type transaction = {
  id : D.Identifier.Event.t;
  effects : D.Effect.t list;
  seen : (string, String.comparator_witness) Set.t;
}

let endpoint line text =
  if String.equal text "household" then Ok A.Open_relations.Household
  else if String.is_prefix text ~prefix:"external:" then
    Result.map
      (identity "Actual" line D.Identifier.External_party.of_string (String.drop_prefix text 9))
      ~f:(fun party -> A.Open_relations.External party)
  else fail "Actual" line "unsupported relation endpoint"

let refuse_actual line fields =
  match fields with
  | ( "" | "TX" | "ENDTX" | "EFFECT" | "KEYED-EFFECT" | "MERCHANT" | "NONMERCHANT" | "OPERATION"
    | "EXCHANGE" | "ORIGINAL-AMOUNT" | "REPLACES" | "REVERSAL-OF" | "DATE-REV" | "RELATION"
    | "DISCHARGE" )
    :: _
  | [] ->
      fail "Actual" line "malformed or misplaced Actual record"
  | _ :: _ -> Error (Unsupported_actual_evidence { line })

let actual parts =
  let* _, rows =
    frame parts "Actual"
      (List.map [ 1; 2; 3; 4 ] ~f:(fun n -> "LOAM-NORMALIZED-ACTUAL\t" ^ Int.to_string n))
  in
  let rec scan (source : A.Actual_source.command) origins current = function
    | [] -> (
        match current with
        | Some _ -> fail "Actual" (List.length rows + 2) "missing ENDTX"
        | None ->
            Ok
              ( {
                  A.Actual_source.events = List.rev source.events;
                  validities = List.rev source.validities;
                  validity_corrections = List.rev source.validity_corrections;
                  corrections = List.rev source.corrections;
                  descriptions = List.rev source.descriptions;
                  merchants = List.rev source.merchants;
                  original_amounts = List.rev source.original_amounts;
                  exchanges = List.rev source.exchanges;
                  reversals = List.rev source.reversals;
                  relations = List.rev source.relations;
                  discharges = List.rev source.discharges;
                },
                List.rev origins ))
    | (line, row) :: rest -> (
        let fields = String.split row ~on:'\t' in
        match current with
        | None -> (
            match fields with
            | "TX" :: id :: date :: disposition ->
                let* id = event_id "Actual" line id in
                let* valid_on = token "Actual" line date in
                let* description =
                  match disposition with
                  | [ "NODESC" ] -> Ok None
                  | "DESC" :: texts ->
                      let text = String.concat ~sep:"\t" texts in
                      if
                        String.is_empty text
                        || String.exists text ~f:(function '\r' | '\n' -> true | _ -> false)
                      then fail "Actual" line "invalid description"
                      else Ok (Some text)
                  | _ -> fail "Actual" line "expected NODESC or DESC text"
                in
                let descriptions =
                  match description with
                  | None -> source.descriptions
                  | Some text -> { A.Event_descriptions.event = id; text } :: source.descriptions
                in
                let source =
                  {
                    source with
                    descriptions;
                    validities = V.Base { event = id; valid_on } :: source.validities;
                  }
                in
                scan source origins
                  (Some { id; effects = []; seen = Set.empty (module String) })
                  rest
            | _ -> refuse_actual line fields)
        | Some ({ id; effects; seen } as tx) -> (
            let singleton =
              match fields with
              | ("MERCHANT" | "NONMERCHANT") :: _ -> Some "merchant"
              | (("OPERATION" | "EXCHANGE" | "ORIGINAL-AMOUNT" | "REPLACES" | "REVERSAL-OF") as name)
                :: _ ->
                  Some name
              | [] | _ :: _ -> None
            in
            let* tx =
              match singleton with
              | None -> Ok tx
              | Some name when Set.mem seen name -> fail "Actual" line "repeated local metadata"
              | Some name -> Ok { tx with seen = Set.add seen name }
            in
            let continue source origins = scan source origins (Some tx) rest in
            match fields with
            | [ "ENDTX" ] ->
                let* event =
                  Result.map_error
                    (D.Event.create ~id ~effects:(List.rev effects))
                    ~f:(fun error -> Invalid_event { line; event = id; error })
                in
                scan { source with events = event :: source.events } origins None rest
            | [ "EFFECT"; locus; measure; n ] | [ "KEYED-EFFECT"; _; locus; measure; n ] ->
                let* key =
                  match fields with
                  | [ "KEYED-EFFECT"; key; _; _; _ ] ->
                      Result.map
                        (identity "Actual" line D.Identifier.Effect_key.of_string key)
                        ~f:Option.some
                  | [ "EFFECT"; _; _; _ ] -> Ok None
                  | [] | _ :: _ -> fail "Actual" line "invalid Effect shape"
                in
                let* c = coordinate "Actual" line locus measure in
                let* quantity = quantity "Actual" line n in
                let change = D.Effect.create ~key ~locus:c.locus ~measure:c.measure ~quantity in
                scan source origins (Some { tx with effects = change :: effects }) rest
            | [ "MERCHANT"; party ] ->
                let* party = identity "Actual" line D.Identifier.External_party.of_string party in
                continue
                  {
                    source with
                    merchants =
                      { event = id; disposition = A.Event_merchants.Merchant party }
                      :: source.merchants;
                  }
                  origins
            | [ "NONMERCHANT" ] ->
                continue
                  {
                    source with
                    merchants =
                      { event = id; disposition = A.Event_merchants.Nonmerchant }
                      :: source.merchants;
                  }
                  origins
            | [ "OPERATION"; request_token ] ->
                let* request_token = token "Actual" line request_token in
                continue source ({ request_token; event = id } :: origins)
            | [ "REPLACES"; target ] ->
                let* target = event_id "Actual" line target in
                continue
                  {
                    source with
                    corrections =
                      { D.Event_correction.target; replacement = id } :: source.corrections;
                  }
                  origins
            | [ "REVERSAL-OF"; target ] ->
                let* target = event_id "Actual" line target in
                continue
                  {
                    source with
                    reversals = { A.Actual_reversals.target; reversal = id } :: source.reversals;
                  }
                  origins
            | [ "EXCHANGE"; from_key; to_key ] ->
                let* from_key = identity "Actual" line D.Identifier.Effect_key.of_string from_key in
                let* to_key = identity "Actual" line D.Identifier.Effect_key.of_string to_key in
                continue
                  {
                    source with
                    exchanges =
                      { A.Exchange_evidence.event = id; source = from_key; destination = to_key }
                      :: source.exchanges;
                  }
                  origins
            | [ "ORIGINAL-AMOUNT"; measure; n ] ->
                let* measure = identity "Actual" line D.Identifier.Measure.of_string measure in
                let* quantity = quantity "Actual" line n in
                continue
                  {
                    source with
                    original_amounts =
                      { A.Original_amounts.root = id; measure; quantity } :: source.original_amounts;
                  }
                  origins
            | [ "DATE-REV"; revision; date; "REPLACES"; "ROOT" ]
            | [ "DATE-REV"; revision; date; "REPLACES"; "REV"; _ ] ->
                let* revision =
                  identity "Actual" line D.Identifier.Validity_revision.of_string revision
                in
                let* valid_on = token "Actual" line date in
                let* target =
                  match fields with
                  | [ _; _; _; _; "ROOT" ] -> Ok (V.Base_ref id)
                  | [ _; _; _; _; "REV"; prior ] ->
                      Result.map
                        (identity "Actual" line D.Identifier.Validity_revision.of_string prior)
                        ~f:(fun r -> V.Revision_ref r)
                  | [] | _ :: _ -> fail "Actual" line "invalid date revision shape"
                in
                continue
                  {
                    source with
                    validities =
                      V.Revision { id = revision; event = id; valid_on } :: source.validities;
                    validity_corrections =
                      { V.target; replacement = revision } :: source.validity_corrections;
                  }
                  origins
            | [ "RELATION"; relation; "SOURCE"; key; debtor; creditor; n ] ->
                let* relation = identity "Actual" line D.Identifier.Relation.of_string relation in
                let* key = identity "Actual" line D.Identifier.Effect_key.of_string key in
                let* debtor = endpoint line debtor in
                let* creditor = endpoint line creditor in
                let* quantity = quantity "Actual" line n in
                let fact : A.Open_relations.fact =
                  {
                    id = relation;
                    source_event = id;
                    source_effect = key;
                    debtor;
                    creditor;
                    quantity;
                  }
                in
                continue { source with relations = fact :: source.relations } origins
            | [ "DISCHARGE"; target; n ] ->
                let* target = identity "Actual" line D.Identifier.Relation.of_string target in
                let* quantity = quantity "Actual" line n in
                continue
                  {
                    source with
                    discharges =
                      { A.Relation_discharges.event = id; target; quantity } :: source.discharges;
                  }
                  origins
            | _ -> refuse_actual line fields))
  in
  scan empty_source [] None rows

let decode envelope =
  let parts = Envelope.sections envelope in
  let* source, operation_origins = actual parts in
  let* _, rows = frame parts "ZeroOrigin" [ "LOAM-ZERO-ORIGIN-COVERAGE\t1" ] in
  let* zero_origins =
    List.map rows ~f:(fun (line, row) ->
        match String.split row ~on:'\t' with
        | [ "COORDINATE"; locus; measure ] -> coordinate "ZeroOrigin" line locus measure
        | _ -> fail "ZeroOrigin" line "expected COORDINATE")
    |> Result.all
  in
  let* _, rows = frame parts "OpeningSupport" [ "LOAM-OPENING-SUPPORT\t1" ] in
  let* openings =
    List.map rows ~f:(fun (line, row) ->
        match String.split row ~on:'\t' with
        | [ "OPENING"; locus; measure; event ] ->
            let* coordinate = coordinate "OpeningSupport" line locus measure in
            let* opening_event = event_id "OpeningSupport" line event in
            Ok ({ Q.coordinate; opening_event } : Q.opening)
        | _ -> fail "OpeningSupport" line "expected OPENING")
    |> Result.all
  in
  let* header, rows =
    frame parts "CurrentQuantityAnchor"
      [ "LOAM-CURRENT-QUANTITY-ANCHOR\t1"; "LOAM-CURRENT-QUANTITY-ANCHOR\t2" ]
  in
  let payload rows =
    let* roots, assertions =
      List.fold_result rows ~init:([], []) ~f:(fun (roots, assertions) (line, row) ->
          match String.split row ~on:'\t' with
          | [ "ROOT"; root ] ->
              let* root = event_id "CurrentQuantityAnchor" line root in
              Ok (root :: roots, assertions)
          | [ "ASSERT"; locus; measure; n ] ->
              let* coordinate = coordinate "CurrentQuantityAnchor" line locus measure in
              let* quantity = quantity "CurrentQuantityAnchor" line n in
              Ok (roots, { A.Current_quantity_projection.coordinate; quantity } :: assertions)
          | _ -> fail "CurrentQuantityAnchor" line "expected ROOT or ASSERT")
    in
    Ok
      ({
         A.Current_quantity_groups.reflected_roots = List.rev roots;
         assertions = List.rev assertions;
       }
        : A.Current_quantity_groups.group)
  in
  let* groups =
    if String.equal header "LOAM-CURRENT-QUANTITY-ANCHOR\t1" then
      Result.map (payload rows) ~f:(fun g -> [ g ])
    else
      let rec take reversed = function
        | [] -> fail "CurrentQuantityAnchor" (List.length rows + 2) "missing group END"
        | (_, "END") :: rest -> Ok (List.rev reversed, rest)
        | item :: rest -> take (item :: reversed) rest
      in
      let rec scan reversed = function
        | [] -> Ok (List.rev reversed)
        | (_, "GROUP") :: rest ->
            let* inside, rest = take [] rest in
            let* group = payload inside in
            scan (group :: reversed) rest
        | (line, _) :: _ -> fail "CurrentQuantityAnchor" line "expected GROUP"
      in
      scan [] rows
  in
  let* _, rows = frame parts "CurrentQuantityPresence" [ "LOAM-CURRENT-QUANTITY-PRESENCE\t1" ] in
  let* roots, coordinates =
    List.fold_result rows ~init:([], []) ~f:(fun (roots, coordinates) (line, row) ->
        match String.split row ~on:'\t' with
        | [ "ROOT"; root ] ->
            let* root = event_id "CurrentQuantityPresence" line root in
            Ok (root :: roots, coordinates)
        | [ "PRESENT"; locus; measure ] ->
            let* c = coordinate "CurrentQuantityPresence" line locus measure in
            Ok (roots, c :: coordinates)
        | _ -> fail "CurrentQuantityPresence" line "expected ROOT or PRESENT")
  in
  Ok
    {
      source;
      operation_origins;
      zero_origins;
      openings;
      groups;
      presence = { Q.reflected_roots = List.rev roots; coordinates = List.rev coordinates };
    }
