(* Income & Expense as a cycle summary: the configured cycle is the default
   window, compared with an earlier window of the same kind (the previous one
   unless [c] chose another) at the same age. Totals carry the exact difference;
   each Locus bar has the compared window's bar under it on one scale. [t] shows
   the last windows side by side. One full-width frame; formulas and keys live in
   the [?] help overlay. *)
module IncExp = Income_expense_report
module P = Report_period
module Frame = Report_frame
module Picker = Compare_picker

type t = {
  report : IncExp.t;
  back : int;  (** The compared window: this many windows before the shown one. *)
  frame : Frame.t;
  table : bool;
  picker : Picker.t option;
  help : Ui_form.t option;
  preview : Ui_form.t option;
}

let config_files = [ P.boundary_file ]

let create () =
  {
    report = IncExp.initial ();
    back = 1;
    frame = Frame.create;
    table = false;
    picker = None;
    help = None;
    preview = None;
  }

let enter t =
  { t with frame = Frame.create; table = false; picker = None; help = None; preview = None }

let modal t = Option.is_some t.preview || Option.is_some t.help || Option.is_some t.picker
let form t = match t.preview with Some f -> Some f | None -> t.help
let preset t = t.report.preset
let scroll t = t.frame.Frame.scroll
let table t = t.table
let back t = t.back
let picker t = t.picker
let saved _env _geometry _result t = (t, Screen.Stay)

(* Roles decide Income and Expense; an unreadable roles file is a refusal, not "no roles". *)
let report (env : Screen.env) period =
  match Lazy.force env.accounting_roles with
  | Ok roles -> Ok (IncExp.compute_report ~book:env.book ~roles ~period)
  | Error why -> Error ("Accounting roles unavailable: " ^ why)

(* The window [back] windows before the shown one, if it resolves. *)
let earlier (env : Screen.env) t back =
  if t.report.preset = IncExp.All_time then None
  else Result.to_option (P.checked env t.report.preset (t.report.period_offset - back))

(* The compared window up to the shown window's elapsed days, and all of it while
   the shown window is partial. Both are exact folds of the book. *)
let comparison (env : Screen.env) t (period : IncExp.period) =
  Option.bind (earlier env t t.back) (fun window ->
      match report env window with
      | Error _ -> None
      | Ok whole -> (
          let elapsed, total = IncExp.elapsed ~today:env.today period in
          if elapsed >= total then Some { IncExp.window; same_age = whole; whole = Some whole }
          else
            match report env (IncExp.truncate_to_days window elapsed) with
            | Error _ -> None
            | Ok same_age ->
                (* A window that has not started compares with an empty window; the
                   whole one would be a misread, so it is not offered. *)
                Some { IncExp.window; same_age; whole = (if elapsed = 0 then None else Some whole) }
          ))

let same_window (a : IncExp.period) (b : IncExp.period) =
  a.start_day = b.start_day && a.end_exclusive = b.end_exclusive

(* The last windows of this kind, oldest first, ending at the shown window. *)
let table_reports (env : Screen.env) t (current : IncExp.period) (rep : IncExp.report) =
  if t.report.preset = IncExp.All_time then [ (current, rep) ]
  else
    let rec collect remaining offset acc =
      if remaining <= 0 then acc
      else
        match P.checked env t.report.preset offset with
        | Error _ -> acc
        | Ok period -> (
            if same_window period current then
              collect (remaining - 1) (offset - 1) ((period, rep) :: acc)
            else
              match report env period with
              | Error _ -> acc
              | Ok r -> collect (remaining - 1) (offset - 1) ((period, r) :: acc))
    in
    collect 6 t.report.period_offset []

(* The earlier windows the picker offers: the last [picker_windows] of this kind
   that resolve, stopping at the first window before the oldest entry. *)
let picker_windows = 24

let picker_rows (env : Screen.env) t (current : IncExp.period) =
  let oldest =
    List.fold_left
      (fun day (e : Bakhlo_household.Daily_book.entry) -> if e.day < day then e.day else day)
      current.start_day
      (Bakhlo_household.Daily_book.entries env.book)
  in
  let year_before =
    match Daily_calendar.shift_years current.start_day (-1) with Ok day -> day | Error _ -> ""
  in
  let total (rep : IncExp.report) =
    match List.filter IncExp.measure_active rep.summaries with
    | [] -> "no flow"
    | active ->
        String.concat ", "
          (List.map
             (fun (ms : IncExp.measure_summary) ->
               Daily_overlays.format_money env.book ms.measure ms.total_expense ^ " " ^ ms.measure)
             active)
  in
  let rec collect back acc =
    if back > picker_windows then List.rev acc
    else
      match earlier env t back with
      | None -> List.rev acc
      | Some window when back > 1 && window.end_exclusive <= oldest -> List.rev acc
      | Some window -> (
          match report env window with
          | Error _ -> List.rev acc
          | Ok rep ->
              let note =
                if back = 1 then "previous"
                else if window.start_day = year_before then "a year earlier"
                else ""
              in
              collect (back + 1)
                ({ Picker.offset = back; label = IncExp.span window; note; total = total rep }
                :: acc))
  in
  collect 1 []

