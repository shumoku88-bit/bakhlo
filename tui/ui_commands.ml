type page = Root | Transactions | Planning | Analysis | Setup
type action = Record | Actual | Scheduled | New_plan | Balances | Daily_pace | Theme | Home | Calendar | Attention | Manage_loci | Exchange | Settlements | Observe | Income_expense | Transactions_flow
type item = Group of page | Action of action
type t = { page : page; selected : int }
type outcome = Updated of t | Chosen of action | Closed

let initial = { page = Root; selected = 0 }

let items = function
  | Root ->
      [
        (Group Transactions, "Transactions →");
        (Group Planning, "Plans and attention →");
        (Group Analysis, "Reports and analysis →");
        (Group Setup, "Household setup →");
        (Action Theme, "Theme / Terminal or Bakhlo Light / Dark");
      ]
  | Transactions ->
      [
        (Action Record, "Record / new entry");
        (Action Calendar, "Calendar / Month flow");
        (Action Actual, "Actual / transactions");
        (Action Exchange, "Exchange / Currency conversion");
      ]
  | Planning ->
      [
        (Action Scheduled, "Scheduled / plans");
        (Action New_plan, "New Scheduled Plan");
        (Action Attention, "Attention / Household matters");
        (Action Settlements, "Settlements / Reimbursements");
      ]
  | Analysis ->
      [
        (Action Daily_pace, "Daily Pace");
        (Action Balances, "Balances / Current");
        (Action Income_expense, "Income & Expense / Cash flow report");
        (Action Transactions_flow, "Transactions Flow / Activity report");
        (Action Observe, "Observe Quantities / Verified balance");
      ]
  | Setup ->
      [
        (Action Theme, "Theme");
        (Action Manage_loci, "Manage Loci / Admitted vocabulary");
        (Action Home, "Home / Bonsai");
      ]

let title = function
  | Root -> "Commands"
  | Transactions -> "Commands / Transactions"
  | Planning -> "Commands / Plans and attention"
  | Analysis -> "Commands / Reports and analysis"
  | Setup -> "Commands / Household setup"

let move state delta =
  let count = List.length (items state.page) in
  { state with selected = max 0 (min (count - 1) (state.selected + delta)) }

let parent_index = function Root | Transactions -> 0 | Planning -> 1 | Analysis -> 2 | Setup -> 3

let back state =
  match state.page with
  | Root -> Closed
  | page -> Updated { page = Root; selected = parent_index page }

let open_group state =
  match List.nth_opt (items state.page) state.selected with
  | Some (Group page, _) -> { page; selected = 0 }
  | Some (Action _, _) | None -> state

let select state =
  match List.nth_opt (items state.page) state.selected with
  | Some (Group _, _) -> Updated (open_group state)
  | Some (Action action, _) -> Chosen action
  | None -> Updated state

let handle state (input : Ui_input.input) =
  match input with
  | `Key ((`Arrow `Up | `ASCII 'k'), []) -> Updated (move state (-1))
  | `Key ((`Arrow `Down | `ASCII 'j'), []) -> Updated (move state 1)
  | `Key (`Arrow `Right, []) -> Updated (open_group state)
  | `Key (`Enter, []) -> select state
  | `Key ((`Arrow `Left | `Escape | `ASCII 'q' | `ASCII ' '), []) -> back state
  | `Key (`Uchar c, []) when Uchar.to_int c = 32 -> back state
  | _ -> Updated state
