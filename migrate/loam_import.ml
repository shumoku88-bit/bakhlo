module D = Bakhlo_domain
module A = Bakhlo_application
module Q = A.Current_quantity_query
module B = Bakhlo_sexp.Daily_book
module E = Bakhlo_loam_read.Envelope
module I = Bakhlo_loam_read.Input
module R = Bakhlo_loam_read.Read

type input = { household : string; measure_presentation : string; locus_catalog : string option }

exception Refused of string

let require p why = if not p then raise (Refused why)
let get why = function Ok x -> x | Error _ -> raise (Refused why)
let estr = D.Identifier.Event.to_string
let lstr = D.Identifier.Locus.to_string
let mstr = D.Identifier.Measure.to_string
let lid s = get "invalid-locus-identity" (D.Identifier.Locus.of_string s)
let mid s = get "invalid-measure-identity" (D.Identifier.Measure.of_string s)
let coord l m : D.Effect_coordinate.t = { locus = lid l; measure = mid m }

let unique values why =
  require (List.length (List.sort_uniq String.compare values) = List.length values) why

let token s =
  require
    (s <> "" && not (String.exists (function '\t' | '\n' | '\r' -> true | _ -> false) s))
    "invalid-source-token";
  s

let integer s =
  let start = if String.length s > 0 && (s.[0] = '-' || s.[0] = '+') then 1 else 0 in
  require (String.length s > start) "invalid-integer";
  for n = start to String.length s - 1 do
    require (s.[n] >= '0' && s.[n] <= '9') "invalid-integer"
  done;
  Z.of_string s

(* Every line ends in a newline; the first is the exact format header. *)
let rows header bytes =
  require (bytes <> "" && bytes.[String.length bytes - 1] = '\n') "missing-source-newline";
  match String.split_on_char '\n' (String.sub bytes 0 (String.length bytes - 1)) with
  | actual :: rows when actual = header -> rows
  | [] | _ :: _ -> raise (Refused "unsupported-source-header")

let section env name =
  Option.map
    (fun (s : E.section) -> s.body)
    (List.find_opt (fun (s : E.section) -> s.name = name) (E.sections env))

(* LOAM Scheduled lifecycle: occurrences, then completion, retirement and
   replacement memories. Retired and replaced plans stay in the LOAM record. *)
let scheduled body =
  let remaining = rows "LOAM-SCHEDULED-LIFECYCLE\t1" body in
  let take name input =
    match input with
    | begin_ :: tail when begin_ = "BEGIN\t" ^ name ->
        let rec loop rev = function
          | finish :: rest when finish = "END\t" ^ name -> (List.rev rev, rest)
          | row :: rest -> loop (row :: rev) rest
          | [] -> raise (Refused "incomplete-scheduled-section")
        in
        loop [] tail
    | [] | _ :: _ -> raise (Refused "missing-scheduled-section")
  in
  let occurrences, rest = take "Scheduled" remaining in
  let completions, rest = take "Completion" rest in
  let retirements, rest = take "Retirement" rest in
  let replacements, rest = take "Replacement" rest in
  require (rest = []) "extra-scheduled-payload";
  let frame header = function
    | actual :: data when actual = header -> data
    | [] | _ :: _ -> raise (Refused "unsupported-scheduled-inner-header")
  in
  let finish (p : B.plan) = { p with changes = List.rev p.changes } in
  let rec scan current rev = function
    | [] -> List.rev (match current with None -> rev | Some p -> finish p :: rev)
    | row :: rest -> (
        match String.split_on_char '\t' row with
        | [ "SCHEDULED"; identity; day; measure ] ->
            let rev = match current with None -> rev | Some p -> finish p :: rev in
            scan
              (Some
                 {
                   B.id = token identity;
                   day;
                   measure = token measure;
                   changes = [];
                   paid_by = None;
                   cancelled_on = None;
                 })
              rev rest
        | [ "CHANGE"; locus; n ] -> (
            match current with
            | None -> raise (Refused "misplaced-scheduled-change")
            | Some p ->
                scan (Some { p with changes = (token locus, integer n) :: p.changes }) rev rest)
        | _ -> raise (Refused "unsupported-scheduled-row"))
  in
  let plans = scan None [] (frame "LOAM-SCHEDULED-MEMORY\t1" occurrences) in
  unique (List.map (fun (p : B.plan) -> p.id) plans) "duplicate-source-plan";
  let pairs kind =
    List.map (fun row ->
        match String.split_on_char '\t' row with
        | [ k; s; e ] when k = kind -> (token s, token e)
        | _ -> raise (Refused ("invalid-" ^ String.lowercase_ascii kind)))
  in
  let completions = pairs "COMPLETION" (frame "LOAM-SCHEDULED-COMPLETION-MEMORY\t1" completions) in
  let retirements =
    List.map
      (fun row ->
        match String.split_on_char '\t' row with
        | [ "RETIREMENT"; s ] -> token s
        | _ -> raise (Refused "invalid-retirement"))
      (frame "LOAM-SCHEDULED-RETIREMENT-MEMORY\t1" retirements)
  in
  let replacements =
    pairs "REPLACEMENT" (frame "LOAM-SCHEDULED-REPLACEMENT-MEMORY\t1" replacements)
  in
  unique
    (List.map fst completions @ retirements @ List.map fst replacements)
    "conflicting-source-plan-terminal";
  unique (List.map snd completions) "duplicate-source-completion-actual";
  unique (List.map snd replacements) "duplicate-source-plan-successor";
  let known s = require (List.exists (fun (p : B.plan) -> p.id = s) plans) "unknown-source-plan" in
  List.iter (fun (s, _) -> known s) completions;
  List.iter known retirements;
  List.iter
    (fun (s, target) ->
      known s;
      known target)
    replacements;
  List.iter
    (fun (p : B.plan) ->
      let rec path visited s =
        require (not (List.mem s visited)) "cyclic-source-plans";
        match List.assoc_opt s replacements with
        | None -> ()
        | Some next -> path (s :: visited) next
      in
      path [] p.id)
    plans;
  (plans, completions, retirements, replacements)

