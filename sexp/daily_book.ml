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

let integer s =
  let start = if String.length s > 0 && (s.[0] = '-' || s.[0] = '+') then 1 else 0 in
  require (String.length s > start) "invalid-integer";
  for n = start to String.length s - 1 do
    require (s.[n] >= '0' && s.[n] <= '9') "invalid-integer"
  done;
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
}

type data = {
  measures : (string * int) list;
  labels : (string * string * string) list option;
  approved : string list option;
  entries : entry list;
  plans : plan list;
  origins : D.Effect_coordinate.t list;
  openings : Q.opening list;
  observations : A.Current_quantity_groups.group list;
  presence : Q.presence option;
}

type t = { data : data; image : Q.t }

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

let valid_date day =
  let event = get "date-event" (D.Event.create ~id:(eid "date-check") ~effects:[]) in
  let events = get "date-memory" (D.Event_memory.of_events [ event ]) in
  ignore
    (get "invalid-date"
       (A.Actual_validity.create ~events
          ~facts:[ A.Actual_validity.Base { event = D.Event.id event; valid_on = day } ]
          ~corrections:[]))

let admit data =
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
  let events =
    List.map
      (fun (e : entry) ->
        List.iter (fun p -> known (mstr (D.Effect.measure p))) e.effects;
        get "invalid-entry" (D.Event.create ~id:(eid e.id) ~effects:e.effects))
      data.entries
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
               data.entries;
           descriptions =
             List.filter_map
               (fun (e : entry) ->
                 Option.map
                   (fun text ->
                     ({ A.Event_descriptions.event = eid e.id; text } : A.Event_descriptions.fact))
                   e.memo)
               data.entries;
           reversals =
             List.filter_map
               (fun (e : entry) ->
                 Option.map
                   (fun target ->
                     ({ A.Actual_reversals.target = eid target; reversal = eid e.id }
                       : A.Actual_reversals.fact))
                   e.reversal_of)
               data.entries;
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
               data.entries;
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
      Option.iter
        (fun id ->
          require (List.exists (fun (e : entry) -> e.id = id) data.entries) "unknown-plan-payment")
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
  {
    data;
    image =
      get "support-admission"
        (Q.create ~source ~zero_origins:data.origins ~openings:data.openings
           ~groups:data.observations ~presence:data.presence);
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

let decode_plan = function
  | X.List (X.Atom "plan" :: X.Atom id :: rows) ->
      fields [ "date"; "measure"; "changes"; "paid-by" ] rows;
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
      }
  | X.Atom _ | X.List _ -> raise (Refused "invalid-plan")

let decode_coord = function
  | X.List [ X.Atom l; X.Atom m ] -> coord l m
  | X.Atom _ | X.List _ -> raise (Refused "invalid-coordinate")

let supplied decode = function
  | [ X.List [ X.Atom "not-supplied" ] ] -> None
  | [ X.List (X.Atom "provided" :: xs) ] -> Some (List.map decode xs)
  | [] | _ :: _ -> raise (Refused "invalid-supply")

let of_string bytes =
  protect (fun () ->
      match get "syntax" (Parsexp.Many.parse_string bytes) with
      | X.List [ X.Atom "bakhlo-daily"; X.Atom version ] :: rows when version = "1" || version = "2"
        ->
          fields
            [ "scope"; "measures"; "labels"; "approved-loci"; "entries"; "plans"; "support" ]
            rows;
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
          admit
            {
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
              entries = List.map (decode_entry version) (field "entries" rows);
              plans = List.map decode_plan (field "plans" rows);
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
            }
      | [] | _ :: _ -> raise (Refused "unsupported-book-header"))

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
    f "bakhlo-daily" [ a "2" ];
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

