module T = Bakhlo_book_txt.Book_txt

type due = T.due = Due_on of string | No_due_date | Due_undetermined
type close_kind = T.close_kind = Resolved | Dropped
type item = T.item = { id : string; due : due; context : string }
type close = T.close = { item : string; day : string; kind : close_kind }
type t = { items : item list; closes : close list }

let empty = { items = []; closes = [] }
let is_closed t id = List.exists (fun (c : close) -> c.item = id) t.closes
let open_items t = List.filter (fun (item : item) -> not (is_closed t item.id)) t.items
let find_item t id = List.find_opt (fun (item : item) -> item.id = id) t.items

let next_id t =
  let rec find n =
    let id = Printf.sprintf "attention-%d" n in
    if find_item t id <> None then find (n + 1) else id
  in
  find (List.length t.items + 1)

let due_label = function
  | Due_on d -> "Due: " ^ d
  | No_due_date -> "No due date"
  | Due_undetermined -> "Due: timing unknown"

type summary = { open_count : int; overdue_count : int; due_today_count : int }

let summarize ~today t =
  let items = open_items t in
  List.fold_left
    (fun acc (item : item) ->
      let is_overdue, is_today =
        match item.due with
        | Due_on d -> (d < today, d = today)
        | No_due_date | Due_undetermined -> (false, false)
      in
      {
        open_count = acc.open_count + 1;
        overdue_count = (acc.overdue_count + if is_overdue then 1 else 0);
        due_today_count = (acc.due_today_count + if is_today then 1 else 0);
      })
    { open_count = 0; overdue_count = 0; due_today_count = 0 }
    items

let badge ?(width = 80) s =
  if s.open_count = 0 then ""
  else if s.overdue_count > 0 then
    if width >= 100 then Printf.sprintf " (! %d overdue)" s.overdue_count
    else Printf.sprintf " (!%d)" s.overdue_count
  else if s.due_today_count > 0 then " (today)"
  else Printf.sprintf " (%d)" s.open_count

let due_display ~today = function
  | Due_on d -> if d < today then "! " ^ d else if d = today then "today" else "due " ^ d
  | No_due_date -> "no due date"
  | Due_undetermined -> "due unknown"

let valid_token s = s <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) s
let valid_date s = match Day.normalize s with Ok day -> day = s | Error _ -> false

let add_item t ~id ~context ~due =
  if not (valid_token id) then Error "Invalid Attention ID."
  else if
    match due with Due_on day -> not (valid_date day) | No_due_date | Due_undetermined -> false
  then Error "Invalid Attention due date."
  else if List.exists (fun (item : item) -> item.id = id) t.items then
    Error (Printf.sprintf "Attention ID '%s' already exists." id)
  else if String.trim context = "" then Error "Attention context cannot be empty."
  else
    let item = { id; context; due } in
    Ok { t with items = t.items @ [ item ] }

let close_item t ~id ~known_on ~kind =
  if not (valid_date known_on) then Error "Invalid Attention closure date."
  else
    match find_item t id with
    | None -> Error (Printf.sprintf "Attention ID '%s' not found." id)
    | Some _ ->
        if is_closed t id then Error (Printf.sprintf "Attention '%s' is already closed." id)
        else
          let close = { item = id; day = known_on; kind } in
          Ok { t with closes = t.closes @ [ close ] }
