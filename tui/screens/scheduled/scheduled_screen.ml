(* Scheduled: LOAM's Series Calendar over scheduled-coverage.tsv (with one
   monitored plan's occurrences and gaps), a six-month Months view and a
   filtered List with a detail pane. Completion, editing, cancellation, batch amounts and
   generation of the selected plan are record actions handled by the Shell. *)
module B = Bakhlo_sexp.Daily_book
module O = Daily_overlays
module RB = Record_browser
module Months = Scheduled_months
module Panel = Ui_panel
module Cov = Scheduled_coverage

let tr = Ui_text.tr

type view = Coverage_view | Plan_view | Months_view | List_view
type pane = List_pane | Detail_pane

type t = {
  view : view;
  list : RB.t;
  months_list : RB.t;
  months : Months.t;
  pane : pane;
  scroll : int;
  search : string option;  (* the search input while it is open *)
  coverage_row : int;
  coverage_offset : int;  (* first visible coverage month *)
  plan_row : int;
}

let coverage_file = "scheduled-coverage.tsv"
let config_files = [ coverage_file ]
let coverage_months = 18

let create months =
  { view = Coverage_view; list = RB.empty; months_list = { RB.empty with order = RB.Oldest }; months;
    pane = List_pane; scroll = 0; search = None; coverage_row = 0; coverage_offset = 0; plan_row = 0 }

(* Monitoring rules are read-side configuration; a missing file is no rule, a
   malformed or unreadable one is an explicit error, never an empty overview. *)
let coverage (env : Screen.env) =
  match env.config coverage_file with
  | Error why -> Error why
  | Ok None -> Ok ([], [])
  | Ok (Some text) ->
      Result.bind (Cov.of_string text) (fun rules ->
          Cov.project rules ~plans:(B.plans env.book) ~today:env.today ~months:coverage_months)

(* Without any configured rule the overview has nothing to show, so the List
   (with Months) stays the entrance, as before monitoring existed. *)
let monitored env = match coverage env with Ok (_, []) -> false | Ok _ | Error _ -> true
let current env t =
  match t.view with (Coverage_view | Plan_view) when not (monitored env) -> List_view | v -> v

let modal t = Option.is_some t.search
let months_view t = t.view = Months_view
let detail_focused t = t.pane = Detail_pane
let scroll t = t.scroll
let months t = t.months
let list_browser t = t.list
let reloaded _env t = ({ t with scroll = 0 }, Screen.Stay)
let saved _env _geometry _result t = (t, Screen.Stay)

let browser t = match t.view with
  | Coverage_view | Plan_view | List_view -> t.list | Months_view -> t.months_list
let with_browser t b = match t.view with
  | Coverage_view | Plan_view | List_view -> { t with list = b }
  | Months_view -> { t with months_list = b }

let rows book t =
  let plans = List.map (fun p -> RB.Scheduled_plan p) (B.open_plans book) in
  match t.view with
  | Months_view -> RB.sorted RB.Oldest plans
  | Coverage_view | Plan_view | List_view -> RB.visible ~book t.list plans

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

(* LOAM order: overview -> Months -> List -> overview; a plan returns to its overview. *)
let toggle_view env book t =
  let t = { t with view = current env t } in
  let selected_id = Option.map RB.identity (RB.selected_row (browser (synced book t)) (rows book t)) in
  let view = match t.view with
    | Coverage_view -> Months_view
    | Plan_view -> Coverage_view
    | Months_view -> List_view
    | List_view -> if monitored env then Coverage_view else Months_view in
  let destination = { t with view } in
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

