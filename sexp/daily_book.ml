(* A corrected-entry book. Earlier input versions belong in separate backups.
   The existing Application owns quantities, reversal and exchange admission. *)
module D = Bakhlo_domain
module R = Q
module A = Bakhlo_application
module Q = A.Current_quantity_query
module X = Sexplib0.Sexp

exception Refused of string

let require p why = if not p then raise (Refused why)
let get why = function Ok x -> x | Error _ -> raise (Refused why)
let eid s = get "invalid-entry-id" (D.Identifier.Event.of_string s)
let lid s = get "invalid-locus" (D.Identifier.Locus.of_string s)
let mid s = get "invalid-measure" (D.Identifier.Measure.of_string s)
let key s = get "invalid-posting-key" (D.Identifier.Effect_key.of_string s)
let estr = D.Identifier.Event.to_string
let lstr = D.Identifier.Locus.to_string
let mstr = D.Identifier.Measure.to_string

let integer_syntax s =
  let len = String.length s in
  let start = if len > 0 && (s.[0] = '-' || s.[0] = '+') then 1 else 0 in
  let rec digits n = n = len || (s.[n] >= '0' && s.[n] <= '9' && digits (n + 1)) in
  len > start && digits start

let integer s =
  require (integer_syntax s) "invalid-integer";
  Z.of_string s

let unique xs why = require (List.length (List.sort_uniq String.compare xs) = List.length xs) why
let coord l m : D.Effect_coordinate.t = { locus = lid l; measure = mid m }
let qty s = D.Quantity.of_quanta (integer s)
let qstr q = Z.to_string (D.Quantity.quanta q)

let posting l m n k =
  D.Effect.create ~locus:(lid l) ~measure:(mid m) ~quantity:(qty n) ~key:(Option.map key k)

type entry = {
  id : string;
  day : string;
  memo : string option;
  effects : D.Effect.t list;
  reversal_of : string option;
  exchange : (string * string) option;
  original_amount : (string * Z.t) option;
  merchant : A.Event_merchants.disposition option;
}

type plan = {
  id : string;
  day : string;
  measure : string;
  changes : (string * Z.t) list;
  paid_by : string option;
  cancelled_on : string option;
}

module Entry_map = Map.Make(String)
module Entry_set = Set.Make(String)

type data = {
  measures : (string * int) list;
  labels : (string * string * string) list option;
  approved : string list option;
  entries_rev : entry list;
  entry_map : entry Entry_map.t;
  entry_count : int;
  reversal_targets : Entry_set.t;  (** IDs some retained entry reverses. *)
  plans : plan list;
  origins : D.Effect_coordinate.t list;
  openings : Q.opening list;
  observations : A.Current_quantity_groups.group list;
  presence : Q.presence option;
  bounded : (D.Effect_coordinate.t * string) list;
}

type t = {
  data : data;
  image : Q.t;
  entries_cached : entry list Lazy.t;
}

let make_data ~measures ~labels ~approved ~entries ~plans ~origins ~openings ~observations ~presence ~bounded =
  let entry_count = List.length entries in
  let entries_rev = List.rev entries in
  let entry_map =
    List.fold_left (fun m (e : entry) -> Entry_map.add e.id e m) Entry_map.empty entries
  in
  let reversal_targets =
    List.fold_left
      (fun s (e : entry) -> Option.fold ~none:s ~some:(fun id -> Entry_set.add id s) e.reversal_of)
      Entry_set.empty entries
  in
  {
    measures;
    labels;
    approved;
    entries_rev;
    entry_map;
    entry_count;
    reversal_targets;
    plans;
    origins;
    openings;
    observations;
    presence;
    bounded;
  }

let empty_command : A.Actual_source.command =
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

let valid_date day = require (A.Actual_validity.valid_date day) "invalid-date"

(* Admission stages. A mutation that changes only one family may run only that
   family's stage on an admitted book: the other stages depend on nothing it
   changes, so they would pass again, and stage order keeps the same first refusal. *)
let known_measure data m = require (List.mem_assoc m data.measures) "measure-scale-not-supplied"

let check_vocabulary data =
  unique (List.map fst data.measures) "duplicate-measure";
  List.iter
    (fun (m, n) ->
      ignore (mid m);
      require (n >= 0 && n <= 9) "invalid-scale")
    data.measures;
  Option.iter
    (fun rows ->
      unique (List.map (fun (id, _, _) -> id) rows) "duplicate-label";
      List.iter
        (fun (id, label, help) ->
          ignore (lid id);
          require (label <> "" && help <> "") "invalid-label")
        rows)
    data.labels;
  Option.iter
    (fun ids ->
      unique ids "duplicate-approved-locus";
      List.iter (fun id -> ignore (lid id)) ids)
    data.approved

let check_plans data =
  let known = known_measure data in
  unique (List.map (fun (p : plan) -> p.id) data.plans) "duplicate-plan";
  unique (List.filter_map (fun (p : plan) -> p.paid_by) data.plans) "duplicate-plan-payment";
  List.iter
    (fun (p : plan) ->
      require (p.id <> "") "invalid-plan-id";
      valid_date p.day;
      known p.measure;
      List.iter (fun (l, _) -> ignore (lid l)) p.changes;
      require
        (Z.equal Z.zero (List.fold_left (fun total (_, n) -> Z.add total n) Z.zero p.changes))
        "unbalanced-plan";
      require (p.paid_by = None || p.cancelled_on = None) "plan-paid-and-cancelled";
      Option.iter valid_date p.cancelled_on;
      Option.iter
        (fun id ->
          require (Entry_map.mem id data.entry_map) "unknown-plan-payment")
        p.paid_by)
    data.plans

