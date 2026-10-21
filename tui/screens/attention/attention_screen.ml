(* Attention: open household matters with due state, and the Add / Resolve /
   Drop editors. The memory is saved only through the Shell, which rechecks
   that the file still equals the state this editor started from. *)
module Att = Attention_data
module A = Daily_draft
module O = Daily_overlays
module Form = Ui_form
module Panel = Ui_panel

let tr = Ui_text.tr

type pane = List_pane | Detail_pane

(* An open editor, and the confirmation shown once its save is read back. *)
type editor = { form : Form.t; success : string }
type t = { selected : int; pane : pane; scroll : int; editor : editor option }

let config_files = []
let create () = { selected = 0; pane = List_pane; scroll = 0; editor = None }
let enter t = { t with pane = List_pane; scroll = 0; editor = None }
let modal t = Option.is_some t.editor
let with_form form t = { t with editor = Option.map (fun e -> { e with form }) t.editor }
let form t = Option.map (fun e -> e.form) t.editor
let selected t = t.selected
let detail_focused t = t.pane = Detail_pane

let open_items (env : Screen.env) =
  match env.attention with Ok t -> Att.open_items t | Error _ -> []

let selected_item env t = List.nth_opt (open_items env) t.selected

let move env t delta =
  let count = List.length (open_items env) in
  (* Bounded before adding: Home/End pass +max_int, which would wrap. *)
  if count = 0 then t
  else
    let current = max 0 (min (count - 1) t.selected) in
    {
      t with
      selected =
        (if delta > 0 then current + min delta (count - 1 - current) else max 0 (current + delta));
    }

let add_form ~today =
  Form.create ~id:"add_attention" ~title:"Add Attention"
    ~summary:[ "Record a household matter needing attention." ]
    ~fields:
      [
        Form.text_field ~id:"context" ~label:"Context" ~placeholder:"Matter description" ();
        Form.choice_field ~id:"due_kind" ~label:"Due"
          ~options:[ "No due date"; "Due undetermined"; "Due on date" ]
          ~selected:0 ();
        Form.text_field ~id:"due_date" ~label:"Due date" ~value:today ~placeholder:"YYYY-MM-DD" ();
        Form.action_buttons ~confirm:"Add Attention" ~cancel:"Cancel" ();
      ]
    ()

let close_form ~id ~title ~confirm (item : Att.item) =
  Form.create ~id ~payload:item.id ~title
    ~summary:[ "Target: " ^ item.id; "Context: " ^ item.context; Att.due_label item.due ]
    ~fields:[ Form.action_buttons ~confirm ~cancel:"Keep Open" () ]
    ()

(* Ask the Shell to save [update] of the loaded memory; refusals stay on the form. *)
let commit (env : Screen.env) t submitted update success =
  let refused why =
    ( {
        t with
        editor =
          Some
            {
              form =
                Form.set_notice submitted
                  ("Attention not confirmed: " ^ why ^ " Reload to inspect before retrying.");
              success;
            };
      },
      Screen.Stay )
  in
  if env.blocked then refused "Writes stopped. Reload to inspect."
  else
    match
      Result.bind env.attention (fun expected ->
          Result.map (fun next -> (expected, next)) (update expected))
    with
    | Error why -> refused why
    | Ok (expected, next) ->
        ( { t with editor = Some { form = submitted; success } },
          Screen.Save_attention { expected; next } )

