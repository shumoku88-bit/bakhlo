(* Shared queries, forms and viewport geometry for input and display. *)
open Daily_interaction_state

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
  else match state.drill_parent with
  | Some W.Actual ->
      let before = Option.value ~default:state.session.book state.drill_book in
      let screens, _ = Screen_registry.book_changed W.Actual ~before ~after:state.session.book state.screens in
      { state with screens; drill_parent = None; drill_book = None;
        workspace = W.enter state.workspace W.Actual; overlay = No_overlay }
  | _ -> open_route state W.Home

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

let write_config_file state name ~expected content =
  let path = config_file_path state name in
  let tmp = ref None in
  try
    F.with_writer path (fun () ->
      match read_pace_config state name with
      | Error why -> Error why
      | Ok current when current <> expected -> Error "Configuration changed. Reopen the editor."
      | Ok _ ->
          let target = path ^ ".tmp-" ^ F.nonce () in
          tmp := Some target;
          F.write_new target content;
          Sys.rename target path;
          F.sync_parent path;
          F.require (F.read path = content) "config-readback-changed";
          Ok ())
  with
  | F.Refused why | Sys_error why ->
      Option.iter (fun p -> try Unix.unlink p with Unix.Unix_error _ -> ()) !tmp;
      Error why
  | Unix.Unix_error (err, fn, arg) ->
      Option.iter (fun p -> try Unix.unlink p with Unix.Unix_error _ -> ()) !tmp;
      Error (Printf.sprintf "%s (%s %s)" (Unix.error_message err) fn arg)

let accounting_roles state =
  match read_config state Locus_roles.file_name with
  | Some text -> O.parse_accounting_roles text
  | None -> []

let annual_history_bounds state =
  try
    match state.session.F.annual_year with
    | None -> Ok None
    | Some year ->
        let sources = F.annual_sources state.session in
        let first_path, _ = List.hd sources in
        let first_year = String.sub (Filename.basename first_path) 0 4 in
        Ok (Some (first_year ^ "-01-01", Printf.sprintf "%04d-01-01" (year + 1)))
  with
  | F.Refused why -> Error why
  | Unix.Unix_error _ | Sys_error _ -> Error "Annual history source unavailable."

(* Shell side of the screen owner protocol ({!Screen}). *)
let screen_env ~config_files state : Screen.env =
  let captured = List.map (fun name -> (name, read_pace_config state name)) config_files in
  {
    book = state.session.book;
    bytes = state.session.bytes;
    new_id = F.new_id;
    measure = state.workspace.measure;
    calendar = state.workspace.calendar;
    today = F.today ();
    annual = {
      year = state.session.F.annual_year;
      unavailable = lazy (annual_unavailable state);
      history = lazy (annual_history_bounds state);
    };
    accounting_roles = lazy (accounting_roles state);
    attention = state.attention;
    settlements = state.settlements;
    blocked = state.blocked;
    config = (fun name ->
      match List.assoc_opt name captured with
      | Some bytes -> bytes
      | None -> Error ("Configuration " ^ name ^ " was not declared by this screen."));
  }

(* After a successful reload, an open editor may refuse its captured generation. *)
let reload state =
  let state = Daily_interaction_state.reload state in
  (* The route owner re-anchors on the reloaded book (e.g. resets a detail offset). *)
  let state =
    match Screen_registry.for_route state.workspace.route with
    | Some (Screen_registry.Owner o) when not (o.modal (o.get state.screens)) ->
        let value, _ = o.reloaded (screen_env ~config_files:o.config_files state) (o.get state.screens) in
        { state with screens = o.set state.screens value }
    | _ -> state
  in
  if state.blocked then state
  else
    match Screen_registry.modal state.screens with
    | None -> state
    | Some (Screen_registry.Owner o) -> (
        let value, request =
          o.reloaded (screen_env ~config_files:o.config_files state) (o.get state.screens) in
        let state = { state with screens = o.set state.screens value } in
        match request with
        | Screen.Stop_writes why ->
            { state with blocked = true; message = Option.value ~default:state.message why }
        | _ -> state)

