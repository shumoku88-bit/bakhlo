(* Stock–Flow: reconstructed start/end stock of the explicitly tracked
   balance-view coordinates and the period flows between them. One full-width
   body on the shared report frame; principles live in the [?] help overlay. *)
module IncExp = Income_expense_report
module StockFlow = Stock_flow_report
module P = Report_period
module Frame = Report_frame
module O = Daily_overlays
module Roles = Locus_roles

type t = {
  report : StockFlow.t;
  frame : Frame.t;
  help : Ui_form.t option;
  preview : Ui_form.t option;
}

let balance_view_file = "balance-view.tsv"
let config_files = [ P.boundary_file; balance_view_file ]
let create () = { report = StockFlow.initial (); frame = Frame.create; help = None; preview = None }
let enter t = { t with frame = Frame.create; help = None; preview = None }
let modal t = Option.is_some t.preview || Option.is_some t.help
let form t = match t.preview with Some f -> Some f | None -> t.help
let preset t = t.report.preset
let scroll t = t.frame.Frame.scroll
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
  (* The debt section needs the roles: an unreadable file is a refusal that names
     it, never a silently empty section. *)
  let liability_coords tracked_measure =
    match Lazy.force env.accounting_roles with
    | Ok roles ->
        Ok
          (List.filter_map
             (fun (locus, role) ->
               if role = Roles.Liability then Some (locus, tracked_measure) else None)
             roles)
    | Error why -> Error ("Accounting roles unavailable (accounting-roles.tsv): " ^ why)
  in
  Result.bind (env.config balance_view_file) (function
    | None -> Error "Stock–Flow requires an explicit balance-view.tsv selection."
    | Some text ->
        Result.bind (parse_selection text) (fun tracked_coords ->
            match tracked_coords with
            | [] -> Error "Stock–Flow requires a nonempty balance-view.tsv selection."
            | (_, measure) :: _ ->
                Result.bind (liability_coords measure) (fun liability_coords ->
                    Result.bind (P.checked env t.report.preset t.report.period_offset)
                      (fun period ->
                        StockFlow.compute_report ~book:env.book ~measure ~tracked_coords
                          ~liability_coords ~period))))

let help_form () =
  Frame.help_form ~title:"Stock–Flow / Help"
    [
      "What it answers";
      "  Why did the tracked balance change between two boundaries?";
      "";
      "Principles";
      "  - A coordinate is reconstructed on one supported route: zero-origin,";
      "    bounded history (the same rule as Daily Pace) or an opening entry.";
      "    An opening entry makes the balance exact from its own day; a window";
      "    starting on that day has an unknown start (—), never as zero.";
      "  - An observation is exact only at its confirmation: the balance before";
      "    it is not derivable, so its window boundaries stay unknown.";
      "  - A window that starts before a coordinate's bounded start shows that";
      "    start as unknown (—), never as zero.";
      "  - Coordinates without support are listed with their state instead of";
      "    rejecting the whole report.";
      "  - Boundary values are reconstructed from current accepted evidence, not";
      "    from archived balance snapshots.";
      "  - Increases/decreases are tracked-balance motion, not income or spending.";
      "  - Liability coordinates keep their remaining end balance, so cycle-to-cycle";
      "    debt payoff is visible; one Measure at a time is never summed with another.";
      "";
      "Keys";
      "  1-5: Month, Cycle, Previous Cycle, Year, All Time";
      "  [ / ]: shift the period back / forward";
      "  j/k or arrows: line; PgUp/PgDn or Ctrl-U/D: page; Home/End/g/G: ends";
      "  p: print preview   ?: this help   Esc/q: Home";
    ]

let content (env : Screen.env) (geometry : Screen.geometry) t =
  let width, _ = geometry.content in
  let width_of = geometry.width_of in
  match result env t with
  | Ok rep ->
      Frame.Body
        ( Printf.sprintf "Stock–Flow • %s (%s)" (IncExp.preset_label t.report.preset) rep.measure,
          StockFlow.render_summary_lines
            ~width:(max 0 (width - 4))
            ~width_of ~book:env.book ~report:rep )
  | Error why ->
      let remedy =
        if Base.String.is_substring why ~substring:"Historical start unsupported" then
          "This coordinate has no admitted zero-origin support, so a reconstructed start is not \
           justified. Add support outside the TUI or choose other tracked coordinates."
        else "Review balance-view.tsv and boundary-presets.tsv."
      in
      let wrap style text =
        List.map (fun line -> (style, line)) (O.wrap_text ~width_of (max 1 (width - 6)) text)
      in
      Frame.Block
        ( "Stock–Flow · Unavailable",
          ((O.Heading, Ui_text.tr "Stock–Flow unavailable:") :: wrap O.Plain why)
          @ wrap O.Chrome remedy )

let handle (env : Screen.env) geometry t input =
  let stay t = (t, Screen.Stay) in
  let capacity = Frame.capacity geometry in
  match P.handle_overlays ~preview:t.preview ~help:t.help input with
  | Some (preview, help) -> stay { t with preview; help }
  | None -> (
      match Frame.handle ~count:(Frame.count (content env geometry t)) ~capacity t.frame input with
      | Some frame -> stay { t with frame }
      | None -> (
          let reset = Frame.create in
          match P.lowercase input with
          | Some ((`Escape | `ASCII 'q'), []) -> (t, Screen.Home)
          | Some (`ASCII '?', []) -> stay { t with help = Some (help_form ()) }
          | Some (`ASCII ('1' .. '5' as c), []) ->
              stay
                { t with frame = reset; report = { preset = P.preset_of_key c; period_offset = 0 } }
          | Some (`ASCII (('[' | ']') as c), []) ->
              let delta = if c = '[' then -1 else 1 in
              stay
                {
                  t with
                  frame = reset;
                  report = { t.report with period_offset = t.report.period_offset + delta };
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
          | _ -> (t, Screen.Ignored)))

let rows env geometry t = Frame.rows ~geometry t.frame (content env geometry t)

let view env geometry t =
  let overlay = match t.preview with Some _ -> t.preview | None -> t.help in
  P.view_of ~title:"Stock–Flow" ~geometry
    ~rows:(lazy (rows env geometry t))
    overlay
    ~footer:
      (if Option.is_some t.help then Frame.help_footer
       else
         [
           "j/k line  PgUp/PgDn page  Home/End ends  g/G top/bottom  ? help";
           "1-5 period  [ / ] shift  p print  q/Esc Home";
         ])
