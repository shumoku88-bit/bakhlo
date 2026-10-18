(* Income & Expense: role totals of an explicit period, formulas and print preview. *)
module IncExp = Income_expense_report
module P = Report_period

type t = { report : IncExp.t; pane : P.pane; scroll : int; preview : Ui_form.t option }

let config_files = [ P.boundary_file ]
let create () = { report = IncExp.initial (); pane = P.Report; scroll = 0; preview = None }
let enter t = { t with pane = P.Report; scroll = 0; preview = None }
let modal t = Option.is_some t.preview
let form t = t.preview
let preset t = t.report.preset
let detail_focused t = t.pane = P.Detail
let saved _env _geometry _result t = (t, Screen.Stay)

let report (env : Screen.env) period =
  IncExp.compute_report ~book:env.book ~roles:(Lazy.force env.accounting_roles) ~period

let handle (env : Screen.env) geometry t input =
  let stay t = (t, Screen.Stay) in
  match t.preview with
  | Some form -> stay { t with preview = P.handle_preview form input }
  | None -> (
      match P.lowercase input with
      | Some ((`Escape | `ASCII 'q'), []) ->
          if t.pane = P.Detail then stay { t with pane = P.Report; scroll = 0 } else (t, Screen.Home)
      | Some (`ASCII ('1' .. '5' as c), []) ->
          stay { t with report = { t.report with preset = P.preset_of_key c; period_offset = 0 }; scroll = 0 }
      | Some (`ASCII (('[' | ']') as c), []) ->
          let delta = if c = '[' then -1 else 1 in
          stay { t with report = { t.report with period_offset = t.report.period_offset + delta }; scroll = 0 }
      | Some (`ASCII 'p', []) -> (
          match P.checked env t.report.preset t.report.period_offset with
          | Error why -> (t, Screen.Message why)
          | Ok period ->
              let lines = IncExp.print_summary ~book:env.book ~report:(report env period) in
              stay { t with preview = Some (P.print_form ~id:"income_expense_print_preview"
                  ~title:"Income & Expense / Print Preview" lines) })
      | Some ((`Enter | `ASCII 'i' | `Tab | `ASCII 'w'), []) | Some (`Tab, [ `Shift ]) ->
          stay { t with pane = (if t.pane = P.Report then P.Detail else P.Report); scroll = 0 }
      | Some (((`ASCII ('j' | 'k') | `Arrow (`Up | `Down)) as k), []) ->
          let delta = match k with `ASCII 'k' | `Arrow `Up -> -1 | _ -> 1 in
          stay { t with scroll = (if t.pane = P.Detail then max 0 (t.scroll + delta) else 0) }
      | key when Option.is_some (P.page_delta key) ->
          let delta = Option.get (P.page_delta key) in
          stay { t with scroll = max 0 (t.scroll + delta * P.page_step geometry) }
      | Some (`Home, []) -> stay { t with scroll = 0 }
      | Some (`End, []) -> stay { t with scroll = max_int / 4 }
      | _ -> (t, Screen.Ignored))

let rows (env : Screen.env) (geometry : Screen.geometry) t =
  let width, _ = geometry.content in
  let width_of = geometry.width_of in
  let left_width, right_width = Ui_panel.split_widths width in
  match P.checked env t.report.preset t.report.period_offset with
  | Ok period ->
      let rep = report env period in
      let left_rows = List.map snd (IncExp.render_report_lines ~width:(max 0 (left_width - 4))
          ~width_of ~book:env.book ~report:rep) in
      let detail_rows = List.map snd (IncExp.render_detail_lines ~width:(max 0 (right_width - 6))
          ~width_of ~book:env.book ~report:rep ~selected_row:0) in
      P.split ~geometry ~pane:t.pane ~scroll:t.scroll
        ~left_title:(Printf.sprintf "Income & Expense • %s" (IncExp.preset_label t.report.preset))
        ~left_rows ~right_title:"Report Details & Formulas"
        ~right_rows:(List.concat_map (Daily_overlays.wrap_text ~width_of (max 1 (right_width - 6))) detail_rows)
  | Error why ->
      P.unavailable ~geometry ~pane:t.pane ~left_title:"Income & Expense" ~right_title:"Period Unavailable"
        [ Ui_text.tr "Report period unavailable:"; why;
          "Supply an explicit boundary-presets.tsv or choose Month / Year." ] why

let view env geometry t =
  P.view_of ~title:"Income & Expense" ~geometry ~rows:(lazy (rows env geometry t)) t.preview
    ~footer:(match t.pane with
      | P.Report -> [ "1-5 period  [ / ] shift  p print  Tab detail  r Record"; "Space Commands  q/Esc Home  Ctrl-r reload" ]
      | P.Detail -> [ "j/k scroll  Tab report  p print  q/Esc back to report  r Record"; "Space Commands  Ctrl-r reload" ])