(* Home/Calendar [o] and Commands: an empty observation draft over any route. *)
let open_observe state =
  { state with screens = { state.screens with
      observe = Observe_screen.open_editor (screen_env ~config_files:[] state) state.screens.observe } }

let screen_geometry ~dimensions ~width_of state : Screen.geometry =
  let width, body = body_dimensions ~dimensions ~width_of state in
  { screen = dimensions; body = (width, body); content = (width, max 0 (body - 2)); width_of }

let save_config state ~file ~expected ~content ~admission =
  let admitted =
    match admission with
    | Screen.Unconditional -> Ok ()
    | Screen.Household_readable -> (
        try
          match B.of_string (F.read state.session.path) with
          | Error why -> Error ("Household read refused: " ^ why)
          | Ok _ -> Ok ()
        with F.Refused why | Sys_error why -> Error why
          | Unix.Unix_error (err, _, _) -> Error (Unix.error_message err))
    | Screen.Vocabulary_unchanged -> (
        try
          let book = (F.reload state.session).book in
          if B.approved_loci book = B.approved_loci state.session.book
             && B.measures book = B.measures state.session.book then Ok ()
          else Error "Admitted Loci or Measures changed; reopen setup."
        with F.Refused why | Sys_error why -> Error why
          | Unix.Unix_error (err, _, _) -> Error (Unix.error_message err))
  in
  Result.bind admitted (fun () -> write_config_file state file ~expected content)

(* Ledger publications requested by screen owners go through the single writer
   against the current session; the result is reported like any publication. *)
let execute_publication state = function
  | Screen.Add_locus token -> A.commit_add_locus ~session:state.session token
  | Screen.Set_locus_label { locus; label; help } ->
      A.commit_set_locus_label ~session:state.session ~base_bytes:state.session.bytes
        ~id:locus ~label ~help ()
  | Screen.Commit_transaction { transaction; base } ->
      A.commit_transaction ~session:state.session ~base_bytes:base transaction
  | Screen.Reverse_entry { id; day; base } ->
      A.commit_reverse_entry ~session:state.session ~base_bytes:base ~id ~day
  | Screen.Correct_entry { transaction; base } ->
      A.commit_transaction ~session:state.session ~base_bytes:base transaction
  | Screen.Classify_merchant { id; disposition; base; message = _ } ->
      A.commit_classify_merchant ~session:state.session ~base_bytes:base ~id ~disposition
  | Screen.Cancel_plan { id; day; base } ->
      A.commit_cancel_plan ~session:state.session ~base_bytes:base ~id ~day
  | Screen.Plan_batch { plans; replace; base } ->
      A.commit_plan_batch ~replace ~session:state.session ~base_bytes:base plans
  | Screen.Create_plan { plan; base } ->
      A.commit_payload ~session:state.session ~base_bytes:base (A.Plan_tx { plan; replace = false })
  | Screen.Observe_quantities _ -> invalid_arg "observations publish through publish_observation"

(* Observations publish a whole candidate book; their outcomes map directly. *)
let publish_observation state ~rows ~base =
  if base <> state.session.bytes then ({ state with blocked = true }, Screen.Publish_conflict)
  else
    match B.observe_quantities state.session.book rows with
    | Error why -> (state, Screen.Publish_refused ("Observation refused: " ^ why))
    | Ok book -> (
        match (try F.publish state.session book with F.Refused why -> F.Refused_input why) with
        | F.Written session -> (sync { state with session }, Screen.Published)
        | F.Conflict -> ({ state with blocked = true }, Screen.Publish_conflict)
        | F.Refused_input why -> (state, Screen.Publish_refused ("Observation save refused: " ^ why))
        | F.Uncertain -> ({ state with blocked = true }, Screen.Publish_stopped))

