(* Actual route owner: the LOAM three-pane Actuals workspace. The list is
   grouped by day inside a period window (Today / Cycle / Month / Year / All); the
   Screen owns the window because only it can read the configured boundary
   presets the reports use. Record actions on the selected entry are requests to
   the Shell, which owns the retained Record draft and the editor sessions. *)
module Act = Actual_workspace
module Pw = Period_window
module Picker = Actual_period_picker

(* The picker is open over the list; the list keeps its own state underneath. *)
type t = { workspace : Act.t; picker : Picker.t option }

let config_files = [ Pw.boundary_file ]
let create () = { workspace = Act.create (); picker = None }
let enter ~focus_day _t = { workspace = Act.create ~focus_day (); picker = None }
let workspace t = t.workspace
let picker t = t.picker
let modal t = Option.is_some t.picker
let saved _env _geometry _result t = (t, Screen.Stay)

let book_changed ~before ~after t =
  let workspace, notice =
    Act.returned_from_detail ~before_book:before ~after_book:after t.workspace
  in
  ({ workspace; picker = None }, notice)

(* The period window: the reports' own configured boundary presets for Cycle and
   Month, one day for Today and the whole ledger for All. *)
let window_label period ~start_day ~end_exclusive =
  Picker.label period { Picker.start_day; end_exclusive }

let anchor (env : Screen.env) ws = Option.value (Act.focus_day ws) ~default:env.today

let raw_window (env : Screen.env) ws =
  let today = anchor env ws in
  let offset = Act.period_offset ws in
  let period = Act.period ws in
  match period with
  | Act.All ->
      Ok
        {
          Act.start_day = "0001-01-01";
          end_exclusive = "9999-12-31";
          label = window_label period ~start_day:"0001-01-01" ~end_exclusive:"9999-12-31";
        }
  | Act.Today -> (
      match Day.shift_days today offset with
      | Error why -> Error why
      | Ok day -> (
          match Day.shift_days day 1 with
          | Error why -> Error why
          | Ok next ->
              Ok
                {
                  Act.start_day = day;
                  end_exclusive = next;
                  label = window_label period ~start_day:day ~end_exclusive:next;
                }))
  | Act.Cycle | Act.Month | Act.Year -> (
      let preset =
        match period with Act.Cycle -> Pw.Cycle | Act.Month -> Pw.Month | _ -> Pw.Year
      in
      match
        Result.bind (env.config Pw.boundary_file) (fun boundary_presets_text ->
            Pw.resolve ~today ~preset ~offset ~boundary_presets_text)
      with
      | Ok p ->
          Ok
            {
              Act.start_day = p.start_day;
              end_exclusive = p.end_exclusive;
              label = window_label period ~start_day:p.start_day ~end_exclusive:p.end_exclusive;
            }
      | Error why -> Error why)

(* A window that cannot be resolved keeps the list working: the whole ledger,
   with a notice that names the reason. *)
let window (env : Screen.env) ws =
  match raw_window env ws with
  | Ok window -> (window, None)
  | Error why ->
      ( { Act.start_day = "0001-01-01"; end_exclusive = "9999-12-31"; label = "All time" },
        Some (why ^ " Showing all entries.") )

let scope_of (env : Screen.env) ws window =
  {
    Act.window;
    today = env.today;
    focus_day = anchor env ws;
    roles = Lazy.force env.accounting_roles;
    measure = env.measure;
  }

let context_of (env : Screen.env) ws =
  let window, warning = window env ws in
  { Act.book = env.book; scope = scope_of env ws window; warning }

let context env t = context_of env t.workspace

let action (env : Screen.env) ws action =
  ( ws,
    Screen.Record_action
      {
        action;
        target =
          Option.map (fun e -> Screen.Entry e) (Act.selected_entry ~ctx:(context_of env ws) ws);
      } )

(* The previous or next window of the same period. A window outside the
   configured presets is refused; the current window stays. *)
