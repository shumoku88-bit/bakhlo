(* One report frame shared by the report screens: a full-width body, one clamped
   scroll model with a position row, and a [?] help overlay. Formulas, key lists
   and principles never take a permanent pane. The frame is an immutable value:
   the handler and the renderer compute the same row count from the screen's pure
   row builder, so rendering never mutates state. *)

type t = { scroll : int }

let create = { scroll = 0 }

(* Content rows inside one framed panel: two borders and the position row. The
   handler and the body both use this one function. *)
let capacity (geometry : Screen.geometry) = max 0 (snd geometry.content - 2)

let last ~count ~capacity = max 0 (count - capacity)
let clamp ~count ~capacity t = { scroll = max 0 (min (last ~count ~capacity) t.scroll) }

(* Selection uses the same rendered count, so [End] cannot poison the next step. *)
let clamp_index ~count index = if count <= 0 then 0 else max 0 (min (count - 1) index)

type move = Line of int | Page of int | Top | Bottom

(* The one scroll model: j/k and arrows by line, page keys by page, Home/End and
   g/G by content. *)
let scroll_move input =
  let key k = `Key (k, []) in
  if input = key (`ASCII 'j') || input = key (`Arrow `Down) then Some (Line 1)
  else if input = key (`ASCII 'k') || input = key (`Arrow `Up) then Some (Line (-1))
  else if input = key (`Page `Down) || input = `Key (`ASCII 'd', [ `Ctrl ]) then Some (Page 1)
  else if input = key (`Page `Up) || input = `Key (`ASCII 'u', [ `Ctrl ]) then Some (Page (-1))
  else if input = key `Home || input = key (`ASCII 'g') then Some Top
  else if input = key `End || input = key (`ASCII 'G') then Some Bottom
  else None

(* The page direction only, for screens that keep their own step or position. *)
let page_delta = function
  | Some (`Page `Up, []) | Some (`ASCII 'u', [ `Ctrl ]) -> Some (-1)
  | Some (`Page `Down, []) | Some (`ASCII 'd', [ `Ctrl ]) -> Some 1
  | _ -> None

let apply ~count ~capacity t = function
  | Line delta -> { scroll = max 0 (min (last ~count ~capacity) (t.scroll + delta)) }
  | Page delta -> { scroll = max 0 (min (last ~count ~capacity) (t.scroll + (delta * capacity))) }
  | Top -> { scroll = 0 }
  | Bottom -> { scroll = last ~count ~capacity }

(* Consumes only the shared scroll keys. *)
let handle ~count ~capacity t input =
  Option.map (apply ~count ~capacity t) (scroll_move input)

let position ~count ~capacity t =
  let capacity = max 0 capacity in
  if count = 0 then "0 / 0"
  else
    let start = min t.scroll (max 0 (count - capacity)) in
    Printf.sprintf "%d–%d / %d" (start + 1) (min count (start + capacity)) count

let slice ~capacity t rows =
  let capacity = max 0 capacity in
  List.filteri (fun i _ -> i >= t.scroll && i < t.scroll + capacity) rows
  |> List.map (fun (style, text) -> (style, " " ^ text))

let footer =
  [
    "j/k line  PgUp/PgDn page  Home/End ends  g/G top/bottom  ? help";
    "1-5 period  [ / ] shift  p print  q/Esc Home";
  ]

let help_footer = [ "? / Esc close help"; "" ]

let help_form ~title lines =
  Ui_form.create ~id:"report_help" ~title:(Ui_text.tr title) ~summary:lines
    ~fields:
      [
        Ui_form.buttons_field ~id:"action"
          ~buttons:[ { Ui_form.label = "Close"; is_cancel = true } ]
          ();
      ]
    ()

(* Body rows for the current scroll, with the shared position row. *)
let body ~geometry ~count ~title t rows =
  let width, height = geometry.Screen.content in
  let capacity = max 0 (height - 2) in
  let shown = slice ~capacity t rows in
  Ui_panel.frame_rows ~inset:0
    ~bottom_label:(position ~count ~capacity t)
    ~width_of:geometry.width_of ~width ~height ~focused:true ~title shown

(* A single full-width framed block that is not scrollable (refusals). *)
let block ~geometry ~title rows =
  let width, height = geometry.Screen.content in
  let capacity = max 0 (height - 2) in
  let shown =
    List.filteri (fun i _ -> i < capacity) rows
    |> List.map (fun (style, text) -> (style, " " ^ text))
  in
  Ui_panel.frame_rows ~inset:0 ~width_of:geometry.width_of ~width ~height ~focused:true ~title
    shown

(* A report's body plan, shared by the renderer and the handler's row count:
   scrollable rows, or a fixed block (refusals). *)
type content =
  | Body of string * (Ui_render.style * string) list
  | Block of string * (Ui_render.style * string) list

let count = function Body (_, rows) -> List.length rows | Block _ -> 0

let rows ~geometry t = function
  | Block (title, rows) -> block ~geometry ~title rows
  | Body (title, rows) -> body ~geometry ~count:(List.length rows) ~title t rows