let content (env : Screen.env) (geometry : Screen.geometry) t =
  let width, _ = geometry.content in
  let width_of = geometry.width_of in
  match P.checked env t.report.preset t.report.period_offset with
  | Error why ->
      Frame.Block
        ( "Income & Expense · Period Unavailable",
          [
            (Daily_overlays.Heading, Ui_text.tr "Report period unavailable:");
            (Daily_overlays.Plain, why);
            ( Daily_overlays.Chrome,
              "Supply an explicit boundary-presets.tsv or choose Month / Year." );
          ] )
  | Ok period -> (
      match report env period with
      | Error why ->
          Frame.Block
            ( "Income & Expense · Accounting Roles Unavailable",
              [
                (Daily_overlays.Heading, Ui_text.tr "Income & Expense unavailable:");
                (Daily_overlays.Plain, why);
                (Daily_overlays.Chrome, "Fix accounting-roles.tsv; no Locus role is guessed.");
              ] )
      | Ok rep ->
          if t.table then
            Frame.Body
              ( "Income & Expense • Compare",
                IncExp.render_compare_lines
                  ~width:(max 0 (width - 4))
                  ~width_of ~book:env.book ~today:env.today
                  ~reports:(table_reports env t period rep) )
          else
            Frame.Body
              ( Printf.sprintf "Income & Expense • %s" (IncExp.preset_label t.report.preset),
                IncExp.render_report_lines
                  ~width:(max 0 (width - 4))
                  ~width_of ~book:env.book ~report:rep ~today:env.today
                  ~comparison:(comparison env t period) ))

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
      "  The shown window is compared with an earlier window of the same kind (the";
      "  previous one unless c chose another), up to the same elapsed day. Totals";
      "  show the exact difference; under each Locus bar (█) is the compared";
      "  window's bar (░) on the same scale. Windows are named by first and last day.";
      "  Inactive Measures are named once and never painted as zero blocks.";
      "";
      "Keys";
      "  1-5: Month, Cycle, Previous Cycle, Year, All Time";
      "  [ / ]: shift the window back / forward (the comparison moves with it)";
      "  c: choose the window to compare with";
      "  t: the last windows side by side";
      "  j/k or arrows: line; PgUp/PgDn or Ctrl-U/D: page; Home/End/g/G: ends";
      "  p: print preview   ?: this help   Esc/q: Home";
    ]

let open_picker (env : Screen.env) t =
  match P.checked env t.report.preset t.report.period_offset with
  | Error why -> (t, Screen.Message why)
  | Ok _ when t.report.preset = IncExp.All_time ->
      (t, Screen.Message "All Time has no earlier window to compare with.")
  | Ok period ->
      ( { t with picker = Some (Picker.create (picker_rows env t period) ~offset:t.back) },
        Screen.Stay )

let picker_input (geometry : Screen.geometry) t picker input =
  match Picker.handle ~body:geometry.body picker input with
  | picker, Picker.Stay -> ({ t with picker = Some picker }, Screen.Stay)
  | _, Picker.Close -> ({ t with picker = None }, Screen.Stay)
  | _, Picker.Choose back ->
      ({ t with picker = None; back; table = false; frame = Frame.create }, Screen.Stay)

let handle (env : Screen.env) geometry t input =
  let stay t = (t, Screen.Stay) in
  let capacity = Frame.capacity geometry in
  match t.picker with
  | Some picker -> picker_input geometry t picker input
  | None -> (
      match P.handle_overlays ~preview:t.preview ~help:t.help input with
      | Some (preview, help) -> stay { t with preview; help }
      | None -> (
          match
            Frame.handle ~count:(Frame.count (content env geometry t)) ~capacity t.frame input
          with
          | Some frame -> stay { t with frame }
          | None -> (
              let reset = Frame.create in
              match P.lowercase input with
              | Some ((`Escape | `ASCII 'q'), []) -> (t, Screen.Home)
              | Some (`ASCII '?', []) -> stay { t with help = Some (help_form ()) }
              | Some (`ASCII 'c', []) -> open_picker env t
              | Some (`ASCII 't', []) -> stay { t with table = not t.table; frame = reset }
              | Some (`ASCII ('1' .. '5' as c), []) ->
                  stay
                    {
                      t with
                      frame = reset;
                      back = 1;
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

let rows env geometry t = Frame.rows ~geometry t.frame (content env geometry t)

let view env (geometry : Screen.geometry) t =
  let overlay = match t.preview with Some _ -> t.preview | None -> t.help in
  let view =
    P.view_of ~title:"Income & Expense" ~geometry
      ~rows:(lazy (rows env geometry t))
      overlay
      ~footer:
        (if Option.is_some t.help then Frame.help_footer
         else
           [
             "j/k line  PgUp/PgDn page  Home/End ends  g/G top/bottom  c compare with  ? help";
             "1-5 period  [ / ] shift  t table  p print  q/Esc Home";
           ])
  in
  match t.picker with
  | None -> view
  | Some picker ->
      let overlay =
        Picker.frame ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body picker
      in
      { view with overlay; cursor = None; footer = Picker.footer ~width:(fst geometry.screen) }
