module Sexp = Sexplib0.Sexp

let ( let* ) result f =
  match result with
  | Ok value -> f value
  | Error _ as error -> error

let errorf fmt = Printf.ksprintf (fun message -> Error message) fmt

type collections =
  { provided : string list
  ; empty : string list
  ; not_supplied : string list
  }

type effect_key =
  | Named of string
  | Unkeyed

type day =
  | Date of string
  | Day_not_supplied

type description =
  | Text of string
  | Description_not_supplied

type wire_effect =
  { key : effect_key
  ; locus : string
  ; measure : string
  ; quanta : Z.t
  }

type event =
  { id : string
  ; day : day
  ; description : description
  ; effects : wire_effect list
  }

type measure =
  { id : string
  ; scale : int
  }

type wire_item =
  | Header of int
  | Collections of collections
  | Measure of measure
  | Event of event
  | Unknown of Sexp.t

type wire_v1 = wire_item list

let head_is tag = function
  | Sexp.List (Sexp.Atom head :: _) -> String.equal head tag
  | Sexp.Atom _ | Sexp.List [] -> false

let atom = function
  | Sexp.Atom value -> Ok value
  | sexp -> errorf "expected atom, got %s" (Sexp.to_string_mach sexp)

let atoms values =
  let rec loop acc = function
    | [] -> Ok (List.rev acc)
    | value :: rest ->
      let* value = atom value in
      loop (value :: acc) rest
  in
  loop [] values

let unique_child tag fields =
  match List.filter (head_is tag) fields with
  | [ value ] -> Ok value
  | [] -> errorf "missing %s field" tag
  | _ -> errorf "duplicate %s field" tag

let exact_atom_field tag fields =
  let* field = unique_child tag fields in
  match field with
  | Sexp.List [ Sexp.Atom actual; Sexp.Atom value ] when String.equal actual tag ->
    Ok value
  | _ -> errorf "malformed %s field" tag

let parse_z value =
  try Ok (Z.of_string value) with
  | Invalid_argument _ -> errorf "invalid arbitrary-precision integer %S" value

let parse_int value =
  match int_of_string_opt value with
  | Some value -> Ok value
  | None -> errorf "invalid machine integer %S" value

let parse_collections fields =
  if List.length fields <> 3 then
    errorf "collections requires exactly provided/empty/not-supplied declarations"
  else
    let state tag =
      let* form = unique_child tag fields in
      match form with
      | Sexp.List (Sexp.Atom actual :: names) when String.equal actual tag -> atoms names
      | _ -> errorf "malformed %s collection declaration" tag
    in
    let* provided = state "provided" in
    let* empty = state "empty" in
    let* not_supplied = state "not-supplied" in
    let seen = Hashtbl.create 32 in
    let add_state state names =
      let rec loop = function
        | [] -> Ok ()
        | name :: rest ->
          (match Hashtbl.find_opt seen name with
           | None ->
             Hashtbl.add seen name state;
             loop rest
           | Some previous ->
             errorf "collection %S declared in both %s and %s" name previous state)
      in
      loop names
    in
    let* () = add_state "provided" provided in
    let* () = add_state "empty" empty in
    let* () = add_state "not-supplied" not_supplied in
    Ok { provided; empty; not_supplied }

let parse_key fields =
  let* field = unique_child "key" fields in
  match field with
  | Sexp.List [ Sexp.Atom "key"; Sexp.List [ Sexp.Atom "named"; Sexp.Atom value ] ] ->
    Ok (Named value)
  | Sexp.List [ Sexp.Atom "key"; Sexp.List [ Sexp.Atom "unkeyed" ] ] -> Ok Unkeyed
  | _ -> errorf "malformed effect key"