(* --- Series Calendar (LOAM ScheduledCoveragePane) and one plan's entries --- *)

type plan_entry = Occurrence of B.plan * bool (* on pace *) | Missing_month of string

let coverage_rows env = match coverage env with Ok (_, rows) -> rows | Error _ -> []
let clamp_index count i = if count = 0 then 0 else max 0 (min (count - 1) i)

let selected_rule env t =
  let rows = coverage_rows env in
  List.nth_opt rows (clamp_index (List.length rows) t.coverage_row)

let plan_entries (env : Screen.env) (row : Cov.row) =
  let explicit = List.map (fun (p : B.plan) -> (p.day, Occurrence (p, Cov.expected_on row.rule p.day)))
      (Cov.plans_for row.rule (B.plans env.book)) in
  let gaps = List.filter_map (fun (c : Cov.cell) ->
      if Cov.missing c then Some (c.month ^ "-00", Missing_month c.month) else None) row.cells in
  List.map snd (List.stable_sort (fun (a, _) (b, _) -> String.compare a b) (explicit @ gaps))

let selected_entry env t =
  Option.bind (selected_rule env t) (fun row ->
      let entries = plan_entries env row in
      List.nth_opt entries (clamp_index (List.length entries) t.plan_row))

(* LOAM extends from the latest current-open occurrence of the monitored shape. *)
let latest_plan env t =
  Option.bind (selected_rule env t) (fun row ->
      List.fold_left (fun _ p -> Some p) None (Cov.plans_for row.rule (B.plans env.book)))

let pace_width width = if width >= 31 then 11 else 0
let plan_width width = min 28 (max 2 (width - pace_width width - 8))
let month_window width = max 0 ((width - plan_width width - pace_width width) / 8)
let trailing_start selected capacity = if selected < capacity then 0 else selected + 1 - capacity

let flow ~width_of width tokens =
  List.rev (List.fold_left (fun lines token ->
      match lines with
      | current :: rest when width_of (current ^ " " ^ token) <= width -> (current ^ " " ^ token) :: rest
      | _ -> token :: lines) [] tokens)

let not_connected = "Not connected in Bakhlo yet; use List (v) for explicit plan edits."

let handle_coverage (env : Screen.env) t key =
  let stay t = (t, Screen.Stay) and say t m = (t, unless_blocked env m) in
  let count = List.length (coverage_rows env) in
  let row = clamp_index count t.coverage_row in
  let months = match coverage env with Ok (months, _) -> List.length months | Error _ -> 0 in
  match key with
  | Some (`ASCII ('k'), []) | Some (`Arrow `Up, []) ->
      if row = 0 then say t "No previous recurring plan." else stay { t with coverage_row = row - 1 }
  | Some (`ASCII ('j'), []) | Some (`Arrow `Down, []) ->
      if row + 1 < count then stay { t with coverage_row = row + 1 } else say t "No next recurring plan."
  | Some (`Page `Up, []) | Some (`ASCII 'u', [ `Ctrl ]) -> stay { t with coverage_row = row - min row 8 }
  | Some (`Page `Down, []) | Some (`ASCII 'd', [ `Ctrl ]) ->
      stay { t with coverage_row = clamp_index count (row + 8) }
  | Some (`Home, []) -> stay { t with coverage_row = 0 }
  | Some (`End, []) -> stay { t with coverage_row = max 0 (count - 1) }
  | Some (`ASCII 'h', []) | Some (`Arrow `Left, []) ->
      if t.coverage_offset = 0 then say t "Already at the first coverage month."
      else stay { t with coverage_offset = t.coverage_offset - 1 }
  | Some (`ASCII 'l', []) | Some (`Arrow `Right, []) ->
      if months = 0 then say t "Coverage months are unavailable."
      else if t.coverage_offset + 1 < months then stay { t with coverage_offset = t.coverage_offset + 1 }
      else say t "No later coverage month is loaded."
  | Some (`Enter, []) | Some (`ASCII 'i', []) ->
      if count = 0 then say t "No recurring plan is selected."
      else stay { t with view = Plan_view; coverage_row = row; plan_row = 0 }
  | Some (`ASCII 'f', []) -> say t "The overview always uses the current-open frontier."
  | Some (`ASCII ('c'), []) ->
      say t "Press Enter to inspect the selected plan before completing one occurrence."
  | Some (`ASCII ('r'), []) ->
      say t "Press Enter to inspect the selected plan before replacing one occurrence."
  | Some (`ASCII ('x'), []) ->
      say t "Press Enter to inspect the selected plan before cancelling one occurrence."
  | Some (`ASCII 'b', []) -> (
      match latest_plan env t with
      | Some p -> (t, Screen.Record_action { action = Screen.Batch; target = Some (Screen.Plan p) })
      | None -> say t "Select an explicit Scheduled reference for batch amount editing.")
  | Some (`ASCII ('e' | 'p' | 's' | 'g' | 'm'), []) -> say t not_connected
  | Some (`ASCII 'v', []) -> (toggle_view env env.book t, unless_blocked env "")
  | Some (`ASCII 'n', []) -> (t, Screen.New_plan)
  | Some ((`Escape | `ASCII 'q'), []) -> (t, Screen.Back)
  | _ -> (t, Screen.Ignored)

