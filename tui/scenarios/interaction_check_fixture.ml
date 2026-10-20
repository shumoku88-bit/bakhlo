(* Synthetic conformance checks for the English workspace controller. *)
module C = Shell_state
module H = Shell_input
module X = Shell_dispatch
module R = Shell_view
module B = Bakhlo_sexp.Daily_book
module F = Daily_file
module W = Ui_workspace
module Cal = Daily_calendar
module M = Ui_commands
module L = Bakhlo_sexp.Book_log

(* The file revision once the store appends [ops] to [session]. *)
let expected_after (session : F.t) ops = F.revision_after session ops
module S = Record_session
module Rev = Reversal_session
module Date = Date_correction_session
module Merchant = Merchant_session
module Act = Actual_workspace
module Cancel = Scheduled_cancellation_session
module Months = Scheduled_months
module Plans = Scheduled_screen
module Day = Selected_day_screen
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

(* Selected Day, read through its owner. *)
let days (state : C.state) = state.screens.day
let day_rows (state : C.state) = Day.rows state.session.book state.screens.day
let day_browser state = Day.browser (days state)
let day_id state = (day_browser state).selected_id
let day_detail state = Day.detail_focused (days state)
let day_scroll state = Day.scroll (days state)
let day_selected (state : C.state) = Day.selected_row state.session.book state.screens.day
let with_day_browser (state : C.state) browser =
  { state with screens = { state.screens with day = Day.with_browser state.screens.day browser } }

(* Calendar/Home and legacy ambient navigation read through their owner. *)
module Calendar_home = Calendar_home_screen
let calendar_jump (s : C.state) value =
  { s with screens = { s.screens with calendar_home = Calendar_home.start_jump value s.screens.calendar_home } }
let calendar_search (s : C.state) value =
  { s with screens = { s.screens with calendar_home = Calendar_home.start_search ~value s.screens.calendar_home } }
let calendar_browser (s : C.state) = Calendar_home.browser s.screens.calendar_home
let calendar_detail (s : C.state) = Calendar_home.detail_focused s.screens.calendar_home
let calendar_scroll (s : C.state) = Calendar_home.scroll s.screens.calendar_home
let with_calendar_browser (s : C.state) browser =
  { s with screens = { s.screens with calendar_home = Calendar_home.with_browser s.screens.calendar_home browser } }

(* The old workspace record included both browsers and the central pane.
   Retention assertions must compare those semantic fields after ownership moves. *)
let same_workspace (a : C.state) (b : C.state) =
  a.workspace = b.workspace
  && Day.browser a.screens.day = Day.browser b.screens.day
  && Calendar_home.browser a.screens.calendar_home = Calendar_home.browser b.screens.calendar_home
  && (let pane s = match s.C.workspace.route with
      | W.Selected_day _ -> Day.detail_focused s.screens.day
      | _ -> Calendar_home.detail_focused s.screens.calendar_home in
      pane a = pane b)

(* The Shell's record-action openers, targeted at what the route owner selects. *)
let selected_target (state : C.state) =
  let target = function
    | Record_browser.Actual_entry e -> Screen.Entry e
    | Record_browser.Scheduled_plan p -> Screen.Plan p in
  match state.workspace.route with
  | W.Actual -> Option.map (fun e -> Screen.Entry e) (Act.selected_entry ~book:state.session.book state.screens.actual)
  | W.Scheduled -> Option.map (fun p -> Screen.Plan p) (Plans.selected_plan state.session.book state.screens.scheduled)
  | W.Selected_day _ -> Option.map target (day_selected state)
  | W.Calendar -> Option.map target (Calendar_home.selected_row ~book:state.session.book
      ~calendar:state.workspace.calendar state.screens.calendar_home)
  | _ -> None
let pay_selected s = Shell_record_actions.pay_target s (selected_target s)
let batch_plan_selected s = Shell_record_actions.batch_plan_target s (selected_target s)
let extend_plan_selected s = Shell_record_actions.extend_plan_target s (selected_target s)
let reverse_entry_selected s = Shell_record_actions.reverse_entry_target s (selected_target s)

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
  Option.map (fun e -> Record_browser.Actual_entry e) (Act.selected_entry ~book:state.session.book state.screens.actual)
let actual_rows (state : C.state) = Act.visible_entries ~book:state.session.book state.screens.actual

let require = F.require
let get = function Ok value -> value | Error cause -> raise (F.Refused cause)

let key ?(dimensions = (140, 40)) ?(width_of = String.length) state button =
  match H.handle ~dimensions ~width_of state (`Key (button, [])) with
  | Some state -> state
  | None -> raise (F.Refused "unexpected-controller-exit")

(* Daily Pace [c]: the spendable-pool picker is painted, not a form; read and
   drive it through its painted rows like a user would. *)
let pool_text ?(dimensions = (140, 40)) ?(width_of = String.length) state =
  Option.value ~default:[] (R.overlay_screen ~dimensions ~width_of state)
  |> List.map snd |> String.concat "\n"

let pool_reviewing ?dimensions ?width_of state =
  Base.String.is_substring (pool_text ?dimensions ?width_of state) ~substring:"Review: these balances"

let pool_toggle ?(dimensions = (140, 40)) ?(width_of = String.length) state locus =
  let rows = String.split_on_char '\n' (pool_text ~dimensions ~width_of state) in
  let index p = let rec go i = function [] -> None | r :: rest -> if p r then Some i else go (i + 1) rest in go 0 rows in
  match index (fun r -> Base.String.is_substring r ~substring:("] " ^ locus ^ " / ")),
        index (fun r -> String.starts_with ~prefix:"> " r) with
  | Some target, Some cursor ->
      let step = if target > cursor then `ASCII 'j' else `ASCII 'k' in
      let moved = List.fold_left (fun s _ -> key ~dimensions ~width_of s step) state
          (List.init (abs (target - cursor)) Fun.id) in
      key ~dimensions ~width_of moved (`ASCII ' ')
  | _ -> raise (F.Refused ("pool-candidate-not-painted-" ^ locus))

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

(* An open search takes every key but Ctrl-R: Ctrl-Q/N are ignored while
   typing; Ctrl-R reloads under the search, keeping its text, and Enter still
   applies it. [query] reads the owner's applied query. *)
let search_control_checks ~width_of ~path ~label ~query state value =
  let before = F.read path in
  let searching = text ~width_of (key ~width_of state (`ASCII '/')) value in
  require (not (no_modal searching)) (label ^ "-search-opens");
  let press c = match H.handle ~width_of searching (`Key (`ASCII c, [`Ctrl])) with
    | Some state -> state | None -> failwith (label ^ "-search-control-exited") in
  List.iter (fun c ->
    let s = press c in
    require (not (no_modal s) && s.message = searching.message && s.record = searching.record
             && s.overlay = searching.overlay && query s = query searching)
      (label ^ "-search-ignores-quit-discard")) ['q';'Q';'n';'N'];
  List.iter (fun c ->
    let s = press c in
    require (not (no_modal s) && s.message = C.tr "Reloaded. Unsaved draft retained."
             && s.record = searching.record && F.read path = before
             && query (key ~width_of s `Enter) = value)
      (label ^ "-search-ctrl-r-reloads-and-keeps-search")) ['r';'R']
