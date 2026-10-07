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
  cancelled_on : string option;
}

type budget = {
  id : string;
  start_day : string;
  end_exclusive : string;
  measure : string;
  allocations : (string * Z.t) list;
  expense_loci : string list;
  actual_routes : (string * string option) list;
  plan_routes : (string * string * string option) list;
}

type data = {
  budgets : budget list option;
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
      require (p.paid_by = None || p.cancelled_on = None) "plan-paid-and-cancelled";
      Option.iter valid_date p.cancelled_on;
      Option.iter
        (fun id ->
          require (List.exists (fun (e : entry) -> e.id = id) data.entries) "unknown-plan-payment")
        p.paid_by)
    data.plans;
  Option.iter
    (fun budgets ->
      unique (List.map (fun (b : budget) -> b.id) budgets) "duplicate-budget";
      List.iter
        (fun (b : budget) ->
          require (b.id <> "") "invalid-budget-id";
          valid_date b.start_day;
          valid_date b.end_exclusive;
          require (b.start_day < b.end_exclusive) "invalid-budget-period";
          known b.measure;
          unique (List.map fst b.allocations) "duplicate-budget-purpose";
          List.iter
            (fun (purpose, n) ->
              require (purpose <> "") "invalid-budget-purpose";
              require (Z.sign n >= 0) "negative-budget-allocation")
            b.allocations;
          unique b.expense_loci "duplicate-budget-locus";
          List.iter (fun loc -> ignore (lid loc)) b.expense_loci;
          let route locus purpose =
            require (List.mem locus b.expense_loci) "untracked-budget-locus";
            Option.iter
              (fun p -> require (List.mem_assoc p b.allocations) "unknown-budget-purpose")
              purpose
          in
          unique (List.map fst b.actual_routes) "duplicate-budget-actual-route";
          List.iter (fun (loc, purpose) -> route loc purpose) b.actual_routes;
          let keys = List.map (fun (id, loc, _) -> (id, loc)) b.plan_routes in
          require
            (List.length (List.sort_uniq Stdlib.compare keys) = List.length keys)
            "duplicate-budget-plan-route";
          List.iter
            (fun (id, loc, purpose) ->
              route loc purpose;
              let p =
                match List.find_opt (fun (p : plan) -> p.id = id) data.plans with
                | Some p -> p
                | None -> raise (Refused "unknown-budget-plan")
              in
              require (p.measure = b.measure) "budget-plan-measure-mismatch";
              require (List.mem_assoc loc p.changes) "budget-plan-locus-missing")
            b.plan_routes)
        budgets)
    data.budgets;
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

