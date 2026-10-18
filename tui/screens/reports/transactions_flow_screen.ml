(* Transactions Flow: per-coordinate gross movement of an explicit period, the
   selected row's transactions and a print preview. *)
module IncExp = Income_expense_report
module Flow = Transactions_flow_report
module P = Report_period

type t = { report : Flow.t; pane : P.pane; scroll : int; preview : Ui_form.t option }

let config_files = [ P.boundary_file ]
let create () = { report = Flow.initial (); pane = P.Report; scroll = 0; preview = None }
let enter t = { t with pane = P.Report; scroll = 0; preview = None }
let modal t = Option.is_some t.preview
let form t = t.preview
let preset t = t.report.preset
let selected_row t = t.report.selected_row
let detail_focused t = t.pane = P.Detail
let saved _env _geometry _result t = (t, Screen.Stay)

let handle (env : Screen.env) geometry t input =
  let stay t = (t, Screen.Stay) in
  let select row = stay { t with report = { t.report with selected_row = row }; scroll = 0 } in
  let detail = t.pane = P.Detail in
  match t.preview with
  | Some form -> stay { t with preview = P.handle_preview form input }
  | None -> (
      match P.lowercase input with
      | Some ((`Escape | `ASCII 'q'), []) ->
          if detail then stay { t with pane = P.Report; scroll = 0 } else (t, Screen.Home)
      | Some (`ASCII ('1' .. '5' as c), []) ->
          stay { t with report = { t.report with preset = P.preset_of_key c; period_offset = 0;
                                                 selected_row = 0 }; scroll = 0 }
      | Some (`ASCII (('[' | ']') as c), []) ->
          let delta = if c = '[' then -1 else 1 in
          stay { t with report = { t.report with period_offset = t.report.period_offset + delta;
                                                 selected_row = 0 }; scroll = 0 }
      | Some (`ASCII 'p', []) -> (
          match P.checked env t.report.preset t.report.period_offset with
          | Error why -> (t, Screen.Message why)
          | Ok period ->
              let lines = Flow.print_summary ~book:env.book
                  ~report:(Flow.compute_report ~book:env.book ~period) in
              stay { t with preview = Some (P.print_form ~id:"transactions_flow_print_preview"
                  ~title:"Transactions Flow / Print Preview" lines) })
      | Some ((`Enter | `ASCII 'i' | `Tab | `ASCII 'w'), []) | Some (`Tab, [ `Shift ]) ->
          stay { t with pane = (if detail then P.Report else P.Detail); scroll = 0 }
      | Some (((`ASCII ('j' | 'k') | `Arrow (`Up | `Down)) as k), []) ->
          let delta = match k with `ASCII 'k' | `Arrow `Up -> -1 | _ -> 1 in
          if detail then stay { t with scroll = max 0 (t.scroll + delta) }
          else select (max 0 (t.report.selected_row + delta))
      | key when Option.is_some (P.page_delta key) ->
          let step = Option.get (P.page_delta key) * P.page_step geometry in
          if detail then stay { t with scroll = max 0 (t.scroll + step) }
          else select (max 0 (t.report.selected_row + step))
      | Some (`Home, []) -> if detail then stay { t with scroll = 0 } else select 0
      | Some (`End, []) ->
          if detail then stay { t with scroll = max_int / 4 } else select (max_int / 4)
      | _ -> (t, Screen.Ignored))

let rows (env : Screen.env) (geometry : Screen.geometry) t =
  let width, _ = geometry.content in
  let width_of = geometry.width_of in
  let left_width, right_width = Ui_panel.split_widths width in
  match P.checked env t.report.preset t.report.period_offset with
  | Ok period ->
      let rep = Flow.compute_report ~book:env.book ~period in
      let selected_row = min (max 0 (List.length rep.rows - 1)) t.report.selected_row in
      let left_rows = List.map snd (Flow.render_summary_lines ~width:(max 0 (left_width - 4))
          ~width_of ~book:env.book ~report:rep ~selected_row) in
      let detail_rows = List.map snd (Flow.render_detail_lines ~width:(max 0 (right_width - 6))
          ~width_of ~book:env.book ~report:rep ~selected_row) in
      P.split ~geometry ~pane:t.pane ~scroll:t.scroll
        ~left_title:(Printf.sprintf "Transactions Flow • %s" (IncExp.preset_label t.report.preset))
        ~left_rows ~right_title:"Flow Detail & Transactions"
        ~right_rows:(List.concat_map (Daily_overlays.wrap_text ~width_of (max 1 (right_width - 6))) detail_rows)
  | Error why ->
      P.unavailable ~geometry ~pane:t.pane ~left_title:"Transactions Flow" ~right_title:"Period Unavailable"
        [ Ui_text.tr "Report period unavailable:"; why;
          "Supply an explicit boundary-presets.tsv or choose Month / Year." ] why

let view env geometry t =
  P.view_of ~title:"Transactions Flow" ~geometry ~rows:(lazy (rows env geometry t)) t.preview
    ~footer:(match t.pane with
      | P.Report -> [ "1-5 period  [ / ] shift  j/k row  p print  Tab detail  r Record"; "Space Commands  q/Esc Home  Ctrl-r reload" ]
      | P.Detail -> [ "j/k scroll  Tab report  p print  q/Esc back to report  r Record"; "Space Commands  Ctrl-r reload" ])
