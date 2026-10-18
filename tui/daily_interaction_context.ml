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

let balance_view_coords state =
  Result.bind (read_pace_config state "balance-view.tsv") (function
    | None -> Ok None
    | Some text ->
        Result.map (fun coords ->
          Some (List.map (fun (c : BalView.coordinate) -> (c.locus, c.measure)) coords))
          (BalView.of_string text))

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

let checked_report_period state preset offset =
  match annual_unavailable state with
  | Some why -> Error why
  | None ->
      Result.bind (read_pace_config state "boundary-presets.tsv") (fun boundary_presets_text ->
        Result.bind (IncExp.resolve_period ~today:(F.today ()) ~preset ~offset ~boundary_presets_text)
          (fun period ->
            Result.bind (annual_history_bounds state) (function
              | None -> Ok period
              | Some (start_day, end_exclusive) ->
                  if preset = IncExp.All_time then
                    Ok { period with start_day; end_exclusive; label = "Selected linked annual history" }
                  else if period.IncExp.start_day < start_day || period.end_exclusive > end_exclusive then
                    Error "Requested period extends outside verified annual history. Open the required linked years."
                  else Ok period)))
let stock_flow_result state =
  let parse_selection text =
    let valid_token s =
      s <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) s
    in
    let rec rows acc = function
      | [] -> Ok (List.rev acc)
      | raw :: rest ->
          let line = String.trim raw in
          if line = "" || String.starts_with ~prefix:"#" line || String.starts_with ~prefix:";" line then
            rows acc rest
          else match String.split_on_char '\t' line with
          | [locus; measure] when valid_token locus && valid_token measure ->
              rows ((locus, measure) :: acc) rest
          | _ -> Error "Invalid balance-view.tsv; no partial selection used."
    in
    rows [] (String.split_on_char '\n' text)
  in
  Result.bind (read_pace_config state "balance-view.tsv") (function
    | None -> Error "Stock–Flow requires an explicit balance-view.tsv selection."
    | Some text ->
        Result.bind (parse_selection text) (fun tracked_coords ->
          match tracked_coords with
          | [] -> Error "Stock–Flow requires a nonempty balance-view.tsv selection."
          | (_, measure) :: _ ->
              Result.bind
                (checked_report_period state state.stock_flow.preset state.stock_flow.period_offset)
                (fun period -> StockFlow.compute_report ~book:state.session.book
                   ~measure ~tracked_coords ~period)))

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

let move_pace_selection state delta =
  let position =
    Result.bind (read_pace_config state "boundary-presets.tsv") (fun boundary_presets_text ->
      Trend.move_selection ~today:(F.today ()) ~preset:state.pace_trend.preset
        ~boundary_presets_text ~position:state.pace_trend.selected_index delta)
  in
  match position with
  | Ok selected_index ->
      { state with pace_trend = { state.pace_trend with selected_index }; scroll = 0 }
  | Error why -> { state with message = "Daily Pace range unavailable: " ^ why }

let current_pace_result state =
  match annual_unavailable state with
  | Some why -> Error why
  | None ->
  let current_year = String.sub (F.today ()) 0 4 in
  if (match state.session.F.annual_year with
      | Some year -> current_year <> Printf.sprintf "%04d" year
      | None -> false) then Error "Daily Pace requires the current calendar year's annual book."
  else
  let today = F.today () and measure = state.workspace.measure in
  Result.bind (resolve_pace_pool state) (fun pool ->
    Result.bind (resolve_pace_window state) (fun (start_day, end_exclusive) ->
      Result.map (fun p -> (p, start_day, end_exclusive))
        (Result.map_error Trend.format_pace_error
           (B.daily_pace state.session.book ~measure ~pool ~observed_at:today ~end_exclusive))))

