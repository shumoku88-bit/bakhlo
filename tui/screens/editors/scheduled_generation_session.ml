(* Scheduled generation: proposes explicit later occurrences without storing recurrence. *)
module B = Bakhlo_household.Daily_book
module O = Ui_render
module Panel = Ui_panel
module Form = Ui_form
module A = Daily_draft
module Fm = Daily_form

type cadence = Monthly | Every_two_months | Every_three_months | Every_six_months | Yearly

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

let cadence_options = [ "Monthly"; "Every 2 months"; "Every 3 months"; "Every 6 months"; "Yearly" ]

let cadence_of_index = function
  | 1 -> Every_two_months
  | 2 -> Every_three_months
  | 3 -> Every_six_months
  | 4 -> Yearly
  | _ -> Monthly

(* A nominal occurrence with no such calendar day stays unresolved: never clamped. *)
type slot = { year : int; month : int; nominal_day : int }
type candidate = Dated of string | Missing of slot
type phase = Horizon | Custom | Resolve

(* Monitored replenishment: cadence is fixed by the source plan. *)
type extend = {
  observed_at : string;
  horizon : int;
  custom : string;
  date_input : string;
  phase : phase;
  limit : string option;
  candidates : candidate list;
  pending : slot list;
  resolutions : (slot * string) list;
}

type kind = General of Form.t | Extend of extend

type t = {
  book : B.t;
  source : B.plan;
  base_revision : string;
  kind : kind;
  generated : B.plan list option;
  through_day : string;
  cadence : cadence;
  choice : int;
  scroll : int;
  notice : string;
}

type outcome = Updated of t | Closed | Publish of B.plan list * string

let valid_date date =
  match A.normalize_date date with
  | Ok canonical -> canonical = date && A.is_valid_canonical_date canonical
  | Error _ -> false

let default_through day = match Day.shift_months day 6 with Ok target -> target | Error _ -> day

(* A monitored cadence preselects the choice; other month counts have no form. *)
let create ?cadence_months ?observed_at ~book ~base_revision ~source () =
  let preset =
    match cadence_months with
    | None -> Some 0
    | Some 1 -> Some 0
    | Some 2 -> Some 1
    | Some 3 -> Some 2
    | Some 6 -> Some 3
    | Some 12 -> Some 4
    | Some _ -> None
  in
  if not (List.exists (( = ) source) (B.open_plans book)) then
    Error "Selected Scheduled plan is not open."
  else
    match preset with
    | None -> Error "This monitoring pattern cannot be extended automatically."
    | Some selected when cadence_months <> None -> (
        match observed_at with
        | None -> Error "An explicit observation date is required to extend a monitored plan."
        | Some observed_at when valid_date observed_at ->
            Ok
              {
                book;
                source;
                base_revision;
                kind =
                  Extend
                    {
                      observed_at;
                      horizon = 0;
                      custom = "";
                      date_input = "";
                      phase = Horizon;
                      limit = None;
                      candidates = [];
                      pending = [];
                      resolutions = [];
                    };
                generated = None;
                through_day = "";
                cadence = cadence_of_index selected;
                choice = 0;
                scroll = 0;
                notice = "";
              }
        | Some _ -> Error "Observation date must be a real Gregorian date (YYYY-MM-DD).")
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
                Form.choice_field ~id:"cadence" ~label:"Cadence" ~options:cadence_options ~selected
                  ();
                Form.action_buttons ~confirm:"Generate Preview" ~cancel:"Cancel" ();
              ]
            ()
        in
        Ok
          {
            book;
            source;
            base_revision;
            kind = General form;
            generated = None;
            through_day = through_val;
            cadence = cadence_of_index selected;
            choice = 0;
            scroll = 0;
            notice = "";
          }

let base_revision t = t.base_revision
let with_publish_error t msg = { t with notice = msg; choice = 0 }
let dimensions (width, height) = (max 0 width, max 0 height)

let horizon_labels =
  [ "Next occurrence"; "Next 3 occurrences"; "Next 6 occurrences"; "Custom date..." ]

let month_index year month = (year * 12) + (month - 1)
let month_start year month = Printf.sprintf "%04d-%02d-01" year month

