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


type observe_draft = {
  rows : (string * string * Z.t) list;
  base_bytes : string;
  pending : string * string * string;
  uncertain : bool;
}

type overlay =
  | No_overlay
  | Commands of M.t
  | Themes of { selected : int; original : P.theme; return_menu : M.t }
  | Jump of string
  | Search of string
  | Modal_form of Form.t
  | Reversal of Rev.t
  | Date_correction of Date.t
  | Event_merchant of Merchant.t
  | Scheduled_create of Sch.t
  | Scheduled_cancel of Cancel.t
  | Scheduled_continuation of Cont.t
  | Scheduled_bulk of Bulk.t
  | Scheduled_generate of Gen.t


let is_reverse_entry = function
  | Reversal _ -> true
  | _ -> false

let is_scheduled_create = function
  | Scheduled_create _ -> true
  | _ -> false

let is_add_attention = function
  | Modal_form f when Form.id f = "add_attention" -> true
  | _ -> false

let is_resolve_attention = function
  | Modal_form f when Form.id f = "resolve_attention" -> true
  | _ -> false

let is_drop_attention = function
  | Modal_form f when Form.id f = "drop_attention" -> true
  | _ -> false

let is_admit_locus = function
  | Modal_form f when Form.id f = "admit_locus" -> true
  | _ -> false

let is_set_locus_role = function
  | Modal_form f when Form.id f = "set_locus_role" -> true
  | _ -> false

let is_exchange = function
  | Modal_form f when Form.id f = "exchange" -> true
  | _ -> false

let is_add_settlement = function
  | Modal_form f when Form.id f = "add_settlement" -> true
  | _ -> false

let is_action_settlement = function
  | Modal_form f when Form.id f = "action_settlement" -> true
  | _ -> false

let is_observe_quantity = function
  | Modal_form f when Form.id f = "observe_quantity" -> true
  | _ -> false


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
  settlement_scope : Stl.scope;
  screens : Screen_registry.t;
  label_review : (Form.t * string * string * string) option;
  exchange_review : (Form.t * A.transaction * string) option;
  observe_draft : observe_draft option;
  actual_workspace : Act.t;
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
  let attention_path = Att.file_path ?config_home session.F.path in
  let attention = Att.load_file attention_path in
  let settlement_path = Stl.file_path ?config_home session.F.path in
  let settlements = Stl.load_file settlement_path in
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
    settlement_scope = Stl.Open_only;
    screens = Screen_registry.create ();
    label_review = None;
    exchange_review = None;
    observe_draft = None;
    actual_workspace = Act.create ~focus_date:focus_day;
    drill_parent = None;
    drill_book = None;
  }

let has_record_draft state =
  match state.record with None -> false | Some record -> S.has_draft record

let editor_visible state = state.record_visible
let mode state = match state.record with None -> A.New | Some record -> S.mode record

let sync state =
  let book = state.session.book in
  let workspace = W.sync ~book state.workspace |> W.follow_months_selection ~book in
  { state with workspace; scroll = 0 }

let sync_actual_to_workspace state =
  let entry_opt = Act.selected_entry ~book:state.session.book state.actual_workspace in
  let browser : W.browser =
    {
      selected = Act.transaction_row state.actual_workspace;
      selected_id = Option.map (fun (e : B.entry) -> (W.Actual_row, e.id)) entry_opt;
      day = (match Act.scope state.actual_workspace with Act.Focus_day -> Some (Act.focus_date state.actual_workspace) | Act.All_current -> None);
      order = (match Act.sort_order state.actual_workspace with Act.Asc -> W.Oldest | Act.Desc -> W.Newest);
      query = Act.search_query state.actual_workspace;
      locus = Act.selected_locus ~book:state.session.book state.actual_workspace;
    }
  in
  let pane = if Act.pane state.actual_workspace = Act.Details then W.Detail else W.Calendar in
  let scroll = if pane = W.Detail then Act.detail_scroll state.actual_workspace else 0 in
  { state with workspace = { state.workspace with actual = browser; pane }; scroll }