let what_if_form ?amount ?result state =
  let summary =
    match current_pace_result state with
    | Ok (pace, _start, _end_excl) ->
        let fmt q = O.format_money state.session.book pace.B.measure q ^ " " ^ pace.measure in
        [
          "Current pace: " ^ fmt pace.daily_pace_quanta ^ "/day";
          "Pool balance: " ^ fmt pace.eligible_pool;
          "Protected Scheduled: " ^ fmt pace.automatic_deductions;
          Printf.sprintf "Available: %s over %d remaining days." (fmt pace.available_through_end) pace.remaining_days;
          "Simulate an immediate purchase; no transaction or reservation is published.";
        ]
    | Error why ->
        [ Printf.sprintf "Daily pace unavailable (%s); simulation is disabled." why ]
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

let pool_rows_of_text ~measure text =
  let rec coords acc = function
    | [] -> Ok (List.rev acc)
    | line :: rest ->
        (match String.split_on_char '\t' line with
         | [locus; m] when config_token locus && m = measure && config_token m ->
             if List.mem locus acc then Error "Duplicate Daily Pace coordinate."
             else coords (locus :: acc) rest
         | [_; m] when config_token m && m <> measure ->
             Error ("Existing Pool uses another Measure: " ^ m ^ ". Refusing replacement.")
         | _ -> Error "Malformed daily-pace.tsv; no rows were skipped.")
  in
  coords [] (config_lines text)

let pool_old_of_payload ~measure payload =
  if payload = "missing" then Ok []
  else if String.starts_with ~prefix:"present\n" payload then
    pool_rows_of_text ~measure (String.sub payload 8 (String.length payload - 8))
  else Error "Pool configuration was unreadable; reopen after repairing it."

let configure_pace_form state =
  let measure = state.workspace.measure in
  let payload, read_notice = match read_pace_config state "daily-pace.tsv" with
    | Ok None -> ("missing", "")
    | Ok (Some text) -> ("present\n" ^ text, "")
    | Error why -> ("unreadable", why)
  in
  let old_loci, old_why =
    match pool_old_of_payload ~measure payload with
    | Ok loci -> (loci, None)
    | Error why -> ([], Some why)
  in
  let notice = if read_notice <> "" then read_notice else Option.value ~default:"" old_why in
  let period = match resolve_pace_window state with
    | Ok (start, stop) -> Printf.sprintf "Explicit period: %s -> %s (exclusive)." start stop
    | Error why -> why
  in
  Form.create ~id:"configure_daily_pace" ~payload ~notice
    ~title:"Configure Daily Pace Pool"
    ~summary:(
      [ "Measure: " ^ measure; "Existing Pool (captured):" ]
      @ (match old_why with
         | Some why -> [why]
         | None when old_loci = [] -> ["  (none)"]
         | None -> List.map (fun locus -> "  " ^ locus ^ " " ^ measure) old_loci)
      @ [ period; "Only daily-pace.tsv changes after Review." ])
    ~fields:[
      Form.text_field ~id:"pool_loci" ~label:"Accounts" ~value:(String.concat ", " old_loci) ();
      Form.action_buttons ~confirm:"Review" ~cancel:"Cancel" ();
    ] ()

let pool_review_form measure old_loci new_loci =
  Form.create ~id:"review_pool" ~title:"Review Pool accounts"
    ~summary:(
      [ "Measure: " ^ measure;
        "Only daily-pace.tsv changes.";
        "Old:" ]
      @ (if old_loci = [] then ["  (none)"] else List.map (fun l -> "  " ^ l) old_loci)
      @ ["New:"]
      @ (if new_loci = [] then ["  (none)"] else List.map (fun l -> "  " ^ l) new_loci))
    ~fields:[Form.action_buttons ~confirm:"Save" ~cancel:"Edit" ()] ()

let open_pool_editor state =
  let measure = state.workspace.measure in
  match state.pool_draft with
  | Some (draft_measure, draft) when draft_measure = measure ->
      { state with overlay = Modal_form draft; pool_review = None; message = "" }
  | _ -> { state with overlay = Modal_form (configure_pace_form state);
      pool_review = None; message = "" }