let handle_plan (env : Screen.env) t key =
  let stay t = (t, Screen.Stay) and say t m = (t, unless_blocked env m) in
  let count = match selected_rule env t with Some row -> List.length (plan_entries env row) | None -> 0 in
  let at = clamp_index count t.plan_row in
  let explicit action =
    match selected_entry env { t with plan_row = at } with
    | Some (Occurrence (p, _)) -> (t, Screen.Record_action { action; target = Some (Screen.Plan p) })
    | Some (Missing_month _) ->
        say t "The selected row is a missing monitored month, not an explicit Scheduled occurrence."
    | None -> say t "Plan details are unavailable."
  in
  match key with
  | Some (`ASCII 'k', []) | Some (`Arrow `Up, []) ->
      if at = 0 then say t "Already at the first plan entry." else stay { t with plan_row = at - 1 }
  | Some (`ASCII 'j', []) | Some (`Arrow `Down, []) ->
      if at + 1 < count then stay { t with plan_row = at + 1 } else say t "Already at the last plan entry."
  | Some (`Page `Up, []) | Some (`ASCII 'u', [ `Ctrl ]) -> stay { t with plan_row = at - min at 8 }
  | Some (`Page `Down, []) | Some (`ASCII 'd', [ `Ctrl ]) -> stay { t with plan_row = clamp_index count (at + 8) }
  | Some (`Home, []) -> stay { t with plan_row = 0 }
  | Some (`End, []) -> stay { t with plan_row = max 0 (count - 1) }
  | Some (`ASCII ('h' | 'l'), []) | Some (`Arrow (`Left | `Right), []) ->
      say t "Plan Detail uses one vertical plan list; j/k moves the selection."
  | Some ((`Enter | `ASCII 'c'), []) -> explicit Screen.Pay
  | Some (`ASCII 'r', []) -> explicit Screen.Edit
  | Some (`ASCII 'x', []) -> explicit Screen.Cancel
  | Some (`ASCII 'b', []) -> (
      match latest_plan env t with
      | Some p -> (t, Screen.Record_action { action = Screen.Batch; target = Some (Screen.Plan p) })
      | None -> say t "Select an explicit Scheduled reference for batch amount editing.")
  | Some (`ASCII ('e' | 'p' | 's' | 'g' | 'm'), []) -> say t not_connected
  | Some (`ASCII 'f', []) -> say t "Plan Detail always shows the selected plan's current-open occurrences."
  | Some ((`Escape | `ASCII ('q' | 'v')), []) -> stay { t with view = Coverage_view; plan_row = 0 }
  | Some (`ASCII 'n', []) -> (t, Screen.New_plan)
  | _ -> (t, Screen.Ignored)