let move_window (env : Screen.env) ws delta =
  if Act.period ws = Act.All then (ws, Screen.Message "All time has no window to move.")
  else
    let candidate = Act.set_period_offset (Act.period_offset ws + delta) ws in
    match raw_window env candidate with
    | Ok window -> (Act.set_scope (scope_of env candidate window) candidate, Screen.Message "")
    | Error why -> (ws, Screen.Message why)

(* The same period one year earlier or later: the window containing the current
   window's first day moved by a year. *)
let move_year (env : Screen.env) ws delta =
  match raw_window env ws with
  | _ when Act.period ws = Act.All -> (ws, Screen.Message "All time has no year to move.")
  | Error why -> (ws, Screen.Message why)
  | Ok window -> (
      match Day.shift_years window.Act.start_day delta with
      | Error why -> (ws, Screen.Message why)
      | Ok day -> (
          let candidate = Act.set_focus_day day ws in
          match raw_window env candidate with
          | Ok window -> (Act.set_scope (scope_of env candidate window) candidate, Screen.Message "")
          | Error why -> (ws, Screen.Message why)))

(* The day the picker starts from: today inside the current window, else the
   window's last day; today for All or a window that cannot be resolved. *)
let reference (env : Screen.env) ws =
  match raw_window env ws with
  | Ok w
    when Act.period ws <> Act.All
         && not (w.Act.start_day <= env.today && env.today < w.end_exclusive) -> (
      match Day.shift_days w.end_exclusive (-1) with Ok day -> day | Error _ -> env.today)
  | _ -> env.today

(* Every window of [period] with its count and total. The cycle is the configured
   one containing [reference], else the one containing today. *)
let picker_for (env : Screen.env) ws period ~reference =
  let cycle =
    Result.bind (env.config Pw.boundary_file) (fun boundary_presets_text ->
        match Pw.cycle_windows ~today:reference ~boundary_presets_text with
        | Ok (windows, _) -> Ok windows
        | Error _ when reference <> env.today ->
            Result.map fst (Pw.cycle_windows ~today:env.today ~boundary_presets_text)
        | Error why -> Error why)
  in
  let rows =
    Result.map
      (fun windows -> Picker.rows ~ctx:(context_of env ws) ~today:env.today period windows)
      (Picker.windows ~book:env.book ~today:env.today ~reference ~cycle period)
  in
  Picker.create period ~rows ~reference

let picker_reference (env : Screen.env) ws picker =
  match Picker.selected picker with
  | Some row -> Picker.reference ~today:env.today row
  | None -> reference env ws

(* Enter on a window opens that period on it; the list selects the window's day
   (today inside it, else its last day) or the latest day before it. *)
let choose (env : Screen.env) t picker row =
  let ws = t.workspace and period = Picker.period picker in
  let candidate =
    if period = Act.All then Act.set_period Act.All ws
    else Act.set_window period ~focus_day:(Picker.reference ~today:env.today row) ws
  in
  match raw_window env candidate with
  | Ok window ->
      ( { workspace = Act.set_scope (scope_of env candidate window) candidate; picker = None },
        Screen.Message "" )
  | Error why -> ({ t with picker = Some picker }, Screen.Message why)

let picker_input (env : Screen.env) (geometry : Screen.geometry) t picker input =
  let picker, command = Picker.handle ~body:geometry.body picker input in
  match command with
  | Picker.Stay -> ({ t with picker = Some picker }, Screen.Stay)
  | Picker.Close -> ({ t with picker = None }, Screen.Message "")
  | Picker.Refuse why -> ({ t with picker = Some picker }, Screen.Message why)
  | Picker.Kind period ->
      let reference = picker_reference env t.workspace picker in
      ({ t with picker = Some (picker_for env t.workspace period ~reference) }, Screen.Message "")
  | Picker.Choose row -> choose env t picker row

let workspace_input (env : Screen.env) (geometry : Screen.geometry) ws input =
  let typing = Act.search_editing ws in
  let ctx = context_of env ws in
  let next, request =
    match input with
    | `Key (`ASCII ' ', []) when not typing -> (ws, Screen.Commands)
    | `Key (`ASCII ('c' | 'C' | 'e' | 'E'), []) when not typing -> action env ws Screen.Edit
    | `Key (`ASCII ('x' | 'X'), []) when not typing -> action env ws Screen.Reverse
    | `Key (`ASCII ('d' | 'D'), []) when not typing -> action env ws Screen.Correct_date
    | `Key (`ASCII ('m' | 'M'), []) when not typing -> action env ws Screen.Classify_merchant
    | `Key (`ASCII '[', []) when not typing -> move_window env ws (-1)
    | `Key (`ASCII ']', []) when not typing -> move_window env ws 1
    | `Key (`ASCII '{', []) when not typing -> move_year env ws (-1)
    | `Key (`ASCII '}', []) when not typing -> move_year env ws 1
    | _ -> (
        let next, command =
          Act.handle ~ctx ~dimensions:geometry.content ~width_of:geometry.width_of ws input
        in
        ( next,
          match command with
          | Act.Stay | Act.Redraw -> Screen.Message (Act.notice next)
          | Act.Open_selected entry -> Screen.Drill { day = entry.day; entry = entry.id }
          | Act.Record_new -> Screen.New_record
          | Act.Back -> Screen.Home ))
  in
  (* The scope of the state we return, so a drill return restores the selection
     in the same window and the same order. *)
  (Act.set_scope (context_of env next).Act.scope next, request)