(* The limit is the first day of the month after the [count]-th cadence slot. *)
let limit_for_count ~cadence_months ~count ~source_day =
  match Day.parts source_day with
  | Error _ -> Error "Source date is not a real Gregorian date."
  | Ok (year, month, _) ->
      let after = month_index year month + (count * cadence_months) + 1 in
      let limit_year = after / 12 and limit_month = (after mod 12) + 1 in
      if limit_year < 1 || limit_year > 9999 then
        Error "Fill limit exceeds the supported calendar range (0001..9999)."
      else Ok (month_start limit_year limit_month)

let horizon_limit ~cadence_months ~source_day = function
  | 1 -> limit_for_count ~cadence_months ~count:3 ~source_day
  | 2 -> limit_for_count ~cadence_months ~count:6 ~source_day
  | _ -> limit_for_count ~cadence_months ~count:1 ~source_day

let extend_limit t e =
  match e.horizon with
  | 3 ->
      if not (valid_date e.custom) then Error "Enter a real Gregorian date (YYYY-MM-DD)."
      else if e.custom <= e.observed_at then
        Error "Fill limit must be strictly after the observation date."
      else if e.custom <= t.source.day then
        Error "Fill limit must be strictly after the source date."
      else Ok e.custom
  | horizon -> (
      match
        horizon_limit ~cadence_months:(cadence_months t.cadence) ~source_day:t.source.day horizon
      with
      | Ok limit when limit <= e.observed_at ->
          Error
            "This source's fill horizon ends at or before the observation date; choose Custom date."
      | result -> result)

(* Occurrences come from the original source anchor; a missing nominal day is
   unresolved, never clamped into an invented date. *)
let extend_candidates ~observed_at ~limit ~cadence_months ~source_day =
  match (Day.parts source_day, Day.parts observed_at, Day.parts limit) with
  | ( Ok (source_year, source_month, nominal_day),
      Ok (observed_year, observed_month, _),
      Ok (limit_year, limit_month, _) ) ->
      let observed_index = month_index observed_year observed_month in
      let limit_index = month_index limit_year limit_month in
      let rec loop k acc =
        let index = month_index source_year source_month + (k * cadence_months) in
        if index > limit_index then List.rev acc
        else
          let year = index / 12 and month = (index mod 12) + 1 in
          if year > 9999 || index < observed_index then loop (k + 1) acc
          else if nominal_day > A.days_in_month ~year ~month then
            if month_start year month < limit then
              loop (k + 1) (Missing { year; month; nominal_day } :: acc)
            else loop (k + 1) acc
          else
            let day = Printf.sprintf "%04d-%02d-%02d" year month nominal_day in
            if day < observed_at || day >= limit then loop (k + 1) acc
            else loop (k + 1) (Dated day :: acc)
      in
      loop 1 []
  | _ -> []

let extend_plans ~new_id ~(source : B.plan) candidates resolutions =
  let rec days acc = function
    | [] -> Ok (List.rev acc)
    | Dated day :: rest -> days (day :: acc) rest
    | Missing slot :: rest -> (
        match List.assoc_opt slot resolutions with
        | Some day -> days (day :: acc) rest
        | None -> Error "Every missing nominal date must be resolved explicitly.")
  in
  match days [] candidates with
  | Error message -> Error message
  | Ok days ->
      Ok
        (List.map
           (fun (day : string) ->
             ({
                id = new_id ();
                day;
                measure = source.measure;
                changes = source.changes;
                paid_by = None;
                cancelled_on = None;
              }
               : B.plan))
           days)

let typed value = function
  | `Key (`ASCII c, []) when Char.code c >= 32 && Char.code c <> 127 ->
      Some (value ^ String.make 1 c)
  | `Key (`Uchar c, []) when O.printable_uchar c -> Some (value ^ O.utf8 c)
  | `Key (`Backspace, []) -> Some (Fm.backspace value)
  | _ -> None

let extend_preview t e limit resolutions plans =
  Updated
    {
      t with
      kind = Extend { e with phase = Horizon; limit = Some limit; pending = []; resolutions };
      generated = Some plans;
      through_day = limit;
      choice = 0;
      scroll = 0;
      notice = "";
    }