let decode_boundary_presets text =
  let canonical_date day =
    match A.normalize_date day with Ok canonical -> canonical = day | Error _ -> false
  in
  let rec increasing = function
    | a :: b :: rest -> a < b && increasing (b :: rest)
    | [] | [_] -> true
  in
  let lines =
    match List.rev (String.split_on_char '\n' text) with
    | "" :: rest -> List.rev rest
    | rows -> List.rev rows
  in
  let rec loop names acc = function
    | [] -> Ok (List.rev acc)
    | line :: rest ->
        if String.starts_with ~prefix:"#" (String.trim line) then loop names acc rest
        else match String.split_on_char '\t' line with
        | name :: dates
          when config_token name && not (List.mem name names)
               && List.length dates >= 2 && List.for_all canonical_date dates
               && increasing dates ->
            loop (name :: names) ((name, dates) :: acc) rest
        | _ -> Error "Boundary preset config malformed. Refusing implicit replacement."
  in
  loop [] [] lines

let current_window_for presets today =
  let rec window_in = function
    | a :: b :: tail -> if a <= today && today < b then Some (a, b) else window_in (b :: tail)
    | _ -> None
  in
  let windows = List.filter_map (fun (name, dates) ->
    Option.map (fun (a, b) -> (name, a, b)) (window_in dates)) presets in
  match windows with
  | [w] -> Ok w
  | [] -> Error "no configured boundary preset contains the current date"
  | _ -> Error "multiple configured boundary presets contain the current date"

let cycle_boundaries_form state =
  let today = F.today () in
  Result.bind (read_pace_config state "boundary-presets.tsv") (fun raw ->
    Result.map (fun presets ->
      let name, dates =
        match current_window_for presets today with
        | Ok (source, _, _) ->
            let ds = Option.value ~default:[] (List.assoc_opt source presets) in
            (source, String.concat ", " ds)
        | Error _ ->
            (match presets with
             | [(n, ds)] -> (n, String.concat ", " ds)
             | _ -> ("pension", ""))
      in
      let payload = match raw with None -> "missing" | Some text -> "present\n" ^ text in
      Form.create ~id:"configure_cycle_boundaries" ~payload
        ~title:"Daily Pace / Cycle boundaries"
        ~summary:[
          "Enter explicit dates, including today's cycle (" ^ today ^ ").";
          "Example: 2026-10-15, 2026-12-15";
          "No dates are extrapolated or repeated; other presets stay untouched.";
        ]
        ~fields:[
          Form.text_field ~id:"name" ~label:"Name" ~value:name ();
          Form.text_field ~id:"dates" ~label:"Dates" ~value:dates ();
          Form.action_buttons ~confirm:"Review" ~cancel:"Cancel" ();
        ] ())
      (match raw with None -> Ok [] | Some text -> decode_boundary_presets text))

let cycle_boundaries_review name dates =
  Form.create ~id:"review_cycle_boundaries" ~title:"Daily Pace / Review explicit cycle boundaries"
    ~summary:(
      [ "Preset: " ^ name;
        "Only this named preset will be replaced.";
        "No dates are extrapolated or repeated.";
        "Other named presets and ledger remain unchanged.";
        "Boundaries:" ]
      @ List.map (fun d -> "  " ^ d) dates)
    ~fields:[Form.action_buttons ~confirm:"Save boundaries" ~cancel:"Edit" ()] ()


let balance_display_review measure chosen =
  Form.create ~id:"review_balance_view" ~title:"Review visible accounts"
    ~summary:(
      [ "Measure: " ^ measure;
        "Only the selected Measure's display rows will change.";
        "Other Measures and household quantities stay untouched.";
        "Selected in display order:" ]
      @ (if chosen = [] then ["(none)"] else
           List.map (fun (c : BalView.coordinate) -> c.locus ^ " × " ^ c.measure) chosen))
    ~fields:[Form.buttons_field ~id:"action"
      ~buttons:[ { Form.label = "Save selection"; is_cancel = false };
                 { Form.label = "Edit"; is_cancel = true } ] ()] ()