let submit (env : Screen.env) t submitted =
  let stay notice =
    ({ t with editor = Some { form = Form.set_notice submitted notice; success = "" } }, Screen.Stay)
  in
  match Form.id submitted with
  | "add_attention" -> (
      let context = Option.value ~default:"" (Form.get_text submitted "context") in
      let due_kind_idx = Option.value ~default:0 (Form.get_choice submitted "due_kind") in
      let due_date = Option.value ~default:"" (Form.get_text submitted "due_date") in
      if String.trim context = "" then stay (tr "Enter a short household matter description.")
      else
        let due =
          match due_kind_idx with
          | 0 -> Ok Att.No_due_date
          | 1 -> Ok Att.Due_undetermined
          | 2 -> (
              match A.normalize_date due_date with
              | Error _ -> Error (tr "Invalid date (YYYY-MM-DD).")
              | Ok canon_day ->
                  if not (A.is_valid_canonical_date canon_day) then
                    Error (tr "Enter a real calendar date in YYYY-MM-DD form.")
                  else Ok (Att.Due_on canon_day))
          | _ -> Ok Att.No_due_date
        in
        match due with
        | Error notice -> stay notice
        | Ok due ->
            commit env t submitted
              (fun a -> Att.add_item a ~id:(Att.next_id a) ~context ~due)
              "Attention added and read back.")
  | "resolve_attention" ->
      let id = Form.payload submitted in
      commit env t submitted
        (fun a -> Att.close_item a ~id ~known_on:env.today ~kind:Att.Resolved)
        (Printf.sprintf "Resolved %s." id)
  | "drop_attention" ->
      let id = Form.payload submitted in
      commit env t submitted
        (fun a -> Att.close_item a ~id ~known_on:env.today ~kind:Att.Dropped)
        (Printf.sprintf "Dropped %s." id)
  | _ -> (t, Screen.Stay)