let enter_extend ~new_id t e =
  match extend_limit t e with
  | Error message -> Updated { t with notice = message }
  | Ok limit -> (
      let candidates =
        extend_candidates ~observed_at:e.observed_at ~limit
          ~cadence_months:(cadence_months t.cadence) ~source_day:t.source.day
      in
      if candidates = [] then
        Updated { t with notice = "No later occurrence falls before the selected fill limit." }
      else
        let resolutions =
          List.filter (fun (_, day) -> e.observed_at <= day && day < limit) e.resolutions
        in
        let missing =
          List.filter_map
            (function
              | Missing slot when not (List.mem_assoc slot resolutions) -> Some slot | _ -> None)
            candidates
        in
        match missing with
        | [] -> (
            match extend_plans ~new_id ~source:t.source candidates resolutions with
            | Error message -> Updated { t with notice = message }
            | Ok plans -> extend_preview t e limit resolutions plans)
        | pending ->
            Updated
              {
                t with
                kind =
                  Extend
                    {
                      e with
                      phase = Resolve;
                      limit = Some limit;
                      date_input = "";
                      candidates;
                      pending;
                      resolutions;
                    };
                notice = "";
              })

let accept_resolution ~new_id t e text =
  match e.limit with
  | None -> Updated t
  | Some limit -> (
      let message =
        if not (valid_date text) then Some "Enter a real Gregorian date (YYYY-MM-DD)."
        else if text < e.observed_at then
          Some "Resolved date must not precede the observation date."
        else if text >= limit then Some "Resolved date must be before the fill limit."
        else None
      in
      match message with
      | Some message -> Updated { t with notice = message }
      | None -> (
          match e.pending with
          | [] -> Updated t
          | slot :: rest ->
              let resolutions = (slot, text) :: e.resolutions in
              if rest = [] then
                match extend_plans ~new_id ~source:t.source e.candidates resolutions with
                | Error message -> Updated { t with notice = message }
                | Ok plans -> extend_preview t { e with date_input = "" } limit resolutions plans
              else
                Updated
                  {
                    t with
                    kind = Extend { e with pending = rest; date_input = ""; resolutions };
                    notice = "";
                  }))

let handle_extend ~new_id t e input =
  let select horizon = Updated { t with kind = Extend { e with horizon }; notice = "" } in
  match (e.phase, input) with
  | Horizon, `Key ((`Escape | `ASCII 'q' | `ASCII 'Q'), []) -> Closed
  | Horizon, `Key ((`Arrow `Down | `Arrow `Right | `ASCII 'j' | `ASCII 'l' | `Tab), []) ->
      select ((e.horizon + 1) mod 4)
  | Horizon, `Key ((`Arrow `Up | `Arrow `Left | `ASCII 'k' | `ASCII 'h'), [])
  | Horizon, `Key (`Tab, [ `Shift ]) ->
      select ((e.horizon + 3) mod 4)
  | Horizon, `Key (`Enter, []) ->
      if e.horizon = 3 then Updated { t with kind = Extend { e with phase = Custom }; notice = "" }
      else enter_extend ~new_id t e
  | Horizon, _ -> Updated t
  | Custom, `Key (`Escape, []) ->
      Updated { t with kind = Extend { e with phase = Horizon }; notice = "" }
  | Custom, `Key (`Enter, []) -> enter_extend ~new_id t e
  | Custom, input -> (
      match typed e.custom input with
      | Some custom -> Updated { t with kind = Extend { e with custom }; notice = "" }
      | None -> Updated t)
  | Resolve, `Key (`Escape, []) -> Closed
  | Resolve, `Key (`Enter, []) -> accept_resolution ~new_id t e e.date_input
  | Resolve, input -> (
      match typed e.date_input input with
      | Some date_input -> Updated { t with kind = Extend { e with date_input }; notice = "" }
      | None -> Updated t)

let text t field =
  match t.kind with
  | General form -> Option.value ~default:"" (Form.get_text form field)
  | Extend _ -> ""

let selected_cadence t =
  match t.kind with
  | General form -> cadence_of_index (Option.value ~default:0 (Form.get_choice form "cadence"))
  | Extend _ -> t.cadence

