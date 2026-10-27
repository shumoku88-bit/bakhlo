(* The window a report is compared with: the earlier windows of one kind, newest
   first, each with its EXPENSE total. *)
module O = Daily_overlays
module Panel = Ui_panel

type row = { offset : int; label : string; note : string; total : string }
type t = { rows : row array; selected : int; top : int }

let create rows ~offset =
  let rows = Array.of_list rows in
  let rec find i =
    if i >= Array.length rows then 0 else if rows.(i).offset = offset then i else find (i + 1)
  in
  { rows; selected = find 0; top = 0 }

let selected t = if t.selected < Array.length t.rows then Some t.rows.(t.selected) else None

(* The pane is as tall as its rows, inside the body. *)
let pane_size (body_w, body_h) t =
  let width = if body_w >= 44 then min 66 (body_w - 4) else body_w in
  let room = if body_h >= 12 then body_h - 2 else body_h in
  (width, min room (max 5 (Array.length t.rows + 2)))

let capacity ~body t = max 1 (snd (pane_size body t) - 2)

(* The first visible row keeps the selection in view. *)
let visible_top ~capacity t =
  if t.selected < t.top then t.selected
  else if t.selected >= t.top + capacity then t.selected - capacity + 1
  else t.top

type command = Stay | Choose of int | Close

let handle ~body t input =
  let capacity = capacity ~body t in
  let last = max 0 (Array.length t.rows - 1) in
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
  | Some (`Enter, _) -> (
      match selected t with Some row -> (t, Choose row.offset) | None -> (t, Close))
  | Some ((`Escape | `ASCII ('q' | 'c')), []) -> (t, Close)
  | _ -> (t, Stay)

(* A window's line: its days and note, then the EXPENSE total in a column as wide
   as the widest of the list. The total is never cut short: a narrower line drops
   the note first; only the days are ever clipped. *)
let row_text ~width_of ~width ~total_width row =
  let total = O.pad_left ~width_of total_width row.total in
  let fits left = width_of left + 2 + width_of total <= width in
  let with_note = if row.note = "" then row.label else row.label ^ "  " ^ row.note in
  match List.find_opt fits [ with_note; row.label ] with
  | Some left -> O.pad ~width_of (width - width_of total) left ^ total
  | None -> O.clip_text ~width_of width row.label

let frame ~width_of ~screen ~body t =
  let body_w, body_h = body in
  if body_w < 8 || body_h < 4 then None
  else
    let width, height = pane_size body t in
    let inner = width - 2 in
    let capacity = capacity ~body t in
    let top = visible_top ~capacity t in
    let total_width = Array.fold_left (fun w row -> max w (width_of row.total)) 0 t.rows in
    let list =
      if t.rows = [||] then [ (O.Status, " No earlier window of this kind.") ]
      else
        List.init
          (min capacity (Array.length t.rows - top))
          (fun i ->
            let index = top + i in
            let chosen = index = t.selected in
            ( (if chosen then O.Active else O.Plain),
              (if chosen then " > " else "   ")
              ^ row_text ~width_of ~width:(max 0 (inner - 4)) ~total_width t.rows.(index) ))
    in
    let position =
      if t.rows = [||] then None
      else Some (Printf.sprintf "%d/%d" (t.selected + 1) (Array.length t.rows))
    in
    Panel.frame_rows ~inset:0 ?bottom_label:position ~width_of ~width ~height ~focused:true
      ~title:"Compare with" list
    |> Ui_overlay.centered ~width_of ~screen ~body ~pane_width:width ~caret:`None

let footer ~width =
  if width >= 60 then
    [ "[j/k] window  [PgUp/PgDn] page  [Home/End]"; "[Enter] compare  [Esc/q/c] cancel" ]
  else [ "[j/k] window"; "[Enter] compare [Esc] cancel" ]
