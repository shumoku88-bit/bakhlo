module B = Bakhlo_sexp.Daily_book
module O = Daily_overlays
module Panel = Ui_panel
module Form = Ui_form
module A = Daily_draft

type t = {
  book : B.t;
  source : B.plan;
  base_bytes : string;
  form : Form.t;
  candidates : B.plan list;
  selected : string list;
  selecting : bool;
  focus : int;
  preview_plans : B.plan list option;
  choice : int;
  scroll : int;
  notice : string;
}

type outcome = Updated of t | Closed | Publish of B.plan list * string

let negative_loci (plan : B.plan) =
  plan.changes
  |> List.filter_map (fun (locus, amount) -> if Z.sign amount < 0 then Some locus else None)
  |> List.sort_uniq String.compare

let positive_loci (plan : B.plan) =
  plan.changes
  |> List.filter_map (fun (locus, amount) -> if Z.sign amount > 0 then Some locus else None)
  |> List.sort_uniq String.compare

let shape plan = negative_loci plan, positive_loci plan

let valid_date date =
  match A.normalize_date date with
  | Ok canonical -> canonical = date && A.is_valid_canonical_date canonical
  | Error _ -> false

let matching_candidates book (source : B.plan) =
  let open_plans = B.open_plans book in
  if not (List.exists (( = ) source) open_plans) then
    Error "Source is no longer a current-open Scheduled plan."
  else if negative_loci source = [] || positive_loci source = [] then
    Error "Source needs both negative and positive Locus sides."
  else
    Ok
      (open_plans
      |> List.filter (fun (plan : B.plan) ->
             plan.measure = source.measure && shape plan = shape source)
      |> List.sort (fun (left : B.plan) right ->
             let by_date = String.compare left.day right.day in
             if by_date = 0 then String.compare left.id right.id else by_date))

let create ~book ~base_bytes ~from_day (source : B.plan) =
  match matching_candidates book source with
  | Error message -> Error message
  | Ok candidates ->
      let form =
        Form.create ~id:"scheduled_bulk" ~title:"Scheduled / Bulk amount"
          ~summary:
            [ "Source: " ^ O.visible source.id;
              "Matching current-open plans; no series is inferred." ]
          ~fields:
            [ Form.text_field ~id:"amount" ~label:("Amount (" ^ O.visible source.measure ^ ")") ();
              Form.text_field ~id:"from" ~label:"From" ~value:from_day ();
              Form.text_field ~id:"through" ~label:"Through (optional)" () ] ()
      in
      Ok
        { book; source; base_bytes; form; candidates; selected = [];
          selecting = false; focus = 0; preview_plans = None; choice = 0;
          scroll = 0; notice = "" }

let base_bytes session = session.base_bytes
let with_publish_error session message = { session with notice = message; choice = 0 }
let dimensions (width, height) = max 0 width, max 0 height
let text session field = Option.value ~default:"" (Form.get_text session.form field)

let in_range (plan : B.plan) from_day through_day =
  plan.day >= from_day && (through_day = "" || plan.day <= through_day)

let amount session = B.parse_amount session.book session.source.measure (text session "amount")

let eligible session =
  let from_day = text session "from" and through_day = text session "through" in
  List.filter (fun plan -> in_range plan from_day through_day) session.candidates

let validate_parameters session =
  let from_day = text session "from" and through_day = text session "through" in
  if not (valid_date from_day) then Error "Enter a real YYYY-MM-DD start date."
  else if through_day <> "" && not (valid_date through_day) then
    Error "Enter a real YYYY-MM-DD end date, or leave it empty."
  else if through_day <> "" && through_day < from_day then
    Error "End date must not precede start date."
  else
    match amount session with
    | Error message -> Error message
    | Ok amount -> Ok (amount, eligible session)

let selected_plans session eligible =
  let eligible_ids = List.map (fun (plan : B.plan) -> plan.id) eligible in
  if List.length (List.sort_uniq String.compare session.selected)
     <> List.length session.selected
  then Error "A candidate may be selected only once."
  else if List.exists (fun id -> not (List.mem id eligible_ids)) session.selected then
    Error "Selected candidate is outside the reviewed period."
  else if session.selected = [] then Error "Check at least one candidate."
  else
    Ok
      (List.filter
         (fun (plan : B.plan) -> List.mem plan.id session.selected)
         eligible)

let simple_amount (plan : B.plan) =
  match plan.changes with
  | [(a, x); (b, y)] when a <> b && Z.sign x * Z.sign y < 0 ->
      Some (if Z.sign x > 0 then x else y)
  | _ -> None