let generate_occurrences ~new_id ~source ~cadence ~through_day =
  let step = cadence_months cadence in
  let rec loop k acc =
    match Day.shift_months source.B.day (k * step) with
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
  if not (valid_date through_day) then Error "Enter a real Gregorian date (YYYY-MM-DD)."
  else if through_day <= t.source.day then
    Error "Through date must be strictly later than source date."
  else
    let plans = generate_occurrences ~new_id ~source:t.source ~cadence ~through_day in
    if plans = [] then Error "No occurrences generated before the through date."
    else Ok (through_day, cadence, plans)

let format_plan_changes book (plan : B.plan) =
  let positive =
    List.filter (fun (_, q) -> Z.sign q > 0) plan.changes
    |> List.map (fun (l, q) ->
        Printf.sprintf "+%s %s [%s]" (B.format book plan.measure q) (O.visible plan.measure)
          (O.visible l))
  in
  let negative =
    List.filter (fun (_, q) -> Z.sign q < 0) plan.changes
    |> List.map (fun (l, q) ->
        Printf.sprintf "-%s %s [%s]"
          (B.format book plan.measure (Z.neg q))
          (O.visible plan.measure) (O.visible l))
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
  let rows = match t.generated with Some plans -> preview_rows t plans | None -> [] in
  let wrapped = List.concat_map (O.wrap_text ~width_of (max 1 (width - 6))) rows in
  (wrapped, Panel.preview_window ~height ~count:(List.length wrapped) ~scroll:t.scroll ())

let handle ~new_id ~blocked ~dimensions:((width, height) as dims) ~width_of t input =
  let _, view = viewport ~dimensions:dims ~width_of t in
  let t = { t with scroll = view.start } in
  let updated t = Updated t in
  match (t.generated, t.kind) with
  | None, Extend e -> handle_extend ~new_id t e input
  | Some _, _ -> (
      match input with
      | `Key ((`Escape | `ASCII 'q' | `ASCII 'Q'), []) ->
          updated { t with generated = None; choice = 0; scroll = 0; notice = "" }
      | `Key ((`Tab | `Arrow `Right), []) -> updated { t with choice = (t.choice + 1) mod 2 }
      | `Key (`Tab, [ `Shift ]) | `Key (`Arrow `Left, []) ->
          updated { t with choice = (t.choice + 1) mod 2 }
      | `Key ((`Arrow (`Up | `Down) | `ASCII ('j' | 'k') | `Page _ | `Home | `End), []) ->
          updated { t with scroll = Panel.review_scroll view input }
      | `Key (`Enter, []) -> (
          if t.choice = 0 then Closed
          else if blocked then
            updated { t with notice = "Writes stopped; generated drafts retained." }
          else if width < 46 || height < 14 || view.capacity = 0 || (height < 16 && view.last > 0)
          then updated { t with notice = "Enlarge terminal to review all generated occurrences." }
          else if view.start < view.last then
            updated { t with notice = "Review to the end before publishing." }
          else
            match t.generated with
            | Some plans -> Publish (plans, t.base_revision)
            | None -> updated t)
      | _ -> updated t)
  | None, General form -> (
      let generate t =
        match validate_and_generate ~new_id t with
        | Error message -> updated { t with notice = message }
        | Ok (through_day, cadence, plans) ->
            updated
              {
                t with
                generated = Some plans;
                through_day;
                cadence;
                choice = 0;
                scroll = 0;
                notice = "";
              }
      in
      match input with
      | `Key ((`Escape | `ASCII 'q' | `ASCII 'Q'), []) -> Closed
      | `Key (`Enter, []) -> generate t
      | _ -> (
          match Form.handle_input form input with
          | Form.Cancel -> Closed
          | Form.Updated form -> updated { t with kind = General form; notice = "" }
          | Form.Submit form -> generate { t with kind = General form }))

let footer t =
  match (t.generated, t.kind) with
  | Some _, Extend _ -> [ "Tab choose  Enter confirm"; "PgUp/Dn/End review  Esc edit" ]
  | Some _, _ ->
      [
        "Tab/Left/Right select  Enter confirm  Esc cancel";
        "j/k PgUp/Dn Home/End review all occurrences";
      ]
  | None, Extend { phase = Horizon; _ } ->
      [ "j/k/Tab choose  Enter accept"; "Esc/q cancel  limit exclusive" ]
  | None, Extend { phase = Custom; _ } ->
      [ "Enter accept  Esc back"; "YYYY-MM-DD; limit exclusive" ]
  | None, Extend { phase = Resolve; _ } ->
      [ "Enter accept  Esc cancel"; "Explicit date; no auto-clamping" ]
  | None, General _ ->
      [
        "Enter preview  Tab switch field  Esc cancel";
        "Generates explicit occurrences; no recurring rule is kept";
      ]

