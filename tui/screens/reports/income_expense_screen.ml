(* Income & Expense as a cycle summary: the configured cycle is the default
   window, totals carry the previous window of the same kind and the exact
   difference, expense rows are sorted by amount with a proportional bar, and
   `c` compares the last windows side by side. One full-width frame; formulas
   and keys live in the [?] help overlay. *)
module IncExp = Income_expense_report
module P = Report_period
module Frame = Report_frame

type t = {
  report : IncExp.t;
  frame : Frame.t;
  compare : bool;
  help : Ui_form.t option;
  preview : Ui_form.t option;
}

let config_files = [ P.boundary_file ]

let create () =
  {
    report = IncExp.initial ();
    frame = Frame.create;
    compare = false;
    help = None;
    preview = None;
  }

let enter t = { t with frame = Frame.create; compare = false; help = None; preview = None }
let modal t = Option.is_some t.preview || Option.is_some t.help
let form t = match t.preview with Some f -> Some f | None -> t.help
let preset t = t.report.preset
let scroll t = t.frame.Frame.scroll
let comparing t = t.compare

let saved _env _geometry _result t = (t, Screen.Stay)

(* Roles decide Income and Expense; an unreadable roles file is a refusal, not "no roles". *)
let report (env : Screen.env) period =
  match Lazy.force env.accounting_roles with
  | Ok roles -> Ok (IncExp.compute_report ~book:env.book ~roles ~period)
  | Error why -> Error ("Accounting roles unavailable: " ^ why)

let previous_period (env : Screen.env) t =
  if t.report.preset = IncExp.All_time then None
  else
    match P.checked env t.report.preset (t.report.period_offset - 1) with
    | Error _ -> None
    | Ok period -> (
        match report env period with Ok rep -> Some rep | Error _ -> None)

(* The previous window truncated to the current window's elapsed days, plus the
   whole previous window for secondary text. Both are exact folds of the book. *)
let previous_pair (env : Screen.env) t (period : IncExp.period) =
  match previous_period env t with
  | None -> (None, None)
  | Some full ->
      let elapsed, total = IncExp.elapsed ~today:env.today period in
      if elapsed >= total then (Some full, Some full)
      else
        let truncated = IncExp.truncate_to_days full.period elapsed in
        let partial =
          match report env truncated with Ok rep -> Some rep | Error _ -> None
        in
        (partial, Some full)

let same_window (a : IncExp.period) (b : IncExp.period) =
  a.start_day = b.start_day && a.end_exclusive = b.end_exclusive

(* The last windows of this kind, oldest first, ending at the shown window. *)
let compare_reports (env : Screen.env) t (current : IncExp.period) (rep : IncExp.report) =
  if t.report.preset = IncExp.All_time then [ (current, rep) ]
  else
    let rec collect remaining offset acc =
      if remaining <= 0 then acc
      else
        match P.checked env t.report.preset offset with
        | Error _ -> acc
        | Ok period ->
            if same_window period current then collect (remaining - 1) (offset - 1) ((period, rep) :: acc)
            else (
              match report env period with
              | Error _ -> acc
              | Ok r -> collect (remaining - 1) (offset - 1) ((period, r) :: acc))
    in
    collect 6 t.report.period_offset []

type content =
  | Body of string * (Daily_overlays.style * string) list
  | Block of string * (Daily_overlays.style * string) list

let content (env : Screen.env) (geometry : Screen.geometry) t =
  let width, _ = geometry.content in
  let width_of = geometry.width_of in
  match P.checked env t.report.preset t.report.period_offset with
  | Error why ->
      Block
        ( "Income & Expense · Period Unavailable",
          [
            (Daily_overlays.Heading, Ui_text.tr "Report period unavailable:");
            (Daily_overlays.Plain, why);
            (Daily_overlays.Chrome, "Supply an explicit boundary-presets.tsv or choose Month / Year.");
          ] )
  | Ok period -> (
      match report env period with
      | Error why ->
          Block
            ( "Income & Expense · Accounting Roles Unavailable",
              [
                (Daily_overlays.Heading, Ui_text.tr "Income & Expense unavailable:");
                (Daily_overlays.Plain, why);
                (Daily_overlays.Chrome, "Fix accounting-roles.tsv; no Locus role is guessed.");
              ] )
      | Ok rep ->
          if t.compare then
            Body
              ( "Income & Expense • Compare",
                IncExp.render_compare_lines ~width:(max 0 (width - 4)) ~width_of ~book:env.book
                  ~today:env.today
                  ~reports:(compare_reports env t period rep) )
          else
            let previous, previous_full = previous_pair env t period in
            Body
              ( Printf.sprintf "Income & Expense • %s" (IncExp.preset_label t.report.preset),
                IncExp.render_report_lines ~width:(max 0 (width - 4)) ~width_of ~book:env.book
                  ~report:rep ~today:env.today ~previous ~previous_full ))

