(* Date-only editing keeps the captured Actual intact until the existing publisher accepts it. *)
module B = Bakhlo_sexp.Daily_book
module A = Daily_draft
module O = Daily_overlays
module Form = Ui_form
module Panel = Ui_panel

type t = { target : B.entry; base_revision : string; form : Form.t; preview : bool; scroll : int }
type outcome = Updated of t | Closed | Publish of A.transaction * string

let create ~base_revision (target : B.entry) =
  let form =
    Form.create ~id:"actual_date" ~title:"Actual / Date / Edit"
      ~summary:[ "Current date: " ^ target.day; "Target Actual: " ^ O.visible target.id ]
      ~fields:
        [
          Form.text_field ~id:"date" ~label:"New date" ~value:target.day ();
          Form.action_buttons ~confirm:"Preview date change" ~cancel:"Keep Actual" ();
        ]
      ()
  in
  { target; base_revision; form; preview = false; scroll = 0 }

let base_revision t = t.base_revision
let day t = Option.value ~default:"" (Form.get_text t.form "date")
let is_preview t = t.preview

let edit t =
  { t with preview = false; scroll = 0; form = Form.set_focused (Form.set_notice t.form "") 0 }

let with_notice t notice = { t with form = Form.set_notice t.form notice }

let dimensions (width, height) =
  if width >= 76 && height >= 18 then (min 72 (width - 4), min 16 (height - 2))
  else (max 0 width, max 0 height)

let viewport ~dimensions:(width, height) ~width_of t =
  let rows =
    [
      "Current date: " ^ t.target.day;
      "Proposed date: " ^ day t;
      "Target Actual: " ^ O.visible t.target.id;
      "Only the occurrence date changes.";
    ]
    |> List.concat_map (O.wrap_text ~width_of (max 1 (width - 6)))
  in
  (rows, Panel.preview_window ~height ~count:(List.length rows) ~scroll:t.scroll ())

let handle ~blocked ~dimensions:((width, height) as dimensions) ~width_of t input =
  let _, view = viewport ~dimensions ~width_of t in
  let t = { t with scroll = view.start } in
  match input with
  | `Key (`ASCII ('q' | 'Q'), []) -> Closed
  | `Key (`Escape, []) -> if t.preview then Updated (edit t) else Closed
  | _ when not t.preview -> (
      match Form.handle_input t.form input with
      | Form.Cancel -> Closed
      | Form.Updated form -> Updated { t with form }
      | Form.Submit form -> (
          let t = { t with form } in
          if blocked then Updated (with_notice t "Writes stopped; date retained.")
          else
            match A.normalize_date (day t) with
            | Ok day when A.is_valid_canonical_date day ->
                Updated
                  {
                    t with
                    preview = true;
                    scroll = 0;
                    form = Form.set_notice (Form.set_text form "date" day) "";
                  }
            | _ -> Updated (with_notice t "Enter a real Gregorian date.")))
  | `Key (`ASCII ('e' | 'E'), []) -> Updated (edit t)
  | `Key ((`Arrow (`Up | `Down) | `ASCII ('j' | 'k') | `Page _ | `Home | `End), []) ->
      Updated { t with scroll = Panel.review_scroll view input }
  | `Key (`Enter, []) ->
      if blocked then Updated (with_notice t "Writes stopped; date retained.")
      else if width < 46 || height < 14 || view.capacity = 0 then
        Updated (with_notice t "Enlarge terminal to review the date and target before Publish.")
      else if view.start < view.last then
        Updated (with_notice t "Review to the end before Publish.")
      else
        Publish
          ({ A.entry = { t.target with day = day t }; replace = true; plan = None }, t.base_revision)
  | _ -> Updated t

let footer t =
  if t.preview then
    [ "Enter publish date change  Esc/e edit  q cancel"; "j/k PgUp/Dn Home/End review" ]
  else [ "Enter preview  Tab action  Esc/q cancel"; "Only the occurrence date is editable" ]

let screen ~dimensions:((width, height) as dimensions) ~width_of t =
  let rows =
    if not t.preview then Form.render_panel ~width_of ~width ~height t.form
    else
      let rows, view = viewport ~dimensions ~width_of t in
      Panel.preview ~width_of ~width ~height ~title:"Actual / Date / Preview" ~scroll:view.start
        ~notice:(Form.notice t.form) ~action:" [Publish date change]" rows
  in
  List.filteri (fun i _ -> i < max 0 height) rows
  |> List.map (fun (style, text) -> (style, O.pad ~width_of width text))
