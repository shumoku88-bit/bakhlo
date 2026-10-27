(* The Actual's period picker: every window of one period, newest first, with its
   entry count and EXPENSE total. *)
module B = Bakhlo_household.Daily_book
module Act = Actual_workspace
module Cal = Daily_calendar
module O = Daily_overlays
module Panel = Ui_panel

type window = { start_day : string; end_exclusive : string }
type row = { window : window; label : string; now : bool; count : int; total : string option }
type t = { period : Act.period; rows : (row array, string) result; selected : int; top : int }

let periods = [ Act.Today; Act.Cycle; Act.Month; Act.Year; Act.All ]
let contains w day = w.start_day <= day && day < w.end_exclusive

let last_day w =
  match Cal.shift_days w.end_exclusive (-1) with Ok day -> day | Error _ -> w.start_day

let label period w =
  match period with
  | Act.All -> "All time"
  | Act.Today -> (
      match Act.weekday_name w.start_day with "" -> w.start_day | name -> w.start_day ^ " " ^ name)
  | Act.Month -> String.sub w.start_day 0 7
  | Act.Year -> String.sub w.start_day 0 4
  | Act.Cycle -> w.start_day ^ " .. " ^ last_day w

(* Ascending windows from [first] while they start on or before [last]; the
   calendar's end (9999) closes the list rather than inventing a window. *)
let steps ~first ~last ~next =
  let rec go acc start =
    if start > last then List.rev acc
    else
      match next start with
      | Error _ -> List.rev acc
      | Ok end_exclusive -> go ({ start_day = start; end_exclusive } :: acc) end_exclusive
  in
  go [] first

let windows ~book ~today ~reference ~cycle period =
  let entries = B.entries book in
  let lo, hi =
    List.fold_left
      (fun (lo, hi) (e : B.entry) ->
        ( (if String.compare e.day lo < 0 then e.day else lo),
          if String.compare e.day hi > 0 then e.day else hi ))
      (if String.compare today reference < 0 then (today, reference) else (reference, today))
      entries
  in
  match period with
  | Act.All -> Ok [ { start_day = "0001-01-01"; end_exclusive = "9999-12-31" } ]
  | Act.Month ->
      Ok (steps ~first:(String.sub lo 0 8 ^ "01") ~last:hi ~next:(fun d -> Cal.shift_months d 1))
  | Act.Year ->
      Ok (steps ~first:(String.sub lo 0 5 ^ "01-01") ~last:hi ~next:(fun d -> Cal.shift_years d 1))
  | Act.Cycle ->
      Result.map (List.map (fun (start_day, end_exclusive) -> { start_day; end_exclusive })) cycle
  | Act.Today ->
      let days = Hashtbl.create 1024 in
      List.iter
        (fun day -> Hashtbl.replace days day ())
        (today :: reference :: List.map (fun (e : B.entry) -> e.day) entries);
      List.sort String.compare (List.of_seq (Hashtbl.to_seq_keys days))
      |> List.filter_map (fun day ->
          match Cal.shift_days day 1 with
          | Ok end_exclusive -> Some { start_day = day; end_exclusive }
          | Error _ -> None)
      |> Result.ok

(* The windows are ascending and do not overlap, so each entry finds its window
   by binary search: one pass over the ledger for the whole list. *)
let rows ~ctx ~today period windows =
  let windows = Array.of_list windows in
  let n = Array.length windows in
  let buckets = Array.make n [] in
  let rec search lo hi day =
    if lo >= hi then lo - 1
    else
      let mid = (lo + hi) / 2 in
      if windows.(mid).start_day <= day then search (mid + 1) hi day else search lo mid day
  in
  List.iter
    (fun (e : B.entry) ->
      let i = search 0 n e.day in
      if i >= 0 && contains windows.(i) e.day then buckets.(i) <- e :: buckets.(i))
    (B.entries ctx.Act.book);
  let roles = Act.expense_roles ~ctx in
  List.init n (fun i ->
      let window = windows.(n - 1 - i) and entries = buckets.(n - 1 - i) in
      {
        window;
        label = label period window;
        now = contains window today;
        count = List.length entries;
        total =
          (if entries = [] then None
           else Option.bind roles (fun roles -> Act.expense_total roles entries));
      })

let index_of rows reference =
  match rows with
  | Error _ -> 0
  | Ok rows ->
      let rec find i =
        if i >= Array.length rows then 0
        else if contains rows.(i).window reference then i
        else find (i + 1)
      in
      find 0

let create period ~rows ~reference =
  let rows = Result.map Array.of_list rows in
  { period; rows; selected = index_of rows reference; top = 0 }

let period t = t.period

let selected t =
  match t.rows with
  | Ok rows when t.selected < Array.length rows -> Some rows.(t.selected)
  | _ -> None

let reference ~today row = if row.now then today else last_day row.window
let count t = match t.rows with Ok rows -> Array.length rows | Error _ -> 0

(* The pane is as tall as its rows, inside the body; the list sits under the
   row of periods. *)
let pane_size (body_w, body_h) t =
  let width = if body_w >= 44 then min 66 (body_w - 4) else body_w in
  let room = if body_h >= 12 then body_h - 2 else body_h in
  (width, min room (max 5 (count t + 3)))

let capacity ~body t = max 1 (snd (pane_size body t) - 3)

(* The first visible row keeps the selection in view. *)
let visible_top ~capacity t =
  if t.selected < t.top then t.selected
  else if t.selected >= t.top + capacity then t.selected - capacity + 1
  else t.top

type command = Stay | Kind of Act.period | Choose of row | Refuse of string | Close

let neighbour period delta =
  let n = List.length periods in
  let rec index i = function
    | [] -> 0
    | p :: rest -> if p = period then i else index (i + 1) rest
  in
  List.nth periods ((index 0 periods + delta + n) mod n)

let handle ~body t input =
  let capacity = capacity ~body t in
  let last = max 0 (count t - 1) in
  let move selected =
    let t = { t with selected = max 0 (min last selected) } in
    ({ t with top = visible_top ~capacity t }, Stay)
  in
  match Ui_input.key_ignoring_case input with
  | Some ((`ASCII 'j' | `Arrow `Down), []) -> move (t.selected + 1)
  | Some ((`ASCII 'k' | `Arrow `Up), []) -> move (t.selected - 1)
  | Some (`Page `Down, _) -> move (t.selected + capacity)
  | Some (`Page `Up, _) -> move (t.selected - capacity)
  | Some (`Home, _) -> move 0
  | Some (`End, _) -> move last
  | Some ((`ASCII 'h' | `Arrow `Left), []) | Some (`Tab, [ `Shift ]) ->
      (t, Kind (neighbour t.period (-1)))
  | Some ((`ASCII 'l' | `Arrow `Right | `Tab), []) -> (t, Kind (neighbour t.period 1))
  | Some (`Enter, _) -> (
      match (t.rows, selected t) with
      | Error why, _ -> (t, Refuse why)
      | Ok _, Some row -> (t, Choose row)
      | Ok _, None -> (t, Refuse "This period has no window to open."))
  | Some ((`Escape | `ASCII ('q' | 'f')), []) -> (t, Close)
  | _ -> (t, Stay)

(* A window's line: the name, "now" when it contains today, then the entry count
   and the EXPENSE total in columns as wide as the widest of the list. An amount is
   never cut short: a narrower line drops the count, then "now", then the total;
   only the label is ever clipped. *)
let count_text row =
  match row.count with 0 -> "no entries" | 1 -> "1 entry" | n -> Printf.sprintf "%d entries" n

let row_text ~width_of ~width ~count_width ~total_width row =
  let now = row.label ^ if row.now then "  now" else "" in
  let total = O.pad_left ~width_of total_width (Option.value ~default:"" row.total) in
  let count = O.pad_left ~width_of count_width (count_text row) in
  let line (left, right) =
    if right = "" then if width_of left <= width then Some left else None
    else if width_of left + 2 + width_of right <= width then
      Some (O.pad ~width_of (width - width_of right) left ^ right)
    else None
  in
  let total_only = if row.total = None then "" else total in
  match
    List.find_map line
      [ (now, count ^ "  " ^ total); (now, total_only); (row.label, total_only); (row.label, "") ]
  with
  | Some text -> text
  | None -> O.clip_text ~width_of width row.label

let frame ~width_of ~screen ~body t =
  let body_w, body_h = body in
  if body_w < 8 || body_h < 4 then None
  else
    let width, height = pane_size body t in
    let inner = width - 2 in
    let capacity = capacity ~body t in
    let tabs gap =
      List.concat
        (List.mapi
           (fun i period ->
             let name = Act.period_name period in
             (if i = 0 then [ (O.Plain, " ") ] else [ (O.Plain, gap) ])
             @ [ (if period = t.period then (O.Heading, "[" ^ name ^ "]") else (O.Chrome, name)) ])
           periods)
    in
    let tabs = if width_of (O.spans_text (tabs "  ")) <= inner then tabs "  " else tabs " " in
    let list =
      match t.rows with
      | Error why ->
          List.map
            (fun line -> (O.Status, " " ^ line))
            (O.wrap_text ~width_of (max 1 (inner - 1)) why)
      | Ok rows ->
          let top = visible_top ~capacity t in
          let widest f = Array.fold_left (fun w row -> max w (width_of (f row))) 0 rows in
          let count_width = widest count_text
          and total_width = widest (fun row -> Option.value ~default:"" row.total) in
          List.init
            (min capacity (Array.length rows - top))
            (fun i ->
              let index = top + i in
              let chosen = index = t.selected in
              ( (if chosen then O.Active else O.Plain),
                (if chosen then " > " else "   ")
                ^ row_text ~width_of
                    ~width:(max 0 (inner - 4))
                    ~count_width ~total_width rows.(index) ))
    in
    let position =
      match t.rows with
      | Ok rows when rows <> [||] ->
          Some (Printf.sprintf "%d/%d" (t.selected + 1) (Array.length rows))
      | _ -> None
    in
    Panel.frame_rows ~inset:0 ?bottom_label:position ~width_of ~width ~height ~focused:true
      ~title:"Choose period"
      ((O.Spans tabs, O.spans_text tabs) :: list)
    |> Ui_overlay.centered ~width_of ~screen ~body ~pane_width:width ~caret:`None

let footer ~width =
  if width >= 60 then
    [ "[h/l] period  [j/k] window  [PgUp/PgDn] page  [Home/End]"; "[Enter] open  [Esc/q/f] cancel" ]
  else [ "[h/l] period [j/k] window"; "[Enter] open [Esc] cancel" ]
