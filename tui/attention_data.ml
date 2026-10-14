(* Attention model, serialization, and lifecycle operations *)

type due =
  | Due_on of string
  | No_due_date
  | Due_undetermined

type closure_kind =
  | Resolved
  | Dropped

type item = {
  id : string;
  context : string;
  due : due;
}

type closure = {
  attention : string;
  known_on : string;
  kind : closure_kind;
}

type t = {
  items : item list;
  closures : closure list;
}

let empty = { items = []; closures = [] }

let is_closed t id =
  List.exists (fun (c : closure) -> c.attention = id) t.closures

let open_items t =
  List.filter (fun (item : item) -> not (is_closed t item.id)) t.items

let closed_items t =
  List.filter (fun (item : item) -> is_closed t item.id) t.items

let find_item t id =
  List.find_opt (fun (item : item) -> item.id = id) t.items

let next_id t =
  Printf.sprintf "attention-%d" (List.length t.items + 1)

let due_label = function
  | Due_on d -> "Due: " ^ d
  | No_due_date -> "No due date"
  | Due_undetermined -> "Due: timing unknown"

let closure_kind_label = function
  | Resolved -> "Resolved"
  | Dropped -> "Dropped"

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
        | '\\' -> Buffer.add_char b '\\'; loop (i + 2)
        | 'n' -> Buffer.add_char b '\n'; loop (i + 2)
        | 'r' -> Buffer.add_char b '\r'; loop (i + 2)
        | 't' -> Buffer.add_char b '\t'; loop (i + 2)
        | _ -> Error "invalid escape"
    else (
      Buffer.add_char b s.[i];
      loop (i + 1)
    )
  in
  loop 0

let add_item t ~id ~context ~due =
  if String.trim id = "" then Error "Attention ID cannot be empty."
  else if List.exists (fun (item : item) -> item.id = id) t.items then
    Error (Printf.sprintf "Attention ID '%s' already exists." id)
  else if String.trim context = "" then
    Error "Attention context cannot be empty."
  else
    let item = { id; context = String.trim context; due } in
    Ok { t with items = t.items @ [item] }

let close_item t ~id ~known_on ~kind =
  match find_item t id with
  | None -> Error (Printf.sprintf "Attention ID '%s' not found." id)
  | Some _ ->
      if is_closed t id then
        Error (Printf.sprintf "Attention '%s' is already closed." id)
      else
        let closure = { attention = id; known_on; kind } in
        Ok { t with closures = t.closures @ [closure] }

let of_string text =
  let lines = String.split_on_char '\n' text in
  let rec parse items closures = function
    | [] -> Ok { items = List.rev items; closures = List.rev closures }
    | line :: rest ->
        let trimmed = String.trim line in
        if trimmed = "" || String.starts_with ~prefix:"#" trimmed || trimmed = "LOAM-ATTENTION-MEMORY\t1" then
          parse items closures rest
        else
          let parts = String.split_on_char '\t' line in
          match parts with
          | ["ITEM"; id; "DUE_ON"; date; escaped_context] -> (
              match unescape_text escaped_context with
              | Ok context ->
                  let item = { id; context; due = Due_on date } in
                  parse (item :: items) closures rest
              | Error _ -> parse items closures rest)
          | ["ITEM"; id; "NO_DUE_DATE"; _; escaped_context] -> (
              match unescape_text escaped_context with
              | Ok context ->
                  let item = { id; context; due = No_due_date } in
                  parse (item :: items) closures rest
              | Error _ -> parse items closures rest)
          | ["ITEM"; id; "DUE_UNDETERMINED"; _; escaped_context] -> (
              match unescape_text escaped_context with
              | Ok context ->
                  let item = { id; context; due = Due_undetermined } in
                  parse (item :: items) closures rest
              | Error _ -> parse items closures rest)
          | ["CLOSE"; id; known_on; "RESOLVED"] ->
              let closure = { attention = id; known_on; kind = Resolved } in
              parse items (closure :: closures) rest
          | ["CLOSE"; id; known_on; "DROPPED"] ->
              let closure = { attention = id; known_on; kind = Dropped } in
              parse items (closure :: closures) rest
          | _ -> parse items closures rest
  in
  parse [] [] lines

let to_string t =
  let b = Buffer.create 1024 in
  Buffer.add_string b "LOAM-ATTENTION-MEMORY\t1\n";
  List.iter
    (fun (item : item) ->
      let (due_kind, date_str) =
        match item.due with
        | Due_on d -> ("DUE_ON", d)
        | No_due_date -> ("NO_DUE_DATE", "-")
        | Due_undetermined -> ("DUE_UNDETERMINED", "-")
      in
      Buffer.add_string b
        (Printf.sprintf "ITEM\t%s\t%s\t%s\t%s\n" item.id due_kind date_str (escape_text item.context)))
    t.items;
  List.iter
    (fun (c : closure) ->
      let kind_str = match c.kind with Resolved -> "RESOLVED" | Dropped -> "DROPPED" in
      Buffer.add_string b (Printf.sprintf "CLOSE\t%s\t%s\t%s\n" c.attention c.known_on kind_str))
    t.closures;
  Buffer.contents b

let file_path ?config_home session_path =
  let dir = Filename.dirname session_path in
  let candidates =
    List.filter_map Fun.id
      [
        Option.map (fun h -> Filename.concat h "attention.loam") config_home;
        Option.map (fun h -> Filename.concat h "attention.tsv") config_home;
        Some (Filename.concat dir "attention.loam");
        Some (Filename.concat dir "attention.tsv");
      ]
  in
  match List.find_opt Sys.file_exists candidates with
  | Some existing -> existing
  | None ->
      (match config_home with
      | Some h when Sys.file_exists h -> Filename.concat h "attention.loam"
      | _ -> Filename.concat dir "attention.loam")

let load_file path =
  if not (Sys.file_exists path) then empty
  else
    try
      let ch = open_in path in
      let len = in_channel_length ch in
      let content = really_input_string ch len in
      close_in ch;
      match of_string content with
      | Ok t -> t
      | Error _ -> empty
    with Sys_error _ -> empty

let save_file path t =
  try
    let content = to_string t in
    let tmp = path ^ ".tmp" in
    let ch = open_out tmp in
    output_string ch content;
    close_out ch;
    Sys.rename tmp path;
    Ok ()
  with Sys_error why -> Error why
