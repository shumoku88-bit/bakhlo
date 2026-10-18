(** daily_pace_owner.ml - Vertical owner for Daily Pace screen. *)

module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module A = Daily_actions
module O = Daily_overlays
module Form = Ui_form
module Panel = Ui_panel
module Trend = Daily_pace_trend

type pane = [ `Calendar | `Detail ]

type command =
  | Stay
  | Back_to_home
  | Open_commands
  | Cycle_measure of [ `Next | `Prev ]
  | Save_pool of { expected : string option; content : string }
  | Save_cycle of { expected : string option; content : string }
  | Reload

type overlay =
  | No_overlay
  | What_if of Form.t
  | Configure_pool of { form : Form.t; draft : Form.t option }
  | Review_pool of { form : Form.t; editing_form : Form.t; new_loci : string list; raw_before : string option }
  | Configure_cycle of Form.t
  | Review_cycle of { form : Form.t; editing_form : Form.t; preset_name : string; preset_dates : string list; raw_before : string option }

type t = {
  trend : Trend.t;
  pane : pane;
  detail_scroll : int;
  overlay : overlay;
  pool_draft : (string * Form.t) option;
  notice : string;
}

let create () = {
  trend = Trend.initial ();
  pane = `Calendar;
  detail_scroll = 0;
  overlay = No_overlay;
  pool_draft = None;
  notice = "";
}

let pane t = t.pane
let preset t = t.trend.preset
let selected_index t = t.trend.selected_index
let notice t = t.notice
let graph_style t = t.trend.graph_style
let trend t = t.trend
let detail_scroll t = t.detail_scroll

let set_preset p t =
  { t with trend = { t.trend with preset = p } }

let set_selected_index idx t =
  { t with trend = { t.trend with selected_index = idx } }

let has_overlay t =
  match t.overlay with
  | No_overlay -> false
  | _ -> true

let active_form t =
  match t.overlay with
  | What_if f
  | Configure_pool { form = f; _ }
  | Review_pool { form = f; _ }
  | Configure_cycle f
  | Review_cycle { form = f; _ } -> Some f
  | No_overlay -> None
let set_pool_form updated t =
  match t.overlay with
  | Configure_pool cp -> { t with overlay = Configure_pool { cp with form = updated } }
  | Review_pool rp -> { t with overlay = Review_pool { rp with form = updated } }
  | _ -> t

let set_what_if_amount amount t =
  match t.overlay with
  | What_if form ->
      let updated = Form.set_focused (Form.set_text form "amount" amount) 1 in
      { t with overlay = What_if updated }
  | _ -> t


let config_lines text =
  String.split_on_char '\n' text
  |> List.filter (fun line ->
      let s = String.trim line in
      s <> "" && not (String.starts_with ~prefix:"#" s))

let resolve_pace_window ~today boundary_presets_tsv =
  let canonical_date day =
    match A.normalize_date day with Ok canonical -> canonical = day | Error _ -> false
  in
  let valid_window start stop =
    start < stop && canonical_date start && canonical_date stop
  in
  let parse_line line =
    match String.split_on_char '\t' line with
    | [ _name; start; stop ] ->
        let start = String.trim start and stop = String.trim stop in
        if valid_window start stop then Some (start, stop) else None
    | _ -> None
  in
  let rec parse exact_windows prefix_windows = function
    | [] -> (
        match exact_windows with
        | [ w ] -> Ok w
        | [] -> (
            match prefix_windows with
            | [ w ] -> Ok w
            | [] -> Error (Printf.sprintf "No boundary preset covers today (%s)." today)
            | _ -> Error (Printf.sprintf "Multiple boundary presets cover today (%s)." today))
        | _ -> Error (Printf.sprintf "Multiple boundary presets match today (%s)." today))
    | line :: rest ->
        let line = String.trim line in
        if line = "" || String.starts_with ~prefix:"#" line || String.starts_with ~prefix:";" line then
          parse exact_windows prefix_windows rest
        else
          match parse_line line with
          | Some ((start, stop) as w) ->
              let exact = start = today in
              let covered = start <= today && today < stop in
              parse
                (if exact then w :: exact_windows else exact_windows)
                (if covered then w :: prefix_windows else prefix_windows)
                rest
          | None -> Error "Invalid boundary presets file (boundary-presets.tsv)."
  in
  match boundary_presets_tsv with
  | Error why -> Error why
  | Ok None -> Error "Period not configured (boundary-presets.tsv missing)."
  | Ok (Some text) -> parse [] [] (config_lines text)

let resolve_pace_pool ~measure daily_pace_tsv =
  let config_token s =
    s <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) s
  in
  let rec coordinates acc = function
    | [] -> if acc = [] then Error "Daily Pace pool is empty." else Ok (List.rev acc)
    | raw :: rest ->
        let line = String.trim raw in
        if line = "" || String.starts_with ~prefix:"#" line || String.starts_with ~prefix:";" line then
          coordinates acc rest
        else
          match String.split_on_char '\t' line with
          | [ locus; m ] when config_token locus && m = measure && config_token m ->
              if List.mem locus acc then Error "Duplicate Daily Pace coordinate."
              else coordinates (locus :: acc) rest
          | _ -> Error "Malformed daily-pace.tsv or mismatched Measure; no rows were skipped."
  in
  match daily_pace_tsv with
  | Error why -> Error why
  | Ok None -> Error "Daily Pace pool not configured (daily-pace.tsv missing)."
  | Ok (Some text) -> coordinates [] (config_lines text)

let current_pace ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds:_ ~today =
  Result.bind (resolve_pace_pool ~measure daily_pace_tsv) (fun pool ->
    Result.bind (resolve_pace_window ~today boundary_presets_tsv) (fun (start_day, end_exclusive) ->
      let pool_coords =
        List.map
          (fun locus ->
            {
              D.Effect_coordinate.locus = A.get_id (D.Identifier.Locus.of_string locus);
              measure = A.get_id (D.Identifier.Measure.of_string measure);
            })
          pool
      in
      Result.map (fun p -> (p, start_day, end_exclusive))
        (Result.map_error Trend.format_pace_error
           (B.daily_pace book ~measure ~pool:pool_coords ~observed_at:today ~end_exclusive))))
let pace_detail_lines ~today ~measure boundary_presets_tsv daily_pace_tsv =
  match resolve_pace_window ~today boundary_presets_tsv with
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
      let pool_origin = match resolve_pace_pool ~measure daily_pace_tsv with
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
      ]

let pace_samples ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today t =
  Result.bind (resolve_pace_pool ~measure daily_pace_tsv) (fun pool_loci ->
    Result.bind
      (match boundary_presets_tsv with
       | Error why -> Error why
       | Ok opt -> Ok opt)
      (fun boundary_text ->
        let compute () =
          Trend.compute_samples ~book ~measure ~pool:pool_loci ~boundary_presets_text:boundary_text
            ~today ~preset:t.trend.preset
        in
        match annual_bounds with
        | None -> compute ()
        | Some (first, last) ->
            Result.bind (current_pace ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds:(Some (first, last)) ~today) (fun _ ->
              Result.bind (compute ()) (fun ((first_day, through_day, _) as result) ->
                if first_day < first || through_day >= last then
                  Error "Date range extends beyond verified prior-year history."
                else Ok result))))

let browser_pane_widths width =
  if width < 80 then (width, width)
  else
    let left = max 36 (min 58 (width * 52 / 100)) in
    (left, width - left - 1)
let detail_viewport ~dimensions ~width_of ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today t =
  let usable_h = max 0 (snd dimensions - 5) in
  let width = fst dimensions in
  let rows =
    match pace_samples ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today t with
    | Ok (_, _, samples) ->
        let sel = Panel.move ~last:(List.length samples - 1) ~position:t.trend.selected_index 0 in
        Trend.render_detail ~width:(max 1 (width - 6)) ~width_of
          ~book ~measure ~sample:(List.nth_opt samples sel)
          ~prev_sample:(if sel = 0 then None else List.nth_opt samples (sel - 1))
          ~today ~preset:t.trend.preset
        |> List.map snd
    | Error why ->
        List.concat_map (O.wrap_text ~width_of (max 1 (width - 6)))
          [ "Daily Pace Configuration Guide"; why ]
  in
  Panel.window ~capacity:(Panel.capacity ~height:usable_h ~heading:false)
    ~count:(List.length rows) ~scroll:t.detail_scroll ~selected:None


let header_summary ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today ~width ~width_of t =
  let _ = t in
  match current_pace ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today with
  | Error _ -> "Today: unavailable (not zero)"
  | Ok (pace, _, _) ->
      let text =
        "Today: " ^ O.format_money book pace.measure pace.daily_pace_quanta ^ " " ^ pace.measure ^ "/day"
      in
      if width_of text <= width then text else "Today: End, then i for full value"

let what_if_form ?amount ?result ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today () =
  let summary =
    match current_pace ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today with
    | Ok (pace, _start, _end_excl) ->
        let fmt q = O.format_money book pace.B.measure q ^ " " ^ pace.measure in
        [
          "Current pace: " ^ fmt pace.daily_pace_quanta ^ "/day";
          "Pool balance: " ^ fmt pace.eligible_pool;
          "Protected Scheduled: " ^ fmt pace.automatic_deductions;
          Printf.sprintf "Available: %s over %d remaining days." (fmt pace.available_through_end) pace.remaining_days;
          "Simulate an immediate purchase; no transaction or reservation is published.";
        ]
        @ (match result with
           | Some (Ok (new_pace, delta)) ->
               [
                 "";
                 "Simulation Result:";
                 Printf.sprintf "  Simulated pace: %s/day (%s/day)"
                   (fmt new_pace.B.daily_pace_quanta) (fmt delta);
                 Printf.sprintf "  Remaining available: %s"
                   (fmt new_pace.available_through_end);
               ]
           | Some (Error err) ->
               [ ""; "Simulation Error: " ^ err ]
           | None -> [])
    | Error why ->
        [ Printf.sprintf "Daily pace unavailable (%s); simulation is disabled." why ]
  in
  let notice =
    match result with
    | Some (Error err) -> err
    | Some (Ok (new_pace, delta)) ->
        let fmt q = O.format_money book new_pace.B.measure q ^ " " ^ new_pace.measure in
        let diff_str = (if Z.gt delta Z.zero then "+" else "") ^ fmt delta ^ "/day" in
        Printf.sprintf "Simulated pace: %s/day (%s). Remaining available: %s."
          (fmt new_pace.B.daily_pace_quanta) diff_str (fmt new_pace.available_through_end)
    | None -> ""
  in
  Form.create
    ~id:"daily_pace_what_if"
    ~title:"Daily Pace What-If (Purchase Scenario)"
    ~summary
    ~notice
    ~fields:[
      Form.text_field ~id:"amount" ~label:"Purchase amount" ?value:amount ();
      Form.action_buttons ~confirm:"Simulate" ~cancel:"Close" ();
    ] ()

let pool_rows_of_text ~measure text =
  let config_token s =
    s <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) s
  in
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

let configure_pace_form ~measure ~daily_pace_tsv ~boundary_presets_tsv ~today =
  let payload, read_notice =
    match daily_pace_tsv with
    | Ok None -> ("missing", "")
    | Ok (Some text) -> ("present\n" ^ text, "")
    | Error why -> ("unreadable", why)
  in
  let old_loci, old_why =
    match pool_old_of_payload ~measure payload with
    | Ok loci -> (loci, None)
    | Error why -> ([], Some why)
  in
  let current_loci = String.concat ", " old_loci in
  let notice = if read_notice <> "" then read_notice else Option.value ~default:"" old_why in
  let period =
    match resolve_pace_window ~today boundary_presets_tsv with
    | Ok (start, stop) -> Printf.sprintf "Explicit period: %s -> %s (exclusive)." start stop
    | Error why -> why
  in
  Form.create ~id:"configure_daily_pace"
    ~title:("Daily Pace Pool (" ^ measure ^ ")")
    ~summary:[
      "Configure pool loci for " ^ measure ^ "; other Measures are unaffected.";
      period;
      "Separate locus names with commas.";
    ]
    ~payload
    ~notice
    ~fields:[
      Form.text_field ~id:"pool_loci" ~label:"Pool accounts" ~value:current_loci ();
      Form.action_buttons ~confirm:"Review" ~cancel:"Cancel" ();
    ] ()

let pool_editor_form = configure_pace_form

let pool_review_form ~measure old_loci new_loci =
  Form.create ~id:"review_pool" ~title:"Review Pool accounts"
    ~summary:(
      [ "Measure: " ^ measure;
        "Only daily-pace.tsv changes.";
        "Old:" ]
      @ (if old_loci = [] then [ "  (none)" ] else List.map (fun l -> "  " ^ l) old_loci)
      @ [ "New:" ]
      @ (if new_loci = [] then [ "  (none)" ] else List.map (fun l -> "  " ^ l) new_loci))
    ~fields:[ Form.action_buttons ~confirm:"Save" ~cancel:"Edit" () ] ()

let decode_boundary_presets text =
  let canonical_date day =
    match A.normalize_date day with Ok canonical -> canonical = day | Error _ -> false
  in
  let rec parse acc = function
    | [] -> Ok (List.rev acc)
    | raw :: rest ->
        let line = String.trim raw in
        if line = "" || String.starts_with ~prefix:"#" line || String.starts_with ~prefix:";" line then
          parse acc rest
        else
          match String.split_on_char '\t' line with
          | [ name; start; stop ] when canonical_date start && canonical_date stop && start < stop ->
              parse ((name, [ start; stop ]) :: acc) rest
          | _ -> Error "Invalid boundary-presets.tsv."
  in
  parse [] (String.split_on_char '\n' text)

let current_window_for presets today =
  let exact =
    List.filter (fun (_, dates) -> match dates with [ start; _ ] -> start = today | _ -> false) presets
  in
  match exact with
  | [ (name, dates) ] -> (name, dates)
  | _ -> (
      let covered =
        List.filter
          (fun (_, dates) ->
            match dates with [ start; stop ] -> start <= today && today < stop | _ -> false)
          presets
      in
      match covered with
      | [ (name, dates) ] -> (name, dates)
      | _ -> ("", [ today; today ]))

let cycle_boundaries_form ~boundary_presets_tsv ~today =
  let raw =
    match boundary_presets_tsv with
    | Ok None -> ("missing", "")
    | Ok (Some text) -> ("present\n" ^ text, "")
    | Error why -> ("unreadable", why)
  in
  let payload = fst raw in
  let presets_res =
    match boundary_presets_tsv with
    | Ok (Some text) -> decode_boundary_presets text
    | Ok None -> Ok []
    | Error why -> Error why
  in
  match presets_res with
  | Error why -> Error why
  | Ok presets ->
      let name, dates = current_window_for presets today in
      let start_str, stop_str =
        match dates with [ s; e ] -> (s, e) | _ -> (today, today)
      in
      Ok
        (Form.create ~id:"configure_cycle_boundaries" ~title:"Cycle boundaries (boundary-presets.tsv)"
           ~summary:[
             "Set current cycle start and stop (exclusive) dates.";
             "Applies to Cycle and Previous Cycle presets across all Measures.";
           ]
           ~payload
           ~fields:[
             Form.text_field ~id:"preset_name" ~label:"Preset name" ~value:(if name = "" then "cycle" else name) ();
             Form.text_field ~id:"start_date" ~label:"Start date" ~value:start_str ();
             Form.text_field ~id:"stop_date" ~label:"Stop date (exclusive)" ~value:stop_str ();
             Form.action_buttons ~confirm:"Review" ~cancel:"Cancel" ();
           ] ())

let cycle_boundaries_review preset_name preset_dates =
  Form.create ~id:"review_cycle_boundaries" ~title:"Review cycle boundaries"
    ~summary:[
      "Preset name: " ^ preset_name;
      Printf.sprintf "Period: %s -> %s (exclusive)"
        (List.nth preset_dates 0) (List.nth preset_dates 1);
      "Edits only boundary-presets.tsv; daily-pace.tsv stays untouched.";
    ]
    ~fields:[ Form.action_buttons ~confirm:"Save" ~cancel:"Edit" () ] ()

let open_pool_editor ~book:_ ~measure ~daily_pace_tsv ~boundary_presets_tsv ~today t =
  match t.pool_draft with
  | Some (draft_measure, draft) when draft_measure = measure ->
      { t with overlay = Configure_pool { form = draft; draft = Some draft }; notice = "" }
  | _ ->
      let form = configure_pace_form ~measure ~daily_pace_tsv ~boundary_presets_tsv ~today in
      { t with overlay = Configure_pool { form; draft = None }; notice = "" }

let open_cycle_editor ~boundary_presets_tsv ~today t =
  match cycle_boundaries_form ~boundary_presets_tsv ~today with
  | Ok form -> { t with overlay = Configure_cycle form; notice = "" }
  | Error why -> { t with overlay = No_overlay; notice = "Cycle setup unavailable: " ^ why }

let open_what_if ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today t =
  let form = what_if_form ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today () in
  { t with overlay = What_if form; notice = "" }

let notify_pool_saved t =
  { t with overlay = No_overlay; pool_draft = None; notice = "Daily Pace pool saved." }

let notify_pool_save_failed t why =
  match t.overlay with
  | Review_pool rp ->
      let updated = Form.set_notice rp.form ("Pool save not confirmed: " ^ why ^ " Reopen to inspect.") in
      { t with overlay = Review_pool { rp with form = updated } }
  | _ -> { t with notice = "Pool save failed: " ^ why }
let notify_cycle_saved t =
  { t with overlay = No_overlay; notice = "Explicit Daily Pace cycle boundaries saved." }

let notify_cycle_save_failed t why =
  match t.overlay with
  | Review_cycle rc ->
      let updated = Form.set_notice rc.form ("Cycle boundary save not confirmed: " ^ why ^ " Reopen to inspect.") in
      { t with overlay = Review_cycle { rc with form = updated } }
  | _ -> { t with notice = "Cycle save failed: " ^ why }

let overlay ~dimensions:((width, _) as _dimensions) ~body_dimensions:((body_w, body_h) as _body_dim) ~width_of t : Ui_overlay.frame option =
  let framed_form form =
    let pane_w = min 64 (max 8 (body_w - 4)) in
    let content_width = max 0 (pane_w - 6) in
    let form_rows =
      Form.render_rows ~width:content_width
        ~height:(Panel.capacity ~height:body_h ~heading:false)
        ~width_of form
    in
    let pane_h = min body_h (max 5 (List.length form_rows + 2)) in
    let rows =
      Panel.frame_rows ~width_of ~width:pane_w ~height:pane_h ~focused:true
        ~title:(Form.title form) form_rows
    in
    let origin_x = max 0 ((width - pane_w) / 2) in
    let origin_y = max 0 ((body_h - pane_h) / 2) in
    let cursor =
      O.cursor_in_rows ~width_of ~width:pane_w rows
      |> Option.map (fun (col, row) -> (origin_x + col, origin_y + row))
    in
    Some { Ui_overlay.origin_x; origin_y; pane_width = pane_w; pane_height = List.length rows; rows; cursor }
  in
  match t.overlay with
  | No_overlay -> None
  | What_if f
  | Configure_pool { form = f; _ }
  | Review_pool { form = f; _ }
  | Configure_cycle f
  | Review_cycle { form = f; _ } -> framed_form f

let cursor_position ~dimensions ~body_dimensions ~width_of t =
  match overlay ~dimensions ~body_dimensions ~width_of t with
  | Some frame -> frame.cursor
  | None -> None

let handle ~blocked ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today ~dimensions ~width_of t (input : Ui_input.input) =
  match t.overlay with
  | What_if form -> (
      match input with
      | `Key ((`Escape | `ASCII ('q' | 'Q')), []) ->
          ({ t with overlay = No_overlay }, Stay)
      | `Key (`Tab, mods) when mods = [] || mods = [ `Shift ] ->
          let current = Form.focused form in
          let count = List.length form.fields in
          let next = if mods = [] then (current + 1) mod count else (current + count - 1) mod count in
          let updated = Form.set_focused form next in
          ({ t with overlay = What_if updated }, Stay)
      | _ -> (
          match Form.handle_input form input with
          | Form.Cancel ->
              ({ t with overlay = No_overlay }, Stay)
          | Form.Updated next_form ->
              ({ t with overlay = What_if next_form }, Stay)
          | Form.Submit submitted -> (
              let amount_str = Option.value ~default:"" (Form.get_text submitted "amount") in
              if String.trim amount_str = "" then
                let updated = Form.set_notice submitted "Enter a purchase amount to simulate." in
                ({ t with overlay = What_if updated }, Stay)
              else
                let sim_result =
                  match B.parse_signed_amount book measure amount_str with
                  | Error _ -> Error "Invalid amount."
                  | Ok quantity ->
                      if Z.sign quantity <= 0 then
                        Error "Amount must be positive."
                      else
                        match current_pace ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today with
                        | Error why -> Error ("Current pace unavailable: " ^ why)
                        | Ok (pace, _, _) ->
                            let remaining_days = pace.remaining_days in
                            let cur_pace = pace.daily_pace_quanta in
                            let new_avail = Z.sub pace.available_through_end quantity in
                            let new_pace = Z.ediv new_avail (Z.of_int remaining_days) in
                            let diff = Z.sub new_pace cur_pace in
                            let simulated = { pace with daily_pace_quanta = new_pace; available_through_end = new_avail } in
                            Ok (simulated, diff)
                in
                let next_form = what_if_form ~amount:amount_str ~result:sim_result ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today () in
                ({ t with overlay = What_if next_form }, Stay))))
  | Configure_pool { form; draft } -> (
      match input with
      | `Key ((`Escape | `ASCII ('q' | 'Q')), []) ->
          ({ t with overlay = No_overlay }, Stay)
      | `Key (`Tab, mods) when mods = [] || mods = [ `Shift ] ->
          let current = Form.focused form in
          let count = List.length form.fields in
          let next = if mods = [] then (current + 1) mod count else (current + count - 1) mod count in
          let updated = Form.set_focused form next in
          ({ t with overlay = Configure_pool { form = updated; draft = Some updated } }, Stay)
      | _ -> (
          match Form.handle_input form input with
          | Form.Cancel ->
              ({ t with overlay = No_overlay }, Stay)
          | Form.Updated updated ->
              ({ t with overlay = Configure_pool { form = updated; draft = Some updated }; pool_draft = Some (measure, updated) }, Stay)
          | Form.Submit submitted -> (
              let t = { t with pool_draft = Some (measure, submitted) } in
              let raw_text = Option.value ~default:"" (Form.get_text submitted "pool_loci") in
              let parse_loci text =
                let tokens =
                  String.split_on_char ',' (String.trim text)
                  |> List.map String.trim
                in
                let rec unique acc = function
                  | [] -> if acc = [] then Error "Choose at least one admitted Locus." else Ok (List.rev acc)
                  | x :: rest ->
                      if x = "" || not (String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) x)
                      then Error "Choose distinct admitted Locus tokens, separated by commas."
                      else if List.mem x acc then Error "Duplicate pool locus."
                      else match D.Identifier.Locus.of_string x with
                      | Ok _ ->
                          (match B.approved_loci book with
                           | Some ids when List.mem x ids -> unique (x :: acc) rest
                           | _ -> Error "Choose admitted Locus tokens only.")
                      | Error _ -> Error "Invalid locus name."
                in
                unique [] tokens
              in
              match parse_loci raw_text with
              | Error err ->
                  let updated = Form.set_notice submitted err in
                  ({ t with overlay = Configure_pool { form = updated; draft } }, Stay)
              | Ok new_loci -> (
                  match pool_old_of_payload ~measure (Form.payload submitted) with
                  | Error why ->
                      let updated = Form.set_notice submitted why in
                      ({ t with overlay = Configure_pool { form = updated; draft = Some updated }; pool_draft = Some (measure, submitted) }, Stay)
                  | Ok old_loci ->
                      let payload = Form.payload submitted in
                      let raw_before =
                        if payload = "missing" then None
                        else Some (String.sub payload 8 (String.length payload - 8))
                      in
                      let rform = pool_review_form ~measure old_loci new_loci in
                      ({ t with overlay = Review_pool { form = rform; editing_form = submitted; new_loci; raw_before } }, Stay)))))
  | Review_pool { form; editing_form; new_loci; raw_before } -> (
      match input with
      | `Key (`ASCII ('e' | 'E'), []) ->
          ({ t with overlay = Configure_pool { form = editing_form; draft = Some editing_form } }, Stay)
      | `Key (`Tab, mods) when mods = [] || mods = [ `Shift ] ->
          let direction = if mods = [] then `Right else `Left in
          (match Form.handle_input form (`Key (`Arrow direction, [])) with
          | Form.Updated updated ->
              ({ t with overlay = Review_pool { form = updated; editing_form; new_loci; raw_before } }, Stay)
          | _ -> (t, Stay))
      | _ -> (
          match Form.handle_input form input with
          | Form.Cancel ->
              ({ t with overlay = Configure_pool { form = editing_form; draft = Some editing_form } }, Stay)
          | Form.Updated updated ->
              ({ t with overlay = Review_pool { form = updated; editing_form; new_loci; raw_before } }, Stay)
          | Form.Submit submitted ->
              if blocked then
                let updated = Form.set_notice submitted "Writes stopped. Cancel and reload to inspect." in
                ({ t with overlay = Review_pool { form = updated; editing_form; new_loci; raw_before } }, Stay)
              else
                let pane_w = min 64 (max 8 (fst dimensions - 4)) in
                let body_h = max 0 (snd dimensions - 3) in
                let rows = Form.render_rows ~width:(max 0 (pane_w - 6)) ~height:max_int ~width_of submitted in
                let fits = pane_w >= 48 && List.length rows <= Panel.capacity ~height:body_h ~heading:false in
                if not fits then
                  let updated = Form.set_notice submitted "Enlarge the terminal to review pool before saving." in
                  ({ t with overlay = Review_pool { form = updated; editing_form; new_loci; raw_before } }, Stay)
                else
                  let other_lines =
                    match daily_pace_tsv with
                    | Ok (Some text) ->
                        String.split_on_char '\n' text
                        |> List.filter (fun line ->
                            let trimmed = String.trim line in
                            trimmed <> "" && not (String.starts_with ~prefix:"#" trimmed)
                            && match String.split_on_char '\t' trimmed with
                            | [ _; m ] -> m <> measure
                            | _ -> false)
                    | _ -> []
                  in
                  let new_lines = List.map (fun l -> l ^ "\t" ^ measure) new_loci in
                  let content = String.concat "\n" (other_lines @ new_lines) ^ "\n" in
                  (t, Save_pool { expected = raw_before; content })))
  | Configure_cycle form -> (
      match input with
      | `Key ((`Escape | `ASCII ('q' | 'Q')), []) ->
          ({ t with overlay = No_overlay }, Stay)
      | `Key (`Tab, mods) when mods = [] || mods = [ `Shift ] ->
          let current = Form.focused form in
          let count = List.length form.fields in
          let next = if mods = [] then (current + 1) mod count else (current + count - 1) mod count in
          let updated = Form.set_focused form next in
          ({ t with overlay = Configure_cycle updated }, Stay)
      | _ -> (
          match Form.handle_input form input with
          | Form.Cancel ->
              ({ t with overlay = No_overlay }, Stay)
          | Form.Updated updated ->
              ({ t with overlay = Configure_cycle updated }, Stay)
          | Form.Submit submitted -> (
              let name = String.trim (Option.value ~default:"" (Form.get_text submitted "preset_name")) in
              let start = String.trim (Option.value ~default:"" (Form.get_text submitted "start_date")) in
              let stop = String.trim (Option.value ~default:"" (Form.get_text submitted "stop_date")) in
              let canonical day =
                match A.normalize_date day with Ok c -> c = day | Error _ -> false
              in
              if name = "" then
                let updated = Form.set_notice submitted "Preset name cannot be empty." in
                ({ t with overlay = Configure_cycle updated }, Stay)
              else if not (canonical start && canonical stop) then
                let updated = Form.set_notice submitted "Invalid date format (use YYYY-MM-DD)." in
                ({ t with overlay = Configure_cycle updated }, Stay)
              else if not (start < stop) then
                let updated = Form.set_notice submitted "Start date must be before stop date." in
                ({ t with overlay = Configure_cycle updated }, Stay)
              else
                let raw_before = match boundary_presets_tsv with Ok opt -> opt | Error _ -> None in
                let rform = cycle_boundaries_review name [ start; stop ] in
                ({ t with overlay = Review_cycle { form = rform; editing_form = submitted; preset_name = name; preset_dates = [ start; stop ]; raw_before } }, Stay))))
  | Review_cycle { form; editing_form; preset_name; preset_dates; raw_before } -> (
      match input with
      | `Key (`ASCII ('e' | 'E'), []) ->
          ({ t with overlay = Configure_cycle editing_form }, Stay)
      | `Key (`Tab, mods) when mods = [] || mods = [ `Shift ] ->
          let direction = if mods = [] then `Right else `Left in
          (match Form.handle_input form (`Key (`Arrow direction, [])) with
          | Form.Updated updated ->
              ({ t with overlay = Review_cycle { form = updated; editing_form; preset_name; preset_dates; raw_before } }, Stay)
          | _ -> (t, Stay))
      | _ -> (
          match Form.handle_input form input with
          | Form.Cancel ->
              ({ t with overlay = Configure_cycle editing_form }, Stay)
          | Form.Updated updated ->
              ({ t with overlay = Review_cycle { form = updated; editing_form; preset_name; preset_dates; raw_before } }, Stay)
          | Form.Submit submitted ->
              if blocked then
                let updated = Form.set_notice submitted "Writes stopped. Cancel and reload to inspect." in
                ({ t with overlay = Review_cycle { form = updated; editing_form; preset_name; preset_dates; raw_before } }, Stay)
              else
                let pane_w = min 64 (max 8 (fst dimensions - 4)) in
                let body_h = max 0 (snd dimensions - 3) in
                let rows = Form.render_rows ~width:(max 0 (pane_w - 6)) ~height:max_int ~width_of submitted in
                let fits = pane_w >= 48 && List.length rows <= Panel.capacity ~height:body_h ~heading:false in
                if not fits then
                  let updated = Form.set_notice submitted "Enlarge the terminal to review cycle before saving." in
                  ({ t with overlay = Review_cycle { form = updated; editing_form; preset_name; preset_dates; raw_before } }, Stay)
                else
                  let other_presets =
                    match boundary_presets_tsv with
                    | Ok (Some text) ->
                        decode_boundary_presets text
                        |> (function Ok ps -> List.filter (fun (n, _) -> n <> preset_name) ps | Error _ -> [])
                    | _ -> []
                  in
                  let all_presets = other_presets @ [ (preset_name, preset_dates) ] in
                  let content =
                    String.concat "\n"
                      (List.map (fun (n, dates) -> Printf.sprintf "%s\t%s\t%s" n (List.nth dates 0) (List.nth dates 1)) all_presets)
                    ^ "\n"
                  in
                  (t, Save_cycle { expected = raw_before; content })))
  | No_overlay -> (
      match input with
      | `Key ((`Escape | `ASCII ('q' | 'Q')), []) ->
          if t.pane = `Detail then
            ({ t with pane = `Calendar; detail_scroll = 0 }, Stay)
          else (t, Back_to_home)
      | `Key ((`Enter | `ASCII 'i'), []) when t.pane = `Calendar ->
          ({ t with pane = `Detail; detail_scroll = 0 }, Stay)
      | `Key (`ASCII ' ', []) ->
          (t, Open_commands)
      | `Key (`Tab, []) ->
          (t, Cycle_measure `Next)
      | `Key (`Tab, [ `Shift ]) ->
          (t, Cycle_measure `Prev)
      | `Key (`ASCII ('1' .. '5' as c), []) -> (
          let preset =
            match c with
            | '1' -> Trend.Ten_days
            | '2' -> Trend.Thirty_days
            | '3' -> Trend.Month
            | '4' -> Trend.Cycle
            | _ -> Trend.Previous_cycle
          in
          let raw_text = match boundary_presets_tsv with Ok opt -> opt | Error _ -> None in
          match Trend.change_preset ~today ~boundary_presets_text:raw_text t.trend preset with
          | Ok next_trend ->
              ({ t with trend = next_trend; detail_scroll = 0; notice = "" }, Stay)
          | Error why ->
              ({ t with notice = "Daily Pace range unavailable: " ^ why }, Stay))
      | `Key (`ASCII 'v', []) ->
          let next_style = Trend.next_graph_style t.trend.graph_style in
          ({ t with trend = { t.trend with graph_style = next_style } }, Stay)
      | `Key (`ASCII 'w', []) ->
          (open_what_if ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today t, Stay)
      | `Key (`ASCII 'c', []) ->
          (open_pool_editor ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~today t, Stay)
      | `Key (`ASCII 'b', []) ->
          (open_cycle_editor ~boundary_presets_tsv ~today t, Stay)
      | `Key ((`Arrow `Left | `ASCII 'h'), []) -> (
          let raw_text = match boundary_presets_tsv with Ok opt -> opt | Error _ -> None in
          match Trend.move_selection ~today ~preset:t.trend.preset ~boundary_presets_text:raw_text ~position:t.trend.selected_index (-1) with
          | Ok idx -> ({ t with trend = { t.trend with selected_index = idx }; detail_scroll = 0; notice = "" }, Stay)
          | Error why -> ({ t with notice = "Daily Pace range unavailable: " ^ why }, Stay))
      | `Key ((`Arrow `Right | `ASCII 'l'), []) -> (
          let raw_text = match boundary_presets_tsv with Ok opt -> opt | Error _ -> None in
          match Trend.move_selection ~today ~preset:t.trend.preset ~boundary_presets_text:raw_text ~position:t.trend.selected_index 1 with
          | Ok idx -> ({ t with trend = { t.trend with selected_index = idx }; detail_scroll = 0; notice = "" }, Stay)
          | Error why -> ({ t with notice = "Daily Pace range unavailable: " ^ why }, Stay))
      | `Key (`Home, []) -> (
          if t.pane = `Detail then ({ t with detail_scroll = 0 }, Stay)
          else
            let raw_text = match boundary_presets_tsv with Ok opt -> opt | Error _ -> None in
            match Trend.move_selection ~today ~preset:t.trend.preset ~boundary_presets_text:raw_text ~position:t.trend.selected_index (-max_int) with
            | Ok idx -> ({ t with trend = { t.trend with selected_index = idx }; detail_scroll = 0; notice = "" }, Stay)
            | Error why -> ({ t with notice = "Daily Pace range unavailable: " ^ why }, Stay))
      | `Key (`End, []) -> (
          if t.pane = `Detail then
            let view = detail_viewport ~dimensions ~width_of ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today t in
            ({ t with detail_scroll = view.last }, Stay)
          else
            let raw_text = match boundary_presets_tsv with Ok opt -> opt | Error _ -> None in
            match Trend.move_selection ~today ~preset:t.trend.preset ~boundary_presets_text:raw_text ~position:t.trend.selected_index max_int with
            | Ok idx -> ({ t with trend = { t.trend with selected_index = idx }; detail_scroll = 0; notice = "" }, Stay)
            | Error why -> ({ t with notice = "Daily Pace range unavailable: " ^ why }, Stay))
      | `Key ((`Arrow `Up | `ASCII 'k'), []) ->
          if t.pane = `Detail then
            let view = detail_viewport ~dimensions ~width_of ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today t in
            let next_scroll = Panel.move ~last:view.last ~position:view.start (-1) in
            ({ t with detail_scroll = next_scroll }, Stay)
          else (t, Stay)
      | `Key ((`Arrow `Down | `ASCII 'j'), []) ->
          if t.pane = `Detail then
            let view = detail_viewport ~dimensions ~width_of ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today t in
            let next_scroll = Panel.move ~last:view.last ~position:view.start 1 in
            ({ t with detail_scroll = next_scroll }, Stay)
          else (t, Stay)
      | `Key ((`Page `Up | `ASCII 'u'), _) ->
          if t.pane = `Detail then
            let view = detail_viewport ~dimensions ~width_of ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today t in
            let next_scroll = Panel.move ~last:view.last ~position:view.start (-view.capacity) in
            ({ t with detail_scroll = next_scroll }, Stay)
          else
            let page =
              let width = fst dimensions in
              let usable_h = max 0 (snd dimensions - 5) in
              let wide = width >= 80 && usable_h >= 15 in
              let history_width = if wide then width - min 60 (max 30 (width * 40 / 100)) - 1 else width in
              let capacity =
                if usable_h >= 15 then max 7 (usable_h / 2) - 2
                else if usable_h >= 9 then 1 else 0
              in
              match pace_samples ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today t with
              | Error _ -> 1
              | Ok (_, _, samples) ->
                  Trend.render_history ~width:(max 0 (history_width - 6)) ~height:capacity
                    ~width_of ~book ~measure ~samples
                    ~selected_index:t.trend.selected_index
                  |> List.fold_left (fun count (style, _) ->
                       if style = O.Chrome then count else count + 1) 0
                  |> max 1
            in
            let raw_text = match boundary_presets_tsv with Ok opt -> opt | Error _ -> None in
            (match Trend.move_selection ~today ~preset:t.trend.preset ~boundary_presets_text:raw_text ~position:t.trend.selected_index (-page) with
            | Ok idx -> ({ t with trend = { t.trend with selected_index = idx }; detail_scroll = 0; notice = "" }, Stay)
            | Error why -> ({ t with notice = "Daily Pace range unavailable: " ^ why }, Stay))
      | `Key ((`Page `Down | `ASCII 'd'), _) ->
          if t.pane = `Detail then
            let view = detail_viewport ~dimensions ~width_of ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today t in
            let next_scroll = Panel.move ~last:view.last ~position:view.start view.capacity in
            ({ t with detail_scroll = next_scroll }, Stay)
          else
            let page =
              let width = fst dimensions in
              let usable_h = max 0 (snd dimensions - 5) in
              let wide = width >= 80 && usable_h >= 15 in
              let history_width = if wide then width - min 60 (max 30 (width * 40 / 100)) - 1 else width in
              let capacity =
                if usable_h >= 15 then max 7 (usable_h / 2) - 2
                else if usable_h >= 9 then 1 else 0
              in
              match pace_samples ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today t with
              | Error _ -> 1
              | Ok (_, _, samples) ->
                  Trend.render_history ~width:(max 0 (history_width - 6)) ~height:capacity
                    ~width_of ~book ~measure ~samples
                    ~selected_index:t.trend.selected_index
                  |> List.fold_left (fun count (style, _) ->
                       if style = O.Chrome then count else count + 1) 0
                  |> max 1
            in
            let raw_text = match boundary_presets_tsv with Ok opt -> opt | Error _ -> None in
            (match Trend.move_selection ~today ~preset:t.trend.preset ~boundary_presets_text:raw_text ~position:t.trend.selected_index page with
            | Ok idx -> ({ t with trend = { t.trend with selected_index = idx }; detail_scroll = 0; notice = "" }, Stay)
            | Error why -> ({ t with notice = "Daily Pace range unavailable: " ^ why }, Stay))
      | _ -> (t, Stay))

let screen ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today ~dimensions:(width, height) ~width_of t =
  let trend_res = pace_samples ~book ~measure ~daily_pace_tsv ~boundary_presets_tsv ~annual_bounds ~today t in
  let is_detail = t.pane = `Detail in
  let left_width, right_width = browser_pane_widths width in
  let pad rows = rows @ List.init (max 0 (height - List.length rows)) (fun _ -> (O.Plain, "")) in
  match trend_res with
  | Ok (_, _, samples) ->
      let count = List.length samples in
      let selected_idx = Panel.move ~last:(count - 1) ~position:t.trend.selected_index 0 in
      let title =
        Printf.sprintf "Daily Pace / Trend • %s [%s]"
          (Trend.preset_label t.trend.preset)
          (Trend.graph_style_label t.trend.graph_style)
      in
      let wide = width >= 80 && height >= 15 in
      let lower_height =
        if height >= 15 then max 7 (height / 2)
        else if height >= 9 then 3 else 0
      in
      let detail_width =
        if is_detail then width
        else if wide then min 60 (max 30 (width * 40 / 100))
        else width
      in
      let detail_height = if wide then lower_height else 0 in
      let history_width = if wide then width - detail_width - 1 else width in
      let history_height = lower_height in
      let detail_panel ~height =
        let sample = List.nth_opt samples selected_idx in
        let prev_sample = if selected_idx = 0 then None else List.nth_opt samples (selected_idx - 1) in
        let detail_rows =
          Trend.render_detail ~width:(max 1 (detail_width - 6)) ~width_of ~book ~measure
            ~sample ~prev_sample ~today ~preset:t.trend.preset
          |> List.map snd
        in
        Panel.frame ~width_of ~width:detail_width ~height ~focused:is_detail
          ~title:"Selected day" ~scroll:t.detail_scroll ~selected:None detail_rows
      in
      if is_detail then detail_panel ~height
      else
        let chart_height = height - lower_height in
        let chart =
          Trend.render_chart ~width:(max 0 (width - 6))
            ~height:(Panel.capacity ~height:chart_height ~heading:false)
            ~width_of ~book ~today ~measure ~samples
            ~selected_index:selected_idx ~graph_style:t.trend.graph_style
          |> Panel.frame_rows ~width_of ~width ~height:chart_height
               ~focused:(not is_detail) ~title
        in
        let history =
          Trend.render_history ~width:(max 0 (history_width - 6))
            ~height:(Panel.capacity ~height:history_height ~heading:false)
            ~width_of ~book ~measure ~samples ~selected_index:selected_idx
          |> Panel.frame_rows ~width_of ~width:history_width ~height:history_height
               ~focused:(not is_detail) ~title:"History"
        in
        let lower =
          if wide then
            List.map2
              (fun (left_style, left_text) (right_style, right_text) ->
                (O.Columns (history_width, left_style, right_style), left_text ^ " " ^ right_text))
              history (detail_panel ~height:detail_height)
          else history @ (if detail_height = 0 then [] else detail_panel ~height:detail_height)
        in
        chart @ lower
  | Error why ->
      if is_detail then
        let right_rows = pace_detail_lines ~today ~measure boundary_presets_tsv daily_pace_tsv in
        let wrapped_detail = List.concat_map (O.wrap_text ~width_of (max 1 (width - 6))) right_rows in
        Panel.frame ~width_of ~width ~height ~focused:true ~title:"Pace Detail & Evidence"
          ~scroll:t.detail_scroll ~selected:None wrapped_detail
      else if width >= 80 then
        let left_title = Printf.sprintf "Daily Pace / %s" (Trend.preset_label t.trend.preset) in
        let right_title = "Pace Detail & Evidence" in
        let left_rows =
          List.concat_map (O.wrap_text ~width_of (max 1 (left_width - 6)))
            [
              Ui_text.tr "Daily Pace unavailable:";
              why;
              "Supply an explicit daily-pace.tsv pool and boundary-presets.tsv period.";
            ]
        in
        let right_rows = pace_detail_lines ~today ~measure boundary_presets_tsv daily_pace_tsv in
        let wrapped_detail = List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) right_rows in
        let left_panel =
          Panel.frame ~width_of ~width:left_width ~height ~focused:true ~title:left_title
            ~scroll:0 ~selected:None left_rows
        in
        let right_panel =
          Panel.frame ~width_of ~width:right_width ~height ~focused:false ~title:right_title
            ~scroll:t.detail_scroll ~selected:None wrapped_detail
        in
        pad
          (List.map2
             (fun (style_l, text_l) (style_r, text_r) ->
               (O.Columns (left_width, style_l, style_r), text_l ^ " " ^ text_r))
             left_panel right_panel)
      else
        let err_rows =
          [
            Ui_text.tr "Daily Pace unavailable:";
            why;
            "Supply an explicit daily-pace.tsv pool and boundary-presets.tsv period.";
          ]
        in
        let wrapped = List.concat_map (O.wrap_text ~width_of (max 1 (width - 6))) err_rows in
        Panel.frame ~width_of ~width ~height ~focused:true
          ~title:("Daily Pace / " ^ Trend.preset_label t.trend.preset)
          ~scroll:0 ~selected:None wrapped
let footer ~dimensions:_ ~width_of:_ t =
  match t.overlay with
  | What_if _ ->
      [ "Enter simulate scenario  Tab switch field/button  Esc close"; "Read-only simulation - does not publish any entries" ]
  | Configure_pool _ ->
      [ "Enter review  Tab switch field  Esc cancel"; "Edits only daily-pace.tsv" ]
  | Review_pool _ ->
      [ "Enter save  Tab choose Edit  Esc edit"; "Full pool must fit before saving" ]
  | Configure_cycle _ ->
      [ "Enter review  Tab switch field  Esc cancel"; "Edits only boundary-presets.tsv" ]
  | Review_cycle _ ->
      [ "Enter save  Tab choose Edit  Esc edit"; "Full boundaries must fit before saving" ]
  | No_overlay ->
      match t.pane with
      | `Calendar ->
          [ "1-5 period  h/l day  v style  Tab/i detail  w what-if";
            "PgUp/Dn Home/End  c pool  b cycle  Space Commands  q back" ]
      | `Detail ->
          [ "j/k PgUp/Dn Home/End scroll  h/l day  Tab/i timeline";
            "w what-if  c pool  b cycle  q/Esc timeline" ]
