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
module Cont = Scheduled_continuation_session
module Bulk = Scheduled_bulk_session
module Gen = Scheduled_generation_session
module Form = Ui_form
module Panel = Ui_panel
module Att = Attention_data
module Stl = Settlement_data
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
  | Bonsai
  | Entrance
  | Panel
  | Panel_heading
  | Panel_active
  | Columns of int * style * style
  | Input of int
  | Series of int
  | Spans of (style * string) list

type overlay =
  | No_overlay
  | Commands of M.t
  | Themes of { selected : int; original : P.theme; return_menu : M.t }
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
  (* A confirmed publication clears only the requesting Record, even if hidden
     while waiting for reload. Other screen publications may share this state. *)
  pending_record_publication : bool;
  config_home : string option;
  paste_blocked : bool;
  settlement_path : string;
  settlements : (Stl.t, string) result;
  screens : Screen_registry.t;
  drill_parent : W.route option;
  drill_book : B.t option;
}

(* Attention is a section of the book, read in its former attention.loam text. *)
let attention (state : state) =
  let text = state.session.F.sidecars.attention in
  if text = "" then Ok Att.empty else Att.of_string text

let initial ?config_home session =
  let measure = match B.measures session.F.book with (id, _) :: _ -> id | [] -> "" in
  let today = F.today () in
  let workspace = get (W.create ~today ~measure) in
  let settlement_path = Settlement_file.file_path ?config_home session.F.path in
  let settlements = Settlement_file.load_file settlement_path in
  {
    session;
    workspace;
    record = None;
    record_visible = false;
    overlay = No_overlay;
    theme = P.load_theme ?config_home ();
    message = "";
    ui_notice = None;
    blocked = false;
    pending = None;
    pending_record_publication = false;
    config_home;
    paste_blocked = false;
    settlement_path;
    settlements;
    screens = Screen_registry.create ~scheduled_months:(get (Scheduled_months.create ~today));
    drill_parent = None;
    drill_book = None;
  }

let open_editor state session =
  {
    state with
    screens =
      { state.screens with editors = Record_editors.open_session session state.screens.editors };
  }

let has_record_draft state =
  match state.record with None -> false | Some record -> S.has_draft record

let editor_visible state = state.record_visible
let mode state = match state.record with None -> A.New | Some record -> S.mode record

let sync state =
  match state.workspace.route with
  | W.Selected_day _ ->
      {
        state with
        screens =
          {
            state.screens with
            day = Selected_day_screen.synced state.session.book state.screens.day;
          };
      }
  | _ -> state

let finish_publication ~record_publication state session message =
  let next =
    sync
      {
        state with
        session;
        record = (if record_publication then None else state.record);
        record_visible = (if record_publication then false else state.record_visible);
        overlay = No_overlay;
        pending = None;
        blocked = false;
        message = tr message;
        pending_record_publication = false;
        screens = Screen_registry.dismiss_floating state.screens;
      }
  in
  let next =
    let screens, notice =
      Screen_registry.book_changed state.workspace.route ~before:state.session.book
        ~after:session.book next.screens
    in
    { next with screens; message = (next.message ^ if notice = "" then "" else "\n" ^ tr notice) }
  in
  match (record_publication, mode state) with
  | true, A.Pay id -> (
      match
        List.find_opt (fun (p : B.plan) -> p.id = id && p.paid_by <> None) (B.plans session.book)
      with
      | Some source ->
          {
            (open_editor next
               (Record_editors.Scheduled_continuation
                  (Cont.create ~book:session.book ~base_revision:session.revision source)))
            with
            message = next.message ^ " No additional Scheduled created.";
          }
      | None ->
          {
            next with
            message =
              next.message ^ " Next-plan inspection unavailable; no additional Scheduled created.";
          })
  | _ -> next

let apply_commit_result ?published_message ?(record_publication = false) state ~draft result =
  let published session default_msg =
    let msg = match published_message with Some m -> m | None -> default_msg in
    finish_publication ~record_publication state session msg
  in
  let stopped ?(pending = draft.pending) message =
    { draft with blocked = true; pending; message }
  in
  match result with
  | A.Published session ->
      published session "Published and read back. Previous bytes are kept separately."
  | A.Conflict_base_changed ->
      stopped ~pending:None
        (tr "The preview generation changed. Draft retained; reload and review.")
  | A.Conflict ->
      stopped ~pending:None
        (tr "Another writer changed the book. Draft retained; reload and review.")
  | A.Storage_failed why ->
      stopped (A.format_message "Storage failed (%s). Writes stopped; draft retained." why)
  | A.Refused why ->
      { draft with message = A.format_message "Publication refused (%s). Draft retained." why }
  | A.Uncertain { message; evidence } ->
      let stopped =
        stopped ~pending:(Some evidence)
          (A.format_message
             "Publication outcome is unknown (%s). Do not retry; reload to inspect. Draft retained."
             message)
      in
      { stopped with pending_record_publication = record_publication }

let reload state =
  let state =
    {
      state with
      settlements = Settlement_file.load_file state.settlement_path;
    }
  in
  match A.reload ~session:state.session ~pending:state.pending ~mode:(mode state) with
  | A.Pending_confirmed session ->
      finish_publication ~record_publication:state.pending_record_publication state session
        "The pending publication is present now. No retry."
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
  | A.Reloaded session -> (
      match state.overlay with
      | _ ->
          sync
            {
              state with
              session;
              blocked = false;
              message = tr "Reloaded. Unsaved draft retained.";
            })
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
              (S.preview ~new_id:Daily_file.new_id ~book:state.session.book
                 ~base_revision:state.session.revision ~blocked:state.blocked record);
          record_visible = true;
        }

let discard state =
  if state.pending <> None then
    {
      state with
      blocked = true;
      message = tr "Unconfirmed publication: inspect before discarding or retrying.";
    }
  else
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
    let form =
      Form.create ~id:"discard_record" ~title:"Discard retained draft?"
        ~summary:[ "The retained draft will be lost."; "Saved entries and plans will not change." ]
        ~fields:
          [
            Form.buttons_field ~id:"actions"
              ~buttons:
                [
                  { Form.label = "Keep draft"; is_cancel = true };
                  { Form.label = "Discard draft"; is_cancel = false };
                ]
              ();
          ]
        ()
    in
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
        let day =
          match state.workspace.route with
          | W.Selected_day day -> day
          | _ -> state.workspace.focus_day
        in
        {
          state with
          record = Some (S.create ~book:state.session.book ~day ~measure:state.workspace.measure ());
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
      match state.workspace.route with W.Selected_day d -> d | _ -> state.workspace.focus_day
    in
    let measure = state.workspace.measure in
    {
      state with
      screens =
        (open_editor state
           (Record_editors.Scheduled_create (Sch.create ~book:state.session.book ~day ~measure)))
          .screens;
      record_visible = false;
      message = "";
    }

let open_route state route =
  sync
    {
      state with
      workspace = W.enter state.workspace route;
      overlay = No_overlay;
      drill_parent = None;
      drill_book = None;
      screens = Screen_registry.enter route ~focus_day:state.workspace.focus_day state.screens;
    }
