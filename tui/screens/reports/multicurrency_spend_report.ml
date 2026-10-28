(* Multicurrency Spend: one explicit half-open Actual window kept as separate
   exact families. Current entry evidence is read directly; no FX rate,
   valuation, home currency or cross-Measure arithmetic is inferred. *)
module B = Bakhlo_household.Book
module O = Ui_render
module A = Draft
module D = Bakhlo_domain
module M = Map.Make (String)

type total = { measure : string; quanta : Z.t }

type exchange_occurrence = {
  event : string;
  date : string;
  description : string option;
  source : B.posting;
  destination : B.posting;
  extra_effects : B.posting list;
}

type unresolved_effect = { event : string; date : string; posting : B.posting }
type original_reason = Unresolved_roles | Exchange_event | No_positive_expense

type original_witness = {
  event : string;
  date : string;
  measure : string;
  quanta : Z.t;
  reason : original_reason;
}

type snapshot = {
  start_day : string;
  end_exclusive : string;
  ordinary_expense : total list;
  original_expense : total list;
  exchange_expense : total list;
  exchanges : exchange_occurrence list;
  unresolved_ordinary : unresolved_effect list;
  unresolved_exchange : unresolved_effect list;
  unresolved_original : original_witness list;
  uncounted_original : original_witness list;
}

type acc = {
  ordinary : Z.t M.t;
  exchange : Z.t M.t;
  original : Z.t M.t;
  exchanges : exchange_occurrence list; (* reversed *)
  unresolved_ordinary : unresolved_effect list; (* reversed *)
  unresolved_exchange : unresolved_effect list; (* reversed *)
  unresolved_original : original_witness list; (* reversed *)
  uncounted_original : original_witness list; (* reversed *)
}

let add measure quanta totals =
  M.update measure
    (function None -> Some quanta | Some current -> Some (Z.add current quanta))
    totals

let totals_of totals =
  M.bindings totals |> List.map (fun (measure, quanta) -> ({ measure; quanta } : total))

let compare_entry (left : B.entry) (right : B.entry) =
  match String.compare left.day right.day with
  | 0 -> String.compare left.id right.id
  | order -> order

let effect_locus (posting : B.posting) = posting.B.locus
let effect_measure (posting : B.posting) = posting.B.measure

let selected_key key (posting : B.posting) =
  match posting.B.key with None -> false | Some actual -> String.equal actual key

let exchange_of_entry (entry : B.entry) =
  match entry.exchange with
  | None -> Ok None
  | Some (source_key, destination_key) -> (
      match
        ( List.find_opt (selected_key source_key) entry.effects,
          List.find_opt (selected_key destination_key) entry.effects )
      with
      | Some source, Some destination ->
          Ok
            (Some
               {
                 event = entry.id;
                 date = entry.day;
                 description = entry.memo;
                 source;
                 destination;
                 extra_effects =
                   List.filter
                     (fun posting ->
                       (not (selected_key source_key posting))
                       && not (selected_key destination_key posting))
                     entry.effects;
               })
      | None, _ ->
          Error
            (Printf.sprintf
               "Exchange source Effect key %s is missing from retained entry %s; no partial \
                occurrence is used."
               source_key entry.id)
      | _, None ->
          Error
            (Printf.sprintf
               "Exchange destination Effect key %s is missing from retained entry %s; no partial \
                occurrence is used."
               destination_key entry.id))