let admit ?entries_cached data =
  check_vocabulary data;
  let known = known_measure data in
  let entries =
    match entries_cached with
    | Some c -> Lazy.force c
    | None -> List.rev data.entries_rev
  in
  let events =
    List.map
      (fun (e : entry) ->
        List.iter (fun p -> known (mstr (D.Effect.measure p))) e.effects;
        Option.iter (fun (m, _) -> known m) e.original_amount;
        get "invalid-entry" (D.Event.create ~id:(eid e.id) ~effects:e.effects))
      entries
  in
  let source =
    get "entry-admission"
      (A.Actual_source.create
         {
           empty_command with
           events;
           validities =
             List.map
               (fun (e : entry) -> A.Actual_validity.Base { event = eid e.id; valid_on = e.day })
               entries;
           descriptions =
             List.filter_map
               (fun (e : entry) ->
                 Option.map
                   (fun text ->
                     ({ A.Event_descriptions.event = eid e.id; text } : A.Event_descriptions.fact))
                   e.memo)
               entries;
           merchants =
             List.filter_map
               (fun (e : entry) ->
                 Option.map
                   (fun disposition ->
                     ({ A.Event_merchants.event = eid e.id; disposition } : A.Event_merchants.fact))
                   e.merchant)
               entries;
           reversals =
             List.filter_map
               (fun (e : entry) ->
                 Option.map
                   (fun target ->
                     ({ A.Actual_reversals.target = eid target; reversal = eid e.id }
                       : A.Actual_reversals.fact))
                   e.reversal_of)
               entries;
           original_amounts =
             List.filter_map
               (fun (e : entry) ->
                 Option.map
                   (fun (m, q) ->
                     ({
                        A.Original_amounts.root = eid e.id;
                        measure = mid m;
                        quantity = D.Quantity.of_quanta q;
                      }
                       : A.Original_amounts.fact))
                   e.original_amount)
               entries;
           exchanges =
             List.filter_map
               (fun (e : entry) ->
                 Option.map
                   (fun (from_key, to_key) ->
                     ({
                        A.Exchange_evidence.event = eid e.id;
                        source = key from_key;
                        destination = key to_key;
                      }
                       : A.Exchange_evidence.fact))
                   e.exchange)
               entries;
         })
  in
  check_plans data;
  let known_coord (c : D.Effect_coordinate.t) = known (mstr c.measure) in
  List.iter known_coord data.origins;
  List.iter (fun (o : Q.opening) -> known_coord o.coordinate) data.openings;
  List.iter
    (fun (g : A.Current_quantity_groups.group) ->
      List.iter
        (fun (a : A.Current_quantity_projection.assertion) -> known_coord a.coordinate)
        g.assertions)
    data.observations;
  Option.iter (fun (p : Q.presence) -> List.iter known_coord p.coordinates) data.presence;
  (* Explicit claims only; route conflicts are refused when a history is asked. *)
  unique
    (List.map (fun ((c : D.Effect_coordinate.t), _) -> lstr c.locus ^ "\x00" ^ mstr c.measure)
       data.bounded)
    "duplicate-bounded-history-coordinate";
  List.iter (fun (c, day) -> known_coord c; valid_date day) data.bounded;
  let entries_cached =
    match entries_cached with
    | Some c -> c
    | None -> lazy entries
  in
  {
    data;
    image =
      get "support-admission"
        (Q.create ~source ~zero_origins:data.origins ~openings:data.openings
           ~groups:data.observations ~presence:data.presence);
    entries_cached;
  }

let protect f = try Ok (f ()) with Refused why -> Error why

let empty ~measure ~scale =
  protect (fun () ->
      admit
        (make_data ~measures:[ (measure, scale) ] ~labels:None ~approved:(Some [])
           ~entries:[] ~plans:[] ~origins:[] ~openings:[] ~observations:[] ~presence:None ~bounded:[]))

let atom = function X.Atom s -> s | X.List _ -> raise (Refused "expected-atom")

let field name rows =
  match
    List.filter_map
      (function
        | X.List (X.Atom tag :: xs) when tag = name -> Some xs | X.Atom _ | X.List _ -> None)
      rows
  with
  | [ xs ] -> xs
  | [] -> raise (Refused "missing-field")
  | _ :: _ -> raise (Refused "duplicate-field")

let field_opt name rows =
  match
    List.filter_map
      (function
        | X.List (X.Atom tag :: xs) when tag = name -> Some xs | X.Atom _ | X.List _ -> None)
      rows
  with
  | [ xs ] -> Some xs
  | [] -> None
  | _ :: _ -> raise (Refused "duplicate-field")
let fields allowed rows =
  let names =
    List.map
      (function
        | X.List (X.Atom name :: _) -> name
        | X.Atom _ | X.List [] | X.List (X.List _ :: _) -> raise (Refused "invalid-field"))
      rows
  in
  unique names "duplicate-field";
  require (List.for_all (fun name -> List.mem name allowed) names) "unsupported-field"

let one = function [ x ] -> x | [] | _ :: _ -> raise (Refused "expected-single-value")

let optional = function
  | X.List [ X.Atom "none" ] -> None
  | X.List [ X.Atom "some"; X.Atom s ] -> Some s
  | X.Atom _ | X.List _ -> raise (Refused "invalid-optional-value")
let valid_token s =
  s <> "" && not (String.contains s '\t' || String.contains s '\n' || String.contains s '\r')


let decode_posting = function
  | X.List [ X.Atom "posting"; X.Atom l; X.Atom m; X.Atom n; k ] -> posting l m n (optional k)
  | X.Atom _ | X.List _ -> raise (Refused "invalid-posting")

let decode_entry version = function
  | X.List (X.Atom "entry" :: X.Atom id :: rows) ->
      fields
        (if version = "1" then [ "date"; "memo"; "postings"; "reversal-of" ]
         else if version = "2" then [ "date"; "memo"; "postings"; "reversal-of"; "exchange" ]
         else [ "date"; "memo"; "postings"; "reversal-of"; "exchange"; "original-amount"; "merchant" ])
        rows;
      let exchange =
        if version = "1" then None
        else
          match field "exchange" rows with
          | [ X.List [ X.Atom "none" ] ] -> None
          | [ X.List [ X.Atom "keys"; X.Atom a; X.Atom b ] ] -> Some (a, b)
          | [] | _ :: _ -> raise (Refused "invalid-exchange")
      in
      {
        id;
        day = atom (one (field "date" rows));
        memo = optional (one (field "memo" rows));
        effects = List.map decode_posting (field "postings" rows);
        reversal_of = optional (one (field "reversal-of" rows));
        exchange;
        original_amount =
          (if version = "1" || version = "2" then None
           else
             match field_opt "original-amount" rows with
             | None | Some [ X.List [ X.Atom "none" ] ] -> None
             | Some [ X.List [ X.Atom "amount"; X.Atom m; X.Atom q ] ] ->
                 let q = integer q in
                 require (Z.sign q > 0) "non-positive-amount";
                 Some (m, q)
             | _ -> raise (Refused "invalid-original-amount"));
        merchant =
          (if version = "1" || version = "2" then None
           else
             match field_opt "merchant" rows with
             | None | Some [ X.List [ X.Atom "none" ] ] -> None
             | Some [ X.List [ X.Atom "nonmerchant" ] ] -> Some A.Event_merchants.Nonmerchant
             | Some [ X.List [ X.Atom "party"; X.Atom p ] ] ->
                 require (valid_token p) "invalid-merchant-party";
                 let party = get "invalid-merchant-party" (D.Identifier.External_party.of_string p) in
                 Some (A.Event_merchants.Merchant party)
             | _ -> raise (Refused "invalid-merchant"));
      }
  | X.Atom _ | X.List _ -> raise (Refused "invalid-entry")

let decode_plan version = function
  | X.List (X.Atom "plan" :: X.Atom id :: rows) ->
      fields
        (if version = "3" then
           [ "date"; "measure"; "changes"; "paid-by"; "cancelled-on" ]
         else [ "date"; "measure"; "changes"; "paid-by" ])
        rows;
      {
        id;
        day = atom (one (field "date" rows));
        measure = atom (one (field "measure" rows));
        changes =
          List.map
            (function
              | X.List [ X.Atom l; X.Atom n ] -> (l, integer n)
              | X.Atom _ | X.List _ -> raise (Refused "invalid-change"))
            (field "changes" rows);
        paid_by = optional (one (field "paid-by" rows));
        cancelled_on =
          (if version = "3" then optional (one (field "cancelled-on" rows))
           else None);
      }
  | X.Atom _ | X.List _ -> raise (Refused "invalid-plan")

