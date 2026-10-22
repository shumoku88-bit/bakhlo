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

module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module Cal = Daily_calendar

(* The unresolved holding Locus: Effects whose real account is not known yet.
   It is not an account and never takes a role. *)
let suspense_locus = "suspense"

type holding = {
  balances : (string * string) list;  (** Formatted exact balance, or "unknown". *)
  entries : int;  (** Actual entries touching the holding Locus. *)
  oldest : string option;
  age_days : int option;
}

let suspense_holding (env : Screen.env) : holding option =
  let book = env.book in
  let entries, oldest =
    List.fold_left
      (fun (count, oldest) (entry : B.entry) ->
        if
          List.exists
            (fun posting -> A.lstr (D.Effect.locus posting) = suspense_locus)
            entry.effects
        then
          let oldest =
            match oldest with None -> Some entry.day | Some day -> Some (min day entry.day)
          in
          (count + 1, oldest)
        else (count, oldest))
      (0, None) (B.entries book)
  in
  if entries = 0 then None
  else
    (* Zero hides, an exact non-zero shows, and no support is "unknown", never 0. *)
    let balances =
      List.filter_map
        (fun (measure, _) ->
          match O.quantity_value ~book ~measure suspense_locus with
          | O.Exact quantity when Z.equal quantity Z.zero -> None
          | O.Exact quantity ->
              Some (measure, O.format_money book measure quantity ^ " " ^ measure)
          | O.Known_present -> Some (measure, "unknown")
          | O.Unsupported -> Some (measure, "unknown (no history support)"))
        (B.measures book)
    in
    if balances = [] then None
    else
      let age_days =
        match oldest with
        | None -> None
        | Some day -> (
            match (Cal.day_index env.today, Cal.day_index day) with
            | Ok today, Ok then_ -> Some (max 0 (today - then_))
            | _ -> None)
      in
      Some { balances; entries; oldest; age_days }

let open_items (env : Screen.env) =
  match env.attention with Ok t -> Att.open_items t | Error _ -> []
(* One selectable row: the derived holding signal first, then household matters. *)
type row = Holding of holding | Matter of Att.item

let row_list env =
  let matters = List.map (fun item -> Matter item) (open_items env) in
  match suspense_holding env with Some holding -> Holding holding :: matters | None -> matters

let holding_line ~width_of ~col_due ~col_ctx (holding : holding) =
  let texts = List.map snd holding.balances in
  let balances =
    match texts with
    | first :: _ when List.for_all (fun text -> text = first) texts ->
        Printf.sprintf "%d Measures: %s" (List.length texts) first
    | _ -> String.concat " · " texts
  in
  let age =
    match (holding.oldest, holding.age_days) with
    | Some day, Some days -> Printf.sprintf " · oldest %s (%d d)" day days
    | Some day, None -> " · oldest " ^ day
    | None, _ -> ""
  in
  O.pad ~width_of col_due "! holding"
  ^ "  "
  ^ O.pad ~width_of col_ctx
      (Printf.sprintf "suspense: %s · %d %s%s" balances holding.entries
         (if holding.entries = 1 then "entry" else "entries")
         age)
let holding_detail (holding : holding) =
  [
    "Suspense holding (unresolved recording):";
    "  " ^ suspense_locus;
    "";
    "Balances:";
  ]
  @ List.map
      (fun (measure, text) -> Printf.sprintf "  %s: %s" (String.uppercase_ascii measure) text)
      holding.balances
  @ [
      "";
      Printf.sprintf "Actual entries touching suspense: %d" holding.entries;
      (match (holding.oldest, holding.age_days) with
      | Some day, Some days -> Printf.sprintf "Oldest such entry: %s (%d days ago)" day days
      | Some day, None -> "Oldest such entry: " ^ day
      | None, _ -> "No Actual entry touches suspense.");
      "";
      "This Locus holds Effects whose real account is not yet known. It is not an";
      "account: it takes no role and is excluded from role summaries.";
      "Resolve it by correcting those entries in Actual:";
      "  /  search \"suspense\"    c  Correct the entry to its real Locus";
      "";
      "Actions:";
      "  n : Add new attention item";
      "  Tab / i : Toggle detail scroll";
      "  j / k   : Select next/previous row";
      "  q / Esc : Return to Home";
    ]

let selected_row env t = List.nth_opt (row_list env) t.selected

(* Only a household matter can be resolved or dropped; the holding signal names
   its own route instead. *)
let selected_item env t =
  match selected_row env t with Some (Matter item) -> Some item | _ -> None

let move env t delta =
  let count = List.length (row_list env) in
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
          match selected_row env t with
          | Some (Holding _) ->
              ( t,
                Screen.Message
                  (tr
                     "Suspense is unresolved recording, not a matter: correct those entries in \
                      Actual (/ search, then c).") )
          | _ -> (
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
              stay { t with editor = Some { form; success = "" } }))
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
  let rows = row_list env in
  let holding = suspense_holding env in
  let left_title =
    match env.attention with
    | Ok a ->
        let s = Att.summarize ~today a in
        let marker = if Option.is_some holding then " • suspense" else "" in
        if s.overdue_count > 0 then
          Printf.sprintf "Attention (%d open • ! %d overdue%s)" (List.length items)
            s.overdue_count marker
        else Printf.sprintf "Attention (%d open%s)" (List.length items) marker
    | Error _ -> "Attention / Unavailable"
  in
  let left_width, right_width = Panel.split_widths width in
  let pad_w = max 0 (left_width - 4) in
  let col_due = 14 in
  let col_ctx = max 16 (pad_w - col_due - 4) in
  let th =
    "  " ^ O.pad ~width_of col_due "Due" ^ "  " ^ O.pad ~width_of col_ctx "Matter / Context"
  in
  (* The frame itself paints the selection marker for this row. *)
  let row_text _idx (row : row) =
    match row with
    | Holding h -> holding_line ~width_of ~col_due ~col_ctx h
    | Matter item ->
        O.pad ~width_of col_due (Att.due_display ~today item.due) ^ "  " ^ item.context
  in
  let left_rows =
    match env.attention with
    | Error why ->
        O.wrap_text ~width_of
          (max 1 (left_width - 6))
          ("Attention unavailable: " ^ why ^ ". Writes refused; Ctrl-R reloads.")
    | Ok _ ->
        if rows = [] then [ tr "No open attention items." ]
        else [ th; O.rule ~width_of pad_w ] @ List.mapi row_text rows
  in
  let detail =
    match (env.attention, selected_row env t) with
    | Error why, _ ->
        [ "Attention unavailable (not empty)."; why; "Writes refused; Ctrl-R reloads." ]
    | Ok _, Some (Holding h) -> holding_detail h
    | Ok _, Some (Matter item) ->
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
    | Ok _, None ->
        [ tr "No selected attention item."; ""; tr "Press 'n' to add a household matter." ]
  in
  let is_detail = t.pane = Detail_pane in
  Panel.split ~width_of ~width ~height ~left_focused:(not is_detail) ~left_title ~left_scroll:0
    ~left_selected:(if rows = [] then None else Some (t.selected + 2))
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
