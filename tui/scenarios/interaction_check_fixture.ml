(* Synthetic conformance checks for the English workspace controller. *)
module C = Daily_interaction_state
module H = Daily_interaction
module X = Daily_interaction_context
module R = Daily_interaction_view
module B = Bakhlo_sexp.Daily_book
module F = Daily_file
module W = Ui_workspace
module Cal = Daily_calendar
module M = Ui_commands
module S = Record_session
module Rev = Reversal_session
module Date = Date_correction_session
module Merchant = Merchant_session
module Act = Actual_workspace
module Cancel = Scheduled_cancellation_session
module Months = Scheduled_months
module Plans = Scheduled_screen
module Cont = Scheduled_continuation_session
module Sch = Scheduled_session
module Bulk = Scheduled_bulk_session
module Gen = Scheduled_generation_session
module P = Ui_preferences
module Att = Attention_data
module Roles = Locus_roles
module D = Bakhlo_domain
module Stl = Settlement_data
module Trend = Daily_pace_trend
module O = Daily_overlays
module Balances = Balances_screen

let balance_items (state : C.state) = Balances.items (X.balances_env state) state.screens.balances

module Pace = Daily_pace_screen

let pace_detail_viewport ~dimensions ~width_of (state : C.state) =
  Pace.detail_viewport (X.pace_env state) (X.screen_geometry ~dimensions ~width_of state) state.screens.pace

let resolve_pace_pool (state : C.state) = Pace.resolve_pool (X.pace_env state)
let resolve_pace_window (state : C.state) = Pace.resolve_window (X.pace_env state)
let current_pace_result (state : C.state) = Pace.current_pace (X.pace_env state)

let open_attentions (state : C.state) =
  match state.attention with Ok t -> Att.open_items t | Error _ -> []

let settlement_rows (state : C.state) =
  Settlements_screen.rows (X.screen_env ~config_files:[] state) state.screens.settlements

let stock_flow_result (state : C.state) =
  Stock_flow_screen.result (X.screen_env ~config_files:Stock_flow_screen.config_files state)
    state.screens.stock_flow

(* The Commands entry: the pool editor opens over the current route. *)
let open_pool_editor (state : C.state) =
  { state with screens = { state.screens with pace = Pace.open_pool (X.pace_env state) state.screens.pace } }

(* The modal form the user currently sees, whichever owner holds it; mirrors the
   view precedence so scenarios do not depend on where a form is stored. *)
let visible_form (state : C.state) =
  if Pace.modal state.screens.pace then Pace.form state.screens.pace
  else if Attention_screen.modal state.screens.attention then
    Attention_screen.form state.screens.attention
  else if Settlements_screen.modal state.screens.settlements then
    Settlements_screen.form state.screens.settlements
  else if Loci_screen.modal state.screens.loci then Loci_screen.form state.screens.loci
  else if Observe_screen.modal state.screens.observe then Observe_screen.form state.screens.observe
  else if Exchange_screen.modal state.screens.exchange then Exchange_screen.form state.screens.exchange
  else if Income_expense_screen.modal state.screens.income_expense then
    Income_expense_screen.form state.screens.income_expense
  else if Transactions_flow_screen.modal state.screens.transactions_flow then
    Transactions_flow_screen.form state.screens.transactions_flow
  else if Stock_flow_screen.modal state.screens.stock_flow then
    Stock_flow_screen.form state.screens.stock_flow
  else if Balances.modal state.screens.balances then Balances.form state.screens.balances
  else match state.overlay with C.Modal_form form -> Some form | _ -> None

let visible_form_id state = Option.map Ui_form.id (visible_form state)

(* Replace the visible form content, equivalent to typing into it. *)
let with_visible_form (state : C.state) form =
  if Pace.modal state.screens.pace then { state with screens = { state.screens with pace = Pace.with_form form state.screens.pace } }
  else if Attention_screen.modal state.screens.attention then
    { state with screens = { state.screens with
      attention = Attention_screen.with_form form state.screens.attention } }
  else if Loci_screen.modal state.screens.loci then
    { state with screens = { state.screens with loci = Loci_screen.with_form form state.screens.loci } }
  else if Observe_screen.modal state.screens.observe then
    { state with screens = { state.screens with observe = Observe_screen.with_form form state.screens.observe } }
  else if Exchange_screen.modal state.screens.exchange then
    { state with screens = { state.screens with exchange = Exchange_screen.with_form form state.screens.exchange } }
  else if Settlements_screen.modal state.screens.settlements then
    { state with screens = { state.screens with
      settlements = Settlements_screen.with_form form state.screens.settlements } }
  else match state.overlay with
    | C.Modal_form _ -> { state with overlay = C.Modal_form form }
    | _ -> raise (F.Refused "no-visible-form")

let b2_overlay_open (state : C.state) =
  (match state.C.overlay with
   | C.No_overlay ->
       Option.is_some (Screen_registry.modal state.screens)
   | _ -> true)


(* Regular private copy of the synthetic examples/daily-book.sexp, made by the
   check runner: Dune may provide the original as a symlink, which the writer
   correctly refuses. *)
let example_book = "scratch/examples/daily-book.sexp"