let decode_coord = function
  | X.List [ X.Atom l; X.Atom m ] -> coord l m
  | X.Atom _ | X.List _ -> raise (Refused "invalid-coordinate")

let supplied decode = function
  | [ X.List [ X.Atom "not-supplied" ] ] -> None
  | [ X.List (X.Atom "provided" :: xs) ] -> Some (List.map decode xs)
  | [] | _ :: _ -> raise (Refused "invalid-supply")

type payload = {
  measures : (string * int) list;
  labels : (string * string * string) list option;
  approved : string list option;
  entries : entry list;
  plans : plan list;
  origins : D.Effect_coordinate.t list;
  openings : Q.opening list;
  observations : A.Current_quantity_groups.group list;
  presence : Q.presence option;
  bounded : (D.Effect_coordinate.t * string) list;
}

let parse_payload version rows =
  fields [ "scope"; "measures"; "labels"; "approved-loci"; "entries"; "plans"; "support" ] rows;
  require
    (List.map atom (field "scope" rows) = [ "corrected-entries"; "explicit-plans" ])
    "unsupported-scope";
  let support = field "support" rows in
  (* v4 was the removed budget trial: never reinterpret it. v5 is v3 plus
     non-empty bounded history support; v3 stays the encoding without it. *)
  let bounded_version = version = "5" in
  let version = if bounded_version then "3" else version in
  fields
    ([ "zero-origin"; "openings"; "observations"; "presence" ]
     @ if bounded_version then [ "bounded-history" ] else [])
    support;
  let bounded =
    if not bounded_version then []
    else
      List.map
        (function
          | X.List [ X.Atom l; X.Atom m; X.Atom day ] -> (coord l m, day)
          | X.Atom _ | X.List _ -> raise (Refused "invalid-bounded-history"))
        (field "bounded-history" support)
  in
  require (not bounded_version || bounded <> []) "empty-bounded-history";
  let presence =
    match field "presence" support with
    | [ X.List [ X.Atom "not-supplied" ] ] -> None
    | [ X.List (X.Atom "provided" :: xs) ] ->
        fields [ "reflected"; "coordinates" ] xs;
        Some
          {
            Q.reflected_roots = List.map (fun x -> eid (atom x)) (field "reflected" xs);
            coordinates = List.map decode_coord (field "coordinates" xs);
          }
    | [] | _ :: _ -> raise (Refused "invalid-presence")
  in
  let entries = List.map (decode_entry version) (field "entries" rows) in
  ({
    measures =
      List.map
        (function
          | X.List [ X.Atom "measure"; X.Atom m; X.Atom n ] ->
              let n = integer n in
              require (Z.geq n Z.zero && Z.leq n (Z.of_int 9)) "invalid-scale";
              (m, Z.to_int n)
          | X.Atom _ | X.List _ -> raise (Refused "invalid-measure"))
        (field "measures" rows);
    labels =
      supplied
        (function
          | X.List [ X.Atom "label"; X.Atom id; X.Atom label; X.Atom help ] ->
              (id, label, help)
          | X.Atom _ | X.List _ -> raise (Refused "invalid-label"))
        (field "labels" rows);
    approved = supplied atom (field "approved-loci" rows);
    entries;
    plans = List.map (decode_plan version) (field "plans" rows);
    origins = List.map decode_coord (field "zero-origin" support);
    openings =
      List.map
        (function
          | X.List [ X.Atom l; X.Atom m; X.Atom e ] ->
              ({ Q.coordinate = coord l m; opening_event = eid e } : Q.opening)
          | X.Atom _ | X.List _ -> raise (Refused "invalid-opening"))
        (field "openings" support);
    observations =
      List.map
        (function
          | X.List (X.Atom "observation" :: xs) ->
              fields [ "reflected"; "quantities" ] xs;
              {
                A.Current_quantity_groups.reflected_roots =
                  List.map (fun x -> eid (atom x)) (field "reflected" xs);
                assertions =
                  List.map
                    (function
                      | X.List [ X.Atom l; X.Atom m; X.Atom n ] ->
                          ({
                             A.Current_quantity_projection.coordinate = coord l m;
                             quantity = qty n;
                           }
                            : A.Current_quantity_projection.assertion)
                      | X.Atom _ | X.List _ -> raise (Refused "invalid-assertion"))
                    (field "quantities" xs);
              }
          | X.Atom _ | X.List _ -> raise (Refused "invalid-observation"))
        (field "observations" support);
    presence;
    bounded;
  } : payload)

let admit_payload (p : payload) =
  protect (fun () ->
    let data =
      make_data ~measures:p.measures ~labels:p.labels ~approved:p.approved
        ~entries:p.entries ~plans:p.plans ~origins:p.origins ~openings:p.openings
        ~observations:p.observations ~presence:p.presence ~bounded:p.bounded
    in
    admit ~entries_cached:(lazy p.entries) data)

let export_payload (t : t) : payload =
  {
    measures = t.data.measures;
    labels = t.data.labels;
    approved = t.data.approved;
    entries = Lazy.force t.entries_cached;
    plans = t.data.plans;
    origins = t.data.origins;
    openings = t.data.openings;
    observations = t.data.observations;
    presence = t.data.presence;
    bounded = t.data.bounded;
  }

let of_string bytes =
  protect (fun () ->
      match get "syntax" (Parsexp.Many.parse_string bytes) with
      | X.List [ X.Atom "bakhlo-daily"; X.Atom version ] :: rows
        when version = "1" || version = "2" || version = "3" || version = "5" ->
          let payload = parse_payload version rows in
          (match admit_payload payload with Ok t -> t | Error why -> raise (Refused why))
      | [] | _ :: _ -> raise (Refused "unsupported-book-header"))


let a s = X.Atom s
let l xs = X.List xs
let f tag xs = l (a tag :: xs)
let opt = function None -> f "none" [] | Some s -> f "some" [ a s ]
let coordinate (c : D.Effect_coordinate.t) = l [ a (lstr c.locus); a (mstr c.measure) ]

