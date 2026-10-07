open Base
module D = Bakhlo_domain
module A = Bakhlo_application
module Q = A.Current_quantity_query
module X = Sexp

type family = Measures | Events | Event_corrections | Observations | Zero_origin | Exchanges
type supply = Provided | Empty | Not_supplied
type measure = { id : D.Identifier.Measure.t; decimal_scale : Z.t }
type entry = { event : D.Event.t; day : string option; description : string option }

type wire = {
  version : int;
  locus_admission : D.Identifier.Locus.t list option;
  declarations : (family * supply) list;
  measures : measure list;
  events : entry list;
  corrections : D.Event_correction.t list;
  observations : A.Current_quantity_groups.group list;
  zero_origins : D.Effect_coordinate.t list;
  exchanges : A.Exchange_evidence.fact list;
}

type t = { bytes : string; wire : wire; image : Q.t }

type error =
  | Syntax of Parsexp.Parse_error.t
  | Wire of { at : string; problem : string }
  | Event of { event : D.Identifier.Event.t; error : D.Event.error }
  | Movement of D.Movement.error list
  | Source of A.Actual_source.error
  | Support of Q.error

type candidate = { base : t; document : t }

let ( let* ) result f = Result.bind result ~f
let fail at problem = Error (Wire { at; problem })
let map_result values ~f = Result.all (List.map values ~f)
let iter_result values ~f = List.fold_result values ~init:() ~f:(fun () value -> f value)
let legacy_families = [ Measures; Events; Event_corrections; Observations; Zero_origin ]
let families = legacy_families @ [ Exchanges ]

let families_for_version = function
  | 1 | 2 -> legacy_families
  | 3 -> families
  | _ -> []

let family_name = function
  | Measures -> "measures"
  | Events -> "events"
  | Event_corrections -> "event-corrections"
  | Observations -> "observations"
  | Zero_origin -> "zero-origin"
  | Exchanges -> "exchanges"

let family_of_name name =
  List.find families ~f:(fun family -> String.equal name (family_name family))

let state_name = function
  | Provided -> "provided"
  | Empty -> "empty"
  | Not_supplied -> "not-supplied"

let fields at allowed values =
  map_result values ~f:(function
    | X.List (X.Atom name :: arguments) when List.mem allowed name ~equal:String.equal ->
        Ok (name, arguments)
    | X.List (X.Atom name :: _) -> fail at (Printf.sprintf "unsupported field %S" name)
    | X.Atom _ | X.List [] | X.List (X.List _ :: _) -> fail at "expected named field")

let repeated name values =
  List.filter_map values ~f:(fun (key, value) -> if String.equal key name then Some value else None)

let required at name values =
  match repeated name values with
  | [ value ] -> Ok value
  | [] -> fail at ("missing field " ^ name)
  | _ :: _ :: _ -> fail at ("duplicate field " ^ name)

let atom at = function [ X.Atom value ] -> Ok value | _ -> fail at "expected one atom"

let field_atom at name values =
  let* value = required at name values in
  atom (at ^ "." ^ name) value

let identifier at make value =
  Result.map_error (make value) ~f:(function D.Identifier.Empty ->
      Wire { at; problem = "empty identity" })

let integer at ~signed text =
  let offset =
    if signed && String.length text > 0 && (Char.equal text.[0] '-' || Char.equal text.[0] '+') then
      1
    else 0
  in
  if
    String.length text = offset
    || not
         (String.for_all (String.drop_prefix text offset) ~f:(function
           | '0' .. '9' -> true
           | _ -> false))
  then fail at "expected exact decimal integer"
  else Ok (Z.of_string_base 10 text)

let coordinate at values =
  let* locus = field_atom at "locus" values in
  let* locus = identifier (at ^ ".locus") D.Identifier.Locus.of_string locus in
  let* measure = field_atom at "measure" values in
  let* measure = identifier (at ^ ".measure") D.Identifier.Measure.of_string measure in
  Ok { D.Effect_coordinate.locus; measure }

let quantity at values =
  let* text = field_atom at "quanta" values in
  let* quanta = integer (at ^ ".quanta") ~signed:true text in
  Ok (D.Quantity.of_quanta quanta)

let roots at values =
  let* values = required at "reflected-roots" values in
  map_result values ~f:(fun value ->
      let* value = atom at [ value ] in
      identifier at D.Identifier.Event.of_string value)

