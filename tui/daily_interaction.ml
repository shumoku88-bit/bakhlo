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
module Form = Ui_form
module Att = Attention_data

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

let is_cancel_plan = function
  | Modal_form f when Form.id f = "cancel_plan" -> true
  | _ -> false

let is_reverse_entry = function
  | Modal_form f when Form.id f = "reverse_entry" -> true
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
  attention : Att.t;
}

let initial ?config_home session =
  let measure = match B.measures session.F.book with (id, _) :: _ -> id | [] -> "" in
  let workspace = get (W.create ~today:(F.today ()) ~measure) in
  let notice = A.recovery_notice ~session in
  let attention_path = Att.file_path ?config_home session.F.path in
  let attention = Att.load_file attention_path in
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
    attention;
  }

let has_record_draft state =
  match state.record with None -> false | Some record -> S.has_draft record

let editor_visible state = state.record_visible
let mode state = match state.record with None -> A.New | Some record -> S.mode record

let sync state =
  { state with workspace = W.sync ~book:state.session.book state.workspace; scroll = 0 }

let apply_commit_result state ~draft result =
  let published session message =
    sync
      {
        state with
        session;
        record = None;
        record_visible = false;
        overlay = No_overlay;
        pending = None;
        blocked = false;
        message = tr message;
      }
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
  match A.reload ~session:state.session ~pending:state.pending ~mode:(mode state) with
  | A.Pending_confirmed session ->
      sync
        {
          state with
          session;
          pending = None;
          record = None;
          record_visible = false;
          blocked = false;
          message = tr "The pending publication is present now. No retry.";
        }
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
  | A.Reloaded session ->
      sync { state with session; blocked = false; message = tr "Reloaded. Unsaved draft retained." }
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
    | Some record when S.has_draft record ->
        { state with record_visible = true; overlay = No_overlay }
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
      record = Some (S.create_plan ~book:state.session.book ~day ~measure ());
      record_visible = true;
      overlay = No_overlay;
      message = "";
    }

let open_route state route =
  sync { state with workspace = W.enter state.workspace route; overlay = No_overlay; scroll = 0 }

let selected state = W.selected_row ~book:state.session.book state.workspace

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

let cancel_plan_form (plan : B.plan) =
  let summary =
    "Due: " ^ plan.day ^ "  " ^ plan.measure ^ "  "
    ^ String.concat ", "
        (List.map (fun (loc, amt) -> loc ^ " " ^ Z.to_string amt) plan.changes)
  in
  Form.create
    ~id:"cancel_plan"
    ~payload:plan.id
    ~title:"Cancel Scheduled"
    ~summary:[summary]
    ~fields:[
      Form.text_field ~id:"date" ~label:"Cancel on" ~value:(F.today ()) ();
      Form.action_buttons ~confirm:"Confirm Cancel" ~cancel:"Keep Plan" ();
    ]
    ()

let cancel_plan_selected state =
  if state.blocked then state
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
            overlay = Modal_form (cancel_plan_form plan);
            message = "";
          }
    | _ -> { state with message = tr "Select an open Scheduled occurrence to cancel." }

let reverse_entry_form (entry : B.entry) =
  let summary =
    "Date: " ^ entry.day ^ "  " ^ (match entry.memo with Some m -> m | None -> "(no memo)")
    ^ "  "
    ^ String.concat ", "
        (List.map
           (fun e ->
             A.lstr (D.Effect.locus e)
             ^ " "
             ^ Z.to_string (A.quanta e))
           entry.effects)
  in
  Form.create
    ~id:"reverse_entry"
    ~payload:entry.id
    ~title:"Reverse Actual"
    ~summary:[summary]
    ~fields:[
      Form.text_field ~id:"date" ~label:"Reversal on" ~value:(F.today ()) ();
      Form.action_buttons ~confirm:"Confirm Reversal" ~cancel:"Keep Actual" ();
    ]
    ()

