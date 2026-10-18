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
  else match state.overlay with
    | C.Modal_form _ -> { state with overlay = C.Modal_form form }
    | _ -> raise (F.Refused "no-visible-form")

let b2_overlay_open (state : C.state) =
  (match state.C.overlay with
   | C.No_overlay ->
       Balances.modal state.screens.balances || Pace.modal state.screens.pace
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