let handle (env : Screen.env) (geometry : Screen.geometry) t input =
  let stay t = (t, Screen.Stay) in
  let detail = t.pane = Detail_pane in
  match t.editor with
  | Some editor -> (
      match Form.handle_input editor.form input with
      | Form.Cancel -> stay { t with editor = None }
      | Form.Updated form -> stay { t with editor = Some { editor with form } }
      | Form.Submit submitted -> submit env t submitted)
  | None -> (
      let key = Ui_input.key_ignoring_case input in
      let page = max 1 (snd geometry.screen - 8) in
      match key with
      | Some ((`Escape | `ASCII 'q'), []) ->
          if detail then stay { t with pane = List_pane; scroll = 0 } else (t, Screen.Home)
      | Some ((`Enter | `ASCII 'i' | `Tab | `ASCII 'w'), []) | Some (`Tab, [ `Shift ]) ->
          stay { t with pane = (if detail then List_pane else Detail_pane); scroll = 0 }
      | Some (`ASCII 'n', []) ->
          stay { t with editor = Some { form = add_form ~today:env.today; success = "" } }
      | Some (`ASCII (('r' | 'x') as c), []) -> (
          match selected_item env t with
          | None ->
              ( t,
                Screen.Message
                  (tr
                     (if c = 'r' then "No attention item selected to resolve."
                      else "No attention item selected to drop.")) )
          | Some item ->
              let form =
                if c = 'r' then
                  close_form ~id:"resolve_attention" ~title:"Resolve Attention"
                    ~confirm:"Confirm Resolve" item
                else
                  close_form ~id:"drop_attention" ~title:"Drop Attention" ~confirm:"Confirm Drop"
                    item
              in
              stay { t with editor = Some { form; success = "" } })
      | Some (((`ASCII ('j' | 'k') | `Arrow (`Up | `Down)) as k), []) ->
          let delta = match k with `ASCII 'k' | `Arrow `Up -> -1 | _ -> 1 in
          if detail then stay { t with scroll = max 0 (t.scroll + delta) }
          else stay (move env t delta)
      | Some (`Page `Up, []) | Some (`ASCII 'u', [ `Ctrl ]) ->
          if detail then stay { t with scroll = max 0 (t.scroll - page) }
          else stay (move env t (-page))
      | Some (`Page `Down, []) | Some (`ASCII 'd', [ `Ctrl ]) ->
          if detail then stay { t with scroll = max 0 (t.scroll + page) }
          else stay (move env t page)
      | Some (`Home, []) ->
          if detail then stay { t with scroll = 0 } else stay (move env t (-max_int))
      | Some (`End, []) ->
          if detail then stay { t with scroll = max_int / 4 } else stay (move env t max_int)
      | _ -> (t, Screen.Ignored))

let saved _env _geometry result t =
  match (t.editor, result) with
  | Some editor, Ok () -> ({ t with editor = None }, Screen.Message editor.success)
  | Some editor, Error why ->
      ( {
          t with
          editor =
            Some
              {
                editor with
                form =
                  Form.set_notice editor.form
                    ("Attention not confirmed: " ^ why ^ " Reload to inspect before retrying.");
              };
        },
        Screen.Stay )
  | None, _ -> (t, Screen.Stay)

let rows (env : Screen.env) (geometry : Screen.geometry) t =
  let width, height = geometry.content in
  let width_of = geometry.width_of in
  let today = env.today in
  let items = open_items env in
  let left_title =
    match env.attention with
    | Ok a ->
        let s = Att.summarize ~today a in
        if s.overdue_count > 0 then
          Printf.sprintf "Attention (%d open • ! %d overdue)" (List.length items) s.overdue_count
        else Printf.sprintf "Attention (%d open)" (List.length items)
    | Error _ -> "Attention / Unavailable"
  in
  let left_width, right_width = Panel.split_widths width in
  let pad_w = max 0 (left_width - 4) in
  let col_due = 14 in
  let col_ctx = max 16 (pad_w - col_due - 4) in
  let th =
    "  " ^ O.pad ~width_of col_due "Due" ^ "  " ^ O.pad ~width_of col_ctx "Matter / Context"
  in
  let left_rows =
    match env.attention with
    | Error why ->
        O.wrap_text ~width_of
          (max 1 (left_width - 6))
          ("Attention unavailable: " ^ why ^ ". Writes refused; Ctrl-R reloads.")
    | Ok _ ->
        if items = [] then [ tr "No open attention items." ]
        else
          [ th; O.rule ~width_of pad_w ]
          @ List.mapi
              (fun idx (item : Att.item) ->
                (if idx = t.selected then "> " else "  ")
                ^ O.pad ~width_of col_due (Att.due_display ~today item.due)
                ^ "  " ^ item.context)
              items
  in
  let detail =
    match (env.attention, selected_item env t) with
    | Error why, _ ->
        [ "Attention unavailable (not empty)."; why; "Writes refused; Ctrl-R reloads." ]
    | Ok _, None ->
        [ tr "No selected attention item."; ""; tr "Press 'n' to add a household matter." ]
    | Ok _, Some item ->
        let urgency =
          match item.due with
          | Att.Due_on d ->
              if d < today then Printf.sprintf "! OVERDUE (due %s, today %s)" d today
              else if d = today then "DUE TODAY"
              else Printf.sprintf "Due on %s" d
          | Att.No_due_date -> "No due date specified"
          | Att.Due_undetermined -> "Due date undetermined / timing unknown"
        in
        [
          "Matter / Description:";
          "  " ^ item.context;
          "";
          "Urgency / Due:";
          "  " ^ urgency;
          "";
          "Item ID:    " ^ item.id;
          "Lifecycle:  Open (unresolved)";
          "";
          "Actions:";
          "  n : Add new attention item";
          "  r : Resolve this item (record completed)";
          "  x : Drop this item (abandon/cancel)";
          "";
          "Navigation:";
          "  Tab / i : Toggle detail scroll";
          "  j / k   : Select next/previous matter";
          "  q / Esc : Return to Home";
        ]
  in
  let is_detail = t.pane = Detail_pane in
  Panel.split ~width_of ~width ~height ~left_focused:(not is_detail) ~left_title ~left_scroll:0
    ~left_selected:(if items = [] then None else Some (t.selected + 2))
    ~left_rows ~right_focused:is_detail ~right_title:"Selected matter"
    ~right_scroll:(if is_detail then t.scroll else 0)
    ~right_selected:None
    ~right_rows:(List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) detail)
    ()

let view env (geometry : Screen.geometry) t =
  let overlay =
    Option.bind (form t)
      (Ui_overlay.form ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body)
  in
  {
    Screen.title = tr "Attention";
    subtitle = Default;
    rows = lazy (rows env geometry t);
    footer =
      (match (t.editor, t.pane) with
      | Some _, _ ->
          [ "Enter submit  Tab next field  Esc cancel"; "Arrow keys / space to choose options" ]
      | None, List_pane ->
          [
            "n new  r resolve  x drop  j/k select  Enter/Tab detail";
            "q/Esc Home  Space Commands  Ctrl-r reload";
          ]
      | None, Detail_pane ->
          [
            "j/k scroll  Tab list  n new  r resolve  x drop";
            "q/Esc back to list  Space Commands  Ctrl-r reload";
          ]);
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