let decode_effect at values =
  let* values = fields at [ "key"; "locus"; "measure"; "quanta" ] values in
  let* key = required at "key" values in
  let* key =
    match key with
    | [ X.List [ X.Atom "unkeyed" ] ] -> Ok None
    | [ X.List [ X.Atom "named"; X.Atom key ] ] ->
        Result.map (identifier (at ^ ".key") D.Identifier.Effect_key.of_string key) ~f:Option.some
    | _ -> fail (at ^ ".key") "expected named or unkeyed"
  in
  let* { D.Effect_coordinate.locus; measure } = coordinate at values in
  let* quantity = quantity at values in
  Ok (D.Effect.create ~key ~locus ~measure ~quantity)

let entry at id values =
  let* id = identifier (at ^ ".id") D.Identifier.Event.of_string id in
  let* values = fields at [ "day"; "description"; "effect" ] values in
  let* day = required at "day" values in
  let* day =
    match day with
    | [ X.List [ X.Atom "date"; X.Atom day ] ] -> Ok (Some day)
    | [ X.List [ X.Atom "not-supplied" ] ] -> Ok None
    | _ -> fail (at ^ ".day") "expected date or not-supplied"
  in
  let* description = required at "description" values in
  let* description =
    match description with
    | [ X.List [ X.Atom "text"; X.Atom text ] ] -> Ok (Some text)
    | [ X.List [ X.Atom "not-supplied" ] ] -> Ok None
    | _ -> fail (at ^ ".description") "expected text or not-supplied"
  in
  let* effects = map_result (repeated "effect" values) ~f:(decode_effect (at ^ ".effect")) in
  let* event =
    Result.map_error (D.Event.create ~id ~effects) ~f:(fun error -> Event { event = id; error })
  in
  Ok { event; day; description }

let measure at id values =
  let* id = identifier (at ^ ".id") D.Identifier.Measure.of_string id in
  let* values = fields at [ "decimal-scale" ] values in
  let* text = field_atom at "decimal-scale" values in
  let* decimal_scale = integer (at ^ ".decimal-scale") ~signed:false text in
  Ok { id; decimal_scale }

let correction at values =
  let* values = fields at [ "target"; "replacement" ] values in
  let* target = field_atom at "target" values in
  let* target = identifier (at ^ ".target") D.Identifier.Event.of_string target in
  let* replacement = field_atom at "replacement" values in
  let* replacement = identifier (at ^ ".replacement") D.Identifier.Event.of_string replacement in
  Ok { D.Event_correction.target; replacement }

let exchange at values =
  let* values = fields at [ "event"; "source"; "destination" ] values in
  let* event = field_atom at "event" values in
  let* event = identifier (at ^ ".event") D.Identifier.Event.of_string event in
  let* source = field_atom at "source" values in
  let* source = identifier (at ^ ".source") D.Identifier.Effect_key.of_string source in
  let* destination = field_atom at "destination" values in
  let* destination =
    identifier (at ^ ".destination") D.Identifier.Effect_key.of_string destination
  in
  Ok ({ event; source; destination } : A.Exchange_evidence.fact)

let observation at values =
  let* values = fields at [ "reflected-roots"; "assertion" ] values in
  let* reflected_roots = roots at values in
  let* assertions =
    map_result (repeated "assertion" values) ~f:(fun values ->
        let at = at ^ ".assertion" in
        let* values = fields at [ "locus"; "measure"; "quanta" ] values in
        let* coordinate = coordinate at values in
        let* quantity = quantity at values in
        Ok { A.Current_quantity_projection.coordinate; quantity })
  in
  Ok { A.Current_quantity_groups.reflected_roots; assertions }

let declarations version values =
  let at = "collections" in
  let* values = fields at [ "provided"; "empty"; "not-supplied" ] values in
  let* groups =
    map_result [ Provided; Empty; Not_supplied ] ~f:(fun state ->
        let* names = required at (state_name state) values in
        map_result names ~f:(fun name ->
            let* name = atom at [ name ] in
            match family_of_name name with
            | None -> fail at (Printf.sprintf "unsupported collection %S" name)
            | Some family
              when List.mem (families_for_version version) family ~equal:Poly.equal ->
                Ok (family, state)
            | Some _ -> fail at (Printf.sprintf "collection %S requires a newer version" name)))
  in
  let supplied = List.concat groups in
  map_result (families_for_version version) ~f:(fun family ->
      match List.filter supplied ~f:(fun (other, _) -> Poly.equal other family) with
      | [ declaration ] -> Ok declaration
      | [] -> fail at ("missing collection " ^ family_name family)
      | _ :: _ :: _ -> fail at ("duplicate collection " ^ family_name family))

