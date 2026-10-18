(* Scheduled: explicit plans as a filtered List or a six-month Months view,
   with a detail pane. Completion, editing, cancellation, batch amounts and
   generation of the selected plan are record actions handled by the Shell. *)
module B = Bakhlo_sexp.Daily_book
module O = Daily_overlays
module RB = Record_browser
module Months = Scheduled_months
module Panel = Ui_panel

let tr = Ui_text.tr

type view = List_view | Months_view
type pane = List_pane | Detail_pane

type t = {
  view : view;
  list : RB.t;
  months_list : RB.t;
  months : Months.t;
  pane : pane;
  scroll : int;
  search : string option;  (* the search input while it is open *)
}

let config_files = []

let create months =
  { view = List_view; list = RB.empty; months_list = { RB.empty with order = RB.Oldest }; months;
    pane = List_pane; scroll = 0; search = None }

let modal t = Option.is_some t.search
let months_view t = t.view = Months_view
let detail_focused t = t.pane = Detail_pane
let scroll t = t.scroll
let months t = t.months
let list_browser t = t.list
let reloaded _env t = ({ t with scroll = 0 }, Screen.Stay)
let saved _env _geometry _result t = (t, Screen.Stay)

let browser t = match t.view with List_view -> t.list | Months_view -> t.months_list
let with_browser t b = match t.view with List_view -> { t with list = b } | Months_view -> { t with months_list = b }

let rows book t =
  let plans = List.map (fun p -> RB.Scheduled_plan p) (B.open_plans book) in
  match t.view with
  | Months_view -> RB.sorted RB.Oldest plans
  | List_view -> RB.visible ~book t.list plans

(* The selection always follows the remembered plan identity in the current book. *)
let synced book t = with_browser t (RB.sync (browser t) (rows book t))
let selected_plan book t =
  let t = synced book t in
  match RB.selected_row (browser t) (rows book t) with
  | Some (RB.Scheduled_plan p) -> Some p
  | _ -> None

let book_changed ~before:_ ~after t = (synced after { t with scroll = 0 }, "")

let follow_months book t =
  match t.view, selected_plan book t with
  | Months_view, Some plan -> { t with months = Months.follow t.months plan.B.day }
  | _ -> t

let detail_rows ~width_of ~width book t =
  let lines = match selected_plan book t with
    | Some plan -> O.plan_lines book plan
    | None -> [ tr "No selected record." ] in
  List.concat_map (O.wrap_text ~width_of (max 1 (width - 6))) lines

let detail_window (env : Screen.env) (geometry : Screen.geometry) t =
  let width, height = geometry.content in
  let detail_width = if months_view t then width else snd (Panel.split_widths width) in
  let count = List.length (detail_rows ~width_of:geometry.width_of ~width:detail_width env.book t) in
  (height, Panel.window ~capacity:(Panel.capacity ~height ~heading:false) ~count ~scroll:t.scroll ~selected:None)

let with_query book t query = synced book (with_browser t (RB.with_query (browser t) query))

let toggle_view book t =
  let selected_id = Option.map RB.identity (RB.selected_row (browser (synced book t)) (rows book t)) in
  let destination = { t with view = (match t.view with Months_view -> List_view | List_view -> Months_view) } in
  let destination =
    match selected_id with
    | Some id when List.exists (fun row -> RB.identity row = id) (rows book destination) ->
        with_browser destination { (browser destination) with selected_id }
    | _ -> destination
  in
  follow_months book (synced book destination)

let action book t action =
  (t, Screen.Record_action { action; target = Option.map (fun p -> Screen.Plan p) (selected_plan book t) })

let unless_blocked (env : Screen.env) message = if env.blocked then Screen.Stay else Screen.Message message

let input_text value = function
  | `Key (`ASCII c, []) when Char.code c >= 32 && Char.code c <> 127 -> Some (value ^ String.make 1 c)
  | `Key (`Uchar c, []) when O.printable_uchar c -> Some (value ^ O.utf8 c)
  | `Key (`Backspace, []) -> Some (Daily_form.backspace value)
  | _ -> None