let payload_sexps (b : payload) =
  let supplied encode = function
    | None -> f "not-supplied" []
    | Some xs -> f "provided" (List.map encode xs)
  in
  [
    f "scope" [ a "corrected-entries"; a "explicit-plans" ];
    f "measures" (List.map (fun (m, n) -> f "measure" [ a m; a (string_of_int n) ]) b.measures);
    f "labels" [ supplied (fun (id, name, help) -> f "label" [ a id; a name; a help ]) b.labels ];
    f "approved-loci" [ supplied a b.approved ];
    f "entries"
      (List.map
         (fun (e : entry) ->
           f "entry"
             [
               a e.id;
               f "date" [ a e.day ];
               f "memo" [ opt e.memo ];
               f "postings"
                 (List.map
                    (fun p ->
                      f "posting"
                        [
                          a (lstr (D.Effect.locus p));
                          a (mstr (D.Effect.measure p));
                          a (qstr (D.Effect.quantity p));
                          opt (Option.map D.Identifier.Effect_key.to_string (D.Effect.key p));
                        ])
                    e.effects);
               f "reversal-of" [ opt e.reversal_of ];
               f "exchange"
                 [
                   (match e.exchange with
                   | None -> f "none" []
                   | Some (a_, b_) -> f "keys" [ a a_; a b_ ]);
                 ];
               f "original-amount"
                 [
                   (match e.original_amount with
                   | None -> f "none" []
                   | Some (m, q) -> f "amount" [ a m; a (Z.to_string q) ]);
                 ];
               f "merchant"
                 [
                   (match e.merchant with
                   | None -> f "none" []
                   | Some Nonmerchant -> f "nonmerchant" []
                   | Some (Merchant p) -> f "party" [ a (D.Identifier.External_party.to_string p) ]);
                 ];
             ])
         b.entries);
    f "plans"
      (List.map
         (fun (p : plan) ->
           f "plan"
             [
               a p.id;
               f "date" [ a p.day ];
               f "measure" [ a p.measure ];
               f "changes" (List.map (fun (loc, n) -> l [ a loc; a (Z.to_string n) ]) p.changes);
               f "paid-by" [ opt p.paid_by ];
               f "cancelled-on" [ opt p.cancelled_on ];
             ])
         b.plans);
    f "support"
      ([
         f "zero-origin" (List.map coordinate b.origins);
        f "openings"
          (List.map
             (fun (o : Q.opening) ->
               l
                 [
                   a (lstr o.coordinate.locus);
                   a (mstr o.coordinate.measure);
                   a (estr o.opening_event);
                 ])
             b.openings);
        f "observations"
          (List.map
             (fun (g : A.Current_quantity_groups.group) ->
               f "observation"
                 [
                   f "reflected" (List.map (fun id -> a (estr id)) g.reflected_roots);
                   f "quantities"
                     (List.map
                        (fun (row : A.Current_quantity_projection.assertion) ->
                          l
                            [
                              a (lstr row.coordinate.locus);
                              a (mstr row.coordinate.measure);
                              a (qstr row.quantity);
                            ])
                        g.assertions);
                 ])
             b.observations);
        f "presence"
          [
            (match b.presence with
            | None -> f "not-supplied" []
            | Some p ->
                f "provided"
                  [
                    f "reflected" (List.map (fun id -> a (estr id)) p.reflected_roots);
                    f "coordinates" (List.map coordinate p.coordinates);
                  ]);
          ];
      ]
      @ (if b.bounded = [] then []
         else
           [
             f "bounded-history"
               (List.map
                  (fun ((c : D.Effect_coordinate.t), day) ->
                    l [ a (lstr c.locus); a (mstr c.measure); a day ])
                  b.bounded);
           ]));
  ]

let sexps t =
  f "bakhlo-daily" [ a (if t.data.bounded = [] then "3" else "5") ]
  :: payload_sexps (export_payload t)

let quote s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter
    (function
      | '"' -> Buffer.add_string b "\\\""
      | '\\' -> Buffer.add_string b "\\\\"
      | '\n' -> Buffer.add_string b "\\n"
      | '\r' -> Buffer.add_string b "\\r"
      | '\t' -> Buffer.add_string b "\\t"
      | c when Char.code c < 32 || Char.code c = 127 ->
          Buffer.add_string b (Printf.sprintf "\\%03d" (Char.code c))
      | c -> Buffer.add_char b c)
    s;
  Buffer.add_char b '"';
  Buffer.contents b

let render_into out x =
  let is_tag = function
    | "bakhlo-daily" | "scope" | "measures" | "measure" | "labels" | "label" | "approved-loci"
    | "entries" | "entry" | "date" | "memo" | "postings" | "posting" | "reversal-of" | "exchange"
    | "keys" | "original-amount" | "amount" | "merchant" | "party" | "nonmerchant" | "plans" | "plan" | "changes" | "paid-by" | "cancelled-on" | "support"
    | "zero-origin" | "openings" | "observations" | "observation" | "reflected"
    | "quantities" | "presence" | "bounded-history" | "coordinates" | "provided" | "not-supplied" | "none" | "some" ->
        true
    | _ -> false
  in
  (* Printing needs the same lexical decision, not a Quantity parse or exceptions. *)
  let leaf s = if integer_syntax s then s else quote s in
  (* Probe only until the flat form exceeds the available bytes: no full flat
     string or second layout tree. Quoting and the 110-byte layout rule stay
     unchanged; this is not terminal cell-width formatting. *)
  let rec remaining room = function
    | _ when room < 0 -> -1
    | X.Atom s -> if String.length s > room then -1 else room - String.length (leaf s)
    | X.List xs -> (
        let rec children room = function
          | _ when room < 0 -> -1
          | [] -> room
          | child :: rest ->
              let room = remaining room child in
              children (room - if rest = [] then 0 else 1) rest
        in
        let room = room - 2 in
        match xs with
        | X.Atom tag :: rest when is_tag tag ->
            children (room - String.length tag - if rest = [] then 0 else 1) rest
        | _ -> children room xs)
  in
  let rec flat = function
    | X.Atom s -> Buffer.add_string out (leaf s)
    | X.List xs ->
        Buffer.add_char out '(';
        let children =
          match xs with
          | X.Atom tag :: rest when is_tag tag ->
              Buffer.add_string out tag;
              if rest <> [] then Buffer.add_char out ' ';
              rest
          | _ -> xs
        in
        List.iteri
          (fun n child ->
            if n > 0 then Buffer.add_char out ' ';
            flat child)
          children;
        Buffer.add_char out ')'
  in
  let rec pretty indent x =
    match x with
    | X.List (X.Atom tag :: children) when is_tag tag && remaining (110 - indent) x < 0 ->
        Buffer.add_char out '(';
        Buffer.add_string out tag;
        let padding = String.make (indent + 2) ' ' in
        List.iter
          (fun child ->
            Buffer.add_char out '\n';
            Buffer.add_string out padding;
            pretty (indent + 2) child)
          children;
        Buffer.add_char out ')'
    | node -> flat node
  in
  pretty 0 x

let to_string t =
  let out = Buffer.create 1024 in
  Buffer.add_string out "; Corrected entries and explicit plans. No correction-version chains.\n";
  List.iteri
    (fun n x ->
      if n > 0 then Buffer.add_string out "\n\n";
      render_into out x)
    (sexps t);
  Buffer.add_char out '\n';
  Buffer.contents out

let entries t = Lazy.force t.entries_cached
let entries_rev t = t.data.entries_rev
let entry_count t = t.data.entry_count
let find_entry t id = Entry_map.find_opt id t.data.entry_map
let mem_entry t id = Entry_map.mem id t.data.entry_map
let plans t = t.data.plans
let plan_is_open (p : plan) = p.paid_by = None && p.cancelled_on = None
let open_plans t = List.filter plan_is_open t.data.plans
let measures t = t.data.measures
let approved_loci t = t.data.approved
let image t = t.image