let supply_wire wire family =
  match List.find wire.declarations ~f:(fun (other, _) -> Poly.equal other family) with
  | Some (_, state) -> state
  | None when wire.version < 3 && Poly.equal family Exchanges -> Not_supplied
  | None -> failwith "qualified collection declaration missing"

let decode_locus_admission values =
  let at = "locus-admission" in
  match values with
  | [ X.List (X.Atom "approved" :: loci) ] ->
      let* loci =
        map_result loci ~f:(fun locus ->
            let* locus = atom at [ locus ] in
            identifier at D.Identifier.Locus.of_string locus)
      in
      let* _ =
        List.fold_result loci ~init:[] ~f:(fun seen locus ->
            if List.mem seen locus ~equal:D.Identifier.Locus.equal then
              fail at "duplicate approved Locus"
            else Ok (locus :: seen))
      in
      Ok (Some loci)
  | [ X.List [ X.Atom "not-supplied" ] ] -> Ok None
  | _ -> fail at "expected exactly approved identities or not-supplied"

let decode = function
  | X.List [ X.Atom "bakhlo"; X.Atom version_text; X.Atom "ordinary-quantity" ] :: body
    when String.equal version_text "1"
         || String.equal version_text "2"
         || String.equal version_text "3" ->
      let version =
        if String.equal version_text "1" then 1
        else if String.equal version_text "2" then 2
        else 3
      in
      let* locus_admission =
        let policies =
          List.filter_map body ~f:(function
            | X.List (X.Atom "locus-admission" :: values) -> Some values
            | X.Atom _ | X.List _ -> None)
        in
        match (version, policies) with
        | 1, [] -> Ok None
        | 1, _ -> fail "book" "locus-admission requires version 2 or newer"
        | (2 | 3), [ values ] -> decode_locus_admission values
        | (2 | 3), [] -> fail "book" "missing locus-admission"
        | (2 | 3), _ :: _ :: _ -> fail "book" "duplicate locus-admission"
        | _, _ -> fail "book" "unsupported version"
      in
      let* declarations =
        match
          List.filter_map body ~f:(function
            | X.List (X.Atom "collections" :: values) -> Some values
            | X.Atom _ | X.List _ -> None)
        with
        | [ values ] -> declarations version values
        | [] -> fail "book" "missing collections"
        | _ :: _ :: _ -> fail "book" "duplicate collections"
      in
      let initial =
        {
          version;
          locus_admission;
          declarations;
          measures = [];
          events = [];
          corrections = [];
          observations = [];
          zero_origins = [];
          exchanges = [];
        }
      in
      let* wire =
        List.fold_result
          (List.mapi body ~f:(fun i form -> (i + 1, form)))
          ~init:initial
          ~f:(fun wire (i, form) ->
            let at = Printf.sprintf "record[%d]" i in
            match form with
            | X.List (X.Atom "collections" :: _) | X.List (X.Atom "locus-admission" :: _) -> Ok wire
            | X.List (X.Atom "measure" :: X.Atom id :: values) ->
                let* value = measure at id values in
                Ok { wire with measures = value :: wire.measures }
            | X.List (X.Atom "event" :: X.Atom id :: values) ->
                let* value = entry at id values in
                Ok { wire with events = value :: wire.events }
            | X.List (X.Atom "event-correction" :: values) ->
                let* value = correction at values in
                Ok { wire with corrections = value :: wire.corrections }
            | X.List (X.Atom "observation" :: values) ->
                let* value = observation at values in
                Ok { wire with observations = value :: wire.observations }
            | X.List (X.Atom "zero-origin" :: values) ->
                let* values = fields at [ "locus"; "measure" ] values in
                let* value = coordinate at values in
                Ok { wire with zero_origins = value :: wire.zero_origins }
            | X.List (X.Atom "exchange" :: values) when wire.version = 3 ->
                let* value = exchange at values in
                Ok { wire with exchanges = value :: wire.exchanges }
            | X.List (X.Atom "exchange" :: _) ->
                fail at "exchange requires version 3"
            | X.List (X.Atom name :: _) ->
                fail at (Printf.sprintf "unsupported or malformed record %S" name)
            | X.Atom _ | X.List [] | X.List (X.List _ :: _) -> fail at "expected record")
      in
      Ok
        {
          wire with
          measures = List.rev wire.measures;
          events = List.rev wire.events;
          corrections = List.rev wire.corrections;
          observations = List.rev wire.observations;
          zero_origins = List.rev wire.zero_origins;
          exchanges = List.rev wire.exchanges;
        }
  | [] -> fail "book" "missing header"
  | _ :: _ ->
      fail "book"
        "expected (bakhlo 1 ordinary-quantity), (bakhlo 2 ordinary-quantity), or (bakhlo 3 ordinary-quantity)"

