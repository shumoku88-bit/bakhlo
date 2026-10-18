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

let reversal_dimensions ~dimensions ~width_of state =
  Rev.dimensions (body_dimensions ~dimensions ~width_of state)

let date_dimensions ~dimensions ~width_of state =
  Date.dimensions (body_dimensions ~dimensions ~width_of state)
let merchant_dimensions ~dimensions ~width_of state =
  Merchant.dimensions (body_dimensions ~dimensions ~width_of state)


let scheduled_dimensions ~dimensions ~width_of state =
  Sch.dimensions (body_dimensions ~dimensions ~width_of state)

let continuation_dimensions ~dimensions ~width_of state =
  Cont.dimensions (body_dimensions ~dimensions ~width_of state)

let cancellation_dimensions ~dimensions ~width_of state =
  Cancel.dimensions (body_dimensions ~dimensions ~width_of state)

let bulk_dimensions ~dimensions ~width_of state =
  Bulk.dimensions (body_dimensions ~dimensions ~width_of state)

let generate_dimensions ~dimensions ~width_of state =
  Gen.dimensions (body_dimensions ~dimensions ~width_of state)

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
      Form.action_buttons ~confirm:"Preview Exchange" ~cancel:"Cancel" ();
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

let observe_quantity_form ?default_locus ?default_measure ?current_amount ?(rows = []) ?(notice = "") state =
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
  let summary =
    [ "Record newly verified balance for an account (Locus).";
      "Existing observations for other loci remain preserved." ]
    @ (if rows = [] then ["  (no observations added yet)"]
       else List.mapi (fun i (l, m, q) ->
         Printf.sprintf "  %d. %s  %s %s" (i + 1) l (B.format state.session.book m q) m) rows)
    @ [ "Enter on amount adds a row; Preview reviews all rows without writing." ]
  in
  Form.create
    ~id:"observe_quantity"
    ~title:"Observe Quantities"
    ~notice
    ~summary
    ~fields:[
      Form.text_field ~id:"locus" ~label:"Locus" ~value:locus_val ~placeholder:(Printf.sprintf "e.g. %s" locus_ph) ();
      Form.text_field ~id:"measure" ~label:"Measure" ~value:def_measure ();
      Form.text_field ~id:"amount" ~label:"Observed amount" ~placeholder:amount_ph ();
      Form.buttons_field ~id:"action"
        ~buttons:[ { Form.label = "Add"; is_cancel = false };
                   { Form.label = "Preview"; is_cancel = false };
                   { Form.label = "Cancel"; is_cancel = true } ] ();
    ]
    ()

let observe_preview_form state rows ~notice =
  let lines = List.mapi (fun i (l, m, q) ->
    Printf.sprintf "  %d. %s  %s %s" (i + 1) l (B.format state.session.book m q) m) rows in
  Form.create
    ~id:"observe_preview"
    ~title:"Observe / Preview"
    ~notice
    ~summary:(
      [ "New reconciliation group:";
        "All rows describe quantities observed together at this boundary.";
        "Unmentioned prior observations are preserved; re-observed move here.";
        "The shared publisher derives the Event root cut." ]
      @ (if lines = [] then ["  (none)"] else lines)
      @ [ "Tab select  Enter confirm  e edit  Esc cancel" ])
    ~fields:[Form.buttons_field ~id:"action"
      ~buttons:[ { Form.label = "Publish"; is_cancel = false };
                 { Form.label = "Edit"; is_cancel = true };
                 { Form.label = "Cancel"; is_cancel = true } ] ()]
    ()

let open_observe state =
  { state with overlay = Modal_form (observe_quantity_form state);
    observe_draft = Some { rows = []; base_bytes = state.session.bytes;
      pending = ("", state.workspace.measure, ""); uncertain = false }; message = "" }

let edit_observe state (draft : observe_draft) =
  let locus, measure, amount = draft.pending in
  let form = observe_quantity_form ~default_locus:locus ~default_measure:measure
      ~rows:draft.rows state |> fun form -> Form.set_text form "amount" amount in
  { state with overlay = Modal_form form }

