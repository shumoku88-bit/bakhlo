module B = Bakhlo_sexp.Daily_book
module A = Daily_draft

type route = Home | Calendar | Selected_day of string | Actual | Scheduled | Balances | Daily_pace | Attention | Loci | Settlements | Income_expense | Transactions_flow | Stock_flow
type pane = Calendar | Detail
module RB = Record_browser

type family = RB.family = Actual_row | Scheduled_row
type row = RB.row = Actual_entry of B.entry | Scheduled_plan of B.plan
type order = RB.order = Newest | Oldest
type schedule_view = Months | List_view

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
  actual : browser;
  scheduled : browser;
  scheduled_months : browser;
  months : Scheduled_months.t;
  selected_day : browser;
  detail : browser;
  attention : browser;
  loci : browser;
  settlements : browser;
  schedule_view : schedule_view;
  measure : string;
}

let empty = RB.empty

let create ~today ~measure =
  match Daily_calendar.create today with
  | Error _ as error -> error
  | Ok calendar ->
      (match Scheduled_months.create ~today with
      | Error _ as error -> error
      | Ok months ->
          Ok
            {
              route = Home;
              calendar;
              pane = Calendar;
              actual = empty;
              scheduled = empty;
              scheduled_months = { empty with order = Oldest };
              months;
              selected_day = empty;
              detail = empty;
              attention = empty;
              loci = empty;
              settlements = empty;
              schedule_view = List_view;
              measure;
            })

let identity = RB.identity
let date = RB.date
let row_matches = RB.matches
let all_rows = RB.all_rows

let browser state =
  match state.route with
  | Actual -> state.actual
  | Scheduled ->
      (match state.schedule_view with
      | Months -> state.scheduled_months
      | List_view -> state.scheduled)
  | Selected_day _ -> state.selected_day
  | Attention -> state.attention
  | Loci -> state.loci
  | Settlements -> state.settlements
  | Home | Calendar | Balances | Daily_pace | Income_expense | Transactions_flow | Stock_flow -> state.detail

let update_browser state browser =
  match state.route with
  | Actual -> { state with actual = browser }
  | Scheduled ->
      (match state.schedule_view with
      | Months -> { state with scheduled_months = browser }
      | List_view -> { state with scheduled = browser })
  | Selected_day _ -> { state with selected_day = browser }
  | Attention -> { state with attention = browser }
  | Loci -> { state with loci = browser }
  | Settlements -> { state with settlements = browser }
  | Home | Calendar | Balances | Daily_pace | Income_expense | Transactions_flow | Stock_flow -> { state with detail = browser }

let sorted = RB.sorted

let home_rows ~book state =
  all_rows book
  |> List.filter (fun row -> Daily_calendar.period_contains state.calendar (date row))
  |> sorted state.detail.order

let rows ~book state =
  let browser = browser state in
  let candidates =
    match state.route with
    | Actual -> List.map (fun e -> Actual_entry e) (B.entries book)
    | Scheduled -> List.map (fun p -> Scheduled_plan p) (B.open_plans book)
    | Selected_day day -> all_rows book |> List.filter (fun row -> date row = day)
    | Calendar -> home_rows ~book state
    | Home | Balances | Daily_pace | Attention | Loci | Settlements | Income_expense | Transactions_flow | Stock_flow -> []
  in
  match state.route, state.schedule_view with
  | Scheduled, Months -> sorted Oldest candidates
  | _ -> candidates |> List.filter (row_matches ~book browser) |> sorted browser.order

let sync ~book state = update_browser state (RB.sync (browser state) (rows ~book state))

let selected_row ~book state = List.nth_opt (rows ~book state) (browser state).selected

let follow_months_selection ~book state =
  match state.route, state.schedule_view with
  | Scheduled, Months ->
      (match selected_row ~book state with
      | Some (Scheduled_plan plan) ->
          { state with months = Scheduled_months.follow state.months plan.B.day }
      | _ -> state)
  | _ -> state

let toggle_schedule_view ~book state =
  let scheduled = { state with route = Scheduled } in
  let selected_id = Option.map identity (selected_row ~book scheduled) in
  let destination =
    { scheduled with
      schedule_view = (match state.schedule_view with Months -> List_view | List_view -> Months) }
  in
  let destination =
    match selected_id with
    | Some id when List.exists (fun row -> identity row = id) (rows ~book destination) ->
        update_browser destination { (browser destination) with selected_id }
    | _ -> destination
  in
  let destination = follow_months_selection ~book (sync ~book destination) in
  { destination with route = state.route }

let move_selection ~book state delta =
  update_browser state (RB.move (browser state) (rows ~book state) delta)
  |> follow_months_selection ~book

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