let admit wire =
  let count = function
    | Measures -> List.length wire.measures
    | Events -> List.length wire.events
    | Event_corrections -> List.length wire.corrections
    | Observations -> List.length wire.observations
    | Zero_origin -> List.length wire.zero_origins
    | Exchanges -> List.length wire.exchanges
  in
  let* () =
    iter_result (families_for_version wire.version) ~f:(fun family ->
        match (supply_wire wire family, count family) with
        | Provided, n when n > 0 -> Ok ()
        | (Empty | Not_supplied), 0 -> Ok ()
        | Provided, _ | (Empty | Not_supplied), _ ->
            fail "collections" ("inconsistent " ^ family_name family))
  in
  let* _ =
    List.fold_result wire.measures ~init:[] ~f:(fun seen { id; decimal_scale = _ } ->
        if List.mem seen id ~equal:D.Identifier.Measure.equal then
          fail "measures" "duplicate Measure"
        else Ok (id :: seen))
  in
  let check { D.Effect_coordinate.locus = _; measure } =
    if
      List.exists wire.measures ~f:(fun { id; decimal_scale = _ } ->
          D.Identifier.Measure.equal id measure)
    then Ok ()
    else fail "coordinate" "undeclared Measure"
  in
  let* () =
    iter_result wire.events ~f:(fun { event; day = _; description = _ } ->
        iter_result (D.Event.effects event) ~f:(fun change ->
            check
              {
                D.Effect_coordinate.locus = D.Effect.locus change;
                measure = D.Effect.measure change;
              }))
  in
  let* () = iter_result wire.zero_origins ~f:check in
  let* () =
    iter_result wire.observations
      ~f:(fun { A.Current_quantity_groups.reflected_roots = _; assertions } ->
        iter_result assertions ~f:(fun { A.Current_quantity_projection.coordinate; quantity = _ } ->
            check coordinate))
  in
  let command : A.Actual_source.command =
    {
      events = List.map wire.events ~f:(fun { event; day = _; description = _ } -> event);
      validities =
        List.filter_map wire.events ~f:(fun { event; day; description = _ } ->
            Option.map day ~f:(fun valid_on ->
                A.Actual_validity.Base { event = D.Event.id event; valid_on }));
      validity_corrections = [];
      corrections = wire.corrections;
      descriptions =
        List.filter_map wire.events ~f:(fun { event; day = _; description } ->
            Option.map description ~f:(fun text ->
                { A.Event_descriptions.event = D.Event.id event; text }));
      merchants = [];
      original_amounts = [];
      exchanges = wire.exchanges;
      reversals = [];
      relations = [];
      discharges = [];
    }
  in
  let* source = Result.map_error (A.Actual_source.create command) ~f:(fun error -> Source error) in
  Result.map_error
    (Q.create ~source ~zero_origins:wire.zero_origins ~openings:[] ~groups:wire.observations
       ~presence:None) ~f:(fun error -> Support error)

let of_string bytes =
  let* forms = Result.map_error (Parsexp.Many.parse_string bytes) ~f:(fun error -> Syntax error) in
  let* wire = decode forms in
  let* image = admit wire in
  Ok { bytes; wire; image }

let original_bytes book = book.bytes
let version book = book.wire.version
let image book = book.image
let measures book = book.wire.measures
let locus_admission book = book.wire.locus_admission
let supply book family = supply_wire book.wire family

(* A small schema-owned printer, not deriving from private OCaml layouts. Preserve
   UTF-8/identity bytes, escaping syntax/control or non-UTF8 bytes; no normalization. *)
