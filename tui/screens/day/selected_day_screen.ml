(* Selected Day owns its retained browser, two panes and deferred search. *)
module RB = Record_browser
module O = Daily_overlays
module Panel = Ui_panel
let tr = Ui_text.tr

type pane = List | Detail
type t = {
  day : string;
  browser : RB.t;
  pane : pane;
  scroll : int;
  search : string option;
  parent : string option;
}

let config_files = []
let create () = { day = ""; browser = RB.empty; pane = List; scroll = 0; search = None; parent = None }
let enter route ~focus_day:_ t = match route with
  | Screen.Selected_day day -> { t with day; pane = List; scroll = 0; search = None; parent = None }
  | _ -> t
let browser t = t.browser
let with_browser t browser = { t with browser }
let detail_focused t = t.pane = Detail
let scroll t = t.scroll
let modal t = Option.is_some t.search
let rows book t = RB.all_rows book |> List.filter (fun row -> RB.date row = t.day) |> RB.visible ~book t.browser
let synced book t = { t with browser = RB.sync t.browser (rows book t) }
let selected_row book t = RB.selected_row t.browser (rows book t)
let drill ~entry ~parent t =
  { t with browser = { t.browser with selected_id = Some (RB.Actual_row, entry);
    query = ""; locus = None; day = None }; parent = Some parent }
let book_changed ~before:_ ~after t = (synced after { t with scroll = 0 }, "")
let reloaded env t = ((if env.Screen.blocked then t else { t with scroll = 0 }), Screen.Stay)
let saved _env _geometry _result t = (t, Screen.Stay)

let input_text value = function
  | `Key (`ASCII c, []) when Char.code c >= 32 && Char.code c <> 127 -> Some (value ^ String.make 1 c)
  | `Key (`Uchar c, []) when O.printable_uchar c -> Some (value ^ O.utf8 c)
  | `Key (`Backspace, []) -> Some (Daily_form.backspace value)
  | _ -> None

