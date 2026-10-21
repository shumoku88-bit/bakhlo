(* Observe Quantities: exact observed quantities added row by row and
   published together as one reconciliation group. The draft keeps the bytes
   it started from; a changed or uncertain generation stops writes. *)
module B = Bakhlo_sexp.Daily_book
module Form = Ui_form

let tr = Ui_text.tr

type draft = {
  rows : (string * string * Z.t) list;
  base : string;
  pending : string * string * string; (* locus, measure, amount being typed *)
  uncertain : bool;
}

type editor = Quantity of Form.t | Preview of Form.t
type t = { editor : editor option; draft : draft option }

let config_files = []
let create () = { editor = None; draft = None }
let modal t = Option.is_some t.editor
let form t = match t.editor with None -> None | Some (Quantity f | Preview f) -> Some f

let with_form form t =
  match t.editor with
  | None -> t
  | Some (Quantity _) -> { t with editor = Some (Quantity form) }
  | Some (Preview _) -> { t with editor = Some (Preview form) }

let config_token s = s <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) s

let quantity_form ?default_locus ?default_measure ?current_amount ?(rows = []) ?(notice = "")
    (env : Screen.env) =
  let def_measure =
    match default_measure with
    | Some m -> m
    | None -> ( match B.measures env.book with (m, _) :: _ -> m | [] -> "jpy")
  in
  let locus_val = Option.value ~default:"" default_locus in
  let locus_ph =
    if locus_val <> "" then locus_val
    else match B.approved_loci env.book with Some (l :: _) -> l | _ -> "wallet"
  in
  let amount_ph =
    match current_amount with Some amt -> Printf.sprintf "e.g. %s" amt | None -> "e.g. 50000"
  in
  let summary =
    [
      "Record newly verified balance for an account (Locus).";
      "Existing observations for other loci remain preserved.";
    ]
    @ (if rows = [] then [ "  (no observations added yet)" ]
       else
         List.mapi
           (fun i (l, m, q) -> Printf.sprintf "  %d. %s  %s %s" (i + 1) l (B.format env.book m q) m)
           rows)
    @ [ "Enter on amount adds a row; Preview reviews all rows without writing." ]
  in
  Form.create ~id:"observe_quantity" ~title:"Observe Quantities" ~notice ~summary
    ~fields:
      [
        Form.text_field ~id:"locus" ~label:"Locus" ~value:locus_val
          ~placeholder:(Printf.sprintf "e.g. %s" locus_ph)
          ();
        Form.text_field ~id:"measure" ~label:"Measure" ~value:def_measure ();
        Form.text_field ~id:"amount" ~label:"Observed amount" ~placeholder:amount_ph ();
        Form.buttons_field ~id:"action"
          ~buttons:
            [
              { Form.label = "Add"; is_cancel = false };
              { Form.label = "Preview"; is_cancel = false };
              { Form.label = "Cancel"; is_cancel = true };
            ]
          ();
      ]
    ()

let preview_form (env : Screen.env) rows ~notice =
  let lines =
    List.mapi
      (fun i (l, m, q) -> Printf.sprintf "  %d. %s  %s %s" (i + 1) l (B.format env.book m q) m)
      rows
  in
  Form.create ~id:"observe_preview" ~title:"Observe / Preview" ~notice
    ~summary:
      ([
         "New reconciliation group:";
         "All rows describe quantities observed together at this boundary.";
         "Unmentioned prior observations are preserved; re-observed move here.";
         "The shared publisher derives the Event root cut.";
       ]
      @ (if lines = [] then [ "  (none)" ] else lines)
      @ [ "Tab select  Enter confirm  e edit  Esc cancel" ])
    ~fields:
      [
        (* [Edit] is selected first: Enter on an unreviewed Preview must not
           publish. [Publish] needs an explicit selection. *)
        Form.buttons_field ~id:"action" ~selected:1
          ~buttons:
            [
              { Form.label = "Publish"; is_cancel = false };
              { Form.label = "Edit"; is_cancel = true };
              { Form.label = "Cancel"; is_cancel = true };
            ]
          ();
      ]
    ()

(* Entry points: Home/Calendar [o] and Commands open an empty draft; Balances
   opens one for its selected coordinate with the amount field focused. *)
let open_editor ?locus ?measure ?amount (env : Screen.env) _t =
  let form =
    quantity_form ?default_locus:locus ?default_measure:measure ?current_amount:amount env
  in
  let form =
    if Option.is_some locus then Form.set_focused form (Form.find_field_index form "amount")
    else form
  in
  {
    editor = Some (Quantity form);
    draft =
      Some { rows = []; base = env.revision; pending = ("", env.measure, ""); uncertain = false };
  }

let edit (env : Screen.env) t (draft : draft) =
  let locus, measure, amount = draft.pending in
  let form = quantity_form ~default_locus:locus ~default_measure:measure ~rows:draft.rows env in
  { t with editor = Some (Quantity (Form.set_text form "amount" amount)) }

