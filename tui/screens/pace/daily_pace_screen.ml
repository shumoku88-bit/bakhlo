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
module Target = Daily_pace_target
module Why = Daily_pace_why
module What_if = Daily_pace_what_if
module Pool = Daily_pace_pool

let tr = Ui_text.tr
let pool_file = "daily-pace.tsv"
let boundary_file = "boundary-presets.tsv"
let config_files = [ pool_file; boundary_file ]

type pane = Trend_pane | Detail_pane

(* A review keeps the editing form whose payload holds the captured bytes. *)
type cycle_review = { form : Form.t; editing : Form.t; name : string; dates : string list }

type overlay =
  | No_overlay
  | What_if of What_if.t  (** Read-only purchase scenario; not a form. *)
  | Target of Target.t  (** Read-only target plan; not a form. *)
  | Why of Why.t  (** Read-only terms of today's answer. *)
  | Pool of Pool.t  (** Spendable-pool picker and its review. *)
  | Cycle of Form.t
  | Cycle_review of cycle_review

type t = {
  trend : Trend.t;
  pane : pane;
  scroll : int;
  overlay : overlay;
  pool_draft : Pool.t option;  (** Cancelled picker, resumed for the same Measure. *)
}

let create () =
  {
    trend = Trend.initial ();
    pane = Trend_pane;
    scroll = 0;
    overlay = No_overlay;
    pool_draft = None;
  }

let enter t = { t with pane = Trend_pane; scroll = 0; overlay = No_overlay }

let form t =
  match t.overlay with
  | No_overlay | Target _ | Why _ | What_if _ | Pool _ -> None
  | Cycle form -> Some form
  | Cycle_review { form; _ } -> Some form

let modal t =
  Option.is_some (form t)
  || match t.overlay with Target _ | Why _ | What_if _ | Pool _ -> true | _ -> false

let with_form form t =
  let overlay =
    match t.overlay with
    | No_overlay -> No_overlay
    | (Target _ | Why _ | What_if _ | Pool _) as other -> other
    | Cycle _ -> Cycle form
    | Cycle_review (r : cycle_review) -> Cycle_review { r with form }
  in
  { t with overlay }

let trend t = t.trend
let detail_focused t = t.pane = Detail_pane
let detail_scroll t = t.scroll

(* Configuration text *)

let config_lines text =
  String.split_on_char '\n' text
  |> List.filter (fun line ->
      let s = String.trim line in
      s <> "" && not (String.starts_with ~prefix:"#" s))

let config_token s = s <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) s
let captured_text payload = String.sub payload 8 (String.length payload - 8)

let resolve_window (env : Screen.env) =
  Result.bind (env.config boundary_file) (function
    | None -> Error "Period not configured (boundary-presets.tsv missing)."
    | Some text -> (
        match Boundary_presets.parse text with
        | Error () -> Error "Malformed boundary-presets.tsv; no period was inferred."
        | Ok presets -> (
            match Boundary_presets.containing env.today presets with
            | [ (_, start_day, end_exclusive) ] -> Ok (start_day, end_exclusive)
            | [] -> Error "No explicit boundary preset contains today."
            | _ -> Error "Multiple boundary presets contain today; selection is ambiguous.")))

let resolve_pool (env : Screen.env) =
  let measure = env.measure in
  let rec coordinates acc = function
    | [] -> if acc = [] then Error "Daily Pace pool is empty." else Ok (List.rev acc)
    | line :: rest -> (
        match String.split_on_char '\t' line with
        | [ locus; m ] when config_token locus && m = measure && config_token m ->
            let coordinate =
              {
                D.Effect_coordinate.locus = A.get_id (D.Identifier.Locus.of_string locus);
                measure = A.get_id (D.Identifier.Measure.of_string m);
              }
            in
            if List.mem coordinate acc then Error "Duplicate Daily Pace coordinate."
            else coordinates (coordinate :: acc) rest
        | _ -> Error "Malformed daily-pace.tsv or mismatched Measure; no rows were skipped.")
  in
  Result.bind (env.config pool_file) (function
    | None -> Error "Daily Pace pool not configured (daily-pace.tsv missing)."
    | Some text -> coordinates [] (config_lines text))

