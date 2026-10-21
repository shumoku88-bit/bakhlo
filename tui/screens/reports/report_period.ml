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


let print_form ~id ~title lines =
  Ui_form.create ~id ~title:(Ui_text.tr title) ~summary:lines
    ~fields:[ Ui_form.action_buttons ~confirm:(Ui_text.tr "Done") ~cancel:(Ui_text.tr "Close") () ]
    ()

(* The legacy print preview closes on Close/Esc; Done keeps it open. *)
let handle_preview form input =
  match Ui_form.handle_input form input with
  | Ui_form.Cancel -> None
  | Ui_form.Updated form -> Some form
  | Ui_form.Submit _ -> Some form

let preview_footer =
  [ "Enter submit  Tab next field  Esc cancel"; "Arrow keys / space to choose options" ]

let lowercase = Ui_input.key_ignoring_case

(* PgUp/PgDn and Ctrl-U/Ctrl-D page by the terminal height less the chrome. *)
let page_delta = function
  | Some (`Page `Up, []) | Some (`ASCII 'u', [ `Ctrl ]) -> Some (-1)
  | Some (`Page `Down, []) | Some (`ASCII 'd', [ `Ctrl ]) -> Some 1
  | _ -> None

let view_of ~title ~(geometry : Screen.geometry) ~rows ~footer preview : Screen.view =
  let overlay =
    Option.bind preview
      (Ui_overlay.form ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body)
  in
  let is_preview =
    match preview with Some form -> Ui_form.id form <> "report_help" | None -> false
  in
  {
    title = Ui_text.tr title;
    subtitle = Default;
    rows;
    footer = (if is_preview then preview_footer else footer);
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