let open_balance_picker state =
  match read_pace_config state "balance-view.tsv" with
  | Error why -> { state with overlay = No_overlay;
      balance_review = None; message = "Balance setup unavailable: " ^ why }
  | Ok raw -> (
      let previous = match raw with
        | None -> Ok [] | Some text -> BalView.of_string text in
      match previous with
      | Error _why -> { state with overlay = No_overlay;
          balance_review = None; message = "Balance setup unavailable: malformed balance-view.tsv." }
      | Ok previous ->
          let measure = state.workspace.measure in
          let old = List.filter_map (fun (c : BalView.coordinate) ->
            if c.measure = measure then Some c.locus else None) previous in
          let approved = Option.value ~default:[] (B.approved_loci state.session.book) in
          let candidates = old @ List.filter (fun l -> not (List.mem l old)) approved in
          let cursor = 0 in
          { state with overlay = Balance_picker { candidates; chosen = old;
              cursor; raw_before = raw; previous };
            balance_review = None; message = "" })

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
  | M.Pace_pool -> open_pool_editor state
  | M.Cycle_boundaries ->
      (match cycle_boundaries_form state with
       | Ok form -> { state with overlay = Modal_form form; cycle_review = None; message = "" }
       | Error why -> { state with overlay = No_overlay; cycle_review = None; message = "Cycle setup unavailable: " ^ why })
  | M.Balance_display -> open_balance_picker state
  | M.Annual_rollover -> open_annual_rollover state
  | M.Theme ->
      let rec index i = function
        | [] -> 0
        | theme :: rest -> if theme = state.theme then i else index (i + 1) rest
      in
      let return_menu = match state.overlay with Commands menu -> menu | _ -> M.initial in
      { state with overlay = Themes { selected = index 0 P.all_themes;
                                     original = state.theme; return_menu } }

let balance_items state =
  match state.balance_mode with
  | `Accounting ->
      let roles = accounting_roles state in
      O.role_balance_items ~book:state.session.book ~roles
  | `Current ->
      (match balance_view_coords state with
       | Ok coords -> O.current_balance_items ~book:state.session.book ~coords
       | Error why -> [O.Header_row ("Balance view unavailable: " ^ why)])

let balance_lines ?(width_of = String.length) ?(width = max_int) state =
  let items = balance_items state in
  List.map (O.balance_item_line ~width_of ~width ~book:state.session.book) items

let balance_print_fits rows =
  let rec fits bytes = function
    | [] -> true
    | row :: rest ->
        let size = String.length row + 1 in
        size <= 32768 - bytes && fits (bytes + size) rest in
  List.length rows <= 200 && fits 0 rows

let balance_print_preview state =
  let refused summary =
    Form.create ~id:"balance_print_refused" ~title:(tr "Print Refused") ~summary
      ~fields:[ Form.action_buttons ~confirm:(tr "OK") ~cancel:(tr "Close") () ] ()
  in
  let view_error = match state.balance_mode with
    | `Accounting -> None
    | `Current -> (match balance_view_coords state with Error why -> Some why | Ok _ -> None) in
  match view_error with
  | Some why -> refused [
      tr "Print refused: visible-account configuration is unavailable.";
      why; tr "Review balance-view.tsv before printing." ]
  | None ->
      let header = match state.balance_mode with
        | `Current -> [ tr "Balances / Current";
            tr "Selected Locus × Measure; unknown is not zero."; "" ]
        | `Accounting -> [ tr "Balances / Accounting";
            tr "Current role-based quantities; different Measures are not combined."; "" ] in
      let summary = header @ balance_lines state in
      if not (balance_print_fits summary) then
        refused [ tr "Print refused: more than 200 lines or 32768 UTF-8 bytes.";
          tr "Narrow the balance selection first." ]
      else
        Form.create ~id:"balance_print_preview" ~title:(tr "Balances / Print Preview")
          ~summary ~fields:[ Form.action_buttons ~confirm:(tr "Done") ~cancel:(tr "Close") () ] ()

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
(* Balances detail shares the painted wrap width and Panel capacity so motion
   clamps to the actually visible last row, including after a resize. *)