(* [saved] hands a configuration save result back to the requesting owner. *)
let rec apply_request ?(saved = fun state _ -> (state, Screen.Stay))
    ?(published = fun state _ -> (state, Screen.Stay)) state = function
  | Screen.Stay | Screen.Ignored -> state
  | Screen.Message message -> { state with message }
  | Screen.Home -> open_route state W.Home
  | Screen.Commands -> { state with overlay = Commands M.initial }
  | Screen.Reload -> reload state
  | Screen.Cycle_measure direction ->
      let current = state.workspace.measure in
      let measure =
        match List.map fst (B.measures state.session.book) with
        | [] -> current
        | measures ->
            let rec next = function
              | [] | [ _ ] -> List.hd measures
              | x :: y :: _ when x = current -> y
              | _ :: rest -> next rest
            in
            let rec prev acc = function
              | [] -> List.hd (List.rev measures)
              | [ x ] when x = current -> (match acc with None -> x | Some p -> p)
              | x :: _ when x = current ->
                  (match acc with None -> List.hd (List.rev measures) | Some p -> p)
              | x :: rest -> prev (Some x) rest
            in
            (match direction with `Next -> next measures | `Prev -> prev None measures)
      in
      { state with workspace = { state.workspace with measure } }
  | Screen.Observe { locus; measure; amount } ->
      { state with screens = { state.screens with
          observe = Observe_screen.open_editor ~locus ~measure ?amount:(Option.map Z.to_string amount)
              (screen_env ~config_files:[] state) state.screens.observe } }
  | Screen.Publish (Screen.Observe_quantities { rows; base }) ->
      let state, outcome = publish_observation state ~rows ~base in
      let state, request = published state outcome in
      apply_request ~saved ~published state request
  | Screen.Open_route route -> open_route state route
  | Screen.Back -> back state
  | Screen.Quit -> state  (* handled by route_screen_input before applying *)
  | Screen.Set_calendar calendar ->
      sync { state with workspace = { state.workspace with calendar; pane = W.Calendar }; scroll = 0;
             message = (if state.blocked then state.message else "") }
  | Screen.Open_observe -> open_observe state
  | Screen.New_plan -> open_plan_record state
  | Screen.Record_action { action; target } -> (
      let target = Option.map (function
          | Screen.Entry e -> W.Actual_entry e | Screen.Plan p -> W.Scheduled_plan p) target in
      match action with
      | Screen.Edit -> edit_target state target
      | Screen.Pay -> pay_target state target
      | Screen.Reverse -> reverse_entry_target state target
      | Screen.Correct_date -> correct_date_target state target
      | Screen.Classify_merchant -> classify_merchant_target state target
      | Screen.Cancel -> cancel_plan_target state target
      | Screen.Batch -> batch_plan_target state target
      | Screen.Generate -> extend_plan_target state target)
  | Screen.New_record -> open_record state
  | Screen.Drill { day; entry } ->
      let parent = state.workspace.route in
      let drilled = open_route state (W.Selected_day day) in
      let day = Selected_day_screen.drill ~entry
          ~parent:(match parent with W.Actual -> "Actual" | _ -> "") drilled.screens.day
          |> Selected_day_screen.synced state.session.book in
      { drilled with screens = { drilled.screens with day };
        drill_parent = Some parent; drill_book = Some state.session.book }
  | Screen.Stop_writes why ->
      { state with blocked = true; message = Option.value ~default:state.message why }
  | Screen.Publish publication ->
      let result = execute_publication state publication in
      let outcome = function
        | A.Published _ | A.Idempotent_duplicate _ -> Screen.Published
        | A.Refused why -> Screen.Publish_refused why
        | A.Conflict | A.Conflict_base_changed -> Screen.Publish_conflict
        | _ -> Screen.Publish_stopped
      in
      (* Editor sessions keep their review open and the Shell reports every
         outcome; Loci and Exchange show refusals and conflicts in their form. *)
      let shell_reports = match publication with
        | Screen.Add_locus _ | Screen.Set_locus_label _ | Screen.Commit_transaction _ -> false
        | _ -> true in
      let published_message = match publication with
        | Screen.Classify_merchant { message; _ } -> Some message | _ -> None in
      let state, request =
        match result with
        | (A.Refused _ | A.Conflict | A.Conflict_base_changed) when not shell_reports ->
            published state (outcome result)
        | _ -> published (apply_commit_result ?published_message state ~draft:state result) (outcome result)
      in
      apply_request ~saved ~published state request
  | Screen.Save_attention { expected; next } ->
      let result =
        Result.map (fun () -> next) (Attention_file.save_file state.attention_path ~expected next) in
      let state = match result with Ok a -> { state with attention = Ok a } | Error _ -> state in
      let state, request = saved state (Result.map ignore result) in
      apply_request ~saved ~published state request
  | Screen.Save_settlements { expected; next } ->
      let result =
        Result.map (fun () -> next) (Settlement_file.save_file state.settlement_path ~expected next) in
      let state = match result with Ok s -> { state with settlements = Ok s } | Error _ -> state in
      let state, request = saved state (Result.map ignore result) in
      apply_request ~saved ~published state request
  | Screen.Save_config { file; expected; content; admission } ->
      let state, request = saved state (save_config state ~file ~expected ~content ~admission) in
      apply_request ~saved ~published state request