let parse_effect = function
  | Sexp.List (Sexp.Atom "effect" :: fields) ->
    if List.length fields <> 4 then
      errorf "effect requires exactly key/locus/measure/quanta fields"
    else
      let* key = parse_key fields in
      let* locus = exact_atom_field "locus" fields in
      let* measure = exact_atom_field "measure" fields in
      let* quanta_text = exact_atom_field "quanta" fields in
      let* quanta = parse_z quanta_text in
      Ok { key; locus; measure; quanta }
  | _ -> errorf "malformed effect"

let parse_day fields =
  let* field = unique_child "day" fields in
  match field with
  | Sexp.List [ Sexp.Atom "day"; Sexp.List [ Sexp.Atom "date"; Sexp.Atom value ] ] ->
    Ok (Date value)
  | Sexp.List [ Sexp.Atom "day"; Sexp.List [ Sexp.Atom "not-supplied" ] ] ->
    Ok Day_not_supplied
  | _ -> errorf "malformed day field"

let parse_description fields =
  let* field = unique_child "description" fields in
  match field with
  | Sexp.List
      [ Sexp.Atom "description"; Sexp.List [ Sexp.Atom "text"; Sexp.Atom value ] ] ->
    Ok (Text value)
  | Sexp.List [ Sexp.Atom "description"; Sexp.List [ Sexp.Atom "not-supplied" ] ] ->
    Ok Description_not_supplied
  | _ -> errorf "malformed description field"

let parse_event = function
  | Sexp.List (Sexp.Atom "event" :: Sexp.Atom id :: fields) ->
    let effects, other_fields = List.partition (head_is "effect") fields in
    if List.length other_fields <> 2 then
      errorf "event %S contains unsupported or duplicate non-effect fields" id
    else
      let* day = parse_day other_fields in
      let* description = parse_description other_fields in
      let rec parse_effects acc = function
        | [] -> Ok (List.rev acc)
        | entry :: rest ->
          let* entry = parse_effect entry in
          parse_effects (entry :: acc) rest
      in
      let* effects = parse_effects [] effects in
      Ok { id; day; description; effects }
  | _ -> errorf "malformed event"

let parse_measure = function
  | Sexp.List
      [ Sexp.Atom "measure"; Sexp.Atom id; Sexp.List [ Sexp.Atom "scale"; Sexp.Atom scale ] ] ->
    let* scale = parse_int scale in
    Ok { id; scale }
  | _ -> errorf "malformed measure"

let decode_top form =
  match form with
  | Sexp.List (Sexp.Atom "bakhlo" :: _) ->
    (match form with
     | Sexp.List [ Sexp.Atom "bakhlo"; Sexp.Atom version ] ->
       let* version = parse_int version in
       Ok (Header version)
     | _ -> errorf "malformed bakhlo header")
  | Sexp.List (Sexp.Atom "collections" :: fields) ->
    let* value = parse_collections fields in
    Ok (Collections value)
  | Sexp.List (Sexp.Atom "measure" :: _) ->
    let* value = parse_measure form in
    Ok (Measure value)
  | Sexp.List (Sexp.Atom "event" :: _) ->
    let* value = parse_event form in
    Ok (Event value)
  | _ -> Ok (Unknown form)

let collection_mem name names = List.exists (String.equal name) names

let validate_wire (wire : wire_v1) =
  let headers =
    List.filter_map
      (function
        | Header version -> Some version
        | _ -> None)
      wire
  in
  let collection_blocks =
    List.filter_map
      (function
        | Collections value -> Some value
        | _ -> None)
      wire
  in
  let* collections =
    match collection_blocks with
    | [ value ] -> Ok value
    | [] -> errorf "missing collections declaration"
    | _ -> errorf "multiple collections declarations"
  in
  let* () =
    match headers with
    | [ 1 ] -> Ok ()
    | [ version ] -> errorf "unsupported wire version %d" version
    | [] -> errorf "missing bakhlo version header"
    | _ -> errorf "multiple bakhlo version headers"
  in
  let has_event =
    List.exists
      (function
        | Event _ -> true
        | _ -> false)
      wire
  in
  let has_measure =
    List.exists
      (function
        | Measure _ -> true
        | _ -> false)
      wire
  in
  let* () =
    if has_event && not (collection_mem "events" collections.provided)
    then errorf "event record exists but events is not explicitly provided"
    else Ok ()
  in
  let* () =
    if has_measure && not (collection_mem "measures" collections.provided)
    then errorf "measure record exists but measures is not explicitly provided"
    else Ok ()
  in
  Ok wire