let measures bytes =
  let rows =
    String.split_on_char '\n' bytes |> List.filter (fun row -> row <> "" && row.[0] <> '#')
  in
  let data =
    List.map
      (fun row ->
        match String.split_on_char '\t' row with
        | [ identity; text ] ->
            let n = integer text in
            require (Z.geq n Z.zero && Z.leq n (Z.of_int 9)) "invalid-source-scale";
            (token identity, Z.to_int n)
        | _ -> raise (Refused "invalid-source-measure-metadata"))
      rows
  in
  unique (List.map fst data) "duplicate-source-measure";
  data

let labels = function
  | None -> None
  | Some bytes ->
      let rows = String.split_on_char '\n' bytes in
      let rows = match List.rev rows with "" :: rest -> List.rev rest | _ -> rows in
      let data =
        List.map
          (fun row ->
            match String.split_on_char '\t' row with
            | [ identity; label; help ] ->
                require (label <> "" && help <> "") "invalid-source-label";
                (token identity, label, help)
            | _ -> raise (Refused "invalid-source-label-row"))
          rows
      in
      unique (List.map (fun (identity, _, _) -> identity) data) "duplicate-source-label";
      Some data

let approved env =
  Option.map
    (fun body ->
      let vocabulary =
        List.map
          (fun row ->
            match String.split_on_char '\t' row with
            | [ "LOCUS"; identity ] -> token identity
            | _ -> raise (Refused "invalid-source-vocabulary"))
          (rows "LOAM-LOCUS-ADMISSION-VOCABULARY\t1" body)
      in
      unique vocabulary "duplicate-source-vocabulary";
      vocabulary)
    (section env "LocusAdmission")

(* Explicit LOAM claims only; an absent section is no claim. *)
let bounded env =
  match section env "BoundedHistorySupport" with
  | None -> []
  | Some body ->
      List.map
        (fun row ->
          match String.split_on_char '\t' row with
          | [ "SUPPORT"; locus; measure; day ] -> (coord locus measure, day)
          | _ -> raise (Refused "invalid-bounded-history-row"))
        (rows "LOAM-BOUNDED-HISTORY-SUPPORT\t1" body)

