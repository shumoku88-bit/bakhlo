(* Scheduled generation: proposes explicit later occurrences without storing recurrence. *)
module B = Bakhlo_sexp.Daily_book
module O = Daily_overlays
module Panel = Ui_panel
module Form = Ui_form
module Cal = Daily_calendar
module A = Daily_draft

type cadence =
  | Monthly
  | Every_two_months
  | Every_three_months
  | Every_six_months
  | Yearly

let cadence_months = function
  | Monthly -> 1
  | Every_two_months -> 2
  | Every_three_months -> 3
  | Every_six_months -> 6
  | Yearly -> 12

let cadence_label = function
  | Monthly -> "Monthly"
  | Every_two_months -> "Every 2 months"
  | Every_three_months -> "Every 3 months"
  | Every_six_months -> "Every 6 months"
  | Yearly -> "Yearly"

let cadence_options =
  [ "Monthly"; "Every 2 months"; "Every 3 months"; "Every 6 months"; "Yearly" ]

let cadence_of_index = function
  | 1 -> Every_two_months
  | 2 -> Every_three_months
  | 3 -> Every_six_months
  | 4 -> Yearly
  | _ -> Monthly

type t = {
  book : B.t;
  source : B.plan;
  base_revision : string;
  form : Form.t;
  generated : B.plan list option;
  through_day : string;
  cadence : cadence;
  choice : int;
  scroll : int;
  notice : string;
}

type outcome =
  | Updated of t
  | Closed
  | Publish of B.plan list * string

let valid_date date =
  match A.normalize_date date with
  | Ok canonical -> canonical = date && A.is_valid_canonical_date canonical
  | Error _ -> false

let default_through day =
  match Cal.shift_months day 6 with
  | Ok target -> target
  | Error _ -> day

(* A monitored cadence preselects the choice; other month counts have no form. *)
let create ?cadence_months ~book ~base_revision ~source () =
  let preset = match cadence_months with
    | None -> Some 0
    | Some 1 -> Some 0 | Some 2 -> Some 1 | Some 3 -> Some 2 | Some 6 -> Some 3 | Some 12 -> Some 4
    | Some _ -> None in
  if not (List.exists (( = ) source) (B.open_plans book)) then
    Error "Selected Scheduled plan is not open."
  else match preset with
  | None -> Error "This monitoring pattern cannot be extended automatically."
  | Some selected ->
    let through_val = default_through source.day in
    let form =
      Form.create ~id:"scheduled_generate" ~title:"Scheduled / Generate Plans"
        ~summary:
          [
            "Source: " ^ O.visible source.id ^ " (" ^ source.day ^ ")";
            "Proposes explicit dates; no recurrence rule is persisted.";
          ]
        ~fields:
          [
            Form.text_field ~id:"through" ~label:"Through (exclusive)" ~value:through_val ();
            Form.choice_field ~id:"cadence" ~label:"Cadence" ~options:cadence_options ~selected ();
            Form.action_buttons ~confirm:"Generate Preview" ~cancel:"Cancel" ();
          ]
        ()
    in
    Ok
      {
        book;
        source;
        base_revision;
        form;
        generated = None;
        through_day = through_val;
        cadence = cadence_of_index selected;
        choice = 0;
        scroll = 0;
        notice = "";
      }

let base_revision t = t.base_revision

let with_publish_error t msg = { t with notice = msg; choice = 0 }

let dimensions (width, height) = max 0 width, max 0 height

let text t field = Option.value ~default:"" (Form.get_text t.form field)

let selected_cadence t =
  cadence_of_index (Option.value ~default:0 (Form.get_choice t.form "cadence"))

let generate_occurrences ~new_id ~source ~cadence ~through_day =
  let step = cadence_months cadence in
  let rec loop k acc =
    match Cal.shift_months source.B.day (k * step) with
    | Error _ -> List.rev acc
    | Ok target_date ->
        if target_date >= through_day then List.rev acc
        else
          let plan : B.plan =
            {
              id = new_id ();
              day = target_date;
              measure = source.measure;
              changes = source.changes;
              paid_by = None;
              cancelled_on = None;
            }
          in
          loop (k + 1) (plan :: acc)
  in
  loop 1 []

let validate_and_generate ~new_id t =
  let through_day = text t "through" in
  let cadence = selected_cadence t in
  if not (valid_date through_day) then
    Error "Enter a real Gregorian date (YYYY-MM-DD)."
  else if through_day <= t.source.day then
    Error "Through date must be strictly later than source date."
  else
    let plans = generate_occurrences ~new_id ~source:t.source ~cadence ~through_day in
    if plans = [] then
      Error "No occurrences generated before the through date."
    else
      Ok (through_day, cadence, plans)

let format_plan_changes book (plan : B.plan) =
  let positive =
    List.filter (fun (_, q) -> Z.sign q > 0) plan.changes
    |> List.map (fun (l, q) -> Printf.sprintf "+%s %s [%s]" (B.format book plan.measure q) (O.visible plan.measure) (O.visible l))
  in
  let negative =
    List.filter (fun (_, q) -> Z.sign q < 0) plan.changes
    |> List.map (fun (l, q) -> Printf.sprintf "-%s %s [%s]" (B.format book plan.measure (Z.neg q)) (O.visible plan.measure) (O.visible l))
  in
  String.concat ", " (negative @ positive)