let build_replacements session =
  match validate_parameters session with
  | Error message -> Error message
  | Ok (amount, eligible) -> (
      match selected_plans session eligible with
      | Error message -> Error message
      | Ok selected ->
          let split =
            List.find_opt
              (fun plan -> simple_amount plan = None)
              selected
          in
          match split with
          | Some plan ->
              Error
                (O.visible plan.id
                ^ ": split postings require individual editing; no allocation was guessed.")
          | None ->
              let replacements =
                List.filter_map
                  (fun (plan : B.plan) ->
                    let current_amount = simple_amount plan in
                    if current_amount = Some amount then None
                    else
                      Some
                        { plan with
                          changes =
                            List.map
                              (fun (locus, value) ->
                                (locus, if Z.sign value < 0 then Z.neg amount else amount))
                              plan.changes })
                  selected
              in
              if replacements = [] then
                Error "Selected amounts are already unchanged. Nothing to publish."
              else Ok replacements)

let preview_rows session plans =
  List.concat_map
    (fun (plan : B.plan) ->
      let original = List.find_opt (fun (item : B.plan) -> item.id = plan.id)
          (B.open_plans session.book)
      in
      let original_changes =
        match original with Some item -> item.changes | None -> []
      in
      [ "ID: " ^ O.visible plan.id;
        "Date: " ^ plan.day ^ "  Measure: " ^ O.visible plan.measure ]
      @ List.concat_map
          (fun (locus, after) ->
            let before = Option.value ~default:Z.zero (List.assoc_opt locus original_changes) in
            [ O.visible locus ^ "  before: " ^ B.format session.book plan.measure before;
              O.visible locus ^ "  after:  " ^ B.format session.book plan.measure after ])
          plan.changes
      @ [ "" ])
    plans

let viewport ~dimensions:(width, height) ~width_of session =
  let candidate_rows =
    if session.preview_plans <> None then [] else eligible session
  in
  let selected_line = ref None in
  let rows =
    match session.preview_plans with
    | Some plans ->
        preview_rows session plans
        |> List.concat_map (O.wrap_text ~width_of (max 1 (width - 6)))
    | None ->
        let offset = ref 0 in
        List.concat
          (List.mapi
             (fun index (plan : B.plan) ->
               let text =
                 (if session.selecting && index = session.focus then "> " else "  ")
                 ^ (if List.mem plan.id session.selected then "[x] " else "[ ] ")
                 ^ O.visible plan.id ^ "  " ^ plan.day ^ "  "
                 ^ (match simple_amount plan with
                    | Some amount -> B.format session.book plan.measure amount
                    | None -> "split: edit individually") ^ "  "
                 ^ O.visible plan.measure ^ "  "
                 ^ String.concat ", "
                     (List.map (fun (locus, _) -> O.visible locus) plan.changes)
               in
               let lines = O.wrap_text ~width_of (max 1 (width - 6)) text in
               if session.selecting && index = session.focus then
                 selected_line := Some !offset;
               offset := !offset + List.length lines;
               lines)
             candidate_rows)
  in
  let view =
    Panel.window
      ~capacity:(Panel.capacity ~height:(max 0 (height - 2)) ~heading:false)
      ~count:(List.length rows) ~scroll:session.scroll
      ~selected:!selected_line
  in
  (rows, view)