let import input =
  let raw = input.household in
  let env = get "source-envelope" (E.of_string raw) in
  let unadmitted = get "source-profile-decoding" (I.decode env) in
  let old = get "source-admission" (R.of_string raw) in
  let oldq = R.quantity_image old in
  let source = Q.source oldq in
  require
    (unadmitted.source.relations = [] && unadmitted.source.discharges = [])
    "unsupported-settlement-relations";
  let lineages = A.Correction_frontier.lineages (A.Actual_source.frontier source) in
  let root row = estr (A.Correction_frontier.root_id row) in
  let terminal_map =
    List.map
      (fun row -> (estr (D.Event.id (A.Correction_frontier.terminal_event row)), root row))
      lineages
  in
  let all_map =
    List.concat_map
      (fun row ->
        (estr (D.Event.id (A.Correction_frontier.terminal_event row)), root row)
        :: List.map
             (fun (edge : D.Event_correction.t) -> (estr edge.target, root row))
             (A.Correction_frontier.correction_path row))
      lineages
  in
  let current_root identity =
    match List.assoc_opt identity terminal_map with
    | Some r -> r
    | None -> raise (Refused "cannot-compact-referenced-old-entry")
  in
  let any_root identity =
    match List.assoc_opt identity all_map with
    | Some r -> r
    | None -> raise (Refused "unknown-source-plan-payment")
  in
  let reversals =
    List.map
      (fun (r : A.Actual_reversals.fact) ->
        (current_root (estr r.reversal), current_root (estr r.target)))
      unadmitted.source.reversals
  in
  let merchants = A.Actual_source.merchants source
  and originals = A.Actual_source.original_amounts source
  and exchanges = A.Actual_source.exchanges source in
  let entries =
    List.map
      (fun row ->
        let event = A.Correction_frontier.terminal_event row in
        let terminal = D.Event.id event and identity = root row in
        let day =
          match A.Actual_validity.find_current (A.Actual_source.validity source) terminal with
          | Some fact -> A.Actual_validity.valid_on fact
          | None -> raise (Refused "missing-current-date")
        in
        ({
           id = identity;
           day;
           memo = A.Event_descriptions.find_text (A.Actual_source.descriptions source) terminal;
           effects = D.Event.effects event;
           reversal_of = List.assoc_opt identity reversals;
           (* LOAM attaches these to the current terminal; a superseded Event's
              facts are not inherited and stay in the LOAM record. *)
           merchant = A.Event_merchants.find_disposition merchants terminal;
           original_amount =
             Option.map
               (fun current ->
                 let fact = A.Original_amounts.retained_fact current in
                 (mstr fact.measure, D.Quantity.quanta fact.quantity))
               (A.Original_amounts.find_current originals terminal);
           exchange =
             Option.map
               (fun selection ->
                 let fact = A.Exchange_evidence.fact selection in
                 ( D.Identifier.Effect_key.to_string fact.source,
                   D.Identifier.Effect_key.to_string fact.destination ))
               (A.Exchange_evidence.find_by_event exchanges terminal);
         }
          : B.entry))
      lineages
  in
  (* Root-addressed amounts and exchanges always reach a terminal; a missing one
     would be a silent loss. *)
  require
    (List.length (List.filter (fun (e : B.entry) -> e.original_amount <> None) entries)
    = List.length (A.Original_amounts.facts originals))
    "original-amount-not-current";
  require
    (List.length (List.filter (fun (e : B.entry) -> e.exchange <> None) entries)
    = List.length (A.Exchange_evidence.facts exchanges))
    "exchange-not-current";
  let scheduled_body =
    match section env "Scheduled" with
    | Some b -> b
    | None -> raise (Refused "missing-required-section")
  in
  let retained, completions, retirements, replacements = scheduled scheduled_body in
  let plans =
    List.filter_map
      (fun (p : B.plan) ->
        if List.mem p.id retirements || List.mem_assoc p.id replacements then None
        else Some { p with paid_by = Option.map any_root (List.assoc_opt p.id completions) })
      retained
  in
  (* Even discarded or replaced completion endpoints must not be silently repaired. *)
  List.iter (fun (_, event) -> ignore (any_root event)) completions;
  let openings =
    List.map
      (fun (o : Q.opening) ->
        {
          o with
          opening_event =
            get "invalid-entry-identity"
              (D.Identifier.Event.of_string (current_root (estr o.opening_event)));
        })
      (Q.openings oldq)
  in
  let payload : B.payload =
    {
      measures = measures input.measure_presentation;
      labels = labels input.locus_catalog;
      approved = approved env;
      entries;
      plans;
      origins = Q.zero_origins oldq;
      openings;
      observations = A.Current_quantity_groups.groups (Q.source_groups oldq);
      presence = Q.presence oldq;
      bounded = bounded env;
    }
  in
  let book = get "book-admission" (B.of_payload payload) in
  let newq = B.image book in
  let same_premise a b =
    match (Q.premise a, Q.premise b) with
    | Q.Zero_origin, Q.Zero_origin
    | Q.Opening _, Q.Opening _
    | Q.Current_assertion _, Q.Current_assertion _ ->
        true
    | (Q.Zero_origin | Q.Opening _ | Q.Current_assertion _), _ -> false
  in
  let compare c =
    match (Q.query oldq c, Q.query newq c) with
    | Ok (Q.Exact a), Ok (Q.Exact b) ->
        require
          (D.Quantity.equal (Q.quantity a) (Q.quantity b) && same_premise a b)
          "quantity-or-premise-changed"
    | Ok (Q.Known_present _), Ok (Q.Known_present _) | Error _, Error _ -> ()
    | (Ok _ | Error _), _ -> raise (Refused "quantity-availability-changed")
  in
  let effect_coords =
    List.concat_map
      (fun event ->
        List.map
          (fun posting -> coord (lstr (D.Effect.locus posting)) (mstr (D.Effect.measure posting)))
          (D.Event.effects event))
      unadmitted.source.events
  in
  let support_coords =
    payload.origins
    @ List.map (fun (o : Q.opening) -> o.coordinate) payload.openings
    @ List.concat_map
        (fun (g : A.Current_quantity_groups.group) ->
          List.map (fun (a : A.Current_quantity_projection.assertion) -> a.coordinate) g.assertions)
        payload.observations
    @ match payload.presence with None -> [] | Some p -> p.coordinates
  in
  let plan_coords =
    List.concat_map
      (fun (p : B.plan) -> List.map (fun (l, _) -> coord l p.measure) p.changes)
      retained
  in
  let coordinates = effect_coords @ support_coords @ plan_coords in
  List.iter compare coordinates;
  let loci =
    List.sort_uniq String.compare
      (List.map (fun (c : D.Effect_coordinate.t) -> lstr c.locus) coordinates)
  in
  List.iter
    (fun locus -> List.iter (fun (measure, _) -> compare (coord locus measure)) payload.measures)
    loci;
  book