(* Queries *)

let current_pace (env : Screen.env) =
  Result.bind (resolve_pool env) (fun pool ->
      Result.bind (resolve_window env) (fun (start_day, end_exclusive) ->
          Result.map
            (fun p -> (p, start_day, end_exclusive))
            (Result.map_error Trend.format_pace_error
               (B.daily_pace env.book ~measure:env.measure ~pool ~observed_at:env.today
                  ~end_exclusive))))

let samples (env : Screen.env) t =
  Result.bind (resolve_pool env) (fun pool_coords ->
      let pool_loci = List.map (fun c -> A.lstr c.D.Effect_coordinate.locus) pool_coords in
      Result.bind (env.config boundary_file) (fun boundary_text ->
          Trend.compute_samples ~book:env.book ~measure:env.measure ~pool:pool_loci
            ~boundary_presets_text:boundary_text ~today:env.today ~preset:t.trend.preset))

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
      let pool_origin =
        match resolve_pool env with Ok _ -> "configured (daily-pace.tsv)" | Error why -> why
      in
      let window_origin = "configured (boundary-presets.tsv)" in
      let pace_status =
        match current_pace env with Ok _ -> "calculated" | Error why -> "unavailable: " ^ why
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
  let selected = Panel.move ~last:(List.length samples - 1) ~position:t.trend.selected_index 0 in
  Trend.render_detail
    ~width:(max 1 (width - 2))
    ~width_of ~book:env.book ~measure:env.measure ~samples ~selected_index:selected ~today:env.today
    ~preset:t.trend.preset

(* The focused detail keeps its neighbours on wide terminals, just as LOAM's
   trend workspace does. Navigation must use these exact painted dimensions. *)
let panel_geometry (geometry : Screen.geometry) =
  let width, body_height = geometry.content in
  let context_rows = if body_height >= 5 then 2 else if body_height >= 4 then 1 else 0 in
  let height = max 0 (body_height - context_rows) in
  let wide = width >= 79 && height >= 15 in
  let lower_height = if height >= 15 then max 7 (height / 2) else 0 in
  let detail_width = if wide then min 60 (max 30 (width * 40 / 100)) else width in
  (wide, lower_height, detail_width)

let detail_viewport env (geometry : Screen.geometry) t =
  let wide, lower_height, detail_width = panel_geometry geometry in
  let _, body_height = geometry.content in
  let context_rows = if body_height >= 5 then 2 else if body_height >= 4 then 1 else 0 in
  let panel_height = max 0 (body_height - context_rows) in
  let width, height =
    match samples env t with
    | Ok _ when wide -> (detail_width, lower_height)
    | Ok _ when lower_height >= 12 -> (detail_width, 6)
    | Ok _ | Error _ -> (fst geometry.content, panel_height)
  in
  let width_of = geometry.width_of in
  let rows =
    match samples env t with
    | Ok (_, _, samples) -> sample_detail ~width_of ~width env t samples
    | Error _ ->
        List.concat_map (O.wrap_text ~width_of (max 1 (width - 2))) (detail_lines env)
        |> List.map (fun text -> (O.Plain, text))
  in
  Panel.window
    ~capacity:(Panel.capacity ~height ~heading:false)
    ~count:(List.length rows) ~scroll:t.scroll ~selected:None

(* Forms *)

let decode_boundary_presets text =
  Result.map_error
    (fun () -> "Boundary preset config malformed. Refusing implicit replacement.")
    (Boundary_presets.parse text)

let current_window_for presets today =
  match Boundary_presets.containing today presets with
  | [ w ] -> Ok w
  | [] -> Error "no configured boundary preset contains the current date"
  | _ -> Error "multiple configured boundary presets contain the current date"

