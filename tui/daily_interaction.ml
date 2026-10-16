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
module Sch = Scheduled_session
module Cancel = Scheduled_cancellation_session
module Act = Actual_workspace
module Months = Scheduled_months
module Cont = Scheduled_continuation_session
module Bulk = Scheduled_bulk_session
module Form = Ui_form
module Panel = Ui_panel
module Att = Attention_data
module Roles = Locus_roles
module Stl = Settlement_data
module BalView = Balance_view_data

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
  | Reversal of Rev.t
  | Date_correction of Date.t
  | Scheduled_create of Sch.t
  | Scheduled_cancel of Cancel.t
  | Scheduled_continuation of Cont.t
  | Scheduled_bulk of Bulk.t


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

let is_daily_pace_what_if = function
  | Modal_form f when Form.id f = "daily_pace_what_if" -> true
  | _ -> false

let is_configure_daily_pace = function
  | Modal_form f when Form.id f = "configure_daily_pace" -> true
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
  balance_mode : [ `Accounting | `Current ];
  actual_workspace : Act.t;
  drill_parent : W.route option;
  drill_book : B.t option;
}

let initial ?config_home session =
  let measure = match B.measures session.F.book with (id, _) :: _ -> id | [] -> "" in
  let workspace = get (W.create ~today:(F.today ()) ~measure) in
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
    balance_mode = `Accounting;
    actual_workspace = Act.create ~focus_date:(F.today ());
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

let finish_publication state session message =
  let next = sync { state with session; record = None; record_visible = false;
    overlay = No_overlay; pending = None; blocked = false; message = tr message } in
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

let apply_commit_result state ~draft result =
  let published session message = finish_publication state session message in
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
      | Reversal editor when Rev.base_bytes editor <> session.bytes ->
          { state with session; blocked = true;
            message = tr "Reversal target generation changed. Date retained; cancel, reload and reselect." }
      | Date_correction editor when Date.base_bytes editor <> session.bytes ->
          { state with session; blocked = true;
            message = tr "Date correction target generation changed. Cancel, reload and reselect." }
      | Scheduled_cancel editor when Cancel.base_bytes editor <> session.bytes ->
          { state with session; blocked = true;
            message = tr "Scheduled cancellation target generation changed. Keep, reload and reselect." }
      | Scheduled_continuation prompt when Cont.base_bytes prompt <> session.bytes ->
          { state with session; blocked = true;
            message = tr "Completion remains published. Later-plan evidence changed; close and reload to inspect." }
      | Scheduled_bulk editor when Bulk.base_bytes editor <> session.bytes ->
          { state with session; blocked = true;
            message = tr "Batch target generation changed. Cancel, reload and reselect." }
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
              (S.preview ~book:state.session.book ~base_bytes:state.session.bytes
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
        {
          state with
          record =
            Some
              (S.create ~book:state.session.book ~day:state.workspace.calendar.selected_day
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

let open_route state route =
  let state =
    if route = W.Actual then
      let focus_date = state.workspace.calendar.selected_day in
      let actual_workspace = Act.create ~focus_date in
      sync_actual_to_workspace { state with actual_workspace }
    else state
  in
  sync { state with workspace = W.enter state.workspace route; overlay = No_overlay; scroll = 0;
                    drill_parent = None; drill_book = None }

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

let line ~width_of width style text = (style, O.clip_text ~width_of (max 0 width) text)

let feedback_lines ~dimensions:(width, height) ~width_of state =
  let wrap text =
    O.wrap_text ~width_of (max 1 width) text |> List.map (line ~width_of width Status)
  in
  let rows =
    (if state.message = "" then [] else wrap state.message)
    @ match state.ui_notice with None -> [] | Some notice -> wrap notice
  in
  let capacity = max 0 (height - 6) in
  if capacity = 0 then []
  else
    let rows =
      if List.length rows <= capacity then rows
      else
        List.filteri (fun i _ -> i < capacity - 1) rows
        @ [ line ~width_of width Status (tr "More feedback; enlarge the terminal.") ]
    in
    List.init (max 0 (min 1 capacity - List.length rows)) (fun _ -> (Chrome, "")) @ rows

let body_dimensions ~dimensions:((width, height) as dimensions) ~width_of state =
  (width, max 0 (height - List.length (feedback_lines ~dimensions ~width_of state) - 2))

(* The editor's navigation remains at the terminal bottom; its body may float.
   Input and painting use the same dimensions, including the editor's two nav rows. *)
let record_dimensions ~dimensions:((width, height) as dimensions) ~width_of state =
  S.surface_dimensions
    (width, max 0 (height - List.length (feedback_lines ~dimensions ~width_of state)))

let reversal_dimensions ~dimensions ~width_of state =
  Rev.dimensions (body_dimensions ~dimensions ~width_of state)

let date_dimensions ~dimensions ~width_of state =
  Date.dimensions (body_dimensions ~dimensions ~width_of state)

let scheduled_dimensions ~dimensions ~width_of state =
  Sch.dimensions (body_dimensions ~dimensions ~width_of state)

let continuation_dimensions ~dimensions ~width_of state =
  Cont.dimensions (body_dimensions ~dimensions ~width_of state)

let cancellation_dimensions ~dimensions ~width_of state =
  Cancel.dimensions (body_dimensions ~dimensions ~width_of state)

let bulk_dimensions ~dimensions ~width_of state =
  Bulk.dimensions (body_dimensions ~dimensions ~width_of state)

let actual_dimensions ~dimensions ~width_of state =
  let width, body_height = body_dimensions ~dimensions ~width_of state in
  (width, max 0 (body_height - 2))

let update_calendar state action =
  match Cal.apply state.workspace.calendar action with
  | Cal.Refused why -> { state with message = tr why }
  | Cal.Moved calendar ->
      sync
        {
          state with
          workspace = { state.workspace with calendar; pane = W.Calendar };
          scroll = 0;
          message = (if state.blocked then state.message else "");
        }
  | Cal.Open_day calendar -> open_route state (W.Selected_day calendar.selected_day)

let back state =
  if state.workspace.pane = W.Detail then
    { state with workspace = { state.workspace with pane = W.Calendar }; scroll = 0 }
  else match state.drill_parent with
  | Some W.Actual ->
      let before_book = Option.value ~default:state.session.book state.drill_book in
      let actual_workspace =
        Act.returned_from_detail ~before_book ~after_book:state.session.book state.actual_workspace in
      sync_actual_to_workspace
        { state with actual_workspace; drill_parent = None; drill_book = None;
          workspace = W.enter state.workspace W.Actual; overlay = No_overlay }
  | _ -> open_route state W.Home

let exchange_form ?(default_date = F.today ()) () =
  Form.create
    ~id:"exchange"
    ~title:"Exchange / Record"
    ~summary:[
      "Record one direct exchange between two Measures.";
      "Amounts are entered as positive magnitudes.";
      "Source Effect is negative; Destination Effect is positive.";
      "No FX rate or valuation is inferred.";
    ]
    ~fields:[
      Form.text_field ~id:"date" ~label:"Date" ~value:default_date ();
      Form.text_field ~id:"memo" ~label:"Description" ~placeholder:"Optional description" ();
      Form.text_field ~id:"source_locus" ~label:"Source Locus" ~placeholder:"e.g. wallet_jpy" ();
      Form.text_field ~id:"source_measure" ~label:"Source Measure" ~value:"jpy" ();
      Form.text_field ~id:"source_amount" ~label:"Source amount" ~placeholder:"Positive amount (deducted)" ();
      Form.text_field ~id:"destination_locus" ~label:"Destination Locus" ~placeholder:"e.g. wallet_usd" ();
      Form.text_field ~id:"destination_measure" ~label:"Destination Measure" ~placeholder:"e.g. usd" ();
      Form.text_field ~id:"destination_amount" ~label:"Destination amount" ~placeholder:"Positive amount (added)" ();
      Form.action_buttons ~confirm:"Publish Exchange" ~cancel:"Cancel" ();
    ]
    ()

let open_exchange state =
  let default_date =
    match state.workspace.route with
    | W.Selected_day day -> day
    | _ -> state.workspace.calendar.selected_day
  in
  let form = exchange_form ~default_date () in
  { state with overlay = Modal_form form; message = "" }

let observe_quantity_form ?default_locus ?default_measure ?current_amount state =
  let def_measure =
    match default_measure with
    | Some m -> m
    | None -> (match B.measures state.session.book with (m, _) :: _ -> m | [] -> "jpy")
  in
  let locus_val = Option.value ~default:"" default_locus in
  let locus_ph =
    if locus_val <> "" then locus_val
    else match B.approved_loci state.session.book with Some (l :: _) -> l | _ -> "wallet"
  in
  let amount_ph =
    match current_amount with
    | Some amt -> Printf.sprintf "e.g. %s" amt
    | None -> "e.g. 50000"
  in
  Form.create
    ~id:"observe_quantity"
    ~title:"Observe Quantities"
    ~summary:[
      "Record newly verified balance for an account (Locus).";
      "Existing observations for other loci remain preserved.";
    ]
    ~fields:[
      Form.text_field ~id:"locus" ~label:"Locus" ~value:locus_val ~placeholder:(Printf.sprintf "e.g. %s" locus_ph) ();
      Form.text_field ~id:"measure" ~label:"Measure" ~value:def_measure ();
      Form.text_field ~id:"amount" ~label:"Observed amount" ~placeholder:amount_ph ();
      Form.action_buttons ~confirm:"Observe" ~cancel:"Cancel" ();
    ]
    ()

let open_command state = function
  | M.Record -> open_record { state with overlay = No_overlay }
  | M.New_plan -> open_plan_record { state with overlay = No_overlay }
  | M.Actual -> open_route state W.Actual
  | M.Scheduled -> open_route state W.Scheduled
  | M.Balances -> open_route state W.Balances
  | M.Daily_pace -> open_route state W.Daily_pace
  | M.Attention -> open_route state W.Attention
  | M.Manage_loci -> open_route state W.Loci
  | M.Exchange -> open_exchange { state with overlay = No_overlay }
  | M.Settlements -> open_route state W.Settlements
  | M.Observe -> { state with overlay = Modal_form (observe_quantity_form state); message = "" }
  | M.Home -> open_route state W.Home
  | M.Calendar -> open_route state W.Calendar
  | M.Theme ->
      let rec index i = function
        | [] -> 0
        | theme :: rest -> if theme = state.theme then i else index (i + 1) rest
      in
      let return_menu = match state.overlay with Commands menu -> menu | _ -> M.initial in
      { state with overlay = Themes { selected = index 0 P.all_themes;
                                     original = state.theme; return_menu } }

let input_text value = function
  | `Key (`ASCII c, []) when Char.code c >= 32 && Char.code c <> 127 ->
      Some (value ^ String.make 1 c)
  | `Key (`Uchar c, []) when O.printable_uchar c -> Some (value ^ O.utf8 c)
  | `Key (`Backspace, []) -> Some (Daily_form.backspace value)
  | _ -> None

let read_config state name =
  let directory = Filename.dirname state.session.F.path in
  let candidates =
    List.filter_map Fun.id
      [
        Option.map (fun home -> Filename.concat home name) state.config_home;
        Some (Filename.concat directory name);
        Some (Filename.concat (Filename.concat directory "config") name);
      ]
  in
  let rec read = function
    | [] -> None
    | filename :: rest -> (
        if not (Sys.file_exists filename) then read rest
        else
          try Some (F.read filename) with F.Refused _ | Unix.Unix_error _ | Sys_error _ -> Some "")
  in
  read candidates

let config_file_path state name =
  let dir = Option.value ~default:(Filename.dirname state.session.F.path) state.config_home in
  let nested = Filename.concat (Filename.concat dir "config") name in
  let present =
    try let _ = Unix.lstat nested in true
    with Unix.Unix_error (Unix.ENOENT, _, _) -> false | Unix.Unix_error _ -> true
  in
  if present then nested else Filename.concat dir name

let read_pace_config state name =
  let path = config_file_path state name in
  try
    let exists =
      try let _ = Unix.lstat path in true
      with Unix.Unix_error (Unix.ENOENT, _, _) -> false
    in
    if exists then Ok (Some (F.read path)) else Ok None
  with
  | F.Refused why | Sys_error why -> Error why
  | Unix.Unix_error (err, fn, arg) -> Error (Printf.sprintf "%s (%s %s)" (Unix.error_message err) fn arg)

let write_pace_pool state ~expected content =
  let path = config_file_path state "daily-pace.tsv" in
  let tmp = ref None in
  try
    F.with_writer path (fun () ->
      match read_pace_config state "daily-pace.tsv" with
      | Error why -> Error why
      | Ok current when current <> expected -> Error "Pool configuration changed. Reopen the editor."
      | Ok _ ->
          let target = path ^ ".tmp-" ^ F.nonce () in
          tmp := Some target;
          F.write_new target content;
          Sys.rename target path;
          F.sync_parent path;
          F.require (F.read path = content) "pace-config-readback-changed";
          Ok ())
  with
  | F.Refused why | Sys_error why ->
      Option.iter (fun p -> try Unix.unlink p with Unix.Unix_error _ -> ()) !tmp;
      Error why
  | Unix.Unix_error (err, fn, arg) ->
      Option.iter (fun p -> try Unix.unlink p with Unix.Unix_error _ -> ()) !tmp;
      Error (Printf.sprintf "%s (%s %s)" (Unix.error_message err) fn arg)

let accounting_roles state =
  match read_config state "accounting-roles.tsv" with
  | Some text -> O.parse_accounting_roles text
  | None -> []

let balance_view_coords state =
  let path = BalView.file_path ?config_home:state.config_home state.session.F.path in
  let configured = BalView.load_file path in
  List.map (fun (c : BalView.coordinate) -> (c.locus, c.measure)) configured

let config_lines text =
  String.split_on_char '\n' text |> List.filter (fun line ->
    let s = String.trim line in s <> "" && not (String.starts_with ~prefix:"#" s))

let config_token s =
  s <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) s

let resolve_pace_window state =
  let today = F.today () in
  let canonical_date day =
    match A.normalize_date day with Ok canonical -> canonical = day | Error _ -> false
  in
  let rec increasing = function
    | a :: b :: rest -> a < b && increasing (b :: rest)
    | [] | [_] -> true
  in
  let rec parse names windows = function
    | [] -> (match windows with
        | [window] -> Ok window
        | [] -> Error "No explicit boundary preset contains today."
        | _ -> Error "Multiple boundary presets contain today; selection is ambiguous.")
    | line :: rest ->
        match String.split_on_char '\t' line with
        | name :: dates when config_token name && not (List.mem name names)
            && List.length dates >= 2 && List.for_all canonical_date dates
            && increasing dates ->
            let rec window = function
              | a :: b :: tail -> if a <= today && today < b then Some (a, b) else window (b :: tail)
              | _ -> None
            in
            let windows = match window dates with Some w -> w :: windows | None -> windows in
            parse (name :: names) windows rest
        | _ -> Error "Malformed boundary-presets.tsv; no period was inferred."
  in
  Result.bind (read_pace_config state "boundary-presets.tsv") (function
    | None -> Error "Period not configured (boundary-presets.tsv missing)."
    | Some text -> parse [] [] (config_lines text))

let resolve_pace_pool state =
  let measure = state.workspace.measure in
  let rec coordinates acc = function
    | [] -> if acc = [] then Error "Daily Pace pool is empty." else Ok (List.rev acc)
    | line :: rest ->
        match String.split_on_char '\t' line with
        | [locus; m] when config_token locus && m = measure && config_token m ->
            let coordinate = {
              D.Effect_coordinate.locus = get_id (D.Identifier.Locus.of_string locus);
              measure = get_id (D.Identifier.Measure.of_string m);
            } in
            if List.mem coordinate acc then Error "Duplicate Daily Pace coordinate."
            else coordinates (coordinate :: acc) rest
        | _ -> Error "Malformed daily-pace.tsv or mismatched Measure; no rows were skipped."
  in
  Result.bind (read_pace_config state "daily-pace.tsv") (function
    | None -> Error "Daily Pace pool not configured (daily-pace.tsv missing)."
    | Some text -> coordinates [] (config_lines text))

let current_pace_result state =
  let today = F.today () and measure = state.workspace.measure in
  Result.bind (resolve_pace_pool state) (fun pool ->
    Result.bind (resolve_pace_window state) (fun (start_day, end_exclusive) ->
      Result.map (fun p -> (p, start_day, end_exclusive))
        (B.daily_pace state.session.book ~measure ~pool ~observed_at:today ~end_exclusive)))

let current_pace_data state = Result.to_option (current_pace_result state)

let what_if_form ?amount ?result state =
  let summary =
    match current_pace_data state with
    | Some (pace, _start, _end_excl) ->
        let cur = B.format state.session.book pace.B.measure pace.daily_pace_quanta in
        let avail = B.format state.session.book pace.B.measure pace.available_through_end in
        [
          Printf.sprintf "Current pace: %s %s/day" cur pace.measure;
          Printf.sprintf "Available: %s %s over %d remaining days." avail pace.measure pace.remaining_days;
          "Simulate an immediate purchase outflow without publishing any transaction.";
        ]
    | None ->
        [ "Daily pace is not currently calculated; enter amount to simulate." ]
  in
  let notice = Option.value ~default:"" result in
  Form.create
    ~id:"daily_pace_what_if"
    ~title:"Daily Pace What-If (Purchase Scenario)"
    ~summary
    ~notice
    ~fields:[
      Form.text_field ~id:"amount" ~label:"Purchase amount" ?value:amount ~placeholder:"e.g. 10000" ();
      Form.action_buttons ~confirm:"Simulate" ~cancel:"Close" ();
    ]
    ()

let configure_pace_form state =
  let current_pool_loci = match resolve_pace_pool state with
    | Ok coords -> String.concat ", " (List.map (fun c -> A.lstr c.D.Effect_coordinate.locus) coords)
    | Error _ -> ""
  in
  let payload, notice = match read_pace_config state "daily-pace.tsv" with
    | Ok None -> ("missing", "")
    | Ok (Some text) -> ("present\n" ^ text, "")
    | Error why -> ("unreadable", why)
  in
  let period = match resolve_pace_window state with
    | Ok (start, stop) -> Printf.sprintf "Explicit period: %s -> %s (exclusive)." start stop
    | Error why -> why
  in
  Form.create ~id:"configure_daily_pace" ~payload ~notice
    ~title:"Configure Daily Pace Pool"
    ~summary:[
      "Save only daily-pace.tsv; no account is selected automatically.";
      period;
      "Period boundaries are read-only here; edit boundary-presets.tsv separately.";
    ]
    ~fields:[
      Form.text_field ~id:"pool_loci" ~label:"Pool accounts (comma-separated)" ~value:current_pool_loci ();
      Form.action_buttons ~confirm:"Save Pool" ~cancel:"Cancel" ();
    ] ()

let balance_items state =
  match state.balance_mode with
  | `Accounting ->
      let roles = accounting_roles state in
      O.role_balance_items ~book:state.session.book ~roles
  | `Current ->
      let coords = balance_view_coords state in
      O.current_balance_items ~book:state.session.book ~coords

let balance_lines state =
  let items = balance_items state in
  List.map (O.balance_item_line ~book:state.session.book) items

let balance_print_preview state =
  let lines = balance_lines state in
  if List.length lines > 200 then
    Form.create ~id:"balance_print_refused" ~title:(tr "Print Refused")
      ~summary:[
        tr "Print refused: more than 200 lines.";
        tr "Narrow the balance selection in balance-view.tsv first.";
      ]
      ~fields:[ Form.action_buttons ~confirm:(tr "OK") ~cancel:(tr "Close") () ]
      ()
  else
    let summary =
      [
        tr "Plain-text print preview of current balance view:";
        Printf.sprintf "Total rows: %d" (List.length lines);
      ] @ lines
    in
    Form.create ~id:"balance_print_preview" ~title:(tr "Balances / Print Preview")
      ~summary
      ~fields:[ Form.action_buttons ~confirm:(tr "Done") ~cancel:(tr "Close") () ]
      ()

let admitted_loci state =
  let book = state.session.book in
  match B.approved_loci book with
  | Some loci when loci <> [] -> loci
  | _ ->
      let from_entries =
        List.concat_map
          (fun (e : B.entry) ->
            List.map (fun p -> A.lstr (D.Effect.locus p)) e.effects)
          (B.entries book)
      in
      let from_plans =
        List.concat_map
          (fun (p : B.plan) -> List.map fst p.changes)
          (B.plans book)
      in
      List.sort_uniq String.compare (from_entries @ from_plans)

let selected_locus state =
  let loci = admitted_loci state in
  let sel = state.workspace.loci.selected in
  List.nth_opt loci sel

let move_locus state delta =
  let loci = admitted_loci state in
  let count = List.length loci in
  if count = 0 then state
  else
    let current = state.workspace.loci.selected in
    let last = count - 1 in
    let selected = max 0 (min last (current + delta)) in
    { state with workspace = { state.workspace with loci = { state.workspace.loci with selected } } }

let role_option_strings =
  [ "(None / Unassigned)"; "Asset"; "Liability"; "Equity"; "Income"; "Expense" ]

let role_of_index = function
  | 1 -> Some Roles.Asset
  | 2 -> Some Roles.Liability
  | 3 -> Some Roles.Equity
  | 4 -> Some Roles.Income
  | 5 -> Some Roles.Expense
  | _ -> None

let index_of_role = function
  | Some Roles.Asset -> 1
  | Some Roles.Liability -> 2
  | Some Roles.Equity -> 3
  | Some Roles.Income -> 4
  | Some Roles.Expense -> 5
  | None -> 0

let admit_locus_form ~count =
  Form.create
    ~id:"admit_locus"
    ~title:"Admit New Locus"
    ~summary:[
      Printf.sprintf "Currently admitted: %d loci" count;
      "Admission establishes an approved coordinate token in the book.";
      "Accounting role can be assigned immediately or configured later.";
    ]
    ~fields:[
      Form.text_field ~id:"token" ~label:"Stable token" ~placeholder:"e.g. cash, wallet, grocery" ();
      Form.choice_field ~id:"role" ~label:"Accounting Role" ~options:role_option_strings ~selected:0 ();
      Form.action_buttons ~confirm:"Admit Locus" ~cancel:"Cancel" ();
    ]
    ()

let set_locus_role_form ~locus ~current_role =
  let curr_label = match current_role with None -> "None" | Some r -> Roles.role_label r in
  Form.create
    ~id:"set_locus_role"
    ~payload:locus
    ~title:("Set Accounting Role / " ^ locus)
    ~summary:[
      "Target Locus: " ^ locus;
      "Current role: " ^ curr_label;
      "Saved to accounting-roles.tsv for role-aware balance sheets and reports.";
    ]
    ~fields:[
      Form.choice_field ~id:"role" ~label:"Accounting Role" ~options:role_option_strings ~selected:(index_of_role current_role) ();
      Form.action_buttons ~confirm:"Save Role" ~cancel:"Cancel" ();
    ]
    ()

let settlement_rows state =
  match state.settlements with
  | Ok t -> Stl.visible_rows t state.settlement_scope
  | Error _ -> []

let selected_settlement state =
  let rows = settlement_rows state in
  let sel = state.workspace.settlements.selected in
  List.nth_opt rows sel

let move_settlement state delta =
  let rows = settlement_rows state in
  let count = List.length rows in
  if count = 0 then state
  else
    let current = state.workspace.settlements.selected in
    let last = count - 1 in
    let selected = max 0 (min last (current + delta)) in
    { state with workspace = { state.workspace with settlements = { state.workspace.settlements with selected } } }

let cycle_settlement_scope state =
  let settlement_scope =
    match state.settlement_scope with
    | Stl.Open_only -> Stl.All
    | Stl.All -> Stl.Open_only
  in
  let rows = match state.settlements with
    | Ok t -> Stl.visible_rows t settlement_scope
    | Error _ -> [] in
  let count = List.length rows in
  let current = state.workspace.settlements.selected in
  let selected = if count = 0 then 0 else min (count - 1) current in
  { state with settlement_scope; workspace = { state.workspace with settlements = { state.workspace.settlements with selected } } }

let add_settlement_form state =
  let def_measure = match B.measures state.session.book with (m, _) :: _ -> m | [] -> "jpy" in
  Form.create
    ~id:"add_settlement"
    ~title:"Add Settlement Commitment"
    ~summary:[
      "Track one reimbursement or external obligation.";
      "Debtor owes Creditor; positive remaining balance indicates open obligation.";
    ]
    ~fields:[
      Form.text_field ~id:"label" ~label:"Description" ~placeholder:"e.g. Dinner reimbursement, 懇親会立替" ();
      Form.text_field ~id:"debtor" ~label:"Debtor (owes)" ~value:"external" ();
      Form.text_field ~id:"creditor" ~label:"Creditor (owed)" ~value:"household" ();
      Form.text_field ~id:"measure" ~label:"Measure" ~value:def_measure ();
      Form.text_field ~id:"amount" ~label:"Committed amount" ~placeholder:"e.g. 5000" ();
      Form.action_buttons ~confirm:"Add Commitment" ~cancel:"Cancel" ();
    ]
    ()

let action_options = [ "Settle (Payment received/made)"; "Reduce without payment"; "Retract commitment" ]

let action_settlement_form (r : Stl.row) =
  let rem = Stl.outstanding r in
  let desc = match r.label with Some l -> l | None -> r.id in
  Form.create
    ~id:"action_settlement"
    ~payload:r.id
    ~title:("Settlement Action / " ^ r.id)
    ~summary:[
      "Target: " ^ desc;
      Printf.sprintf "Direction: %s -> %s" r.debtor r.creditor;
      Printf.sprintf "Committed: %s %s  Remaining: %s %s" (Z.to_string r.committed) r.measure (Z.to_string rem) r.measure;
    ]
    ~fields:[
      Form.choice_field ~id:"action_kind" ~label:"Action" ~options:action_options ~selected:0 ();
      Form.text_field ~id:"amount" ~label:"Amount" ~value:(Z.to_string rem) ();
      Form.action_buttons ~confirm:"Confirm Action" ~cancel:"Cancel" ();
    ]
    ()

let commit_attention state submitted update message =
  let result =
    if state.blocked then Error "Writes stopped. Reload to inspect."
    else Result.bind state.attention (fun expected ->
      Result.bind (update expected) (fun updated ->
        Result.map (fun () -> updated) (Att.save_file state.attention_path ~expected updated)))
  in
  match result with
  | Ok attention -> { state with overlay = No_overlay; attention = Ok attention; message }
  | Error why -> { state with overlay = Modal_form (Form.set_notice submitted
      ("Attention not confirmed: " ^ why ^ " Reload to inspect before retrying.")) }

let commit_settlements state submitted update message =
  let result =
    if state.blocked then Error "Writes stopped. Reload to inspect."
    else Result.bind state.settlements (fun expected ->
      Result.bind (update expected) (fun updated ->
        Result.map (fun () -> updated) (Stl.save_file state.settlement_path ~expected updated)))
  in
  match result with
  | Ok settlements -> { state with overlay = No_overlay; settlements = Ok settlements; message }
  | Error why -> { state with overlay = Modal_form (Form.set_notice submitted
      ("Settlements not confirmed: " ^ why ^ " Reload to inspect before retrying.")) }

let is_scheduled_months state =
  state.workspace.route = W.Scheduled && state.workspace.schedule_view = W.Months

let is_record_browser state =
  state.workspace.route = W.Actual || state.workspace.route = W.Scheduled

let browser_pane_widths width =
  if width < 80 then (width, width)
  else let left = max 36 (min 58 (width * 52 / 100)) in (left, width - left - 1)

let browser_detail_rows ~width_of ~width state =
  let lines = match selected state with
    | Some (W.Actual_entry entry) -> O.entry_lines state.session.book entry
    | Some (W.Scheduled_plan plan) -> O.plan_lines state.session.book plan
    | None -> [ tr "No selected record." ] in
  List.concat_map (O.wrap_text ~width_of (max 1 (width - 6))) lines

let browser_viewport ~dimensions ~width_of state =
  let width, body_height = body_dimensions ~dimensions ~width_of state in
  let height = max 0 (body_height - 2) in
  let _, detail_width = if is_scheduled_months state then (width, width) else browser_pane_widths width in
  let view = Panel.window ~capacity:(Panel.capacity ~height ~heading:false)
    ~count:(List.length (browser_detail_rows ~width_of ~width:detail_width state))
    ~scroll:state.scroll ~selected:None in
  (height, view)

let handle ?(dimensions = (80, 24)) ?(width_of = String.length) state (input : input) =
  let state =
    if is_record_browser state && not state.record_visible then
      let _, view = browser_viewport ~dimensions ~width_of state in
      { state with scroll = view.start }
    else state in
  if state.paste_blocked then
    match input with
    | `Paste `End ->
        Some
          {
            state with
            paste_blocked = false;
            message =
              (if state.blocked then state.message
               else tr "Paste ignored outside Record input; no commands were run.");
          }
    | `End -> None
    | _ -> Some state
  else if input = `Paste `Start && ((not state.record_visible) || Option.is_none state.record) then
    Some { state with paste_blocked = true }
  else if state.record_visible then
    match state.record with
    | None -> Some { state with record_visible = false }
    | Some record -> (
        match
          S.handle ~book:state.session.book ~base_bytes:state.session.bytes ~blocked:state.blocked
            ~dimensions:(record_dimensions ~dimensions ~width_of state)
            ~width_of record input
        with
        | S.Updated record -> Some { state with record = Some record }
        | S.Closed record -> Some { state with record = Some record; record_visible = false }
        | S.Publish (payload, base_bytes, record) ->
            let draft = { state with record = Some record } in
            Some
              (if state.blocked then draft
               else
                 apply_commit_result state ~draft
                   (A.commit_payload ~session:state.session ~base_bytes payload)))
  else
    match state.overlay with
    | Scheduled_bulk editor -> (
        match input with
        | `Key (`ASCII ('r' | 'R'), [`Ctrl]) -> Some (reload state)
        | _ -> (
            match Bulk.handle ~blocked:state.blocked
              ~dimensions:(bulk_dimensions ~dimensions ~width_of state) ~width_of editor input with
            | Bulk.Updated editor -> Some { state with overlay = Scheduled_bulk editor }
            | Bulk.Closed -> Some { state with overlay = No_overlay }
            | Bulk.Publish (plans, base_bytes) ->
                let draft = { state with overlay = Scheduled_bulk
                  (Bulk.with_publish_error editor "Batch publication not confirmed. Review the notice below.") } in
                Some (apply_commit_result state ~draft
                  (A.commit_plan_batch ~session:state.session ~base_bytes plans))))
    | Scheduled_continuation prompt -> (
        match input with
        | `Key (`ASCII ('r' | 'R'), [ `Ctrl ]) -> Some (reload state)
        | _ -> (
            let updated message =
              { state with overlay = Scheduled_continuation (Cont.with_notice prompt message) } in
            match Cont.handle ~dimensions:(continuation_dimensions ~dimensions ~width_of state) ~width_of prompt input with
            | Cont.Updated prompt -> Some { state with overlay = Scheduled_continuation prompt }
            | Cont.Closed candidate ->
                Some { state with overlay = No_overlay;
                  message = (if state.blocked then state.message else
                    match candidate with
                    | None -> "Completion retained. No additional Scheduled created."
                    | Some p -> "Completion retained. Kept later Scheduled " ^ O.visible p.id ^
                        "; no additional Scheduled created.") }
            | Cont.Add source ->
                if state.blocked then Some (updated "Writes stopped; completion remains published.")
                else (match Sch.create_from_scheduled ~book:state.session.book source with
                  | Ok editor -> Some { state with overlay = Scheduled_create editor;
                      message = "Completion remains published; adding an independent Scheduled." }
                  | Error why -> Some (updated why))
            | Cont.Defer source ->
                if state.blocked then Some (updated "Writes stopped; completion remains published.")
                else
                  let result = Result.bind state.attention (fun expected ->
                    let id = Att.next_id expected in
                    let context = "Decide continuation after " ^ source.id ^ " (scheduled " ^ source.day ^ "): " ^
                      String.concat "; " (List.map (fun (locus, amount) ->
                        locus ^ " " ^ B.format state.session.book source.measure amount ^ " " ^ source.measure) source.changes) in
                    Result.bind (Att.add_item expected ~id ~context ~due:Att.Due_undetermined) (fun attention ->
                      Result.map (fun () -> attention, id) (Att.save_file state.attention_path ~expected attention))) in
                  (match result with
                   | Ok (attention, id) -> Some { state with overlay = No_overlay; attention = Ok attention;
                       message = "Completion retained. Deferred continuation as " ^ id ^ "; no additional Scheduled created." }
                   | Error why -> Some { (updated "Defer not confirmed; reload to inspect before retrying.") with
                       message = "Completion remains published. Defer not confirmed: " ^ why })))
    | Scheduled_cancel editor -> (
        match input with
        | `Key (`ASCII ('r' | 'R'), [ `Ctrl ]) -> Some (reload state)
        | _ -> (
            match Cancel.handle ~blocked:state.blocked
              ~dimensions:(cancellation_dimensions ~dimensions ~width_of state) ~width_of editor input with
            | Cancel.Updated editor -> Some { state with overlay = Scheduled_cancel editor }
            | Cancel.Closed -> Some { state with overlay = No_overlay }
            | Cancel.Publish (id, day, base_bytes) ->
                let draft = { state with overlay = Scheduled_cancel (Cancel.with_publish_error editor) } in
                Some (apply_commit_result state ~draft
                  (A.commit_cancel_plan ~session:state.session ~base_bytes ~id ~day))))
    | Date_correction editor -> (
        match input with
        | `Key (`ASCII ('r' | 'R'), [ `Ctrl ]) -> Some (reload state)
        | _ -> (
            match Date.handle ~blocked:state.blocked
              ~dimensions:(date_dimensions ~dimensions ~width_of state) ~width_of editor input with
            | Date.Updated editor -> Some { state with overlay = Date_correction editor }
            | Date.Closed -> Some { state with overlay = No_overlay }
            | Date.Publish (tx, base_bytes) ->
                let draft = { state with overlay = Date_correction (Date.edit editor) } in
                let next = apply_commit_result state ~draft
                  (A.commit_transaction ~session:state.session ~base_bytes tx) in
                Some (if next.overlay = No_overlay && next.workspace.route = W.Actual then
                  let actual_workspace = Act.returned_from_detail
                    ~before_book:state.session.book ~after_book:next.session.book state.actual_workspace in
                  sync_actual_to_workspace { next with actual_workspace }
                else next)))
    | Reversal editor -> (
        match input with
        | `Key (`ASCII ('r' | 'R'), [ `Ctrl ]) -> Some (reload state)
        | _ -> (
            match Rev.handle ~blocked:state.blocked
              ~dimensions:(reversal_dimensions ~dimensions ~width_of state) ~width_of editor input with
            | Rev.Updated editor -> Some { state with overlay = Reversal editor }
            | Rev.Closed -> Some { state with overlay = No_overlay }
            | Rev.Publish (id, day, base_bytes) ->
                let draft = { state with overlay = Reversal (Rev.with_publish_error editor) } in
                Some (apply_commit_result state ~draft
                  (A.commit_reverse_entry ~session:state.session ~base_bytes ~id ~day))))
    | Scheduled_create editor -> (
        match input with
        | `Key (`ASCII ('r' | 'R'), [ `Ctrl ]) -> Some (reload state)
        | _ -> (
            let dim = scheduled_dimensions ~dimensions ~width_of state in
            match Sch.handle ~blocked:state.blocked ~dimensions:dim ~width_of editor input with
            | Sch.Updated editor -> Some { state with overlay = Scheduled_create editor }
            | Sch.Closed -> Some { state with overlay = No_overlay }
            | Sch.Publish draft ->
                let plan =
                  {
                    B.id = Daily_actions.F.new_id ();
                    day = draft.Sch.scheduled_on;
                    measure = draft.Sch.measure;
                    changes = draft.Sch.changes;
                    paid_by = None;
                    cancelled_on = None;
                  }
                in
                let draft_state =
                  { state with overlay = Scheduled_create (Sch.with_publish_error editor "Publish failed.") }
                in
                Some
                  (if state.blocked then draft_state
                   else
                     apply_commit_result state ~draft:draft_state
                       (A.commit_payload ~session:state.session ~base_bytes:state.session.bytes
                          (A.Plan_tx { plan; replace = false })))))
    | Commands menu -> (
        match M.handle menu input with
        | M.Updated menu -> Some { state with overlay = Commands menu }
        | M.Closed -> Some { state with overlay = No_overlay }
        | M.Chosen action -> Some (open_command state action))
    | Themes { selected; original; return_menu } -> (
        let count = List.length P.all_themes in
        match input with
        | `Key ((`Escape | `ASCII 'q'), []) ->
            Some
              { state with theme = original; overlay = Commands return_menu }
        | `Key ((`Arrow `Up | `Arrow `Left | `ASCII 'k'), [])
        | `Key ((`Arrow `Down | `Arrow `Right | `ASCII 'j'), []) ->
            let delta =
              match input with `Key ((`Arrow `Up | `Arrow `Left | `ASCII 'k'), []) -> -1 | _ -> 1
            in
            let selected = max 0 (min (count - 1) (selected + delta)) in
            Some
              {
                state with
                theme = List.nth P.all_themes selected;
                overlay = Themes { selected; original; return_menu };
              }
        | `Key (`Enter, []) ->
            let notice =
              match P.save_theme ?config_home:state.config_home state.theme with
              | Ok () -> tr "Theme saved."
              | Error _ -> tr "Theme changed for this session only; settings could not be saved."
            in
            Some { state with overlay = No_overlay; ui_notice = Some notice }
        | _ -> Some state)
    | Jump value -> (
        match input with
        | `Key (`Escape, []) -> Some { state with overlay = No_overlay }
        | `Key (`Enter, []) ->
            Some (update_calendar { state with overlay = No_overlay } (Cal.Jump value))
        | _ ->
            Some
              (match input_text value input with
              | None -> state
              | Some value -> { state with overlay = Jump value }))
    | Search value -> (
        match input with
        | `Key (`Escape, []) ->
            Some
              (sync { state with overlay = No_overlay; workspace = W.set_query state.workspace "" })
        | `Key (`Enter, []) ->
            Some
              (sync
                 { state with overlay = No_overlay; workspace = W.set_query state.workspace value })
        | _ ->
            Some
              (match input_text value input with
              | None -> state
              | Some value ->
                  if state.workspace.route = W.Actual then
                    sync { state with overlay = Search value;
                      workspace = W.set_query state.workspace value }
                  else { state with overlay = Search value }))
    | Modal_form form -> (
        match Form.handle_input form input with
        | Form.Cancel -> Some { state with overlay = No_overlay }
        | Form.Updated updated -> Some { state with overlay = Modal_form updated }
        | Form.Submit submitted -> (
            match Form.id submitted with
            | "add_attention" ->
                let context = Option.value ~default:"" (Form.get_text submitted "context") in
                let due_kind_idx = Option.value ~default:0 (Form.get_choice submitted "due_kind") in
                let due_date = Option.value ~default:"" (Form.get_text submitted "due_date") in
                if String.trim context = "" then
                  Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter a short household matter description.")) }
                else
                  let due_res =
                    match due_kind_idx with
                    | 0 -> Ok Att.No_due_date
                    | 1 -> Ok Att.Due_undetermined
                    | 2 ->
                        (match A.normalize_date due_date with
                        | Error _ -> Error (tr "Invalid date (YYYY-MM-DD).")
                        | Ok canon_day ->
                            if not (A.is_valid_canonical_date canon_day) then
                              Error (tr "Enter a real calendar date in YYYY-MM-DD form.")
                            else Ok (Att.Due_on canon_day))
                    | _ -> Ok Att.No_due_date
                  in
                  (match due_res with
                  | Error notice ->
                      Some { state with overlay = Modal_form (Form.set_notice submitted notice) }
                  | Ok due ->
                      Some (commit_attention state submitted
                        (fun t -> Att.add_item t ~id:(Att.next_id t) ~context ~due)
                        "Attention added and read back."))
            | "resolve_attention" ->
                let item_id = Form.payload submitted in
                Some (commit_attention state submitted
                  (fun t -> Att.close_item t ~id:item_id ~known_on:(F.today ()) ~kind:Att.Resolved)
                  (Printf.sprintf "Resolved %s." item_id))
            | "drop_attention" ->
                let item_id = Form.payload submitted in
                Some (commit_attention state submitted
                  (fun t -> Att.close_item t ~id:item_id ~known_on:(F.today ()) ~kind:Att.Dropped)
                  (Printf.sprintf "Dropped %s." item_id))
            | "admit_locus" ->
                let token = Option.value ~default:"" (Form.get_text submitted "token") |> String.trim in
                let role_idx = Option.value ~default:0 (Form.get_choice submitted "role") in
                let role_opt = role_of_index role_idx in
                if token = "" then
                  Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter the new Locus token.")) }
                else
                  let res = A.commit_add_locus ~session:state.session token in
                  (match res with
                  | A.Refused why ->
                      Some { state with overlay = Modal_form (Form.set_notice submitted why) }
                  | A.Conflict | A.Conflict_base_changed ->
                      Some { state with overlay = Modal_form (Form.set_notice submitted (tr "File changed on disk. Reload to inspect.")) }
                  | A.Published _ | A.Idempotent_duplicate _ ->
                      (match role_opt with
                      | Some r ->
                          let path = Roles.file_path ?config_home:state.config_home state.session.F.path in
                          let roles = Roles.load_file path in
                          let updated_roles = Roles.set_role roles token (Some r) in
                          let _ = Roles.save_file path updated_roles in
                          ()
                      | None -> ());
                      let next_state = { state with overlay = No_overlay; message = Printf.sprintf "Admitted locus %s." token } in
                      Some (apply_commit_result next_state ~draft:next_state res)
                  | _ ->
                      let next_state = { state with overlay = No_overlay; message = Printf.sprintf "Admitted locus %s." token } in
                      Some (apply_commit_result next_state ~draft:next_state res))
            | "set_locus_role" ->
                let locus = Form.payload submitted in
                let role_idx = Option.value ~default:0 (Form.get_choice submitted "role") in
                let role_opt = role_of_index role_idx in
                let path = Roles.file_path ?config_home:state.config_home state.session.F.path in
                let roles = Roles.load_file path in
                let updated_roles = Roles.set_role roles locus role_opt in
                (match Roles.save_file path updated_roles with
                | Error why ->
                    Some { state with overlay = Modal_form (Form.set_notice submitted why) }
                | Ok () ->
                    let role_str = match role_opt with None -> "None" | Some r -> Roles.role_label r in
                    Some { state with overlay = No_overlay; message = Printf.sprintf "Set accounting role for %s to %s." locus role_str })
            | "exchange" ->
                let date_str = Option.value ~default:"" (Form.get_text submitted "date") |> String.trim in
                let memo_str = Option.value ~default:"" (Form.get_text submitted "memo") |> String.trim in
                let src_locus = Option.value ~default:"" (Form.get_text submitted "source_locus") |> String.trim in
                let src_measure = Option.value ~default:"" (Form.get_text submitted "source_measure") |> String.trim in
                let src_amount_str = Option.value ~default:"" (Form.get_text submitted "source_amount") |> String.trim in
                let dst_locus = Option.value ~default:"" (Form.get_text submitted "destination_locus") |> String.trim in
                let dst_measure = Option.value ~default:"" (Form.get_text submitted "destination_measure") |> String.trim in
                let dst_amount_str = Option.value ~default:"" (Form.get_text submitted "destination_amount") |> String.trim in
                let valid_token s =
                  s <> "" && not (String.contains s ' ') && not (String.contains s '\t')
                  && not (String.contains s '\n') && not (String.contains s '\r')
                in
                (match A.normalize_date date_str with
                | Error _ ->
                    Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Invalid date (YYYY-MM-DD).")) }
                | Ok canon_day ->
                    if not (A.is_valid_canonical_date canon_day) then
                      Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter a real calendar date in YYYY-MM-DD form.")) }
                    else if not (valid_token src_locus) then
                      Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Source Locus must be a nonempty single-line token.")) }
                    else if not (valid_token dst_locus) then
                      Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Destination Locus must be a nonempty single-line token.")) }
                    else if not (valid_token src_measure) then
                      Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Source Measure must be a nonempty single-line token.")) }
                    else if not (valid_token dst_measure) then
                      Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Destination Measure must be a nonempty single-line token.")) }
                    else if String.equal src_measure dst_measure then
                      Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Source and destination Measures must differ.")) }
                    else
                      (match B.parse_amount state.session.book src_measure src_amount_str with
                      | Error why ->
                          let msg =
                            if why = "non-positive-amount" then tr "Source amount must be positive."
                            else if why = "measure-scale-not-supplied" then
                              Printf.sprintf "Measure '%s' scale is not configured." src_measure
                            else tr "Source amount is invalid."
                          in
                          Some { state with overlay = Modal_form (Form.set_notice submitted msg) }
                      | Ok src_quanta ->
                          (match B.parse_amount state.session.book dst_measure dst_amount_str with
                          | Error why ->
                              let msg =
                                if why = "non-positive-amount" then tr "Destination amount must be positive."
                                else if why = "measure-scale-not-supplied" then
                                  Printf.sprintf "Measure '%s' scale is not configured." dst_measure
                                else tr "Destination amount is invalid."
                              in
                              Some { state with overlay = Modal_form (Form.set_notice submitted msg) }
                          | Ok dst_quanta ->
                              let approved = B.approved_loci state.session.book in
                              let unapproved =
                                match approved with
                                | None -> []
                                | Some ids ->
                                    let check loc = if not (List.mem loc ids) then [ loc ] else [] in
                                    check src_locus @ check dst_locus
                              in
                              if unapproved <> [] then
                                let msg = Printf.sprintf "Locus '%s' is not admitted." (String.concat ", " unapproved) in
                                Some { state with overlay = Modal_form (Form.set_notice submitted msg) }
                              else
                                let src_effect =
                                  D.Effect.create
                                    ~key:(Some (Result.get_ok (D.Identifier.Effect_key.of_string "exchange-source")))
                                    ~locus:(Result.get_ok (D.Identifier.Locus.of_string src_locus))
                                    ~measure:(Result.get_ok (D.Identifier.Measure.of_string src_measure))
                                    ~quantity:(D.Quantity.of_quanta (Z.neg src_quanta))
                                in
                                let dst_effect =
                                  D.Effect.create
                                    ~key:(Some (Result.get_ok (D.Identifier.Effect_key.of_string "exchange-destination")))
                                    ~locus:(Result.get_ok (D.Identifier.Locus.of_string dst_locus))
                                    ~measure:(Result.get_ok (D.Identifier.Measure.of_string dst_measure))
                                    ~quantity:(D.Quantity.of_quanta dst_quanta)
                                in
                                let memo = if memo_str = "" then None else Some memo_str in
                                let entry =
                                  {
                                    B.id = F.new_id ();
                                    day = canon_day;
                                    memo;
                                    effects = [ src_effect; dst_effect ];
                                    reversal_of = None;
                                    exchange = Some ("exchange-source", "exchange-destination");
                                  }
                                in
                                let tx = { A.entry; replace = false; plan = None } in
                                let res = A.commit_transaction ~session:state.session ~base_bytes:state.session.bytes tx in
                                (match res with
                                | A.Refused why ->
                                    Some { state with overlay = Modal_form (Form.set_notice submitted why) }
                                | A.Conflict | A.Conflict_base_changed ->
                                    Some { state with overlay = Modal_form (Form.set_notice submitted (tr "File changed on disk. Reload to inspect.")) }
                                | A.Published _ | A.Idempotent_duplicate _ | _ ->
                                    let next_state = { state with overlay = No_overlay; message = tr "Exchange recorded." } in
                                    Some (apply_commit_result next_state ~draft:next_state res)))))
            | "add_settlement" ->
                let label_str = Option.value ~default:"" (Form.get_text submitted "label") |> String.trim in
                let debtor = Option.value ~default:"" (Form.get_text submitted "debtor") |> String.trim in
                let creditor = Option.value ~default:"" (Form.get_text submitted "creditor") |> String.trim in
                let measure = Option.value ~default:"" (Form.get_text submitted "measure") |> String.trim in
                let amount_str = Option.value ~default:"" (Form.get_text submitted "amount") |> String.trim in
                if debtor = "" then
                  Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter debtor endpoint.")) }
                else if creditor = "" then
                  Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter creditor endpoint.")) }
                else if measure = "" then
                  Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter measure token.")) }
                else
                  (match B.parse_amount state.session.book measure amount_str with
                  | Error why ->
                      let msg =
                        if why = "non-positive-amount" then tr "Committed amount must be positive."
                        else if why = "measure-scale-not-supplied" then
                          Printf.sprintf "Measure '%s' scale is not configured." measure
                        else tr "Invalid amount."
                      in
                      Some { state with overlay = Modal_form (Form.set_notice submitted msg) }
                  | Ok committed ->
                      let label = if label_str = "" then None else Some label_str in
                      Some (commit_settlements state submitted
                        (fun t -> Stl.add_row t ~id:(Stl.next_id t) ?label ~debtor ~creditor ~measure ~committed ())
                        "Commitment added and read back."))
            | "action_settlement" ->
                let id = Form.payload submitted in
                let kind_idx = Option.value ~default:0 (Form.get_choice submitted "action_kind") in
                let amount_str = Option.value ~default:"" (Form.get_text submitted "amount") |> String.trim in
                (match Result.bind state.settlements (fun t ->
                   match Stl.find_row t id with Some r -> Ok r | None -> Error "Commitment not found.") with
                | Error why ->
                    Some { state with overlay = Modal_form (Form.set_notice submitted why) }
                | Ok r ->
                    if kind_idx = 2 then
                      Some (commit_settlements state submitted
                        (fun t -> Stl.retract_row t ~id)
                        (Printf.sprintf "Retracted commitment %s." id))
                    else
                      (match B.parse_amount state.session.book r.measure amount_str with
                      | Error why ->
                          let msg =
                            if why = "non-positive-amount" then tr "Amount must be positive."
                            else if why = "measure-scale-not-supplied" then
                              Printf.sprintf "Measure '%s' scale is not configured." r.measure
                            else tr "Invalid amount."
                          in
                          Some { state with overlay = Modal_form (Form.set_notice submitted msg) }
                      | Ok amount ->
                          let verb = if kind_idx = 0 then "Settled" else "Reduced" in
                          Some (commit_settlements state submitted
                            (fun t -> if kind_idx = 0 then Stl.settle_row t ~id ~amount
                              else Stl.reduce_row t ~id ~amount)
                            (Printf.sprintf "%s %s on %s." verb (Z.to_string amount) id))))
        | "observe_quantity" ->
            let locus = String.trim (Option.value ~default:"" (Form.get_text submitted "locus")) in
            let measure = String.trim (String.lowercase_ascii (Option.value ~default:"jpy" (Form.get_text submitted "measure"))) in
            let amount_str = String.trim (Option.value ~default:"" (Form.get_text submitted "amount")) in
            if locus = "" then
              Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter account Locus token.")) }
            else if measure = "" then
              Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter Measure token.")) }
            else if amount_str = "" then
              Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter observed amount.")) }
            else
              (match B.parse_signed_amount state.session.book measure amount_str with
              | Error why ->
                  let msg =
                    if why = "unknown-measure" || why = "measure-scale-not-supplied" then
                      Printf.sprintf "Measure '%s' scale is not configured." measure
                    else tr "Invalid amount."
                  in
                  Some { state with overlay = Modal_form (Form.set_notice submitted msg) }
              | Ok quantity ->
                  (match B.observe_quantities state.session.book [ (locus, measure, quantity) ] with
                  | Error why ->
                      let msg =
                        if why = "locus-not-approved" then
                          Printf.sprintf "Locus '%s' is not in approved vocabulary." locus
                        else if why = "support-admission" || why = "assertion-overlaps-origin" || why = "assertion-overlaps-opening" then
                          tr "Coordinate is already supported by zero-origin or opening balance."
                        else why
                      in
                      Some { state with overlay = Modal_form (Form.set_notice submitted msg) }
                  | Ok new_book ->
                      (match F.publish state.session new_book with
                      | F.Written updated_session ->
                          Some (sync { state with session = updated_session; overlay = No_overlay;
                                                 message = Printf.sprintf "Observed %s %s = %s." locus measure amount_str })
                      | F.Conflict ->
                          Some { state with overlay = Modal_form (Form.set_notice submitted (tr "File changed on disk. Reload to inspect.")) }
                      | F.Refused_input why ->
                          Some { state with overlay = Modal_form (Form.set_notice submitted why) }
                      | F.Uncertain ->
                          Some { state with overlay = Modal_form (Form.set_notice submitted (tr "File write uncertain. Reload to inspect.")) })))
        | "daily_pace_what_if" ->
            let amount_str = String.trim (Option.value ~default:"" (Form.get_text submitted "amount")) in
            if amount_str = "" then
              Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter purchase amount to simulate.")) }
            else
              (match B.parse_signed_amount state.session.book state.workspace.measure amount_str with
              | Error _ ->
                  Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Invalid amount.")) }
              | Ok quantity ->
                  if Z.leq quantity Z.zero then
                    Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter a positive amount for purchase outflow.")) }
                  else
                    match current_pace_data state with
                    | None ->
                        Some { state with overlay = Modal_form (Form.set_notice submitted "Current pace is not available to simulate.") }
                    | Some (pace, _start, _end_excl) ->
                        let remaining_days = pace.remaining_days in
                        let cur_pace = pace.daily_pace_quanta in
                        let new_avail = Z.sub pace.available_through_end quantity in
                        let new_pace = Z.ediv new_avail (Z.of_int remaining_days) in
                        let diff = Z.sub new_pace cur_pace in
                        let fmt z = B.format state.session.book pace.measure z ^ " " ^ pace.measure in
                        let diff_str = (if Z.gt diff Z.zero then "+" else "") ^ fmt diff ^ "/day" in
                        let res_msg =
                          Printf.sprintf "Simulated pace: %s/day (%s). Remaining available: %s."
                            (fmt new_pace) diff_str (fmt new_avail)
                        in
                        Some { state with overlay = Modal_form (what_if_form ~amount:amount_str ~result:res_msg state) })
        | "configure_daily_pace" ->
            let pool_loci_str = String.trim (Option.value ~default:"" (Form.get_text submitted "pool_loci")) in
            let loci = String.split_on_char ',' pool_loci_str |> List.map String.trim in
            let approved = B.approved_loci state.session.book in
            let valid = List.for_all (fun locus -> config_token locus
              && (match approved with Some ids -> List.mem locus ids | None -> false)) loci
              && List.length (List.sort_uniq String.compare loci) = List.length loci in
            if not valid then
              Some { state with overlay = Modal_form (Form.set_notice submitted
                "Choose distinct admitted Locus tokens, separated by commas.") }
            else
              let payload = Form.payload submitted in
              let expected = if payload = "missing" then Ok None
                else if String.starts_with ~prefix:"present\n" payload then
                  Ok (Some (String.sub payload 8 (String.length payload - 8)))
                else Error "Pool configuration was unreadable; reopen after repairing it." in
              let content = String.concat "" (List.map
                (fun locus -> locus ^ "\t" ^ state.workspace.measure ^ "\n") loci) in
              (match Result.bind expected (fun expected -> write_pace_pool state ~expected content) with
              | Error why -> Some { state with overlay = Modal_form (Form.set_notice submitted
                  ("Pool save not confirmed: " ^ why ^ " Reopen to inspect before retrying.")) }
              | Ok () -> Some { state with overlay = No_overlay;
                  message = "Daily Pace pool saved. Period presets unchanged." })
        | _ -> Some state))
    | No_overlay -> (
        let key = match input with `Key (key, mods) -> Some (key, mods) | _ -> None in
        let normalize (key, mods) =
          match key with `ASCII c -> (`ASCII (Char.lowercase_ascii c), mods) | _ -> (key, mods)
        in
        match Option.map normalize key with
        | Some (`ASCII 'q', [ `Ctrl ]) -> None
        | Some (`ASCII 'r', [ `Ctrl ]) -> Some (reload state)
        | Some (`ASCII 'n', [ `Ctrl ]) -> Some (discard state)
        | _ when state.workspace.route = W.Actual -> (
            match input with
            | `Key (`ASCII ' ', []) when not (Act.search_editing state.actual_workspace) ->
                Some { state with overlay = Commands M.initial }
            | `Key (`ASCII ('c' | 'C' | 'e' | 'E'), []) when not (Act.search_editing state.actual_workspace) ->
                Some (edit_selected state)
            | `Key (`ASCII ('x' | 'X'), []) when not (Act.search_editing state.actual_workspace) ->
                Some (reverse_entry_selected state)
            | `Key (`ASCII ('d' | 'D'), []) when not (Act.search_editing state.actual_workspace) ->
                Some (correct_date_selected state)
            | _ ->
                let actual_dim = actual_dimensions ~dimensions ~width_of state in
                let next_ws, cmd =
                  Act.handle ~book:state.session.book ~dimensions:actual_dim ~width_of state.actual_workspace input
                in
                let state =
                  sync_actual_to_workspace
                    { state with actual_workspace = next_ws; message = Act.notice next_ws }
                in
                (match cmd with
                | Act.Stay -> Some state
                | Act.Open_selected entry ->
                    let drilled = open_route state (W.Selected_day entry.day) in
                    Some { drilled with drill_parent = Some W.Actual; drill_book = Some state.session.book }
                | Act.Record_new -> Some (open_record state)
                | Act.Back -> Some (open_route state W.Home)
                | Act.Redraw -> Some state))
        | Some (`ASCII ' ', []) -> Some { state with overlay = Commands M.initial }
        | Some (`Uchar c, []) when Uchar.to_int c = 32 ->
            Some { state with overlay = Commands M.initial }
        | Some ((`Escape | `ASCII 'q'), []) when state.workspace.route = W.Home ->
            None
        | Some (`ASCII 'g', []) when state.workspace.route = W.Home ->
            Some (open_route state W.Calendar)
        | Some (`Enter, []) when state.workspace.route = W.Home ->
            Some (open_route state W.Calendar)
        | Some (`ASCII 'g', []) when state.workspace.route = W.Calendar ->
            Some (open_route state W.Home)
        | Some (`ASCII 'g', []) when (match state.workspace.route with W.Selected_day _ -> true | _ -> false) ->
            Some (open_route state W.Loci)
        | Some ((`Escape | `ASCII 'q'), []) ->
            if state.workspace.route = W.Attention || state.workspace.route = W.Loci || state.workspace.route = W.Settlements then
              Some (open_route state W.Home)
            else if state.workspace.route = W.Calendar then
              if state.workspace.pane = W.Detail then
                Some { state with workspace = { state.workspace with pane = W.Calendar }; scroll = 0 }
              else if fst (Option.get key) = `Escape && state.workspace.calendar.zoom <> Cal.Day then
                Some
                  (sync
                     {
                       state with
                       workspace =
                         {
                           state.workspace with
                           calendar =
                             {
                               state.workspace.calendar with
                               zoom =
                                 (match state.workspace.calendar.zoom with
                                 | Cal.Year -> Cal.Month
                                 | Cal.Month -> Cal.Day
                                 | Cal.Day -> Cal.Day);
                             };
                         };
                     })
              else Some (open_route state W.Home)
            else Some (back state)
        | Some (`ASCII 'w', []) when state.workspace.route = W.Daily_pace ->
            Some { state with overlay = Modal_form (what_if_form state) }
        | Some (`ASCII 'c', []) when state.workspace.route = W.Daily_pace ->
            Some { state with overlay = Modal_form (configure_pace_form state) }
        | Some (`ASCII 'b', []) when (match state.workspace.route with
            | W.Scheduled | W.Selected_day _ -> true | _ -> false) ->
            Some (batch_plan_selected state)
        | Some (`ASCII 'v', []) when state.workspace.route = W.Scheduled ->
            Some (sync { state with workspace = W.toggle_schedule_view ~book:state.session.book state.workspace;
              message = (if state.blocked then state.message else "") })
        | Some ((`ASCII 'h' | `Arrow `Left | `ASCII 'l' | `Arrow `Right), [])
          when is_scheduled_months state && state.workspace.pane = W.Calendar ->
            let delta = match Option.map normalize key with
              | Some ((`ASCII 'h' | `Arrow `Left), _) -> -1 | _ -> 1 in
            (match Months.shift state.workspace.months delta with
             | Ok months -> Some { state with workspace = { state.workspace with months } }
             | Error message -> Some { state with message = (if state.blocked then state.message else message) })
        | Some (`ASCII ('f' | '/'), []) when is_scheduled_months state ->
            Some { state with message = (if state.blocked then state.message else
              "Months uses all current-open plans; v opens filtered List.") }
        | Some (`Enter, []) when is_scheduled_months state -> Some (pay_selected state)
        | Some (`ASCII 'r', []) when is_scheduled_months state -> Some (edit_selected state)
        | Some ((`ASCII ('h' | 'l') | `Arrow (`Left | `Right)), [])
          when is_record_browser state ->
            Some { state with workspace = { state.workspace with
              pane = (if state.workspace.pane = W.Calendar then W.Detail else W.Calendar) } }
        | Some ((`Home | `End | `Page _ | `ASCII ('j' | 'k') | `Arrow (`Up | `Down)), [])
        | Some (`ASCII ('u' | 'd'), [ `Ctrl ]) when is_record_browser state ->
            let height, view = browser_viewport ~dimensions ~width_of state in
            let detail = state.workspace.pane = W.Detail in
            let page = max 1 (if detail then view.capacity else if is_scheduled_months state then 8 else
              Panel.capacity ~height ~heading:(state.workspace.route = W.Actual)) in
            let delta = match Option.map normalize key with
              | Some (`Home, _) -> -max_int
              | Some (`End, _) -> max_int
              | Some (`Page `Up, _) | Some (`ASCII 'u', [ `Ctrl ]) -> -page
              | Some (`Page `Down, _) | Some (`ASCII 'd', [ `Ctrl ]) -> page
              | Some ((`ASCII 'k' | `Arrow `Up), _) -> -1
              | _ -> 1 in
            if detail then
              Some { state with scroll = Panel.move ~last:view.last ~position:view.start delta }
            else Some { state with scroll = 0;
              workspace = W.move_selection ~book:state.session.book state.workspace delta }
        | Some ((`Tab | `ASCII 'w'), []) | Some (`Tab, [ `Shift ]) ->
            Some
              {
                state with
                workspace =
                  {
                    state.workspace with
                    pane = (if state.workspace.pane = W.Calendar then W.Detail else W.Calendar);
                  };
                scroll = (if is_record_browser state then state.scroll else 0);
              }
        | Some (`ASCII 't', []) when state.workspace.route = W.Calendar ->
            Some (update_calendar state (Cal.Today (F.today ())))
        | Some (`ASCII 'z', []) when state.workspace.route = W.Calendar ->
            Some (update_calendar state Cal.Cycle_zoom)
        | Some (`ASCII '/', []) ->
            Some
              {
                state with
                overlay = (if state.workspace.route = W.Calendar then Jump ""
                  else Search (W.browser state.workspace).query);
              }
        | Some (`ASCII 'n', []) when state.workspace.route = W.Attention ->
            Some { state with overlay = Modal_form (add_attention_form ~today:(F.today ())) }
        | Some (`ASCII 'r', []) when state.workspace.route = W.Attention -> (
            match selected_attention state with
            | None -> Some { state with message = tr "No attention item selected to resolve." }
            | Some item -> Some { state with overlay = Modal_form (resolve_attention_form ~today:(F.today ()) item) })
        | Some (`ASCII 'x', []) when state.workspace.route = W.Attention -> (
            match selected_attention state with
            | None -> Some { state with message = tr "No attention item selected to drop." }
            | Some item -> Some { state with overlay = Modal_form (drop_attention_form ~today:(F.today ()) item) })
        | Some (`ASCII 'n', []) when state.workspace.route = W.Loci ->
            let count = List.length (admitted_loci state) in
            Some { state with overlay = Modal_form (admit_locus_form ~count) }
        | Some (`ASCII 'r', []) when state.workspace.route = W.Loci -> (
            match selected_locus state with
            | None -> Some { state with message = tr "No locus selected." }
            | Some locus ->
                let roles = accounting_roles state in
                let current_role = List.assoc_opt locus roles in
                Some { state with overlay = Modal_form (set_locus_role_form ~locus ~current_role) })
        | Some (`ASCII 'n', []) when state.workspace.route = W.Settlements ->
            Some { state with overlay = Modal_form (add_settlement_form state) }
        | Some (`ASCII 'a', []) when state.workspace.route = W.Settlements -> (
            match selected_settlement state with
            | None -> Some { state with message = tr "No commitment selected." }
            | Some r -> Some { state with overlay = Modal_form (action_settlement_form r) })
        | Some (`ASCII 's', []) when state.workspace.route = W.Settlements ->
            Some (cycle_settlement_scope state)
        | Some (`ASCII 'r', []) | Some (`ASCII 'n', [])
          when state.workspace.route = W.Scheduled ->
            Some (open_plan_record state)
        | Some (`ASCII 'r', []) | Some (`ASCII 'n', []) -> Some (open_record state)
        | Some (`ASCII 'a', []) when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_route state W.Actual)
        | Some (`ASCII 's', []) when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_route state W.Scheduled)
        | Some (`ASCII 'b', []) when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_route state W.Balances)
        | Some (`ASCII 'd', []) when (match state.workspace.route with W.Selected_day _ -> true | _ -> false) ->
            Some (correct_date_selected state)
        | Some (`ASCII 'd', []) when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_route state W.Daily_pace)
        | Some (`ASCII 'i', []) when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_route state W.Attention)
        | Some (`ASCII 'o', [])
          when state.workspace.route = W.Home || state.workspace.route = W.Balances || state.workspace.route = W.Calendar ->
            let default_locus, default_measure, current_amount =
              if state.workspace.route = W.Balances then
                let items = balance_items state in
                match List.nth_opt items state.workspace.balance_selected with
                | Some (O.Account_row { locus; measure; value; _ }) ->
                    let amt_str =
                      match value with
                      | O.Exact n -> Some (B.format state.session.book measure n)
                      | _ -> None
                    in
                    (Some locus, Some measure, amt_str)
                | _ -> (None, None, None)
              else (None, None, None)
            in
            let form = observe_quantity_form ?default_locus ?default_measure ?current_amount state in
            let form =
              if default_locus <> None then
                Form.set_focused form (Form.find_field_index form "amount")
              else form
            in
            Some { state with overlay = Modal_form form }
        | Some (`ASCII 'v', []) when state.workspace.route = W.Balances ->
            let next_mode =
              match state.balance_mode with
              | `Accounting -> `Current
              | `Current -> `Accounting
            in
            let msg =
              match next_mode with
              | `Accounting -> "Switched to Accounting view (Balance Sheet & Net Worth)."
              | `Current -> "Switched to Current view (Neutral coordinates)."
            in
            Some { state with balance_mode = next_mode; message = msg; workspace = { state.workspace with balance_selected = 0 } }
        | Some (`ASCII 'p', []) when state.workspace.route = W.Balances ->
            Some { state with overlay = Modal_form (balance_print_preview state) }
        | Some (`ASCII 's', []) when state.workspace.route = W.Actual ->
            Some (sync { state with workspace = W.cycle_order state.workspace })
        | Some (`ASCII 'f', [])
          when state.workspace.route = W.Actual || state.workspace.route = W.Scheduled ->
            Some (sync { state with workspace = W.toggle_day_filter state.workspace })
        | Some (`ASCII 'x', []) when state.workspace.route = W.Scheduled ->
            Some (cancel_plan_selected state)
        | Some (`ASCII 'x', []) when state.workspace.route = W.Actual ->
            Some (reverse_entry_selected state)
        | Some (`ASCII 'x', []) -> (
            match selected state with
            | Some (W.Scheduled_plan _) -> Some (cancel_plan_selected state)
            | Some (W.Actual_entry _) -> Some (reverse_entry_selected state)
            | _ -> Some state)
        | Some (`ASCII 'c', []) when state.workspace.route = W.Scheduled ->
            Some (pay_selected state)
        | Some (`ASCII 'e', []) when state.workspace.route = W.Scheduled ->
            Some (edit_selected state)
        | Some (`ASCII 'c', []) | Some (`ASCII 'e', []) | Some (`ASCII 'e', [ `Ctrl ]) ->
            Some (edit_selected state)
        | Some (`ASCII 'i', []) ->
            Some { state with workspace = { state.workspace with pane = W.Detail }; scroll = 0 }
        | Some (`Enter, []) ->
            if state.workspace.route = W.Calendar && state.workspace.pane = W.Calendar then
              Some (update_calendar state Cal.Drill)
            else if state.workspace.route = W.Calendar then
              match selected state with
              | None -> Some state
              | Some row -> Some (open_route state (W.Selected_day (W.date row)))
            else
              Some { state with workspace = { state.workspace with pane = W.Detail }; scroll = 0 }
        | (Some ((`ASCII 'h' | `Arrow `Left), []) | Some ((`ASCII 'l' | `Arrow `Right), []))
          when state.workspace.route = W.Calendar && state.workspace.pane = W.Calendar ->
            let action =
              match Option.get key with
              | (`ASCII 'h' | `Arrow `Left), _ -> Cal.Left
              | _ -> Cal.Right
            in
            Some (update_calendar state action)
        | Some ((`ASCII 'k' | `Arrow `Up), []) | Some ((`ASCII 'j' | `Arrow `Down), []) ->
            let delta =
              match Option.map normalize key with
              | Some ((`ASCII 'k' | `Arrow `Up), _) -> -1
              | _ -> 1
            in
            if state.workspace.route = W.Calendar && state.workspace.pane = W.Calendar then
              Some (update_calendar state (if delta < 0 then Cal.Up else Cal.Down))
            else if state.workspace.pane = W.Detail && state.workspace.route <> W.Calendar && state.workspace.route <> W.Home then
              Some { state with scroll = max 0 (state.scroll + delta) }
            else if state.workspace.route = W.Balances then
              let count = List.length (balance_items state) in
              Some
                {
                  state with
                  workspace =
                    {
                      state.workspace with
                      balance_selected =
                        max 0 (min (max 0 (count - 1)) (state.workspace.balance_selected + delta));
                    };
                }
            else if state.workspace.route = W.Attention then
              Some (move_attention state delta)
            else if state.workspace.route = W.Loci then
              Some (move_locus state delta)
            else if state.workspace.route = W.Settlements then
              Some (move_settlement state delta)
            else
              Some
                {
                  state with
                  workspace = W.move_selection ~book:state.session.book state.workspace delta;
                  scroll = 0;
                }
        | Some (`Page _, []) | Some (`ASCII ('u' | 'd'), [ `Ctrl ]) ->
            let delta =
              match Option.map normalize key with
              | Some (`Page `Up, _) | Some (`ASCII 'u', _) -> -1
              | _ -> 1
            in
            let step = delta * max 1 (snd dimensions - 8) in
            if
              state.workspace.pane = W.Calendar && state.workspace.route <> W.Home
              && state.workspace.route <> W.Balances
              && state.workspace.route <> W.Daily_pace
              || (state.workspace.route = W.Home && state.workspace.pane = W.Detail)
            then
              Some
                {
                  state with
                  workspace = W.move_selection ~book:state.session.book state.workspace step;
                  scroll = 0;
                }
            else Some { state with scroll = max 0 (state.scroll + step) }
        | Some (`Home, []) ->
            Some
              {
                state with
                scroll = 0;
                workspace = W.move_selection ~book:state.session.book state.workspace (-max_int);
              }
        | Some (`End, []) ->
            Some
              {
                state with
                scroll = max_int / 4;
                workspace = W.move_selection ~book:state.session.book state.workspace max_int;
              }
        | _ -> ( match input with `End -> None | _ -> Some state))

let row_title book = function
  | W.Actual_entry entry ->
      let amount =
        match entry.B.effects with
        | [ a; b ] when D.Identifier.Measure.equal (D.Effect.measure a) (D.Effect.measure b) ->
            let positive = if Z.sign (A.quanta a) > 0 then a else b in
            let measure = A.mstr (D.Effect.measure positive) in
            let amount = B.format book measure (A.quanta positive) in
            if String.length amount > 20 then tr "see details" else amount ^ " " ^ measure
        | _ -> tr "split / see details"
      in
      entry.day ^ "  " ^ Option.value ~default:"(no description)" entry.memo ^ "  " ^ amount
  | W.Scheduled_plan plan ->
      let total =
        List.fold_left
          (fun n (_, v) -> if Z.sign v > 0 then Z.add n v else n)
          Z.zero plan.changes
      in
      let status =
        if plan.paid_by <> None then "[Paid]"
        else if plan.cancelled_on <> None then "[Cancelled]"
        else "[Open]"
      in
      let amt = B.format book plan.measure total in
      plan.day ^ "  " ^ plan.id ^ "  " ^ amt ^ " " ^ plan.measure ^ "  " ^ status

let actual_amount book (entry : B.entry) =
  let format p =
    let measure = A.mstr (D.Effect.measure p) and quanta = A.quanta p in
    let amount = B.format book measure (Z.abs quanta) in
    let parts = String.split_on_char '.' amount in
    let whole = List.hd parts in
    let grouped = Buffer.create (String.length amount + 16) in
    String.iteri (fun i c ->
      if i > 0 && (String.length whole - i) mod 3 = 0 then Buffer.add_char grouped ',';
      Buffer.add_char grouped c) whole;
    (if Z.sign quanta < 0 then "-" else if Z.sign quanta > 0 then "+" else "")
    ^ Buffer.contents grouped
    ^ (match List.tl parts with [] -> "" | xs -> "." ^ String.concat "." xs)
    ^ " " ^ measure in
  let measures = List.sort_uniq String.compare
    (List.map (fun p -> A.mstr (D.Effect.measure p)) entry.effects) in
  let positive = List.filter (fun p -> Z.sign (A.quanta p) > 0) entry.effects
  and negative = List.filter (fun p -> Z.sign (A.quanta p) < 0) entry.effects in
  if List.length measures > 1 then Printf.sprintf "multi (%d)" (List.length measures)
  else if List.length positive > 1 || List.length negative > 1 then "split"
  else match positive, entry.effects with
    | p :: _, _ | [], [p] -> format p
    | [], [] -> "—"
    | [], _ -> "see details"

let actual_table ~width_of ~width book rows =
  let room = max 0 (width - 6) in
  let amount_width = min 22 (max 12 (List.fold_left (fun n row ->
    match row with W.Actual_entry e -> max n (width_of (actual_amount book e))
    | _ -> n) 0 rows)) in
  let table date description amount =
    if room < 40 then O.pad ~width_of room description
    else
      let amount = if width_of amount <= amount_width then amount else "see details" in
      O.pad ~width_of 10 date ^ "  "
      ^ O.pad ~width_of (room - 14 - amount_width) description ^ "  "
      ^ String.make (max 0 (amount_width - width_of amount)) ' ' ^ amount in
  let titles = List.map (function
    | W.Actual_entry e -> table e.day (Option.value ~default:"(no description)" e.memo)
        (actual_amount book e)
    | row -> row_title book row) rows in
  ("  " ^ table "Date" "Description" "Amount", titles)

let calendar_rows ?(width = 80) state =
  let calendar = state.workspace.calendar and book = state.session.book in
  let actuals = B.entries book and scheduled = B.open_plans book in
  let count prefix =
    ( List.length (List.filter (fun (e : B.entry) -> String.starts_with ~prefix e.day) actuals),
      List.length (List.filter (fun (p : B.plan) -> String.starts_with ~prefix p.day) scheduled) )
  in
  let cell width value = value ^ String.make (max 0 (width - String.length value)) ' ' in
  let today = F.today () in
  let names =
    [| "Jan"; "Feb"; "Mar"; "Apr"; "May"; "Jun"; "Jul"; "Aug"; "Sep"; "Oct"; "Nov"; "Dec" |]
  in
  match calendar.Cal.zoom with
  | Cal.Day ->
      let room = max 0 (width - 6) in
      let compact = room < 49 in
      let cell_width = if room >= 49 then 7 else if room >= 35 then 5 else 3 in
      let slots = get (Cal.month_slots calendar.selected_day) in
      let rec weeks = function
        | [] -> []
        | xs ->
            let week = List.filteri (fun i _ -> i < 7) xs in
            let rest = List.filteri (fun i _ -> i >= 7) xs in
            let dates =
              List.map
                (function
                  | None -> String.make cell_width ' '
                  | Some day ->
                      let actual, planned = count day in
                      let dd = String.sub day 8 2 in
                      let chosen = day = calendar.selected_day in
                      let label = if chosen then "[" ^ dd ^ "]" else if compact then dd else " " ^ dd in
                      let today_mark =
                        if day = today && (not chosen || room >= (7 * cell_width) + 2) then "*"
                        else if compact && chosen then "" else " "
                      in
                      cell cell_width
                        (label ^ today_mark
                         ^ (if compact then "" else (if actual > 0 then "a" else " ") ^ (if planned > 0 then "s" else " "))))
                week
            in
            String.concat "" dates :: weeks rest
      in
      if room < 22 then
        [ "[" ^ String.sub calendar.selected_day 8 2 ^ "] " ^ calendar.selected_day ]
      else
      [ String.concat "" (List.map (cell cell_width)
            (if cell_width = 3 then [ "Mo"; "Tu"; "We"; "Th"; "Fr"; "Sa"; "Su" ]
             else [ "Mon"; "Tue"; "Wed"; "Thu"; "Fri"; "Sat"; "Sun" ])) ]
      @ weeks slots
      @ [ tr (if compact then "[ ] selected   * today" else "a Actual   s open Scheduled   * today") ]
  | Cal.Month ->
      let year = String.sub calendar.selected_day 0 4 in
      if width < 64 then
        List.init 12 (fun i ->
            let prefix = Printf.sprintf "%s-%02d" year (i + 1) in
            let actual, planned = count prefix in
            Printf.sprintf "%s%02d %s    A%d S%d"
              (if String.starts_with ~prefix calendar.selected_day then "> " else "  ")
              (i + 1) names.(i) actual planned)
      else List.init 4 (fun quarter ->
          List.init 3 (fun column ->
              let i = (quarter * 3) + column in
              let prefix = Printf.sprintf "%s-%02d" year (i + 1) in
              let actual, planned = count prefix in
              let label = Printf.sprintf "%02d %s" (i + 1) names.(i) in
              let label = if String.starts_with ~prefix calendar.selected_day then "[" ^ label ^ "]" else " " ^ label ^ " " in
              cell 19 (Printf.sprintf "%s A%d S%d" label actual planned))
          |> String.concat "")
      @ [ ""; tr "A Actual   S open Scheduled" ]
  | Cal.Year ->
      let year = int_of_string (String.sub calendar.selected_day 0 4) in
      List.init 5 (fun i -> year + i - 2)
      |> List.filter (fun y -> y >= 1 && y <= 9999)
      |> List.map (fun y ->
          let prefix = Printf.sprintf "%04d" y in
          let actual, planned = count prefix in
          Printf.sprintf "%s%s    A%d  S%d" (if y = year then "> " else "  ") prefix actual planned)

let pace_lines state =
  let measure = state.workspace.measure in
  match current_pace_result state with
  | Error why -> [ tr "Daily Pace unavailable (not zero):"; why;
      "Supply an explicit daily-pace.tsv pool and boundary-presets.tsv period.";
      "Historical Trend is unavailable." ]
  | Ok (pace, start_day, end_exclusive) ->
          let amount n = B.format state.session.book measure n ^ " " ^ measure in
          let total_period_days =
            let day_num y m d =
              let prior = y - 1 in
              let before = [| 0; 0; 31; 59; 90; 120; 151; 181; 212; 243; 273; 304; 334 |] in
              (prior * 365) + (prior / 4) - (prior / 100) + (prior / 400) + before.(m)
              + (if m > 2 && A.is_leap_year y then 1 else 0)
              + d - 1
            in
            match (Cal.parts start_day, Cal.parts end_exclusive) with
            | Ok (y1, m1, d1), Ok (y2, m2, d2) ->
                let j1 = day_num y1 m1 d1 and j2 = day_num y2 m2 d2 in
                max 1 (j2 - j1)
            | _ -> max 1 pace.remaining_days
          in
          let elapsed_days = max 0 (total_period_days - pace.remaining_days) in
          let progress_ratio = float_of_int elapsed_days /. float_of_int total_period_days in
          let bar = O.progress_bar ~width:28 ~ratio:progress_ratio in
          let pool_origin = "config/daily-pace.tsv" in
          let window_origin = "config/boundary-presets.tsv" in
          [
            Printf.sprintf "Daily Pace: %s / day" (amount pace.daily_pace_quanta);
            "";
            Printf.sprintf "Period progress: %s %d/%d days" bar elapsed_days total_period_days;
            Printf.sprintf "Through end: %s (Available)" (amount pace.available_through_end);
            Printf.sprintf "Days remaining: %d days  (Observed: %s -> End: %s)"
              pace.remaining_days pace.observed_at pace.end_exclusive;
            Printf.sprintf "Source: Pool [%s] | Window [%s]" pool_origin window_origin;
            "";
            "Eligible Pool:";
          ]
          @ (if pace.pool_balances = [] then [ "  (none)" ]
             else
               List.map
                 (fun (coordinate, n) ->
                   let locus = A.lstr coordinate.D.Effect_coordinate.locus in
                   let label = B.label state.session.book locus in
                   let name = if label <> "" && label <> locus then Printf.sprintf "%s [%s]" label locus else locus in
                   Printf.sprintf "  %-24s %s" name (amount n))
                 pace.pool_balances)
          @ [ ""; "Scheduled Deductions:" ]
          @ (if pace.plan_deductions = [] then [ "  (no upcoming deductions)" ]
             else
               List.map
                 (fun (id, n) -> Printf.sprintf "  %-24s -%s" ("Plan " ^ id) (amount n))
                 pace.plan_deductions)
          @ [ ""; "Net Pool: " ^ amount pace.eligible_pool;
              "Total Deductions: -" ^ amount pace.automatic_deductions ]

let pace_detail_lines state =
  let today = F.today () and measure = state.workspace.measure in
  match resolve_pace_window state with
  | Error why ->
      [
        "Daily Pace Configuration Guide";
        why;
        "";
        "Files required or generated in config directory:";
        "";
        "1. daily-pace.tsv:";
        "   Locus<TAB>Measure";
        "   Example: wallet<TAB>jpy";
        "";
        "2. boundary-presets.tsv:";
        "   Preset<TAB>Date<TAB>Date...";
        "   Example: month<TAB>2026-10-01<TAB>2026-11-01";
        "";
        "Press 'c' to configure pool accounts only; period presets are preserved.";
        "";
        "Daily Pace divides eligible pool minus scheduled obligations";
        "by the remaining calendar days until exclusive period end.";
      ]
  | Ok (start_day, end_exclusive) ->
      let pool_origin = match resolve_pace_pool state with
        | Ok _ -> "configured (daily-pace.tsv)" | Error why -> why in
      let window_origin = "configured (boundary-presets.tsv)" in
      [
        "Daily Pace Calculation & Evidence";
        "";
        "Formula:";
        "  Daily Pace = Available Through End / Remaining Days";
        "  Available Through End = Eligible Pool - Open Deductions";
        "";
        "Period Window:";
        "  Start date: " ^ start_day;
        "  End date (exclusive): " ^ end_exclusive;
        "  Observed as of: " ^ today;
        "  Measure: " ^ measure;
        "";
        "Configuration Status:";
        "  Pool source: " ^ pool_origin;
        "  Window source: " ^ window_origin;
        "";
        "Actions:";
        "  Press 'w' to simulate a purchase scenario (What-If).";
        "  Press 'c' to configure pool loci; period presets remain unchanged.";
        "";
        "Integrity & Principles:";
        "  - Current evidence reconstruction only.";
        "  - No speculative spending or trend projection is inferred.";
        "  - Past pacing or historical velocity is unavailable.";
        "  - Distinct currency balances are never cross-converted.";
      ]


let workspace_rows ~width_of ~width ~height state =
  let draw_frame = Panel.frame in
  let book = state.session.book and workspace = state.workspace in
  let rows = W.rows ~book workspace in
  let titles = List.map (row_title book) rows in
  let title =
    match workspace.W.route with
    | W.Home -> "Home"
    | W.Calendar -> "Calendar / Month flow"
    | W.Selected_day day -> "Household Day Workspace / " ^ day
    | W.Actual -> "Actual"
    | W.Scheduled -> "Scheduled / List"
    | W.Balances ->
        (match state.balance_mode with
        | `Accounting -> "Balances / Current [Accounting]"
        | `Current -> "Balances / Current [Neutral]")
    | W.Daily_pace -> "Daily Pace"
    | W.Attention -> "Attention / Household matters"
    | W.Loci -> "Manage Loci / Admitted vocabulary"
    | W.Settlements -> "Settlements / Reimbursements"
  in
  let pad rows = rows @ List.init (max 0 (height - List.length rows)) (fun _ -> (Plain, "")) in
  let split_pane ?left_heading ~left_focused ~left_title ~left_scroll ~left_selected ~left_rows
      ~right_focused ~right_title ~right_scroll ~right_selected ~right_rows () =
    if width >= 80 then
      let left_width, right_width = browser_pane_widths width in
      let left_panel =
        draw_frame ?heading:left_heading ~width_of ~width:left_width ~height ~focused:left_focused
          ~title:left_title ~scroll:left_scroll ~selected:left_selected left_rows
      in
      let right_panel =
        draw_frame ~width_of ~width:right_width ~height ~focused:right_focused
          ~title:right_title ~scroll:right_scroll ~selected:right_selected right_rows
      in
      pad (List.map2 (fun (style_l, text_l) (style_r, text_r) ->
          (Columns (left_width, style_l, style_r), text_l ^ " " ^ text_r)) left_panel right_panel)
    else
      if right_focused then
        draw_frame ~width_of ~width ~height ~focused:true
          ~title:right_title ~scroll:right_scroll ~selected:right_selected right_rows
      else
        draw_frame ~width_of ~width ~height ~focused:true
          ?heading:left_heading ~title:left_title ~scroll:left_scroll ~selected:left_selected left_rows
  in
  if workspace.route = W.Home then
    O.bonsai_home_lines ~width ~height ~width_of ~today:(F.today ())
  else if workspace.route = W.Calendar then
    let calendar_focused = workspace.pane = W.Calendar in
    let detail =
      let actual = List.length (List.filter (function W.Actual_entry _ -> true | _ -> false) rows) in
      let scheduled = List.length rows - actual in
      Printf.sprintf "Actual %d   Open Scheduled %d" actual scheduled
      :: (if titles = [] then [ tr "No records in this period." ] else titles)
      @ [ tr "Flow unavailable: classification not supplied." ]
    in
    let period =
      let n = match workspace.calendar.zoom with Cal.Day -> 10 | Cal.Month -> 7 | Cal.Year -> 4 in
      String.sub workspace.calendar.selected_day 0 n
    in
    let calendar_frame ~width ~height =
      let calendar = calendar_rows ~width state in
      let selected = match workspace.calendar.zoom with
        | Cal.Month when width < 64 -> Some (int_of_string (String.sub workspace.calendar.selected_day 5 2) - 1)
        | Cal.Year -> Some (min 2 (int_of_string (String.sub workspace.calendar.selected_day 0 4) - 1))
        | Cal.Day | Cal.Month -> None
      in
      let scroll =
        if workspace.calendar.zoom <> Cal.Day || state.scroll <> 0 then state.scroll
        else
          let first = String.sub workspace.calendar.selected_day 0 8 ^ "01" in
          let week =
            (get (Cal.weekday first) + int_of_string (String.sub workspace.calendar.selected_day 8 2) - 1) / 7
          in
          max 0 (1 + week - max 1 (height - 2) + 1)
      in
      let result = draw_frame ~width_of ~width ~height ~focused:calendar_focused
          ~title:("Calendar / " ^ String.sub workspace.calendar.selected_day 0 (if workspace.calendar.zoom = Cal.Day then 7 else 4))
          ~scroll ~selected calendar in
      let marker = "[" ^ String.sub workspace.calendar.selected_day 8 2 ^ "]" in
      List.map (fun (style, text) ->
          if calendar_focused && workspace.calendar.zoom = Cal.Day && style = Plain
             && Base.String.is_substring text ~substring:marker
          then (Calendar_dates, text) else (style, text)) result
    in
    let detail_frame ~width ~height =
      draw_frame ~width_of ~width ~height ~focused:(not calendar_focused)
        ~title:("Detail / " ^ period) ~scroll:0
        ~selected:(if rows = [] then None else Some ((W.browser workspace).selected + 1)) detail
    in
    if width >= 120 then
      let left = 64 and right = width - 65 in
      let natural = List.length (calendar_rows ~width:left state) + 2 in
      let pane_height = min height (max natural (min 12 (List.length detail + 2))) in
      let left_rows = calendar_frame ~width:left ~height:pane_height in
      let right_rows = detail_frame ~width:right ~height:pane_height in
      pad (List.map2 (fun (style, left_text) (right_style, right_text) ->
          (Columns (left, style, right_style), left_text ^ " " ^ right_text)) left_rows right_rows)
    else
      let natural = List.length (calendar_rows ~width state) + 2 in
      if width >= 72 && height >= natural + 6 then
        let calendar_height = natural in
        calendar_frame ~width ~height:calendar_height
        @ [ (Plain, "") ]
        @ detail_frame ~width ~height:(height - calendar_height - 1)
      else if calendar_focused then calendar_frame ~width ~height
      else detail_frame ~width ~height
  else if workspace.route = W.Balances then
    let items = balance_items state in
    let lines = balance_lines state in
    let detail =
      match List.nth_opt items workspace.balance_selected with
      | None -> [ tr "No supplied Locus / Measure coordinates." ]
      | Some item -> O.balance_item_detail ~book item
    in
    let right_width = if width >= 80 then width - max 36 (min 58 (width * 52 / 100)) - 1 else width in
    let wrapped_detail = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) detail in
    let is_detail = workspace.pane = W.Detail in
    split_pane
      ~left_focused:(not is_detail) ~left_title:title ~left_scroll:0
      ~left_selected:(if lines = [] then None else Some workspace.balance_selected)
      ~left_rows:(if lines = [] then [ tr "No records in this view." ] else lines)
      ~right_focused:is_detail ~right_title:"Selected Balance"
      ~right_scroll:state.scroll ~right_selected:None ~right_rows:wrapped_detail ()
  else if workspace.route = W.Daily_pace then
    let left_title = "Daily Pace / Current" in
    let right_title = "Pace Detail & Evidence" in
    let left_rows = pace_lines state in
    let right_rows = pace_detail_lines state in
    let is_detail = workspace.pane = W.Detail in
    let right_width = if width >= 80 then width - max 36 (min 58 (width * 52 / 100)) - 1 else width in
    let wrapped_detail = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) right_rows in
    split_pane
      ~left_focused:(not is_detail) ~left_title ~left_scroll:0
      ~left_selected:None ~left_rows
      ~right_focused:is_detail ~right_title
      ~right_scroll:state.scroll ~right_selected:None ~right_rows:wrapped_detail ()
  else if workspace.route = W.Attention then
    let items = open_attentions state in
    let left_title = match state.attention with
      | Ok _ -> Printf.sprintf "Attention (%d open)" (List.length items)
      | Error _ -> "Attention / Unavailable" in
    let right_title = "Attention Detail" in
    let item_line (item : Att.item) =
      let due_str =
        match item.due with
        | Att.Due_on d -> d
        | Att.No_due_date -> "-"
        | Att.Due_undetermined -> "?"
      in
      Printf.sprintf "%-4s  %-10s  %s" item.id due_str item.context
    in
    let left_rows = match state.attention with
      | Error why -> O.wrap_text ~width_of (max 1 (width / 2 - 6))
          ("Attention unavailable: " ^ why ^ ". Writes refused; Ctrl-R reloads.")
      | Ok _ -> if items = [] then [ tr "No open attention items." ] else List.map item_line items
    in
    let detail =
      match state.attention, selected_attention state with
      | Error why, _ -> [ "Attention unavailable (not empty)."; why; "Writes refused; Ctrl-R reloads." ]
      | Ok _, None -> [ tr "No selected attention item."; ""; tr "Press 'n' to add a household matter." ]
      | Ok _, Some item ->
          [
            "Item ID:    " ^ item.id;
            "Status:     Open";
            "Due:        " ^ Att.due_label item.due;
            "";
            "Context / Description:";
            "  " ^ item.context;
            "";
            "Actions:";
            "  n : Add new attention item";
            "  r : Resolve this item";
            "  x : Drop this item";
          ]
    in
    let right_width = if width >= 80 then width - max 36 (min 58 (width * 52 / 100)) - 1 else width in
    let wrapped_detail = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) detail in
    let is_detail = workspace.pane = W.Detail in
    split_pane
      ~left_focused:(not is_detail) ~left_title ~left_scroll:0
      ~left_selected:(if items = [] then None else Some workspace.attention.selected)
      ~left_rows
      ~right_focused:is_detail ~right_title
      ~right_scroll:state.scroll ~right_selected:None ~right_rows:wrapped_detail ()
  else if workspace.route = W.Loci then
    let loci = admitted_loci state in
    let roles = accounting_roles state in
    let left_title = Printf.sprintf "Manage Loci (%d admitted)" (List.length loci) in
    let right_title = "Locus Detail" in
    let locus_line locus =
      let label = B.label book locus in
      let role_opt = List.assoc_opt locus roles in
      let role_tag =
        match role_opt with
        | Some r -> "[" ^ Roles.role_label r ^ "]"
        | None -> "[--]"
      in
      if label <> "" && label <> locus then
        Printf.sprintf "%-18s  %-12s  %s" locus role_tag label
      else
        Printf.sprintf "%-18s  %-12s" locus role_tag
    in
    let left_rows =
      if loci = [] then [ tr "No admitted loci in this book." ]
      else List.map locus_line loci
    in
    let detail =
      match selected_locus state with
      | None -> [ tr "No selected locus."; ""; tr "Press 'n' to admit a new coordinate token." ]
      | Some locus ->
          let label = B.label book locus in
          let role_opt = List.assoc_opt locus roles in
          let role_str = match role_opt with None -> "None / Unassigned" | Some r -> Roles.role_label r in
          let balances =
            List.map (fun (m, _) ->
              let q = O.quantity ~book ~measure:m locus in
              Printf.sprintf "  %s: %s" (String.uppercase_ascii m) q)
              (B.measures book)
          in
          [
            "Locus Token:      " ^ locus;
            "Display Label:    " ^ (if label <> "" then label else "(same as token)");
            "Accounting Role:  " ^ role_str;
            "";
            "Current Balances:";
          ]
          @ (if balances = [] then [ "  (no measures)" ] else balances)
          @ [
            "";
            "Role Impact:";
            (match role_opt with
             | Some Roles.Asset -> "  Asset: Positive balance represents owned resources."
             | Some Roles.Liability -> "  Liability: Positive balance represents debt owed."
             | Some Roles.Equity -> "  Equity: Capital / opening balance baseline."
             | Some Roles.Income -> "  Income: Inflow tracking for reporting."
             | Some Roles.Expense -> "  Expense: Outflow tracking for reporting."
             | None -> "  Unassigned: Available for general posting; excluded from role summaries.");
            "";
            "Actions:";
            "  n : Admit new Locus token";
            "  r : Set / change accounting role";
          ]
    in
    let right_width = if width >= 80 then width - max 36 (min 58 (width * 52 / 100)) - 1 else width in
    let wrapped_detail = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) detail in
    let is_detail = workspace.pane = W.Detail in
    split_pane
      ~left_focused:(not is_detail) ~left_title ~left_scroll:0
      ~left_selected:(if loci = [] then None else Some workspace.loci.selected)
      ~left_rows
      ~right_focused:is_detail ~right_title
      ~right_scroll:state.scroll ~right_selected:None ~right_rows:wrapped_detail ()
  else if workspace.route = W.Settlements then
    let rows = settlement_rows state in
    let scope_label = match state.settlement_scope with Stl.Open_only -> "Open" | Stl.All -> "All current" in
    let left_title = match state.settlements with
      | Ok _ -> Printf.sprintf "Settlements [%s] (%d)" scope_label (List.length rows)
      | Error _ -> "Settlements / Unavailable" in
    let right_title = "Commitment Details" in
    let row_line r =
      let desc = match r.Stl.label with Some l -> l | None -> r.id in
      let rem = Stl.outstanding r in
      let status = if Z.equal rem Z.zero then "done" else "" in
      let trunc_desc = if String.length desc > 22 then String.sub desc 0 19 ^ "..." else desc in
      Printf.sprintf "%-22s  %10s %-4s %s" trunc_desc (Z.to_string rem) r.measure status
    in
    let left_rows = match state.settlements with
      | Error why -> O.wrap_text ~width_of (max 1 (width / 2 - 6))
          ("Settlements unavailable: " ^ why ^ ". Writes refused; Ctrl-R reloads.")
      | Ok _ -> if rows = [] then [ tr "  (no commitments in this scope)" ] else List.map row_line rows
    in
    let detail =
      match state.settlements, selected_settlement state with
      | Error why, _ -> [ "Settlements unavailable (not empty)."; why; "Writes refused; Ctrl-R reloads." ]
      | Ok _, None -> [ tr "No selected commitment."; ""; tr "Press 'n' to add a new settlement commitment." ]
      | Ok _, Some r ->
          let rem = Stl.outstanding r in
          let desc = match r.label with Some l -> l | None -> "(no description)" in
          let effective = match r.effective_on with Some d -> d | None -> "(date unknown)" in
          [
            "Identity:    " ^ r.id;
            "Description: " ^ desc;
            "Direction:   " ^ r.debtor ^ " -> " ^ r.creditor;
            "Measure:     " ^ r.measure;
            "Committed:   " ^ Z.to_string r.committed ^ " " ^ r.measure;
            "Settled:     " ^ Z.to_string r.settled ^ " " ^ r.measure;
            "Adjusted:    " ^ Z.to_string r.extinguished ^ " " ^ r.measure;
            "Remaining:   " ^ Z.to_string rem ^ " " ^ r.measure;
            "Effective:   " ^ effective;
            "";
            "Allocations:";
            (if Z.gt r.settled Z.zero then Printf.sprintf "  Settled payment: %s %s" (Z.to_string r.settled) r.measure else "  Direct settlement: (none)");
            (if Z.gt r.extinguished Z.zero then Printf.sprintf "  Non-payment reduction: %s %s" (Z.to_string r.extinguished) r.measure else "  Reductions: (none)");
            "";
            "Actions:";
            "  a / Enter : Settlement action (Settle / Reduce / Retract)";
            "  s         : Cycle scope (Open only <-> All current)";
            "  n         : Add new settlement commitment";
          ]
    in
    let right_width = if width >= 80 then width - max 36 (min 58 (width * 52 / 100)) - 1 else width in
    let wrapped_detail = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) detail in
    let is_detail = workspace.pane = W.Detail in
    split_pane
      ~left_focused:(not is_detail) ~left_title ~left_scroll:0
      ~left_selected:(if rows = [] then None else Some workspace.settlements.selected)
      ~left_rows
      ~right_focused:is_detail ~right_title
      ~right_scroll:state.scroll ~right_selected:None ~right_rows:wrapped_detail ()
  else if workspace.route = W.Actual then
    Act.screen ~book:state.session.book ~dimensions:(width, height) ~width_of state.actual_workspace
  else if is_scheduled_months state then
    if workspace.pane = W.Detail then
      let detail = browser_detail_rows ~width_of ~width state in
      Panel.frame ~width_of ~width ~height ~focused:true ~title:"Selected Scheduled"
        ~scroll:state.scroll ~selected:None detail
    else
      let plans = List.filter_map (function W.Scheduled_plan p -> Some p | _ -> None) rows in
      let selected = match selected state with Some (W.Scheduled_plan p) -> Some p | _ -> None in
      Months.screen ~book ~plans ~dimensions:(width, height) ~width_of ~selected workspace.months
  else
    let is_detail = workspace.pane = W.Detail in
    let right_title =
      match workspace.route with
      | W.Scheduled -> "Plan Detail"
      | _ -> "Selected Record"
    in
    let _, right_width = browser_pane_widths width in
    let wrapped_detail = browser_detail_rows ~width_of ~width:right_width state in
    let list_title =
      match workspace.route with
      | W.Scheduled -> Printf.sprintf "Scheduled / List (%d)" (List.length rows)
      | W.Selected_day day -> Printf.sprintf "Day %s (%d)" day (List.length rows)
      | _ -> title
    in
    split_pane
      ~left_focused:(not is_detail) ~left_title:list_title
      ~left_scroll:(if is_detail then 0 else state.scroll)
      ~left_selected:(if titles = [] then None else Some (W.browser workspace).selected)
      ~left_rows:(if titles = [] then [ tr "No records in this view." ] else titles)
      ~right_focused:is_detail ~right_title
      ~right_scroll:(if is_detail then state.scroll else 0)
      ~right_selected:None ~right_rows:wrapped_detail ()

let footer ?(dimensions = (80, 24)) ?(width_of = String.length) state =
  match state.overlay with
  | (Reversal _ | Date_correction _ | Scheduled_cancel _) when state.blocked ->
      [ "Writes stopped; date retained"; "Ctrl-r inspect/reload  q keep" ]
  | Reversal editor -> Rev.footer editor
  | Date_correction editor -> Date.footer editor
  | Scheduled_create editor -> Sch.footer editor
  | Scheduled_cancel editor -> Cancel.footer editor
  | Scheduled_continuation prompt -> Cont.footer prompt
  | Scheduled_bulk _ when state.blocked ->
      [ "Writes stopped; batch retained"; "Ctrl-r inspect/reload  Esc cancel" ]
  | Scheduled_bulk editor -> Bulk.footer editor
  | Themes _ -> [ "j/k or Up/Down preview theme"; "Enter save  Esc/q cancel" ]
  | Modal_form form -> (
      match Form.id form with
      | "observe_quantity" ->
          [ "Enter observe  Tab next field  Esc cancel"; "Locus & Measure tokens, signed or zero amount" ]
      | "daily_pace_what_if" ->
          [ "Enter simulate scenario  Tab switch field/button  Esc close"; "Read-only simulation - does not publish any entries" ]
      | "configure_daily_pace" ->
          [ "Enter save configuration  Tab switch field  Esc cancel"; "Saves to daily-pace.tsv and boundary-presets.tsv" ]
      | _ ->
          [ "Enter submit  Tab next field  Esc cancel"; "Arrow keys / space to choose options" ])
  | No_overlay | Commands _ | Jump _ | Search _ ->
  if state.workspace.W.route = W.Actual then
    Act.footer ~dimensions ~width_of state.actual_workspace
  else if is_scheduled_months state then
    if state.workspace.pane = W.Detail then
      [ "j/k PgUp/Dn Home/End scroll  Tab Months"; "Enter/c complete  b batch  x cancel  v List  q back" ]
    else if fst dimensions < 46 then
      [ "j/k select  h/l months  v List"; "Enter complete  x cancel  q back" ]
    else
      [ "j/k select  h/l months  Enter/c complete  q back";
        "i/Tab detail  b batch  r/e edit  x cancel  n new  v List" ]
  else
  match (state.workspace.W.route, state.workspace.pane) with
  | W.Home, _ ->
      [
        " [Enter] calendar   [i] attention";
        " [Space] commands   [q] quit";
      ]
  | W.Calendar, W.Calendar ->
      [
        (match state.workspace.calendar.zoom with
         | Cal.Day -> "h/l day  j/k week  Enter open  z zoom  / jump  t today"
         | Cal.Month -> "h/l month  j/k quarter  Enter days  z zoom  / jump  t today"
         | Cal.Year -> "h/l/j/k year  Enter months  z zoom  / jump  t today");
        "q/Esc Home  Tab/w Detail  r Record  Space Commands  a/s/b/d views";
      ]
  | W.Calendar, W.Detail ->
      [
        "q/Esc Calendar  j/k select  Enter Selected Day  Tab/w pane";
        "r Record  Space Commands  a/s/b/d views";
      ]
  | W.Scheduled, W.Calendar ->
      [
        "j/k select  Enter/i/Tab Detail  h/l pane  c Complete  e Edit  x Cancel";
        "b Batch amount  v Months  n New Plan  f Filter  / search  Space Commands  q/Esc Home";
      ]
  | W.Actual, W.Calendar ->
      [
        "j/k select  Enter/i/Tab Detail  h/l pane  c Correct  x Reverse  f Day/All  s Order";
        "n Record  / search  Space Commands  q/Esc Home  Ctrl-r reload";
      ]
  | W.Scheduled, W.Detail ->
      [
        "j/k scroll  Page Up/Down page  Home/End range  h/l/Tab pane";
        "b Batch amount  v Months  q/Esc list  c Complete  e Edit  x Cancel  n New Plan  Ctrl-r reload";
      ]
  | W.Actual, W.Detail ->
      [
        "j/k scroll  Page Up/Down page  Home/End range  h/l/Tab pane";
        "q/Esc list  c Correct  x Reverse  n Record  / search  Ctrl-r reload";
      ]
  | W.Selected_day _, W.Calendar ->
      [
        "j/k select  Enter/i/Tab Detail  c Correct  d Date  x Reverse  b Batch plan  g Loci  r Record";
        (match state.drill_parent with
         | Some W.Actual -> "Space Commands  q/Esc Actual  Ctrl-r reload"
         | _ -> "Space Commands  q/Esc Home  Ctrl-r reload");
      ]
  | W.Balances, W.Calendar ->
      let v_label = match state.balance_mode with `Accounting -> "v current" | `Current -> "v accounting" in
      [
        Printf.sprintf "j/k select  Enter/i/Tab Detail  o observe  %s  p print  r record" v_label;
        "Space Commands  q/Esc Home  Ctrl-r reload";
      ]
  | W.Balances, W.Detail ->
      [
        "j/k scroll  Tab/w switch pane  o observe  r record";
        "q/Esc back to list  Space Commands  Ctrl-r reload";
      ]
  | W.Daily_pace, W.Calendar ->
      [ "w what-if  c configure  j/k scroll  Tab/w Detail  r Record"; "Space Commands  q/Esc Home  Ctrl-r reload" ]
  | W.Daily_pace, W.Detail ->
      [ "w what-if  c configure  j/k scroll  Tab/w switch pane  r Record"; "q/Esc back  Space Commands  Ctrl-r reload" ]
  | W.Attention, _ ->
      [
        "n new  r resolve  x drop  j/k select  Enter/Tab detail";
        "q/Esc Home  Space Commands  Ctrl-r reload";
      ]
  | W.Loci, _ ->
      [
        "n admit locus  r set role  j/k select  Enter/Tab detail";
        "q/Esc Home  Space Commands  Ctrl-r reload";
      ]
  | W.Settlements, _ ->
      [
        "n add  a action  s scope  j/k select  Enter/Tab detail";
        "q/Esc Home  Space Commands  Ctrl-r reload";
      ]
  | _, _ ->
      [
        "j/k scroll  Page Up/Down page  Home/End range"; "q/Esc back  Space Commands  Ctrl-r reload";
      ]

let rec screen ?(width_of = String.length) ((width, height) as dimensions) state =
  let feedback = feedback_lines ~dimensions ~width_of state in
  let usable = max 0 (height - List.length feedback) in
  if state.record_visible then
    match state.record with
    | Some record ->
        let pane_dimensions = record_dimensions ~dimensions ~width_of state in
        let rows = S.screen ~book:state.session.book ~dimensions:pane_dimensions ~width_of record in
        let pane_height = snd pane_dimensions in
        let body = List.filteri (fun i _ -> i < max 0 (pane_height - 2)) rows in
        let help = List.filteri (fun i _ -> i >= max 0 (pane_height - 2)) rows in
        if pane_dimensions = (width, usable) then body @ feedback @ help
        else
          let parent = screen ~width_of dimensions { state with record_visible = false } in
          List.filteri (fun i _ -> i < max 0 (height - 2)) parent
          @ List.map (fun (style, text) -> line ~width_of width style text) help
    | None -> List.init height (fun _ -> (Plain, ""))
  else
    let body_height = max 0 (height - List.length feedback - 2) in
    let headers =
      if state.workspace.route = W.Home then []
      else if state.workspace.route = W.Actual then
        [
          line ~width_of width Heading
            (tr "Bakhlo" ^ "  /  " ^ tr "Actual" ^ "  |  "
            ^ Act.scope_text state.actual_workspace ^ "  |  "
            ^ Act.current_locus_name ~book:state.session.book state.actual_workspace);
          (if Act.search_editing state.actual_workspace || Act.search_query state.actual_workspace <> "" then
             let style, text = Act.search_line ~width ~width_of state.actual_workspace in
             line ~width_of width style text
           else
             line ~width_of width Chrome
               (state.workspace.calendar.selected_day ^ "   "
                ^ Cal.title state.workspace.calendar ^ tr " view"
                ^ if has_record_draft state then "   Draft retained" else ""));
        ]
      else
        [
          line ~width_of width Heading
            (tr "Bakhlo" ^ "  /  " ^ (match state.workspace.route with
             | W.Home -> tr "Home"
             | W.Calendar -> tr "Calendar"
             | W.Actual -> tr "Actual"
             | W.Scheduled -> tr (if is_scheduled_months state then "Scheduled / Months" else "Scheduled")
             | W.Selected_day _ -> tr "Selected Day"
             | W.Balances -> tr "Balances"
             | W.Daily_pace -> tr "Daily Pace"
             | W.Attention -> tr "Attention"
             | W.Loci -> tr "Manage Loci"
             | W.Settlements -> tr "Settlements"));
          line ~width_of width Chrome
            ((if is_scheduled_months state then "Explicit current-open plans; no recurrence inferred."
              else state.workspace.calendar.selected_day ^ "   " ^ Cal.title state.workspace.calendar ^ tr " view")
            ^ if has_record_draft state then "   Draft retained" else "");
        ]
    in
    let header_count = List.length headers in
    let body =
      headers
      @ workspace_rows ~width_of ~width ~height:(max 0 (body_height - header_count)) state
    in
    let visible_body = List.filteri (fun i _ -> i < body_height) body in
    let bottom_pad = max 0 (body_height - List.length visible_body) in
    let full_body = visible_body @ List.init bottom_pad (fun _ -> (Plain, "")) in
    full_body @ feedback @ List.map (line ~width_of width Chrome) (footer ~dimensions ~width_of state)

let commands_overlay_rows ~width_of ~width ~height (menu : M.t) =
  let framed = height >= 5 && width >= 8 in
  let body_height = if framed then height - 2 else height in
  let path, description, back_label =
    match menu.page with
    | M.Root -> (" Home / Commands", " Choose a command group.", "Esc close")
    | M.Transactions -> (" Commands / Transactions", " Recording and exchange.", "Esc back")
    | M.Planning -> (" Commands / Plans and attention", " Scheduled household work.", "Esc back")
    | M.Analysis -> (" Commands / Reports and analysis", " Read household answers.", "Esc back")
    | M.Setup -> (" Commands / Household setup", " Explicit household evidence.", "Esc back")
  in
  let header =
    if body_height >= 9 then
      [ (Status, path); (Chrome, description); (Plain, "") ]
    else if body_height >= 3 then
      [ (Status, path) ]
    else []
  in
  let footer =
    if body_height >= 9 then
      [ (Plain, ""); (Chrome, " ↑/↓ select  → group  ← back"); (Chrome, " Enter open  " ^ back_label) ]
    else if body_height >= 2 then
      [ (Chrome, " ↑↓/jk Enter  " ^ back_label) ]
    else []
  in
  let page_cap = max 1 (body_height - List.length header - List.length footer) in
  let items = List.map snd (M.items menu.page) in
  let count = List.length items in
  let last = max 0 (count - page_cap) in
  let start = min last (max 0 (menu.selected - (page_cap / 2))) in
  let visible_items = items |> List.filteri (fun i _ -> i >= start && i < start + page_cap) in
  let item_lines =
    visible_items
    |> List.mapi (fun i text ->
        let index = i + start in
        let chosen = index = menu.selected in
        let marker = if chosen then "  > " else "    " in
        let style = if chosen then Active else Plain in
        (style, marker ^ text))
  in
  let pad_count = max 0 (page_cap - List.length item_lines) in
  let pad_lines = List.init pad_count (fun _ -> (Plain, "")) in
  let body_content = header @ item_lines @ pad_lines @ footer in
  let content =
    body_content
    |> List.mapi (fun i (style, text) ->
        if i < body_height then
          O.panel_line ~width ~width_of style text
        else (Plain, ""))
    |> List.filteri (fun i _ -> i < body_height)
  in
  let style = if width >= 54 && height >= 14 then Focused_frame else Frame in
  (O.panel_border ~width ~style ~width_of "Commands")
  :: content
  @ [ O.panel_bottom ~width ~style ~width_of () ]

type overlay_frame = {
  origin_x : int;
  origin_y : int;
  pane_width : int;
  pane_height : int;
  rows : (Daily_overlays.style * string) list;
  cursor : (int * int) option;
}

let resolve_overlay ~dimensions:((width, height) as dimensions) ~width_of state : overlay_frame option =
  let body_w, body_h = body_dimensions ~dimensions ~width_of state in
  let framed_form ~pane_w form =
    let content_width = max 0 (pane_w - 6) in
    let form_rows = Form.render_rows ~width:content_width
        ~height:(Panel.capacity ~height:body_h ~heading:false) ~width_of form in
    let pane_h = min body_h (max 5 (List.length form_rows + 2)) in
    let rows = Panel.frame_rows ~width_of ~width:pane_w ~height:pane_h
        ~focused:true ~title:(Form.title form) form_rows in
    let origin_x = max 0 ((width - pane_w) / 2) in
    let origin_y = max 0 ((body_h - pane_h) / 2) in
    let cursor = O.cursor_in_rows ~width_of ~width:pane_w rows
      |> Option.map (fun (col, row) -> (origin_x + col, origin_y + row)) in
    Some { origin_x; origin_y; pane_width = pane_w;
      pane_height = List.length rows; rows; cursor }
  in
  if state.record_visible then
    match state.record with
    | None -> None
    | Some record ->
        let pane_dimensions = record_dimensions ~dimensions ~width_of state in
        let available = (body_w, body_h + 2) in
        if pane_dimensions = available then None
        else
          let pane_w = fst pane_dimensions in
          let pane_h = snd pane_dimensions in
          let all_rows = S.screen ~book:state.session.book ~dimensions:pane_dimensions ~width_of record in
          let rows =
            all_rows
            |> List.filteri (fun i _ -> i < max 0 (pane_h - 2))
            |> List.map (fun (style, text) -> (style, O.pad ~width_of pane_w text))
          in
          let actual_h = List.length rows in
          let origin_x = max 0 ((width - pane_w) / 2) in
          let origin_y =
            if body_h - pane_h >= 2 then 2 + max 0 ((body_h - 2 - pane_h) / 2)
            else max 0 ((body_h - pane_h) / 2)
          in
          let cursor =
            match O.cursor_in_rows ~width_of ~width:pane_w rows with
            | Some (caret, row_idx) ->
                let col = origin_x + caret in
                let row = origin_y + row_idx in
                if col < width && row < height then Some (col, row) else None
            | None -> None
          in
          Some { origin_x; origin_y; pane_width = pane_w; pane_height = actual_h; rows; cursor }
  else if state.overlay = No_overlay || body_w < 8 || body_h < 3 then None
  else
    match state.overlay with
    | Scheduled_bulk editor ->
        let pane_dimensions = bulk_dimensions ~dimensions ~width_of state in
        let pane_w = fst pane_dimensions in
        let rows = Bulk.screen ~dimensions:pane_dimensions ~width_of editor in
        let pane_h = List.length rows in
        let origin_x = max 0 ((width - pane_w) / 2) in
        let origin_y = max 0 ((body_h - pane_h) / 2) in
        let cursor = Option.map (fun (col, row) -> (origin_x + col, origin_y + row))
          (O.cursor_in_rows ~width_of ~width:pane_w rows) in
        Some { origin_x; origin_y; pane_width = pane_w; pane_height = pane_h; rows; cursor }
    | Scheduled_continuation prompt ->
        let pane_dimensions = continuation_dimensions ~dimensions ~width_of state in
        let pane_w = fst pane_dimensions in
        let rows = Cont.screen ~dimensions:pane_dimensions ~width_of prompt in
        let pane_h = List.length rows in
        Some { origin_x = max 0 ((width - pane_w) / 2); origin_y = max 0 ((body_h - pane_h) / 2);
          pane_width = pane_w; pane_height = pane_h; rows; cursor = None }
    | Scheduled_cancel editor ->
        let pane_dimensions = cancellation_dimensions ~dimensions ~width_of state in
        let pane_w = fst pane_dimensions in
        let rows = Cancel.screen ~dimensions:pane_dimensions ~width_of editor in
        let pane_h = List.length rows in
        let origin_x = max 0 ((width - pane_w) / 2) in
        let origin_y = max 0 ((body_h - pane_h) / 2) in
        let cursor = Option.map (fun (col, row) -> (origin_x + col, origin_y + row))
          (O.cursor_in_rows ~width_of ~width:pane_w rows) in
        Some { origin_x; origin_y; pane_width = pane_w; pane_height = pane_h; rows; cursor }
    | Date_correction editor ->
        let pane_dimensions = date_dimensions ~dimensions ~width_of state in
        let pane_w = fst pane_dimensions in
        let rows = Date.screen ~dimensions:pane_dimensions ~width_of editor in
        let pane_h = List.length rows in
        let origin_x = max 0 ((width - pane_w) / 2) in
        let origin_y = max 0 ((body_h - pane_h) / 2) in
        let cursor = Option.map (fun (col, row) -> (origin_x + col, origin_y + row))
          (O.cursor_in_rows ~width_of ~width:pane_w rows) in
        Some { origin_x; origin_y; pane_width = pane_w; pane_height = pane_h; rows; cursor }
    | Reversal editor ->
        let pane_dimensions = reversal_dimensions ~dimensions ~width_of state in
        let pane_w = fst pane_dimensions in
        let rows = Rev.screen ~dimensions:pane_dimensions ~width_of editor in
        let pane_h = List.length rows in
        let origin_x = max 0 ((width - pane_w) / 2) in
        let origin_y = max 0 ((body_h - pane_h) / 2) in
        let cursor =
          match O.cursor_in_rows ~width_of ~width:pane_w rows with
          | Some (col, row) ->
              let c = origin_x + col and r = origin_y + row in
              if c < width && r < height then Some (c, r) else None
          | None -> None
        in
        Some { origin_x; origin_y; pane_width = pane_w; pane_height = pane_h; rows; cursor }
    | Scheduled_create editor ->
        let pane_dimensions = scheduled_dimensions ~dimensions ~width_of state in
        let pane_w = fst pane_dimensions in
        let rows = Sch.screen ~book:state.session.book ~dimensions:pane_dimensions ~width_of editor in
        let pane_h = List.length rows in
        let origin_x = max 0 ((width - pane_w) / 2) in
        let origin_y = max 0 ((body_h - pane_h) / 2) in
        let cursor =
          match O.cursor_in_rows ~width_of ~width:pane_w rows with
          | Some (col, row) ->
              let c = origin_x + col and r = origin_y + row in
              if c < width && r < height then Some (c, r) else None
          | None -> None
        in
        Some { origin_x; origin_y; pane_width = pane_w; pane_height = pane_h; rows; cursor }
    | Commands menu ->
        let can_float = body_w >= 60 && body_h >= 14 in
        let pane_w = min 54 (max 8 (body_w - 4)) in
        let available_h = if can_float then max 5 (body_h - 4) else body_h in
        let pane_h = min (List.length (M.items menu.page) + 8) available_h in
        let rows = commands_overlay_rows ~width_of ~width:pane_w ~height:pane_h menu in
        let origin_x = max 0 ((width - pane_w) / 2) in
        let origin_y = max 0 ((body_h - pane_h) / 2) in
        Some { origin_x; origin_y; pane_width = pane_w; pane_height = List.length rows; rows; cursor = None }
    | Themes { selected; _ } ->
        let pane_w = min 54 (max 8 (body_w - 4)) in
        let items = List.map P.theme_label P.all_themes in
        let pane_h = min body_h (max 5 (List.length items + 2)) in
        let rows =
          Panel.frame ~width_of ~width:pane_w ~height:pane_h ~focused:true ~title:(tr "Theme")
            ~scroll:0 ~selected:(Some selected) items
        in
        let origin_x = max 0 ((width - pane_w) / 2) in
        let origin_y = max 0 ((body_h - pane_h) / 2) in
        Some { origin_x; origin_y; pane_width = pane_w; pane_height = List.length rows; rows; cursor = None }
    | Jump value ->
        framed_form ~pane_w:(min 54 (max 8 (body_w - 4)))
          (Form.create ~id:"jump" ~title:(tr "Jump to date / month / year")
             ~fields:[Form.text_field ~id:"value" ~label:"" ~value ()]
             ~notice:(tr "Enter apply; Esc cancel") ())
    | Search value ->
        framed_form ~pane_w:(min 54 (max 8 (body_w - 4)))
          (Form.create ~id:"search" ~title:(tr "Search Actual / Scheduled")
             ~fields:[Form.text_field ~id:"value" ~label:"" ~value ()]
             ~notice:(tr "Enter apply; Esc clear") ())
    | Modal_form form ->
        framed_form ~pane_w:(min 64 (max 8 (body_w - 4))) form
    | No_overlay -> None

let overlay_screen ~dimensions ~width_of state =
  match resolve_overlay ~dimensions ~width_of state with
  | Some frame -> Some frame.rows
  | None -> None

let overlay_position ~dimensions ~width_of state ~pane_width ~pane_height =
  match resolve_overlay ~dimensions ~width_of state with
  | Some frame -> (frame.origin_x, frame.origin_y)
  | None ->
      let width, height = body_dimensions ~dimensions ~width_of state in
      let top =
        if state.record_visible && height - pane_height >= 2 then
          2 + max 0 ((height - 2 - pane_height) / 2)
        else max 0 ((height - pane_height) / 2)
      in
      (max 0 ((width - pane_width) / 2), top)

let cursor_position ~width_of ((width, height) as dimensions) state : (int * int) option =
  match resolve_overlay ~dimensions ~width_of state with
  | Some frame -> frame.cursor
  | None ->
      if state.record_visible then
        match state.record with
        | None -> None
        | Some record ->
            let pane_dimensions = record_dimensions ~dimensions ~width_of state in
            let rows = S.screen ~book:state.session.book ~dimensions:pane_dimensions ~width_of record in
            let painted = List.filteri (fun i _ -> i < max 0 height) rows in
            O.cursor_in_rows ~width_of ~width:(min width (fst pane_dimensions)) painted
      else if state.workspace.route = W.Actual then
        Act.cursor_position ~dimensions ~width_of state.actual_workspace
      else None

