(* Shell dispatch: screen env/geometry, owner input/view, request application,
   reload, back navigation and Commands. *)
open Shell_state
open Shell_files
open Shell_publication
open Shell_record_actions

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

let back state =
  match state.drill_parent with
  | Some W.Actual ->
      let before = Option.value ~default:state.session.book state.drill_book in
      let screens, _ =
        Screen_registry.book_changed W.Actual ~before ~after:state.session.book state.screens
      in
      {
        state with
        drill_parent = None;
        drill_book = None;
        workspace = W.enter state.workspace W.Actual;
        overlay = No_overlay;
        screens;
      }
  | _ -> open_route state W.Home

(* Shell side of the screen owner protocol ({!Screen}). *)
let screen_env ~config_files state : Screen.env =
  let captured = List.map (fun name -> (name, read_pace_config state name)) config_files in
  {
    book = state.session.book;
    revision = state.session.revision;
    new_id = F.new_id;
    measure = state.workspace.measure;
    today = Clock.today ();
    accounting_roles = lazy (accounting_roles state);
    attention = attention state;
    settlements = state.settlements;
    blocked = state.blocked;
    draft_retained = has_record_draft state;
    config =
      (fun name ->
        match List.assoc_opt name captured with
        | Some bytes -> bytes
        | None -> Error ("Configuration " ^ name ^ " was not declared by this screen."));
  }

(* After a successful reload, an open editor may refuse its captured generation. *)
let reload state =
  let state = Shell_state.reload state in
  (* The route owner re-anchors on the reloaded book (e.g. resets a detail offset). *)
  let state =
    match Screen_registry.for_route state.workspace.route with
    | Some (Screen_registry.Owner o) when not (o.modal (o.get state.screens)) ->
        let value, _ =
          o.reloaded (screen_env ~config_files:o.config_files state) (o.get state.screens)
        in
        { state with screens = o.set state.screens value }
    | _ -> state
  in
  if state.blocked then state
  else
    match Screen_registry.modal state.screens with
    | None -> state
    | Some (Screen_registry.Owner o) -> (
        let value, request =
          o.reloaded (screen_env ~config_files:o.config_files state) (o.get state.screens)
        in
        let state = { state with screens = o.set state.screens value } in
        match request with
        | Screen.Stop_writes why ->
            { state with blocked = true; message = Option.value ~default:state.message why }
        | _ -> state)

(* Home [o] and Commands: an empty observation draft over any route. *)
let open_observe state =
  {
    state with
    screens =
      {
        state.screens with
        observe =
          Observe_screen.open_editor (screen_env ~config_files:[] state) state.screens.observe;
      };
  }

let route_layout state =
  match Screen_registry.for_route state.workspace.route with
  | Some (Screen_registry.Owner owner) -> owner.layout
  | None -> Screen.Standard

let canvas_dimensions layout (width, height) =
  match layout with
  | Screen.Standard -> (width, height)
  | Screen.Workspace -> ((if width > 1 then width - 1 else width), max 0 (height - 1))