let coverage_paint (env : Screen.env) (geometry : Screen.geometry) t =
  let width_of = geometry.width_of and width, height = geometry.content in
  let legend = List.map (fun line -> (O.Status, line))
      (flow ~width_of width
         (if snd geometry.screen < 18 then [ "days=open;"; "✓=done;"; "!=gap;"; "blank=not expected" ]
          else [ "days = open;"; "✓ = completed;"; "p = open count;"; "! = expected gap;";
                 "blank = not expected;"; "pace = guidance only" ])) in
  let panel_h = max 0 (height - List.length legend) in
  let inner_w = max 0 (width - 2) and inner_h = max 0 (panel_h - 2) in
  match coverage env with
  | Error why ->
      Panel.frame_rows ~inset:0 ~width_of ~width ~height:panel_h ~focused:true
        ~title:"Monitored plans [Unavailable]"
        ((List.map (fun l -> (O.Plain, l)) (O.wrap_text ~width_of inner_w (" [Coverage unavailable] " ^ why)))
         @ [ (O.Status, " Months and List remain available with v.") ])
      @ legend
  | Ok (months, rows) ->
      let count = List.length rows in
      let selected = clamp_index count t.coverage_row in
      let shown_months = List.filteri (fun i _ -> i >= t.coverage_offset && i - t.coverage_offset < month_window inner_w) months in
      let capacity = max 1 (inner_h - (if inner_h >= 2 then 1 else 0)) in
      let start = trailing_start selected capacity in
      let pace_w = pace_width inner_w and plan_w = plan_width inner_w in
      let header =
        O.pad ~width_of plan_w "Plan" ^ O.pad ~width_of pace_w "Pace"
        ^ String.concat "" (List.map (fun m -> O.pad ~width_of 8 (Cov.month_label m)) shown_months) in
      let line index (row : Cov.row) =
        let cells = List.filteri (fun i _ -> i >= t.coverage_offset && i - t.coverage_offset < List.length shown_months) row.cells in
        let text =
          (if index = selected then "> " else "  ")
          ^ O.pad ~width_of (max 0 (plan_w - 2)) row.rule.name
          ^ O.pad ~width_of pace_w (Cov.cadence_label row.rule.every_months)
          ^ String.concat "" (List.map (fun c -> O.pad ~width_of 8 (Cov.cell_text c)) cells) in
        ((if index = selected then O.Active else O.Plain), text)
      in
      let body =
        if rows = [] then [ (O.Status, "No recurring plans are being monitored.") ]
        else
          (if inner_h >= 2 then [ (O.Status, header) ] else [])
          @ List.filteri (fun i _ -> i >= start && i - start < capacity) (List.mapi line rows) in
      let more = (if start > 0 then " ▲" else "") ^ (if start + capacity < count then " ▼" else "") in
      Panel.frame_rows ~inset:0 ~width_of ~width ~height:panel_h ~focused:true
        ~bottom_label:((if count = 0 then "0/0" else Printf.sprintf "%d/%d" (selected + 1) count) ^ more)
        ~title:(Printf.sprintf "Monitored plans (%d)" count) body
      @ legend

(* LOAM groups the whole part by three digits; the exact fraction is kept. *)
let grouped amount =
  match String.split_on_char '.' amount with
  | [] -> amount
  | whole :: rest ->
      let b = Buffer.create (String.length amount + 8) in
      String.iteri (fun i c ->
          if i > 0 && (String.length whole - i) mod 3 = 0 then Buffer.add_char b ',';
          Buffer.add_char b c) whole;
      String.concat "." (Buffer.contents b :: rest)

let entry_quantity book = function
  | Missing_month _ -> "—"
  | Occurrence (p, _) -> (
      match List.filter (fun (_, q) -> Z.sign q < 0) p.B.changes,
            List.filter (fun (_, q) -> Z.sign q > 0) p.B.changes with
      | [ _ ], [ (_, q) ] -> grouped (B.format book p.measure q) ^ " " ^ p.measure
      | _ -> Printf.sprintf "split (%d)" (List.length p.changes))