let balance_viewport ~dimensions:((width, _) as dimensions) ~width_of state =
  let _, body_height = body_dimensions ~dimensions ~width_of state in
  let height = max 0 (body_height - 2) in
  let stacked = width >= 72 && width < 120 && height >= 18 in
  let right_width = if stacked then width else snd (browser_pane_widths width) in
  let detail_height = if stacked then height - height / 2 else height in
  let detail =
    match List.nth_opt (balance_items state) state.workspace.balance_selected with
    | None -> [ tr "No supplied Locus / Measure coordinates." ]
    | Some item -> O.balance_item_detail ~book:state.session.book item
  in
  let wrapped = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) detail in
  let view = Panel.window ~capacity:(Panel.capacity ~height:detail_height ~heading:false)
    ~count:(List.length wrapped) ~scroll:state.scroll ~selected:None in
  (detail_height, view)

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
      let pace_status =
        match current_pace_result state with
        | Ok _ -> "calculated"
        | Error why -> "unavailable: " ^ why
      in
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
        "  Current pace: " ^ pace_status;
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

let pace_samples state =
  let book = state.session.book and measure = state.workspace.measure in
  Result.bind (resolve_pace_pool state) (fun pool_coords ->
    let pool_loci = List.map (fun c -> A.lstr c.D.Effect_coordinate.locus) pool_coords in
    Result.bind (read_pace_config state "boundary-presets.tsv") (fun boundary_text ->
      let compute () =
        Trend.compute_samples ~book ~measure ~pool:pool_loci ~boundary_presets_text:boundary_text
          ~today:(F.today ()) ~preset:state.pace_trend.preset
      in
      match state.session.F.annual_year with
      | None -> compute ()
      | Some _ ->
          Result.bind (current_pace_result state) (fun _ ->
            Result.bind (compute ()) (fun ((first_day, through_day, _) as result) ->
              Result.bind (annual_history_bounds state) (function
                | Some (first, last) when first_day < first || through_day >= last ->
                    Error "Trend extends outside verified annual history."
                | _ -> Ok result)))))

let pace_sample_detail ~width_of ~width state samples =
  let selected = Panel.move ~last:(List.length samples - 1)
      ~position:state.pace_trend.selected_index 0 in
  Trend.render_detail ~width:(max 1 (width - 6)) ~width_of
    ~book:state.session.book ~measure:state.workspace.measure
    ~sample:(List.nth_opt samples selected)
    ~prev_sample:(if selected = 0 then None else List.nth_opt samples (selected - 1))
    ~today:(F.today ()) ~preset:state.pace_trend.preset
  |> List.map snd

let pace_detail_viewport ~dimensions ~width_of state =
  let width, body_height = body_dimensions ~dimensions ~width_of state in
  let height = max 0 (body_height - 2) in
  let rows = match pace_samples state with
    | Ok (_, _, samples) -> pace_sample_detail ~width_of ~width state samples
    | Error _ -> List.concat_map (O.wrap_text ~width_of (max 1 (width - 6)))
        (pace_detail_lines state) in
  Panel.window ~capacity:(Panel.capacity ~height ~heading:false)
    ~count:(List.length rows) ~scroll:state.scroll ~selected:None

let is_balance_print form =
  Form.id form = "balance_print_preview" || Form.id form = "balance_print_refused"

let balance_print_viewport ~dimensions ~width_of state form =
  let body_w, body_h = body_dimensions ~dimensions ~width_of state in
  let width = min 64 (max 8 (body_w - 4)) in
  let rows = List.concat_map (O.wrap_text ~width_of (max 1 (width - 6))) form.Form.summary in
  let height = min body_h (max 3 (List.length rows + 2)) in
  let view = Panel.window ~capacity:(Panel.capacity ~height ~heading:false)
      ~count:(List.length rows) ~scroll:state.balance_print_scroll ~selected:None in
  width, height, rows, view

let print_motion = function
  | `Key ((`Home | `End | `Page _ | `ASCII ('j' | 'k') | `Arrow (`Up | `Down)), [])
  | `Key (`ASCII ('u' | 'd'), [`Ctrl]) -> true
  | _ -> false