let cycle_form (env : Screen.env) =
  let today = env.today in
  Result.bind (env.config boundary_file) (fun raw ->
      Result.map
        (fun presets ->
          let name, dates =
            match current_window_for presets today with
            | Ok (source, _, _) ->
                let ds = Option.value ~default:[] (List.assoc_opt source presets) in
                (source, String.concat ", " ds)
            | Error _ -> (
                match presets with [ (n, ds) ] -> (n, String.concat ", " ds) | _ -> ("pension", ""))
          in
          let payload = match raw with None -> "missing" | Some text -> "present\n" ^ text in
          Form.create ~id:"configure_cycle_boundaries" ~payload
            ~title:"Daily Pace / Cycle boundaries"
            ~summary:
              [
                "Enter explicit dates, including today's cycle (" ^ today ^ ").";
                "Example: 2026-10-15, 2026-12-15";
                "No dates are extrapolated or repeated; other presets stay untouched.";
              ]
            ~fields:
              [
                Form.text_field ~id:"name" ~label:"Name" ~value:name ();
                Form.text_field ~id:"dates" ~label:"Dates" ~value:dates ();
                Form.action_buttons ~confirm:"Review" ~cancel:"Cancel" ();
              ]
            ())
        (match raw with None -> Ok [] | Some text -> decode_boundary_presets text))

let cycle_review_form name dates =
  Form.create ~id:"review_cycle_boundaries" ~title:"Daily Pace / Review explicit cycle boundaries"
    ~summary:
      ([
         "Preset: " ^ name;
         "Only this named preset will be replaced.";
         "No dates are extrapolated or repeated.";
         "Other named presets and ledger remain unchanged.";
         "Boundaries:";
       ]
      @ List.map (fun d -> "  " ^ d) dates)
    ~fields:[ Form.action_buttons ~confirm:"Save boundaries" ~cancel:"Edit" () ]
    ()

let replace_preset presets name dates =
  if List.mem_assoc name presets then
    List.map (fun (n, ds) -> if n = name then (name, dates) else (n, ds)) presets
  else presets @ [ (name, dates) ]

(* Entry points that other workflows (Commands) may open over any route. *)

let open_pool (env : Screen.env) t =
  match t.pool_draft with
  | Some draft when Pool.measure draft = env.measure -> { t with overlay = Pool draft }
  | _ ->
      {
        t with
        overlay =
          Pool (Pool.prepare ~book:env.book ~measure:env.measure ~config:(env.config pool_file));
      }

let open_cycle env t =
  match cycle_form env with
  | Ok form -> ({ t with overlay = Cycle form }, Screen.Message "")
  | Error why ->
      ({ t with overlay = No_overlay }, Screen.Message ("Cycle setup unavailable: " ^ why))

(* Input *)

let notice form message = Form.set_notice form message

let move_selection (env : Screen.env) t delta =
  let position =
    Result.bind (env.config boundary_file) (fun boundary_presets_text ->
        Trend.move_selection ~today:env.today ~preset:t.trend.preset ~boundary_presets_text
          ~position:t.trend.selected_index delta)
  in
  match position with
  | Ok selected_index ->
      ({ t with trend = { t.trend with selected_index }; scroll = 0 }, Screen.Stay)
  | Error why -> (t, Screen.Message ("Daily Pace range unavailable: " ^ why))

let submit_cycle (env : Screen.env) t submitted =
  let stay form = ({ t with overlay = Cycle form }, Screen.Stay) in
  let raw = Form.payload submitted in
  let previous =
    if raw = "missing" then Ok []
    else if String.starts_with ~prefix:"present\n" raw then
      decode_boundary_presets (captured_text raw)
    else Error "Boundary preset configuration was unreadable; reopen after repairing it."
  in
  let name = String.trim (Option.value ~default:"" (Form.get_text submitted "name")) in
  let dates_str = String.trim (Option.value ~default:"" (Form.get_text submitted "dates")) in
  let days =
    if dates_str = "" then [] else List.map String.trim (String.split_on_char ',' dates_str)
  in
  if List.length days > 32 then
    stay (notice submitted "Too many dates. Enter up to 32 explicit boundaries.")
  else
    match (previous, decode_boundary_presets (name ^ "\t" ^ String.concat "\t" days ^ "\n")) with
    | Error why, _ -> stay (notice submitted why)
    | _, Error _ | _, Ok [] | _, Ok (_ :: _ :: _) ->
        stay
          (notice submitted
             "Enter a token name and at least two REAL, strictly increasing YYYY-MM-DD dates, \
              separated by commas.")
    | Ok presets, Ok [ (name, dates) ] -> (
        match current_window_for (replace_preset presets name dates) env.today with
        | Error why ->
            stay (notice submitted ("Explicit dates must define exactly one current cycle: " ^ why))
        | Ok (source, _, _) when source <> name ->
            stay
              (notice submitted
                 "These dates do not cover the current cycle. Edit the current preset instead.")
        | Ok _ ->
            ( {
                t with
                overlay =
                  Cycle_review
                    { form = cycle_review_form name dates; editing = submitted; name; dates };
              },
              Screen.Stay ))