let quote value =
  let utf8 = Stdlib.String.is_valid_utf_8 value in
  "\""
  ^ String.concat_map value ~f:(function
    | '"' -> "\\\""
    | '\\' -> "\\\\"
    | '\n' -> "\\n"
    | '\r' -> "\\r"
    | '\t' -> "\\t"
    | ('\000' .. '\031' | '\127') as c -> Printf.sprintf "\\x%02X" (Char.to_int c)
    | c when (not utf8) && Char.to_int c >= 128 -> Printf.sprintf "\\x%02X" (Char.to_int c)
    | c -> String.of_char c)
  ^ "\""

let event_id id = quote (D.Identifier.Event.to_string id)
let measure_id id = quote (D.Identifier.Measure.to_string id)

let coordinate_text { D.Effect_coordinate.locus; measure } =
  Printf.sprintf "(locus %s) (measure %s)"
    (quote (D.Identifier.Locus.to_string locus))
    (measure_id measure)

let effect_text change =
  let key =
    match D.Effect.key change with
    | None -> "(unkeyed)"
    | Some key -> "(named " ^ quote (D.Identifier.Effect_key.to_string key) ^ ")"
  in
  Printf.sprintf "  (effect (key %s) %s (quanta %s))" key
    (coordinate_text
       { D.Effect_coordinate.locus = D.Effect.locus change; measure = D.Effect.measure change })
    (Z.to_string (D.Quantity.quanta (D.Effect.quantity change)))

let entry_text { event; day; description } =
  let day = match day with None -> "(not-supplied)" | Some day -> "(date " ^ quote day ^ ")" in
  let description =
    match description with None -> "(not-supplied)" | Some text -> "(text " ^ quote text ^ ")"
  in
  String.concat ~sep:"\n"
    ([
       "(event " ^ event_id (D.Event.id event);
       "  (day " ^ day ^ ")";
       "  (description " ^ description ^ ")";
     ]
    @ List.map (D.Event.effects event) ~f:effect_text)
  ^ ")"

let print_wire wire =
  let collection_rows =
    List.map [ Provided; Empty; Not_supplied ] ~f:(fun state ->
        let names =
          List.filter (families_for_version wire.version)
            ~f:(fun family -> Poly.equal (supply_wire wire family) state)
          |> List.map ~f:family_name
        in
        "  (" ^ String.concat ~sep:" " (state_name state :: names) ^ ")")
  in
  let declarations = "(collections\n" ^ String.concat ~sep:"\n" collection_rows ^ ")" in
  let measures =
    List.map wire.measures ~f:(fun { id; decimal_scale } ->
        Printf.sprintf "(measure %s (decimal-scale %s))" (measure_id id) (Z.to_string decimal_scale))
  in
  let corrections =
    List.map wire.corrections ~f:(fun { D.Event_correction.target; replacement } ->
        Printf.sprintf "(event-correction (target %s) (replacement %s))" (event_id target)
          (event_id replacement))
  in
  let observations =
    List.map wire.observations ~f:(fun { A.Current_quantity_groups.reflected_roots; assertions } ->
        let roots =
          "  ("
          ^ String.concat ~sep:" " ("reflected-roots" :: List.map reflected_roots ~f:event_id)
          ^ ")"
        in
        let assertions =
          List.map assertions ~f:(fun { A.Current_quantity_projection.coordinate; quantity } ->
              Printf.sprintf "  (assertion %s (quanta %s))" (coordinate_text coordinate)
                (Z.to_string (D.Quantity.quanta quantity)))
        in
        "(observation\n" ^ String.concat ~sep:"\n" (roots :: assertions) ^ ")")
  in
  let exchanges =
    List.map wire.exchanges ~f:(fun ({ event; source; destination } : A.Exchange_evidence.fact) ->
        Printf.sprintf "(exchange (event %s) (source %s) (destination %s))"
          (event_id event)
          (quote (D.Identifier.Effect_key.to_string source))
          (quote (D.Identifier.Effect_key.to_string destination)))
  in
  let origins =
    List.map wire.zero_origins ~f:(fun coordinate ->
        "(zero-origin " ^ coordinate_text coordinate ^ ")")
  in
  String.concat ~sep:"\n\n"
    ([ Printf.sprintf "(bakhlo %d ordinary-quantity)" wire.version; declarations ]
    @ (if wire.version = 1 then []
       else
         [
           (match wire.locus_admission with
           | None -> "(locus-admission (not-supplied))"
           | Some loci ->
               "(locus-admission ("
               ^ String.concat ~sep:" "
                   ("approved"
                   :: List.map loci ~f:(fun locus -> quote (D.Identifier.Locus.to_string locus)))
               ^ "))");
         ])
    @ measures
    @ List.map wire.events ~f:entry_text
    @ exchanges @ corrections @ observations @ origins)
  ^ "\n"