let step ~role_map (acc : acc) (entry : B.entry) =
  match exchange_of_entry entry with
  | Error _ as error -> error
  | Ok occurrence ->
      let expense_effects =
        List.filter
          (fun (posting : B.posting) ->
            M.find_opt (effect_locus posting) role_map = Some Locus_roles.Expense)
          entry.effects
      in
      let unresolved_nonzero =
        List.filter
          (fun posting ->
            M.find_opt (effect_locus posting) role_map = None && Z.sign posting.B.amount <> 0)
          entry.effects
      in
      let add_expenses totals =
        List.fold_left
          (fun totals posting -> add (effect_measure posting) posting.B.amount totals)
          totals expense_effects
      in
      let unresolved effects =
        List.map (fun posting -> { event = entry.id; date = entry.day; posting }) effects
      in
      let classified =
        match occurrence with
        | Some occurrence ->
            {
              acc with
              exchange = add_expenses acc.exchange;
              exchanges = occurrence :: acc.exchanges;
              unresolved_exchange =
                List.rev_append (unresolved unresolved_nonzero) acc.unresolved_exchange;
            }
        | None ->
            {
              acc with
              ordinary = add_expenses acc.ordinary;
              unresolved_ordinary =
                List.rev_append (unresolved unresolved_nonzero) acc.unresolved_ordinary;
            }
      in
      let original =
        match entry.original_amount with
        | None -> classified
        | Some (measure, quanta) -> (
            let witness reason : original_witness =
              { event = entry.id; date = entry.day; measure; quanta; reason }
            in
            match occurrence with
            | Some _ ->
                {
                  classified with
                  uncounted_original = witness Exchange_event :: classified.uncounted_original;
                }
            | None -> (
                if
                  List.exists
                    (fun (posting : B.posting) -> Z.sign posting.B.amount > 0)
                    expense_effects
                then { classified with original = add measure quanta classified.original }
                else
                  match unresolved_nonzero with
                  | _ :: _ ->
                      {
                        classified with
                        unresolved_original =
                          witness Unresolved_roles :: classified.unresolved_original;
                      }
                  | [] ->
                      {
                        classified with
                        uncounted_original =
                          witness No_positive_expense :: classified.uncounted_original;
                      }))
      in
      Ok original

let rec run ~role_map acc = function
  | [] -> Ok acc
  | entry :: rest -> (
      match step ~role_map acc entry with
      | Error _ as error -> error
      | Ok acc -> run ~role_map acc rest)

let compute ~book ~roles ~start_day ~end_exclusive =
  if not (Day.is_valid start_day) then
    Error "Multicurrency Spend requires a real canonical Start date (YYYY-MM-DD)."
  else if not (Day.is_valid end_exclusive) then
    Error "The exclusive End date must be a real YYYY-MM-DD calendar date."
  else if start_day >= end_exclusive then
    Error "The exclusive End date must be after the Start date."
  else
    let role_map =
      List.fold_left
        (fun map (locus, role) -> if M.mem locus map then map else M.add locus role map)
        M.empty roles
    in
    let entries =
      B.entries book
      |> List.filter (fun (entry : B.entry) -> entry.day >= start_day && entry.day < end_exclusive)
      |> List.stable_sort compare_entry
    in
    let empty =
      {
        ordinary = M.empty;
        exchange = M.empty;
        original = M.empty;
        exchanges = [];
        unresolved_ordinary = [];
        unresolved_exchange = [];
        unresolved_original = [];
        uncounted_original = [];
      }
    in
    match run ~role_map empty entries with
    | Error _ as error -> error
    | Ok acc ->
        Ok
          {
            start_day;
            end_exclusive;
            ordinary_expense = totals_of acc.ordinary;
            original_expense = totals_of acc.original;
            exchange_expense = totals_of acc.exchange;
            exchanges = List.rev acc.exchanges;
            unresolved_ordinary = List.rev acc.unresolved_ordinary;
            unresolved_exchange = List.rev acc.unresolved_exchange;
            unresolved_original = List.rev acc.unresolved_original;
            uncounted_original = List.rev acc.uncounted_original;
          }

let amount book measure quanta = Book_display.format_money book measure quanta ^ " " ^ measure

let signed_amount book measure quanta =
  (if Z.sign quanta > 0 then "+" else "") ^ amount book measure quanta

let reason_text = function
  | Unresolved_roles -> "roles unresolved"
  | Exchange_event -> "exchange event"
  | No_positive_expense -> "no positive Expense Effect"