let handle ~blocked ~dimensions:((width, height) as dimensions) ~width_of session input =
  let _, view = viewport ~dimensions ~width_of session in
  let session = { session with scroll = view.start } in
  let updated session = Updated session in
  let move amount =
    Updated
      { session with
        scroll = Panel.move ~last:view.last ~position:view.start amount }
  in
  match input with
  | `Key ((`Escape | `ASCII 'q' | `ASCII 'Q'), []) ->
      if session.preview_plans <> None then
        updated { session with preview_plans = None; choice = 0; scroll = 0 }
      else Closed
  | _ when session.preview_plans <> None -> (
      match input with
      | `Key ((`Tab | `Arrow `Right), []) ->
          updated { session with choice = (session.choice + 1) mod 3 }
      | `Key (`Tab, [ `Shift ]) | `Key (`Arrow `Left, []) ->
          updated { session with choice = (session.choice + 2) mod 3 }
      | `Key (`ASCII 'j', []) | `Key (`Arrow `Down, []) -> move 1
      | `Key (`ASCII 'k', []) | `Key (`Arrow `Up, []) -> move (-1)
      | `Key (`Page `Up, []) -> move (-max 1 view.capacity)
      | `Key (`Page `Down, []) -> move (max 1 view.capacity)
      | `Key (`Home, []) -> updated { session with scroll = 0 }
      | `Key (`End, []) -> updated { session with scroll = view.last }
      | `Key (`Enter, []) -> (
          if session.choice = 0 then
            updated { session with preview_plans = None; scroll = 0 }
          else if session.choice = 2 then Closed
          else if blocked then updated { session with notice = "Writes stopped; selection retained." }
          else if width < 46 || height < 14 || view.capacity = 0
                  || (height < 16 && view.last > 0) then
            updated { session with notice = "Enlarge terminal to review the Scheduled effects." }
          else if view.start < view.last then
            updated { session with notice = "Review to the end before publishing." }
          else
            match session.preview_plans with
            | Some plans -> Publish (plans, session.base_bytes)
            | None -> updated session)
      | _ -> updated session)
  | _ when session.selecting ->
      let candidates = eligible session in
      let last = max 0 (List.length candidates - 1) in
      (match input with
      | `Key ((`Escape | `ASCII 'q'), []) -> Closed
      | `Key ((`ASCII 'e' | `ASCII 'E'), []) -> updated { session with selecting = false }
      | `Key (`ASCII 'j', []) | `Key (`Arrow `Down, []) ->
          updated { session with focus = min last (session.focus + 1) }
      | `Key (`ASCII 'k', []) | `Key (`Arrow `Up, []) ->
          updated { session with focus = max 0 (session.focus - 1) }
      | `Key (`Home, []) -> updated { session with focus = 0 }
      | `Key (`End, []) -> updated { session with focus = last }
      | `Key (`ASCII ' ', []) -> (
          match List.nth_opt candidates session.focus with
          | None -> updated session
          | Some plan ->
              let selected =
                if List.mem plan.id session.selected then
                  List.filter (( <> ) plan.id) session.selected
                else plan.id :: session.selected
              in
              updated { session with selected })
      | `Key (`ASCII 'a', []) ->
          updated { session with selected = List.map (fun (p : B.plan) -> p.id) candidates }
      | `Key (`ASCII 'd', []) -> updated { session with selected = [] }
      | `Key (`Enter, []) -> (
          match build_replacements session with
          | Error message -> updated { session with notice = message }
          | Ok plans ->
              updated { session with preview_plans = Some plans; choice = 0; scroll = 0; notice = "" })
      | _ -> updated session)
  | _ ->
      (match input with
      | `Key (`Escape, []) | `Key (`ASCII 'q', []) -> Closed
      | `Key (`Enter, []) -> (
          match validate_parameters session with
          | Error message -> updated { session with notice = message }
          | Ok _ -> updated { session with selecting = true; selected = []; focus = 0; scroll = 0; notice = "" })
      | _ ->
          match Form.handle_input session.form input with
          | Form.Cancel -> Closed
          | Form.Updated form -> updated { session with form; notice = "" }
          | Form.Submit form ->
              let session = { session with form } in
              (match validate_parameters session with
              | Error message -> updated { session with notice = message }
              | Ok _ -> updated { session with selecting = true; selected = []; focus = 0; notice = "" }))

let footer session =
  if session.preview_plans <> None then
    [ "Tab/Left/Right select  Enter confirm  Esc back";
      "j/k PgUp/Dn Home/End review before and after" ]
  else if session.selecting then
    [ "Space toggle  a select all  d clear  Enter preview";
      "j/k/Home/End move  e parameters  Esc/q close" ]
  else
    [ "Enter continue  Tab/Shift-Tab fields  Esc/q close";
      "Amount is exact; dates include both bounds" ]

let screen ~dimensions:((width, height) as dimensions) ~width_of session =
  let width = max 0 width and height = max 0 height in
  if width = 0 || height = 0 then []
  else
    let rows =
      if not session.selecting && session.preview_plans = None then
        Panel.frame_rows ~width_of ~width ~height:(max 0 (height - 1)) ~focused:true
          ~title:(Form.title session.form)
          (Form.render_rows ~width:(max 0 (width - 6))
             ~height:(Panel.capacity ~height:(max 0 (height - 1)) ~heading:false)
             ~width_of session.form)
        @ [ O.Status, O.clip_text ~width_of width session.notice ]
      else
        let content, view = viewport ~dimensions ~width_of session in
        let frame =
          Panel.frame ~width_of ~width ~height:(max 0 (height - 2)) ~focused:true
            ~title:(if session.preview_plans <> None then "Scheduled / Bulk / Preview"
                    else "Scheduled / Bulk / Candidates")
            ~scroll:view.start ~selected:None content
        in
        if session.preview_plans <> None then
          frame
          @ [ O.Status, O.clip_text ~width_of width session.notice;
              O.Active,
              O.clip_text ~width_of width
                (match session.choice with
                | 0 -> "[Back]  Publish all  Cancel"
                | 1 -> "Back  [Publish all]  Cancel"
                | _ -> "Back  Publish all  [Cancel]") ]
        else
          let count = List.length session.selected in
          let a = O.visible (text session "from") in
          let b = O.visible (text session "through") in
          frame
          @ [ O.Status,
              O.clip_text ~width_of width
                (Printf.sprintf "%d selected  Amount: %s  Period: %s–%s  %s"
                   count (text session "amount") a (if b = "" then "…" else b) session.notice) ]
    in
    List.filteri (fun index _ -> index < height) rows
    |> List.map (fun (style, text) -> style, O.pad ~width_of width text)