let submit_cycle_review (env : Screen.env) (geometry : Screen.geometry) t (r : cycle_review)
    submitted =
  let review form = { t with overlay = Cycle_review { r with form } } in
  if not (Ui_overlay.form_fits ~width_of:geometry.width_of ~body:geometry.body submitted) then
    ( review (notice submitted "Enlarge the terminal to review every cycle boundary before saving."),
      Screen.Stay )
  else
    let payload = Form.payload r.editing in
    let expected =
      if payload = "missing" then Ok None
      else if String.starts_with ~prefix:"present\n" payload then Ok (Some (captured_text payload))
      else Error "Boundary preset configuration was unreadable."
    in
    let content =
      Result.bind expected (fun expected ->
          Result.bind
            (match expected with None -> Ok [] | Some raw -> decode_boundary_presets raw)
            (fun presets ->
              let next = replace_preset presets r.name r.dates in
              Result.bind (current_window_for next env.today) (fun (source, _, _) ->
                  if source <> r.name then
                    Error
                      "These dates do not cover the current cycle. Edit the current preset instead."
                  else
                    Ok
                      ( expected,
                        String.concat ""
                          (List.map (fun (n, ds) -> n ^ "\t" ^ String.concat "\t" ds ^ "\n") next)
                      ))))
    in
    match content with
    | Error why ->
        ( review
            (notice submitted
               ("Cycle boundary save not confirmed: " ^ why ^ " Reopen to inspect before retrying.")),
          Screen.Stay )
    | Ok (expected, content) ->
        ( review submitted,
          Screen.Save_config
            { file = boundary_file; expected; content; admission = Household_readable } )

let handle_form env geometry t form input =
  match Form.handle_input form input with
  | Form.Cancel -> (
      match t.overlay with
      | Cycle_review r -> ({ t with overlay = Cycle r.editing }, Screen.Stay)
      | No_overlay | Pool _ | Target _ | Why _ | What_if _ | Cycle _ ->
          ({ t with overlay = No_overlay }, Screen.Stay))
  | Form.Updated updated -> (with_form updated t, Screen.Stay)
  | Form.Submit submitted -> (
      match t.overlay with
      | Cycle _ -> submit_cycle env t submitted
      | Cycle_review r -> submit_cycle_review env geometry t r submitted
      | No_overlay | Target _ | Why _ | What_if _ | Pool _ -> (t, Screen.Stay))

(* LOAM historyCapacityForBounds: the painted History data rows, at least one. *)
let history_page (geometry : Screen.geometry) =
  let wide, lower_height, _ = panel_geometry geometry in
  let history_height =
    if (not wide) && lower_height >= 12 then lower_height - 6 else lower_height
  in
  max 1 (history_height - 4)

let toggle_pane t =
  ( { t with pane = (if t.pane = Trend_pane then Detail_pane else Trend_pane); scroll = 0 },
    Screen.Stay )