let plan_paint (env : Screen.env) (geometry : Screen.geometry) t =
  let width_of = geometry.width_of and width, height = geometry.content in
  let legend = List.map (fun line -> (O.Status, line))
      (flow ~width_of width
         (if snd geometry.screen < 18 then [ "MISSING = gap only;"; "exact amounts" ]
          else [ "Explicit dates;"; "pace = guidance;"; "MISSING is not an occurrence;"; "exact amounts." ])) in
  let panel_h = max 0 (height - List.length legend) in
  let inner_w = max 0 (width - 2) and inner_h = max 0 (panel_h - 2) in
  match selected_rule env t with
  | None ->
      Panel.frame_rows ~inset:0 ~width_of ~width ~height:panel_h ~focused:true ~title:"Plan"
        [ (O.Status, " No recurring plan is selected.") ] @ legend
  | Some row ->
      let entries = plan_entries env row in
      let total = List.length entries in
      let at = clamp_index total t.plan_row in
      let show_header = inner_h >= 2 && inner_w >= 42 in
      let capacity = max 1 (inner_h - (if show_header then 1 else 0)) in
      let start = trailing_start at capacity in
      let qty_w = min (max 0 (inner_w - 2 - 10 - 4 - 14))
          (min 22 (max 14 (List.fold_left (fun w e -> max w (width_of (entry_quantity env.book e))) 0 entries))) in
      let status_w = max 0 (inner_w - 2 - 10 - 4 - qty_w) in
      let tabular = inner_w >= 42 in
      let cells date status qty =
        O.pad ~width_of 10 date ^ "  " ^ O.pad ~width_of status_w status ^ "  "
        ^ O.pad_left ~width_of qty_w (if width_of qty <= qty_w then qty else "too wide") in
      let line index e =
        let date, status = match e with
          | Missing_month m -> (m, if tabular && status_w >= 22 then "MISSING monitored month" else "MISSING")
          | Occurrence (p, on_pace) -> (p.B.day, if on_pace then "[on pace]" else "[outside pace]") in
        let marker = if index = at then "> " else "  " in
        ((if index = at then O.Active else O.Plain),
         marker ^ (if tabular then cells date status (entry_quantity env.book e) else date ^ " " ^ status)) in
      let body =
        if entries = [] then [ (O.Status, " No current-open occurrences or monitored gaps in the loaded horizon.") ]
        else
          (if show_header then [ (O.Status, "  " ^ cells "Date/Month" "Status" "Amount") ] else [])
          @ List.filteri (fun i _ -> i >= start && i - start < capacity) (List.mapi line entries) in
      let more = (if start > 0 then " ▲" else "") ^ (if start + capacity < total then " ▼" else "") in
      Panel.frame_rows ~inset:0 ~width_of ~width ~height:panel_h ~focused:true
        ~bottom_label:((if total = 0 then "0/0" else Printf.sprintf "%d/%d" (at + 1) total) ^ more)
        ~title:"Occurrences / monitored gaps" body
      @ legend

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
      let t = { t with view = current env t } in
      match t.view with
      | Coverage_view -> handle_coverage env t key
      | Plan_view -> handle_plan env t key
      | Months_view | List_view ->
      let months = months_view t and detail = t.pane = Detail_pane in
      let toggle_pane t = { t with pane = (if t.pane = List_pane then Detail_pane else List_pane) } in
      match key with
      | Some ((`Escape | `ASCII ('q')), []) ->
          if detail then stay { t with pane = List_pane; scroll = 0 } else (t, Screen.Back)
      | Some (`ASCII 'b', []) -> action book t Screen.Batch
      | Some (`ASCII 'g', []) -> action book t Screen.Generate
      | Some (`ASCII 'v', []) -> (toggle_view env book { t with scroll = 0 }, unless_blocked env "")
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

let enter ~focus_day:_ t =
  { t with pane = List_pane; scroll = 0; search = None; plan_row = 0;
    view = (match t.view with Plan_view -> Coverage_view | v -> v) }

let paint (env : Screen.env) (geometry : Screen.geometry) t =
  let book = env.book and width_of = geometry.width_of in
  let width, height = geometry.content in
  let t = synced book t in
  let rows = rows book t in
  let is_detail = t.pane = Detail_pane in
  match t.view with
  | Coverage_view -> coverage_paint env geometry t
  | Plan_view -> plan_paint env geometry t
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
  let width = fst geometry.screen in
  match t.view, t.pane with
  | Coverage_view, _ ->
      if width >= 79 then
        [ "[j/k] plan  [h/l] months  [Enter] detail  [q] back";
          "[b] batch  [n] new  [v] views  (e/p/s not connected)" ]
      else if width >= 47 then [ "[j/k] plan [h/l] months [Enter] detail [q] back"; "[b] batch [n] new [v] views" ]
      else [ "[j/k] plan [q] back"; "[Enter] detail [v] views" ]
  | Plan_view, _ ->
      if width >= 79 then
        [ "[j/k] select  [c/Enter] complete  [q] overview";
          "[b] batch  [r] replace  [x] cancel  [n] new  (e/p/s not connected)" ]
      else if width >= 47 then [ "[j/k] select [c/Enter] complete [q] overview"; "[b] batch [r] replace [x] cancel" ]
      else [ "[j/k] select [q] overview"; "[c/Enter] complete [x] cancel" ]
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
  let t = { t with view = current env t } in
  let overlay = Option.bind t.search (fun value ->
      let body_w, _ = geometry.body in
      Ui_overlay.form ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body
        ~pane_width:(min 54 (max 8 (body_w - 4)))
        (Ui_form.create ~id:"search" ~title:(tr "Search Actual / Scheduled")
           ~fields:[ Ui_form.text_field ~id:"value" ~label:"" ~value () ]
           ~notice:(tr "Enter apply; Esc clear") ())) in
  {
    Screen.title = (match t.view, selected_rule env t with
      | Coverage_view, _ -> "Scheduled Series Calendar"
      | Plan_view, Some row -> "Scheduled / Plan / " ^ row.rule.name
      | Plan_view, None -> "Scheduled / Plan"
      | Months_view, _ -> tr "Scheduled / Months"
      | List_view, _ -> tr "Scheduled");
    subtitle = (match t.view, selected_rule env t, coverage env with
      | Coverage_view, _, Ok (months, _) ->
          let width = max 0 (fst geometry.content - 2) in
          let shown = List.filteri (fun i _ -> i >= t.coverage_offset
              && i - t.coverage_offset < month_window width) months in
          let window = match shown with
            | [] -> if months = [] then "(empty loaded horizon)" else "(widen for months)"
            | first :: _ -> first ^ " .. " ^ List.nth shown (List.length shown - 1) in
          Screen.Text ("Month window: " ^ window ^ "  |  known through " ^ env.today)
      | Coverage_view, _, Error _ -> Screen.Text "Coverage unavailable"
      | Plan_view, Some row, _ ->
          Screen.Text ("Pace: " ^ (match row.rule.every_months with
              | 0 -> "undecided" | 1 -> "monthly" | n -> "every " ^ string_of_int n ^ " months")
            ^ " from " ^ row.rule.anchor ^ "  |  Shape: " ^ String.concat "," row.rule.negative
            ^ " -> " ^ String.concat "," row.rule.positive)
      | Plan_view, None, _ -> Screen.Default
      | Months_view, _, _ -> Screen.Text "Explicit current-open plans; no recurrence inferred."
      | List_view, _, _ -> Screen.Default);
    rows = lazy (paint env geometry t);
    footer = footer geometry t;
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