let finish_publication state session message =
  let next = sync { state with session; record = None; record_visible = false;
    overlay = No_overlay; pending = None; blocked = false; message = tr message } in
  let next =
    if state.workspace.route = W.Actual then
      let actual_workspace = Act.returned_from_detail
        ~before_book:state.session.book ~after_book:session.book state.actual_workspace in
      let notice = Act.notice actual_workspace in
      sync_actual_to_workspace { next with actual_workspace;
        message = next.message ^ (if notice = "" then "" else "\n" ^ tr notice) }
    else next
  in
  match mode state with
  | A.Pay id -> (
      match List.find_opt (fun (p : B.plan) -> p.id = id && p.paid_by <> None) (B.plans session.book) with
      | Some source ->
          { next with overlay = Scheduled_continuation
              (Cont.create ~book:session.book ~base_bytes:session.bytes source);
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
    attention = Att.load_file state.attention_path;
    settlements = Stl.load_file state.settlement_path;
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
      | Modal_form _ when Option.fold ~none:false ~some:(fun draft ->
            draft.uncertain || draft.base_bytes <> session.bytes) state.observe_draft ->
          { state with session; blocked = true;
            message = "Observation generation changed or save is uncertain. Cancel and inspect; do not retry." }
      | Reversal editor when Rev.base_bytes editor <> session.bytes ->
          { state with session; blocked = true;
            message = tr "Reversal target generation changed. Date retained; cancel, reload and reselect." }
      | Date_correction editor when Date.base_bytes editor <> session.bytes ->
          { state with session; blocked = true;
            message = tr "Date correction target generation changed. Cancel, reload and reselect." }
      | Event_merchant editor when Merchant.base_bytes editor <> session.bytes ->
          { state with session; blocked = true;
            message = tr "Merchant classification target generation changed. Draft retained; cancel, reload and reselect." }
      | Scheduled_cancel editor when Cancel.base_bytes editor <> session.bytes ->
          { state with session; blocked = true;
            message = tr "Scheduled cancellation target generation changed. Keep, reload and reselect." }
      | Scheduled_continuation prompt when Cont.base_bytes prompt <> session.bytes ->
          { state with session; blocked = true;
            message = tr "Completion remains published. Later-plan evidence changed; close and reload to inspect." }
      | Scheduled_bulk editor when Bulk.base_bytes editor <> session.bytes ->
          { state with session; blocked = true;
            message = tr "Batch target generation changed. Cancel, reload and reselect." }
      | Scheduled_generate editor when Gen.base_bytes editor <> session.bytes ->
          { state with session; blocked = true;
            message = tr "Generation target generation changed. Cancel, reload and reselect." }
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
      overlay = Scheduled_create (Sch.create ~book:state.session.book ~day ~measure);
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
  let state =
    if route = W.Actual then
      let focus_date = state.workspace.calendar.selected_day in
      let actual_workspace = Act.create ~focus_date in
      sync_actual_to_workspace { state with actual_workspace }
    else state
  in
  sync { state with workspace = W.enter state.workspace route; overlay = No_overlay; scroll = 0;
                    drill_parent = None; drill_book = None;
                    screens = Screen_registry.enter route state.screens }

let selected state =
  if state.workspace.route = W.Actual then
    Option.map (fun e -> W.Actual_entry e)
      (Act.selected_entry ~book:state.session.book state.actual_workspace)
  else W.selected_row ~book:state.session.book state.workspace

let edit_selected state =
  if state.blocked then state
  else if has_record_draft state then
    {
      state with
      message = tr "A draft is retained. Resume or discard it before editing.";
    }
  else
    match selected state with
    | Some (W.Actual_entry entry) -> (
        match S.of_edit ~book:state.session.book entry with
        | Ok record -> { state with record = Some record; record_visible = true; message = "" }
        | Error why -> { state with message = why })
    | Some (W.Scheduled_plan plan) -> (
        match S.of_edit_plan ~book:state.session.book plan with
        | Ok record -> { state with record = Some record; record_visible = true; message = "" }
        | Error why -> { state with message = why })
    | None -> { state with message = tr "Select an Actual or Scheduled occurrence to edit." }

let correct_date_selected state =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before changing a date." }
  else match selected state with
  | Some (W.Actual_entry entry) ->
      { state with overlay = Date_correction (Date.create ~base_bytes:state.session.bytes entry);
        message = "" }
  | _ -> { state with message = tr "Select an Actual entry to change its date." }


let cancel_plan_selected state =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before cancelling a Scheduled occurrence." }
  else
    match selected state with
    | Some (W.Scheduled_plan plan) ->
        if plan.paid_by <> None then
          { state with message = tr "This Scheduled occurrence is already completed." }
        else if plan.cancelled_on <> None then
          { state with message = tr "This Scheduled occurrence is already cancelled." }
        else
          {
            state with
            overlay = Scheduled_cancel (Cancel.create ~book:state.session.book
              ~base_bytes:state.session.bytes ~day:(F.today ()) plan);
            message = "";
          }
    | _ -> { state with message = tr "Select an open Scheduled occurrence to cancel." }

let batch_plan_selected state =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before batch editing." }
  else match selected state with
  | Some (W.Scheduled_plan plan) -> (
      match Bulk.create ~book:state.session.book ~base_bytes:state.session.bytes ~from_day:plan.day plan with
      | Ok editor -> { state with overlay = Scheduled_bulk editor; message = "" }
      | Error message -> { state with message })
  | _ -> { state with message = tr "Select an open Scheduled occurrence for batch amount editing." }

let extend_plan_selected state =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before generating plans." }
  else match selected state with
  | Some (W.Scheduled_plan plan) -> (
      match Gen.create ~book:state.session.book ~base_bytes:state.session.bytes ~source:plan with
      | Ok editor -> { state with overlay = Scheduled_generate editor; message = "" }
      | Error message -> { state with message })
  | _ -> { state with message = tr "Select an open Scheduled occurrence to generate." }

let reverse_entry_selected state =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before reversing." }
  else
    match selected state with
    | Some (W.Actual_entry entry) ->
        if entry.reversal_of <> None then
          { state with message = tr "This entry is already a Reversal; it cannot be reversed." }
        else if List.exists (fun (e : B.entry) -> e.reversal_of = Some entry.id) (B.entries state.session.book) then
          { state with message = tr "This entry has already been reversed." }
        else
          {
            state with
            overlay = Reversal (Rev.create ~book:state.session.book
              ~base_bytes:state.session.bytes ~day:(F.today ()) entry);
            message = "";
          }
    | _ -> { state with message = tr "Select an Actual entry to reverse." }
let classify_merchant_selected state =
  if state.blocked then state
  else if has_record_draft state then
    { state with message = tr "A draft is retained. Resume or discard it before classifying." }
  else
    match selected state with
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
              overlay = Event_merchant (Merchant.create ~base_bytes:state.session.bytes entry);
              message = "";
            })
    | _ -> { state with message = tr "Select an Actual entry to classify Merchant." }