let render x =
  let tags =
    [
      "bakhlo-daily";
      "scope";
      "measures";
      "measure";
      "labels";
      "label";
      "approved-loci";
      "entries";
      "entry";
      "date";
      "memo";
      "postings";
      "posting";
      "reversal-of";
      "exchange";
      "keys";
      "plans";
      "plan";
      "changes";
      "paid-by";
      "support";
      "zero-origin";
      "openings";
      "observations";
      "observation";
      "reflected";
      "quantities";
      "presence";
      "coordinates";
      "provided";
      "not-supplied";
      "none";
      "some";
    ]
  in
  let leaf s =
    if
      try
        ignore (integer s);
        true
      with Refused _ -> false
    then s
    else quote s
  in
  let rec flat = function
    | X.Atom s -> leaf s
    | X.List (X.Atom tag :: xs) when List.mem tag tags ->
        "(" ^ tag ^ (if xs = [] then "" else " " ^ String.concat " " (List.map flat xs)) ^ ")"
    | X.List xs -> "(" ^ String.concat " " (List.map flat xs) ^ ")"
  in
  let rec pretty indent x =
    match x with
    | X.List (X.Atom tag :: xs) when List.mem tag tags && String.length (flat x) + indent > 110 ->
        "(" ^ tag
        ^ String.concat ""
            (List.map
               (fun value -> "\n" ^ String.make (indent + 2) ' ' ^ pretty (indent + 2) value)
               xs)
        ^ ")"
    | X.Atom _ | X.List _ -> flat x
  in
  pretty 0 x

let to_string t =
  "; Corrected entries and explicit plans. No correction-version chains.\n"
  ^ String.concat "\n\n" (List.map render (sexps t))
  ^ "\n"

let entries t = t.data.entries
let plans t = t.data.plans
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

let parse_amount t m text =
  protect (fun () ->
      let decimals = scale t m in
      let digits s =
        require (s <> "" && String.for_all (fun c -> c >= '0' && c <= '9') s) "invalid-amount"
      in
      let n =
        match String.split_on_char '.' text with
        | [ whole ] ->
            digits whole;
            Z.mul (integer whole) (Z.pow (Z.of_int 10) decimals)
        | [ whole; fraction ] ->
            digits whole;
            digits fraction;
            require (decimals > 0 && String.length fraction <= decimals) "amount-precision";
            integer (whole ^ fraction ^ String.make (decimals - String.length fraction) '0')
        | [] | _ :: _ -> raise (Refused "invalid-amount")
      in
      require (Z.sign n > 0) "non-positive-amount";
      n)

let approve_effects t effects =
  match t.data.approved with
  | None -> raise (Refused "locus-policy-not-supplied")
  | Some ids ->
      List.iter
        (fun p -> require (List.mem (lstr (D.Effect.locus p)) ids) "locus-unapproved")
        effects

let put_entry t ~replace (e : entry) ~plan =
  protect (fun () ->
      approve_effects t e.effects;
      let exists = List.exists (fun (row : entry) -> row.id = e.id) t.data.entries in
      require (exists = replace) (if replace then "unknown-entry" else "duplicate-entry");
      let entries =
        if replace then
          List.map (fun (row : entry) -> if row.id = e.id then e else row) t.data.entries
        else t.data.entries @ [ e ]
      in
      let plans =
        match plan with
        | None -> t.data.plans
        | Some id ->
            require (not replace) "cannot-attach-plan-on-edit";
            let selected = List.find_opt (fun (p : plan) -> p.id = id) t.data.plans in
            let p = match selected with Some p -> p | None -> raise (Refused "unknown-plan") in
            require (p.paid_by = None) "plan-already-paid";
            List.map
              (fun (p : plan) -> if p.id = id then { p with paid_by = Some e.id } else p)
              t.data.plans
      in
      admit { t.data with entries; plans })

let add_locus t id =
  protect (fun () ->
      ignore (lid id);
      match t.data.approved with
      | None -> raise (Refused "locus-policy-not-supplied")
      | Some ids ->
          require (not (List.mem id ids)) "duplicate-locus";
          admit { t.data with approved = Some (ids @ [ id ]) })
