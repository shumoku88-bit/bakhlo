(* Explicit report periods shared by the report screens: presets resolve only
   from configured boundaries. *)
module IncExp = Income_expense_report

let boundary_file = "boundary-presets.tsv"

let preset_of_key = function
  | '1' -> IncExp.Month
  | '2' -> IncExp.Cycle
  | '3' -> IncExp.Previous_cycle
  | '4' -> IncExp.Year
  | _ -> IncExp.All_time

let checked (env : Screen.env) preset offset =
  Result.bind (env.config boundary_file) (fun boundary_presets_text ->
    IncExp.resolve_period ~today:env.today ~preset ~offset ~boundary_presets_text)

(* Report pane / detail pane, print preview and the keys every report shares. *)
type pane = Report | Detail

let print_form ~id ~title lines =
  Ui_form.create ~id ~title:(Ui_text.tr title) ~summary:lines
    ~fields:[ Ui_form.action_buttons ~confirm:(Ui_text.tr "Done") ~cancel:(Ui_text.tr "Close") () ] ()

(* The legacy print preview closes on Close/Esc; Done keeps it open. *)
let handle_preview form input =
  match Ui_form.handle_input form input with
  | Ui_form.Cancel -> None
  | Ui_form.Updated form -> Some form
  | Ui_form.Submit _ -> Some form

let preview_footer =
  [ "Enter submit  Tab next field  Esc cancel"; "Arrow keys / space to choose options" ]

let lowercase = function
  | `Key (`ASCII c, mods) -> Some (`ASCII (Char.lowercase_ascii c), mods)
  | `Key (key, mods) -> Some (key, mods)
  | _ -> None

let page_step (geometry : Screen.geometry) = max 1 (snd geometry.screen - 8)

(* PgUp/PgDn and Ctrl-U/Ctrl-D page by the terminal height less the chrome. *)
let page_delta = function
  | Some (`Page `Up, []) | Some (`ASCII 'u', [ `Ctrl ]) -> Some (-1)
  | Some (`Page `Down, []) | Some (`ASCII 'd', [ `Ctrl ]) -> Some 1
  | _ -> None

let split ~(geometry : Screen.geometry) ~pane ~scroll ~left_title ~left_rows ~right_title ~right_rows =
  let width, height = geometry.content in
  let is_detail = pane = Detail in
  Ui_panel.split ~width_of:geometry.width_of ~width ~height
    ~left_focused:(not is_detail) ~left_title ~left_scroll:(if is_detail then 0 else scroll)
    ~left_selected:None ~left_rows
    ~right_focused:is_detail ~right_title ~right_scroll:(if is_detail then scroll else 0)
    ~right_selected:None ~right_rows ()

let unavailable ~(geometry : Screen.geometry) ~pane ~left_title ~right_title lines why =
  let width, height = geometry.content in
  let left_width, _ = Ui_panel.split_widths width in
  let wrapped = List.concat_map (Daily_overlays.wrap_text ~width_of:geometry.width_of
      (max 1 (left_width - 6))) lines in
  let is_detail = pane = Detail in
  Ui_panel.split ~width_of:geometry.width_of ~width ~height
    ~left_focused:(not is_detail) ~left_title ~left_scroll:0 ~left_selected:None ~left_rows:wrapped
    ~right_focused:is_detail ~right_title ~right_scroll:0 ~right_selected:None ~right_rows:[ why ] ()

let view_of ~title ~(geometry : Screen.geometry) ~rows ~footer preview : Screen.view =
  let overlay = Option.bind preview
      (Ui_overlay.form ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body) in
  {
    title = Ui_text.tr title;
    subtitle = Default;
    rows;
    footer = (if Option.is_some preview then preview_footer else footer);
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