let review_fits ~dimensions ~width_of state form =
  let body_w, body_h = body_dimensions ~dimensions ~width_of state in
  let pane_w = min 64 (max 8 (body_w - 4)) in
  let rows = Form.render_rows ~width:(max 0 (pane_w - 6))
      ~height:max_int ~width_of form in
  pane_w >= 48 && List.length rows <= Panel.capacity ~height:body_h ~heading:false

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
  match read_config state "accounting-roles.tsv" with
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
    measure = state.workspace.measure;
    today = F.today ();
    annual = {
      year = state.session.F.annual_year;
      unavailable = lazy (annual_unavailable state);
      history = lazy (annual_history_bounds state);
    };
    accounting_roles = lazy (accounting_roles state);
    blocked = state.blocked;
    config = (fun name ->
      match List.assoc_opt name captured with
      | Some bytes -> bytes
      | None -> Error ("Configuration " ^ name ^ " was not declared by this screen."));
  }

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

(* [saved] hands a configuration save result back to the requesting owner. *)
let rec apply_request ?(saved = fun state _ -> (state, Screen.Stay)) state = function
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
      let current_amount = Option.map Z.to_string amount in
      let form = observe_quantity_form ~default_locus:locus ~default_measure:measure
          ?current_amount state in
      let form = Form.set_focused form (Form.find_field_index form "amount") in
      { state with overlay = Modal_form form;
        observe_draft = Some { rows = []; base_bytes = state.session.bytes;
          pending = ("", state.workspace.measure, ""); uncertain = false } }
  | Screen.Save_config { file; expected; content; admission } ->
      let state, request = saved state (save_config state ~file ~expected ~content ~admission) in
      apply_request ~saved state request

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

let owner_input ~dimensions ~width_of (Screen_registry.Owner o) state input =
  let value, request =
    o.handle (screen_env ~config_files:o.config_files state)
      (screen_geometry ~dimensions ~width_of state) (o.get state.screens) input in
  if request = Screen.Ignored then None
  else Some (apply_owner ~dimensions ~width_of o state (value, request))

let owner_view ~dimensions ~width_of (Screen_registry.Owner o) state =
  o.view (screen_env ~config_files:o.config_files state)
    (screen_geometry ~dimensions ~width_of state) (o.get state.screens)

let modal_screen_input ~dimensions ~width_of state input =
  Option.bind (Screen_registry.modal state.screens) (fun owner ->
    match owner_input ~dimensions ~width_of owner state input with
    | Some state -> Some state
    | None -> Some state)

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
  | M.Exchange -> open_exchange { state with overlay = No_overlay }
  | M.Settlements -> open_route state W.Settlements
  | M.Observe -> open_observe state
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

let set_locus_label_form ~locus ~current_label ~current_help =
  Form.create
    ~id:"set_locus_label"
    ~payload:locus
    ~title:("Edit Display Name / " ^ locus)
    ~summary:[
      "Target Locus: " ^ locus;
      "Display name is shown across views instead of the raw coordinate token.";
      "Help text provides description in locus detail.";
    ]
    ~fields:[
      Form.text_field ~id:"label" ~label:"Display name" ~value:current_label ();
      Form.text_field ~id:"help" ~label:"Help / description (optional)" ~value:current_help ();
      Form.action_buttons ~confirm:"Review" ~cancel:"Cancel" ();
    ]
    ()

let review_locus_label locus label help =
  Form.create
    ~id:"review_locus_label"
    ~payload:locus
    ~title:"Review Locus Display Name"
    ~summary:[
      "Stable identity: " ^ locus;
      "Display name:    " ^ label;
      "Help:            " ^ help;
    ]
    ~fields:[
      Form.action_buttons ~confirm:"Save display name" ~cancel:"Edit" ();
    ]
    ()

let exchange_review_form ~canon_day ~memo ~src_locus ~src_measure ~src_quanta_str ~dst_locus ~dst_measure ~dst_quanta_str =
  let memo_line = match memo with Some m -> "Description:        " ^ m | None -> "Description:        (none)" in
  Form.create
    ~id:"review_exchange"
    ~title:"Exchange / Preview"
    ~summary:[
      "Date:               " ^ canon_day;
      memo_line;
      Printf.sprintf "Source Effect:      -%s %s at %s" src_quanta_str src_measure src_locus;
      Printf.sprintf "Destination Effect: +%s %s at %s" dst_quanta_str dst_measure dst_locus;
      "Exact observed quantities only; no FX rate is inferred.";
    ]
    ~fields:[
      Form.action_buttons ~confirm:"Publish Exchange" ~cancel:"Edit" ();
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
let print_motion = function
  | `Key ((`Home | `End | `Page _ | `ASCII ('j' | 'k') | `Arrow (`Up | `Down)), [])
  | `Key (`ASCII ('u' | 'd'), [`Ctrl]) -> true
  | _ -> false