let handle (env : Screen.env) (geometry : Screen.geometry) t input =
  let book = env.book in
  let stay t = (t, Screen.Stay) in
  let move delta = { t with browser = RB.move t.browser (rows book t) delta } in
  let action action =
    let target = Option.map (function RB.Actual_entry e -> Screen.Entry e | RB.Scheduled_plan p -> Screen.Plan p)
        (selected_row book t) in
    (t, Screen.Record_action { action; target }) in
  match t.search with
  | Some value -> (
      match input with
      | `Key (`Escape, []) -> stay (synced book { t with browser = RB.with_query t.browser ""; search = None; scroll = 0 })
      | `Key (`Enter, []) -> stay (synced book { t with browser = RB.with_query t.browser value; search = None; scroll = 0 })
      | _ -> stay (match input_text value input with None -> t | Some value -> { t with search = Some value }))
  | None ->
      let key = match input with
        | `Key (`ASCII c, mods) -> Some (`ASCII (Char.lowercase_ascii c), mods)
        | `Key (key, mods) -> Some (key, mods)
        | _ -> None in
      match key with
      | Some ((`Escape | `ASCII 'q'), []) ->
          if t.pane = Detail then stay { t with pane = List; scroll = 0 } else (t, Screen.Back)
      | Some (`ASCII 'g', []) -> (t, Screen.Open_route Screen.Loci)
      | Some (`ASCII 'b', []) -> action Screen.Batch
      | Some (`ASCII 'd', []) -> action Screen.Correct_date
      | Some (`ASCII 'm', []) -> action Screen.Classify_merchant
      | Some (`ASCII ('c' | 'e'), []) | Some (`ASCII 'e', [ `Ctrl ]) -> action Screen.Edit
      | Some (`ASCII 'x', []) -> (
          match selected_row book t with
          | Some (RB.Scheduled_plan _) -> action Screen.Cancel
          | Some (RB.Actual_entry _) -> action Screen.Reverse
          | None -> stay t)
      | Some (`ASCII ('r' | 'n'), []) -> (t, Screen.New_record)
      | Some (`ASCII '/', []) -> stay { t with search = Some t.browser.query }
      | Some ((`Tab | `ASCII 'w'), []) | Some (`Tab, [ `Shift ]) ->
          stay { t with pane = (if t.pane = List then Detail else List); scroll = 0 }
      | Some ((`Enter | `ASCII 'i'), []) -> stay { t with pane = Detail; scroll = 0 }
      | Some ((`ASCII ('j' | 'k') | `Arrow (`Up | `Down)) as key, []) ->
          let delta = match key with `ASCII 'k' | `Arrow `Up -> -1 | _ -> 1 in
          if t.pane = Detail then stay { t with scroll = max 0 (t.scroll + delta) }
          else stay { (move delta) with scroll = 0 }
      | Some (`Page _ as key, []) | Some (`ASCII ('u' | 'd') as key, [ `Ctrl ]) ->
          let delta = match key with `Page `Up | `ASCII 'u' -> -1 | _ -> 1 in
          let step = delta * max 1 (snd geometry.screen - 8) in
          if t.pane = List then stay { (move step) with scroll = 0 }
          else stay { t with scroll = max 0 (t.scroll + step) }
      | Some (`Home, []) -> stay { (move (-max_int)) with scroll = 0 }
      | Some (`End, []) -> stay { (move max_int) with scroll = max_int / 4 }
      | _ -> (t, Screen.Ignored)

let detail_rows ~width_of ~width book t =
  let lines = match selected_row book t with
    | Some (RB.Actual_entry e) -> O.entry_lines book e
    | Some (RB.Scheduled_plan p) -> O.plan_lines book p
    | None -> [ tr "No selected record." ] in
  List.concat_map (O.wrap_text ~width_of (max 1 (width - 6))) lines

let paint (env : Screen.env) (geometry : Screen.geometry) t =
  let width, height = geometry.content in
  let rows = rows env.book t in
  let left_width, right_width = Panel.split_widths width in
  let detail = t.pane = Detail in
  Panel.split ~width_of:geometry.width_of ~width ~height
    ~left_focused:(not detail) ~left_title:(Printf.sprintf "Day %s (%d)" t.day (List.length rows))
    ~left_scroll:(if detail then 0 else t.scroll)
    ~left_selected:(if rows = [] then None else Some t.browser.selected)
    ~left_rows:(if rows = [] then [ tr "No records in this view." ]
      else snd (Record_lines.actual_table ~width_of:geometry.width_of ~width:left_width env.book rows))
    ~right_focused:detail ~right_title:"Selected Record"
    ~right_scroll:(if detail then t.scroll else 0) ~right_selected:None
    ~right_rows:(detail_rows ~width_of:geometry.width_of ~width:right_width env.book t) ()

let view env (geometry : Screen.geometry) t =
  let overlay = Option.bind t.search (fun value ->
      let body_w, _ = geometry.body in
      Ui_overlay.form ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body
        ~pane_width:(min 54 (max 8 (body_w - 4)))
        (Ui_form.create ~id:"search" ~title:(tr "Search Actual / Scheduled")
          ~fields:[ Ui_form.text_field ~id:"value" ~label:"" ~value () ]
          ~notice:(tr "Enter apply; Esc clear") ())) in
  { Screen.title = tr "Selected Day";
    subtitle = Screen.Text (t.day ^ "   " ^ tr "Day" ^ tr " view");
    rows = lazy (paint env geometry t);
    footer = (if t.pane = Detail then
      [ "j/k scroll  Page Up/Down page  Home/End range"; "q/Esc back  Space Commands  Ctrl-r reload" ]
      else [ "j/k select  Enter/i/Tab Detail  c Correct  d Date  x Reverse  m Merchant  e Extend  b Batch  g Loci  r Record";
        (if t.parent = Some "Actual" then "Space Commands  q/Esc Actual  Ctrl-r reload"
         else "Space Commands  q/Esc Home  Ctrl-r reload") ]);
    overlay; cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor) }
