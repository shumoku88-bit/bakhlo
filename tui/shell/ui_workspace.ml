module B = Bakhlo_sexp.Daily_book
module A = Daily_draft

type route = Screen.route =
  | Home | Calendar | Selected_day of string | Actual | Scheduled | Balances | Daily_pace
  | Attention | Loci | Settlements | Income_expense | Transactions_flow | Stock_flow
type pane = Calendar | Detail
module RB = Record_browser

type family = RB.family = Actual_row | Scheduled_row
type row = RB.row = Actual_entry of B.entry | Scheduled_plan of B.plan
type order = RB.order = Newest | Oldest

type browser = RB.t = {
  selected : int;
  selected_id : (family * string) option;
  query : string;
  locus : string option;
  day : string option;
  order : order;
}

type t = {
  route : route;
  calendar : Daily_calendar.t;
  pane : pane;
  detail : browser;
  measure : string;
}

let empty = RB.empty

let create ~today ~measure =
  match Daily_calendar.create today with
  | Error _ as error -> error
  | Ok calendar ->
      Ok { route = Home; calendar; pane = Calendar; detail = empty; measure }

let identity = RB.identity
let date = RB.date
let row_matches = RB.matches
let all_rows = RB.all_rows

let browser state =
  match state.route with
  | Home | Calendar | Selected_day _ | Actual | Scheduled | Balances | Daily_pace | Attention | Loci | Settlements
  | Income_expense | Transactions_flow | Stock_flow -> state.detail

let update_browser state browser =
  match state.route with
  | Home | Calendar | Selected_day _ | Actual | Scheduled | Balances | Daily_pace | Attention | Loci | Settlements
  | Income_expense | Transactions_flow | Stock_flow -> { state with detail = browser }

let sorted = RB.sorted

let home_rows ~book state =
  all_rows book
  |> List.filter (fun row -> Daily_calendar.period_contains state.calendar (date row))
  |> sorted state.detail.order

let rows ~book state =
  let browser = browser state in
  let candidates =
    match state.route with
    | Calendar -> home_rows ~book state
    | Home | Selected_day _ | Actual | Scheduled | Balances | Daily_pace | Attention | Loci | Settlements | Income_expense | Transactions_flow | Stock_flow -> []
  in
  candidates |> List.filter (row_matches ~book browser) |> sorted browser.order

let sync ~book state = update_browser state (RB.sync (browser state) (rows ~book state))

let selected_row ~book state = List.nth_opt (rows ~book state) (browser state).selected

let move_selection ~book state delta =
  update_browser state (RB.move (browser state) (rows ~book state) delta)

let enter state route = { state with route; pane = Calendar }

let back state =
  if state.pane = Detail then { state with pane = Calendar }
  else { state with route = Home; pane = Calendar }

let has_parent state = state.route <> Home || state.pane = Detail

let cycle_order state = update_browser state (RB.cycle_order (browser state))
let set_query state query = update_browser state (RB.with_query (browser state) query)
let set_locus state locus = update_browser state (RB.with_locus (browser state) locus)

let toggle_day_filter state =
  update_browser state (RB.toggle_day (browser state) ~focus_day:state.calendar.selected_day)