let decode_wire forms =
  let rec loop acc = function
    | [] -> validate_wire (List.rev acc)
    | form :: rest ->
      let* item = decode_top form in
      loop (item :: acc) rest
  in
  loop [] forms

let sexp_atom value = Sexp.Atom value
let sexp_list values = Sexp.List values

let sexp_of_key = function
  | Named value -> sexp_list [ sexp_atom "named"; sexp_atom value ]
  | Unkeyed -> sexp_list [ sexp_atom "unkeyed" ]

let sexp_of_day = function
  | Date value -> sexp_list [ sexp_atom "date"; sexp_atom value ]
  | Day_not_supplied -> sexp_list [ sexp_atom "not-supplied" ]

let sexp_of_description = function
  | Text value -> sexp_list [ sexp_atom "text"; sexp_atom value ]
  | Description_not_supplied -> sexp_list [ sexp_atom "not-supplied" ]

let sexp_of_effect entry =
  sexp_list
    [ sexp_atom "effect"
    ; sexp_list [ sexp_atom "key"; sexp_of_key entry.key ]
    ; sexp_list [ sexp_atom "locus"; sexp_atom entry.locus ]
    ; sexp_list [ sexp_atom "measure"; sexp_atom entry.measure ]
    ; sexp_list [ sexp_atom "quanta"; sexp_atom (Z.to_string entry.quanta) ]
    ]

let sexp_of_event event =
  sexp_list
    ([ sexp_atom "event"
     ; sexp_atom event.id
     ; sexp_list [ sexp_atom "day"; sexp_of_day event.day ]
     ; sexp_list [ sexp_atom "description"; sexp_of_description event.description ]
     ]
     @ List.map sexp_of_effect event.effects)

let sexp_of_collections collections =
  let state tag names = sexp_list (sexp_atom tag :: List.map sexp_atom names) in
  sexp_list
    [ sexp_atom "collections"
    ; state "provided" collections.provided
    ; state "empty" collections.empty
    ; state "not-supplied" collections.not_supplied
    ]

let encode_top = function
  | Header version -> sexp_list [ sexp_atom "bakhlo"; sexp_atom (string_of_int version) ]
  | Collections collections -> sexp_of_collections collections
  | Measure measure ->
    sexp_list
      [ sexp_atom "measure"
      ; sexp_atom measure.id
      ; sexp_list [ sexp_atom "scale"; sexp_atom (string_of_int measure.scale) ]
      ]
  | Event event -> sexp_of_event event
  | Unknown form -> form

let encode_wire wire = List.map encode_top wire

let parse text =
  match Parsexp.Many.parse_string text with
  | Ok forms -> Ok forms
  | Error _ -> errorf "Parsexp rejected the S-expression source"

let render forms =
  String.concat "\n\n" (List.map (Sexp.to_string_hum ~indent:2) forms) ^ "\n"

let canonicalize text =
  let* forms = parse text in
  let* wire = decode_wire forms in
  Ok (wire, render (encode_wire wire))

let check_stable_roundtrip text =
  let* wire, first = canonicalize text in
  let* _, second = canonicalize first in
  if String.equal first second
  then Ok (wire, first)
  else errorf "canonical writer was not stable after parse/decode/write/reparse"

let unknown_forms wire =
  List.filter_map
    (function
      | Unknown form -> Some form
      | _ -> None)
    wire

