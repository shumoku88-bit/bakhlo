(* Attention model, serialization, and lifecycle operations *)

type due = Due_on of string | No_due_date | Due_undetermined
type closure_kind = Resolved | Dropped
type item = { id : string; context : string; due : due }
type closure = { attention : string; known_on : string; kind : closure_kind }
type t = { items : item list; closures : closure list }

let empty = { items = []; closures = [] }
let is_closed t id = List.exists (fun (c : closure) -> c.attention = id) t.closures
let open_items t = List.filter (fun (item : item) -> not (is_closed t item.id)) t.items
let closed_items t = List.filter (fun (item : item) -> is_closed t item.id) t.items
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

let closure_kind_label = function Resolved -> "Resolved" | Dropped -> "Dropped"

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

let escape_text s =
  let b = Buffer.create (String.length s * 2) in
  String.iter
    (function
      | '\\' -> Buffer.add_string b "\\\\"
      | '\n' -> Buffer.add_string b "\\n"
      | '\r' -> Buffer.add_string b "\\r"
      | '\t' -> Buffer.add_string b "\\t"
      | c -> Buffer.add_char b c)
    s;
  Buffer.contents b

let unescape_text s =
  let b = Buffer.create (String.length s) in
  let len = String.length s in
  let rec loop i =
    if i >= len then Ok (Buffer.contents b)
    else if s.[i] = '\\' then
      if i + 1 >= len then Error "dangling backslash"
      else
        match s.[i + 1] with
        | '\\' ->
            Buffer.add_char b '\\';
            loop (i + 2)
        | 'n' ->
            Buffer.add_char b '\n';
            loop (i + 2)
        | 'r' ->
            Buffer.add_char b '\r';
            loop (i + 2)
        | 't' ->
            Buffer.add_char b '\t';
            loop (i + 2)
        | _ -> Error "invalid escape"
    else (
      Buffer.add_char b s.[i];
      loop (i + 1))
  in
  loop 0

let valid_token s = s <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) s
let valid_date s = match Daily_draft.normalize_date s with Ok day -> day = s | Error _ -> false

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
          let closure = { attention = id; known_on; kind } in
          Ok { t with closures = t.closures @ [ closure ] }

let of_string text =
  let rec parse t header = function
    | [] -> Ok t
    | line :: rest ->
        let trimmed = String.trim line in
        if trimmed = "" || String.starts_with ~prefix:"#" trimmed then parse t header rest
        else if line = "LOAM-ATTENTION-MEMORY\t1" && (not header) && t = empty then
          parse t true rest
        else
          let item id due escaped_context =
            Result.bind (unescape_text escaped_context) (fun context ->
                add_item t ~id ~context ~due)
          in
          let updated =
            match String.split_on_char '\t' line with
            | [ "ITEM"; id; "DUE_ON"; date; context ] -> item id (Due_on date) context
            | [ "ITEM"; id; "NO_DUE_DATE"; "-"; context ] -> item id No_due_date context
            | [ "ITEM"; id; "DUE_UNDETERMINED"; "-"; context ] -> item id Due_undetermined context
            | [ "CLOSE"; id; known_on; "RESOLVED" ] -> close_item t ~id ~known_on ~kind:Resolved
            | [ "CLOSE"; id; known_on; "DROPPED" ] -> close_item t ~id ~known_on ~kind:Dropped
            | _ -> Error "Malformed or unsupported Attention row."
          in
          Result.bind updated (fun t -> parse t header rest)
  in
  parse empty false (String.split_on_char '\n' text)

let to_string t =
  let b = Buffer.create 1024 in
  Buffer.add_string b "LOAM-ATTENTION-MEMORY\t1\n";
  List.iter
    (fun (item : item) ->
      let due_kind, date_str =
        match item.due with
        | Due_on d -> ("DUE_ON", d)
        | No_due_date -> ("NO_DUE_DATE", "-")
        | Due_undetermined -> ("DUE_UNDETERMINED", "-")
      in
      Buffer.add_string b
        (Printf.sprintf "ITEM\t%s\t%s\t%s\t%s\n" item.id due_kind date_str
           (escape_text item.context)))
    t.items;
  List.iter
    (fun (c : closure) ->
      let kind_str = match c.kind with Resolved -> "RESOLVED" | Dropped -> "DROPPED" in
      Buffer.add_string b (Printf.sprintf "CLOSE\t%s\t%s\t%s\n" c.attention c.known_on kind_str))
    t.closures;
  Buffer.contents b
