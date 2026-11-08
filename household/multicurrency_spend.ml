(* Spending in every currency, never converted.

   A household that spends yen and dollars wants to see both without a rate that
   it never recorded. So each Measure keeps its own exact sum, and three families
   stay apart: ordinary EXPENSE (entries that are not exchanges), EXPENSE inside an
   exchange (a fee, say), and the original amounts the household noted on an
   entry (a card charge in yen for a 10.00 dollar purchase). An original amount
   counts only for a non-exchange entry with a positive EXPENSE effect; any other
   is kept as a witness with the reason it was not counted, so nothing is dropped
   or guessed. A Locus without a role is never classified. Pinned in test/reports
   ([MULTICURRENCY]). *)

module M = Map.Make (String)

type total = { measure : string; quanta : Z.t }

type exchange_occurrence = {
  event : string;
  date : string;
  description : string option;
  source : Book.posting;
  destination : Book.posting;
  extra_effects : Book.posting list;
}

type unresolved_effect = { event : string; date : string; posting : Book.posting }
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

let compare_entry (left : Book.entry) (right : Book.entry) =
  match String.compare left.day right.day with
  | 0 -> String.compare left.id right.id
  | order -> order

let effect_locus (posting : Book.posting) = posting.locus
let effect_measure (posting : Book.posting) = posting.measure

let selected_key key (posting : Book.posting) =
  match posting.key with None -> false | Some actual -> String.equal actual key

let exchange_of_entry (entry : Book.entry) =
  match entry.exchange with
  | None -> None
  | Some (source_key, destination_key) -> (
      match
        ( List.find_opt (selected_key source_key) entry.effects,
          List.find_opt (selected_key destination_key) entry.effects )
      with
      | Some source, Some destination ->
          Some
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
            }
      | _ ->
          (* Book names both legs of every admitted exchange (Book.entry_of_tx). *)
          invalid_arg ("Multicurrency_spend: exchange leg missing in " ^ entry.id))

let step ~role_map (acc : acc) (entry : Book.entry) =
  let occurrence = exchange_of_entry entry in
  begin
    let expense_effects =
      List.filter
        (fun (posting : Book.posting) ->
          M.find_opt (effect_locus posting) role_map = Some Book.T.Expense)
        entry.effects
    in
    let unresolved_nonzero =
      List.filter
        (fun posting ->
          M.find_opt (effect_locus posting) role_map = None && Z.sign posting.amount <> 0)
        entry.effects
    in
    let add_expenses totals =
      List.fold_left
        (fun totals posting -> add (effect_measure posting) posting.amount totals)
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
                  (fun (posting : Book.posting) -> Z.sign posting.amount > 0)
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
    original
  end

type refusal = Bad_start | Bad_end | Empty_window

let code = function
  | Bad_start -> "bad-start"
  | Bad_end -> "bad-end"
  | Empty_window -> "empty-window"

let message = function
  | Bad_start -> "Multicurrency Spend requires a real canonical Start date (YYYY-MM-DD)."
  | Bad_end -> "The exclusive End date must be a real YYYY-MM-DD calendar date."
  | Empty_window -> "The exclusive End date must be after the Start date."

let compute book ~start:start_day ~stop:end_exclusive =
  let roles = Book.roles book in
  if not (Day.is_valid start_day) then Error Bad_start
  else if not (Day.is_valid end_exclusive) then Error Bad_end
  else if start_day >= end_exclusive then Error Empty_window
  else
    let role_map =
      List.fold_left
        (fun map (locus, role) -> if M.mem locus map then map else M.add locus role map)
        M.empty roles
    in
    let entries =
      Book.entries book
      |> List.filter (fun (entry : Book.entry) ->
          entry.day >= start_day && entry.day < end_exclusive)
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
    let acc = List.fold_left (step ~role_map) empty entries in
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