let reverse_entry_selected state =
  if state.blocked then state
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
            overlay = Modal_form (reverse_entry_form entry);
            message = "";
          }
    | _ -> { state with message = tr "Select an Actual entry to reverse." }

let open_attentions state =
  Att.open_items state.attention

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
  else open_route state W.Home

let open_command state = function
  | M.Record -> open_record { state with overlay = No_overlay }
  | M.New_plan -> open_plan_record { state with overlay = No_overlay }
  | M.Actual -> open_route state W.Actual
  | M.Scheduled -> open_route state W.Scheduled
  | M.Balances -> open_route state W.Balances
  | M.Daily_pace -> open_route state W.Daily_pace
  | M.Attention -> open_route state W.Attention
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

let accounting_roles state =
  match read_config state "accounting-roles.tsv" with
  | Some text -> O.parse_accounting_roles text
  | None -> []

let balance_items state =
  let roles = accounting_roles state in
  O.role_balance_items ~book:state.session.book ~roles

let balance_lines state =
  let items = balance_items state in
  List.map (O.balance_item_line ~book:state.session.book) items

let handle ?(dimensions = (80, 24)) ?(width_of = String.length) state (input : input) =
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
              | Some value -> { state with overlay = Search value }))
    | Modal_form form -> (
        match Form.handle_input form input with
        | Form.Cancel -> Some { state with overlay = No_overlay }
        | Form.Updated updated -> Some { state with overlay = Modal_form updated }
        | Form.Submit submitted -> (
            match Form.id submitted with
            | "cancel_plan" ->
                let cancel_day = Option.value ~default:"" (Form.get_text submitted "date") in
                (match A.normalize_date cancel_day with
                | Error _ ->
                    Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Invalid date (YYYY-MM-DD).")) }
                | Ok canon_day ->
                    if not (A.is_valid_canonical_date canon_day) then
                      Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter a real Gregorian date.")) }
                    else
                      let plan_id = Form.payload submitted in
                      let res =
                        A.commit_cancel_plan ~session:state.session ~base_bytes:state.session.bytes
                          ~id:plan_id ~day:canon_day
                      in
                      let next_state = { state with overlay = No_overlay } in
                      Some (apply_commit_result next_state ~draft:next_state res))
            | "reverse_entry" ->
                let reverse_day = Option.value ~default:"" (Form.get_text submitted "date") in
                (match A.normalize_date reverse_day with
                | Error _ ->
                    Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Invalid date (YYYY-MM-DD).")) }
                | Ok canon_day ->
                    if not (A.is_valid_canonical_date canon_day) then
                      Some { state with overlay = Modal_form (Form.set_notice submitted (tr "Enter a real Gregorian date.")) }
                    else
                      let entry_id = Form.payload submitted in
                      let res =
                        A.commit_reverse_entry ~session:state.session ~base_bytes:state.session.bytes
                          ~id:entry_id ~day:canon_day
                      in
                      let next_state = { state with overlay = No_overlay } in
                      Some (apply_commit_result next_state ~draft:next_state res))
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
                      let id = Att.next_id state.attention in
                      (match Att.add_item state.attention ~id ~context ~due with
                      | Error why ->
                          Some { state with overlay = Modal_form (Form.set_notice submitted why) }
                      | Ok updated_attention ->
                          let path = Att.file_path ?config_home:state.config_home state.session.F.path in
                          let _ = Att.save_file path updated_attention in
                          Some { state with overlay = No_overlay; attention = updated_attention; message = Printf.sprintf "Added %s." id }))
            | "resolve_attention" ->
                let item_id = Form.payload submitted in
                (match Att.close_item state.attention ~id:item_id ~known_on:(F.today ()) ~kind:Att.Resolved with
                | Error why ->
                    Some { state with overlay = Modal_form (Form.set_notice submitted why) }
                | Ok updated_attention ->
                    let path = Att.file_path ?config_home:state.config_home state.session.F.path in
                    let _ = Att.save_file path updated_attention in
                    Some { state with overlay = No_overlay; attention = updated_attention; message = Printf.sprintf "Resolved %s." item_id })
            | "drop_attention" ->
                let item_id = Form.payload submitted in
                (match Att.close_item state.attention ~id:item_id ~known_on:(F.today ()) ~kind:Att.Dropped with
                | Error why ->
                    Some { state with overlay = Modal_form (Form.set_notice submitted why) }
                | Ok updated_attention ->
                    let path = Att.file_path ?config_home:state.config_home state.session.F.path in
                    let _ = Att.save_file path updated_attention in
                    Some { state with overlay = No_overlay; attention = updated_attention; message = Printf.sprintf "Dropped %s." item_id })
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
        | Some ((`Escape | `ASCII 'q'), []) ->
            if state.workspace.route = W.Attention then
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
        | Some ((`Tab | `ASCII 'w'), []) | Some (`Tab, [ `Shift ]) ->
            Some
              {
                state with
                workspace =
                  {
                    state.workspace with
                    pane = (if state.workspace.pane = W.Calendar then W.Detail else W.Calendar);
                  };
                scroll = 0;
              }
        | Some (`ASCII 't', []) when state.workspace.route = W.Calendar ->
            Some (update_calendar state (Cal.Today (F.today ())))
        | Some (`ASCII 'z', []) when state.workspace.route = W.Calendar ->
            Some (update_calendar state Cal.Cycle_zoom)
        | Some (`ASCII '/', []) ->
            Some
              {
                state with
                overlay = (if state.workspace.route = W.Calendar then Jump "" else Search "");
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
        | Some (`ASCII 'd', []) when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_route state W.Daily_pace)
        | Some (`ASCII 'i', []) when state.workspace.route = W.Home || state.workspace.route = W.Calendar ->
            Some (open_route state W.Attention)
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

let frame ~width_of ~width ~height ~focused ~title ~scroll ~selected rows =
  if width < 6 || height < 2 then List.init (max 0 height) (fun _ -> (Plain, ""))
  else
    let capacity = max 0 (height - 2) in
    let last = max 0 (List.length rows - capacity) in
    let start =
      match selected with
      | None -> min last (max 0 scroll)
      | Some index -> min last (max 0 (index - capacity + 1))
    in
    let shown = rows |> List.filteri (fun i _ -> i >= start && i < start + capacity) in
    let shown =
      List.mapi
        (fun i text ->
          O.panel_line ~width ~width_of
            (match selected with
            | Some index when index = i + start -> if focused then Active else Chrome
            | _ -> Plain)
            ((match selected with Some index when index = i + start -> "> " | _ -> "  ") ^ text))
        shown
    in
    let style = if focused then Focused_frame else Frame in
    (O.panel_border ~width ~style ~width_of (tr title) :: shown)
    @ List.init
        (max 0 (capacity - List.length shown))
        (fun _ -> O.panel_line ~width ~width_of Plain "")
    @ [
        O.panel_bottom ~width ~style ~width_of
          ~title:
            (Printf.sprintf "%d–%d / %d"
               (if rows = [] then 0 else start + 1)
               (min (List.length rows) (start + capacity))
               (List.length rows))
          ();
      ]

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

let row_detail book = function
  | W.Actual_entry entry -> O.entry_lines book entry
  | W.Scheduled_plan plan -> O.plan_lines book plan

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
  let today = F.today () and measure = state.workspace.measure in
  match (read_config state "daily-pace.tsv", read_config state "boundary-presets.tsv") with
  | None, _ | _, None ->
      [
        tr "Not configured.";
        "";
        tr "Supply a balance pool and exclusive period end:";
        "  - daily-pace.tsv (Locus<TAB>Measure)";
        "  - boundary-presets.tsv (Preset<TAB>Date...)";
        "";
        tr "Historical Trend is unavailable.";
      ]
  | Some pool, Some windows -> (
      let tokens line = String.split_on_char '\t' line in
      let meaningful text =
        String.split_on_char '\n' text
        |> List.filter (fun line ->
            String.trim line <> "" && not (String.starts_with ~prefix:"#" (String.trim line)))
      in
      let rec coordinates acc = function
        | [] -> Ok (List.rev acc)
        | line :: rest -> (
            match tokens line with
            | [ locus; m ] when m <> measure -> coordinates acc rest
            | [ locus; m ] -> (
                match (D.Identifier.Locus.of_string locus, D.Identifier.Measure.of_string m) with
                | Ok locus, Ok measure ->
                    coordinates ({ D.Effect_coordinate.locus; measure } :: acc) rest
                | _ -> Error "Invalid Daily Pace coordinate.")
            | _ -> Error "Invalid daily-pace.tsv row; expected Locus<TAB>Measure.")
      in
      let rec find_window = function
        | [] -> Error "No boundary contains today."
        | line :: rest -> (
            let rec window = function
              | a :: b :: tail -> (
                  match (Cal.parts a, Cal.parts b) with
                  | Ok _, Ok _ when a <= today && today < b -> Ok (a, b)
                  | Ok _, Ok _ -> window (b :: tail)
                  | _ -> Error "Invalid boundary date.")
              | _ -> find_window rest
            in
            match tokens line with _preset :: dates -> window dates | [] -> find_window rest)
      in
      match (coordinates [] (meaningful pool), find_window (meaningful windows)) with
      | Error why, _ | _, Error why -> [ tr "Daily Pace unavailable:"; tr why ]
      | Ok [], _ -> [ tr "Daily Pace unavailable: no selected-Measure pool supplied." ]
      | Ok pool, Ok (start_day, end_exclusive) -> (
          match
            B.daily_pace state.session.book ~measure ~pool ~observed_at:today ~end_exclusive
          with
          | Error why -> [ tr "Daily Pace unavailable:"; why ]
          | Ok pace ->
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
              [
                Printf.sprintf "Daily Pace: %s / day" (amount pace.daily_pace_quanta);
                "";
                Printf.sprintf "Period progress: %s %d/%d days" bar elapsed_days total_period_days;
                Printf.sprintf "Through end: %s (Available)" (amount pace.available_through_end);
                Printf.sprintf "Days remaining: %d days  (Observed: %s -> End: %s)"
                  pace.remaining_days pace.observed_at pace.end_exclusive;
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
                  "Total Deductions: -" ^ amount pace.automatic_deductions ]))

let pace_detail_lines state =
  let today = F.today () and measure = state.workspace.measure in
  match (read_config state "daily-pace.tsv", read_config state "boundary-presets.tsv") with
  | None, _ | _, None ->
      [
        "Daily Pace Configuration Guide";
        "";
        "Files required in repository root or config directory:";
        "";
        "1. daily-pace.tsv:";
        "   Locus<TAB>Measure";
        "   Example: wallet<TAB>jpy";
        "";
        "2. boundary-presets.tsv:";
        "   Preset<TAB>Date<TAB>Date...";
        "   Example: month<TAB>2026-10-01<TAB>2026-11-01";
        "";
        "Daily Pace divides eligible pool minus scheduled obligations";
        "by the remaining calendar days until exclusive period end.";
      ]
  | Some pool, Some windows -> (
      let tokens line = String.split_on_char '\t' line in
      let meaningful text =
        String.split_on_char '\n' text
        |> List.filter (fun line ->
            String.trim line <> "" && not (String.starts_with ~prefix:"#" (String.trim line)))
      in
      let rec find_window = function
        | [] -> None
        | line :: rest -> (
            let rec window = function
              | a :: b :: tail ->
                  if a <= today && today < b then Some (a, b) else window (b :: tail)
              | _ -> find_window rest
            in
            match tokens line with _preset :: dates -> window dates | [] -> find_window rest)
      in
      match find_window (meaningful windows) with
      | None -> [ tr "Boundary window not found for today." ]
      | Some (start_day, end_exclusive) ->
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
            "Integrity & Principles:";
            "  - Current evidence reconstruction only.";
            "  - No speculative spending or trend projection is inferred.";
            "  - Past pacing or historical velocity is unavailable.";
            "  - Distinct currency balances are never cross-converted.";
          ])

let workspace_rows ~width_of ~width ~height state =
  let draw_frame = frame in
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
    | W.Balances -> "Balances / Current"
    | W.Daily_pace -> "Daily Pace"
    | W.Attention -> "Attention / Household matters"
  in
  let pad rows = rows @ List.init (max 0 (height - List.length rows)) (fun _ -> (Plain, "")) in
  let split_pane ~left_focused ~left_title ~left_scroll ~left_selected ~left_rows
      ~right_focused ~right_title ~right_scroll ~right_selected ~right_rows =
    if width >= 80 then
      let left_width = max 36 (min 58 (width * 52 / 100)) in
      let right_width = width - left_width - 1 in
      let left_panel =
        draw_frame ~width_of ~width:left_width ~height ~focused:left_focused
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
          ~title:left_title ~scroll:left_scroll ~selected:left_selected left_rows
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
      ~right_scroll:state.scroll ~right_selected:None ~right_rows:wrapped_detail
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
      ~right_scroll:state.scroll ~right_selected:None ~right_rows:wrapped_detail
  else if workspace.route = W.Attention then
    let items = open_attentions state in
    let left_title = Printf.sprintf "Attention (%d open)" (List.length items) in
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
    let left_rows =
      if items = [] then [ tr "No open attention items." ]
      else List.map item_line items
    in
    let detail =
      match selected_attention state with
      | None -> [ tr "No selected attention item."; ""; tr "Press 'n' to add a household matter." ]
      | Some item ->
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
      ~right_scroll:state.scroll ~right_selected:None ~right_rows:wrapped_detail
  else
    let is_detail = workspace.pane = W.Detail in
    let right_title =
      match workspace.route with
      | W.Scheduled -> "Plan Detail"
      | W.Actual -> "Actual Detail"
      | _ -> "Selected Record"
    in
    let detail =
      match selected state with
      | None -> [ tr "No selected record." ]
      | Some row -> row_detail book row
    in
    let right_width = if width >= 80 then width - max 36 (min 58 (width * 52 / 100)) - 1 else width in
    let wrapped_detail = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) detail in
    let list_title =
      match workspace.route with
      | W.Actual ->
          let browser = W.browser workspace in
          let order_str = match browser.order with W.Newest -> "desc" | W.Oldest -> "asc" in
          let scope_str = match browser.day with None -> "all" | Some _ -> "day" in
          Printf.sprintf "Actuals (%d, %s, %s)" (List.length rows) order_str scope_str
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
      ~right_selected:None ~right_rows:wrapped_detail

let footer state =
  match state.overlay with
  | Themes _ -> [ "j/k or Up/Down preview theme"; "Enter save  Esc/q cancel" ]
  | Modal_form form -> (
      match Form.id form with
      | "cancel_plan" ->
          [ "Enter confirm cancel  Tab switch button  Esc keep plan"; "Cancel date can be edited" ]
      | "reverse_entry" ->
          [ "Enter confirm reversal  Tab switch button  Esc keep actual"; "Reversal date can be edited" ]
      | _ ->
          [ "Enter submit  Tab next field  Esc cancel"; "Arrow keys / space to choose options" ])
  | No_overlay | Commands _ | Jump _ | Search _ ->
  match (state.workspace.W.route, state.workspace.pane) with
  | W.Home, _ ->
      [
        "Enter/g calendar  i attention  r record  s scheduled  a actual  b balances  d daily pace";
        "Space commands  q quit";
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
        "j/k select  Enter/i/Tab Detail  c Complete  e Edit  x Cancel";
        "n New Plan  f Filter  / search  Space Commands  q/Esc Home";
      ]
  | W.Actual, W.Calendar ->
      [
        "j/k select  Enter/i/Tab Detail  c Correct  x Reverse  f Day/All  s Order";
        "n Record  / search  Space Commands  q/Esc Home  Ctrl-r reload";
      ]
  | W.Selected_day _, W.Calendar ->
      [
        "j/k select  Enter/i/Tab Detail  c Correct  x Reverse  r Record";
        "Space Commands  q/Esc Home  Ctrl-r reload";
      ]
  | W.Balances, W.Calendar ->
      [ "j/k select  Enter/i/Tab Detail  r Record"; "Space Commands  q/Esc Home  Ctrl-r reload" ]
  | W.Daily_pace, W.Calendar ->
      [ "j/k scroll  Tab/w Detail  r Record"; "Space Commands  q/Esc Home  Ctrl-r reload" ]
  | W.Attention, _ ->
      [
        "n new  r resolve  x drop  j/k select  Enter/Tab detail";
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
      else
        [
          line ~width_of width Heading
            (tr "Bakhlo" ^ "  /  " ^ (match state.workspace.route with
             | W.Home -> tr "Home"
             | W.Calendar -> tr "Calendar"
             | W.Actual -> tr "Actual"
             | W.Scheduled -> tr "Scheduled"
             | W.Selected_day _ -> tr "Selected Day"
             | W.Balances -> tr "Balances"
             | W.Daily_pace -> tr "Daily Pace"
             | W.Attention -> tr "Attention"));
          line ~width_of width Chrome
            (state.workspace.calendar.selected_day ^ "   "
            ^ Cal.title state.workspace.calendar ^ tr " view"
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
    full_body @ feedback @ List.map (line ~width_of width Chrome) (footer state)

let overlay_screen ~dimensions ~width_of state =
  let width, height = body_dimensions ~dimensions ~width_of state in
  if state.record_visible then
    match state.record with
    | None -> None
    | Some record ->
        let pane_dimensions = record_dimensions ~dimensions ~width_of state in
        let available = (width, height + 2) in
        if pane_dimensions = available then None
        else
          Some
            (S.screen ~book:state.session.book ~dimensions:pane_dimensions ~width_of record
            |> List.filteri (fun i _ -> i < max 0 (snd pane_dimensions - 2))
            |> List.map (fun (style, text) ->
                   (style, O.pad ~width_of (fst pane_dimensions) text)))
  else if state.overlay = No_overlay || width < 8 || height < 3 then None
  else
    let max_w = match state.overlay with Modal_form _ -> 64 | _ -> 54 in
    let width = min max_w (max 8 (width - 4)) in
    let title, rows, selected =
      match state.overlay with
      | Commands menu -> (M.title menu.page, List.map snd (M.items menu.page), Some menu.selected)
      | Themes { selected; _ } -> ("Theme", List.map P.theme_label P.all_themes, Some selected)
      | Jump value ->
          ("Jump to date / month / year", [ value ^ "|"; tr "Enter apply; Esc cancel" ], None)
      | Search value ->
          ("Search Actual / Scheduled", [ value ^ "|"; tr "Enter apply; Esc clear" ], None)
      | Modal_form form ->
          (Form.title form, Form.render_rows form, None)
      | No_overlay -> ("", [], None)
    in
    let height = min height (max 5 (List.length rows + 2)) in
    Some (frame ~width_of ~width ~height ~focused:true ~title ~scroll:0 ~selected rows)

let overlay_position ~dimensions ~width_of state ~pane_width ~pane_height =
  let width, height = body_dimensions ~dimensions ~width_of state in
  let top =
    if state.record_visible && height - pane_height >= 2 then
      2 + max 0 ((height - 2 - pane_height) / 2)
    else max 0 ((height - pane_height) / 2)
  in
  (max 0 ((width - pane_width) / 2), top)