let submit_quantity (env : Screen.env) t submitted =
  let refused why =
    ({ t with editor = Some (Quantity (Form.set_notice submitted why)) }, Screen.Stay)
  in
  match t.draft with
  | None -> refused "Observation session expired. Cancel and reopen."
  | Some draft -> (
      let text id = Option.value ~default:"" (Form.get_text submitted id) in
      if
        Form.focused submitted = Form.find_field_index submitted "action"
        && Form.get_button submitted "action" = Some 1
      then
        if draft.rows = [] then refused "Add at least one observed quantity before Preview."
        else
          ( {
              editor = Some (Preview (preview_form env draft.rows ~notice:""));
              draft = Some { draft with pending = (text "locus", text "measure", text "amount") };
            },
            Screen.Stay )
      else
        let locus = String.trim (text "locus") in
        let measure = String.lowercase_ascii (String.trim (text "measure")) in
        if not (config_token locus && config_token measure) then
          refused "Enter single-line Locus and Measure tokens."
        else
          match B.parse_signed_amount env.book measure (String.trim (text "amount")) with
          | Error why -> refused ("Invalid observed amount: " ^ why)
          | Ok quantity ->
              let rows = draft.rows @ [ (locus, measure, quantity) ] in
              ( {
                  editor = Some (Quantity (quantity_form ~default_measure:measure ~rows env));
                  draft = Some { draft with rows; pending = ("", measure, "") };
                },
                Screen.Stay ))

let submit_preview (env : Screen.env) (geometry : Screen.geometry) t submitted =
  let refused why = { t with editor = Some (Preview (Form.set_notice submitted why)) } in
  match t.draft with
  | None -> (refused "Observation session expired. Cancel and reopen.", Screen.Stay)
  | Some draft ->
      if env.blocked || draft.uncertain || draft.base <> env.revision then
        ( refused "Observation stopped. Cancel and reload to inspect; do not retry this image.",
          Screen.Stop_writes None )
      else if not (Ui_overlay.form_fits ~width_of:geometry.width_of ~body:geometry.body submitted)
      then
        (refused "Enlarge the terminal to review every observation before publishing.", Screen.Stay)
      else
        ( { t with editor = Some (Preview submitted) },
          Screen.Publish (Observe_quantities { rows = draft.rows; base = draft.base }) )

let handle (env : Screen.env) (geometry : Screen.geometry) t input =
  match t.editor with
  | None -> (t, Screen.Ignored)
  | Some editor -> (
      let form = Option.get (form t) in
      let result =
        match (editor, input) with
        | Preview _, `Key (`ASCII ('e' | 'E'), []) -> Form.Cancel
        | Preview _, `Key (`Tab, mods) when mods = [] || mods = [ `Shift ] ->
            Form.handle_input form (`Key (`Arrow (if mods = [] then `Right else `Left), []))
        | Quantity _, `Key (`Tab, mods) when mods = [] || mods = [ `Shift ] ->
            let action = Form.find_field_index form "action" in
            let position =
              if Form.focused form = action then
                action + Option.value ~default:0 (Form.get_button form "action")
              else Form.focused form
            in
            let next = (position + if mods = [] then 1 else 5) mod 6 in
            let form = Form.set_focused form (min action next) in
            Form.Updated
              (Form.update_field form "action" (function
                | Form.Buttons buttons ->
                    Form.Buttons { buttons with selected = max 0 (next - action) }
                | field -> field))
        | _ -> Form.handle_input form input
      in
      match (result, editor) with
      | Form.Cancel, Preview _ ->
          let edit_requested =
            input = `Key (`ASCII 'e', [])
            || input = `Key (`ASCII 'E', [])
            || (input = `Key (`Enter, []) && Form.get_button form "action" = Some 1)
          in
          if edit_requested then
            ( (match t.draft with
              | Some draft -> edit env t draft
              | None -> { t with editor = None }),
              Screen.Stay )
          else ({ editor = None; draft = None }, Screen.Stay)
      | Form.Cancel, Quantity _ -> ({ editor = None; draft = None }, Screen.Stay)
      | Form.Updated form, _ -> (with_form form t, Screen.Stay)
      | Form.Submit submitted, Quantity _ -> submit_quantity env t submitted
      | Form.Submit submitted, Preview _ -> submit_preview env geometry t submitted)

let published _env _geometry outcome t =
  let notice why = with_form (Form.set_notice (Option.get (form t)) why) t in
  match (outcome, t.editor, t.draft) with
  | _, None, _ -> (t, Screen.Stay)
  | Screen.Published, Some _, draft ->
      let count = match draft with Some d -> List.length d.rows | None -> 0 in
      ( { editor = None; draft = None },
        Screen.Message (Printf.sprintf "Observed %d coordinates together." count) )
  | Screen.Publish_refused why, Some _, _ -> (notice why, Screen.Stay)
  | Screen.Publish_conflict, Some _, _ ->
      (notice "File changed on disk. Draft retained; cancel and reload to inspect.", Screen.Stay)
  | Screen.Publish_stopped, Some _, draft ->
      let t = { t with draft = Option.map (fun d -> { d with uncertain = true }) draft } in
      ( with_form
          (Form.set_notice
             (Option.get (form t))
             "Observation save uncertain. Do not retry; reload to inspect.")
          t,
        Screen.Stay )

let reloaded (env : Screen.env) t =
  match (t.editor, t.draft) with
  | Some _, Some draft when draft.uncertain || draft.base <> env.revision ->
      ( t,
        Screen.Stop_writes
          (Some
             "Observation generation changed or save is uncertain. Cancel and inspect; do not \
              retry.") )
  | _ -> (t, Screen.Stay)

let view _env (geometry : Screen.geometry) t =
  let overlay =
    Option.bind (form t)
      (Ui_overlay.form ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body)
  in
  {
    Screen.title = tr "Observe";
    subtitle = Default;
    rows = lazy [];
    footer =
      (match t.editor with
      | Some (Preview _) ->
          [
            "Enter = Edit (default)  Tab/Left/Right select  Esc cancel";
            "Publish needs an explicit selection; full image must fit; no partial save";
          ]
      | Some (Quantity _) | None ->
          [
            "Enter next/Add  Tab fields  Left/Right action";
            "Add observed rows together, then Preview; Esc cancels";
          ]);
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