let preview_rows t plans =
  [
    "Explicit Scheduled drafts: " ^ string_of_int (List.length plans);
    "Through: " ^ t.through_day ^ "  Cadence: " ^ cadence_label t.cadence;
    "Only reviewed explicit dates will be created; no recurrence is stored.";
    "";
  ]
  @ List.mapi
      (fun i (p : B.plan) ->
        Printf.sprintf " %2d. %s  %s" (i + 1) p.day (format_plan_changes t.book p))
      plans

let viewport ~dimensions:(width, height) ~width_of t =
  let rows =
    match t.generated with
    | Some plans -> preview_rows t plans
    | None -> []
  in
  let wrapped = List.concat_map (O.wrap_text ~width_of (max 1 (width - 6))) rows in
  let view =
    Panel.window
      ~capacity:(Panel.capacity ~height:(max 0 (height - 2)) ~heading:false)
      ~count:(List.length wrapped)
      ~scroll:t.scroll
      ~selected:None
  in
  (wrapped, view)

let handle ~new_id ~blocked ~dimensions:((width, height) as dims) ~width_of t input =
  let _, view = viewport ~dimensions:dims ~width_of t in
  let t = { t with scroll = view.start } in
  let updated t = Updated t in
  let move n = Updated { t with scroll = Panel.move ~last:view.last ~position:view.start n } in
  match input with
  | `Key ((`Escape | `ASCII 'q' | `ASCII 'Q'), []) ->
      if t.generated <> None then
        updated { t with generated = None; choice = 0; scroll = 0; notice = "" }
      else Closed
  | _ when t.generated <> None -> (
      match input with
      | `Key ((`Tab | `Arrow `Right), []) ->
          updated { t with choice = (t.choice + 1) mod 2 }
      | `Key (`Tab, [ `Shift ]) | `Key (`Arrow `Left, []) ->
          updated { t with choice = (t.choice + 1) mod 2 }
      | `Key (`ASCII 'j', []) | `Key (`Arrow `Down, []) -> move 1
      | `Key (`ASCII 'k', []) | `Key (`Arrow `Up, []) -> move (-1)
      | `Key (`Page `Up, []) -> move (-max 1 view.capacity)
      | `Key (`Page `Down, []) -> move (max 1 view.capacity)
      | `Key (`Home, []) -> updated { t with scroll = 0 }
      | `Key (`End, []) -> updated { t with scroll = view.last }
      | `Key (`Enter, []) ->
          if t.choice = 0 then
            Closed
          else if blocked then
            updated { t with notice = "Writes stopped; generated drafts retained." }
          else if width < 46 || height < 14 || view.capacity = 0 || (height < 16 && view.last > 0) then
            updated { t with notice = "Enlarge terminal to review all generated occurrences." }
          else if view.start < view.last then
            updated { t with notice = "Review to the end before publishing." }
          else
            (match t.generated with
            | Some plans -> Publish (plans, t.base_revision)
            | None -> updated t)
      | _ -> updated t)
  | _ -> (
      match input with
      | `Key (`Escape, []) -> Closed
      | `Key (`Enter, []) -> (
          match validate_and_generate ~new_id t with
          | Error message -> updated { t with notice = message }
          | Ok (through_day, cadence, plans) ->
              updated { t with generated = Some plans; through_day; cadence; choice = 0; scroll = 0; notice = "" })
      | _ -> (
          match Form.handle_input t.form input with
          | Form.Cancel -> Closed
          | Form.Updated form -> updated { t with form; notice = "" }
          | Form.Submit form -> (
              let t = { t with form } in
              match validate_and_generate ~new_id t with
              | Error message -> updated { t with notice = message }
              | Ok (through_day, cadence, plans) ->
                  updated { t with generated = Some plans; through_day; cadence; choice = 0; scroll = 0; notice = "" })))

let footer t =
  if t.generated <> None then
    [
      "Tab/Left/Right select  Enter confirm  Esc cancel";
      "j/k PgUp/Dn Home/End review all occurrences";
    ]
  else
    [
      "Enter preview  Tab switch field  Esc cancel";
      "Generates explicit occurrences; no recurring rule is kept";
    ]

let screen ~dimensions:((width, height) as dims) ~width_of t =
  let width = max 0 width and height = max 0 height in
  if width = 0 || height = 0 then []
  else
    let rows =
      if t.generated = None then
        Panel.frame_rows ~width_of ~width ~height:(max 0 (height - 1)) ~focused:true
          ~title:(Form.title t.form)
          (Form.render_rows ~width:(max 0 (width - 6))
             ~height:(Panel.capacity ~height:(max 0 (height - 1)) ~heading:false)
             ~width_of t.form)
        @ [ O.Status, O.clip_text ~width_of width t.notice ]
      else
        let content, view = viewport ~dimensions:dims ~width_of t in
        let frame =
          Panel.frame ~width_of ~width ~height:(max 0 (height - 2)) ~focused:true
            ~title:"Scheduled / Generate / Preview" ~scroll:view.start ~selected:None content
        in
        let action_text =
          if t.choice = 0 then " [Cancel]  Publish all"
          else " Cancel  [Publish all]"
        in
        frame
        @ [
            O.Status, O.clip_text ~width_of width t.notice;
            O.Active, O.clip_text ~width_of width action_text;
          ]
    in
    List.filteri (fun index _ -> index < height) rows
    |> List.map (fun (style, text) -> style, O.pad ~width_of width text)

let source t = t.source
let selected_months t = cadence_months (selected_cadence t)