let row_count (env : Screen.env) geometry t =
  match content env geometry t with Body (_, rows) -> List.length rows | Block _ -> 0

let help_form () =
  Frame.help_form ~title:"Income & Expense / Help"
    [
      "Accounting Formula";
      "  Income  = Sum of negative postings on Income accounts";
      "  Expense = Sum of positive postings on Expense accounts";
      "  Result  = Income - Expense";
      "";
      "Provenance Distinction";
      "  Scheduled: paid via Scheduled plan completion";
      "  other: direct ad-hoc spending";
      "";
      "Reading the summary";
      "  Each total shows the previous window at the same elapsed day and the exact";
      "  difference; expense rows are largest first with a proportional bar.";
      "  Inactive Measures are named once and never painted as zero blocks.";
      "";
      "Keys";
      "  1-5: Month, Cycle, Previous Cycle, Year, All Time";
      "  [ / ]: shift the window back / forward";
      "  c: compare the last windows side by side";
      "  j/k or arrows: line; PgUp/PgDn or Ctrl-U/D: page; Home/End/g/G: ends";
      "  p: print preview   ?: this help   Esc/q: Home";
    ]

let handle (env : Screen.env) geometry t input =
  let stay t = (t, Screen.Stay) in
  let capacity = Frame.capacity geometry in
  match t.preview with
  | Some form -> stay { t with preview = P.handle_preview form input }
  | None -> (
      match t.help with
      | Some form -> (
          match input with
          | `Key (`ASCII '?', []) -> stay { t with help = None }
          | _ -> stay { t with help = P.handle_preview form input })
      | None -> (
          match Frame.handle ~count:(row_count env geometry t) ~capacity t.frame input with
          | Some frame -> stay { t with frame }
          | None -> (
              let reset = Frame.create in
              match P.lowercase input with
              | Some ((`Escape | `ASCII 'q'), []) -> (t, Screen.Home)
              | Some (`ASCII '?', []) -> stay { t with help = Some (help_form ()) }
              | Some (`ASCII 'c', []) -> stay { t with compare = not t.compare; frame = reset }
              | Some (`ASCII ('1' .. '5' as c), []) ->
                  stay
                    {
                      t with
                      frame = reset;
                      report = { preset = P.preset_of_key c; period_offset = 0 };
                    }
              | Some (`ASCII (('[' | ']') as c), []) ->
                  let delta = if c = '[' then -1 else 1 in
                  stay
                    {
                      t with
                      frame = reset;
                      report = { t.report with period_offset = t.report.period_offset + delta };
                    }
              | Some (`ASCII 'p', []) -> (
                  match P.checked env t.report.preset t.report.period_offset with
                  | Error why -> (t, Screen.Message why)
                  | Ok period -> (
                      match report env period with
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
                            }))
              | _ -> (t, Screen.Ignored))))

let rows (env : Screen.env) (geometry : Screen.geometry) t =
  match content env geometry t with
  | Block (title, rows) -> Frame.block ~geometry ~title rows
  | Body (title, rows) ->
      Frame.body ~geometry ~count:(List.length rows) ~title t.frame rows

let view env geometry t =
  let overlay = match t.preview with Some _ -> t.preview | None -> t.help in
  P.view_of ~title:"Income & Expense" ~geometry
    ~rows:(lazy (rows env geometry t))
    overlay
    ~footer:
      (if Option.is_some t.help then Frame.help_footer
       else
         [
           "j/k line  PgUp/PgDn page  Home/End ends  g/G top/bottom  c compare  ? help";
           "1-5 period  [ / ] shift  p print  q/Esc Home";
         ])