let materialize_example_book () =
  let bytes = In_channel.with_open_bin "examples/daily-book.sexp" In_channel.input_all in
  if not (Sys.file_exists "scratch/examples") then Unix.mkdir "scratch/examples" 0o700;
  if Sys.file_exists example_book then Unix.unlink example_book;
  F.write_new example_book bytes

(* The open record editor session, whichever route it floats over. *)
module E = Record_editors

let session_of (state : C.state) = E.active state.screens.editors

let with_session (state : C.state) session =
  { state with screens = { state.screens with editors = E.open_session session state.screens.editors } }

(* Nothing modal is open: neither a Shell overlay nor any owner's editor. *)
let no_modal (state : C.state) =
  state.overlay = C.No_overlay && Option.is_none (Screen_registry.modal state.screens)

let is_reversal state = match session_of state with Some (E.Reversal _) -> true | _ -> false
let is_plan_create state = match session_of state with Some (E.Scheduled_create _) -> true | _ -> false

(* The Scheduled owner, read through its own interface. *)
let plans (state : C.state) = Plans.synced state.session.book state.screens.scheduled
let plan_rows (state : C.state) = Plans.rows state.session.book state.screens.scheduled
let plan_browser state = Plans.browser (plans state)
let plan_id state = (plan_browser state).selected_id
let plan_row state = (plan_browser state).selected
let plan_detail state = Plans.detail_focused (plans state)
let plan_scroll state = Plans.scroll (plans state)
let plan_months state = Plans.months (plans state)
let plan_list (state : C.state) = Plans.list_browser state.screens.scheduled
let plan_months_view state = Plans.months_view (plans state)
let plan_window ~dimensions ~width_of (state : C.state) =
  Plans.detail_window (X.screen_env ~config_files:[] state) (X.screen_geometry ~dimensions ~width_of state) state.screens.scheduled
let with_plan_query (state : C.state) query =
  { state with screens = { state.screens with scheduled = Plans.with_query state.session.book state.screens.scheduled query } }

(* The Shell's record-action openers, targeted at what the route owner selects. *)
let selected_target (state : C.state) =
  match state.workspace.route with
  | W.Actual -> Option.map (fun e -> W.Actual_entry e) (Act.selected_entry ~book:state.session.book state.screens.actual)
  | W.Scheduled -> Option.map (fun p -> W.Scheduled_plan p) (Plans.selected_plan state.session.book state.screens.scheduled)
  | _ -> C.selected state
let pay_selected s = C.pay_target s (selected_target s)
let batch_plan_selected s = C.batch_plan_target s (selected_target s)
let extend_plan_selected s = C.extend_plan_target s (selected_target s)
let reverse_entry_selected s = C.reverse_entry_target s (selected_target s)

(* The Actual owner, read through its own interface. *)
let actual_dims ~dimensions ~width_of (state : C.state) =
  (X.screen_geometry ~dimensions ~width_of state).content
let actual_window ~dimensions ~width_of (state : C.state) =
  let content = actual_dims ~dimensions ~width_of state in
  (snd content, Act.detail_window ~book:state.session.book ~dimensions:content ~width_of state.screens.actual)
let actual_selected_id (state : C.state) =
  Option.map (fun (e : B.entry) -> e.id) (Act.selected_entry ~book:state.session.book state.screens.actual)
let actual_detail (state : C.state) = Act.pane state.screens.actual = Act.Details
let actual_scroll state = if actual_detail state then Act.detail_scroll state.C.screens.actual else 0
let actual_row (state : C.state) = Act.transaction_row state.screens.actual
let actual_query (state : C.state) = Act.search_query state.screens.actual
let actual_selected (state : C.state) =
  Option.map (fun e -> W.Actual_entry e) (Act.selected_entry ~book:state.session.book state.screens.actual)
let actual_rows (state : C.state) = Act.visible_entries ~book:state.session.book state.screens.actual

let require = F.require
let get = function Ok value -> value | Error cause -> raise (F.Refused cause)

let key ?(dimensions = (140, 40)) ?(width_of = String.length) state button =
  match H.handle ~dimensions ~width_of state (`Key (button, [])) with
  | Some state -> state
  | None -> raise (F.Refused "unexpected-controller-exit")

(* Daily Pace [w]: the What-If editor of the Daily Pace route. *)
let open_what_if ~width_of state = key ~width_of (C.open_route state W.Daily_pace) (`ASCII 'w')

let text ~width_of state value =
  Uutf.String.fold_utf_8
    (fun state _ -> function
      | `Uchar char -> key ~width_of state (`Uchar char)
      | `Malformed _ -> raise (F.Refused "malformed-test-input"))
    state value

let prepare_record ~width_of state =
  let state = key ~width_of state (`ASCII 'r') in
  let state = text ~width_of state "English UI / 日本語のメモ" in
  let state = key ~width_of (key ~width_of state `Tab) `Tab in
  let state = key ~width_of (text ~width_of state "wallet") `Enter in
  let state = key ~width_of (text ~width_of state "-37") `Tab in
  let state = key ~width_of (text ~width_of state "food") `Enter in
  text ~width_of state "+37"

(* Shared text predicate only; individual suites own their scenarios. *)
let contains rows needle =
  List.exists (fun (_, text) -> Base.String.is_substring text ~substring:needle) rows