let handle (env : Screen.env) (geometry : Screen.geometry) t input =
  let book = env.book in
  let stay t = (t, Screen.Stay) in
  match t.search with
  | Some value -> (
      match input with
      | `Key (`Escape, []) -> stay (synced book { (with_browser t (RB.with_query (browser t) "")) with search = None; scroll = 0 })
      | `Key (`Enter, []) -> stay (synced book { (with_browser t (RB.with_query (browser t) value)) with search = None; scroll = 0 })
      | _ -> stay (match input_text value input with None -> t | Some value -> { t with search = Some value }))
  | None -> (
      let _, view = detail_window env geometry t in
      let t = { t with scroll = view.start } in
      let key = match input with
        | `Key (`ASCII c, mods) -> Some (`ASCII (Char.lowercase_ascii c), mods)
        | `Key (key, mods) -> Some (key, mods)
        | _ -> None
      in
      let months = months_view t and detail = t.pane = Detail_pane in
      let toggle_pane t = { t with pane = (if t.pane = List_pane then Detail_pane else List_pane) } in
      match key with
      | Some ((`Escape | `ASCII ('q')), []) ->
          if detail then stay { t with pane = List_pane; scroll = 0 } else (t, Screen.Back)
      | Some (`ASCII 'b', []) -> action book t Screen.Batch
      | Some (`ASCII 'g', []) -> action book t Screen.Generate
      | Some (`ASCII 'v', []) -> (toggle_view book { t with scroll = 0 }, unless_blocked env "")
      | Some ((`ASCII ('h' | 'l') | `Arrow (`Left | `Right)) as k, []) when months && not detail -> (
          let delta = match k with `ASCII 'h' | `Arrow `Left -> -1 | _ -> 1 in
          match Months.shift t.months delta with
          | Ok months -> stay { t with months }
          | Error message -> (t, unless_blocked env message))
      | Some (`ASCII ('f' | '/'), []) when months ->
          (t, unless_blocked env "Months uses all current-open plans; v opens filtered List.")
      | Some (`Enter, []) when months -> action book t Screen.Pay
      | Some (`ASCII 'r', []) when months -> action book t Screen.Edit
      | Some ((`ASCII ('h' | 'l') | `Arrow (`Left | `Right)), []) -> stay { (toggle_pane t) with scroll = 0 }
      | Some (((`Home | `End | `Page _ | `ASCII ('j' | 'k') | `Arrow (`Up | `Down)) as k), [])
      | Some ((`ASCII ('u' | 'd') as k), [ `Ctrl ]) ->
          let height, view = detail_window env geometry t in
          let page = max 1 (if detail then view.capacity else if months then 8
                            else Panel.capacity ~height ~heading:false) in
          let delta = match k with
            | `Home -> -max_int | `End -> max_int
            | `Page `Up | `ASCII 'u' -> -page | `Page `Down | `ASCII 'd' -> page
            | `ASCII 'k' | `Arrow `Up -> -1 | _ -> 1 in
          if detail then stay { t with scroll = Panel.move ~last:view.last ~position:view.start delta }
          else
            let t = synced book t in
            stay (follow_months book { (with_browser t (RB.move (browser t) (rows book t) delta)) with scroll = 0 })
      | Some ((`Tab | `ASCII 'w'), []) | Some (`Tab, [ `Shift ]) -> stay (toggle_pane t)
      | Some (`ASCII '/', []) -> stay { t with search = Some (browser t).query }
      | Some (`ASCII ('r' | 'n'), []) -> (t, Screen.New_plan)
      | Some (`ASCII ('f'), []) ->
          stay (synced book (with_browser { t with scroll = 0 } (RB.toggle_day (browser t) ~focus_day:env.calendar.selected_day)))
      | Some (`ASCII 'x', []) -> action book t Screen.Cancel
      | Some (`ASCII 'c', []) -> action book t Screen.Pay
      | Some (`ASCII 'e', ([] | [ `Ctrl ])) -> action book t Screen.Edit
      | Some ((`Enter | `ASCII 'i'), []) -> stay { t with pane = Detail_pane; scroll = 0 }
      | _ -> (t, Screen.Ignored))