let pace_env state = screen_env ~config_files:Pace.config_files state
let balances_env state = screen_env ~config_files:Balances.config_files state

(* Migrated screen owners through the registry. A screen with an open editor
   takes all input but Ctrl-R; otherwise the route's owner sees input after the
   Shell's Ctrl keys and returns Ignored for anything that is not its own. *)
let apply_owner ~dimensions ~width_of (o : _ Screen_registry.owner) state (value, request) =
  apply_request { state with screens = o.set state.screens value } request
    ~saved:(fun state result ->
      let value, request =
        o.saved (screen_env ~config_files:o.config_files state)
          (screen_geometry ~dimensions ~width_of state) result (o.get state.screens) in
      ({ state with screens = o.set state.screens value }, request))
    ~published:(fun state outcome ->
      let value, request =
        o.published (screen_env ~config_files:o.config_files state)
          (screen_geometry ~dimensions ~width_of state) outcome (o.get state.screens) in
      ({ state with screens = o.set state.screens value }, request))

let owner_input ~dimensions ~width_of (Screen_registry.Owner o) state input =
  let value, request =
    o.handle (screen_env ~config_files:o.config_files state)
      (screen_geometry ~dimensions ~width_of state) (o.get state.screens) input in
  match request with
  | Screen.Ignored -> None
  | Screen.Quit -> Some `Quit
  | _ -> Some (`State (apply_owner ~dimensions ~width_of o state (value, request)))

let owner_view ~dimensions ~width_of (Screen_registry.Owner o) state =
  o.view (screen_env ~config_files:o.config_files state)
    (screen_geometry ~dimensions ~width_of state) (o.get state.screens)

let modal_screen_input ~dimensions ~width_of state input =
  Option.bind (Screen_registry.modal state.screens) (fun owner ->
    match owner_input ~dimensions ~width_of owner state input with
    | Some (`State state) -> Some state
    | Some `Quit | None -> Some state)

let route_screen_input ~dimensions ~width_of state input =
  Option.bind (Screen_registry.for_route state.workspace.route) (fun owner ->
    owner_input ~dimensions ~width_of owner state input)

let modal_screen_view ~dimensions ~width_of state =
  Option.map (fun owner -> owner_view ~dimensions ~width_of owner state)
    (Screen_registry.modal state.screens)

let route_screen_view ~dimensions ~width_of state =
  Option.map (fun owner -> owner_view ~dimensions ~width_of owner state)
    (Screen_registry.for_route state.workspace.route)

let config_lines text =
  String.split_on_char '\n' text |> List.filter (fun line ->
    let s = String.trim line in s <> "" && not (String.starts_with ~prefix:"#" s))

let config_token s =
  s <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) s