let book input = try Ok (import input) with Refused why -> Error why

let attention household =
  try
    let env = get "source-envelope" (E.of_string household) in
    Ok (section env "Attention")
  with Refused why -> Error why

(* The household AccountingRole section is already Bakhlo's accounting-roles.tsv. *)
let role_tokens = [ "ASSET"; "LIABILITY"; "EQUITY"; "INCOME"; "EXPENSE" ]

let accounting_roles household =
  try
    let env = get "source-envelope" (E.of_string household) in
    match section env "AccountingRole" with
    | None -> Error "accounting-role-authority-missing"
    | Some body ->
        let rows =
          match String.split_on_char '\n' body with
          | "LOAM-ACCOUNTING-ROLE-MAP\t1" :: rows -> rows
          | _ -> raise (Refused "unsupported-accounting-role-section")
        in
        let rows =
          match List.rev rows with
          | "" :: rows -> List.rev rows
          | _ -> raise (Refused "unsupported-accounting-role-section")
        in
        let seen = Hashtbl.create (List.length rows) in
        List.iter
          (fun row ->
            match String.split_on_char '\t' row with
            | [ "ROLE"; locus; role ] ->
                (* Bakhlo role readers trim Locus identities; refuse rather than trim. *)
                require
                  (locus <> ""
                  && String.trim locus = locus
                  && (not (String.contains locus '\r'))
                  && List.mem role role_tokens)
                  "invalid-accounting-role-row";
                require (not (Hashtbl.mem seen locus)) "duplicate-accounting-role-locus";
                Hashtbl.replace seen locus ()
            | _ -> raise (Refused "invalid-accounting-role-row"))
          rows;
        Ok body
  with Refused why -> Error why