let label t id =
  match t.data.labels with
  | None -> id
  | Some rows -> (
      match List.find_opt (fun (key, _, _) -> key = id) rows with
      | None -> id
      | Some (_, name, _) -> name)

let help t id =
  match t.data.labels with
  | None -> ""
  | Some rows -> (
      match List.find_opt (fun (key, _, _) -> key = id) rows with
      | None -> ""
      | Some (_, _, h) -> h)

let scale t m =
  get "unknown-measure"
    (match List.assoc_opt m t.data.measures with Some n -> Ok n | None -> Error ())

let format t m n =
  let decimals = scale t m in
  if decimals = 0 then Z.to_string n
  else
    let factor = Z.pow (Z.of_int 10) decimals in
    let whole, fraction = Z.div_rem (Z.abs n) factor in
    let digits = Z.to_string fraction in
    (if Z.sign n < 0 then "-" else "")
    ^ Z.to_string whole ^ "."
    ^ String.make (decimals - String.length digits) '0'
    ^ digits

let normalize_amount_text text =
  let len = String.length text in
  let b = Buffer.create len in
  let rec loop i =
    if i >= len then Buffer.contents b
    else if i + 2 < len
            && Char.code text.[i] = 0xEF
            && Char.code text.[i + 1] = 0xBC then
      let c3 = Char.code text.[i + 2] in
      if c3 >= 0x90 && c3 <= 0x99 then begin
        Buffer.add_char b (Char.chr (Char.code '0' + (c3 - 0x90)));
        loop (i + 3)
      end else begin
        (match c3 with
         | 0x8C -> Buffer.add_char b ','
         | 0x8E -> Buffer.add_char b '.'
         | 0x8B -> Buffer.add_char b '+'
         | 0x8D -> Buffer.add_char b '-'
         | 0x8A -> Buffer.add_char b '*'
         | 0x8F -> Buffer.add_char b '/'
         | 0x88 -> Buffer.add_char b '('
         | 0x89 -> Buffer.add_char b ')'
         | _ -> Buffer.add_substring b text i 3);
        loop (i + 3)
      end
    else if i + 1 < len && text.[i] = '\xc3'
            && (text.[i + 1] = '\x97' || text.[i + 1] = '\xb7') then begin
      Buffer.add_char b (if text.[i + 1] = '\x97' then '*' else '/');
      loop (i + 2)
    end
    else if i + 2 < len && text.[i] = '\xe3'
            && text.[i + 1] = '\x80' && text.[i + 2] = '\x80' then begin
      Buffer.add_char b ' ';
      loop (i + 3)
    end
    else begin
      Buffer.add_char b text.[i];
      loop (i + 1)
    end
  in
  loop 0

let parse_whole whole =
  let is_digit c = c >= '0' && c <= '9' in
  if whole = "" then raise (Refused "invalid-amount");
  if not (String.contains whole ',') then begin
    require (String.for_all is_digit whole) "invalid-amount";
    whole
  end else
    let groups = String.split_on_char ',' whole in
    match groups with
    | [] -> raise (Refused "invalid-amount")
    | g0 :: rest ->
        require (rest <> []) "invalid-amount";
        let len0 = String.length g0 in
        require (len0 >= 1 && len0 <= 3 && String.for_all is_digit g0) "invalid-amount";
        List.iter
          (fun g ->
            require (String.length g = 3 && String.for_all is_digit g) "invalid-amount")
          rest;
        String.concat "" groups

let calculate_amount decimals text =
  (* shortcut: cap expression input to bound recursive nesting, raise it if real receipts need more. *)
  require (String.length text <= 4096) "invalid-amount";
  let length = String.length text and pos = ref 0 in
  let rec spaces () =
    if !pos < length && text.[!pos] = ' ' then (incr pos; spaces ())
  in
  let decimal () =
    spaces ();
    let start = !pos in
    while !pos < length &&
          (match text.[!pos] with '0' .. '9' | ',' | '.' -> true | _ -> false) do
      incr pos
    done;
    let raw = String.sub text start (!pos - start) in
    match String.split_on_char '.' raw with
    | [whole] -> R.of_bigint (integer (parse_whole whole))
    | [whole; fraction] ->
        require (fraction <> "" && String.for_all (fun c -> c >= '0' && c <= '9') fraction)
          "invalid-amount";
        let whole = parse_whole whole in
        R.make (integer (whole ^ fraction)) (Z.pow (Z.of_int 10) (String.length fraction))
    | _ -> raise (Refused "invalid-amount")
  in
  let rec atom () =
    spaces ();
    if !pos < length && text.[!pos] = '(' then (
      incr pos;
      let value = expression () in
      spaces ();
      require (!pos < length && text.[!pos] = ')') "invalid-amount";
      incr pos;
      value)
    else decimal ()
  and product () =
    let rec more value =
      spaces ();
      if !pos < length && (text.[!pos] = '*' || text.[!pos] = '/') then (
        let op = text.[!pos] in
        incr pos;
        let right = atom () in
        if op = '/' then require (not (R.equal right R.zero)) "division-by-zero";
        more (if op = '*' then R.mul value right else R.div value right))
      else value
    in
    more (atom ())
  and expression () =
    let rec more value =
      spaces ();
      if !pos < length && (text.[!pos] = '+' || text.[!pos] = '-') then (
        let op = text.[!pos] in
        incr pos;
        let right = product () in
        more (if op = '+' then R.add value right else R.sub value right))
      else value
    in
    more (product ())
  in
  let value = expression () in
  spaces ();
  require (!pos = length) "invalid-amount";
  require (R.sign value > 0) "non-positive-amount";
  let quanta = R.mul value (R.of_bigint (Z.pow (Z.of_int 10) decimals)) in
  require (Z.equal (R.den quanta) Z.one) "indivisible-amount";
  R.num quanta

let parse_amount t m text =
  protect (fun () ->
      let decimals = scale t m in
      let norm = normalize_amount_text text in
      let expression =
        String.exists (function '+' | '-' | '*' | '/' | '(' | ')' -> true | _ -> false) norm
      in
      if expression then calculate_amount decimals norm else
      let is_digit c = c >= '0' && c <= '9' in
      let n =
        match String.split_on_char '.' norm with
        | [ whole ] ->
            let clean_whole = parse_whole whole in
            Z.mul (integer clean_whole) (Z.pow (Z.of_int 10) decimals)
        | [ whole; fraction ] ->
            let clean_whole = parse_whole whole in
            require (fraction <> "" && String.for_all is_digit fraction) "invalid-amount";
            require (decimals > 0 && String.length fraction <= decimals) "amount-precision";
            integer (clean_whole ^ fraction ^ String.make (decimals - String.length fraction) '0')
        | [] | _ :: _ -> raise (Refused "invalid-amount")
      in
      require (Z.sign n > 0) "non-positive-amount";
      n)