let handle (env : Screen.env) (geometry : Screen.geometry) t input =
  match (t.picker, input) with
  | Some picker, _ -> picker_input env geometry t picker input
  | None, `Key (`ASCII 'f', []) when not (Act.search_editing t.workspace) ->
      let ws = t.workspace in
      ( { t with picker = Some (picker_for env ws (Act.period ws) ~reference:(reference env ws)) },
        Screen.Message "" )
  | None, _ ->
      let workspace, request = workspace_input env geometry t.workspace input in
      ({ t with workspace }, request)

(* A reload recounts an open picker on the new book, on the same window. *)
let reloaded (env : Screen.env) t =
  match t.picker with
  | None -> (t, Screen.Stay)
  | Some picker ->
      let reference = picker_reference env t.workspace picker in
      ( { t with picker = Some (picker_for env t.workspace (Picker.period picker) ~reference) },
        Screen.Stay )

let view (env : Screen.env) (geometry : Screen.geometry) t =
  let width_of = geometry.width_of and ws = t.workspace in
  let ctx = context_of env ws in
  let total = Act.window_total ~ctx in
  {
    Screen.title =
      (Ui_text.tr "Actual" ^ "  |  "
      ^ Act.period_name (Act.period ws)
      ^ " " ^ ctx.Act.scope.window.label
      ^ match total with Some amount -> "  |  Expense " ^ amount | None -> "");
    subtitle =
      (if Act.search_editing ws || Act.search_query ws <> "" then
         let style, text = Act.search_line ~width:(fst geometry.screen) ~width_of ws in
         Screen.Styled (style, text)
       else Screen.Default);
    rows =
      lazy
        (Act.screen ~ctx ~total ~draft_retained:env.draft_retained ~dimensions:geometry.content
           ~width_of ws);
    footer =
      (match t.picker with
      | Some _ -> Picker.footer ~width:(fst geometry.screen)
      | None -> Act.footer ~dimensions:geometry.screen ~width_of ws);
    overlay =
      Option.bind t.picker (fun picker ->
          Picker.frame ~width_of ~screen:geometry.screen ~body:geometry.body picker);
    cursor =
      (match t.picker with
      | Some _ -> None
      | None -> Act.cursor_position ~dimensions:geometry.content ~width_of ws);
  }