let decode_plan version = function
  | X.List (X.Atom "plan" :: X.Atom id :: rows) ->
      fields
        (if version = "3" || version = "4" then
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
          (if version = "3" || version = "4" then optional (one (field "cancelled-on" rows))
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

let decode_budget = function
  | X.List (X.Atom "budget" :: X.Atom id :: rows) ->
      fields
        [
          "start";
          "end-exclusive";
          "measure";
          "allocations";
          "expense-loci";
          "actual-routes";
          "plan-routes";
        ]
        rows;
      {
        id;
        start_day = atom (one (field "start" rows));
        end_exclusive = atom (one (field "end-exclusive" rows));
        measure = atom (one (field "measure" rows));
        allocations =
          List.map
            (function
              | X.List [ X.Atom p; X.Atom n ] -> (p, integer n)
              | X.Atom _ | X.List _ -> raise (Refused "invalid-budget-allocation"))
            (field "allocations" rows);
        expense_loci = List.map atom (field "expense-loci" rows);
        actual_routes =
          List.map
            (function
              | X.List [ X.Atom loc; target ] -> (loc, optional target)
              | X.Atom _ | X.List _ -> raise (Refused "invalid-budget-actual-route"))
            (field "actual-routes" rows);
        plan_routes =
          List.map
            (function
              | X.List [ X.Atom id; X.Atom loc; target ] -> (id, loc, optional target)
              | X.Atom _ | X.List _ -> raise (Refused "invalid-budget-plan-route"))
            (field "plan-routes" rows);
      }
  | X.Atom _ | X.List _ -> raise (Refused "invalid-budget")

let of_string bytes =
  protect (fun () ->
      match get "syntax" (Parsexp.Many.parse_string bytes) with
      | X.List [ X.Atom "bakhlo-daily"; X.Atom version ] :: rows
        when version = "1" || version = "2" || version = "3" || version = "4" ->
          fields
            ([ "scope"; "measures"; "labels"; "approved-loci"; "entries"; "plans"; "support" ]
            @ if version = "4" then [ "budgets" ] else [])
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
              budgets =
                (if version = "4" then supplied decode_budget (field "budgets" rows) else None);
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
    f "bakhlo-daily" [ a (match b.budgets with None -> "3" | Some _ -> "4") ];
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
  @
  match b.budgets with
  | None -> []
  | Some budgets ->
      [
        f "budgets"
          [
            f "provided"
              (List.map
                 (fun (budget : budget) ->
                   f "budget"
                     [
                       a budget.id;
                       f "start" [ a budget.start_day ];
                       f "end-exclusive" [ a budget.end_exclusive ];
                       f "measure" [ a budget.measure ];
                       f "allocations"
                         (List.map (fun (p, n) -> l [ a p; a (Z.to_string n) ]) budget.allocations);
                       f "expense-loci" (List.map a budget.expense_loci);
                       f "actual-routes"
                         (List.map (fun (loc, p) -> l [ a loc; opt p ]) budget.actual_routes);
                       f "plan-routes"
                         (List.map
                            (fun (id, loc, p) -> l [ a id; a loc; opt p ])
                            budget.plan_routes);
                     ])
                 budgets);
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
      "cancelled-on";
      "support";
      "budgets";
      "budget";
      "start";
      "end-exclusive";
      "allocations";
      "expense-loci";
      "actual-routes";
      "plan-routes";
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

let budgets t = t.data.budgets
let entries t = t.data.entries
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

let find_budget t id =
  match t.data.budgets with
  | None -> raise (Refused "budgets-not-supplied")
  | Some budgets -> (
      match List.find_opt (fun (b : budget) -> b.id = id) budgets with
      | Some b -> b
      | None -> raise (Refused "unknown-budget"))

let put_budget t ~replace (b : budget) =
  protect (fun () ->
      let budgets = match t.data.budgets with None -> [] | Some xs -> xs in
      let exists = List.exists (fun (row : budget) -> row.id = b.id) budgets in
      require (exists = replace) (if replace then "unknown-budget" else "duplicate-budget");
      let budgets =
        if replace then List.map (fun (row : budget) -> if row.id = b.id then b else row) budgets
        else budgets @ [ b ]
      in
      admit { t.data with budgets = Some budgets })

let rebalance_budget t ~id ~from_purpose ~to_purpose ~amount =
  protect (fun () ->
      let b = find_budget t id in
      require (from_purpose <> to_purpose) "same-budget-purpose";
      require (Z.sign amount > 0) "non-positive-budget-transfer";
      let allocation p =
        match List.assoc_opt p b.allocations with
        | Some n -> n
        | None -> raise (Refused "unknown-budget-purpose")
      in
      require (Z.geq (allocation from_purpose) amount) "insufficient-budget-allocation";
      ignore (allocation to_purpose);
      let allocations =
        List.map
          (fun (p, n) ->
            ( p,
              if p = from_purpose then Z.sub n amount
              else if p = to_purpose then Z.add n amount
              else n ))
          b.allocations
      in
      match put_budget t ~replace:true { b with allocations } with
      | Ok book -> book
      | Error why -> raise (Refused why))

type budget_item = { source_id : string; locus : string; quanta : Z.t }

type budget_row = {
  purpose : string;
  allocated : Z.t;
  actuals : budget_item list;
  plans : budget_item list;
  spent : Z.t;
  planned : Z.t;
  remaining : Z.t;
  after_known : Z.t;
}

type budget_review = {
  definition : budget;
  observed_at : string;
  rows : budget_row list;
  unrouted_actual : budget_item list;
  unmanaged_actual : budget_item list;
  unrouted_plans : budget_item list;
  unmanaged_plans : budget_item list;
}

let budget_review t ~id ~observed_at =
  protect (fun () ->
      let b = find_budget t id in
      valid_date observed_at;
      require
        (b.start_day <= observed_at && observed_at < b.end_exclusive)
        "budget-observation-outside-period";
      let tracked loc = List.mem loc b.expense_loci in
      let actual =
        t.data.entries
        |> List.filter (fun (e : entry) -> b.start_day <= e.day && e.day <= observed_at)
        |> List.concat_map (fun (e : entry) ->
            e.effects
            |> List.filter_map (fun p ->
                let loc = lstr (D.Effect.locus p) in
                if mstr (D.Effect.measure p) = b.measure && tracked loc then
                  Some
                    {
                      source_id = e.id;
                      locus = loc;
                      quanta = D.Quantity.quanta (D.Effect.quantity p);
                    }
                else None))
      in
      let planned =
        open_plans t
        |> List.filter (fun (p : plan) -> p.measure = b.measure && p.day < b.end_exclusive)
        |> List.concat_map (fun (p : plan) ->
            p.changes
            |> List.filter_map (fun (loc, n) ->
                if tracked loc then Some { source_id = p.id; locus = loc; quanta = n } else None))
      in
      let actual_route item = List.assoc_opt item.locus b.actual_routes in
      let plan_route item =
        match
          List.find_opt (fun (id, loc, _) -> id = item.source_id && loc = item.locus) b.plan_routes
        with
        | None -> None
        | Some (_, _, p) -> Some p
      in
      let routed route purpose = List.filter (fun item -> route item = Some (Some purpose)) in
      let sum items = List.fold_left (fun n item -> Z.add n item.quanta) Z.zero items in
      let pressure items =
        items
        |> List.map (fun item -> item.source_id)
        |> List.sort_uniq String.compare
        |> List.fold_left
             (fun n id ->
               let net = sum (List.filter (fun item -> item.source_id = id) items) in
               Z.add n (Z.max Z.zero net))
             Z.zero
      in
      let rows =
        List.map
          (fun (purpose, allocated) ->
            let actuals = routed actual_route purpose actual
            and plans = routed plan_route purpose planned in
            let spent = sum actuals and planned = pressure plans in
            let remaining = Z.sub allocated spent in
            {
              purpose;
              allocated;
              actuals;
              plans;
              spent;
              planned;
              remaining;
              after_known = Z.sub remaining planned;
            })
          b.allocations
      in
      {
        definition = b;
        observed_at;
        rows;
        unrouted_actual = List.filter (fun item -> actual_route item = None) actual;
        unmanaged_actual = List.filter (fun item -> actual_route item = Some None) actual;
        unrouted_plans = List.filter (fun item -> plan_route item = None) planned;
        unmanaged_plans = List.filter (fun item -> plan_route item = Some None) planned;
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
      admit { t.data with plans })

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
      admit { t.data with plans })

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
            require_open_plan (find_plan t id);
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