let event_by_id wire id =
  List.find_map
    (function
      | Event event when String.equal event.id id -> Some event
      | _ -> None)
    wire

let count pred values =
  List.fold_left (fun total value -> if pred value then total + 1 else total) 0 values

let print_summary label wire canonical =
  let known =
    count
      (function
        | Unknown _ -> false
        | _ -> true)
      wire
  in
  let unknown = List.length (unknown_forms wire) in
  let events =
    count
      (function
        | Event _ -> true
        | _ -> false)
      wire
  in
  Printf.printf
    "check=%s forms=%d known=%d unknown=%d events=%d canonical-bytes=%d\n"
    label
    (List.length wire)
    known
    unknown
    events
    (String.length canonical)

let read_all path =
  let channel = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in channel)
    (fun () -> really_input_string channel (in_channel_length channel))

let check_regular path =
  let text = read_all path in
  match check_stable_roundtrip text with
  | Error message -> failwith message
  | Ok (wire, canonical) ->
    let unknown_before = unknown_forms wire in
    let reparsed =
      match parse canonical with
      | Error message -> failwith message
      | Ok forms ->
        (match decode_wire forms with
         | Error message -> failwith message
         | Ok wire -> wire)
    in
    let unknown_after = unknown_forms reparsed in
    if List.length unknown_before <> List.length unknown_after
    then failwith "unknown top-level form count changed during round-trip";
    List.iter2
      (fun before after ->
        if not (Sexp.equal before after)
        then failwith "unknown top-level form changed during round-trip")
      unknown_before
      unknown_after;
    print_summary path wire canonical

let check_probe path =
  let text = read_all path in
  match check_stable_roundtrip text with
  | Error message -> failwith message
  | Ok (wire, canonical) ->
    let huge =
      "100000000000000000000000000000000000001"
    in
    let event =
      match event_by_id wire "huge" with
      | Some event -> event
      | None -> failwith "huge probe event missing after decode"
    in
    let quantities = List.map (fun entry -> Z.to_string entry.quanta) event.effects in
    if quantities <> [ huge; "-" ^ huge ]
    then failwith "arbitrary-precision quantities did not survive Wire V1 decoding";
    let future =
      List.find_opt (head_is "future-evidence") (unknown_forms wire)
    in
    (match future with
     | Some _ -> ()
     | None -> failwith "unknown future-evidence form was not retained opaquely");
    print_summary path wire canonical;
    Printf.printf "probe=huge-zarith-ok unknown-future-form-ok\n"

let bench path copies =
  if copies <= 0 then failwith "benchmark copies must be positive";
  let text = read_all path in
  Gc.full_major ();
  let allocated_before = Gc.allocated_bytes () in
  let start = Unix.gettimeofday () in
  let form_count = ref 0 in
  for _ = 1 to copies do
    match Parsexp.Many.parse_string text with
    | Ok forms -> form_count := !form_count + List.length forms
    | Error _ -> failwith "Parsexp rejected source during benchmark"
  done;
  let elapsed = Unix.gettimeofday () -. start in
  let allocated = Gc.allocated_bytes () -. allocated_before in
  Printf.printf
    "benchmark=cold-source-reparse copies=%d total-forms=%d elapsed-ms=%.3f allocated-mib=%.3f\n"
    copies
    !form_count
    (elapsed *. 1000.)
    (allocated /. 1024. /. 1024.)

let usage () =
  prerr_endline
    "usage: codec_trial check <minimal.sexp> <probe.sexp> | codec_trial bench <minimal.sexp> [copies]";
  exit 2

let () =
  match Array.to_list Sys.argv with
  | [ _; "check"; regular; probe ] ->
    check_regular regular;
    check_probe probe
  | [ _; "bench"; path ] -> bench path 10_000
  | [ _; "bench"; path; copies ] ->
    (match int_of_string_opt copies with
     | Some copies -> bench path copies
     | None -> usage ())
  | _ -> usage ()
