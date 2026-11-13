(* Explicit report periods shared by the report screens: presets resolve only
   from configured boundaries. *)
module IncExp = Income_expense_report

let boundary_file = Period_window.boundary_file

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
    subtitle = Hidden;
    rows;
    footer = (if is_preview then preview_footer else footer);
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }

(* An open print preview takes every key first, then an open help, which [?] also
   closes. The new (preview, help) pair, or [None] when neither is open. *)
let handle_overlays ~preview ~help input =
  match (preview, help) with
  | Some form, _ -> Some (handle_preview form input, help)
  | None, Some form -> (
      match input with
      | `Key (`ASCII '?', []) -> Some (None, None)
      | _ -> Some (None, handle_preview form input))
  | None, None -> None

(* The keys every period report reads the same way, so a screen only says what
   each one does to its own state:

     q / Esc   back to Home           ?   help
     1-5       Month, Cycle, Previous Cycle, Year, All Time
     [ / ]     the window before / after the shown one
     p         print preview *)
type key = Home | Help | Preset of IncExp.period_preset | Shift of int | Print

let key input =
  match lowercase input with
  | Some ((`Escape | `ASCII 'q'), []) -> Some Home
  | Some (`ASCII '?', []) -> Some Help
  | Some (`ASCII ('1' .. '5' as c), []) -> Some (Preset (preset_of_key c))
  | Some (`ASCII '[', []) -> Some (Shift (-1))
  | Some (`ASCII ']', []) -> Some (Shift 1)
  | Some (`ASCII 'p', []) -> Some Print
  | _ -> None
