(* Controller state, navigation and publication-result transitions. *)
(* English-first workspace controller. UI state never owns accounting facts. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module F = Daily_file
module A = Daily_actions
module O = Daily_overlays
module P = Ui_preferences
module W = Ui_workspace
module Cal = Daily_calendar
module M = Ui_commands
module S = Record_session
module Rev = Reversal_session
module Date = Date_correction_session
module Merchant = Merchant_session
module Sch = Scheduled_session
module Cancel = Scheduled_cancellation_session
module Act = Actual_workspace
module Months = Scheduled_months
module Cont = Scheduled_continuation_session
module Bulk = Scheduled_bulk_session
module Gen = Scheduled_generation_session
module Form = Ui_form
module Panel = Ui_panel
module Att = Attention_data
module Roles = Locus_roles
module Stl = Settlement_data
module BalView = Balance_view_data
module Balances = Balances_screen
module Pace = Daily_pace_screen

let tr = Ui_text.tr
let get = A.get
let get_id = A.get_id

type input = Ui_input.input

type style = O.style =
  | Plain
  | Active
  | Heading
  | Status
  | Chrome
  | Frame
  | Focused_frame
  | Calendar_dates
  | Bonsai
  | Entrance
  | Panel
  | Panel_heading
  | Panel_active
  | Columns of int * style * style
  | Input of int


type overlay =
  | No_overlay
  | Commands of M.t
  | Themes of { selected : int; original : P.theme; return_menu : M.t }
  | Jump of string
  | Search of string
  | Modal_form of Form.t



type state = {
  session : F.t;
  workspace : W.t;
  record : S.t option;
  record_visible : bool;
  overlay : overlay;
  theme : P.theme;
  message : string;
  ui_notice : string option;
  blocked : bool;
  pending : A.uncertain_evidence option;
  config_home : string option;
  scroll : int;
  paste_blocked : bool;
  attention_path : string;
  attention : (Att.t, string) result;
  settlement_path : string;
  settlements : (Stl.t, string) result;
  screens : Screen_registry.t;
  drill_parent : W.route option;
  drill_book : B.t option;
}

let initial ?config_home session =
  let measure = match B.measures session.F.book with (id, _) :: _ -> id | [] -> "" in
  let today = F.today () in
  let focus_day =
    match session.F.annual_year with
    | None -> today
    | Some year ->
        let prefix = Printf.sprintf "%04d-" year in
        if String.starts_with ~prefix today then today else prefix ^ "01-01"
  in
  let workspace = get (W.create ~today:focus_day ~measure) in
  let notice = A.recovery_notice ~session in
  let attention_path = Attention_file.file_path ?config_home session.F.path in
  let attention = Attention_file.load_file attention_path in
  let settlement_path = Settlement_file.file_path ?config_home session.F.path in
  let settlements = Settlement_file.load_file settlement_path in
  {
    session;
    workspace;
    record = None;
    record_visible = false;
    overlay = No_overlay;
    theme = P.load_theme ?config_home ();
    message = Option.value ~default:"" notice;
    ui_notice = None;
    blocked = notice <> None;
    pending = None;
    config_home;
    scroll = 0;
    paste_blocked = false;
    attention_path;
    attention;
    settlement_path;
    settlements;
    screens = Screen_registry.create ();
    drill_parent = None;
    drill_book = None;
  }

let open_editor state session =
  { state with screens = { state.screens with
      editors = Record_editors.open_session session state.screens.editors } }

let has_record_draft state =
  match state.record with None -> false | Some record -> S.has_draft record

let editor_visible state = state.record_visible
let mode state = match state.record with None -> A.New | Some record -> S.mode record

let sync state =
  let book = state.session.book in
  let workspace = W.sync ~book state.workspace |> W.follow_months_selection ~book in
  { state with workspace; scroll = 0 }

let finish_publication state session message =
  let next = sync { state with session; record = None; record_visible = false;
    overlay = No_overlay; pending = None; blocked = false; message = tr message;
    screens = Screen_registry.dismiss_floating state.screens } in
  let next =
    let screens, notice = Screen_registry.book_changed state.workspace.route
        ~before:state.session.book ~after:session.book next.screens in
    { next with screens; message = next.message ^ (if notice = "" then "" else "\n" ^ tr notice) }
  in
  match mode state with
  | A.Pay id -> (
      match List.find_opt (fun (p : B.plan) -> p.id = id && p.paid_by <> None) (B.plans session.book) with
      | Some source ->
          { (open_editor next (Record_editors.Scheduled_continuation
              (Cont.create ~book:session.book ~base_bytes:session.bytes source))) with
            message = next.message ^ " No additional Scheduled created." }
      | None -> { next with message = next.message ^
          " Next-plan inspection unavailable; no additional Scheduled created." })
  | _ -> next

let apply_commit_result ?published_message state ~draft result =
  let published session default_msg =
    let msg = match published_message with Some m -> m | None -> default_msg in
    finish_publication state session msg
  in
  let stopped ?(pending = draft.pending) message =
    { draft with blocked = true; pending; message }
  in
  match result with
  | A.Published session ->
      published session "Published and read back. Previous bytes are kept separately."
  | A.Idempotent_duplicate { session; _ } ->
      published session "Already published; no duplicate was applied."
  | A.Conflict_base_changed ->
      stopped ~pending:None
        (tr "The preview generation changed. Draft retained; reload and review.")
  | A.Conflict ->
      stopped ~pending:None
        (tr "Another writer changed the book. Draft retained; reload and review.")
  | A.Conflict_lsn { expected; actual } ->
      stopped ~pending:None
        (A.format_message "Append conflict: expected LSN %d, found %d. Draft retained." expected
           actual)
  | A.Payload_drift_refused why ->
      stopped
        (A.format_message "Same ID has a different payload (%s). Retry stopped; draft retained." why)
  | A.Recovery_blocked -> stopped A.recovery_message
  | A.Storage_failed why ->
      stopped (A.format_message "Storage failed (%s). Writes stopped; draft retained." why)
  | A.Refused why ->
      { draft with message = A.format_message "Publication refused (%s). Draft retained." why }
  | A.Uncertain { message; evidence } ->
      stopped ~pending:(Some evidence)
        (A.format_message
           "Publication outcome is unknown (%s). Do not retry; reload to inspect. Draft retained."
           message)

let reload state =
  let state = { state with
    attention = Attention_file.load_file state.attention_path;
    settlements = Settlement_file.load_file state.settlement_path;
  } in
  match A.reload ~session:state.session ~pending:state.pending ~mode:(mode state) with
  | A.Pending_confirmed session ->
      finish_publication state session "The pending publication is present now. No retry."
  | A.Pending_unconfirmed session ->
      {
        state with
        session;
        blocked = true;
        message = tr "Reloaded; the previous publication is still unconfirmed. No retry.";
      }
  | A.Edit_base_changed session ->
      {
        state with
        session;
        blocked = true;
        message =
          tr "The edited generation changed. Draft retained; discard explicitly and reselect.";
      }
  | A.Recovery_required (session, message) -> { state with session; blocked = true; message }
  | A.Reloaded session -> (
      match state.overlay with
      | _ -> sync { state with session; blocked = false; message = tr "Reloaded. Unsaved draft retained." })
  | A.Reload_failed why ->
      {
        state with
        blocked = true;
        message = A.format_message "Reload failed (%s). Existing book and draft retained." why;
      }

let submit state =
  if state.blocked then state
  else
    match state.record with
    | None -> state
    | Some record ->
        {
          state with
          record =
            Some
              (S.preview ~new_id:Daily_file.new_id ~book:state.session.book ~base_bytes:state.session.bytes
                 ~blocked:state.blocked record);
          record_visible = true;
        }

let discard state =
  match A.recovery_notice ~session:state.session with
  | Some message -> { state with blocked = true; message }
  | None when state.pending <> None ->
      {
        state with
        blocked = true;
        message = tr "Unconfirmed publication: inspect before discarding or retrying.";
      }
  | None ->
      {
        state with
        record = None;
        record_visible = false;
        blocked = false;
        message = tr "Draft discarded explicitly.";
      }

let request_discard state =
  if not (has_record_draft state) then state
  else
    let form = Form.create ~id:"discard_record" ~title:"Discard retained draft?"
      ~summary:["The retained draft will be lost.";
        "Saved entries and plans will not change."]
      ~fields:[Form.buttons_field ~id:"actions" ~buttons:[
        { Form.label = "Keep draft"; is_cancel = true };
        { Form.label = "Discard draft"; is_cancel = false }] ()] () in
    { state with overlay = Modal_form form }

let open_record state =
  if state.blocked then state
  else
    match state.record with
    | Some record when S.has_draft record && not (S.is_plan record) ->
        { state with record_visible = true; overlay = No_overlay }
    | Some record when S.has_draft record && S.is_plan record ->
        {
          state with
          message =
            tr "A Scheduled draft is retained. Resume or discard it before creating a Record.";
        }
    | _ ->
        let day = match state.workspace.route with
          | W.Selected_day day -> day
          | _ -> state.workspace.calendar.selected_day in
        {
          state with
          record =
            Some
              (S.create ~book:state.session.book ~day
                 ~measure:state.workspace.measure ());
          record_visible = true;
          overlay = No_overlay;
          message = "";
        }

let open_plan_record state =
  if state.blocked then state
  else if has_record_draft state then
    {
      state with
      message =
        tr "A draft is retained. Resume or discard it before creating a Scheduled occurrence.";
    }
  else
    let day =
      match state.workspace.route with
      | W.Selected_day d -> d
      | _ -> state.workspace.calendar.selected_day
    in
    let measure = state.workspace.measure in
    {
      state with
      screens = (open_editor state (Record_editors.Scheduled_create
        (Sch.create ~book:state.session.book ~day ~measure))).screens;
      record_visible = false;
      message = "";
    }

let annual_unavailable state = F.annual_unavailable state.session

let annual_needs_history = function
  | W.Balances | W.Daily_pace | W.Stock_flow | W.Income_expense
  | W.Transactions_flow -> true
  | W.Home | W.Calendar | W.Selected_day _ | W.Actual | W.Scheduled
  | W.Attention | W.Loci | W.Settlements -> false

let open_route state route =
  if annual_needs_history route && annual_unavailable state <> None then
    { state with overlay = No_overlay;
      message = Option.value ~default:"Annual opening evidence unavailable." (annual_unavailable state) }
  else
  sync { state with workspace = W.enter state.workspace route; overlay = No_overlay; scroll = 0;
                    drill_parent = None; drill_book = None;
                    screens = Screen_registry.enter route ~focus_day:state.workspace.calendar.selected_day state.screens }

let selected state = W.selected_row ~book:state.session.book state.workspace

let edit_target state target =
  if state.blocked then state
  else if has_record_draft state then
    {
      state with
      message = tr "A draft is retained. Resume or discard it before editing.";
    }
  else
    match target with
    | Some (W.Actual_entry entry) -> (
        match S.of_edit ~book:state.session.book entry with
        | Ok record -> { state with record = Some record; record_visible = true; message = "" }
        | Error why -> { state with message = why })
    | Some (W.Scheduled_plan plan) -> (
        match S.of_edit_plan ~book:state.session.book plan with
        | Ok record -> { state with record = Some record; record_visible = true; message = "" }
        | Error why -> { state with message = why })
    | None -> { state with message = tr "Select an Actual or Scheduled occurrence to edit." }

let correct_date_target state target =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before changing a date." }
  else match target with
  | Some (W.Actual_entry entry) ->
      { (open_editor state (Record_editors.Date_correction (Date.create ~base_bytes:state.session.bytes entry)))
        with message = "" }
  | _ -> { state with message = tr "Select an Actual entry to change its date." }


let cancel_plan_target state target =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before cancelling a Scheduled occurrence." }
  else
    match target with
    | Some (W.Scheduled_plan plan) ->
        if plan.paid_by <> None then
          { state with message = tr "This Scheduled occurrence is already completed." }
        else if plan.cancelled_on <> None then
          { state with message = tr "This Scheduled occurrence is already cancelled." }
        else
          {
            state with
            screens = (open_editor state (Record_editors.Scheduled_cancel (Cancel.create
              ~book:state.session.book ~base_bytes:state.session.bytes ~day:(F.today ()) plan))).screens;
            message = "";
          }
    | _ -> { state with message = tr "Select an open Scheduled occurrence to cancel." }

let batch_plan_target state target =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before batch editing." }
  else match target with
  | Some (W.Scheduled_plan plan) -> (
      match Bulk.create ~book:state.session.book ~base_bytes:state.session.bytes ~from_day:plan.day plan with
      | Ok editor -> { (open_editor state (Record_editors.Scheduled_bulk editor)) with message = "" }
      | Error message -> { state with message })
  | _ -> { state with message = tr "Select an open Scheduled occurrence for batch amount editing." }

let extend_plan_target state target =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before generating plans." }
  else match target with
  | Some (W.Scheduled_plan plan) -> (
      match Gen.create ~book:state.session.book ~base_bytes:state.session.bytes ~source:plan with
      | Ok editor -> { (open_editor state (Record_editors.Scheduled_generate editor)) with message = "" }
      | Error message -> { state with message })
  | _ -> { state with message = tr "Select an open Scheduled occurrence to generate." }

let reverse_entry_target state target =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before reversing." }
  else
    match target with
    | Some (W.Actual_entry entry) ->
        if entry.reversal_of <> None then
          { state with message = tr "This entry is already a Reversal; it cannot be reversed." }
        else if List.exists (fun (e : B.entry) -> e.reversal_of = Some entry.id) (B.entries state.session.book) then
          { state with message = tr "This entry has already been reversed." }
        else
          {
            state with
            screens = (open_editor state (Record_editors.Reversal (Rev.create ~book:state.session.book
              ~base_bytes:state.session.bytes ~day:(F.today ()) entry))).screens;
            message = "";
          }
    | _ -> { state with message = tr "Select an Actual entry to reverse." }
let classify_merchant_target state target =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before classifying." }
  else
    match target with
    | Some (W.Actual_entry entry) -> (
        match entry.merchant with
        | Some disposition ->
            let disp_text =
              match disposition with
              | Bakhlo_application.Event_merchants.Nonmerchant -> "Nonmerchant"
              | Merchant p -> "Merchant " ^ D.Identifier.External_party.to_string p
            in
            { state with message = "Merchant already classified: " ^ disp_text ^ "." }
        | None ->
            {
              state with
              screens = (open_editor state (Record_editors.Event_merchant
                (Merchant.create ~base_bytes:state.session.bytes entry))).screens;
              message = "";
            })
    | _ -> { state with message = tr "Select an Actual entry to classify Merchant." }


let pay_target state target =
  if state.blocked then state
  else if has_record_draft state then
    {
      state with
      message = tr "A draft is retained. Resume or discard it before completing Scheduled.";
    }
  else
    match target with
    | Some (W.Scheduled_plan plan) -> (
        match S.of_plan ~day:(F.today ()) ~book:state.session.book plan with
        | Ok record -> { state with record = Some record; record_visible = true; message = "" }
        | Error why -> { state with message = why })
    | Some (W.Actual_entry _) | None ->
        { state with message = tr "Select a Scheduled occurrence to complete." }


(* Routes still browsed by the central controller act on their selected row. *)
let edit_selected state = edit_target state (selected state)
let correct_date_selected state = correct_date_target state (selected state)
let cancel_plan_selected state = cancel_plan_target state (selected state)
let batch_plan_selected state = batch_plan_target state (selected state)
let extend_plan_selected state = extend_plan_target state (selected state)
let reverse_entry_selected state = reverse_entry_target state (selected state)
let classify_merchant_selected state = classify_merchant_target state (selected state)
let pay_selected state = pay_target state (selected state)
