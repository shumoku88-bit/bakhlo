(* Terminal cell geometry, text clipping/wrapping and framed panel rows.
   Pure presentation primitives: no book, editor or screen knowledge. *)
type style =
  | Plain
  | Active
  | Heading
  | Status
  | Chrome
  | Frame
  | Focused_frame
  | Calendar_dates
  | Bonsai
  | Entrance
  | Panel
  | Panel_heading
  | Panel_active
  (* Two independently styled panes separated by one physical space. *)
  | Columns of int * style * style
  (* Physical cell of the actual caret, never inferred from user text. *)
  | Input of int

let panel_width = 34

let utf8 c =
  let b = Buffer.create 4 in
  Uutf.Buffer.add_utf_8 b c;
  Buffer.contents b

let printable_uchar c =
  let n = Uchar.to_int c in
  n >= 32 && (n < 127 || n > 159)

let visible text =
  let b = Buffer.create (String.length text) in
  Uutf.String.fold_utf_8
    (fun () _ -> function
      | `Uchar c ->
          let n = Uchar.to_int c in
          if n < 32 || (n >= 127 && n <= 159) then
            Buffer.add_string b (Printf.sprintf "\\\\u%04x" n)
          else Uutf.Buffer.add_utf_8 b c
      | `Malformed bytes ->
          String.iter
            (fun c -> Buffer.add_string b (Printf.sprintf "\\\\x%02x" (Char.code c)))
            bytes)
    () text;
  Buffer.contents b

let clip_text ~width_of room value =
  let text = visible value in
  if room <= 0 then ""
  else if width_of text <= room then text
  else
    let _, prefix =
      Uutf.String.fold_utf_8
        (fun (stopped, prefix) _ -> function
          | `Uchar c when not stopped ->
              let next = prefix ^ utf8 c in
              if width_of next <= room - width_of "…" then (false, next) else (true, prefix)
          | `Uchar _ | `Malformed _ -> (stopped, prefix))
        (false, "") text
    in
    if width_of "…" <= room then prefix ^ "…" else String.make room '.'

let tail_text ~width_of room text =
  if width_of text <= room then text
  else
    let chars =
      Uutf.String.fold_utf_8
        (fun xs _ -> function `Uchar c -> utf8 c :: xs | `Malformed _ -> xs)
        [] text
    in
    let _, suffix =
      List.fold_left
        (fun (stopped, suffix) glyph ->
          if stopped || width_of (glyph ^ suffix) > max 0 (room - width_of "…") then (true, suffix)
          else (false, glyph ^ suffix))
        (false, "") chars
    in
    clip_text ~width_of room ("…" ^ suffix)

let input_text ~width_of ~width ~cursor ~caret value =
  if width <= 0 then ("", None)
  else if width_of caret <> 1 then (clip_text ~width_of width value, None)
  else
    let pos = Daily_form.cursor_pos ~value cursor in
    let left = visible (String.sub value 0 pos) in
    let left = tail_text ~width_of (width - 1) left in
    let column = width_of left in
    let right = String.sub value pos (String.length value - pos) in
    (left ^ caret ^ clip_text ~width_of (width - column - 1) right, Some column)

let rec input_cell ~width = function
  | _ when width <= 0 -> None
  | Input column when column >= 0 && column < width -> Some column
  | Columns (left_width, left, right) when left_width >= 0 -> (
      match input_cell ~width:(min width left_width) left with
      | Some _ as cell -> cell
      | None when left_width < width ->
          Option.map
            (fun column -> left_width + 1 + column)
            (input_cell ~width:(width - left_width - 1) right)
      | None -> None)
  | _ -> None

let cursor_in_rows ~width_of ~width rows =
  let rec find row = function
    | [] -> None
    | (style, text) :: rest -> (
        match input_cell ~width style with
        | Some column when column < width_of text -> Some (column, row)
        | _ -> find (row + 1) rest)
  in
  find 0 rows

let pad ~width_of width value =
  let text = clip_text ~width_of width value in
  text ^ String.make (max 0 (width - width_of text)) ' '

let pad_left ~width_of width value =
  let text = clip_text ~width_of width value in
  String.make (max 0 (width - width_of text)) ' ' ^ text

let panel_line ?(width = panel_width) ~width_of style text =
  let left = "│ " and right = " │" in
  let room = max 0 (width - width_of left - width_of right) in
  (style, left ^ pad ~width_of room text ^ right)

let rule ~width_of room =
  let cells = max 1 (width_of "─") in
  String.concat "" (List.init (max 0 room / cells) (fun _ -> "─"))
  ^ String.make (max 0 room mod cells) ' '

let panel_border ?(width = panel_width) ?(style = Focused_frame) ?(inset = 1) ~width_of title =
  let left = "╭" ^ rule ~width_of (max 0 inset) and right = rule ~width_of (max 0 inset) ^ "╮" in
  let room = max 0 (width - width_of left - width_of right) in
  let title = clip_text ~width_of room (" " ^ title ^ " ") in
  (style, left ^ title ^ rule ~width_of (room - width_of title) ^ right)

let panel_bottom ?(width = panel_width) ?(style = Focused_frame) ?(title = "") ~width_of () =
  let room = max 0 (width - width_of "╰╯") in
  let title = if title = "" then "" else clip_text ~width_of room (" " ^ title ^ " ") in
  (style, "╰" ^ title ^ rule ~width_of (room - width_of title) ^ "╯")

let wrap_text ~width_of room text =
  if room <= 0 then []
  else
    let lines, last =
      Uutf.String.fold_utf_8
        (fun (lines, current) _ -> function
          | `Malformed _ -> (lines, current)
          | `Uchar c ->
              let glyph = utf8 c in
              let glyph =
                if width_of glyph <= room then glyph else clip_text ~width_of room glyph
              in
              let next = current ^ glyph in
              if current = "" || width_of next <= room then (lines, next)
              else (current :: lines, glyph))
        ([], "") (visible text)
    in
    List.rev (last :: lines)

let review_page ~dimensions:(width, height) ~width_of lines scroll =
  let width = max 4 (min 76 (width - 4)) in
  let capacity = max 1 (height - 7) in
  let lines = List.concat_map (wrap_text ~width_of (max 1 (width - 4))) lines in
  let last = max 0 (List.length lines - capacity) in
  (width, capacity, lines, min last (max 0 scroll), last)
