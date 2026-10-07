open Base

module Sexp = Base.Sexp

type supply_state =
  | Provided
  | Empty
  | Not_supplied

type collection_state =
  { name : string
  ; state : supply_state
  }

type top_form =
  | Format_version of int
  | Collections of collection_state list
  | Known of
      { tag : string
      ; sexp : Sexp.t
      }
  | Unknown of Sexp.t

type wire =
  { forms : top_form list
  ; quanta : Z.t list
  }

let state_key = function
  | Provided -> "provided"
  | Empty -> "empty"
  | Not_supplied -> "not-supplied"

let state_of_key = function
  | "provided" -> Some Provided
  | "empty" -> Some Empty
  | "not-supplied" -> Some Not_supplied
  | _ -> None

let known_tags =
  [ "measure"
  ; "event"
  ; "event-correction"
  ; "occurrence-revision"
  ; "relation"
  ; "discharge"
  ; "zero-origin"
  ; "observation"
  ; "presence"
  ; "new-write-loci"
  ; "request-origin"
  ; "scheduled-occurrence"
  ; "attention-item"
  ]

let known_tag tag = List.mem known_tags tag ~equal:String.equal

let rec add_collection_names state names acc =
  match names with
  | [] -> Ok acc
  | Sexp.Atom name :: rest ->
      if List.exists acc ~f:(fun item -> String.equal item.name name) then
        Error ("duplicate collection state for " ^ name)
      else
        add_collection_names state rest ({ name; state } :: acc)
  | _ -> Error "collection names must be atoms"

let decode_collections groups =
  let rec loop groups seen_states acc =
    match groups with
    | [] ->
        if List.length seen_states = 3 then Ok (List.rev acc)
        else Error "collections must explicitly contain provided, empty, and not-supplied groups"
    | Sexp.List (Sexp.Atom key :: names) :: rest -> (
        match state_of_key key with
        | None -> Error ("unknown collection-state group " ^ key)
        | Some state ->
            if List.mem seen_states key ~equal:String.equal then
              Error ("duplicate collection-state group " ^ key)
            else (
              match add_collection_names state names acc with
              | Error _ as error -> error
              | Ok acc -> loop rest (key :: seen_states) acc))
    | _ -> Error "collection-state group must be a list beginning with its state"
  in
  loop groups [] []

let decode_top = function
  | Sexp.List [ Sexp.Atom "bakhlo"; Sexp.Atom "1" ] -> Ok (Format_version 1)
  | Sexp.List (Sexp.Atom "bakhlo" :: _) -> Error "only synthetic format version 1 is admitted"
  | Sexp.List (Sexp.Atom "collections" :: groups) -> (
      match decode_collections groups with
      | Ok collections -> Ok (Collections collections)
      | Error _ as error -> error)
  | (Sexp.List (Sexp.Atom tag :: _) as sexp) when known_tag tag ->
      Ok (Known { tag; sexp })
  | sexp -> Ok (Unknown sexp)

let rec quanta_in = function
  | Sexp.List [ Sexp.Atom "quanta"; Sexp.Atom text ] -> (
      try Ok [ Z.of_string text ] with
      | Invalid_argument _ -> Error ("invalid exact quanta " ^ text)
      | Failure _ -> Error ("invalid exact quanta " ^ text))
  | Sexp.List children ->
      let rec loop children acc =
        match children with
        | [] -> Ok (List.rev acc)
        | child :: rest -> (
            match quanta_in child with
            | Error _ as error -> error
            | Ok values -> loop rest (List.rev_append values acc))
      in
      loop children []
  | Sexp.Atom _ -> Ok []

let decode sexps =
  let rec loop sexps forms quanta =
    match sexps with
    | [] ->
        let forms = List.rev forms in
        let version_count =
          List.count forms ~f:(function
            | Format_version _ -> true
            | Collections _ | Known _ | Unknown _ -> false)
        in
        let collections_count =
          List.count forms ~f:(function
            | Collections _ -> true
            | Format_version _ | Known _ | Unknown _ -> false)
        in
        if not (Int.equal version_count 1) then Error "exactly one format marker is required"
        else if not (Int.equal collections_count 1) then
          Error "exactly one collections declaration is required"
        else Ok { forms; quanta = List.rev quanta }
    | sexp :: rest -> (
        match decode_top sexp with
        | Error _ as error -> error
        | Ok form -> (
            match form with
            | Known { sexp; _ } -> (
                match quanta_in sexp with
                | Error _ as error -> error
                | Ok values -> loop rest (form :: forms) (List.rev_append values quanta))
            | Format_version _ | Collections _ | Unknown _ ->
                loop rest (form :: forms) quanta))
  in
  loop sexps [] []

let decode_string text =
  match Parsexp.Many.parse_string text with
  | Error _ -> Error "S-expression parse error"
  | Ok sexps -> decode sexps

let collection_group state collections =
  let names =
    List.filter_map collections ~f:(fun item ->
        if String.equal (state_key item.state) (state_key state) then Some (Sexp.Atom item.name)
        else None)
  in
  Sexp.List (Sexp.Atom (state_key state) :: names)

