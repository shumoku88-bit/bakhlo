(* Cancellation captures its review evidence; the existing writer rechecks lifecycle and base. *)
module B = Bakhlo_sexp.Daily_book
module A = Daily_draft
module O = Daily_overlays
module Form = Ui_form
module Panel = Ui_panel

type t = {
  book : B.t;
  target : B.plan;
  base_revision : string;
  form : Form.t;
  preview : bool;
  cancel_selected : bool;
  scroll : int;
}

type outcome = Updated of t | Closed | Publish of string * string * string

let create ~book ~base_revision ~day (target : B.plan) =
  let form =
    Form.create ~id:"cancel_plan" ~title:"Scheduled / Cancel / Date"
      ~summary:[ "Target: " ^ O.visible target.id; "Due: " ^ target.day ]
      ~fields:
        [
          Form.text_field ~id:"date" ~label:"Cancel on" ~value:day ();
          Form.action_buttons ~confirm:"Preview cancellation" ~cancel:"Keep" ();
        ]
      ()
  in
  { book; target; base_revision; form; preview = false; cancel_selected = false; scroll = 0 }

let base_revision t = t.base_revision
let day t = Option.value ~default:"" (Form.get_text t.form "date")
let is_preview t = t.preview
let with_publish_error t = { t with cancel_selected = false }

let edit t =
  {
    t with
    preview = false;
    cancel_selected = false;
    scroll = 0;
    form = Form.set_focused (Form.set_notice t.form "") 0;
  }

let with_notice t notice = { t with form = Form.set_notice t.form notice }

let dimensions (width, height) =
  if width >= 76 && height >= 19 then (min 72 (width - 4), min 24 (height - 2))
  else (max 0 width, max 0 height)

let viewport ~dimensions:(width, height) ~width_of t =
  let rows =
    [ "Cancel on: " ^ day t; "Retirement keeps history; no deletion."; "" ]
    @ O.plan_lines t.book t.target
    |> List.concat_map (O.wrap_text ~width_of (max 1 (width - 6)))
  in
  let view =
    Panel.window
      ~capacity:(Panel.capacity ~height:(max 0 (height - 2)) ~heading:false)
      ~count:(List.length rows) ~scroll:t.scroll ~selected:None
  in
  (rows, view)

let handle ~blocked ~dimensions:((width, height) as dimensions) ~width_of t input =
  let _, view = viewport ~dimensions ~width_of t in
  let t = { t with scroll = view.start } in
  let move delta =
    Updated { t with scroll = Panel.move ~last:view.last ~position:view.start delta }
  in
  match input with
  | `Key ((`Escape | `ASCII 'q' | `ASCII 'Q'), []) -> Closed
  | _ when not t.preview -> (
      match Form.handle_input t.form input with
      | Form.Cancel -> Closed
      | Form.Updated form -> Updated { t with form }
      | Form.Submit form -> (
          let t = { t with form } in
          if blocked then Updated (with_notice t "Writes stopped; cancellation retained.")
          else
            match A.normalize_date (day t) with
            | Ok day when A.is_valid_canonical_date day ->
                Updated
                  {
                    t with
                    preview = true;
                    cancel_selected = false;
                    scroll = 0;
                    form = Form.set_notice (Form.set_text form "date" day) "";
                  }
            | _ -> Updated (with_notice t "Enter a real Gregorian date.")))
  | `Key (`ASCII ('e' | 'E'), []) -> Updated (edit t)
  | `Key ((`Tab | `Arrow `Left | `Arrow `Right), []) | `Key (`Tab, [ `Shift ]) ->
      Updated { t with cancel_selected = not t.cancel_selected }
  | `Key ((`Arrow `Up | `ASCII 'k'), []) -> move (-1)
  | `Key ((`Arrow `Down | `ASCII 'j'), []) -> move 1
  | `Key (`Page `Up, []) -> move (-max 1 view.capacity)
  | `Key (`Page `Down, []) -> move (max 1 view.capacity)
  | `Key (`Home, []) -> Updated { t with scroll = 0 }
  | `Key (`End, []) -> Updated { t with scroll = view.last }
  | `Key (`Enter, []) ->
      if not t.cancel_selected then Closed
      else if blocked then Updated (with_notice t "Writes stopped; cancellation retained.")
      else if width < 46 || height < 14 || view.capacity = 0 || (height < 16 && view.last > 0) then
        Updated (with_notice t "Enlarge terminal to review the Scheduled effects.")
      else if view.start < view.last then
        Updated (with_notice t "Review to the end before cancelling.")
      else Publish (t.target.id, day t, t.base_revision)
  | _ -> Updated t

let footer t =
  if t.preview then
    [
      "Tab/Left/Right select  Enter confirm  Esc/q keep"; "j/k PgUp/Dn Home/End review  e edit date";
    ]
  else [ "Enter preview  Tab action  Esc/q keep"; "No Scheduled change before confirmation" ]

let screen ~dimensions:((width, height) as dimensions) ~width_of t =
  let rows =
    if not t.preview then Form.render_panel ~width_of ~width ~height t.form
    else
      let rows, view = viewport ~dimensions ~width_of t in
      let actions =
        if t.cancel_selected then " [Cancel Scheduled]  Keep" else " Cancel Scheduled  [Keep]"
      in
      Panel.preview ~width_of ~width ~height ~title:"Scheduled / Cancel / Preview"
        ~scroll:view.start ~notice:(Form.notice t.form) ~action:actions rows
  in
  List.filteri (fun i _ -> i < max 0 height) rows
  |> List.map (fun (style, text) -> (style, O.pad ~width_of width text))
