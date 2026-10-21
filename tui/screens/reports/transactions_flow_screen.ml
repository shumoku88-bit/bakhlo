(* Transactions Flow: per-coordinate gross movement of an explicit period, the
   selected row's transactions and a print preview. One full-width body when the
   terminal is narrow; the detail pane appears only from 100 columns. The shared
   frame is immutable: handlers clamp against the same pure row count the
   renderer uses. *)
module IncExp = Income_expense_report
module Flow = Transactions_flow_report
module P = Report_period
module Frame = Report_frame
module O = Daily_overlays

type t = {
  report : Flow.t;
  detail_frame : Frame.t; (* detail pane scroll *)
  detail : bool;
  help : Ui_form.t option;
  preview : Ui_form.t option;
}

let config_files = [ P.boundary_file ]

let create () =
  { report = Flow.initial (); detail_frame = Frame.create; detail = false; help = None; preview = None }

let enter t =
  { t with detail_frame = Frame.create; detail = false; help = None; preview = None }

let modal t = Option.is_some t.preview || Option.is_some t.help
let form t = match t.preview with Some f -> Some f | None -> t.help
let preset t = t.report.preset
let selected_row t = t.report.selected_row
let detail_focused t = t.detail
let scroll t = t.detail_frame.Frame.scroll
let saved _env _geometry _result t = (t, Screen.Stay)

let help_form () =
  Frame.help_form ~title:"Transactions Flow / Help"
    [
      "What it answers";
      "  Which exact coordinates moved in this window, and what did they carry?";
      "  Zero-net circulation stays visible through gross activity.";
      "";
      "Reading the table";
      "  Net = inflows + outflows; Gross = |inflow| + |outflow|.";
      "  Rows are sorted by gross quantity, not by importance.";
      "  Zero cells are omitted; a missing coordinate had no movement.";
      "";
      "Keys";
      "  j/k or arrows: select a coordinate";
      "  PgUp/PgDn or Ctrl-U/D: page the selection; Home/End/g/G: first/last";
      "  Enter or Tab: open/leave the detail (full width below 100 columns)";
      "  1-5, [ / ]: period; p: print preview; ?: this help; Esc/q: Home";
    ]

let period_of (env : Screen.env) t = P.checked env t.report.preset t.report.period_offset

let report_of (env : Screen.env) t = Result.map (fun period -> Flow.compute_report ~book:env.book ~period) (period_of env t)

let coordinate_count (env : Screen.env) t =
  match report_of env t with Ok rep -> List.length rep.rows | Error _ -> 0

let selected (env : Screen.env) t =
  Frame.clamp_index ~count:(coordinate_count env t) t.report.selected_row

(* Detail lines at the width the detail actually gets, so the handler's clamp
   and the renderer agree. *)
let detail_width (geometry : Screen.geometry) =
  let width, _ = geometry.Screen.content in
  if width >= 100 then
    let left_width = max 60 (min (width * 2 / 3) (width - 36)) in
    width - left_width - 1
  else width

let detail_lines (env : Screen.env) (geometry : Screen.geometry) t =
  match report_of env t with
  | Error _ -> []
  | Ok rep ->
      List.concat_map
        (O.wrap_text ~width_of:geometry.width_of (max 1 (detail_width geometry - 4)))
        (List.map snd (Flow.render_detail_lines ~book:env.book ~report:rep ~selected_row:(selected env t)))

let detail_count (env : Screen.env) geometry t = List.length (detail_lines env geometry t)

