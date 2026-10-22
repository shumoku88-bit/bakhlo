(* Home and Calendar share one retained period browser, as in the original UI.
   The Shell supplies route/calendar notifications, never a browser snapshot. *)
module B = Bakhlo_sexp.Daily_book
module RB = Record_browser
module Cal = Daily_calendar
module O = Daily_overlays
module Panel = Ui_panel

let tr = Ui_text.tr
let get = function Ok value -> value | Error why -> invalid_arg why

type pane = Calendar_pane | Detail_pane
type overlay = Jump of string | Search of string

type t = {
  route : Screen.route;
  browser : RB.t;
  pane : pane;
  scroll : int;
  overlay : overlay option;
}

let config_files = []

let create () =
  { route = Screen.Home; browser = RB.empty; pane = Calendar_pane; scroll = 0; overlay = None }

let browser t = t.browser
let with_browser t browser = { t with browser }
let detail_focused t = t.pane = Detail_pane
let scroll t = t.scroll

let back_to_list t =
  if t.pane = Detail_pane then Some { t with pane = Calendar_pane; scroll = 0 } else None

let modal t = Option.is_some t.overlay
let ambient t = modal t && t.route <> Screen.Home && t.route <> Screen.Calendar

let rows ~book ~calendar t =
  if t.route <> Screen.Calendar then []
  else
    RB.all_rows book
    |> List.filter (fun row -> Cal.period_contains calendar (RB.date row))
    |> RB.visible ~book t.browser

let synced ~book ~calendar t = { t with browser = RB.sync t.browser (rows ~book ~calendar t) }

let synchronize ~route ~book ~calendar t =
  (* Selected Day has its own browser and never synchronizes this one. *)
  if match route with Screen.Selected_day _ -> true | _ -> false then { t with scroll = 0 }
  else synced ~book ~calendar { t with route; scroll = 0 }

let entered route ~focus_day:_ t =
  { t with route; pane = Calendar_pane; scroll = 0; overlay = None }

let selected_row ~book ~calendar t = RB.selected_row t.browser (rows ~book ~calendar t)
let book_changed ~before:_ ~after:_ t = (t, "")

(* Shell synchronization has the current calendar. *)
let reloaded env t = ((if env.Screen.blocked then t else { t with scroll = 0 }), Screen.Stay)

let start_search ?value t =
  { t with overlay = Some (Search (Option.value ~default:t.browser.query value)) }

let start_jump value t = { t with overlay = Some (Jump value) }

let input_text value = function
  | `Key (`ASCII c, []) when Char.code c >= 32 && Char.code c <> 127 ->
      Some (value ^ String.make 1 c)
  | `Key (`Uchar c, []) when O.printable_uchar c -> Some (value ^ O.utf8 c)
  | `Key (`Backspace, []) -> Some (Daily_form.backspace value)
  | _ -> None

let apply_calendar (env : Screen.env) action t =
  match Cal.apply env.calendar action with
  | Cal.Refused why -> (t, Screen.Message (tr why))
  | Cal.Open_day calendar -> (t, Screen.Open_route (Screen.Selected_day calendar.selected_day))
  | Cal.Moved calendar ->
      ( { t with pane = Calendar_pane; scroll = 0 },
        Screen.Set_calendar { calendar; clear_message = true } )