let extend_rows ~width ~width_of t e =
  let room = max 1 (width - 6) in
  let plain lines =
    List.map
      (fun text -> (O.Plain, text))
      (List.concat_map (fun line -> O.wrap_text ~width_of room line) lines)
  in
  let info =
    plain
      [
        "Source: " ^ O.visible t.source.id ^ " (" ^ t.source.day ^ ")";
        "Known through: " ^ e.observed_at;
        "Pattern: " ^ cadence_label t.cadence;
      ]
  in
  let field_line prompt value =
    let prompt = O.clip_text ~width_of (max 0 (room - 1)) prompt in
    let inset = width_of prompt in
    let text, caret =
      O.input_text ~width_of ~width:(max 0 (room - inset)) ~cursor:None ~caret:"|" value
    in
    (Option.fold ~none:O.Active ~some:(fun column -> O.Input (inset + column)) caret, prompt ^ text)
  in
  match e.phase with
  | Horizon ->
      let row index =
        let selected = index = e.horizon in
        let text = (if selected then "> " else "  ") ^ List.nth horizon_labels index in
        ((if selected then O.Active else O.Plain), O.clip_text ~width_of room text)
      in
      (info @ List.map row [ 0; 1; 2; 3 ], Some (List.length info + e.horizon))
  | Custom ->
      ( info @ [ (O.Plain, ""); field_line "Custom fill limit: " e.custom ],
        Some (List.length info + 1) )
  | Resolve -> (
      match e.pending with
      | [] -> (info, None)
      | slot :: _ ->
          let nominal =
            plain
              [
                Printf.sprintf "Nominal day %d does not exist in %04d-%02d." slot.nominal_day
                  slot.year slot.month;
              ]
          in
          let rows =
            nominal
            @ [ field_line "Explicit date: " e.date_input ]
            @ [ (O.Status, Printf.sprintf "Unresolved missing dates: %d" (List.length e.pending)) ]
            @ plain [ "Enter the explicit real date you intend; nothing is chosen for you." ]
          in
          (rows, Some (List.length nominal)))

(* Small terminals window the rows so the active choice or date input stays visible. *)
let window_rows ~height rows active =
  let capacity = Panel.capacity ~height ~heading:false in
  let view = Panel.window ~capacity ~count:(List.length rows) ~scroll:0 ~selected:active in
  List.filteri (fun index _ -> index >= view.start && index - view.start < view.capacity) rows

let screen ~dimensions:((width, height) as dims) ~width_of t =
  let width = max 0 width and height = max 0 height in
  if width = 0 || height = 0 then []
  else
    let rows =
      match (t.generated, t.kind) with
      | None, Extend e ->
          let rows, active = extend_rows ~width ~width_of t e in
          let rows = window_rows ~height:(max 0 (height - 1)) rows active in
          Panel.frame_rows ~width_of ~width
            ~height:(max 0 (height - 1))
            ~focused:true ~title:"Scheduled / Extend Plan" rows
          @ [ (O.Status, O.clip_text ~width_of width t.notice) ]
      | None, General form -> Form.render_panel ~status:t.notice ~width_of ~width ~height form
      | Some _, _ ->
          let content, view = viewport ~dimensions:dims ~width_of t in
          let title =
            match t.kind with
            | Extend _ -> "Scheduled / Extend / Preview"
            | General _ -> "Scheduled / Generate / Preview"
          in
          let action_text =
            if t.choice = 0 then " [Cancel]  Publish all" else " Cancel  [Publish all]"
          in
          Panel.preview ~width_of ~width ~height ~title ~scroll:view.start ~notice:t.notice
            ~action:action_text content
    in
    List.filteri (fun index _ -> index < height) rows
    |> List.map (fun (style, text) -> (style, O.pad ~width_of width text))

let source t = t.source
let selected_months t = cadence_months (selected_cadence t)