let parse_signed_amount t m text =
  protect (fun () ->
      let text = String.trim text in
      require (text <> "") "empty-amount";
      let is_neg, clean_text =
        if String.starts_with ~prefix:"-" text then
          (true, String.sub text 1 (String.length text - 1))
        else if String.starts_with ~prefix:"+" text then
          (false, String.sub text 1 (String.length text - 1))
        else (false, text)
      in
      let decimals = scale t m in
      let norm = normalize_amount_text clean_text in
      let is_digit c = c >= '0' && c <= '9' in
      let n =
        match String.split_on_char '.' norm with
        | [ whole ] ->
            let clean_whole = parse_whole whole in
            Z.mul (integer clean_whole) (Z.pow (Z.of_int 10) decimals)
        | [ whole; fraction ] ->
            let clean_whole = parse_whole whole in
            require (fraction <> "" && String.for_all is_digit fraction) "invalid-amount";
            require (decimals > 0 && String.length fraction <= decimals) "amount-precision";
            integer (clean_whole ^ fraction ^ String.make (decimals - String.length fraction) '0')
        | [] | _ :: _ -> raise (Refused "invalid-amount")
      in
      if is_neg then Z.neg n else n)


type daily_pace = {
  measure : string;
  observed_at : string;
  end_exclusive : string;
  remaining_days : int;
  pool_balances : (D.Effect_coordinate.t * Z.t) list;
  plan_deductions : (string * Z.t) list;
  eligible_pool : Z.t;
  automatic_deductions : Z.t;
  available_through_end : Z.t;
  daily_pace_quanta : Z.t;
}

(* Calendar arithmetic over the existing validated 0001..9999 ISO spelling;
   never Unix timestamps, local clock reads, or retained period state. *)
let day_number text =
  valid_date text;
  let year = int_of_string (String.sub text 0 4)
  and month = int_of_string (String.sub text 5 2)
  and day = int_of_string (String.sub text 8 2) in
  let previous = year - 1 in
  let months = [| 0; 31; 59; 90; 120; 151; 181; 212; 243; 273; 304; 334 |] in
  let leap = year mod 400 = 0 || (year mod 4 = 0 && year mod 100 <> 0) in
  (365 * previous) + (previous / 4) - (previous / 100) + (previous / 400)
  + months.(month - 1)
  + day
  + if leap && month > 2 then 1 else 0

