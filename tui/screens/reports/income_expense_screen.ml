(* Income & Expense: role totals of an explicit period, formulas and print
   preview. The body is the shared full-width report frame; formulas and keys
   live in the [?] help overlay, never in a permanent pane. *)
module IncExp = Income_expense_report
module P = Report_period
module Frame = Report_frame

type t = {
  report : IncExp.t;
  frame : Frame.t;
  help : Ui_form.t option;
  preview : Ui_form.t option;
}

let config_files = [ P.boundary_file ]

let create () =
  { report = IncExp.initial (); frame = Frame.create (); help = None; preview = None }

let enter t = { t with frame = Frame.create (); help = None; preview = None }
let modal t = Option.is_some t.preview || Option.is_some t.help
let form t = match t.preview with Some f -> Some f | None -> t.help
let preset t = t.report.preset
let scroll t = t.frame.Frame.scroll

let saved _env _geometry _result t = (t, Screen.Stay)

(* Roles decide Income and Expense; an unreadable roles file is a refusal, not "no roles". *)
let report (env : Screen.env) period =
  match Lazy.force env.accounting_roles with
  | Ok roles -> Ok (IncExp.compute_report ~book:env.book ~roles ~period)
  | Error why -> Error ("Accounting roles unavailable: " ^ why)

let help_form () =
  Frame.help_form ~title:"Income & Expense / Help"
    [
      "Accounting Formula";
      "  Income  = Sum of negative postings on Income accounts";
      "  Expense = Sum of positive postings on Expense accounts";
      "  Savings = Income - Expense";
      "";
      "Provenance Distinction";
      "  Scheduled bills: paid via Scheduled plan completion";
      "  Ordinary: direct ad-hoc spending";
      "";
      "Keys";
      "  1-5: Month, Cycle, Previous Cycle, Year, All Time";
      "  [ / ]: shift the period back / forward";
      "  j/k or arrows: line; PgUp/PgDn or Ctrl-U/D: page; Home/End/g/G: ends";
      "  p: print preview   ?: this help   Esc/q: Home";
    ]

let handle (env : Screen.env) geometry t input =
  let stay t = (t, Screen.Stay) in
  match t.preview with
  | Some form -> stay { t with preview = P.handle_preview form input }
  | None -> (
      match t.help with
      | Some form -> (
          match input with
          | `Key (`ASCII '?', []) -> stay { t with help = None }
          | _ -> stay { t with help = P.handle_preview form input })
      | None ->
          if Frame.handle ~geometry t.frame input then stay t
          else
            let scrolled () = { t.frame with Frame.scroll = 0 } in
            match P.lowercase input with
            | Some ((`Escape | `ASCII 'q'), []) -> (t, Screen.Home)
            | Some (`ASCII '?', []) -> stay { t with help = Some (help_form ()) }
            | Some (`ASCII ('1' .. '5' as c), []) ->
                stay
                  {
                    t with
                    frame = scrolled ();
                    report = { t.report with preset = P.preset_of_key c; period_offset = 0 };
                  }
            | Some (`ASCII (('[' | ']') as c), []) ->
                let delta = if c = '[' then -1 else 1 in
                stay
                  {
                    t with
                    frame = scrolled ();
                    report = { t.report with period_offset = t.report.period_offset + delta };
                  }
            | Some (`ASCII 'p', []) -> (
                match
                  Result.bind (P.checked env t.report.preset t.report.period_offset) (report env)
                with
                | Error why -> (t, Screen.Message why)
                | Ok rep ->
                    let lines = IncExp.print_summary ~book:env.book ~report:rep in
                    stay
                      {
                        t with
                        preview =
                          Some
                            (P.print_form ~id:"income_expense_print_preview"
                               ~title:"Income & Expense / Print Preview" lines);
                      })
            | _ -> (t, Screen.Ignored))

let rows (env : Screen.env) (geometry : Screen.geometry) t =
  let width, _ = geometry.content in
  let width_of = geometry.width_of in
  match Result.map (report env) (P.checked env t.report.preset t.report.period_offset) with
  | Ok (Error why) ->
      Frame.block ~geometry ~title:"Income & Expense · Accounting Roles Unavailable"
        [
          (Daily_overlays.Heading, Ui_text.tr "Income & Expense unavailable:");
          (Daily_overlays.Plain, why);
          (Daily_overlays.Chrome, "Fix accounting-roles.tsv; no Locus role is guessed.");
        ]
  | Ok (Ok rep) ->
      let body =
        IncExp.render_report_lines ~width:(max 0 (width - 4)) ~width_of ~book:env.book ~report:rep
      in
      Frame.body ~geometry
        ~title:(Printf.sprintf "Income & Expense • %s" (IncExp.preset_label t.report.preset))
        t.frame body
  | Error why ->
      Frame.block ~geometry ~title:"Income & Expense · Period Unavailable"
        [
          (Daily_overlays.Heading, Ui_text.tr "Report period unavailable:");
          (Daily_overlays.Plain, why);
          (Daily_overlays.Chrome, "Supply an explicit boundary-presets.tsv or choose Month / Year.");
        ]

let view env geometry t =
  let overlay = match t.preview with Some _ -> t.preview | None -> t.help in
  P.view_of ~title:"Income & Expense" ~geometry
    ~rows:(lazy (rows env geometry t))
    overlay
    ~footer:
      (if Option.is_some t.help then Frame.help_footer
       else
         [
           "j/k line  PgUp/PgDn page  Home/End ends  g/G top/bottom  ? help";
           "1-5 period  [ / ] shift  p print  q/Esc Home";
         ])