(* Legacy fallback navigation on other routes affects only this retained model. *)
let ambient_handle (env : Screen.env) (geometry : Screen.geometry) t input =
  let stay t = (t, Screen.Stay) in
  let move delta =
    { t with browser = RB.move t.browser (rows ~book:env.book ~calendar:env.calendar t) delta }
  in
  let key = Ui_input.key_ignoring_case input in
  match t.overlay with
  | Some (Jump value) -> (
      match input with
      | `Key (`Escape, []) -> stay { t with overlay = None }
      | `Key (`Enter, []) -> apply_calendar env (Cal.Jump value) { t with overlay = None }
      | _ ->
          stay
            (match input_text value input with
            | None -> t
            | Some value -> { t with overlay = Some (Jump value) }))
  | Some (Search value) -> (
      let apply query =
        synced ~book:env.book ~calendar:env.calendar
          { t with browser = RB.with_query t.browser query; overlay = None; scroll = 0 }
      in
      match input with
      | `Key (`Escape, []) -> stay (apply "")
      | `Key (`Enter, []) -> stay (apply value)
      | _ ->
          stay
            (match input_text value input with
            | None -> t
            | Some value -> { t with overlay = Some (Search value) }))
  | None -> (
      match key with
      | Some (`ASCII '/', []) -> stay (start_search t)
      | Some ((`Tab | `ASCII 'w'), []) | Some (`Tab, [ `Shift ]) ->
          stay
            {
              t with
              pane = (if t.pane = Calendar_pane then Detail_pane else Calendar_pane);
              scroll = 0;
            }
      | Some ((`Enter | `ASCII 'i'), []) -> stay { t with pane = Detail_pane; scroll = 0 }
      | Some (((`ASCII ('j' | 'k') | `Arrow (`Up | `Down)) as key), []) ->
          let delta = match key with `ASCII 'k' | `Arrow `Up -> -1 | _ -> 1 in
          if t.pane = Detail_pane && t.route <> Screen.Calendar && t.route <> Screen.Home then
            stay { t with scroll = max 0 (t.scroll + delta) }
          else stay { (move delta) with scroll = 0 }
      | Some ((`Page _ as key), []) | Some ((`ASCII ('u' | 'd') as key), [ `Ctrl ]) ->
          let delta = match key with `Page `Up | `ASCII 'u' -> -1 | _ -> 1 in
          let step = delta * max 1 (snd geometry.screen - 8) in
          if
            (t.pane = Calendar_pane && t.route <> Screen.Home && t.route <> Screen.Daily_pace)
            || (t.route = Screen.Home && t.pane = Detail_pane)
          then stay { (move step) with scroll = 0 }
          else stay { t with scroll = max 0 (t.scroll + step) }
      | Some (`Home, []) -> stay { (move (-max_int)) with scroll = 0 }
      | Some (`End, []) -> stay { (move max_int) with scroll = max_int / 4 }
      | _ -> (t, Screen.Ignored))

let handle (env : Screen.env) geometry t input =
  if modal t then ambient_handle env geometry t input
  else
    let key = Ui_input.key_ignoring_case input in
    let stay t = (t, Screen.Stay) in
    let calendar = t.route = Screen.Calendar in
    let action action =
      let target =
        Option.map
          (function RB.Actual_entry e -> Screen.Entry e | RB.Scheduled_plan p -> Screen.Plan p)
          (selected_row ~book:env.book ~calendar:env.calendar t)
      in
      (t, Screen.Record_action { action; target })
    in
    match key with
    | Some ((`Escape | `ASCII 'q'), []) when not calendar -> (t, Screen.Quit)
    | Some (`ASCII 'g', []) ->
        (t, Screen.Open_route (if calendar then Screen.Home else Screen.Calendar))
    | Some (`Enter, []) when not calendar -> (t, Screen.Open_route Screen.Actual)
    | Some (((`Escape | `ASCII 'q') as key), []) ->
        if t.pane = Detail_pane then stay { t with pane = Calendar_pane; scroll = 0 }
        else if key = `Escape && env.calendar.zoom <> Cal.Day then
          let calendar =
            {
              env.calendar with
              zoom =
                (match env.calendar.zoom with
                | Cal.Year -> Cal.Month
                | Cal.Month -> Cal.Day
                | Cal.Day -> Cal.Day);
            }
          in
          ({ t with scroll = 0 }, Screen.Set_calendar { calendar; clear_message = false })
        else (t, Screen.Open_route Screen.Home)
    | Some (`ASCII 't', []) when calendar -> apply_calendar env (Cal.Today env.today) t
    | Some (`ASCII 'z', []) when calendar -> apply_calendar env Cal.Cycle_zoom t
    | Some (`ASCII '/', []) when calendar -> stay (start_jump "" t)
    | Some (`ASCII 'a', []) -> (t, Screen.Open_route Screen.Actual)
    | Some (`ASCII 's', []) -> (t, Screen.Open_route Screen.Scheduled)
    | Some (`ASCII 'b', []) -> (t, Screen.Open_route Screen.Balances)
    | Some (`ASCII 'd', []) -> (t, Screen.Open_route Screen.Daily_pace)
    | Some (`ASCII 'i', []) -> (t, Screen.Open_route Screen.Attention)
    | Some (`ASCII 'o', []) -> (t, Screen.Open_observe)
    | Some (`ASCII ('r' | 'n'), []) -> (t, Screen.New_record)
    | Some (`ASCII ('c' | 'e'), []) | Some (`ASCII 'e', [ `Ctrl ]) -> action Screen.Edit
    | Some (`ASCII 'x', []) -> (
        match selected_row ~book:env.book ~calendar:env.calendar t with
        | Some (RB.Actual_entry _) -> action Screen.Reverse
        | Some (RB.Scheduled_plan _) -> action Screen.Cancel
        | None -> stay t)
    | Some (`Enter, []) -> (
        if t.pane = Calendar_pane then apply_calendar env Cal.Drill t
        else
          match selected_row ~book:env.book ~calendar:env.calendar t with
          | None -> stay t
          | Some row -> (t, Screen.Open_route (Screen.Selected_day (RB.date row))))
    | Some (((`ASCII ('h' | 'l') | `Arrow (`Left | `Right)) as key), [])
      when calendar && t.pane = Calendar_pane ->
        apply_calendar env
          (match key with `ASCII 'h' | `Arrow `Left -> Cal.Left | _ -> Cal.Right)
          t
    | Some (((`ASCII ('j' | 'k') | `Arrow (`Up | `Down)) as key), [])
      when calendar && t.pane = Calendar_pane ->
        apply_calendar env (match key with `ASCII 'k' | `Arrow `Up -> Cal.Up | _ -> Cal.Down) t
    | _ -> ambient_handle env geometry t input

let calendar_rows ?(width = 80) (env : Screen.env) =
  let calendar = env.calendar and book = env.book in
  let actuals = B.entries book and scheduled = B.open_plans book in
  let count prefix =
    ( List.length (List.filter (fun (e : B.entry) -> String.starts_with ~prefix e.day) actuals),
      List.length (List.filter (fun (p : B.plan) -> String.starts_with ~prefix p.day) scheduled) )
  in
  let cell width value = value ^ String.make (max 0 (width - String.length value)) ' ' in
  let today = env.today in
  let names =
    [| "Jan"; "Feb"; "Mar"; "Apr"; "May"; "Jun"; "Jul"; "Aug"; "Sep"; "Oct"; "Nov"; "Dec" |]
  in
  match calendar.Cal.zoom with
  | Cal.Day ->
      let room = max 0 (width - 6) in
      let compact = room < 49 in
      let cell_width = if room >= 49 then 7 else if room >= 35 then 5 else 3 in
      let slots = get (Cal.month_slots calendar.selected_day) in
      let rec weeks = function
        | [] -> []
        | xs ->
            let week = List.filteri (fun i _ -> i < 7) xs in
            let rest = List.filteri (fun i _ -> i >= 7) xs in
            let dates =
              List.map
                (function
                  | None -> String.make cell_width ' '
                  | Some day ->
                      let actual, planned = count day in
                      let dd = String.sub day 8 2 in
                      let chosen = day = calendar.selected_day in
                      let label =
                        if chosen then "[" ^ dd ^ "]" else if compact then dd else " " ^ dd
                      in
                      let today_mark =
                        if day = today && ((not chosen) || room >= (7 * cell_width) + 2) then "*"
                        else if compact && chosen then ""
                        else " "
                      in
                      cell cell_width
                        (label ^ today_mark
                        ^
                        if compact then ""
                        else (if actual > 0 then "a" else " ") ^ if planned > 0 then "s" else " "))
                week
            in
            String.concat "" dates :: weeks rest
      in
      if room < 22 then
        [ "[" ^ String.sub calendar.selected_day 8 2 ^ "] " ^ calendar.selected_day ]
      else
        [
          String.concat ""
            (List.map (cell cell_width)
               (if cell_width = 3 then [ "Mo"; "Tu"; "We"; "Th"; "Fr"; "Sa"; "Su" ]
                else [ "Mon"; "Tue"; "Wed"; "Thu"; "Fri"; "Sat"; "Sun" ]));
        ]
        @ weeks slots
        @ [
            tr
              (if compact then "[ ] selected   * today" else "a Actual   s open Scheduled   * today");
          ]
  | Cal.Month ->
      let year = String.sub calendar.selected_day 0 4 in
      if width < 64 then
        List.init 12 (fun i ->
            let prefix = Printf.sprintf "%s-%02d" year (i + 1) in
            let actual, planned = count prefix in
            Printf.sprintf "%s%02d %s    A%d S%d"
              (if String.starts_with ~prefix calendar.selected_day then "> " else "  ")
              (i + 1) names.(i) actual planned)
      else
        List.init 4 (fun quarter ->
            List.init 3 (fun column ->
                let i = (quarter * 3) + column in
                let prefix = Printf.sprintf "%s-%02d" year (i + 1) in
                let actual, planned = count prefix in
                let label = Printf.sprintf "%02d %s" (i + 1) names.(i) in
                let label =
                  if String.starts_with ~prefix calendar.selected_day then "[" ^ label ^ "]"
                  else " " ^ label ^ " "
                in
                cell 19 (Printf.sprintf "%s A%d S%d" label actual planned))
            |> String.concat "")
        @ [ ""; tr "A Actual   S open Scheduled" ]
  | Cal.Year ->
      let year = int_of_string (String.sub calendar.selected_day 0 4) in
      List.init 5 (fun i -> year + i - 2)
      |> List.filter (fun y -> y >= 1 && y <= 9999)
      |> List.map (fun y ->
          let prefix = Printf.sprintf "%04d" y in
          let actual, planned = count prefix in
          Printf.sprintf "%s%s    A%d  S%d" (if y = year then "> " else "  ") prefix actual planned)

let paint (env : Screen.env) (geometry : Screen.geometry) t =
  let book = env.book and width_of = geometry.width_of in
  let width, height = if t.route = Screen.Home then geometry.body else geometry.content in
  let draw_frame = Panel.frame in
  let pad rows = rows @ List.init (max 0 (height - List.length rows)) (fun _ -> (O.Plain, "")) in
  let rows = rows ~book ~calendar:env.calendar t in
  let titles = List.map (Record_lines.row_title book) rows in
  if t.route = Screen.Home then O.bonsai_home_lines ~width ~height ~width_of ~today:env.today
  else
    let calendar_focused = t.pane = Calendar_pane in
    let detail =
      let actual =
        List.length (List.filter (function RB.Actual_entry _ -> true | _ -> false) rows)
      in
      let scheduled = List.length rows - actual in
      Printf.sprintf "Actual %d   Open Scheduled %d" actual scheduled
      :: (if titles = [] then [ tr "No records in this period." ] else titles)
      @ [ tr "Flow unavailable: classification not supplied." ]
    in
    let period =
      let n = match env.calendar.zoom with Cal.Day -> 10 | Cal.Month -> 7 | Cal.Year -> 4 in
      String.sub env.calendar.selected_day 0 n
    in
    let calendar_frame ~width ~height =
      let calendar = calendar_rows ~width env in
      let selected =
        match env.calendar.zoom with
        | Cal.Month when width < 64 ->
            Some (int_of_string (String.sub env.calendar.selected_day 5 2) - 1)
        | Cal.Year -> Some (min 2 (int_of_string (String.sub env.calendar.selected_day 0 4) - 1))
        | Cal.Day | Cal.Month -> None
      in
      let scroll =
        if env.calendar.zoom <> Cal.Day || t.scroll <> 0 then t.scroll
        else
          let first = String.sub env.calendar.selected_day 0 8 ^ "01" in
          let week =
            (get (Cal.weekday first) + int_of_string (String.sub env.calendar.selected_day 8 2) - 1)
            / 7
          in
          max 0 (1 + week - max 1 (height - 2) + 1)
      in
      let result =
        draw_frame ~width_of ~width ~height ~focused:calendar_focused
          ~title:
            ("Calendar / "
            ^ String.sub env.calendar.selected_day 0 (if env.calendar.zoom = Cal.Day then 7 else 4)
            )
          ~scroll ~selected calendar
      in
      let marker = "[" ^ String.sub env.calendar.selected_day 8 2 ^ "]" in
      List.map
        (fun (style, text) ->
          if
            calendar_focused && env.calendar.zoom = Cal.Day && style = O.Plain
            && Base.String.is_substring text ~substring:marker
          then (O.Calendar_dates, text)
          else (style, text))
        result
    in
    let detail_frame ~width ~height =
      draw_frame ~width_of ~width ~height ~focused:(not calendar_focused)
        ~title:("Detail / " ^ period) ~scroll:0
        ~selected:(if rows = [] then None else Some (t.browser.selected + 1))
        detail
    in
    if width >= 120 then
      let left = 64 and right = width - 65 in
      let natural = List.length (calendar_rows ~width:left env) + 2 in
      let pane_height = min height (max natural (min 12 (List.length detail + 2))) in
      let left_rows = calendar_frame ~width:left ~height:pane_height in
      let right_rows = detail_frame ~width:right ~height:pane_height in
      pad
        (List.map2
           (fun (style, left_text) (right_style, right_text) ->
             (O.Columns (left, style, right_style), left_text ^ " " ^ right_text))
           left_rows right_rows)
    else
      let natural = List.length (calendar_rows ~width env) + 2 in
      if width >= 72 && height >= natural + 6 then
        let calendar_height = natural in
        calendar_frame ~width ~height:calendar_height
        @ [ (O.Plain, "") ]
        @ detail_frame ~width ~height:(height - calendar_height - 1)
      else if calendar_focused then calendar_frame ~width ~height
      else detail_frame ~width ~height

let footer (env : Screen.env) t =
  if t.route = Screen.Home then
    let badge =
      match env.attention with
      | Ok a -> Attention_data.badge (Attention_data.summarize ~today:env.today a)
      | Error _ -> ""
    in
    [ " [Enter] actual   [g] calendar   [i] attention" ^ badge; " [Space] commands   [q] quit" ]
  else if t.pane = Calendar_pane then
    [
      (match env.calendar.zoom with
      | Cal.Day -> "h/l day  j/k week  Enter open  z zoom  / jump  t today"
      | Cal.Month -> "h/l month  j/k quarter  Enter days  z zoom  / jump  t today"
      | Cal.Year -> "h/l/j/k year  Enter months  z zoom  / jump  t today");
      "q/Esc Home  Tab/w Detail  r Record  Space Commands  a/s/b/d views";
    ]
  else
    [
      "q/Esc Calendar  j/k select  Enter Selected Day  Tab/w pane";
      "r Record  Space Commands  a/s/b/d views";
    ]

let view env (geometry : Screen.geometry) t =
  let overlay =
    Option.bind t.overlay (fun overlay ->
        let value, title, notice, id =
          match overlay with
          | Jump value -> (value, "Jump to date / month / year", "Enter apply; Esc cancel", "jump")
          | Search value -> (value, "Search Actual / Scheduled", "Enter apply; Esc clear", "search")
        in
        let body_w, _ = geometry.body in
        Ui_overlay.form ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body
          ~pane_width:(min 54 (max 8 (body_w - 4)))
          (Ui_form.create ~id ~title:(tr title)
             ~fields:[ Ui_form.text_field ~id:"value" ~label:"" ~value () ]
             ~notice:(tr notice) ()))
  in
  {
    Screen.title = tr (if t.route = Screen.Home then "Home" else "Calendar");
    subtitle = Screen.Default;
    rows = lazy (paint env geometry t);
    footer = footer env t;
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
