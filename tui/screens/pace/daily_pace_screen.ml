(* Daily Pace: today's spending guide, its retrospective trend and the explicit
   pool / cycle-boundary editors. Configuration bytes are captured in each
   form's payload; saving goes through the Shell with those captured bytes. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module A = Daily_draft
module O = Daily_overlays
module Cal = Daily_calendar
module Form = Ui_form
module Panel = Ui_panel
module Trend = Daily_pace_trend

let tr = Ui_text.tr
let pool_file = "daily-pace.tsv"
let boundary_file = "boundary-presets.tsv"
let config_files = [ pool_file; boundary_file ]

type pane = Trend_pane | Detail_pane

(* A review keeps the editing form whose payload holds the captured bytes. *)
type pool_review = { form : Form.t; editing : Form.t; measure : string; loci : string list }
type cycle_review = { form : Form.t; editing : Form.t; name : string; dates : string list }

type overlay =
  | No_overlay
  | What_if of Form.t
  | Pool of Form.t
  | Pool_review of pool_review
  | Cycle of Form.t
  | Cycle_review of cycle_review

type t = {
  trend : Trend.t;
  pane : pane;
  scroll : int;
  overlay : overlay;
  pool_draft : (string * Form.t) option;
}

let create () =
  { trend = Trend.initial (); pane = Trend_pane; scroll = 0; overlay = No_overlay; pool_draft = None }

let enter t = { t with pane = Trend_pane; scroll = 0; overlay = No_overlay }

let form t =
  match t.overlay with
  | No_overlay -> None
  | What_if form | Pool form | Cycle form
  | Pool_review { form; _ } -> Some form
  | Cycle_review { form; _ } -> Some form

let modal t = Option.is_some (form t)

let with_form form t =
  let overlay =
    match t.overlay with
    | No_overlay -> No_overlay
    | What_if _ -> What_if form
    | Pool _ -> Pool form
    | Cycle _ -> Cycle form
    | Pool_review (r : pool_review) -> Pool_review { r with form }
    | Cycle_review (r : cycle_review) -> Cycle_review { r with form }
  in
  { t with overlay }

let trend t = t.trend
let detail_focused t = t.pane = Detail_pane
let detail_scroll t = t.scroll

(* Configuration text *)

let config_lines text =
  String.split_on_char '\n' text |> List.filter (fun line ->
    let s = String.trim line in s <> "" && not (String.starts_with ~prefix:"#" s))

let config_token s =
  s <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) s

let payload_of = function
  | Ok None -> ("missing", "")
  | Ok (Some text) -> ("present\n" ^ text, "")
  | Error why -> ("unreadable", why)

let captured_text payload =
  String.sub payload 8 (String.length payload - 8)

let resolve_window (env : Screen.env) =
  let today = env.today in
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
  Result.bind (env.config boundary_file) (function
    | None -> Error "Period not configured (boundary-presets.tsv missing)."
    | Some text -> parse [] [] (config_lines text))

let resolve_pool (env : Screen.env) =
  let measure = env.measure in
  let rec coordinates acc = function
    | [] -> if acc = [] then Error "Daily Pace pool is empty." else Ok (List.rev acc)
    | line :: rest ->
        match String.split_on_char '\t' line with
        | [locus; m] when config_token locus && m = measure && config_token m ->
            let coordinate = {
              D.Effect_coordinate.locus = A.get_id (D.Identifier.Locus.of_string locus);
              measure = A.get_id (D.Identifier.Measure.of_string m);
            } in
            if List.mem coordinate acc then Error "Duplicate Daily Pace coordinate."
            else coordinates (coordinate :: acc) rest
        | _ -> Error "Malformed daily-pace.tsv or mismatched Measure; no rows were skipped."
  in
  Result.bind (env.config pool_file) (function
    | None -> Error "Daily Pace pool not configured (daily-pace.tsv missing)."
    | Some text -> coordinates [] (config_lines text))

