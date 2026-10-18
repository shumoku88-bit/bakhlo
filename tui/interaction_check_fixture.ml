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
module Balances = Balances_owner

let balance_items (state : C.state) =
  Balances.items
    ~book:state.C.session.book
    ~measure:state.workspace.measure
    ~roles:(X.accounting_roles state)
    ~balance_view_text:(X.read_pace_config state "balance-view.tsv")
    state.balances_owner

module Daily_pace = Daily_pace_owner

let pace_detail_viewport ~dimensions ~width_of (state : C.state) =
  Daily_pace.detail_viewport ~dimensions ~width_of
    ~book:state.C.session.book ~measure:state.workspace.measure
    ~daily_pace_tsv:(X.read_pace_config state "daily-pace.tsv")
    ~boundary_presets_tsv:(X.read_pace_config state "boundary-presets.tsv")
    ~annual_bounds:(match X.annual_history_bounds state with Ok opt -> opt | Error _ -> None)
    ~today:(F.today ())
    state.daily_pace_owner

let resolve_pace_pool (state : C.state) =
  Daily_pace.resolve_pace_pool ~measure:state.workspace.measure
    (X.read_pace_config state "daily-pace.tsv")

let resolve_pace_window (state : C.state) =
  Daily_pace.resolve_pace_window ~today:(F.today ())
    (X.read_pace_config state "boundary-presets.tsv")

let current_pace_result (state : C.state) =
  Daily_pace.current_pace
    ~book:state.C.session.book
    ~measure:state.workspace.measure
    ~daily_pace_tsv:(X.read_pace_config state "daily-pace.tsv")
    ~boundary_presets_tsv:(X.read_pace_config state "boundary-presets.tsv")
    ~annual_bounds:(match X.annual_history_bounds state with Ok opt -> opt | Error _ -> None)
    ~today:(F.today ())

let what_if_form ?amount ?result (state : C.state) =
  let _ = (amount, result) in
  Daily_pace.open_what_if
    ~book:state.C.session.book
    ~measure:state.workspace.measure
    ~daily_pace_tsv:(X.read_pace_config state "daily-pace.tsv")
    ~boundary_presets_tsv:(X.read_pace_config state "boundary-presets.tsv")
    ~annual_bounds:(match X.annual_history_bounds state with Ok opt -> opt | Error _ -> None)
    ~today:(F.today ())
    state.daily_pace_owner
  |> Daily_pace.active_form
  |> Option.get

let configure_pace_form (state : C.state) =
  Daily_pace.pool_editor_form
    ~measure:state.workspace.measure
    ~daily_pace_tsv:(X.read_pace_config state "daily-pace.tsv")
    ~boundary_presets_tsv:(X.read_pace_config state "boundary-presets.tsv")
    ~today:(F.today ())

let b2_overlay_open (state : C.state) =
  (match state.C.overlay with
   | C.No_overlay ->
       Balances.has_overlay state.balances_owner
       || Daily_pace.has_overlay state.daily_pace_owner
   | _ -> true)


let require = F.require
let get = function Ok value -> value | Error cause -> raise (F.Refused cause)

let key ?(dimensions = (140, 40)) ?(width_of = String.length) state button =
  match H.handle ~dimensions ~width_of state (`Key (button, [])) with
  | Some state -> state
  | None -> raise (F.Refused "unexpected-controller-exit")

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
