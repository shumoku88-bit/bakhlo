(* Local reversal review; only the existing publisher constructs the durable inverse. *)
module B = Bakhlo_household.Daily_book
module D = Bakhlo_domain
module A = Daily_draft
module O = Daily_overlays
module Form = Ui_form
module Panel = Ui_panel

let tr = Ui_text.tr

type t = {
  book : B.t;
  target : B.entry;
  base_revision : string;
  form : Form.t;
  preview : bool;
  scroll : int;
  action : int;
}

type outcome = Updated of t | Closed | Publish of string * string * string

let create ~book ~base_revision ~day (target : B.entry) =
  let form =
    Form.create ~id:"reverse_entry" ~payload:target.id ~title:"Actual / Reverse / Date"
      ~summary:[ "Target: " ^ target.id; "Target date: " ^ target.day ]
      ~fields:
        [
          Form.text_field ~id:"date" ~label:"Reversal on" ~value:day ();
          Form.action_buttons ~confirm:"Preview reversal" ~cancel:"Keep Actual" ();
        ]
      ()
  in
  { book; target; base_revision; form; preview = false; scroll = 0; action = 0 }

let is_preview t = t.preview
let base_revision t = t.base_revision
let day t = Option.value ~default:"" (Form.get_text t.form "date")
let edit t = { t with preview = false; form = Form.set_focused (Form.set_notice t.form "") 0 }
let with_publish_error = edit

let dimensions (width, height) =
  if width >= 76 && height >= 19 then (min 72 (width - 4), min 24 (height - 2))
  else (max 0 width, max 0 height)

let posting t inverse original =
  let quantity = A.quanta original in
  let quantity = if inverse then Z.neg quantity else quantity in
  let measure = A.mstr (D.Effect.measure original) in
  A.lstr (D.Effect.locus original)
  ^ "  "
  ^ (if Z.sign quantity > 0 then "+" else "")
  ^ B.format t.book measure quantity ^ " " ^ measure

let review_rows t =
  [
    "Target: " ^ t.target.id;
    "Target date: " ^ t.target.day;
    "Description: " ^ Option.value ~default:"(no description)" t.target.memo;
    "Reversal date: " ^ day t;
    "Original retained; a new inverse Actual is added.";
    "";
    "Original postings:";
  ]
  @ List.map (posting t false) t.target.effects
  @ [ ""; "Inverse postings:" ]
  @ List.map (posting t true) t.target.effects

let viewport ~dimensions:(width, height) ~width_of t =
  let rows = List.concat_map (O.wrap_text ~width_of (max 1 (width - 6))) (review_rows t) in
  (rows, Panel.preview_window ~height ~count:(List.length rows) ~scroll:t.scroll ())

let with_notice t notice = { t with form = Form.set_notice t.form (tr notice) }

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
          if blocked then Updated (with_notice t "Writes stopped; draft retained.")
          else
            match A.normalize_date (day t) with
            | Error _ -> Updated (with_notice t "Enter a real Gregorian date.")
            | Ok day when not (A.is_valid_canonical_date day) ->
                Updated (with_notice t "Enter a real Gregorian date.")
            | Ok day ->
                Updated
                  {
                    t with
                    preview = true;
                    scroll = 0;
                    action = 0;
                    form = Form.set_notice (Form.set_text t.form "date" day) "";
                  }))
  | `Key (`ASCII ('e' | 'E'), []) -> Updated (edit t)
  | `Key ((`Tab | `Arrow `Right), []) -> Updated { t with action = (t.action + 1) mod 3 }
  | `Key (`Tab, [ `Shift ]) | `Key (`Arrow `Left, []) ->
      Updated { t with action = (t.action + 2) mod 3 }
  | `Key ((`Arrow (`Up | `Down) | `ASCII ('j' | 'k') | `Page _ | `Home | `End), [])
  | `Key (`ASCII ('u' | 'd'), [ `Ctrl ]) ->
      Updated { t with scroll = Panel.review_scroll view input }
  | `Key (`Enter, []) ->
      if t.action = 1 then Updated (edit t)
      else if t.action = 2 then Closed
      else if blocked then Updated (with_notice t "Writes stopped; draft retained.")
      else if width < 32 || height < 12 || view.capacity = 0 || (height < 16 && view.last > 0) then
        Updated (with_notice t "Enlarge terminal to review.")
      else if view.start < view.last then
        Updated (with_notice t "Review to the end before Publish.")
      else Publish (t.target.id, day t, t.base_revision)
  | _ -> Updated t

let footer t =
  if t.preview then [ "j/k PgUp/Dn Home/End review"; "Enter action  Tab  Esc/e edit  q keep" ]
  else [ "Enter preview  Tab action  Esc/q keep"; "Only the reversal date is editable" ]

let screen ~dimensions:((width, height) as dimensions) ~width_of t =
  let rows =
    if not t.preview then Form.render_panel ~width_of ~width ~height t.form
    else
      let rows, view = viewport ~dimensions ~width_of t in
      let actions =
        [ "Publish"; "Edit"; "Cancel" ]
        |> List.mapi (fun i label -> if t.action = i then "[" ^ label ^ "]" else label)
        |> String.concat "  "
      in
      Panel.preview ~width_of ~width ~height ~title:"Actual / Reverse / Preview" ~scroll:view.start
        ~notice:(Form.notice t.form) ~action:(" " ^ actions) rows
  in
  List.filteri (fun i _ -> i < max 0 height) rows
  |> List.map (fun (style, text) -> (style, O.pad ~width_of width text))