let handle (env : Screen.env) geometry t input =
  let stay t = (t, Screen.Stay) in
  let count = coordinate_count env t in
  let select delta =
    let next = Frame.clamp_index ~count:count (t.report.selected_row + delta) in
    stay { t with report = { t.report with selected_row = next } }
  in
  let period preset offset =
    stay
      {
        t with
        report = { t.report with preset; period_offset = offset; selected_row = 0 };
        detail_frame = Frame.create;
        detail = false;
      }
  in
  let print () =
    match period_of env t with
    | Error why -> (t, Screen.Message why)
    | Ok period_value ->
        let rep = Flow.compute_report ~book:env.book ~period:period_value in
        let lines = Flow.print_summary ~book:env.book ~report:rep in
        stay
          {
            t with
            preview =
              Some
                (P.print_form ~id:"transactions_flow_print_preview"
                   ~title:"Transactions Flow / Print Preview" lines);
          }
  in
  match t.preview with
  | Some form -> stay { t with preview = P.handle_preview form input }
  | None -> (
      match t.help with
      | Some form -> (
          match input with
          | `Key (`ASCII '?', []) -> stay { t with help = None }
          | _ -> stay { t with help = P.handle_preview form input })
      | None ->
          let leave_detail = stay { t with detail = false; detail_frame = Frame.create } in
          if t.detail then
            match
              Frame.handle ~count:(detail_count env geometry t) ~capacity:(Frame.capacity geometry)
                t.detail_frame input
            with
            | Some detail_frame -> stay { t with detail_frame }
            | None -> (
                match P.lowercase input with
                | Some ((`Escape | `ASCII 'q' | `ASCII 'i' | `Tab | `Enter), _) -> leave_detail
                | Some (`ASCII '?', []) -> stay { t with help = Some (help_form ()) }
                | Some (`ASCII 'p', []) -> print ()
                | Some (`ASCII ('1' .. '5' as c), []) -> period (P.preset_of_key c) 0
                | Some (`ASCII (('[' | ']') as c), []) ->
                    period t.report.preset (t.report.period_offset + if c = '[' then -1 else 1)
                | _ -> (t, Screen.Ignored))
          else
            match P.lowercase input with
            | Some ((`Escape | `ASCII 'q'), []) -> (t, Screen.Home)
            | Some (`ASCII '?', []) -> stay { t with help = Some (help_form ()) }
            | Some (`ASCII 'p', []) -> print ()
            | Some (`ASCII ('1' .. '5' as c), []) -> period (P.preset_of_key c) 0
            | Some (`ASCII (('[' | ']') as c), []) ->
                period t.report.preset (t.report.period_offset + if c = '[' then -1 else 1)
            | Some ((`ASCII 'j' | `Arrow `Down), []) -> select 1
            | Some ((`ASCII 'k' | `Arrow `Up), []) -> select (-1)
            | Some (`Page `Down, []) | Some (`ASCII 'd', [ `Ctrl ]) ->
                select (max 1 (Frame.capacity geometry - 1))
            | Some (`Page `Up, []) | Some (`ASCII 'u', [ `Ctrl ]) ->
                select (-(max 1 (Frame.capacity geometry - 1)))
            | Some (`Home, []) | Some (`ASCII 'g', []) ->
                stay { t with report = { t.report with selected_row = 0 } }
            | Some (`End, []) | Some (`ASCII 'G', []) ->
                stay { t with report = { t.report with selected_row = Frame.clamp_index ~count:count max_int } }
            | Some ((`Enter | `ASCII 'i' | `Tab), _) ->
                stay { t with detail = true; detail_frame = Frame.create }
            | _ -> (t, Screen.Ignored))

let table ~geometry ~width ~title ~count ~selected rows =
  let capacity = Frame.capacity geometry in
  let header = List.length rows - count in
  let visible = max 1 (capacity - header) in
  let start = if selected < visible then 0 else selected + 1 - visible in
  let head = List.filteri (fun i _ -> i < header) rows in
  let body = List.filteri (fun i _ -> i >= header + start && i < header + start + visible) rows in
  let position = Frame.position ~count ~capacity { Frame.scroll = start } in
  let height = snd geometry.Screen.content in
  Ui_panel.frame_rows ~inset:0 ~bottom_label:position ~width_of:geometry.width_of ~width ~height
    ~focused:true ~title
    (List.map (fun (style, text) -> (style, " " ^ text)) (head @ body))

let rows (env : Screen.env) (geometry : Screen.geometry) t =
  let width, _ = geometry.content in
  let width_of = geometry.width_of in
  let wide = width >= 100 in
  match report_of env t with
  | Error why ->
      Frame.block ~geometry ~title:"Transactions Flow · Period Unavailable"
        [
          (O.Heading, Ui_text.tr "Report period unavailable:");
          (O.Plain, why);
          (O.Chrome, "Supply an explicit boundary-presets.tsv or choose Month / Year.");
        ]
  | Ok rep ->
      let count = List.length rep.rows in
      let selected = Frame.clamp_index ~count:count t.report.selected_row in
      let title =
        Printf.sprintf "Transactions Flow • %s" (IncExp.preset_label t.report.preset)
      in
      let left_width = max 60 (min (width * 2 / 3) (width - 36)) in
      let table_rows width =
        Flow.render_summary_lines ~width:(max 0 (width - 4)) ~width_of ~book:env.book ~report:rep
          ~selected_row:selected
      in
      let detail_rows = List.map (fun text -> (O.Plain, text)) (detail_lines env geometry t) in
      if wide then
        let right_width = width - left_width - 1 in
        let left = table ~geometry ~width:left_width ~title ~count ~selected (table_rows left_width) in
        let right_geometry : Screen.geometry =
          { geometry with Screen.content = (right_width, snd geometry.content) }
        in
        let right =
          Frame.body ~geometry:right_geometry ~count:(List.length detail_rows)
            ~title:"Flow Detail & Transactions" t.detail_frame detail_rows
        in
        List.map2
          (fun (ls, lt) (rs, rt) -> (O.Columns (left_width, ls, rs), lt ^ " " ^ rt))
          left right
      else if t.detail then
        Frame.body ~geometry ~count:(List.length detail_rows) ~title:(title ^ " · Detail")
          t.detail_frame detail_rows
      else table ~geometry ~width ~title ~count ~selected (table_rows width)

let view env geometry t =
  let overlay = match t.preview with Some _ -> t.preview | None -> t.help in
  let footer =
    if Option.is_some t.help then Frame.help_footer
    else if t.detail then
      [
        "j/k line  PgUp/PgDn page  Home/End ends  g/G top/bottom  ? help";
        "Esc/Tab table  p print  q Home";
      ]
    else
      [
        "j/k row  PgUp/PgDn page  Home/End ends  g/G first/last  ? help";
        "Enter/Tab detail  1-5 period  [ / ] shift  p print  q/Esc Home";
      ]
  in
  P.view_of ~title:"Transactions Flow" ~geometry
    ~rows:(lazy (rows env geometry t))
    overlay ~footer
