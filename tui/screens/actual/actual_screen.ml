(* Actual route owner: the LOAM three-pane Actuals workspace. Record actions on
   the selected entry are requests to the Shell, which owns the retained Record
   draft and the editor sessions. *)
module Act = Actual_workspace

type t = Act.t

let config_files = []
let create () = Act.create ~focus_date:"1970-01-01"
let enter ~focus_day _t = Act.create ~focus_date:focus_day
let modal _t = false
let saved _env _geometry _result t = (t, Screen.Stay)

let book_changed ~before ~after t =
  let t = Act.returned_from_detail ~before_book:before ~after_book:after t in
  (t, Act.notice t)

let action (env : Screen.env) t action =
  (t, Screen.Record_action { action;
        target = Option.map (fun e -> Screen.Entry e) (Act.selected_entry ~book:env.book t) })

let handle (env : Screen.env) (geometry : Screen.geometry) t input =
  let typing = Act.search_editing t in
  match input with
  | `Key (`ASCII ' ', []) when not typing -> (t, Screen.Commands)
  | `Key (`ASCII ('c' | 'C' | 'e' | 'E'), []) when not typing -> action env t Screen.Edit
  | `Key (`ASCII ('x' | 'X'), []) when not typing -> action env t Screen.Reverse
  | `Key (`ASCII ('d' | 'D'), []) when not typing -> action env t Screen.Correct_date
  | `Key (`ASCII ('m' | 'M'), []) when not typing -> action env t Screen.Classify_merchant
  | _ -> (
      let next, command =
        Act.handle ~book:env.book ~dimensions:geometry.content ~width_of:geometry.width_of t input in
      match command with
      | Act.Stay | Act.Redraw -> (next, Screen.Message (Act.notice next))
      | Act.Open_selected entry -> (next, Screen.Drill { day = entry.day; entry = entry.id })
      | Act.Record_new -> (next, Screen.New_record)
      | Act.Back -> (next, Screen.Home))

let view (env : Screen.env) (geometry : Screen.geometry) t =
  let width_of = geometry.width_of in
  {
    Screen.title = Ui_text.tr "Actual" ^ "  |  " ^ Act.scope_text t ^ "  |  "
                   ^ Act.current_locus_name ~book:env.book t;
    subtitle =
      (if Act.search_editing t || Act.search_query t <> "" then
         let style, text = Act.search_line ~width:(fst geometry.screen) ~width_of t in
         Screen.Styled (style, text)
       else Screen.Default);
    rows = lazy (Act.screen ~book:env.book ~today:env.today ~draft_retained:env.draft_retained
                   ~dimensions:geometry.content ~width_of t);
    footer = Act.footer ~dimensions:geometry.screen ~width_of t;
    overlay = None;
    cursor = Act.cursor_position ~dimensions:geometry.content ~width_of t;
  }
