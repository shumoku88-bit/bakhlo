(* Stock–Flow: reconstructed start/end stock of the explicitly tracked
   balance-view coordinates and the period flows between them. *)
module IncExp = Income_expense_report
module StockFlow = Stock_flow_report
module P = Report_period

type t = { report : StockFlow.t; pane : P.pane; scroll : int; preview : Ui_form.t option }

let balance_view_file = "balance-view.tsv"
let config_files = [ P.boundary_file; balance_view_file ]
let create () = { report = StockFlow.initial (); pane = P.Report; scroll = 0; preview = None }
let enter t = { t with pane = P.Report; scroll = 0; preview = None }
let modal t = Option.is_some t.preview
let form t = t.preview
let preset t = t.report.preset
let detail_focused t = t.pane = P.Detail
let saved _env _geometry _result t = (t, Screen.Stay)

let result (env : Screen.env) t =
  let parse_selection text =
    let valid_token s =
      s <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) s
    in
    let rec rows acc = function
      | [] -> Ok (List.rev acc)
      | raw :: rest -> (
          let line = String.trim raw in
          if line = "" || String.starts_with ~prefix:"#" line || String.starts_with ~prefix:";" line
          then rows acc rest
          else
            match String.split_on_char '\t' line with
            | [ locus; measure ] when valid_token locus && valid_token measure ->
                rows ((locus, measure) :: acc) rest
            | _ -> Error "Invalid balance-view.tsv; no partial selection used.")
    in
    rows [] (String.split_on_char '\n' text)
  in
  Result.bind (env.config balance_view_file) (function
    | None -> Error "Stock–Flow requires an explicit balance-view.tsv selection."
    | Some text ->
        Result.bind (parse_selection text) (fun tracked_coords ->
            match tracked_coords with
            | [] -> Error "Stock–Flow requires a nonempty balance-view.tsv selection."
            | (_, measure) :: _ ->
                Result.bind (P.checked env t.report.preset t.report.period_offset) (fun period ->
                    StockFlow.compute_report ~book:env.book ~measure ~tracked_coords ~period)))

let handle (env : Screen.env) geometry t input =
  let stay t = (t, Screen.Stay) in
  let detail = t.pane = P.Detail in
  match t.preview with
  | Some form -> stay { t with preview = P.handle_preview form input }
  | None -> (
      match P.lowercase input with
      | Some ((`Escape | `ASCII 'q'), []) ->
          if detail then stay { t with pane = P.Report; scroll = 0 } else (t, Screen.Home)
      | Some (`ASCII ('1' .. '5' as c), []) ->
          stay { t with report = { preset = P.preset_of_key c; period_offset = 0 }; scroll = 0 }
      | Some (`ASCII (('[' | ']') as c), []) ->
          let delta = if c = '[' then -1 else 1 in
          stay
            {
              t with
              report = { t.report with period_offset = t.report.period_offset + delta };
              scroll = 0;
            }
      | Some (`ASCII 'p', []) -> (
          match result env t with
          | Ok rep ->
              let lines = StockFlow.print_summary ~book:env.book ~report:rep in
              stay
                {
                  t with
                  preview =
                    Some
                      (P.print_form ~id:"stock_flow_print_preview"
                         ~title:"Stock–Flow / Print Preview" lines);
                }
          | Error why -> (t, Screen.Message why))
      | Some ((`Enter | `ASCII 'i' | `Tab | `ASCII 'w'), []) | Some (`Tab, [ `Shift ]) ->
          stay { t with pane = (if detail then P.Report else P.Detail); scroll = 0 }
      | Some (((`ASCII ('j' | 'k') | `Arrow (`Up | `Down)) as k), []) ->
          let delta = match k with `ASCII 'k' | `Arrow `Up -> -1 | _ -> 1 in
          stay
            {
              t with
              scroll =
                (if detail then max 0 (t.scroll + delta)
                 else Ui_panel.move ~last:max_int ~position:t.scroll delta);
            }
      | key when Option.is_some (P.page_delta key) ->
          stay
            {
              t with
              scroll = max 0 (t.scroll + (Option.get (P.page_delta key) * P.page_step geometry));
            }
      | Some (`Home, []) -> stay { t with scroll = 0 }
      | Some (`End, []) -> stay { t with scroll = max_int / 4 }
      | _ -> (t, Screen.Ignored))

let rows (env : Screen.env) (geometry : Screen.geometry) t =
  let width, _ = geometry.content in
  let width_of = geometry.width_of in
  let left_width, right_width = Ui_panel.split_widths width in
  match result env t with
  | Ok rep ->
      let left_rows =
        List.map snd
          (StockFlow.render_summary_lines
             ~width:(max 0 (left_width - 4))
             ~width_of ~book:env.book ~report:rep)
      in
      let detail_rows =
        List.map snd
          (StockFlow.render_detail_lines
             ~width:(max 0 (right_width - 6))
             ~width_of ~book:env.book ~report:rep)
      in
      P.split ~geometry ~pane:t.pane ~scroll:t.scroll
        ~left_title:
          (Printf.sprintf "Stock–Flow • %s (%s)" (IncExp.preset_label t.report.preset) rep.measure)
        ~left_rows ~right_title:"Principles & Evidence"
        ~right_rows:
          (List.concat_map
             (Daily_overlays.wrap_text ~width_of (max 1 (right_width - 6)))
             detail_rows)
  | Error why ->
      P.unavailable ~geometry ~pane:t.pane ~left_title:"Stock–Flow"
        ~right_title:"Stock–Flow Unavailable"
        [
          Ui_text.tr "Stock–Flow unavailable:";
          why;
          "Review balance coordinates and boundary presets.";
        ]
        why

let view env geometry t =
  P.view_of ~title:"Stock–Flow" ~geometry
    ~rows:(lazy (rows env geometry t))
    t.preview
    ~footer:
      (match t.pane with
      | P.Report ->
          [
            "1-5 period  [ / ] shift  p print  Tab detail  r Record";
            "Space Commands  q/Esc Home  Ctrl-r reload";
          ]
      | P.Detail ->
          [
            "j/k scroll  Tab report  p print  q/Esc back to report  r Record";
            "Space Commands  Ctrl-r reload";
          ])