let open_attentions state =
  match state.attention with Ok t -> Att.open_items t | Error _ -> []

let selected_attention state =
  let items = open_attentions state in
  let sel = state.workspace.attention.selected in
  List.nth_opt items sel

let move_attention state delta =
  let items = open_attentions state in
  let count = List.length items in
  if count = 0 then state
  else
    let current = state.workspace.attention.selected in
    let last = count - 1 in
    let selected = max 0 (min last (current + delta)) in
    { state with workspace = { state.workspace with attention = { state.workspace.attention with selected } } }

let add_attention_form ~today =
  Form.create
    ~id:"add_attention"
    ~title:"Add Attention"
    ~summary:["Record a household matter needing attention."]
    ~fields:[
      Form.text_field ~id:"context" ~label:"Context" ~placeholder:"Matter description" ();
      Form.choice_field ~id:"due_kind" ~label:"Due" ~options:["No due date"; "Due undetermined"; "Due on date"] ~selected:0 ();
      Form.text_field ~id:"due_date" ~label:"Due date" ~value:today ~placeholder:"YYYY-MM-DD" ();
      Form.action_buttons ~confirm:"Add Attention" ~cancel:"Cancel" ();
    ]
    ()

let resolve_attention_form ~today (item : Att.item) =
  let summary =
    [
      "Target: " ^ item.id;
      "Context: " ^ item.context;
      Att.due_label item.due;
    ]
  in
  Form.create
    ~id:"resolve_attention"
    ~payload:item.id
    ~title:"Resolve Attention"
    ~summary
    ~fields:[
      Form.action_buttons ~confirm:"Confirm Resolve" ~cancel:"Keep Open" ();
    ]
    ()

let drop_attention_form ~today (item : Att.item) =
  let summary =
    [
      "Target: " ^ item.id;
      "Context: " ^ item.context;
      Att.due_label item.due;
    ]
  in
  Form.create
    ~id:"drop_attention"
    ~payload:item.id
    ~title:"Drop Attention"
    ~summary
    ~fields:[
      Form.action_buttons ~confirm:"Confirm Drop" ~cancel:"Keep Open" ();
    ]
    ()

let pay_selected state =
  if state.blocked then state
  else if has_record_draft state then
    {
      state with
      message = tr "A draft is retained. Resume or discard it before completing Scheduled.";
    }
  else
    match selected state with
    | Some (W.Scheduled_plan plan) -> (
        match S.of_plan ~day:(F.today ()) ~book:state.session.book plan with
        | Ok record -> { state with record = Some record; record_visible = true; message = "" }
        | Error why -> { state with message = why })
    | Some (W.Actual_entry _) | None ->
        { state with message = tr "Select a Scheduled occurrence to complete." }