(* Queries *)

let current_pace (env : Screen.env) =
  match Lazy.force env.annual.unavailable with
  | Some why -> Error why
  | None ->
      let current_year = String.sub env.today 0 4 in
      if (match env.annual.year with
          | Some year -> current_year <> Printf.sprintf "%04d" year
          | None -> false) then Error "Daily Pace requires the current calendar year's annual book."
      else
        Result.bind (resolve_pool env) (fun pool ->
          Result.bind (resolve_window env) (fun (start_day, end_exclusive) ->
            Result.map (fun p -> (p, start_day, end_exclusive))
              (Result.map_error Trend.format_pace_error
                 (B.daily_pace env.book ~measure:env.measure ~pool ~observed_at:env.today
                    ~end_exclusive))))

let samples (env : Screen.env) t =
  Result.bind (resolve_pool env) (fun pool_coords ->
    let pool_loci = List.map (fun c -> A.lstr c.D.Effect_coordinate.locus) pool_coords in
    Result.bind (env.config boundary_file) (fun boundary_text ->
      let compute () =
        Trend.compute_samples ~book:env.book ~measure:env.measure ~pool:pool_loci
          ~boundary_presets_text:boundary_text ~today:env.today ~preset:t.trend.preset
      in
      match env.annual.year with
      | None -> compute ()
      | Some _ ->
          Result.bind (current_pace env) (fun _ ->
            Result.bind (compute ()) (fun ((first_day, through_day, _) as result) ->
              Result.bind (Lazy.force env.annual.history) (function
                | Some (first, last) when first_day < first || through_day >= last ->
                    Error "Trend extends outside verified annual history."
                | _ -> Ok result)))))

let detail_lines (env : Screen.env) =
  let today = env.today and measure = env.measure in
  match resolve_window env with
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
      let pool_origin = match resolve_pool env with
        | Ok _ -> "configured (daily-pace.tsv)" | Error why -> why in
      let window_origin = "configured (boundary-presets.tsv)" in
      let pace_status =
        match current_pace env with
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

let sample_detail ~width_of ~width (env : Screen.env) t samples =
  let selected = Panel.move ~last:(List.length samples - 1)
      ~position:t.trend.selected_index 0 in
  Trend.render_detail ~width:(max 1 (width - 6)) ~width_of
    ~book:env.book ~measure:env.measure
    ~sample:(List.nth_opt samples selected)
    ~prev_sample:(if selected = 0 then None else List.nth_opt samples (selected - 1))
    ~today:env.today ~preset:t.trend.preset
  |> List.map snd

(* The focused detail keeps its neighbours on wide terminals, just as LOAM's
   trend workspace does. Navigation must use these exact painted dimensions. *)
let panel_geometry (geometry : Screen.geometry) =
  let width, height = geometry.content in
  let wide = width >= 79 && height >= 15 in
  let lower_height = if height >= 15 then max 7 (height / 2)
    else if height >= 9 then 3 else 0 in
  let detail_width = if wide then min 60 (max 30 (width * 40 / 100)) else width in
  (wide, lower_height, detail_width)

let detail_viewport env (geometry : Screen.geometry) t =
  let wide, lower_height, detail_width = panel_geometry geometry in
  let width, height = match samples env t with
    | Ok _ when wide -> detail_width, lower_height
    | Ok _ | Error _ -> geometry.content in
  let width_of = geometry.width_of in
  let rows = match samples env t with
    | Ok (_, _, samples) -> sample_detail ~width_of ~width env t samples
    | Error _ -> List.concat_map (O.wrap_text ~width_of (max 1 (width - 6))) (detail_lines env) in
  Panel.window ~capacity:(Panel.capacity ~height ~heading:false)
    ~count:(List.length rows) ~scroll:t.scroll ~selected:None

(* Forms *)