let open_annual_rollover state =
  if state.blocked || has_record_draft state then
    { state with overlay = No_overlay;
      message = "Resume or discard the retained draft and resolve recovery before starting a year." }
  else
    match state.session.F.annual_year with
    | None -> { state with overlay = No_overlay; message = "Open an explicitly named annual book first." }
    | Some year when year >= 9999 ->
        { state with overlay = No_overlay; message = "No successor year is representable." }
    | Some year ->
        let target = Filename.concat (Filename.dirname state.session.path)
            (Bakhlo_sexp.Annual_scope.file_name (year + 1)) in
        let form = Form.create ~id:"annual_rollover" ~payload:state.session.bytes
            ~title:"Start next annual book"
            ~summary:[
              "Source: " ^ state.session.path;
              "Create: " ^ target;
              "Carry verified evidence and surviving plans; unknown stays unknown.";
              "The source becomes read-only. Only the successor may discharge plans.";
              "No source rewrite, automatic reconciliation or operational cutover.";
            ]
            ~fields:[Form.buttons_field ~id:"decision" ~selected:0
                ~buttons:[
                  { Form.label = "Keep current year"; is_cancel = true };
                  { Form.label = "Create next year"; is_cancel = false };
                ] ()] () in
        { state with overlay = Modal_form form; message = "" }

let open_command state = function
  | M.Record -> open_record { state with overlay = No_overlay }
  | M.New_plan -> open_plan_record { state with overlay = No_overlay }
  | M.Actual -> open_route state W.Actual
  | M.Scheduled -> open_route state W.Scheduled
  | M.Balances -> open_route state W.Balances
  | M.Daily_pace -> open_route state W.Daily_pace
  | M.Attention -> open_route state W.Attention
  | M.Manage_loci | M.Friendly_locus_names -> open_route state W.Loci
  | M.Exchange ->
      let default_date = match state.workspace.route with
        | W.Selected_day day -> day | _ -> state.workspace.calendar.selected_day in
      { state with overlay = No_overlay; message = "";
        screens = { state.screens with exchange = Exchange_screen.open_editor ~default_date state.screens.exchange } }
  | M.Settlements -> open_route state W.Settlements
  | M.Observe -> { (open_observe state) with overlay = No_overlay; message = "" }
  | M.Home -> open_route state W.Home
  | M.Income_expense -> open_route state W.Income_expense
  | M.Stock_flow -> open_route state W.Stock_flow
  | M.Transactions_flow -> open_route state W.Transactions_flow
  | M.Calendar -> open_route state W.Calendar
  | M.Pace_pool ->
      { state with overlay = No_overlay; message = "";
        screens = { state.screens with pace = Pace.open_pool (pace_env state) state.screens.pace } }
  | M.Cycle_boundaries ->
      let pace, request = Pace.open_cycle (pace_env state) state.screens.pace in
      apply_request { state with overlay = No_overlay; screens = { state.screens with pace } } request
  | M.Balance_display ->
      let state = open_route state W.Balances in
      let balances, request = Balances.open_config (balances_env state) state.screens.balances in
      apply_request { state with screens = { state.screens with balances } } request
  | M.Annual_rollover -> open_annual_rollover state
  | M.Theme ->
      let rec index i = function
        | [] -> 0
        | theme :: rest -> if theme = state.theme then i else index (i + 1) rest
      in
      let return_menu = match state.overlay with Commands menu -> menu | _ -> M.initial in
      { state with overlay = Themes { selected = index 0 P.all_themes;
                                     original = state.theme; return_menu } }

let browser_pane_widths width =
  if width < 80 then (width, width)
  else let left = max 36 (min 58 (width * 52 / 100)) in (left, width - left - 1)

let print_motion = function
  | `Key ((`Home | `End | `Page _ | `ASCII ('j' | 'k') | `Arrow (`Up | `Down)), [])
  | `Key (`ASCII ('u' | 'd'), [`Ctrl]) -> true
  | _ -> false