let to_string book = print_wire book.wire
let base candidate = candidate.base
let document candidate = candidate.document

let candidate ~base wire =
  let* _ = admit wire in
  let* document = of_string (print_wire wire) in
  Ok { base; document }

let admit_locus ~base ~locus =
  let* locus = identifier "locus-admission" D.Identifier.Locus.of_string locus in
  match (base.wire.version, base.wire.locus_admission) with
  | (2 | 3), Some loci ->
      if List.mem loci locus ~equal:D.Identifier.Locus.equal then
        fail "locus-admission" "Locus already approved"
      else candidate ~base { base.wire with locus_admission = Some (loci @ [ locus ]) }
  | _, _ -> fail "locus-admission" "explicit version 2 vocabulary required"

let admits_new_effects base effects =
  if base.wire.version = 1 then Ok () (* Legacy pure proposals, not publication permission. *)
  else
    match base.wire.locus_admission with
    | None -> fail "locus-admission" "new-write policy not supplied"
    | Some loci ->
        iter_result effects ~f:(fun change ->
            if List.mem loci (D.Effect.locus change) ~equal:D.Identifier.Locus.equal then Ok ()
            else fail "locus-admission" "Effect Locus not approved for new writes")

let propose ~base target event =
  let* form = Result.map_error (Parsexp.Single.parse_string event) ~f:(fun error -> Syntax error) in
  let* entry =
    match form with
    | X.List (X.Atom "event" :: X.Atom id :: values) -> entry "event" id values
    | X.Atom _ | X.List _ -> fail "event" "expected one Event record"
  in
  let* _ =
    Result.map_error
      (D.Movement.validate (D.Event.effects entry.event))
      ~f:(fun error -> Movement error)
  in
  let* () = admits_new_effects base (D.Event.effects entry.event) in
  let declarations =
    List.map base.wire.declarations ~f:(fun (family, state) ->
        match (family, target) with
        | Events, _ | Event_corrections, Some _ -> (family, Provided)
        | (Measures | Observations | Zero_origin | Exchanges | Event_corrections), _ ->
            (family, state))
  in
  let corrections =
    match target with
    | None -> base.wire.corrections
    | Some target ->
        base.wire.corrections
        @ [ { D.Event_correction.target; replacement = D.Event.id entry.event } ]
  in
  let wire = { base.wire with declarations; events = base.wire.events @ [ entry ]; corrections } in
  candidate ~base wire

let append ~base ~event = propose ~base None event
let correct ~base ~target ~event = propose ~base (Some target) event

let append_exchange ~base ~event ~source ~destination =
  if base.wire.version <> 3 then fail "exchange" "explicit version 3 book required"
  else
    let* form =
      Result.map_error (Parsexp.Single.parse_string event) ~f:(fun error -> Syntax error)
    in
    let* entry =
      match form with
      | X.List (X.Atom "event" :: X.Atom id :: values) -> entry "event" id values
      | X.Atom _ | X.List _ -> fail "event" "expected one Event record"
    in
    let* () = admits_new_effects base (D.Event.effects entry.event) in
    let* source = identifier "exchange.source" D.Identifier.Effect_key.of_string source in
    let* destination =
      identifier "exchange.destination" D.Identifier.Effect_key.of_string destination
    in
    let exchange : A.Exchange_evidence.fact =
      { event = D.Event.id entry.event; source; destination }
    in
    let declarations =
      List.map base.wire.declarations ~f:(fun (family, state) ->
          match family with
          | Events | Exchanges -> (family, Provided)
          | Measures | Event_corrections | Observations | Zero_origin -> (family, state))
    in
    candidate ~base
      {
        base.wire with
        declarations;
        events = base.wire.events @ [ entry ];
        exchanges = base.wire.exchanges @ [ exchange ];
      }