let daily_pace t ~measure ~pool ~observed_at ~end_exclusive =
  protect (fun () ->
      let first = day_number observed_at and last = day_number end_exclusive in
      let remaining_days = last - first in
      require (remaining_days > 0) "daily-pace-non-positive-horizon";
      ignore (scale t measure);
      let selected_measure = mid measure in
      require
        (List.length (List.sort_uniq D.Effect_coordinate.compare pool) = List.length pool)
        "daily-pace-duplicate-coordinate";
      require
        (List.for_all
           (fun (c : D.Effect_coordinate.t) ->
             D.Identifier.Measure.equal c.measure selected_measure)
           pool)
        "daily-pace-pool-measure-mismatch";
      let pool_balances =
        List.map
          (fun c ->
            let n =
              match Q.query t.image c with
              | Ok (Q.Exact answer) -> D.Quantity.quanta (Q.quantity answer)
              | Ok (Q.Known_present _) ->
                  raise
                    (Refused ("daily-pace-balance-amount-unknown:" ^ lstr c.locus ^ ":" ^ measure))
              | Error (Q.Support_unknown _) ->
                  raise
                    (Refused ("daily-pace-balance-support-unknown:" ^ lstr c.locus ^ ":" ^ measure))
            in
            (c, n))
          pool
      in
      let selected locus =
        List.exists (fun (c : D.Effect_coordinate.t) -> lstr c.locus = locus) pool
      in
      let plan_deductions =
        open_plans t
        |> List.filter_map (fun (p : plan) ->
            if p.measure <> measure || p.day >= end_exclusive then None
            else
              let net =
                List.fold_left
                  (fun total (locus, n) -> if selected locus then Z.add total n else total)
                  Z.zero p.changes
              in
              if Z.sign net < 0 then Some (p.id, Z.neg net) else None)
      in
      let sum rows = List.fold_left (fun total (_, n) -> Z.add total n) Z.zero rows in
      let eligible_pool = sum pool_balances and automatic_deductions = sum plan_deductions in
      let available_through_end = Z.sub eligible_pool automatic_deductions in
      {
        measure;
        observed_at;
        end_exclusive;
        remaining_days;
        pool_balances;
        plan_deductions;
        eligible_pool;
        automatic_deductions;
        available_through_end;
        (* Positive divisor: Euclidean division floors negative deficits too,
           matching LOAM's integer-quanta guide, not truncation toward zero. *)
        daily_pace_quanta = Z.ediv available_through_end (Z.of_int remaining_days);
      })

let approve_effects t effects =
  match t.data.approved with
  | None -> raise (Refused "locus-policy-not-supplied")
  | Some ids ->
      List.iter
        (fun p -> require (List.mem (lstr (D.Effect.locus p)) ids) "locus-unapproved")
        effects

let find_plan t id =
  match List.find_opt (fun (p : plan) -> p.id = id) t.data.plans with
  | Some p -> p
  | None -> raise (Refused "unknown-plan")

let require_open_plan (p : plan) =
  require (p.paid_by = None) "plan-already-paid";
  require (p.cancelled_on = None) "plan-cancelled"

(* Every mutation builds its candidate once. The ordinary entry point checks only
   the stages the change can affect (see the admission stages); [Full] re-admits
   the whole candidate and is the reference the oracle compares against. *)
let plan_candidate t ~replace (p : plan) =
  require (plan_is_open p) "plan-terminal-not-input";
  let exists = List.exists (fun (row : plan) -> row.id = p.id) t.data.plans in
  require (exists = replace) (if replace then "unknown-plan" else "duplicate-plan");
  if replace then require_open_plan (find_plan t p.id);
  let effects =
    List.map
      (fun (loc, n) ->
        D.Effect.create ~locus:(lid loc) ~measure:(mid p.measure)
          ~quantity:(D.Quantity.of_quanta n) ~key:None)
      p.changes
  in
  approve_effects t effects;
  ignore (get "invalid-plan-movement" (D.Movement.validate effects));
  let plans =
    if replace then List.map (fun (row : plan) -> if row.id = p.id then p else row) t.data.plans
    else t.data.plans @ [ p ]
  in
  { t.data with plans }

let cancel_candidate t ~id ~day =
  let selected = find_plan t id in
  require_open_plan selected;
  valid_date day;
  let plans =
    List.map
      (fun (p : plan) -> if p.id = id then { p with cancelled_on = Some day } else p)
      t.data.plans
  in
  { t.data with plans }

(* Plans feed no balance answer, so the admitted image is reused unchanged. *)
let with_plans t data = check_plans data; { t with data }

let put_plan t ~replace p = protect (fun () -> with_plans t (plan_candidate t ~replace p))
let cancel_plan t ~id ~day = protect (fun () -> with_plans t (cancel_candidate t ~id ~day))

let put_entry_full t ~replace (e : entry) ~plan =
  protect (fun () ->
      approve_effects t e.effects;
      let exists = Entry_map.mem e.id t.data.entry_map in
      require (exists = replace) (if replace then "unknown-entry" else "duplicate-entry");
      if replace then (
        let old_e = Entry_map.find e.id t.data.entry_map in
        match old_e.merchant with
        | Some old_m ->
            require (e.merchant = Some old_m)
              "loam: Event Merchant is already classified; replacement is not qualified"
        | None -> ()
      );
      let entries =
        if replace then
          List.map (fun (row : entry) -> if row.id = e.id then e else row) (entries t)
        else (entries t) @ [ e ]
      in
      let plans =
        match plan with
        | None -> t.data.plans
        | Some id ->
            require (not replace) "cannot-attach-plan-on-edit";
            require_open_plan (find_plan t id);
            List.map
              (fun (p : plan) -> if p.id = id then { p with paid_by = Some e.id } else p)
              t.data.plans
      in
      let data =
        make_data ~measures:t.data.measures ~labels:t.data.labels
          ~approved:t.data.approved ~entries ~plans ~origins:t.data.origins
          ~openings:t.data.openings ~observations:t.data.observations
          ~presence:t.data.presence
          ~bounded:t.data.bounded
      in
      admit ~entries_cached:(lazy entries) data)

let check_effects_balanced effects =
  let rec fold acc = function
    | [] -> acc
    | p :: rest ->
        let q = D.Effect.quantity p in
        if D.Quantity.equal q D.Quantity.zero then raise (Refused "entry-admission");
        let m = mstr (D.Effect.measure p) in
        let cur = match List.assoc_opt m acc with None -> D.Quantity.zero | Some v -> v in
        fold ((m, D.Quantity.add cur q) :: List.remove_assoc m acc) rest
  in
  let totals = fold [] effects in
  List.iter
    (fun (_, net) ->
      if not (D.Quantity.equal net D.Quantity.zero) then
        raise (Refused "entry-admission"))
    totals

(* The local part of admission for one changed entry, in admission order:
   known Measures, Event construction, then the Actual stage's own refusals. *)
let admit_entry_locally t (e : entry) =
  let known = known_measure t.data in
  List.iter (fun p -> known (mstr (D.Effect.measure p))) e.effects;
  Option.iter (fun (m, _) -> known m) e.original_amount;
  let _ = get "invalid-entry" (D.Event.create ~id:(eid e.id) ~effects:e.effects) in
  check_effects_balanced e.effects;
  (try valid_date e.day with _ -> raise (Refused "entry-admission"));
  Option.iter (fun (_, q) -> require (Z.sign q > 0) "entry-admission") e.original_amount

let put_entry_incremental t (e : entry) ~plan =
  protect (fun () ->
      approve_effects t e.effects;
      require (not (Entry_map.mem e.id t.data.entry_map)) "duplicate-entry";
      let plans =
        match plan with
        | None -> t.data.plans
        | Some id ->
            require_open_plan (find_plan t id);
            List.map
              (fun (p : plan) -> if p.id = id then { p with paid_by = Some e.id } else p)
              t.data.plans
      in
      admit_entry_locally t e;
      let entries_rev = e :: t.data.entries_rev in
      let entry_map = Entry_map.add e.id e t.data.entry_map in
      let entry_count = t.data.entry_count + 1 in
      let data = { t.data with entries_rev; entry_map; entry_count; plans } in
      let image = Q.with_added_effects t.image e.effects in
      let entries_cached = lazy (List.rev data.entries_rev) in
      { data; image; entries_cached })

exception Needs_full_admission

(* A correction that keeps the entry outside every cross-entry relation (Reversal
   pair, Exchange evidence, opening witness, presence evidence) changes only its own
   facts and its Effects' contribution; anything else is re-admitted whole. *)
let put_entry_replace_incremental t (e : entry) =
  protect (fun () ->
      approve_effects t e.effects;
      let old_e =
        match Entry_map.find_opt e.id t.data.entry_map with
        | Some old_e -> old_e
        | None -> raise (Refused "unknown-entry")
      in
      (match old_e.merchant with
      | Some old_m ->
          require (e.merchant = Some old_m)
            "loam: Event Merchant is already classified; replacement is not qualified"
      | None -> ());
      if old_e.reversal_of <> None || e.reversal_of <> None || old_e.exchange <> None
         || e.exchange <> None || Entry_set.mem e.id t.data.reversal_targets
      then raise Needs_full_admission;
      admit_entry_locally t e;
      let image =
        match
          Q.with_replaced_effects t.image ~event:(eid e.id) ~old_effects:old_e.effects
            ~new_effects:e.effects
        with
        | Some image -> image
        | None -> raise Needs_full_admission
      in
      let entries_rev =
        List.map (fun (row : entry) -> if row.id = e.id then e else row) t.data.entries_rev
      in
      let data = { t.data with entries_rev; entry_map = Entry_map.add e.id e t.data.entry_map } in
      { data; image; entries_cached = lazy (List.rev entries_rev) })

let plain (e : entry) =
  e.reversal_of = None && e.exchange = None && e.original_amount = None && e.merchant = None

let put_entry t ~replace (e : entry) ~plan =
  if (not replace) && plain e then put_entry_incremental t e ~plan
  else if replace && plan = None then
    try put_entry_replace_incremental t e with Needs_full_admission -> put_entry_full t ~replace e ~plan
  else put_entry_full t ~replace e ~plan

let classify_with put t ~id ~disposition =
  protect (fun () ->
      let e =
        match Entry_map.find_opt id t.data.entry_map with
        | Some e -> e
        | None -> raise (Refused "loam: Merchant classification requires an existing Event")
      in
      if e.merchant <> None then
        raise (Refused "loam: Event Merchant is already classified; replacement is not qualified");
      (match disposition with
      | A.Event_merchants.Merchant p ->
          let tok = D.Identifier.External_party.to_string p in
          require (valid_token tok)
            "loam: Merchant party token must be a non-empty single text field"
      | Nonmerchant -> ());
      let updated = { e with merchant = Some disposition } in
      get "classify-merchant" (put t ~replace:true updated ~plan:None))

let classify_merchant = classify_with put_entry

let add_locus_candidate t id =
  ignore (lid id);
  match t.data.approved with
  | None -> raise (Refused "locus-policy-not-supplied")
  | Some ids ->
      require (not (List.mem id ids)) "duplicate-locus";
      { t.data with approved = Some (ids @ [ id ]) }

let label_candidate t ~id ~label ?help () =
  ignore (lid id);
  Option.iter (fun ids -> require (List.mem id ids) "locus-not-approved") t.data.approved;
  let valid_str s =
    s <> "" && String.length s <= 80
    && String.for_all (fun c -> Char.code c >= 32 && Char.code c <> 127) s
  in
  let label = String.trim label in
  require (valid_str label) "invalid-label";
  let existing_help = match t.data.labels with
    | None -> None
    | Some rows ->
        match List.find_opt (fun (key, _, _) -> key = id) rows with
        | Some (_, _, h) -> Some h
        | None -> None
  in
  let resolved_help =
    match help with
    | Some h ->
        let trimmed = String.trim h in
        if trimmed = "" then Option.value ~default:label existing_help else trimmed
    | None -> Option.value ~default:label existing_help
  in
  require (valid_str resolved_help) "invalid-label";
  let next_rows =
    let new_row = (id, label, resolved_help) in
    match t.data.labels with
    | None -> [ new_row ]
    | Some rows ->
        if List.exists (fun (key, _, _) -> key = id) rows then
          List.map (fun (key, n, h) -> if key = id then new_row else (key, n, h)) rows
        else
          rows @ [ new_row ]
  in
  { t.data with labels = Some next_rows }


(* Vocabulary feeds no stored fact or balance answer. *)
let with_vocabulary t data = check_vocabulary data; { t with data }

let add_locus t id = protect (fun () -> with_vocabulary t (add_locus_candidate t id))

let set_locus_label t ~id ~label ?help () =
  protect (fun () -> with_vocabulary t (label_candidate t ~id ~label ?help ()))

module Full = struct
  let readmit data = admit ~entries_cached:(lazy (List.rev data.entries_rev)) data
  let put_entry = put_entry_full
  let put_plan t ~replace p = protect (fun () -> readmit (plan_candidate t ~replace p))
  let cancel_plan t ~id ~day = protect (fun () -> readmit (cancel_candidate t ~id ~day))
  let classify_merchant = classify_with put_entry_full
  let add_locus t id = protect (fun () -> readmit (add_locus_candidate t id))

  let set_locus_label t ~id ~label ?help () =
    protect (fun () -> readmit (label_candidate t ~id ~label ?help ()))
end

let observe_quantities t rows =
  protect (fun () ->
      require (rows <> []) "empty-observations";
      let assertions =
        List.map
          (fun (l, m, q) ->
            let c = coord l m in
            let known m = require (List.mem_assoc m t.data.measures) "measure-scale-not-supplied" in
            known m;
            Option.iter
              (fun approved -> require (List.mem l approved) "locus-not-approved")
              t.data.approved;
            let assertion : A.Current_quantity_projection.assertion =
              { coordinate = c; quantity = D.Quantity.of_quanta q }
            in
            assertion)
          rows
      in
      unique (List.map (fun (l, m, _) -> l ^ "\x00" ^ m) rows) "duplicate-coordinate";
      (* An incrementally extended image keeps its admission-time frontier; the
         reflected cut must cover every current entry or they count twice. *)
      let groups = Q.source_groups (admit ~entries_cached:t.entries_cached t.data).image in
      let frontier = A.Current_quantity_groups.source_frontier groups in
      let roots =
        List.map A.Correction_frontier.root_id (A.Correction_frontier.lineages frontier)
      in
      let incoming : A.Current_quantity_groups.group =
        { reflected_roots = roots; assertions }
      in
      let new_groups =
        match A.Current_quantity_groups.reobserve groups incoming with
        | Ok g -> g
        | Error (A.Current_quantity_groups.Invalid_cut _) -> raise (Refused "invalid-cut")
        | Error (A.Current_quantity_groups.Invalid_assertions _) -> raise (Refused "invalid-assertions")
        | Error (A.Current_quantity_groups.Repeated_coordinate _) -> raise (Refused "repeated-coordinate")
      in
      let new_obs = A.Current_quantity_groups.groups new_groups in
      let data = { t.data with observations = new_obs } in
      admit ~entries_cached:t.entries_cached data)
let has_zero_origin t ~locus ~measure =
  let coordinate = coord locus measure in
  List.exists
    (fun candidate -> D.Effect_coordinate.equal candidate coordinate)
    t.data.origins

let bounded_history_start t ~locus ~measure =
  let coordinate = coord locus measure in
  List.find_map
    (fun (candidate, day) ->
      if D.Effect_coordinate.equal candidate coordinate then Some day else None)
    t.data.bounded

let with_bounded_history t rows =
  protect (fun () ->
      let bounded = List.map (fun (l, m, day) -> (coord l m, day)) rows in
      admit ~entries_cached:t.entries_cached { t.data with bounded })

(* LOAM's two independent history routes, per coordinate: zero-origin sums
   forward; bounded support subtracts later Effects from the exact current
   anchor. Overlap is refused rather than given a precedence. *)
let pool_at_end_of_day t ~measure ~pool ~day =
  protect (fun () ->
      let next_start = day_number day + 1 in
      ignore (scale t measure);
      let selected_measure = mid measure in
      require
        (List.length (List.sort_uniq D.Effect_coordinate.compare pool) = List.length pool)
        "history-duplicate-coordinate";
      require
        (List.for_all
           (fun (c : D.Effect_coordinate.t) ->
             D.Identifier.Measure.equal c.measure selected_measure)
           pool)
        "history-pool-measure-mismatch";
      let entries = entries t in
      let sum c keep =
        List.fold_left
          (fun total (e : entry) ->
            if not (keep e.day) then total
            else
              List.fold_left
                (fun total eff ->
                  if
                    D.Identifier.Locus.equal (D.Effect.locus eff) c.D.Effect_coordinate.locus
                    && D.Identifier.Measure.equal (D.Effect.measure eff) c.measure
                  then Z.add total (D.Quantity.quanta (D.Effect.quantity eff))
                  else total)
                total e.effects)
          Z.zero entries
      in
      List.fold_left
        (fun total (c : D.Effect_coordinate.t) ->
          let label = lstr c.locus ^ ":" ^ measure in
          let zero = List.exists (D.Effect_coordinate.equal c) t.data.origins in
          let opening =
            List.exists
              (fun (o : Q.opening) -> D.Effect_coordinate.equal o.coordinate c)
              t.data.openings
          in
          match zero, bounded_history_start t ~locus:(lstr c.locus) ~measure with
          | true, Some _ -> raise (Refused ("history-support-conflict:" ^ label))
          | true, None -> Z.add total (sum c (fun d -> d <= day))
          | false, None -> raise (Refused ("history-support-missing:" ^ label))
          | false, Some first ->
              require (not opening) ("history-support-conflict:" ^ label);
              require (next_start >= day_number first)
                ("history-precedes-bounded-start:" ^ label);
              let current =
                match Q.query t.image c with
                | Ok (Q.Exact answer) -> (
                    match Q.premise answer with
                    | Q.Current_assertion _ -> D.Quantity.quanta (Q.quantity answer)
                    | Q.Zero_origin | Q.Opening _ ->
                        raise (Refused ("history-bounded-anchor-missing:" ^ label)))
                | Ok (Q.Known_present _) | Error (Q.Support_unknown _) ->
                    raise (Refused ("history-bounded-anchor-missing:" ^ label))
              in
              Z.add total (Z.sub current (sum c (fun d -> d > day))))
        Z.zero pool)
