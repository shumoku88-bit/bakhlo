(* A corrected-entry book. Earlier input versions belong in separate backups.
   The existing Application owns quantities, reversal and exchange admission. *)
module D = Bakhlo_domain
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

type data = {
  measures : (string * int) list;
  labels : (string * string * string) list option;
  approved : string list option;
  entries_rev : entry list;
  entry_map : entry Entry_map.t;
  entry_count : int;
  plans : plan list;
  origins : D.Effect_coordinate.t list;
  openings : Q.opening list;
  observations : A.Current_quantity_groups.group list;
  presence : Q.presence option;
}

type t = {
  data : data;
  image : Q.t;
  entries_cached : entry list Lazy.t;
}

let make_data ~measures ~labels ~approved ~entries ~plans ~origins ~openings ~observations ~presence =
  let entry_count = List.length entries in
  let entries_rev = List.rev entries in
  let entry_map =
    List.fold_left (fun m (e : entry) -> Entry_map.add e.id e m) Entry_map.empty entries
  in
  {
    measures;
    labels;
    approved;
    entries_rev;
    entry_map;
    entry_count;
    plans;
    origins;
    openings;
    observations;
    presence;
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

let admit ?entries_cached data =
  unique (List.map fst data.measures) "duplicate-measure";
  List.iter
    (fun (m, n) ->
      ignore (mid m);
      require (n >= 0 && n <= 9) "invalid-scale")
    data.measures;
  let known m = require (List.mem_assoc m data.measures) "measure-scale-not-supplied" in
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
    data.approved;
  let entries =
    match entries_cached with
    | Some c -> Lazy.force c
    | None -> List.rev data.entries_rev
  in
  let events =
    List.map
      (fun (e : entry) ->
        List.iter (fun p -> known (mstr (D.Effect.measure p))) e.effects;
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
           reversals =
             List.filter_map
               (fun (e : entry) ->
                 Option.map
                   (fun target ->
                     ({ A.Actual_reversals.target = eid target; reversal = eid e.id }
                       : A.Actual_reversals.fact))
                   e.reversal_of)
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
    data.plans;
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

let decode_posting = function
  | X.List [ X.Atom "posting"; X.Atom l; X.Atom m; X.Atom n; k ] -> posting l m n (optional k)
  | X.Atom _ | X.List _ -> raise (Refused "invalid-posting")

let decode_entry version = function
  | X.List (X.Atom "entry" :: X.Atom id :: rows) ->
      fields
        (if version = "1" then [ "date"; "memo"; "postings"; "reversal-of" ]
         else [ "date"; "memo"; "postings"; "reversal-of"; "exchange" ])
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

let of_monolithic_string bytes =
  protect (fun () ->
      match get "syntax" (Parsexp.Many.parse_string bytes) with
      | X.List [ X.Atom "bakhlo-daily"; X.Atom version ] :: rows
        when version = "1" || version = "2" || version = "3" ->
          fields [ "scope"; "measures"; "labels"; "approved-loci"; "entries"; "plans"; "support" ] rows;
          require
            (List.map atom (field "scope" rows) = [ "corrected-entries"; "explicit-plans" ])
            "unsupported-scope";
          let support = field "support" rows in
          fields [ "zero-origin"; "openings"; "observations"; "presence" ] support;
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
          let data =
            make_data
              ~measures:
                (List.map
                   (function
                     | X.List [ X.Atom "measure"; X.Atom m; X.Atom n ] ->
                         let n = integer n in
                         require (Z.geq n Z.zero && Z.leq n (Z.of_int 9)) "invalid-scale";
                         (m, Z.to_int n)
                     | X.Atom _ | X.List _ -> raise (Refused "invalid-measure"))
                   (field "measures" rows))
              ~labels:
                (supplied
                   (function
                     | X.List [ X.Atom "label"; X.Atom id; X.Atom label; X.Atom help ] ->
                         (id, label, help)
                     | X.Atom _ | X.List _ -> raise (Refused "invalid-label"))
                   (field "labels" rows))
              ~approved:(supplied atom (field "approved-loci" rows))
              ~entries
              ~plans:(List.map (decode_plan version) (field "plans" rows))
              ~origins:(List.map decode_coord (field "zero-origin" support))
              ~openings:
                (List.map
                   (function
                     | X.List [ X.Atom l; X.Atom m; X.Atom e ] ->
                         ({ Q.coordinate = coord l m; opening_event = eid e } : Q.opening)
                     | X.Atom _ | X.List _ -> raise (Refused "invalid-opening"))
                   (field "openings" support))
              ~observations:
                (List.map
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
                   (field "observations" support))
              ~presence
          in
          admit ~entries_cached:(lazy entries) data
      | [] | _ :: _ -> raise (Refused "unsupported-book-header"))

let source_format_of_string bytes =
  let lines = String.split_on_char '\n' bytes in
  let non_comment =
    List.find_opt
      (fun s ->
        let t = String.trim s in
        t <> "" && not (String.starts_with ~prefix:";" t))
      lines
  in
  match non_comment with
  | None -> `Unknown
  | Some line -> (
      match Parsexp.Single.parse_string line with
      | Ok (X.List [ X.Atom "bakhlo-daily"; X.Atom v ]) -> `Monolithic v
      | Ok (X.List (X.Atom "frame" :: _)) -> `Records 1
      | _ -> (
          match Parsexp.Many.parse_string bytes with
          | Ok (X.List [ X.Atom "bakhlo-daily"; X.Atom v ] :: _) -> `Monolithic v
          | Ok (X.List (X.Atom "frame" :: _) :: _) -> `Records 1
          | _ -> `Unknown))