let screen_geometry ?layout ~dimensions ~width_of state : Screen.geometry =
  let layout = Option.value ~default:(route_layout state) layout in
  let canvas = canvas_dimensions layout dimensions in
  let width, body = body_dimensions ~dimensions:canvas ~width_of state in
  let content_height =
    match layout with Screen.Standard -> max 0 (body - 2) | Screen.Workspace -> body
  in
  { screen = dimensions; body = (width, body); content = (width, content_height); width_of }

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
        | measures -> (
            let rec next = function
              | [] | [ _ ] -> List.hd measures
              | x :: y :: _ when x = current -> y
              | _ :: rest -> next rest
            in
            let rec prev acc = function
              | [] -> List.hd (List.rev measures)
              | [ x ] when x = current -> ( match acc with None -> x | Some p -> p)
              | x :: _ when x = current -> (
                  match acc with None -> List.hd (List.rev measures) | Some p -> p)
              | x :: rest -> prev (Some x) rest
            in
            match direction with `Next -> next measures | `Prev -> prev None measures)
      in
      { state with workspace = { state.workspace with measure } }
  | Screen.Observe { locus; measure; amount } ->
      {
        state with
        screens =
          {
            state.screens with
            observe =
              Observe_screen.open_editor ~locus ~measure ?amount:(Option.map Z.to_string amount)
                (screen_env ~config_files:[] state)
                state.screens.observe;
          };
      }
  | Screen.Publish (Screen.Observe_quantities { rows; base }) ->
      let state, outcome = publish_observation state ~rows ~base in
      let state, request = published state outcome in
      apply_request ~saved ~published state request
  | Screen.Open_route route -> open_route state route
  | Screen.Back -> back state
  | Screen.Quit -> state (* handled by route_screen_input before applying *)
  | Screen.Open_observe -> open_observe state
  | Screen.New_plan -> open_plan_record state
  | Screen.Record_action { action; target } -> (
      match action with
      | Screen.Edit -> edit_target state target
      | Screen.Pay -> pay_target state target
      | Screen.Reverse -> reverse_entry_target state target
      | Screen.Correct_date -> correct_date_target state target
      | Screen.Classify_merchant -> classify_merchant_target state target
      | Screen.Cancel -> cancel_plan_target state target
      | Screen.Batch -> batch_plan_target state target
      | Screen.Generate -> extend_plan_target state target
      | Screen.Generate_every months -> extend_plan_target ~cadence_months:months state target)
  | Screen.New_record -> open_record state
  | Screen.Drill { day; entry } ->
      let parent = state.workspace.route in
      let drilled = open_route state (W.Selected_day day) in
      let day =
        Selected_day_screen.drill ~entry
          ~parent:(match parent with W.Actual -> "Actual" | _ -> "")
          drilled.screens.day
        |> Selected_day_screen.synced state.session.book
      in
      {
        drilled with
        screens = { drilled.screens with day };
        drill_parent = Some parent;
        drill_book = Some state.session.book;
      }
  | Screen.Stop_writes why ->
      { state with blocked = true; message = Option.value ~default:state.message why }
  | Screen.Publish publication -> (
      let result = execute_publication state publication in
      (* Editor sessions keep their review open and the Shell reports every
         outcome; Loci and Exchange show refusals and conflicts in their form. *)
      let shell_reports =
        match publication with
        | Screen.Add_locus _ | Screen.Set_locus_label _ | Screen.Commit_transaction _ -> false
        | _ -> true
      in
      let published_message =
        match publication with Screen.Classify_merchant { message; _ } -> Some message | _ -> None
      in
      let state, request =
        match result with
        | (A.Refused _ | A.Conflict | A.Conflict_base_changed) when not shell_reports ->
            published state (publish_outcome result)
        | _ ->
            published
              (apply_commit_result ?published_message state ~draft:state result)
              (publish_outcome result)
      in
      let state = apply_request ~saved ~published state request in
      match (publication, result) with
      | Screen.Create_plan { plan; offer_pace = true; _ }, A.Published _ ->
          offer_created_pace state plan.id
      | _ -> state)
  | Screen.Save_attention { expected; next } ->
      let state, result = save_attention state ~expected next in
      let state, request = saved state result in
      apply_request ~saved ~published state request
  | Screen.Save_settlements { expected; next } ->
      let result =
        Result.map (fun () -> next) (Settlement_file.save_file state.settlement_path ~expected next)
      in
      let state =
        match result with Ok s -> { state with settlements = Ok s } | Error _ -> state
      in
      let state, request = saved state (Result.map ignore result) in
      apply_request ~saved ~published state request
  | Screen.Save_config { file; expected; content; admission } ->
      let state, result = save_config state ~file ~expected ~content ~admission in
      let state, request = saved state result in
      apply_request ~saved ~published state request

(* LOAM finishCreated: an ordinary creation offers the published plan's expected
   pace once, re-read from the reloaded book. The chooser is the Scheduled
   owner's modal over the current route, so leaving it returns to wherever the
   creation was started. *)
and offer_created_pace state id =
  match List.find_opt (fun (p : B.plan) -> p.id = id) (B.plans state.session.book) with
  | None ->
      {
        state with
        message =
          state.message ^ " Expected-pace setup unavailable: new Scheduled identity not found.";
      }
  | Some plan ->
      let scheduled, request =
        Scheduled_screen.open_created_pace
          (screen_env ~config_files:Scheduled_screen.config_files state)
          state.screens.scheduled plan
      in
      apply_request { state with screens = { state.screens with scheduled } } request

let pace_env state = screen_env ~config_files:Pace.config_files state
let balances_env state = screen_env ~config_files:Balances.config_files state

