(* Actual route owner: the LOAM three-pane Actuals workspace. The list is
   grouped by day inside a period window (Today / Cycle / Month / All); the
   Screen owns the window because only it can read the configured boundary
   presets the reports use. Record actions on the selected entry are requests to
   the Shell, which owns the retained Record draft and the editor sessions. *)
module Act = Actual_workspace
module Cal = Daily_calendar
module Pw = Period_window

type t = Act.t

let config_files = [ Pw.boundary_file ]

let create () = Act.create ()
let enter ~focus_day _t = Act.create ~focus_day ()
let modal _t = false
let saved _env _geometry _result t = (t, Screen.Stay)

let book_changed ~before ~after t = Act.returned_from_detail ~before_book:before ~after_book:after t

(* The period window: the reports' own configured boundary presets for Cycle and
   Month, one day for Today and the whole ledger for All. *)
let window_label period ~start_day ~end_exclusive =
  match period with
  | Act.All -> "All time"
  | Act.Today -> "Day " ^ start_day
  | Act.Month -> "Month " ^ String.sub start_day 0 7
  | Act.Cycle -> "Cycle " ^ start_day ^ ".." ^ end_exclusive

let anchor (env : Screen.env) t = Option.value (Act.focus_day t) ~default:env.today

let raw_window (env : Screen.env) t =
  let today = anchor env t in
  let offset = Act.period_offset t in
  let period = Act.period t in
  match period with
  | Act.All ->
      Ok
        {
          Act.start_day = "0001-01-01";
          end_exclusive = "9999-12-31";
          label = window_label period ~start_day:"0001-01-01" ~end_exclusive:"9999-12-31";
        }
  | Act.Today -> (
      match Cal.shift_days today offset with
      | Error why -> Error why
      | Ok day -> (
          match Cal.shift_days day 1 with
          | Error why -> Error why
          | Ok next ->
              Ok
                {
                  Act.start_day = day;
                  end_exclusive = next;
                  label = window_label period ~start_day:day ~end_exclusive:next;
                }))
  | Act.Cycle | Act.Month ->
      let preset = if period = Act.Cycle then Pw.Cycle else Pw.Month in
      (match
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
let window (env : Screen.env) t =
  match raw_window env t with
  | Ok window -> (window, None)
  | Error why ->
      ( {
          Act.start_day = "0001-01-01";
          end_exclusive = "9999-12-31";
          label = "All time";
        },
        Some (why ^ " Showing all entries.") )

let scope_of (env : Screen.env) t window =
  {
    Act.window;
    today = env.today;
    focus_day = anchor env t;
    roles = Lazy.force env.accounting_roles;
    measure = env.measure;
  }

let context (env : Screen.env) t =
  let window, warning = window env t in
  { Act.book = env.book; scope = scope_of env t window; warning }

let action (env : Screen.env) t action =
  ( t,
    Screen.Record_action
      {
        action;
        target =
          Option.map (fun e -> Screen.Entry e) (Act.selected_entry ~ctx:(context env t) t);
      } )

(* The previous or next window of the same period. A window outside the
   configured presets is refused; the current window stays. *)
let move_window (env : Screen.env) t delta =
  if Act.period t = Act.All then (t, Screen.Message "All time has no window to move.")
  else
    let candidate = Act.set_period_offset (Act.period_offset t + delta) t in
    match raw_window env candidate with
    | Ok window -> (Act.set_scope (scope_of env candidate window) candidate, Screen.Message "")
    | Error why -> (t, Screen.Message why)

let handle (env : Screen.env) (geometry : Screen.geometry) t input =
  let typing = Act.search_editing t in
  let ctx = context env t in
  let next, request =
    match input with
    | `Key (`ASCII ' ', []) when not typing -> (t, Screen.Commands)
    | `Key (`ASCII ('c' | 'C' | 'e' | 'E'), []) when not typing -> action env t Screen.Edit
    | `Key (`ASCII ('x' | 'X'), []) when not typing -> action env t Screen.Reverse
    | `Key (`ASCII ('d' | 'D'), []) when not typing -> action env t Screen.Correct_date
    | `Key (`ASCII ('m' | 'M'), []) when not typing -> action env t Screen.Classify_merchant
    | `Key (`ASCII 'f', []) when not typing ->
        let period =
          match Act.period t with
          | Act.Today -> Act.Cycle
          | Act.Cycle -> Act.Month
          | Act.Month -> Act.All
          | Act.All -> Act.Today
        in
        (Act.set_period period t, Screen.Message "")
    | `Key (`ASCII '[', []) when not typing -> move_window env t (-1)
    | `Key (`ASCII ']', []) when not typing -> move_window env t 1
    | _ ->
        let next, command =
          Act.handle ~ctx:ctx ~dimensions:geometry.content ~width_of:geometry.width_of t input
        in
        ( next,
          match command with
          | Act.Stay | Act.Redraw -> Screen.Message (Act.notice next)
          | Act.Open_selected entry -> Screen.Drill { day = entry.day; entry = entry.id }
          | Act.Record_new -> Screen.New_record
          | Act.Back -> Screen.Home )
  in
  (* The scope of the state we return, so a drill return restores the selection
     in the same window and the same order. *)
  (Act.set_scope (context env next).Act.scope next, request)

let view (env : Screen.env) (geometry : Screen.geometry) t =
  let width_of = geometry.width_of in
  let ctx = context env t in
  let total = Act.window_total ~ctx:ctx in
  {
    Screen.title =
      Ui_text.tr "Actual" ^ "  |  " ^ ctx.Act.scope.window.label
      ^ (match total with Some amount -> "  |  Expense " ^ amount | None -> "");
    subtitle =
      (if Act.search_editing t || Act.search_query t <> "" then
         let style, text = Act.search_line ~width:(fst geometry.screen) ~width_of t in
         Screen.Styled (style, text)
       else Screen.Default);
    rows =
      lazy
        (Act.screen ~ctx:ctx ~total ~draft_retained:env.draft_retained ~dimensions:geometry.content
           ~width_of t);
    footer = Act.footer ~dimensions:geometry.screen ~width_of t;
    overlay = None;
    cursor = Act.cursor_position ~dimensions:geometry.content ~width_of t;
  }