let sexp_of_top = function
  | Format_version version ->
      Sexp.List [ Sexp.Atom "bakhlo"; Sexp.Atom (Int.to_string version) ]
  | Collections collections ->
      Sexp.List
        [ Sexp.Atom "collections"
        ; collection_group Provided collections
        ; collection_group Empty collections
        ; collection_group Not_supplied collections
        ]
  | Known { sexp; _ } | Unknown sexp -> sexp

let render wire =
  wire.forms
  |> List.map ~f:(fun form -> Sexp.to_string_hum (sexp_of_top form))
  |> String.concat ~sep:"\n\n"
  |> fun text -> text ^ "\n"

let rec sexp_equal left right =
  match left, right with
  | Sexp.Atom left, Sexp.Atom right -> String.equal left right
  | Sexp.List left, Sexp.List right -> List.equal sexp_equal left right
  | Sexp.Atom _, Sexp.List _ | Sexp.List _, Sexp.Atom _ -> false

let state_for wire name =
  List.find_map wire.forms ~f:(function
    | Collections collections ->
        List.find_map collections ~f:(fun item ->
            if String.equal item.name name then Some item.state else None)
    | Format_version _ | Known _ | Unknown _ -> None)

let version wire =
  List.find_map_exn wire.forms ~f:(function
    | Format_version version -> Some version
    | Collections _ | Known _ | Unknown _ -> None)

let unknown_count wire =
  List.count wire.forms ~f:(function
    | Unknown _ -> true
    | Format_version _ | Collections _ | Known _ -> false)

let debug_json wire =
  let quanta =
    wire.quanta |> List.map ~f:(fun value -> "\"" ^ Z.to_string value ^ "\"")
    |> String.concat ~sep:","
  in
  Stdlib.Printf.sprintf
    "{\"version\":%d,\"forms\":%d,\"unknown\":%d,\"quanta\":[%s]}"
    (version wire)
    (List.length wire.forms)
    (unknown_count wire)
    quanta

let get_ok = function
  | Ok value -> value
  | Error message -> failwith message

let synthetic =
  {|
; Comments are presentation here, not household evidence.
(bakhlo 1)

(collections
  (provided measures events scheduled-occurrences attention-items)
  (empty scheduled-terminals attention-closures)
  (not-supplied settlement))

(measure "jpy"
  (scale 0))

(event "huge"
  (effect
    (key (unkeyed))
    (locus "wallet")
    (measure "jpy")
    (quanta 100000000000000000000000000000000000001))
  (effect
    (key (unkeyed))
    (locus "offset")
    (measure "jpy")
    (quanta -100000000000000000000000000000000000001)))

(scheduled-occurrence "s1"
  (scheduled-on "2000-02-01")
  (movement
    (measure "jpy")
    (change (locus "wallet") (quanta -20))
    (change (locus "food") (quanta 20))))

(attention-item "a1"
  (context "架空例")
  (due (undetermined)))

(future-evidence
  (opaque "keep-me")
  (nested (a b)))
|}

let print_state wire name =
  match state_for wire name with
  | None -> Stdlib.print_endline "missing"
  | Some state -> Stdlib.print_endline (state_key state)

let%expect_test "wire envelope keeps three collection states and exact unbounded quanta" =
  let wire = get_ok (decode_string synthetic) in
  print_state wire "events";
  print_state wire "scheduled-terminals";
  print_state wire "settlement";
  List.iter wire.quanta ~f:(fun value -> Stdlib.print_endline (Z.to_string value));
  [%expect
    {|
    provided
    empty
    not-supplied
    100000000000000000000000000000000000001
    -100000000000000000000000000000000000001
    -20
    20 |}]

let%expect_test "unknown top-level form survives parse write parse by structure" =
  let wire = get_ok (decode_string synthetic) in
  let rendered = render wire in
  let reparsed = Parsexp.Many.parse_string_exn rendered in
  let expected = List.map wire.forms ~f:sexp_of_top in
  Stdlib.print_endline (Bool.to_string (List.equal sexp_equal expected reparsed));
  Stdlib.Printf.printf "unknown=%d\n" (unknown_count wire);
  Stdlib.print_endline (Bool.to_string (String.is_substring rendered ~substring:"future-evidence"));
  Stdlib.print_endline (Bool.to_string (not (String.is_substring rendered ~substring:"Comments")));
  [%expect
    {|
    true
    unknown=1
    true
    true |}]

let%expect_test "wire envelope is a clean export boundary" =
  let wire = get_ok (decode_string synthetic) in
  Stdlib.print_endline (debug_json wire);
  [%expect
    {|
    {"version":1,"forms":7,"unknown":1,"quanta":["100000000000000000000000000000000000001","-100000000000000000000000000000000000001","-20","20"]} |}]

let%expect_test "10k full parse and envelope-decode load smoke" =
  let forms = ref 0 in
  for _ = 1 to 10_000 do
    let wire = get_ok (decode_string synthetic) in
    forms := !forms + List.length wire.forms
  done;
  Stdlib.Printf.printf "decoded=10000 forms=%d\n" !forms;
  [%expect {| decoded=10000 forms=70000 |}]