(* Migrated screen owners through the registry. A screen with an open editor
   takes all input but Ctrl-R; otherwise the route's owner sees input after the
   Shell's Ctrl keys and returns Ignored for anything that is not its own. *)
let owner_layout (o : _ Screen_registry.owner) state =
  if o.owns state.workspace.route then o.layout else route_layout state

let apply_owner ~dimensions ~width_of (o : _ Screen_registry.owner) state (value, request) =
  let layout = owner_layout o state in
  apply_request
    { state with screens = o.set state.screens value }
    request
    ~saved:(fun state result ->
      let value, request =
        o.saved
          (screen_env ~config_files:o.config_files state)
          (screen_geometry ~layout ~dimensions ~width_of state)
          result (o.get state.screens)
      in
      ({ state with screens = o.set state.screens value }, request))
    ~published:(fun state outcome ->
      let value, request =
        o.published
          (screen_env ~config_files:o.config_files state)
          (screen_geometry ~layout ~dimensions ~width_of state)
          outcome (o.get state.screens)
      in
      ({ state with screens = o.set state.screens value }, request))

let owner_input ~dimensions ~width_of (Screen_registry.Owner o) state input =
  let layout = owner_layout o state in
  let value, request =
    o.handle
      (screen_env ~config_files:o.config_files state)
      (screen_geometry ~layout ~dimensions ~width_of state)
      (o.get state.screens) input
  in
  match request with
  | Screen.Ignored -> None
  | Screen.Quit -> Some `Quit
  | _ -> Some (`State (apply_owner ~dimensions ~width_of o state (value, request)))

let owner_view ~dimensions ~width_of (Screen_registry.Owner o) state =
  let layout = owner_layout o state in
  o.view
    (screen_env ~config_files:o.config_files state)
    (screen_geometry ~layout ~dimensions ~width_of state)
    (o.get state.screens)

let modal_screen_input ~dimensions ~width_of state input =
  Option.bind (Screen_registry.modal state.screens) (fun owner ->
      match owner_input ~dimensions ~width_of owner state input with
      | Some (`State state) -> Some state
      | Some `Quit | None -> Some state)

let route_screen_input ~dimensions ~width_of state input =
  Option.bind (Screen_registry.for_route state.workspace.route) (fun owner ->
      owner_input ~dimensions ~width_of owner state input)

let route_screen_view ~dimensions ~width_of state =
  Option.map
    (fun owner -> owner_view ~dimensions ~width_of owner state)
    (Screen_registry.for_route state.workspace.route)

let modal_screen_view ~dimensions ~width_of state =
  Option.map
    (fun owner -> owner_view ~dimensions ~width_of owner state)
    (Screen_registry.modal state.screens)

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
      let default_date =
        match state.workspace.route with
        | W.Selected_day day -> day
        | _ -> state.workspace.focus_day
      in
      {
        state with
        overlay = No_overlay;
        message = "";
        screens =
          {
            state.screens with
            exchange = Exchange_screen.open_editor ~default_date state.screens.exchange;
          };
      }
  | M.Settlements -> open_route state W.Settlements
  | M.Home -> open_route state W.Home
  | M.Income_expense -> open_route state W.Income_expense
  | M.Stock_flow -> open_route state W.Stock_flow
  | M.Liquidity -> open_route state W.Liquidity
  | M.Multicurrency_spend -> open_route state W.Multicurrency_spend
  | M.Transactions_flow -> open_route state W.Transactions_flow
  | M.Trend_locus -> open_route state W.Trend_locus
  | M.Pace_pool ->
      {
        state with
        overlay = No_overlay;
        message = "";
        screens = { state.screens with pace = Pace.open_pool (pace_env state) state.screens.pace };
      }
  | M.Cycle_boundaries ->
      let pace, request = Pace.open_cycle (pace_env state) state.screens.pace in
      apply_request
        { state with overlay = No_overlay; screens = { state.screens with pace } }
        request
  | M.Balance_display ->
      let state = open_route state W.Balances in
      let balances, request = Balances.open_config (balances_env state) state.screens.balances in
      apply_request { state with screens = { state.screens with balances } } request
  | M.Theme ->
      let rec index i = function
        | [] -> 0
        | theme :: rest -> if theme = state.theme then i else index (i + 1) rest
      in
      let return_menu = match state.overlay with Commands menu -> menu | _ -> M.initial in
      {
        state with
        overlay = Themes { selected = index 0 P.all_themes; original = state.theme; return_menu };
      }