let of_records (rb : Records_book.t) =
  protect (fun () ->
      let h = Records_book.header rb in
      let approved =
        let init = match h.approved_loci with None -> [] | Some xs -> xs in
        let added = Records_book.added_loci rb in
        if init = [] && added = [] then h.approved_loci
        else Some (List.sort_uniq String.compare (init @ added))
      in
      let entries =
        List.map
          (fun (e : Records_book.entry) ->
            {
              id = e.id;
              day = e.day;
              memo = e.memo;
              effects = e.effects;
              reversal_of = e.reversal_of;
              exchange = e.exchange;
            })
          (Records_book.entries rb)
      in
      let plans =
        List.map
          (fun (p : Records_book.plan) ->
            {
              id = p.id;
              day = p.day;
              measure = p.measure;
              changes = p.changes;
              paid_by = p.paid_by;
              cancelled_on = p.cancelled_on;
            })
          (Records_book.plans rb)
      in
      let frame_obs =
        List.map
          (fun (o : Records_book.observation) ->
            {
              A.Current_quantity_groups.reflected_roots =
                List.map (fun r -> eid r) o.reflected_roots;
              assertions =
                List.map
                  (fun (l, m, q) ->
                    {
                      A.Current_quantity_projection.coordinate = coord l m;
                      quantity = D.Quantity.of_quanta q;
                    })
                  o.quantities;
            })
          (Records_book.observations rb)
      in
      let data =
        make_data
          ~measures:h.measures
          ~labels:h.labels
          ~approved
          ~entries
          ~plans
          ~origins:h.origins
          ~openings:h.openings
          ~observations:(h.observations @ frame_obs)
          ~presence:h.presence
      in
      admit ~entries_cached:(lazy entries) data)

