(* Local reversal review; only the existing publisher constructs the durable inverse. *)
module B = Bakhlo_sexp.Daily_book
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

let posting t inverse effect =
  let quantity = A.quanta effect in
  let quantity = if inverse then Z.neg quantity else quantity in
  let measure = A.mstr (D.Effect.measure effect) in
  A.lstr (D.Effect.locus effect)
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
  let view =
    Panel.window
      ~capacity:(Panel.capacity ~height:(max 0 (height - 2)) ~heading:false)
      ~count:(List.length rows) ~scroll:t.scroll ~selected:None
  in
  (rows, view)

let with_notice t notice = { t with form = Form.set_notice t.form (tr notice) }

let handle ~blocked ~dimensions:((width, height) as dimensions) ~width_of t input =
  let _, view = viewport ~dimensions ~width_of t in
  let t = { t with scroll = view.start } in
  let move delta =
    Updated { t with scroll = Panel.move ~last:view.last ~position:view.start delta }
  in
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
  | `Key ((`Arrow `Up | `ASCII 'k'), []) -> move (-1)
  | `Key ((`Arrow `Down | `ASCII 'j'), []) -> move 1
  | `Key (`Page `Up, []) | `Key (`ASCII 'u', [ `Ctrl ]) -> move (-max 1 view.capacity)
  | `Key (`Page `Down, []) | `Key (`ASCII 'd', [ `Ctrl ]) -> move (max 1 view.capacity)
  | `Key (`Home, []) -> Updated { t with scroll = 0 }
  | `Key (`End, []) -> Updated { t with scroll = view.last }
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
    if not t.preview then
      Panel.frame_rows ~width_of ~width ~height ~focused:true ~title:(Form.title t.form)
        (Form.render_rows
           ~width:(max 0 (width - 6))
           ~height:(Panel.capacity ~height ~heading:false)
           ~width_of t.form)
    else
      let rows, view = viewport ~dimensions ~width_of t in
      let actions =
        [ "Publish"; "Edit"; "Cancel" ]
        |> List.mapi (fun i label -> if t.action = i then "[" ^ label ^ "]" else label)
        |> String.concat "  "
      in
      Panel.frame ~width_of ~width
        ~height:(max 0 (height - 2))
        ~focused:true ~title:"Actual / Reverse / Preview" ~scroll:view.start ~selected:None rows
      @ [
          (O.Status, O.clip_text ~width_of width (Form.notice t.form));
          (O.Active, O.clip_text ~width_of width (" " ^ actions));
        ]
  in
  List.filteri (fun i _ -> i < max 0 height) rows
  |> List.map (fun (style, text) -> (style, O.pad ~width_of width text))