let effect_line book label (posting : B.posting) =
  let measure = effect_measure posting in
  let key = match posting.B.key with None -> "" | Some key -> "  key " ^ key in
  "  " ^ label ^ "  "
  ^ signed_amount book measure posting.B.amount
  ^ "  " ^ effect_locus posting ^ key

let render_lines ~book (snapshot : snapshot) =
  let total_lines heading empty_text rows =
    (O.Heading, heading)
    ::
    (match rows with
    | [] -> [ (O.Chrome, "  " ^ empty_text) ]
    | rows ->
        List.map (fun (row : total) -> (O.Plain, "  " ^ amount book row.measure row.quanta)) rows)
  in
  let occurrence_lines (occurrence : exchange_occurrence) =
    let description = match occurrence.description with None -> "" | Some text -> "  " ^ text in
    (O.Plain, occurrence.date ^ description ^ "  [" ^ occurrence.event ^ "]")
    :: (O.Plain, effect_line book "source" occurrence.source)
    :: (O.Plain, effect_line book "destination" occurrence.destination)
    ::
    (match occurrence.extra_effects with
    | [] -> []
    | extras ->
        (O.Chrome, "  extra Effects")
        :: List.map (fun posting -> (O.Plain, effect_line book "extra" posting)) extras)
  in
  let unresolved_lines heading rows =
    (O.Heading, Printf.sprintf "%s: %d" heading (List.length rows))
    :: List.map
         (fun (row : unresolved_effect) ->
           ( O.Plain,
             "? " ^ row.date ^ "  " ^ effect_locus row.posting ^ "  "
             ^ signed_amount book (effect_measure row.posting) row.posting.B.amount
             ^ "  [" ^ row.event ^ "]" ))
         rows
  in
  let witness_lines heading rows =
    (O.Heading, Printf.sprintf "%s: %d" heading (List.length rows))
    :: List.map
         (fun (row : original_witness) ->
           ( O.Plain,
             "? " ^ row.date ^ "  original "
             ^ amount book row.measure row.quanta
             ^ "  [" ^ row.event ^ "]  " ^ reason_text row.reason ))
         rows
  in
  [
    (O.Heading, "Multicurrency Spend");
    (O.Chrome, Printf.sprintf "Window [%s, %s)" snapshot.start_day snapshot.end_exclusive);
    ( O.Chrome,
      "Distinct Measures remain separate. No FX rate, valuation, or home currency is inferred." );
    (O.Chrome, "This is a read lens over existing evidence, not a Trip transaction type.");
    (O.Plain, "");
  ]
  @ total_lines "Ordinary accounting Expense" "No classified ordinary Expense in this window."
      snapshot.ordinary_expense
  @ [ (O.Plain, "") ]
  @ total_lines "Original presented Expense" "No qualified OriginalAmount evidence in this window."
      snapshot.original_expense
  @ [ (O.Plain, "") ]
  @ total_lines "Exchange-associated Expense" "No classified Expense attached to Exchange Events."
      snapshot.exchange_expense
  @ [ (O.Plain, ""); (O.Heading, "Exchange occurrences") ]
  @ (match snapshot.exchanges with
    | [] -> [ (O.Chrome, "  No qualified Exchange Event in this window.") ]
    | exchanges -> List.concat_map occurrence_lines exchanges)
  @ [ (O.Plain, "") ]
  @ unresolved_lines "Unresolved ordinary Effects" snapshot.unresolved_ordinary
  @ unresolved_lines "Unresolved exchange Effects" snapshot.unresolved_exchange
  @ witness_lines "Unresolved original amounts" snapshot.unresolved_original
  @ witness_lines "Non-counted original observations" snapshot.uncounted_original
  @ (if snapshot.unresolved_ordinary = [] && snapshot.unresolved_exchange = [] then []
     else
       [
         ( O.Status,
           "Unresolved role evidence exists: classified figures above are not a complete spending \
            total." );
       ])
  @ [
      (O.Chrome, "Exchange quantities are evidence of the exchange occurrence, not spending totals.");
      ( O.Chrome,
        "Original presented amounts remain observations; they are not converted into accounting \
         Measure." );
    ]