let handle_screen (env : Screen.env) geometry t input =
  let key = Ui_input.key_ignoring_case input in
  match key with
  | Some ((`Escape | `ASCII 'q'), []) ->
      if t.pane = Detail_pane then ({ t with pane = Trend_pane; scroll = 0 }, Screen.Stay)
      else (t, Screen.Home)
  | Some (`ASCII 'w', []) -> ({ t with overlay = What_if (What_if.create ()) }, Screen.Stay)
  | Some (`ASCII 't', []) -> ({ t with overlay = Target (Target.create ()) }, Screen.Stay)
  | Some (`ASCII '?', []) -> ({ t with overlay = Why (Why.create ()) }, Screen.Stay)
  | Some (`ASCII 'c', []) -> (open_pool env t, Screen.Message "")
  | Some (`ASCII 'b', []) -> (
      match cycle_form env with
      | Ok form -> ({ t with overlay = Cycle form }, Screen.Stay)
      | Error why -> (t, Screen.Message ("Cycle setup unavailable: " ^ why)))
  | Some (`ASCII ('1' .. '5' as c), []) -> (
      let preset =
        match c with
        | '1' -> Trend.Ten_days
        | '2' -> Trend.Thirty_days
        | '3' -> Trend.Month
        | '4' -> Trend.Cycle
        | _ -> Trend.Previous_cycle
      in
      match
        Result.bind (env.config boundary_file) (fun boundary_presets_text ->
            Trend.change_preset ~today:env.today ~boundary_presets_text t.trend preset)
      with
      | Ok trend -> ({ t with trend; scroll = 0 }, Screen.Stay)
      | Error why -> (t, Screen.Message ("Daily Pace range unavailable: " ^ why)))
  | Some (`ASCII 'v', []) ->
      ( { t with trend = { t.trend with graph_style = Trend.next_graph_style t.trend.graph_style } },
        Screen.Stay )
  | Some (((`ASCII ('h' | 'l') | `Arrow (`Left | `Right)) as k), []) ->
      move_selection env t (match k with `ASCII 'h' | `Arrow `Left -> -1 | _ -> 1)
  | Some (((`Home | `End | `Page _ | `ASCII ('j' | 'k') | `Arrow (`Up | `Down)) as k), [])
  | Some ((`ASCII ('u' | 'd') as k), [ `Ctrl ]) -> (
      let view = if t.pane = Detail_pane then Some (detail_viewport env geometry t) else None in
      let paging = match k with `Page _ | `ASCII ('u' | 'd') -> true | _ -> false in
      let page =
        match view with
        | Some view -> max 1 view.capacity
        | None when paging -> history_page geometry
        | None -> 1
      in
      let delta = Ui_input.motion_delta ~page k in
      match view with
      | Some view ->
          ({ t with scroll = Panel.move ~last:view.last ~position:view.start delta }, Screen.Stay)
      | None -> move_selection env t delta)
  | Some ((`Enter | `ASCII 'i'), []) -> toggle_pane t
  | Some (`Tab, ([] | [ `Shift ])) -> toggle_pane t
  | _ -> (t, Screen.Ignored)

let target_pace env = Result.map (fun (pace, _, _) -> pace) (current_pace env)

let handle env geometry t input =
  match (t.overlay, form t) with
  | Target target, _ -> (
      match Target.update ~book:env.Screen.book ~pace:(target_pace env) target input with
      | Target.Stay target -> ({ t with overlay = Target target }, Screen.Stay)
      | Target.Back -> ({ t with overlay = No_overlay }, Screen.Stay))
  | What_if what_if, _ -> (
      match
        What_if.update ~book:env.Screen.book ~measure:env.measure ~pace:(target_pace env) what_if
          input
      with
      | What_if.Stay what_if -> ({ t with overlay = What_if what_if }, Screen.Stay)
      | What_if.Back -> ({ t with overlay = No_overlay }, Screen.Stay))
  | Pool picker, _ -> (
      let width, height = geometry.Screen.body in
      match Pool.update ~width_of:geometry.width_of ~width ~height picker input with
      | Pool.Stay picker -> ({ t with overlay = Pool picker }, Screen.Stay)
      | Pool.Cancel picker ->
          ({ t with overlay = No_overlay; pool_draft = Some picker }, Screen.Stay)
      | Pool.Save { picker; expected; content } ->
          ( { t with overlay = Pool picker; pool_draft = Some picker },
            Screen.Save_config { file = pool_file; expected; content; admission = Unconditional } ))
  | Why why, _ -> (
      match
        Why.update ~width_of:geometry.Screen.width_of ~body:geometry.body ~book:env.Screen.book
          ~pace:(target_pace env) why input
      with
      | Why.Stay why -> ({ t with overlay = Why why }, Screen.Stay)
      | Why.Back -> ({ t with overlay = No_overlay }, Screen.Stay))
  | _, Some form -> handle_form env geometry t form input
  | _, None -> handle_screen env geometry t input

let saved _env _geometry result t =
  match (t.overlay, result) with
  | Pool _, Ok () ->
      ( { t with overlay = No_overlay; pool_draft = None },
        Screen.Message "Daily Pace pool saved. Period presets unchanged." )
  | Pool picker, Error why ->
      let picker =
        Pool.with_notice picker
          ("Pool save not confirmed: " ^ why ^ " Reopen to inspect before retrying.")
      in
      ({ t with overlay = Pool picker; pool_draft = Some picker }, Screen.Stay)
  | Cycle_review _, Ok () ->
      ({ t with overlay = No_overlay }, Screen.Message "Explicit Daily Pace cycle boundaries saved.")
  | Cycle_review r, Error why ->
      ( {
          t with
          overlay =
            Cycle_review
              {
                r with
                form =
                  notice r.form
                    ("Cycle boundary save not confirmed: " ^ why
                   ^ " Reopen to inspect before retrying.");
              };
        },
        Screen.Stay )
  | (No_overlay | Target _ | Why _ | What_if _ | Cycle _), _ -> (t, Screen.Stay)

(* Painting *)

let header_summary env t ~today_pace ~history ~width ~width_of =
  let current = Lazy.force today_pace in
  let today =
    match current with
    | Error _ -> "Today: unavailable (i: cause)"
    | Ok (pace, _, _) ->
        let text =
          " Today: "
          ^ O.format_money env.Screen.book pace.B.measure pace.daily_pace_quanta
          ^ " " ^ pace.measure ^ "/day"
        in
        if width_of text <= width then text else "Today: End, then i for full value"
  in
  let choices =
    Trend.presets
    |> List.mapi (fun index preset ->
        Printf.sprintf "%d:%s%s" (index + 1) (Trend.preset_label preset)
          (if preset = t.trend.preset then "*" else ""))
    |> String.concat " "
  in
  let period = if width >= 85 then "   " ^ choices else "   [1-5] period" in
  let spent =
    match (current, Lazy.force history) with
    | Ok (pace, _, _), Ok (_, _, samples) -> (
        match List.find_opt (fun (sample : Trend.sample) -> sample.day = env.today) samples with
        | Some { activity = Some activity; pace_quanta = Some _; _ } ->
            let money q = O.format_money env.book pace.B.measure q in
            let margin = Z.sub pace.daily_pace_quanta activity.discretionary_outflow in
            " • Spent: "
            ^ money activity.discretionary_outflow
            ^ " " ^ pace.measure ^ " ("
            ^ (if Z.sign margin > 0 then "+" else "")
            ^ money margin ^ " vs pace)"
        | Some _ | None -> "")
    | Error _, _ | _, Error _ -> ""
  in
  (* Keep quantities whole. Activity is shown only from today's qualified
     sample; selecting Previous Cycle must not invent a current-day sample. *)
  let full = today ^ spent ^ period in
  if width_of full <= width then full
  else
    let context = today ^ period in
    if width_of context <= width then context else today

(* Two context rows when there is room (title, then today's summary), one when
   tight, none in a tiny terminal. *)
let context_rows env t ~today_pace ~history ~width ~width_of ~body_height =
  if body_height >= 5 then
    [
      ( O.Plain,
        O.clip_text ~width_of width
          (" Daily Pace / Trend • " ^ Trend.preset_label t.trend.preset
         ^ "   [?] why  [w] what-if  [t] target") );
      ( O.Chrome,
        O.clip_text ~width_of width (header_summary env t ~today_pace ~history ~width ~width_of) );
    ]
  else if body_height >= 4 then
    [ (O.Plain, header_summary env t ~today_pace ~history ~width ~width_of) ]
  else []

let panel ~width_of ~width ~height ~focused ~title ~bottom rows =
  Panel.frame_rows ~inset:0 ~bottom_label:bottom ~width_of ~width ~height ~focused ~title rows

(* The Selected day panel, scrolled by [t.scroll], with a position label. *)
let selected_day_panel ~width_of ~width ~height t rows =
  let is_detail = t.pane = Detail_pane in
  let view =
    Panel.window
      ~capacity:(max 0 (height - 2))
      ~count:(List.length rows) ~scroll:t.scroll ~selected:None
  in
  let bottom =
    Printf.sprintf "%d-%d/%d%s%s"
      (if view.capacity = 0 then 0 else view.start + 1)
      (min (view.start + view.capacity) (List.length rows))
      (List.length rows)
      (if view.start > 0 then " ↑" else "")
      (if view.start + view.capacity < List.length rows then " ↓" else "")
  in
  List.filteri (fun i _ -> i >= view.start && i < view.start + view.capacity) rows
  |> panel ~width_of ~width ~height ~focused:is_detail
       ~title:("Selected day" ^ if is_detail then " [active]" else "")
       ~bottom

(* Chart on top; History beside (wide) or above (narrow) the Selected day panel. *)
let trend_rows (env : Screen.env) (geometry : Screen.geometry) t ~height samples =
  let width, _ = geometry.content and width_of = geometry.width_of in
  let is_detail = t.pane = Detail_pane in
  let count = List.length samples in
  let selected_idx = max 0 (min (count - 1) t.trend.selected_index) in
  let wide, lower_height, detail_width = panel_geometry geometry in
  let detail_height = if wide then lower_height else if lower_height >= 12 then 6 else 0 in
  let history_width = if wide then width - detail_width - 1 else width in
  let history_height = if wide then lower_height else lower_height - detail_height in
  let detail ~height =
    selected_day_panel ~width_of ~width:detail_width ~height t
      (sample_detail ~width_of ~width:detail_width env t samples)
  in
  if is_detail && detail_height = 0 then detail ~height
  else
    let chart_height = height - lower_height in
    let chart =
      let title =
        "Trend"
        ^ (if is_detail then "" else " [active]")
        ^ if width >= 38 then " • " ^ Trend.graph_style_label t.trend.graph_style else ""
      in
      let history_capacity = max 0 (history_height - 4) in
      let start = max 0 (selected_idx - max 0 (history_capacity - 1)) in
      let position =
        Printf.sprintf "%d/%d%s"
          (if count = 0 then 0 else selected_idx + 1)
          count
          (if history_capacity = 0 then " • list hidden"
           else
             (if start > 0 then " ↑" else "")
             ^ if start + history_capacity < count then " ↓" else "")
      in
      Trend.render_chart
        ~width:(max 0 (width - 2))
        ~height:(Panel.capacity ~height:chart_height ~heading:false)
        ~width_of ~book:env.book ~today:env.today ~measure:env.measure ~samples
        ~selected_index:selected_idx ~graph_style:t.trend.graph_style
      |> List.map (fun (style, text) ->
          ((if is_detail && style = O.Active then O.Plain else style), text))
      |> panel ~width_of ~width ~height:chart_height ~focused:(not is_detail) ~title
           ~bottom:position
    in
    let history =
      Trend.render_history
        ~width:(max 0 (history_width - 2))
        ~height:(Panel.capacity ~height:history_height ~heading:false)
        ~width_of ~book:env.book ~today:env.today ~measure:env.measure ~samples
        ~selected_index:selected_idx ~detail_focused:is_detail
      |> panel ~width_of ~width:history_width ~height:history_height ~focused:(not is_detail)
           ~title:"History"
           ~bottom:(Printf.sprintf "%d/%d" (if count = 0 then 0 else selected_idx + 1) count)
    in
    let lower =
      if wide then
        List.map2
          (fun (left_style, left_text) (right_style, right_text) ->
            (O.Columns (history_width, left_style, right_style), left_text ^ " " ^ right_text))
          history (detail ~height:detail_height)
      else history @ if detail_height = 0 then [] else detail ~height:detail_height
    in
    chart @ lower

(* Without a qualified pool and period: the cause, and its details on i. *)
let unavailable_rows env t ~width_of ~width ~height why =
  if t.pane = Detail_pane then
    selected_day_panel ~width_of ~width ~height t
      (List.concat_map (O.wrap_text ~width_of (max 1 (width - 2))) (detail_lines env)
      |> List.map (fun text -> (O.Plain, text)))
  else
    List.concat_map
      (O.wrap_text ~width_of (max 1 (width - 2)))
      [
        tr "Daily Pace unavailable:";
        why;
        "Supply an explicit daily-pace.tsv pool and boundary-presets.tsv period.";
      ]
    |> List.map (fun text -> (O.Chrome, text))
    |> panel ~width_of ~width ~height ~focused:true ~title:"Trend [active]" ~bottom:"i for details"

let rows (env : Screen.env) (geometry : Screen.geometry) t ~today_pace ~history =
  let width, body_height = geometry.content and width_of = geometry.width_of in
  let context = context_rows env t ~today_pace ~history ~width ~width_of ~body_height in
  let height = max 0 (body_height - List.length context) in
  context
  @
  match Lazy.force history with
  | Ok (_, _, samples) -> trend_rows env geometry t ~height samples
  | Error why -> unavailable_rows env t ~width_of ~width ~height why

let footer (geometry : Screen.geometry) t =
  let narrow = fst geometry.content < 79 in
  match (t.overlay, t.pane) with
  | Target _, _ ->
      [ "[Tab] field [j/k] horizon [Esc/q] back"; "Read-only plan; nothing is recorded" ]
  | Why _, _ -> [ "[j/k] scroll [Esc/q/?] back"; "Terms of today's answer; nothing is recorded" ]
  | What_if _, _ -> [ "[Esc/q] close"; "Read-only scenario; nothing is recorded" ]
  | Pool picker, _ ->
      if Pool.reviewing picker then
        [ "Enter save  Esc/e edit"; "Edits only daily-pace.tsv; the whole review must fit" ]
      else [ "j/k select  Space toggle  Enter review  Esc cancel"; "Edits only daily-pace.tsv" ]
  | Cycle _, _ ->
      [ "Enter review  Tab switch field  Esc cancel"; "Edits only boundary-presets.tsv" ]
  | Cycle_review _, _ ->
      [ "Enter save  Tab choose Edit  Esc edit"; "Full boundaries must fit before saving" ]
  | No_overlay, Trend_pane ->
      if narrow then
        [ "[h/l] day [v] view [i] info [q] back"; "[1-5] period [C-u/d] page [Home/End] ends" ]
      else
        [
          "[h/l] day [v] view [i/Enter] details [q] back";
          "[1-5] period [C-u/d] page [Home/End] ends";
        ]
  | No_overlay, Detail_pane ->
      [ "[j/k] scroll [v] view [i/q] trend [h/l] day"; "[1-5] period [C-u/d] page [Home/End] ends" ]

let view env (geometry : Screen.geometry) t =
  (* Today's pace and the trend samples are computed once for the whole view, and
     only when painted: the Shell asks for the view again for its footer and cursor. *)
  let today_pace = lazy (current_pace env) and history = lazy (samples env t) in
  let pace = lazy (Result.map (fun (pace, _, _) -> pace) (Lazy.force today_pace)) in
  let overlay =
    match t.overlay with
    | Target target ->
        Target.frame ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body
          ~book:env.Screen.book ~pace:(Lazy.force pace) target
    | Pool picker ->
        let width, height = geometry.body in
        Pool.rows ~width_of:geometry.width_of ~width ~height picker
        |> List.filteri (fun i _ -> i < height)
        |> (fun rows ->
        rows @ List.init (max 0 (height - List.length rows)) (fun _ -> (O.Plain, "")))
        |> List.map (fun (style, text) -> (style, O.pad ~width_of:geometry.width_of width text))
        |> Ui_overlay.centered ~width_of:geometry.width_of ~screen:geometry.screen
             ~body:geometry.body ~pane_width:width ~caret:`None
    | What_if what_if ->
        What_if.frame ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body
          ~book:env.Screen.book ~measure:env.Screen.measure ~pace:(Lazy.force pace) what_if
    | Why why ->
        Why.frame ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body
          ~book:env.Screen.book ~pace:(Lazy.force pace) why
    | _ ->
        Option.bind (form t)
          (Ui_overlay.form ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body)
  in
  {
    Screen.title = tr "Daily Pace / Trend" ^ " • " ^ Trend.preset_label t.trend.preset;
    (* The Workspace layout paints no subtitle; today's summary is a context row. *)
    subtitle = Hidden;
    rows = lazy (rows env geometry t ~today_pace ~history);
    footer = footer geometry t;
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