let of_string bytes =
  match source_format_of_string bytes with
  | `Records _ -> (
      match Records_book.of_string bytes with
      | Ok rb -> of_records rb
      | Error err -> Error err)
  | `Monolithic _ | `Unknown -> of_monolithic_string bytes

let to_records ?(request_tokens = []) (t : t) : Records_book.t =
  let b = t.data in
  let header : Records_book.header =
    {
      version = 1;
      measures = b.measures;
      labels = b.labels;
      approved_loci = b.approved;
      origins = b.origins;
      openings = b.openings;
      observations = b.observations;
      presence = b.presence;
      opaque = [];
    }
  in
  let lsn = ref 1 in
  let frames = ref [] in
  let emit payload =
    let f = Records_book.encode_frame !lsn payload in
    incr lsn;
    frames := f :: !frames
  in
  List.iter
    (fun (p : plan) ->
      emit
        (Records_book.Plan
           {
             id = p.id;
             day = p.day;
             measure = p.measure;
             changes = p.changes;
             paid_by = p.paid_by;
             cancelled_on = p.cancelled_on;
             opaque = [];
           }))
    b.plans;
  List.iter
    (fun (e : entry) ->
      let tok =
        List.find_map
          (fun (token, eid) -> if eid = e.id then Some token else None)
          request_tokens
      in
      emit
        (Records_book.Entry
           {
             id = e.id;
             day = e.day;
             token = tok;
             memo = e.memo;
             effects = e.effects;
             reversal_of = e.reversal_of;
             exchange = e.exchange;
             opaque = [];
           }))
    (Lazy.force t.entries_cached);
  List.iter
    (fun (token, event_id) ->
      emit (Records_book.Origin { token; event_id; opaque = [] }))
    request_tokens;
  { header; frames = List.rev !frames }

let to_records_string ?request_tokens t =
  Records_book.to_string (to_records ?request_tokens t)


let a s = X.Atom s
let l xs = X.List xs
let f tag xs = l (a tag :: xs)
let opt = function None -> f "none" [] | Some s -> f "some" [ a s ]
let coordinate (c : D.Effect_coordinate.t) = l [ a (lstr c.locus); a (mstr c.measure) ]

let sexps t =
  let b = t.data in
  let supplied encode = function
    | None -> f "not-supplied" []
    | Some xs -> f "provided" (List.map encode xs)
  in
  [
    f "bakhlo-daily" [ a "3" ];
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
             ])
         (Lazy.force t.entries_cached));
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
      [
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
      ];
  ]

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
    | "keys" | "plans" | "plan" | "changes" | "paid-by" | "cancelled-on" | "support"
    | "zero-origin" | "openings" | "observations" | "observation" | "reflected"
    | "quantities" | "presence" | "coordinates" | "provided" | "not-supplied" | "none" | "some" ->
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
      end else if c3 = 0x8C then begin
        Buffer.add_char b ',';
        loop (i + 3)
      end else if c3 = 0x8E then begin
        Buffer.add_char b '.';
        loop (i + 3)
      end else begin
        Buffer.add_substring b text i 3;
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

let parse_amount t m text =
  protect (fun () ->
      let decimals = scale t m in
      let norm = normalize_amount_text text in
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

let put_plan t ~replace (p : plan) =
  protect (fun () ->
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
      admit ~entries_cached:t.entries_cached { t.data with plans })

let cancel_plan t ~id ~day =
  protect (fun () ->
      let selected = find_plan t id in
      require_open_plan selected;
      valid_date day;
      let plans =
        List.map
          (fun (p : plan) -> if p.id = id then { p with cancelled_on = Some day } else p)
          t.data.plans
      in
      admit ~entries_cached:t.entries_cached { t.data with plans })

let put_entry_full t ~replace (e : entry) ~plan =
  protect (fun () ->
      approve_effects t e.effects;
      let exists = Entry_map.mem e.id t.data.entry_map in
      require (exists = replace) (if replace then "unknown-entry" else "duplicate-entry");
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

let put_entry_incremental t (e : entry) ~plan =
  protect (fun () ->
      approve_effects t e.effects;
      require (not (Entry_map.mem e.id t.data.entry_map)) "duplicate-entry";
      let known m = require (List.mem_assoc m t.data.measures) "measure-scale-not-supplied" in
      List.iter (fun p -> known (mstr (D.Effect.measure p))) e.effects;
      check_effects_balanced e.effects;
      let _ = get "invalid-entry" (D.Event.create ~id:(eid e.id) ~effects:e.effects) in
      (try valid_date e.day with _ -> raise (Refused "entry-admission"));
      let plans =
        match plan with
        | None -> t.data.plans
        | Some id ->
            require_open_plan (find_plan t id);
            List.map
              (fun (p : plan) -> if p.id = id then { p with paid_by = Some e.id } else p)
              t.data.plans
      in
      let entries_rev = e :: t.data.entries_rev in
      let entry_map = Entry_map.add e.id e t.data.entry_map in
      let entry_count = t.data.entry_count + 1 in
      let data = { t.data with entries_rev; entry_map; entry_count; plans } in
      let image = Q.with_added_effects t.image e.effects in
      let entries_cached = lazy (List.rev data.entries_rev) in
      { data; image; entries_cached })

let put_entry t ~replace (e : entry) ~plan =
  if (not replace) && e.reversal_of = None && e.exchange = None then
    put_entry_incremental t e ~plan
  else
    put_entry_full t ~replace e ~plan

let add_locus t id =
  protect (fun () ->
      ignore (lid id);
      match t.data.approved with
      | None -> raise (Refused "locus-policy-not-supplied")
      | Some ids ->
          require (not (List.mem id ids)) "duplicate-locus";
          admit ~entries_cached:t.entries_cached { t.data with approved = Some (ids @ [ id ]) })
