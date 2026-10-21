(* One report frame shared by the report screens: a full-width body, one clamped
   scroll model with a position row, and a [?] help overlay. Formulas, key
   lists and principles never take a permanent pane. *)

type t = { mutable scroll : int; mutable count : int }

let create () = { scroll = 0; count = 0 }

(* Content rows inside one framed panel: two borders and the position row. *)
let capacity (geometry : Screen.geometry) = max 1 (snd geometry.content - 2)

let last ~capacity t = max 0 (t.count - capacity)
let clamp ~capacity t = t.scroll <- max 0 (min (last ~capacity t) t.scroll)

(* Selection uses the same rendered count, so [End] cannot poison the next step. *)
let clamp_index t index = if t.count <= 0 then 0 else max 0 (min (t.count - 1) index)

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

let apply_move ~capacity t = function
  | Line delta -> t.scroll <- max 0 (min (last ~capacity t) (t.scroll + delta))
  | Page delta -> t.scroll <- max 0 (min (last ~capacity t) (t.scroll + (delta * capacity)))
  | Top -> t.scroll <- 0
  | Bottom -> t.scroll <- last ~capacity t

(* Consumes only the shared scroll keys. Returns true when the key was used. *)
let handle ~geometry t input =
  match scroll_move input with
  | Some movement ->
      apply_move ~capacity:(capacity geometry) t movement;
      true
  | None -> false

let position ~capacity t =
  let capacity = max 0 capacity in
  if t.count = 0 then "0 / 0"
  else
    let start = min t.scroll (max 0 (t.count - capacity)) in
    Printf.sprintf "%d–%d / %d" (start + 1) (min t.count (start + capacity)) t.count

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

(* Body rows for the current scroll, with the shared position row. Sets
   [count] so selection and End clamp against what is actually rendered. *)
let body ~geometry ~title t rows =
  let width, height = geometry.Screen.content in
  let capacity = max 0 (height - 2) in
  t.count <- List.length rows;
  clamp ~capacity t;
  let shown =
    List.map (fun (style, text) -> (style, " " ^ text))
      (List.filteri (fun i _ -> i >= t.scroll && i < t.scroll + capacity) rows)
  in
  Ui_panel.frame_rows ~inset:0 ~bottom_label:(position ~capacity t) ~width_of:geometry.width_of
    ~width ~height ~focused:true ~title shown

(* A single full-width framed block that is not scrollable (refusals, help). *)
let block ~geometry ~title rows =
  let width, height = geometry.Screen.content in
  let capacity = max 0 (height - 2) in
  let shown =
    List.map (fun (style, text) -> (style, " " ^ text)) (List.filteri (fun i _ -> i < capacity) rows)
  in
  Ui_panel.frame_rows ~inset:0 ~width_of:geometry.width_of ~width ~height ~focused:true ~title
    shown