let what_if_form ?amount ?result env =
  let summary =
    match current_pace env with
    | Ok (pace, _start, _end_excl) ->
        let fmt q = O.format_money env.Screen.book pace.B.measure q ^ " " ^ pace.measure in
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
    pool_rows_of_text ~measure (captured_text payload)
  else Error "Pool configuration was unreadable; reopen after repairing it."

let pool_form (env : Screen.env) =
  let measure = env.measure in
  let payload, read_notice = payload_of (env.config pool_file) in
  let old_loci, old_why =
    match pool_old_of_payload ~measure payload with
    | Ok loci -> (loci, None)
    | Error why -> ([], Some why)
  in
  let notice = if read_notice <> "" then read_notice else Option.value ~default:"" old_why in
  let period = match resolve_window env with
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

let cycle_form (env : Screen.env) =
  let today = env.today in
  Result.bind (env.config boundary_file) (fun raw ->
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

let cycle_review_form name dates =
  Form.create ~id:"review_cycle_boundaries" ~title:"Daily Pace / Review explicit cycle boundaries"
    ~summary:(
      [ "Preset: " ^ name;
        "Only this named preset will be replaced.";
        "No dates are extrapolated or repeated.";
        "Other named presets and ledger remain unchanged.";
        "Boundaries:" ]
      @ List.map (fun d -> "  " ^ d) dates)
    ~fields:[Form.action_buttons ~confirm:"Save boundaries" ~cancel:"Edit" ()] ()

let replace_preset presets name dates =
  if List.mem_assoc name presets then
    List.map (fun (n, ds) -> if n = name then (name, dates) else (n, ds)) presets
  else presets @ [(name, dates)]

(* Entry points that other workflows (Commands) may open over any route. *)

let open_pool (env : Screen.env) t =
  match t.pool_draft with
  | Some (draft_measure, draft) when draft_measure = env.measure -> { t with overlay = Pool draft }
  | _ -> { t with overlay = Pool (pool_form env) }

let open_cycle env t =
  match cycle_form env with
  | Ok form -> ({ t with overlay = Cycle form }, Screen.Message "")
  | Error why -> ({ t with overlay = No_overlay }, Screen.Message ("Cycle setup unavailable: " ^ why))

(* Input *)

let notice form message = Form.set_notice form message

let move_selection (env : Screen.env) t delta =
  let position =
    Result.bind (env.config boundary_file) (fun boundary_presets_text ->
      Trend.move_selection ~today:env.today ~preset:t.trend.preset
        ~boundary_presets_text ~position:t.trend.selected_index delta)
  in
  match position with
  | Ok selected_index -> ({ t with trend = { t.trend with selected_index }; scroll = 0 }, Screen.Stay)
  | Error why -> (t, Screen.Message ("Daily Pace range unavailable: " ^ why))

let submit_what_if (env : Screen.env) t submitted =
  let stay form = ({ t with overlay = What_if form }, Screen.Stay) in
  let amount_str = String.trim (Option.value ~default:"" (Form.get_text submitted "amount")) in
  if amount_str = "" then stay (notice submitted (tr "Enter purchase amount to simulate."))
  else
    match B.parse_signed_amount env.book env.measure amount_str with
    | Error _ -> stay (notice submitted (tr "Invalid amount."))
    | Ok quantity when Z.leq quantity Z.zero ->
        stay (notice submitted (tr "Enter a positive amount for purchase outflow."))
    | Ok quantity ->
        match current_pace env with
        | Error why -> stay (notice submitted ("Current pace unavailable: " ^ why))
        | Ok (pace, _start, _end_excl) ->
            let new_avail = Z.sub pace.available_through_end quantity in
            let new_pace = Z.ediv new_avail (Z.of_int pace.remaining_days) in
            let diff = Z.sub new_pace pace.daily_pace_quanta in
            let fmt z = O.format_money env.book pace.measure z ^ " " ^ pace.measure in
            let diff_str = (if Z.gt diff Z.zero then "+" else "") ^ fmt diff ^ "/day" in
            let result =
              Printf.sprintf "Simulated pace: %s/day (%s). Remaining available: %s."
                (fmt new_pace) diff_str (fmt new_avail)
            in
            stay (what_if_form ~amount:amount_str ~result env)

let submit_pool (env : Screen.env) t submitted =
  let pool_loci_str = String.trim (Option.value ~default:"" (Form.get_text submitted "pool_loci")) in
  let loci = if pool_loci_str = "" then [] else
    List.map String.trim (String.split_on_char ',' pool_loci_str) in
  let approved = B.approved_loci env.book in
  let valid = loci <> [] && List.for_all (fun locus -> config_token locus
    && (match approved with Some ids -> List.mem locus ids | None -> false)) loci
    && List.length (List.sort_uniq String.compare loci) = List.length loci in
  if not valid then
    ({ t with overlay = Pool (notice submitted
        "Choose distinct admitted Locus tokens, separated by commas.") }, Screen.Stay)
  else
    let pool_draft = Some (env.measure, submitted) in
    match pool_old_of_payload ~measure:env.measure (Form.payload submitted) with
    | Error why -> ({ t with overlay = Pool (notice submitted why); pool_draft }, Screen.Stay)
    | Ok old_loci ->
        ({ t with
           overlay = Pool_review { form = pool_review_form env.measure old_loci loci;
             editing = submitted; measure = env.measure; loci };
           pool_draft }, Screen.Stay)

let submit_pool_review (env : Screen.env) (geometry : Screen.geometry) t (r : pool_review) submitted =
  let review form = { t with overlay = Pool_review { r with form } } in
  match t.pool_draft with
  | Some (draft_measure, draft)
    when r.measure = env.measure && draft_measure = r.measure
      && Form.payload r.editing = Form.payload draft ->
      if not (Ui_overlay.form_fits ~width_of:geometry.width_of ~body:geometry.body submitted) then
        (review (notice submitted "Not saved: too small."), Screen.Stay)
      else
        let payload = Form.payload r.editing in
        let expected =
          if payload = "missing" then Ok None
          else if String.starts_with ~prefix:"present\n" payload then Ok (Some (captured_text payload))
          else Error "Pool configuration was unreadable." in
        let content = String.concat "" (List.map
          (fun locus -> locus ^ "\t" ^ r.measure ^ "\n") r.loci) in
        (match Result.bind expected (fun expected ->
           Result.map (fun _ -> expected) (pool_old_of_payload ~measure:r.measure payload)) with
         | Error why ->
             (review (notice submitted
               ("Pool save not confirmed: " ^ why ^ " Reopen to inspect before retrying.")), Screen.Stay)
         | Ok expected ->
             (review submitted,
              Screen.Save_config { file = pool_file; expected; content; admission = Unconditional }))
  | _ -> ({ t with overlay = No_overlay }, Screen.Message "Pool review expired; reopen setup.")

let submit_cycle (env : Screen.env) t submitted =
  let stay form = ({ t with overlay = Cycle form }, Screen.Stay) in
  let raw = Form.payload submitted in
  let previous =
    if raw = "missing" then Ok []
    else if String.starts_with ~prefix:"present\n" raw then decode_boundary_presets (captured_text raw)
    else Error "Boundary preset configuration was unreadable; reopen after repairing it."
  in
  let name = String.trim (Option.value ~default:"" (Form.get_text submitted "name")) in
  let dates_str = String.trim (Option.value ~default:"" (Form.get_text submitted "dates")) in
  let days = if dates_str = "" then [] else
    List.map String.trim (String.split_on_char ',' dates_str) in
  if List.length days > 32 then
    stay (notice submitted "Too many dates. Enter up to 32 explicit boundaries.")
  else
    match previous, decode_boundary_presets (name ^ "\t" ^ String.concat "\t" days ^ "\n") with
    | Error why, _ -> stay (notice submitted why)
    | _, Error _ | _, Ok [] | _, Ok (_ :: _ :: _) ->
        stay (notice submitted
          "Enter a token name and at least two REAL, strictly increasing YYYY-MM-DD dates, separated by commas.")
    | Ok presets, Ok [(name, dates)] ->
        match current_window_for (replace_preset presets name dates) env.today with
        | Error why ->
            stay (notice submitted ("Explicit dates must define exactly one current cycle: " ^ why))
        | Ok (source, _, _) when source <> name ->
            stay (notice submitted
              "These dates do not cover the current cycle. Edit the current preset instead.")
        | Ok _ ->
            ({ t with overlay = Cycle_review { form = cycle_review_form name dates;
                 editing = submitted; name; dates } }, Screen.Stay)

let submit_cycle_review (env : Screen.env) (geometry : Screen.geometry) t (r : cycle_review) submitted =
  let review form = { t with overlay = Cycle_review { r with form } } in
  if not (Ui_overlay.form_fits ~width_of:geometry.width_of ~body:geometry.body submitted) then
    (review (notice submitted
       "Enlarge the terminal to review every cycle boundary before saving."), Screen.Stay)
  else
    let payload = Form.payload r.editing in
    let expected =
      if payload = "missing" then Ok None
      else if String.starts_with ~prefix:"present\n" payload then Ok (Some (captured_text payload))
      else Error "Boundary preset configuration was unreadable." in
    let content =
      Result.bind expected (fun expected ->
        Result.bind (match expected with None -> Ok [] | Some raw -> decode_boundary_presets raw)
          (fun presets ->
            let next = replace_preset presets r.name r.dates in
            Result.bind (current_window_for next env.today) (fun (source, _, _) ->
              if source <> r.name then
                Error "These dates do not cover the current cycle. Edit the current preset instead."
              else
                Ok (expected, String.concat "" (List.map (fun (n, ds) ->
                  n ^ "\t" ^ String.concat "\t" ds ^ "\n") next)))))
    in
    match content with
    | Error why ->
        (review (notice submitted ("Cycle boundary save not confirmed: " ^ why
           ^ " Reopen to inspect before retrying.")), Screen.Stay)
    | Ok (expected, content) ->
        (review submitted,
         Screen.Save_config { file = boundary_file; expected; content; admission = Household_readable })

let handle_form env geometry t form input =
  match Form.handle_input form input with
  | Form.Cancel -> (
      match t.overlay with
      | Cycle_review r -> ({ t with overlay = Cycle r.editing }, Screen.Stay)
      | Pool_review r -> ({ t with overlay = Pool r.editing }, Screen.Stay)
      | Pool _ -> ({ t with overlay = No_overlay; pool_draft = Some (env.Screen.measure, form) }, Screen.Stay)
      | No_overlay | What_if _ | Cycle _ -> ({ t with overlay = No_overlay }, Screen.Stay))
  | Form.Updated updated -> (
      match t.overlay with
      | Pool _ ->
          ({ t with overlay = Pool updated; pool_draft = Some (env.measure, updated) }, Screen.Stay)
      | _ -> (with_form updated t, Screen.Stay))
  | Form.Submit submitted -> (
      match t.overlay with
      | What_if _ -> submit_what_if env t submitted
      | Pool _ -> submit_pool env t submitted
      | Pool_review r -> submit_pool_review env geometry t r submitted
      | Cycle _ -> submit_cycle env t submitted
      | Cycle_review r -> submit_cycle_review env geometry t r submitted
      | No_overlay -> (t, Screen.Stay))

let history_page (env : Screen.env) (geometry : Screen.geometry) t =
  let width, _ = geometry.content in
  let wide, lower_height, detail_width = panel_geometry geometry in
  let history_width = if wide then width - detail_width - 1 else width in
  let capacity = Panel.capacity ~height:lower_height ~heading:false in
  match samples env t with
  | Error _ -> 1
  | Ok (_, _, samples) ->
      Trend.render_history ~width:(max 0 (history_width - 6)) ~height:capacity
        ~width_of:geometry.width_of ~book:env.book ~measure:env.measure ~samples
        ~selected_index:t.trend.selected_index
      |> List.fold_left (fun count (style, _) ->
           if style = O.Chrome then count else count + 1) 0
      |> max 1

let toggle_pane t =
  ({ t with pane = (if t.pane = Trend_pane then Detail_pane else Trend_pane); scroll = 0 }, Screen.Stay)

let handle_screen (env : Screen.env) geometry t input =
  let key = match input with
    | `Key (`ASCII c, mods) -> Some (`ASCII (Char.lowercase_ascii c), mods)
    | `Key (key, mods) -> Some (key, mods)
    | _ -> None
  in
  match key with
  | Some ((`Escape | `ASCII 'q'), []) ->
      if t.pane = Detail_pane then ({ t with pane = Trend_pane; scroll = 0 }, Screen.Stay)
      else (t, Screen.Home)
  | Some (`ASCII 'w', []) -> ({ t with overlay = What_if (what_if_form env) }, Screen.Stay)
  | Some (`ASCII 'c', []) -> (open_pool env t, Screen.Message "")
  | Some (`ASCII 'b', []) -> (
      match cycle_form env with
      | Ok form -> ({ t with overlay = Cycle form }, Screen.Stay)
      | Error why -> (t, Screen.Message ("Cycle setup unavailable: " ^ why)))
  | Some (`ASCII ('1' .. '5' as c), []) -> (
      let preset = match c with
        | '1' -> Trend.Ten_days
        | '2' -> Trend.Thirty_days
        | '3' -> Trend.Month
        | '4' -> Trend.Cycle
        | _ -> Trend.Previous_cycle in
      match Result.bind (env.config boundary_file)
          (fun boundary_presets_text -> Trend.change_preset ~today:env.today
            ~boundary_presets_text t.trend preset) with
      | Ok trend -> ({ t with trend; scroll = 0 }, Screen.Stay)
      | Error why -> (t, Screen.Message ("Daily Pace range unavailable: " ^ why)))
  | Some (`ASCII 'v', []) ->
      ({ t with trend = { t.trend with graph_style = Trend.next_graph_style t.trend.graph_style } },
       Screen.Stay)
  | Some (((`ASCII ('h' | 'l') | `Arrow (`Left | `Right)) as k), []) ->
      move_selection env t (match k with `ASCII 'h' | `Arrow `Left -> -1 | _ -> 1)
  | Some (((`Home | `End | `Page _ | `ASCII ('j' | 'k') | `Arrow (`Up | `Down)) as k), [])
  | Some ((`ASCII ('u' | 'd') as k), [ `Ctrl ]) ->
      let view = if t.pane = Detail_pane then Some (detail_viewport env geometry t) else None in
      let paging = match k with `Page _ | `ASCII ('u' | 'd') -> true | _ -> false in
      let page = match view with
        | Some view -> max 1 view.capacity
        | None when paging -> history_page env geometry t
        | None -> 1 in
      let delta = match k with
        | `Home -> -max_int | `End -> max_int
        | `Page `Up | `ASCII 'u' -> -page
        | `Page `Down | `ASCII 'd' -> page
        | `ASCII 'k' | `Arrow `Up -> -1 | _ -> 1 in
      (match view with
       | Some view -> ({ t with scroll = Panel.move ~last:view.last ~position:view.start delta }, Screen.Stay)
       | None -> move_selection env t delta)
  | Some ((`Enter | `ASCII 'i'), []) -> toggle_pane t
  | Some (`Tab, ([] | [ `Shift ])) -> toggle_pane t
  | _ -> (t, Screen.Ignored)

let handle env geometry t input =
  match form t with
  | Some form -> handle_form env geometry t form input
  | None -> handle_screen env geometry t input

let saved _env _geometry result t =
  match t.overlay, result with
  | Pool_review _, Ok () ->
      ({ t with overlay = No_overlay; pool_draft = None },
       Screen.Message "Daily Pace pool saved. Period presets unchanged.")
  | Pool_review r, Error why ->
      ({ t with overlay = Pool_review { r with form = notice r.form
           ("Pool save not confirmed: " ^ why ^ " Reopen to inspect before retrying.") } },
       Screen.Stay)
  | Cycle_review _, Ok () ->
      ({ t with overlay = No_overlay }, Screen.Message "Explicit Daily Pace cycle boundaries saved.")
  | Cycle_review r, Error why ->
      ({ t with overlay = Cycle_review { r with form = notice r.form
           ("Cycle boundary save not confirmed: " ^ why ^ " Reopen to inspect before retrying.") } },
       Screen.Stay)
  | (No_overlay | What_if _ | Pool _ | Cycle _), _ -> (t, Screen.Stay)

(* Painting *)

let header_summary env t ~width ~width_of =
  let current = current_pace env in
  let today = match current with
  | Error _ -> "Today: unavailable (not zero)"
  | Ok (pace, _, _) ->
      let text = "Today: " ^ O.format_money env.Screen.book pace.B.measure
          pace.daily_pace_quanta ^ " " ^ pace.measure ^ "/day" in
      if width_of text <= width then text else "Today: End, then i for full value" in
  let choices = Trend.presets |> List.mapi (fun index preset ->
    Printf.sprintf "%d:%s%s" (index + 1) (Trend.preset_label preset)
      (if preset = t.trend.preset then "*" else "")) |> String.concat " " in
  let period = if width >= 85 then "   " ^ choices else "   [1-5] period" in
  let spent = match current, samples env t with
    | Ok (pace, _, _), Ok (_, _, samples) ->
        (match List.find_opt (fun (sample : Trend.sample) -> sample.day = env.today) samples with
        | Some { activity = Some activity; pace_quanta = Some _; _ } ->
            let money q = O.format_money env.book pace.B.measure q in
            let margin = Z.sub pace.daily_pace_quanta activity.discretionary_outflow in
            " • Spent: " ^ money activity.discretionary_outflow ^ " " ^ pace.measure
            ^ " (" ^ (if Z.sign margin > 0 then "+" else "") ^ money margin
            ^ " vs pace)"
        | Some _ | None -> "")
    | Error _, _ | _, Error _ -> "" in
  (* Keep quantities whole. Activity is shown only from today's qualified
     sample; selecting Previous Cycle must not invent a current-day sample. *)
  let full = today ^ spent ^ period in
  if width_of full <= width then full
  else let context = today ^ period in
    if width_of context <= width then context else today

let rows (env : Screen.env) (geometry : Screen.geometry) t =
  let width, height = geometry.content in
  let width_of = geometry.width_of in
  let is_detail = t.pane = Detail_pane in
  match samples env t with
  | Ok (_, _, samples) ->
      let count = List.length samples in
      let selected_idx = max 0 (min (count - 1) t.trend.selected_index) in
      let title = Printf.sprintf "Trend • %s [%s] %d/%d"
          (Trend.preset_label t.trend.preset)
          (Trend.graph_style_label t.trend.graph_style)
          (if count = 0 then 0 else selected_idx + 1) count in
      let wide, lower_height, detail_width = panel_geometry geometry in
      let detail_height = if wide then lower_height else 0 in
      let history_width = if wide then width - detail_width - 1 else width in
      let history_height = lower_height in
      let detail_panel ~height =
        let detail_rows = sample_detail ~width_of ~width:detail_width env t samples in
        Panel.frame ~width_of ~width:detail_width ~height ~focused:is_detail
          ~title:"Selected day" ~scroll:t.scroll ~selected:None detail_rows
      in
      if is_detail && not wide then detail_panel ~height
      else
        let chart_height = height - lower_height in
        let chart =
          Trend.render_chart ~width:(max 0 (width - 6))
            ~height:(Panel.capacity ~height:chart_height ~heading:false)
            ~width_of ~book:env.book ~today:env.today ~measure:env.measure ~samples
            ~selected_index:selected_idx ~graph_style:t.trend.graph_style
          |> Panel.frame_rows ~width_of ~width ~height:chart_height
               ~focused:(not is_detail) ~title
        in
        let history =
          Trend.render_history ~width:(max 0 (history_width - 6))
            ~height:(Panel.capacity ~height:history_height ~heading:false)
            ~width_of ~book:env.book ~measure:env.measure ~samples ~selected_index:selected_idx
          |> Panel.frame_rows ~width_of ~width:history_width ~height:history_height
               ~focused:(not is_detail)
               ~title:(Printf.sprintf "History %d/%d"
                 (if count = 0 then 0 else selected_idx + 1) count)
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
        Panel.frame ~width_of ~width ~height ~focused:true ~title:"Pace Detail & Evidence"
          ~scroll:t.scroll ~selected:None
          (List.concat_map (O.wrap_text ~width_of (max 1 (width - 6))) (detail_lines env))
      else
        let left_width, right_width = Panel.split_widths width in
        let left_rows =
          List.concat_map (O.wrap_text ~width_of (max 1 (left_width - 6)))
            [
              tr "Daily Pace unavailable:";
              why;
              "Supply an explicit daily-pace.tsv pool and boundary-presets.tsv period.";
            ]
        in
        let wrapped_detail =
          List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) (detail_lines env) in
        Panel.split ~width_of ~width ~height
          ~left_focused:true ~left_title:(Printf.sprintf "Daily Pace / %s"
            (Trend.preset_label t.trend.preset))
          ~left_scroll:0 ~left_selected:None ~left_rows
          ~right_focused:false ~right_title:"Pace Detail & Evidence" ~right_scroll:0
          ~right_selected:None ~right_rows:wrapped_detail ()

let footer (geometry : Screen.geometry) t =
  let narrow = fst geometry.screen < 64 in
  match t.overlay, t.pane with
  | What_if _, _ ->
      [ "Enter simulate scenario  Tab switch field/button  Esc close"; "Read-only simulation - does not publish any entries" ]
  | Pool _, _ -> [ "Enter review  Tab switch field  Esc cancel"; "Edits only daily-pace.tsv" ]
  | Pool_review _, _ -> [ "Enter save  Tab choose Edit  Esc edit"; "Full pool must fit before saving" ]
  | Cycle _, _ -> [ "Enter review  Tab switch field  Esc cancel"; "Edits only boundary-presets.tsv" ]
  | Cycle_review _, _ -> [ "Enter save  Tab choose Edit  Esc edit"; "Full boundaries must fit before saving" ]
  | No_overlay, Trend_pane ->
      if narrow then [ "h/l day  v view  i info  q back"; "1-5 period  C-u/d page  Home/End" ]
      else
        [ "h/l day  v view  i/Enter details  q back  w what-if";
          "1-5 period  C-u/d page  Home/End ends  c pool  b cycle" ]
  | No_overlay, Detail_pane ->
      if narrow then [ "j/k scroll  v view  i/q trend"; "h/l day  1-5 period  C-u/d page" ]
      else
        [ "j/k scroll  v view  i/q trend  h/l day  w what-if";
          "1-5 period  C-u/d page  Home/End ends  c pool  b cycle" ]

let view env (geometry : Screen.geometry) t =
  let overlay = Option.bind (form t)
      (Ui_overlay.form ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body) in
  {
    Screen.title = tr "Daily Pace / Trend" ^ " • " ^ Trend.preset_label t.trend.preset;
    subtitle = Text (header_summary env t ~width:(fst geometry.screen) ~width_of:geometry.width_of);
    rows = lazy (rows env geometry t);
    footer = footer geometry t;
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