let enter ~focus_day:_ t = { t with pane = List_pane; scroll = 0; search = None }

let paint (env : Screen.env) (geometry : Screen.geometry) t =
  let book = env.book and width_of = geometry.width_of in
  let width, height = geometry.content in
  let t = synced book t in
  let rows = rows book t in
  let is_detail = t.pane = Detail_pane in
  match t.view with
  | Months_view ->
      if is_detail then
        Panel.frame ~width_of ~width ~height ~focused:true ~title:"Selected Scheduled"
          ~scroll:t.scroll ~selected:None (detail_rows ~width_of ~width book t)
      else
        let plans = List.filter_map (function RB.Scheduled_plan p -> Some p | _ -> None) rows in
        Months.screen ~book ~plans ~dimensions:(width, height) ~width_of ~selected:(selected_plan book t) t.months
  | List_view ->
      let left_width, right_width = Panel.split_widths width in
      Panel.split ~width_of ~width ~height
        ~left_focused:(not is_detail) ~left_title:(Printf.sprintf "Scheduled / List (%d)" (List.length rows))
        ~left_scroll:(if is_detail then 0 else t.scroll)
        ~left_selected:(if rows = [] then None else Some (browser t).selected)
        ~left_rows:(if rows = [] then [ tr "No records in this view." ]
                    else Record_lines.scheduled_table ~width_of ~width:left_width book rows)
        ~right_focused:is_detail ~right_title:"Plan Detail"
        ~right_scroll:(if is_detail then t.scroll else 0)
        ~right_selected:None ~right_rows:(detail_rows ~width_of ~width:right_width book t) ()

let footer (geometry : Screen.geometry) t =
  match t.view, t.pane with
  | Months_view, Detail_pane ->
      [ "j/k PgUp/Dn Home/End scroll  Tab Months"; "Enter/c complete  g generate  b batch  x cancel  v List  q back" ]
  | Months_view, List_pane ->
      if fst geometry.screen < 46 then [ "j/k select  h/l months  v List"; "Enter complete  x cancel  q back" ]
      else
        [ "j/k select  h/l months  Enter/c complete  q back";
          "i/Tab detail  b batch  r/e edit  g generate  x cancel  n new  v List" ]
  | List_view, List_pane ->
      [ "j/k select  Enter/i/Tab Detail  h/l pane  c Complete  e Edit  g Generate  x Cancel";
        "b Batch amount  v Months  n New Plan  f Filter  / search  Space Commands  q/Esc Home" ]
  | List_view, Detail_pane ->
      [ "j/k scroll  Page Up/Down page  Home/End range  h/l/Tab pane";
        "b Batch amount  v Months  q/Esc list  c Complete  e Edit  g Generate  x Cancel  n New Plan  Ctrl-r reload" ]

let view env (geometry : Screen.geometry) t =
  let overlay = Option.bind t.search (fun value ->
      let body_w, _ = geometry.body in
      Ui_overlay.form ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body
        ~pane_width:(min 54 (max 8 (body_w - 4)))
        (Ui_form.create ~id:"search" ~title:(tr "Search Actual / Scheduled")
           ~fields:[ Ui_form.text_field ~id:"value" ~label:"" ~value () ]
           ~notice:(tr "Enter apply; Esc clear") ())) in
  {
    Screen.title = tr (if months_view t then "Scheduled / Months" else "Scheduled");
    subtitle = (if months_view t then Screen.Text "Explicit current-open plans; no recurrence inferred."
                else Screen.Default);
    rows = lazy (paint env geometry t);
    footer = footer geometry t;
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
