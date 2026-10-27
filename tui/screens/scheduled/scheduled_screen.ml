(* Scheduled: LOAM's Series Calendar over scheduled-coverage.tsv (with one
   monitored plan's occurrences and gaps), a six-month Months view and a
   filtered List with a detail pane. Completion, editing, cancellation, batch amounts and
   generation of the selected plan are record actions handled by the Shell. *)
module B = Bakhlo_sexp.Daily_book
module O = Daily_overlays
module RB = Record_browser
module Months = Scheduled_months
module Panel = Ui_panel
module Cov = Scheduled_coverage

let tr = Ui_text.tr

type view = Coverage_view | Plan_view | Months_view | List_view
type pane = List_pane | Loci_pane | Detail_pane

(* How the Expected pace chooser was opened. [Created] is the post-publication
   follow-up of a new Scheduled plan; it offers the published one-off as the
   default and never generates a future occurrence. *)
type pace_mode = Paced | Extending | Created

type t = {
  view : view;
  list : RB.t;
  months_list : RB.t;
  months : Months.t;
  focus_day : string; (* captured through enter: the day scope's exact date *)
  pane : pane;
  origin : pane; (* the pane that opened the detail *)
  scroll : int;
  search : string option; (* the search input while it is open *)
  coverage_row : int;
  coverage_offset : int; (* first visible coverage month *)
  plan_row : int;
  pace : (B.plan * int) option; (* the Expected pace chooser: source plan, choice *)
  pending : (B.plan * string * int option) option;
  (* monitoring save in flight: source, success notice, cadence to extend with *)
  pace_mode : pace_mode;
      (* why the chooser is open: an existing plan, an extend, or a just-created one *)
}

let coverage_file = "scheduled-coverage.tsv"
let config_files = [ coverage_file ]
let coverage_months = 18

let create months =
  {
    view = Coverage_view;
    list = { RB.empty with order = RB.Oldest };
    months_list = { RB.empty with order = RB.Oldest };
    months;
    focus_day = "";
    pane = List_pane;
    origin = List_pane;
    scroll = 0;
    search = None;
    coverage_row = 0;
    coverage_offset = 0;
    plan_row = 0;
    pace = None;
    pending = None;
    pace_mode = Paced;
  }

(* Monitoring rules are read-side configuration; a missing file is no rule, a
   malformed or unreadable one is an explicit error, never an empty overview. *)
let coverage (env : Screen.env) =
  match env.config coverage_file with
  | Error why -> Error why
  | Ok None -> Ok ([], [])
  | Ok (Some text) ->
      Result.bind (Cov.of_string text) (fun rules ->
          Cov.project rules ~plans:(B.plans env.book) ~today:env.today ~months:coverage_months)

(* Without any configured rule the overview has nothing to show, so the List
   (with Months) stays the entrance, as before monitoring existed. *)
let monitored env = match coverage env with Ok (_, []) -> false | Ok _ | Error _ -> true

let current env t =
  match t.view with (Coverage_view | Plan_view) when not (monitored env) -> List_view | v -> v

let modal t = Option.is_some t.search || Option.is_some t.pace
let months_view t = t.view = Months_view
let detail_focused t = t.pane = Detail_pane
let scroll t = t.scroll
let months t = t.months
let list_browser t = t.list
let reloaded _env t = ({ t with scroll = 0 }, Screen.Stay)

let browser t =
  match t.view with Coverage_view | Plan_view | List_view -> t.list | Months_view -> t.months_list

let with_browser t b =
  match t.view with
  | Coverage_view | Plan_view | List_view -> { t with list = b }
  | Months_view -> { t with months_list = b }

let rows book t =
  let plans = List.map (fun p -> RB.Scheduled_plan p) (B.open_plans book) in
  match t.view with
  | Months_view -> RB.sorted RB.Oldest plans
  | Coverage_view | Plan_view | List_view -> RB.visible ~book t.list plans

(* The selection always follows the remembered plan identity in the current book. *)
let synced book t = with_browser t (RB.sync (browser t) (rows book t))

let selected_plan book t =
  let t = synced book t in
  match RB.selected_row (browser t) (rows book t) with
  | Some (RB.Scheduled_plan p) -> Some p
  | _ -> None

(* The List's Loci pane derives its rows from the same scope the browser filters
   on: all current-open plans, or the captured focus day. *)
let scope_plans book t =
  match t.list.day with
  | None -> B.open_plans book
  | Some day -> List.filter (fun (p : B.plan) -> p.day = day) (B.open_plans book)

let loci book t =
  List.sort_uniq String.compare
    (List.concat_map (fun (p : B.plan) -> List.map fst p.changes) (scope_plans book t))

(* Row 0 is [All loci]; the filter lives in the browser, so the pane and the
   List can never disagree. *)
let locus_row book t =
  match t.list.locus with
  | None -> 0
  | Some id ->
      let rec find i = function
        | [] -> 0
        | locus :: rest -> if locus = id then i + 1 else find (i + 1) rest
      in
      find 0 (loci book t)

let set_locus book t row =
  let names = loci book t in
  let row = max 0 (min (List.length names) row) in
  let locus = if row = 0 then None else List.nth_opt names (row - 1) in
  if t.list.locus = locus then synced book t
  else synced book (with_browser { t with scroll = 0 } (RB.with_locus (browser t) locus))

let book_changed ~before:_ ~after t =
  (* A locus that left the new scope would filter everything out silently. *)
  let t =
    match t.list.locus with
    | Some id when not (List.mem id (loci after t)) -> { t with list = RB.with_locus t.list None }
    | _ -> t
  in
  (synced after { t with scroll = 0 }, "")

let follow_months book t =
  match (t.view, selected_plan book t) with
  | Months_view, Some plan -> { t with months = Months.follow t.months plan.B.day }
  | _ -> t

let detail_rows ~width_of ~width book t =
  let lines =
    match selected_plan book t with
    | Some plan -> O.plan_lines book plan
    | None -> [ tr "No selected record." ]
  in
  List.concat_map (O.wrap_text ~width_of (max 1 (width - 6))) lines

let detail_window (env : Screen.env) (geometry : Screen.geometry) t =
  let width, height = geometry.content in
  (* The full-detail pane is the whole body in both Months and List. *)
  let count = List.length (detail_rows ~width_of:geometry.width_of ~width env.book t) in
  ( height,
    Panel.window
      ~capacity:(Panel.capacity ~height ~heading:false)
      ~count ~scroll:t.scroll ~selected:None )

let with_query book t query = synced book (with_browser t (RB.with_query (browser t) query))

(* LOAM order: overview -> Months -> List -> overview; a plan returns to its overview. *)
let toggle_view env book t =
  let t = { t with view = current env t } in
  let selected_id =
    Option.map RB.identity (RB.selected_row (browser (synced book t)) (rows book t))
  in
  let view =
    match t.view with
    | Coverage_view -> Months_view
    | Plan_view -> Coverage_view
    | Months_view -> List_view
    | List_view -> if monitored env then Coverage_view else Months_view
  in
  let destination = { t with view; pane = List_pane; origin = List_pane; scroll = 0 } in
  let destination =
    match selected_id with
    | Some id when List.exists (fun row -> RB.identity row = id) (rows book destination) ->
        with_browser destination { (browser destination) with selected_id }
    | _ -> destination
  in
  follow_months book (synced book destination)

let action book t action =
  ( t,
    Screen.Record_action
      { action; target = Option.map (fun p -> Screen.Plan p) (selected_plan book t) } )

let unless_blocked (env : Screen.env) message =
  if env.blocked then Screen.Stay else Screen.Message message

let input_text value = function
  | `Key (`ASCII c, []) when Char.code c >= 32 && Char.code c <> 127 ->
      Some (value ^ String.make 1 c)
  | `Key (`Uchar c, []) when O.printable_uchar c -> Some (value ^ O.utf8 c)
  | `Key (`Backspace, []) -> Some (Daily_form.backspace value)
  | _ -> None

(* --- Series Calendar (LOAM ScheduledCoveragePane) and one plan's entries --- *)

type plan_entry =
  | Occurrence of B.plan * bool
  (* on pace *)
  | Missing_month of string

let coverage_rows env = match coverage env with Ok (_, rows) -> rows | Error _ -> []
let clamp_index count i = if count = 0 then 0 else max 0 (min (count - 1) i)

let selected_rule env t =
  let rows = coverage_rows env in
  List.nth_opt rows (clamp_index (List.length rows) t.coverage_row)

let plan_entries (env : Screen.env) (row : Cov.row) =
  let explicit =
    List.map
      (fun (p : B.plan) -> (p.day, Occurrence (p, Cov.expected_on row.rule p.day)))
      (Cov.plans_for row.rule (B.plans env.book))
  in
  let gaps =
    List.filter_map
      (fun (c : Cov.cell) ->
        if Cov.missing c then Some (c.month ^ "-00", Missing_month c.month) else None)
      row.cells
  in
  List.map snd (List.stable_sort (fun (a, _) (b, _) -> String.compare a b) (explicit @ gaps))

let selected_entry env t =
  Option.bind (selected_rule env t) (fun row ->
      let entries = plan_entries env row in
      List.nth_opt entries (clamp_index (List.length entries) t.plan_row))

(* LOAM extends from the latest current-open occurrence of the monitored shape. *)
let latest_plan env t =
  Option.bind (selected_rule env t) (fun row ->
      List.fold_left (fun _ p -> Some p) None (Cov.plans_for row.rule (B.plans env.book)))

(* LOAM replenishment source: before the first gap, the latest open occurrence
   on the monitored cadence; with no gap, the latest open occurrence. *)
let replenishment_source env t =
  Option.bind (selected_rule env t) (fun (row : Cov.row) ->
      let plans = Cov.plans_for row.rule (B.plans env.book) in
      let candidates =
        match row.first_missing with
        | None -> plans
        | Some month ->
            List.filter
              (fun (p : B.plan) -> p.day < month ^ "-01" && Cov.expected_on row.rule p.day)
              plans
      in
      Option.map (fun p -> (row.rule, p)) (List.fold_left (fun _ p -> Some p) None candidates))

let replenish env t =
  match replenishment_source env t with
  | None ->
      ( t,
        unless_blocked env
          "No explicit Scheduled occurrence on the monitored pace is available before the first \
           gap." )
  | Some (rule, _) when not (List.mem rule.Cov.every_months [ 1; 2; 3; 6; 12 ]) ->
      (t, unless_blocked env "This monitoring pattern cannot be extended automatically.")
  | Some (rule, p) ->
      ( t,
        Screen.Record_action
          { action = Screen.Generate_every rule.every_months; target = Some (Screen.Plan p) } )

(* LOAM groups the whole part by three digits; the exact fraction is kept. *)
let grouped amount =
  match String.split_on_char '.' amount with
  | [] -> amount
  | whole :: rest ->
      let b = Buffer.create (String.length amount + 8) in
      String.iteri
        (fun i c ->
          if i > 0 && (String.length whole - i) mod 3 = 0 then Buffer.add_char b ',';
          Buffer.add_char b c)
        whole;
      String.concat "." (Buffer.contents b :: rest)

(* --- Monitoring edits (LOAM p / s): only scheduled-coverage.tsv changes --- *)

let pace_choices =
  [
    ("Monthly", 1);
    ("Every 2 months", 2);
    ("Every 3 months", 3);
    ("Every 6 months", 6);
    ("Yearly", 12);
  ]

(* LOAM createdPaceLabels: keep the just-published occurrence, the five
   cadences, then an explicit undecided. Selection 0 and Esc both leave
   monitoring unchanged; the occurrence is already published either way. *)
let created_pace_labels =
  [ "This occurrence only (leave monitoring unchanged)" ]
  @ List.map fst pace_choices @ [ "Future pace undecided" ]

(* LOAM runAfterCreation: the Scheduled occurrence is already published, so only
   its expected pace is offered. An unusable signed-Locus shape refuses before a
   chooser that could not save anything is shown. *)
let open_created_pace (env : Screen.env) t plan =
  match Cov.rule_for plan ~months:1 with
  | Error _ ->
      (t, unless_blocked env "The new Scheduled occurrence has no usable signed-Locus shape.")
  | Ok _ -> ({ t with pace = Some (plan, 0); pace_mode = Created }, Screen.Stay)

(* LOAM selectedActionRecord: a Plan Detail occurrence, else the plan's latest. *)
let action_record env t =
  match (t.view, selected_entry env t) with
  | Plan_view, Some (Occurrence (p, _)) -> Some p
  | (Months_view | List_view), _ -> selected_plan env.book t
  | _ -> latest_plan env t

(* Whole-image replacement against the captured bytes; the Shell refuses a
   changed file. The new image must decode again before it is offered. *)
let save_rule ?extend (env : Screen.env) t (source : B.plan) rule success =
  match env.config coverage_file with
  | Error why -> (t, unless_blocked env why)
  | Ok expected -> (
      let current = match expected with None -> Ok [] | Some text -> Cov.of_string text in
      match Result.bind current (fun rules -> Cov.upsert rules rule) with
      | Error why -> (t, unless_blocked env why)
      | Ok rules -> (
          let content = Cov.to_string rules in
          match Cov.of_string content with
          | Error why -> (t, unless_blocked env why)
          | Ok _ ->
              let name =
                match
                  List.find_opt
                    (fun (r : Cov.rule) ->
                      r.negative = rule.Cov.negative && r.positive = rule.positive)
                    rules
                with
                | Some r -> r.name
                | None -> rule.name
              in
              ( { t with pending = Some (source, success name, extend) },
                Screen.Save_config
                  { file = coverage_file; expected; content; admission = Screen.Household_readable }
              )))

let change_pace env t =
  match action_record env t with
  | None ->
      ( t,
        unless_blocked env
          "No current-open Scheduled occurrence is available for the selected recurring plan." )
  | Some p -> ({ t with pace = Some (p, 0); pace_mode = Paced }, Screen.Stay)

(* LOAM extendPlan from List / Months: a monitored plan extends on its cadence;
   an unmonitored one first chooses its expected pace, then extends. *)
let extend_selected (env : Screen.env) t =
  match selected_plan env.book t with
  | None -> (t, unless_blocked env "No Scheduled plan is selected to extend.")
  | Some p -> (
      match List.find_opt (fun (row : Cov.row) -> Cov.matches row.rule p) (coverage_rows env) with
      | Some row when List.mem row.rule.every_months [ 1; 2; 3; 6; 12 ] ->
          ( t,
            Screen.Record_action
              {
                action = Screen.Generate_every row.rule.every_months;
                target = Some (Screen.Plan p);
              } )
      | Some _ -> (t, unless_blocked env "This monitoring pattern cannot be extended automatically.")
      | None -> ({ t with pace = Some (p, 0); pace_mode = Extending }, Screen.Stay))

let stop_monitoring env t =
  match action_record env t with
  | None -> (t, unless_blocked env "No recurring plan is selected.")
  | Some p -> (
      let monitored =
        List.find_opt (fun (row : Cov.row) -> Cov.matches row.rule p) (coverage_rows env)
      in
      let rule =
        match monitored with
        | Some row -> Ok { row.rule with every_months = 0 }
        | None -> Result.map (fun r -> { r with Cov.every_months = 0 }) (Cov.rule_for p ~months:1)
      in
      match rule with
      | Error why -> (t, unless_blocked env why)
      | Ok rule ->
          save_rule env t p rule (fun _ ->
              "Future pace is undecided for this plan. Existing Scheduled occurrences were not \
               changed."))

let handle_pace env t (source, choice) key =
  let stay t = (t, Screen.Stay) in
  let close notice = ({ t with pace = None; pace_mode = Paced }, Screen.Message notice) in
  match t.pace_mode with
  | Created -> (
      let count = List.length created_pace_labels in
      let move delta = stay { t with pace = Some (source, (choice + delta + count) mod count) } in
      (* LOAM updateCreatedPace: keep the published occurrence, choose a cadence
         or record an explicit undecided. No future Scheduled is ever created. *)
      match key with
      | Some ((`Escape | `ASCII ('q' | 'Q')), []) ->
          close "Expected pace unchanged; no future Scheduled created."
      | Some ((`ASCII 'k' | `Arrow `Up), []) | Some (`Tab, [ `Shift ]) -> move (-1)
      | Some ((`ASCII 'j' | `Arrow `Down | `Tab), []) -> move 1
      | Some (`Enter, []) -> (
          match choice with
          | 0 -> close "Expected pace unchanged; no future Scheduled created."
          | n when n = List.length pace_choices + 1 -> (
              (* LOAM undecided: the cadence template with everyMonths 0. *)
              match Cov.rule_for source ~months:1 with
              | Error why -> (t, unless_blocked env why)
              | Ok template ->
                  save_rule env t source { template with Cov.every_months = 0 } (fun _ ->
                      "Expected pace: undecided. No future Scheduled created; use e to extend \
                       explicitly."))
          | n -> (
              match List.nth_opt pace_choices (n - 1) with
              | None -> (t, unless_blocked env "Invalid pace selection.")
              | Some (label, months) -> (
                  match Cov.rule_for source ~months with
                  | Error why -> (t, unless_blocked env why)
                  | Ok rule ->
                      save_rule env t source rule (fun _ ->
                          "Expected pace: " ^ label ^ " from " ^ rule.anchor
                          ^ ". No future Scheduled created; use e to extend explicitly."))))
      | _ -> stay t)
  | Extending | Paced -> (
      let count = List.length pace_choices in
      match key with
      | Some ((`Escape | `ASCII 'q'), []) ->
          close
            (if t.pace_mode = Extending then "Extend cancelled; no recurring pattern was selected."
             else "Plan monitoring unchanged.")
      | Some ((`ASCII 'k' | `Arrow `Up), []) | Some (`Tab, [ `Shift ]) ->
          stay { t with pace = Some (source, (choice + count - 1) mod count) }
      | Some ((`ASCII 'j' | `Arrow `Down | `Tab), []) ->
          stay { t with pace = Some (source, (choice + 1) mod count) }
      | Some (`Enter, []) -> (
          let label, months = List.nth pace_choices choice in
          match Cov.rule_for source ~months with
          | Error why -> (t, unless_blocked env why)
          | Ok rule ->
              save_rule
                ?extend:(if t.pace_mode = Extending then Some months else None)
                env t source rule
                (fun name ->
                  "Monitoring " ^ name ^ ": " ^ label ^ " from " ^ rule.anchor
                  ^ ". No Scheduled occurrence was created."))
      | _ -> stay t)

(* After a monitoring save the overview follows the source plan's row, which
   may move when its cadence changes the order. *)
let saved env _geometry result t =
  match (result, t.pending) with
  | Ok (), Some (source, notice, extend) -> (
      let rows = coverage_rows env in
      let rec find i = function
        | [] -> t.coverage_row
        | (row : Cov.row) :: rest -> if Cov.matches row.rule source then i else find (i + 1) rest
      in
      let t =
        { t with pace = None; pending = None; pace_mode = Paced; coverage_row = find 0 rows }
      in
      match extend with
      | None -> (t, Screen.Message notice)
      | Some months ->
          ( t,
            Screen.Record_action
              { action = Screen.Generate_every months; target = Some (Screen.Plan source) } ))
  | Ok (), None -> (t, Screen.Stay)
  | Error why, _ -> ({ t with pending = None }, Screen.Message why)

let pace_paint (env : Screen.env) (geometry : Screen.geometry) t ((source : B.plan), choice) =
  let width_of = geometry.width_of and width, height = geometry.content in
  let book = env.book in
  let created = t.pace_mode = Created in
  let labels = if created then created_pace_labels else List.map fst pace_choices in
  let choice = clamp_index (List.length labels) choice in
  (* LOAM ScheduledReview.summary wording; the amount is Measure-scaled. *)
  let changes =
    match
      ( List.filter (fun (_, q) -> Z.sign q < 0) source.changes,
        List.filter (fun (_, q) -> Z.sign q > 0) source.changes )
    with
    | [ (from, _) ], [ (into, q) ] ->
        from ^ " -> " ^ into ^ ": " ^ B.format book source.measure q ^ " " ^ source.measure
    | _ -> string_of_int (List.length source.changes) ^ " movement change(s)  " ^ source.measure
  in
  let prompt =
    if created then "The Scheduled occurrence is already published; choose its expected pace."
    else "Choose the expected pace of explicit plans."
  in
  let header =
    [
      (O.Plain, O.clip_text ~width_of width ("Selected: " ^ source.day ^ "  " ^ changes));
      (O.Status, O.clip_text ~width_of width prompt);
    ]
  in
  let header = if height >= 10 then header else List.filteri (fun i _ -> i = 0) header in
  let note =
    if height >= 12 then [ (O.Status, "Monitoring only. No future Scheduled is created.") ] else []
  in
  let panel_h =
    max 0 (min (List.length labels + 2) (height - List.length header - List.length note))
  in
  (* The selected choice stays inside the frame when it cannot show them all. *)
  let first = max 0 (choice - max 1 (panel_h - 2) + 1) in
  let options =
    List.filteri
      (fun i _ -> i >= first)
      (List.mapi
         (fun i label ->
           ((if i = choice then O.Active else O.Plain), (if i = choice then "> " else "  ") ^ label))
         labels)
  in
  header
  @ Panel.frame_rows ~inset:0 ~width_of ~width ~height:panel_h ~focused:true
      ~bottom_label:(Printf.sprintf "%d/%d" (choice + 1) (List.length labels))
      ~title:(if created then "Expected pace after creation" else "Expected pace")
      options
  @ note

let pace_width width = if width >= 31 then 11 else 0
let plan_width width = min 28 (max 2 (width - pace_width width - 8))
let month_window width = max 0 ((width - plan_width width - pace_width width) / 8)
let trailing_start selected capacity = if selected < capacity then 0 else selected + 1 - capacity

let flow ~width_of width tokens =
  List.rev
    (List.fold_left
       (fun lines token ->
         match lines with
         | current :: rest when width_of (current ^ " " ^ token) <= width ->
             (current ^ " " ^ token) :: rest
         | _ -> token :: lines)
       [] tokens)

let batch_latest env t =
  match latest_plan env t with
  | Some p -> (t, Screen.Record_action { action = Screen.Batch; target = Some (Screen.Plan p) })
  | None ->
      (t, unless_blocked env "Select an explicit Scheduled reference for batch amount editing.")

let handle_coverage (env : Screen.env) t key =
  let stay t = (t, Screen.Stay) and say t m = (t, unless_blocked env m) in
  let count = List.length (coverage_rows env) in
  let row = clamp_index count t.coverage_row in
  let months = match coverage env with Ok (months, _) -> List.length months | Error _ -> 0 in
  match key with
  | Some (`ASCII 'k', []) | Some (`Arrow `Up, []) ->
      if row = 0 then say t "No previous recurring plan."
      else stay { t with coverage_row = row - 1 }
  | Some (`ASCII 'j', []) | Some (`Arrow `Down, []) ->
      if row + 1 < count then stay { t with coverage_row = row + 1 }
      else say t "No next recurring plan."
  | Some (`Page `Up, []) | Some (`ASCII 'u', [ `Ctrl ]) ->
      stay { t with coverage_row = row - min row 8 }
  | Some (`Page `Down, []) | Some (`ASCII 'd', [ `Ctrl ]) ->
      stay { t with coverage_row = clamp_index count (row + 8) }
  | Some (`Home, []) -> stay { t with coverage_row = 0 }
  | Some (`End, []) -> stay { t with coverage_row = max 0 (count - 1) }
  | Some (`ASCII 'h', []) | Some (`Arrow `Left, []) ->
      if t.coverage_offset = 0 then say t "Already at the first coverage month."
      else stay { t with coverage_offset = t.coverage_offset - 1 }
  | Some (`ASCII 'l', []) | Some (`Arrow `Right, []) ->
      if months = 0 then say t "Coverage months are unavailable."
      else if t.coverage_offset + 1 < months then
        stay { t with coverage_offset = t.coverage_offset + 1 }
      else say t "No later coverage month is loaded."
  | Some (`Enter, []) | Some (`ASCII 'i', []) ->
      if count = 0 then say t "No recurring plan is selected."
      else stay { t with view = Plan_view; coverage_row = row; plan_row = 0 }
  | Some (`ASCII 'f', []) -> say t "The overview always uses the current-open frontier."
  | Some (`ASCII 'c', []) ->
      say t "Press Enter to inspect the selected plan before completing one occurrence."
  | Some (`ASCII 'r', []) ->
      say t "Press Enter to inspect the selected plan before replacing one occurrence."
  | Some (`ASCII 'x', []) ->
      say t "Press Enter to inspect the selected plan before cancelling one occurrence."
  | Some (`ASCII 'b', []) -> batch_latest env t
  | Some (`ASCII 'e', []) -> replenish env t
  | Some (`ASCII 'g', []) -> say t "Use e to replenish the selected recurring plan."
  | Some (`ASCII ('p' | 'm'), []) -> change_pace env t
  | Some (`ASCII 's', []) -> stop_monitoring env t
  | Some (`ASCII 'v', []) -> (toggle_view env env.book t, unless_blocked env "")
  | Some (`ASCII 'n', []) -> (t, Screen.New_plan)
  | Some ((`Escape | `ASCII 'q'), []) -> (t, Screen.Back)
  | _ -> (t, Screen.Ignored)

let handle_plan (env : Screen.env) t key =
  let stay t = (t, Screen.Stay) and say t m = (t, unless_blocked env m) in
  let count =
    match selected_rule env t with Some row -> List.length (plan_entries env row) | None -> 0
  in
  let at = clamp_index count t.plan_row in
  let explicit action =
    match selected_entry env { t with plan_row = at } with
    | Some (Occurrence (p, _)) -> (t, Screen.Record_action { action; target = Some (Screen.Plan p) })
    | Some (Missing_month _) ->
        say t "The selected row is a missing monitored month, not an explicit Scheduled occurrence."
    | None -> say t "Plan details are unavailable."
  in
  match key with
  | Some (`ASCII 'k', []) | Some (`Arrow `Up, []) ->
      if at = 0 then say t "Already at the first plan entry." else stay { t with plan_row = at - 1 }
  | Some (`ASCII 'j', []) | Some (`Arrow `Down, []) ->
      if at + 1 < count then stay { t with plan_row = at + 1 }
      else say t "Already at the last plan entry."
  | Some (`Page `Up, []) | Some (`ASCII 'u', [ `Ctrl ]) -> stay { t with plan_row = at - min at 8 }
  | Some (`Page `Down, []) | Some (`ASCII 'd', [ `Ctrl ]) ->
      stay { t with plan_row = clamp_index count (at + 8) }
  | Some (`Home, []) -> stay { t with plan_row = 0 }
  | Some (`End, []) -> stay { t with plan_row = max 0 (count - 1) }
  | Some (`ASCII ('h' | 'l'), []) | Some (`Arrow (`Left | `Right), []) ->
      say t "Plan Detail uses one vertical plan list; j/k moves the selection."
  | Some ((`Enter | `ASCII 'c'), []) -> explicit Screen.Pay
  | Some (`ASCII 'r', []) -> explicit Screen.Edit
  | Some (`ASCII 'x', []) -> explicit Screen.Cancel
  | Some (`ASCII 'b', []) -> batch_latest env t
  | Some (`ASCII 'e', []) -> replenish env t
  | Some (`ASCII 'g', []) -> say t "Use e to replenish the selected recurring plan."
  | Some (`ASCII ('p' | 'm'), []) -> change_pace env t
  | Some (`ASCII 's', []) -> stop_monitoring env t
  | Some (`ASCII 'f', []) ->
      say t "Plan Detail always shows the selected plan's current-open occurrences."
  | Some ((`Escape | `ASCII ('q' | 'v')), []) -> stay { t with view = Coverage_view; plan_row = 0 }
  | Some (`ASCII 'n', []) -> (t, Screen.New_plan)
  | _ -> (t, Screen.Ignored)

let coverage_paint (env : Screen.env) (geometry : Screen.geometry) t =
  let width_of = geometry.width_of and width, height = geometry.content in
  let legend =
    List.map
      (fun line -> (O.Status, line))
      (flow ~width_of width
         (if snd geometry.screen < 18 then
            [ "days=open;"; "✓=done;"; "!=gap;"; "blank=not expected" ]
          else
            [
              "days = open;";
              "✓ = completed;";
              "p = open count;";
              "! = expected gap;";
              "blank = not expected;";
              "pace = guidance only";
            ]))
  in
  let panel_h = max 0 (height - List.length legend) in
  let inner_w = max 0 (width - 2) and inner_h = max 0 (panel_h - 2) in
  match coverage env with
  | Error why ->
      Panel.frame_rows ~inset:0 ~width_of ~width ~height:panel_h ~focused:true
        ~title:"Monitored plans [Unavailable]"
        (List.map
           (fun l -> (O.Plain, l))
           (O.wrap_text ~width_of inner_w (" [Coverage unavailable] " ^ why))
        @ [ (O.Status, " Months and List remain available with v.") ])
      @ legend
  | Ok (months, rows) ->
      let count = List.length rows in
      let selected = clamp_index count t.coverage_row in
      let shown_months =
        List.filteri
          (fun i _ -> i >= t.coverage_offset && i - t.coverage_offset < month_window inner_w)
          months
      in
      let capacity = max 1 (inner_h - if inner_h >= 2 then 1 else 0) in
      let start = trailing_start selected capacity in
      let pace_w = pace_width inner_w and plan_w = plan_width inner_w in
      let header =
        O.pad ~width_of plan_w "Plan" ^ O.pad ~width_of pace_w "Pace"
        ^ String.concat "" (List.map (fun m -> O.pad ~width_of 8 (Cov.month_label m)) shown_months)
      in
      let line index (row : Cov.row) =
        let cells =
          List.filteri
            (fun i _ -> i >= t.coverage_offset && i - t.coverage_offset < List.length shown_months)
            row.cells
        in
        let text =
          (if index = selected then "> " else "  ")
          ^ O.pad ~width_of (max 0 (plan_w - 2)) row.rule.name
          ^ O.pad ~width_of pace_w (Cov.cadence_label row.rule.every_months)
          ^ String.concat "" (List.map (fun c -> O.pad ~width_of 8 (Cov.cell_text c)) cells)
        in
        ((if index = selected then O.Active else O.Plain), text)
      in
      let body =
        if rows = [] then [ (O.Status, "No recurring plans are being monitored.") ]
        else
          (if inner_h >= 2 then [ (O.Status, header) ] else [])
          @ List.filteri (fun i _ -> i >= start && i - start < capacity) (List.mapi line rows)
      in
      let more = (if start > 0 then " ▲" else "") ^ if start + capacity < count then " ▼" else "" in
      Panel.frame_rows ~inset:0 ~width_of ~width ~height:panel_h ~focused:true
        ~bottom_label:
          ((if count = 0 then "0/0" else Printf.sprintf "%d/%d" (selected + 1) count) ^ more)
        ~title:(Printf.sprintf "Monitored plans (%d)" count)
        body
      @ legend

let entry_quantity book = function
  | Missing_month _ -> "—"
  | Occurrence (p, _) -> (
      match
        ( List.filter (fun (_, q) -> Z.sign q < 0) p.B.changes,
          List.filter (fun (_, q) -> Z.sign q > 0) p.B.changes )
      with
      | [ _ ], [ (_, q) ] -> grouped (B.format book p.measure q) ^ " " ^ p.measure
      | _ -> Printf.sprintf "split (%d)" (List.length p.changes))

let plan_paint (env : Screen.env) (geometry : Screen.geometry) t =
  let width_of = geometry.width_of and width, height = geometry.content in
  let legend =
    List.map
      (fun line -> (O.Status, line))
      (flow ~width_of width
         (if snd geometry.screen < 18 then [ "MISSING = gap only;"; "exact amounts" ]
          else
            [
              "Explicit dates;";
              "pace = guidance;";
              "MISSING is not an occurrence;";
              "exact amounts.";
            ]))
  in
  let panel_h = max 0 (height - List.length legend) in
  let inner_w = max 0 (width - 2) and inner_h = max 0 (panel_h - 2) in
  match selected_rule env t with
  | None ->
      Panel.frame_rows ~inset:0 ~width_of ~width ~height:panel_h ~focused:true ~title:"Plan"
        [ (O.Status, " No recurring plan is selected.") ]
      @ legend
  | Some row ->
      let entries = plan_entries env row in
      let total = List.length entries in
      let at = clamp_index total t.plan_row in
      let show_header = inner_h >= 2 && inner_w >= 42 in
      let capacity = max 1 (inner_h - if show_header then 1 else 0) in
      let start = trailing_start at capacity in
      let qty_w =
        min
          (max 0 (inner_w - 2 - 10 - 4 - 14))
          (min 22
             (max 14
                (List.fold_left (fun w e -> max w (width_of (entry_quantity env.book e))) 0 entries)))
      in
      let status_w = max 0 (inner_w - 2 - 10 - 4 - qty_w) in
      let tabular = inner_w >= 42 in
      let cells date status qty =
        O.pad ~width_of 10 date ^ "  " ^ O.pad ~width_of status_w status ^ "  "
        ^ O.pad_left ~width_of qty_w (if width_of qty <= qty_w then qty else "too wide")
      in
      let line index e =
        let date, status =
          match e with
          | Missing_month m ->
              (m, if tabular && status_w >= 22 then "MISSING monitored month" else "MISSING")
          | Occurrence (p, on_pace) -> (p.B.day, if on_pace then "[on pace]" else "[outside pace]")
        in
        let marker = if index = at then "> " else "  " in
        ( (if index = at then O.Active else O.Plain),
          marker
          ^ if tabular then cells date status (entry_quantity env.book e) else date ^ " " ^ status
        )
      in
      let body =
        if entries = [] then
          [ (O.Status, " No current-open occurrences or monitored gaps in the loaded horizon.") ]
        else
          (if show_header then [ (O.Status, "  " ^ cells "Date/Month" "Status" "Amount") ] else [])
          @ List.filteri (fun i _ -> i >= start && i - start < capacity) (List.mapi line entries)
      in
      let more = (if start > 0 then " ▲" else "") ^ if start + capacity < total then " ▼" else "" in
      Panel.frame_rows ~inset:0 ~width_of ~width ~height:panel_h ~focused:true
        ~bottom_label:((if total = 0 then "0/0" else Printf.sprintf "%d/%d" (at + 1) total) ^ more)
        ~title:"Occurrences / monitored gaps" body
      @ legend

(* --- List: Loci pane, aligned occurrence table, inline selected record --- *)

let list_shape (p : B.plan) =
  let side positive =
    List.sort_uniq String.compare
      (List.filter_map (fun (id, q) -> if Z.sign q > 0 = positive then Some id else None) p.changes)
  in
  let negative, positive = (side false, side true) in
  (* An arrow would claim a movement the changes do not state. *)
  if negative = [] || positive = [] then String.concat "," (negative @ positive)
  else String.concat "," negative ^ " -> " ^ String.concat "," positive

let list_amount book (p : B.plan) = entry_quantity book (Occurrence (p, true))

let side_by_side ~height left_width left_rows right_rows =
  let pad rows = rows @ List.init (max 0 (height - List.length rows)) (fun _ -> (O.Plain, "")) in
  List.map2
    (fun (left_style, left) (right_style, right) ->
      (O.Columns (left_width, left_style, right_style), left ^ " " ^ right))
    (pad left_rows) (pad right_rows)

let list_paint (env : Screen.env) (geometry : Screen.geometry) t =
  let book = env.book and width_of = geometry.width_of in
  let width, height = geometry.content in
  let rows = rows book t in
  let plans = List.filter_map (function RB.Scheduled_plan p -> Some p | _ -> None) rows in
  let names = loci book t in
  let detail_height =
    if height < 13 then 0
    else min ((if height >= 48 then 10 else if height >= 36 then 8 else 6) + 2) (height - 5)
  in
  let panel_h = max 0 (height - detail_height) in
  let focused = if t.pane = Loci_pane then Loci_pane else List_pane in
  let locus_panel pane_w =
    let inner_w = max 0 (pane_w - 2) in
    let total = List.length names + 1 in
    let selected = min (locus_row book t) (total - 1) in
    let capacity = max 1 (panel_h - 2) in
    let start = trailing_start selected capacity in
    let active = t.pane = Loci_pane in
    let label i =
      if i = 0 then "[All loci]" else Option.value ~default:"" (List.nth_opt names (i - 1))
    in
    let line i =
      ( (if i = selected && active then O.Active else O.Plain),
        O.clip_text ~width_of inner_w
          ((if i = selected then if active then "> " else "* " else "  ") ^ label i) )
    in
    let more = (if start > 0 then " ▲" else "") ^ if start + capacity < total then " ▼" else "" in
    Panel.frame_rows ~inset:0 ~width_of ~width:pane_w ~height:panel_h ~focused:active
      ~title:(Printf.sprintf "Loci (%d)" (List.length names))
      ~bottom_label:(Printf.sprintf "%d/%d%s" (selected + 1) total more)
      (List.init (max 0 (min capacity (total - start))) (fun i -> line (start + i)))
  in
  let occurrence_panel pane_w =
    let inner_w = max 0 (pane_w - 2) in
    let at = (browser t).selected in
    let total = List.length plans in
    let tabular = inner_w >= 32 in
    let show_header = tabular && panel_h >= 4 in
    let capacity = max 1 (max 0 (panel_h - 2) - if show_header then 1 else 0) in
    let start = trailing_start at capacity in
    let qty_w =
      min
        (max 0 (inner_w - 24))
        (min 22
           (max 12 (List.fold_left (fun w p -> max w (width_of (list_amount book p))) 0 plans)))
    in
    let shape_w = max 0 (inner_w - 2 - 14 - qty_w) in
    let cells date shape amount =
      O.pad ~width_of 10 date ^ "  "
      ^ O.pad ~width_of shape_w (O.clip_text ~width_of shape_w shape)
      ^ "  "
      ^ O.pad_left ~width_of qty_w (if width_of amount <= qty_w then amount else "too wide")
    in
    let active = t.pane = List_pane in
    let line index (p : B.plan) =
      let text =
        if tabular then
          (if index = at then if active then "> " else "* " else "  ")
          ^ cells p.B.day (list_shape p) (list_amount book p)
        else
          let amount = list_amount book p in
          (if index = at then if active then "> " else "* " else "  ")
          ^ p.day ^ " "
          ^ if width_of amount <= max 0 (inner_w - 13) then amount else "too wide"
      in
      ((if index = at && active then O.Active else O.Plain), O.clip_text ~width_of inner_w text)
    in
    let empty =
      if total > 0 then []
      else
        [
          ( O.Status,
            " "
            ^
            if t.list.query <> "" then "No Scheduled occurrence matches this search and scope."
            else
              match t.list.locus with
              | Some _ -> "No matching Scheduled occurrences for this Locus."
              | None ->
                  if t.list.day <> None then "(none dated on this day)"
                  else "(no current-open Scheduled occurrences)" );
        ]
    in
    let body =
      if total = 0 then empty
      else
        (if show_header then [ (O.Status, "  " ^ cells "Date" "Shape" "Amount") ] else [])
        @ List.filteri (fun i _ -> i >= start && i - start < capacity) (List.mapi line plans)
    in
    let more = (if start > 0 then " ▲" else "") ^ if start + capacity < total then " ▼" else "" in
    Panel.frame_rows ~inset:0 ~width_of ~width:pane_w ~height:panel_h ~focused:active
      ~title:(Printf.sprintf "Scheduled (%d)" total)
      ~bottom_label:((if total = 0 then "0/0" else Printf.sprintf "%d/%d" (at + 1) total) ^ more)
      body
  in
  let panels =
    if width >= 80 then
      let left_width = min 30 (max 20 (width / 4)) in
      side_by_side ~height:panel_h left_width (locus_panel left_width)
        (occurrence_panel (max 0 (width - left_width - 1)))
    else if focused = Loci_pane then locus_panel width
    else occurrence_panel width
  in
  let details =
    if detail_height = 0 then []
    else
      let lines = detail_rows ~width_of ~width:(max 1 (width - 2)) book t in
      let capacity = max 0 (detail_height - 2) in
      let overflow =
        if List.length lines > capacity then
          Some (Printf.sprintf "%d/%d lines ▼" capacity (List.length lines))
        else None
      in
      Panel.frame_rows ~inset:0 ?bottom_label:overflow ~width_of ~width ~height:detail_height
        ~focused:false ~title:"Selected Scheduled"
        (List.map (fun line -> (O.Plain, line)) lines)
  in
  panels @ details

(* The List search line: Enter applies the query, Esc clears it. *)
let handle_search (env : Screen.env) t value input =
  let book = env.book and stay t = (t, Screen.Stay) in
  let close query =
    synced book
      { (with_browser t (RB.with_query (browser t) query)) with search = None; scroll = 0 }
  in
  match input with
  | `Key (`Escape, []) -> stay (close "")
  | `Key (`Enter, []) -> stay (close value)
  | _ ->
      stay
        (match input_text value input with
        | None -> t
        | Some value -> { t with search = Some value })

let handle_months (env : Screen.env) (geometry : Screen.geometry) t key =
  let book = env.book and stay t = (t, Screen.Stay) in
  let detail = t.pane = Detail_pane in
  match key with
  | Some ((`Escape | `ASCII 'q'), []) ->
      if detail then stay { t with pane = List_pane; scroll = 0 } else (t, Screen.Back)
  | Some (`ASCII 'b', []) -> action book t Screen.Batch
  | Some (`ASCII 'g', []) -> action book t Screen.Generate
  | Some (`ASCII 'v', []) ->
      (toggle_view env book { t with pane = List_pane; scroll = 0 }, unless_blocked env "")
  | Some (((`ASCII ('h' | 'l') | `Arrow (`Left | `Right)) as k), []) when not detail -> (
      let delta = match k with `ASCII 'h' | `Arrow `Left -> -1 | _ -> 1 in
      match Months.shift t.months delta with
      | Ok months -> stay { t with months }
      | Error message -> (t, unless_blocked env message))
  | Some (`ASCII ('f' | '/'), []) ->
      (t, unless_blocked env "Months uses all current-open plans; v opens filtered List.")
  | Some (`Enter, []) -> action book t Screen.Pay
  | Some (`ASCII 'r', []) -> action book t Screen.Edit
  | Some ((`ASCII ('h' | 'l') | `Arrow (`Left | `Right)), []) ->
      stay { t with pane = List_pane; scroll = 0 }
  | Some (`ASCII 'c', []) -> action book t Screen.Pay
  | Some (`ASCII 'x', []) -> action book t Screen.Cancel
  | Some (`ASCII 'e', []) -> extend_selected env t
  | Some (`ASCII ('p' | 'm'), []) -> change_pace env t
  | Some (`ASCII 's', []) -> stop_monitoring env t
  | Some (`ASCII 'e', [ `Ctrl ]) -> action book t Screen.Edit
  | Some (`ASCII 'i', []) -> stay { t with pane = Detail_pane; origin = List_pane; scroll = 0 }
  | Some (((`Home | `End | `Page _ | `ASCII ('j' | 'k') | `Arrow (`Up | `Down)) as k), [])
  | Some ((`ASCII ('u' | 'd') as k), [ `Ctrl ]) ->
      let _, view = detail_window env geometry t in
      let delta = Ui_input.motion_delta ~page:(max 1 (if detail then view.capacity else 8)) k in
      if detail then stay { t with scroll = Panel.move ~last:view.last ~position:view.start delta }
      else
        let t = synced book t in
        stay
          (follow_months book
             { (with_browser t (RB.move (browser t) (rows book t) delta)) with scroll = 0 })
  | Some ((`Tab | `ASCII 'w'), []) | Some (`Tab, [ `Shift ]) ->
      stay
        (if detail then { t with pane = List_pane; scroll = 0 }
         else { t with pane = Detail_pane; origin = List_pane; scroll = 0 })
  | Some (`ASCII 'n', []) -> (t, Screen.New_plan)
  | _ -> (t, Screen.Ignored)

let handle_list (env : Screen.env) (geometry : Screen.geometry) t key =
  let book = env.book and stay t = (t, Screen.Stay) in
  let detail = t.pane = Detail_pane in
  let open_detail t = { t with pane = Detail_pane; origin = t.pane } in
  let move_rows delta =
    synced book (with_browser { t with scroll = 0 } (RB.move (browser t) (rows book t) delta))
  in
  let move_loci delta =
    let last = List.length (loci book t) and row = locus_row book t in
    let row =
      if delta > 0 then row + min delta (last - row) else if delta < -row then 0 else row + delta
    in
    set_locus book t row
  in
  match key with
  | Some ((`Escape | `ASCII 'q'), []) ->
      if detail then stay { t with pane = t.origin; scroll = 0 } else (t, Screen.Back)
  | (Some ((`ASCII ('h' | 'l') as k), []) | Some ((`Arrow (`Left | `Right) as k), []))
    when not detail ->
      stay
        { t with pane = (match k with `ASCII 'h' | `Arrow `Left -> Loci_pane | _ -> List_pane) }
  | Some (`ASCII 'f', []) ->
      let browser = RB.toggle_day (RB.with_locus (browser t) None) ~focus_day:t.focus_day in
      stay (synced book (with_browser { t with pane = List_pane; scroll = 0 } browser))
  | Some (`Enter, []) -> if t.pane = Loci_pane then stay t else action book t Screen.Pay
  | Some (`ASCII 'i', []) -> stay (if detail then t else open_detail { t with scroll = 0 })
  | Some ((`Tab | `ASCII 'w'), []) | Some (`Tab, [ `Shift ]) ->
      stay (if detail then { t with pane = t.origin } else open_detail t)
  | Some (`ASCII ('c' | 'r' | 'x' | 'e' | 'b' | 'g' | 'p' | 'm' | 's'), [])
  | Some (`ASCII 'e', [ `Ctrl ])
    when t.pane = Loci_pane ->
      (t, unless_blocked env "Focus the Scheduled pane with l before acting on an occurrence.")
  | Some (`ASCII 'c', []) -> action book t Screen.Pay
  | Some (`ASCII 'r', []) -> action book t Screen.Edit
  | Some (`ASCII 'x', []) -> action book t Screen.Cancel
  | Some (`ASCII 'b', []) -> action book t Screen.Batch
  | Some (`ASCII 'g', []) -> action book t Screen.Generate
  | Some (`ASCII 'e', []) -> extend_selected env t
  | Some (`ASCII ('p' | 'm'), []) -> change_pace env t
  | Some (`ASCII 's', []) -> stop_monitoring env t
  | Some (`ASCII 'e', [ `Ctrl ]) -> action book t Screen.Edit
  | Some (`ASCII 'n', []) -> (t, Screen.New_plan)
  | Some (`ASCII '/', []) -> stay { t with search = Some (browser t).query }
  | Some (`ASCII 'v', []) ->
      (toggle_view env book { t with pane = List_pane; scroll = 0 }, unless_blocked env "")
  | Some (((`Home | `End | `Page _ | `ASCII ('j' | 'k') | `Arrow (`Up | `Down)) as k), [])
  | Some ((`ASCII ('u' | 'd') as k), [ `Ctrl ]) ->
      if detail then
        let _, view = detail_window env geometry t in
        let delta = Ui_input.motion_delta ~page:view.capacity k in
        stay { t with scroll = Panel.move ~last:view.last ~position:view.start delta }
      else
        let delta = Ui_input.motion_delta ~page:8 k in
        stay (if t.pane = Loci_pane then move_loci delta else move_rows delta)
  | _ -> (t, Screen.Ignored)

let handle (env : Screen.env) (geometry : Screen.geometry) t input =
  match t.search with
  | Some value -> handle_search env t value input
  | None -> (
      let _, view = detail_window env geometry t in
      let key = Ui_input.key_ignoring_case input in
      let t = { t with scroll = view.start; view = current env { t with scroll = view.start } } in
      match (t.pace, t.view) with
      | Some chooser, _ -> handle_pace env t chooser key
      | None, Coverage_view -> handle_coverage env t key
      | None, Plan_view -> handle_plan env t key
      | None, Months_view -> handle_months env geometry t key
      | None, List_view -> handle_list env geometry t key)

let enter ~focus_day t =
  let list =
    match t.list.day with
    | None -> t.list
    | Some day when day = focus_day -> t.list
    | Some _ -> RB.with_locus { t.list with day = Some focus_day } None
  in
  {
    t with
    focus_day;
    list;
    pane = List_pane;
    origin = List_pane;
    scroll = 0;
    search = None;
    plan_row = 0;
    view = (match t.view with Plan_view -> Coverage_view | v -> v);
  }

let paint (env : Screen.env) (geometry : Screen.geometry) t =
  let book = env.book and width_of = geometry.width_of in
  let width, height = geometry.content in
  let t = synced book t in
  let rows = rows book t in
  let is_detail = t.pane = Detail_pane in
  match (t.pace, t.view) with
  | Some chooser, _ -> pace_paint env geometry t chooser
  | None, Coverage_view -> coverage_paint env geometry t
  | None, Plan_view -> plan_paint env geometry t
  | None, Months_view ->
      if is_detail then
        Panel.frame ~width_of ~width ~height ~focused:true ~title:"Selected Scheduled"
          ~scroll:t.scroll ~selected:None
          (detail_rows ~width_of ~width book t)
      else
        let plans = List.filter_map (function RB.Scheduled_plan p -> Some p | _ -> None) rows in
        Months.screen ~book ~plans ~dimensions:(width, height) ~width_of
          ~selected:(selected_plan book t) t.months
  | None, List_view ->
      (* [i]/[Tab]/[w] retain the exact full-detail text and scroll. *)
      if is_detail then
        Panel.frame ~width_of ~width ~height ~focused:true ~title:"Selected Scheduled"
          ~scroll:t.scroll ~selected:None
          (detail_rows ~width_of ~width book t)
      else list_paint env geometry t

let footer (geometry : Screen.geometry) t =
  let width = fst geometry.screen in
  match (t.view, t.pane) with
  | _ when t.pace <> None ->
      if t.pace_mode = Created then [ "Enter choose  Up/Down move  Esc keep one" ]
      else [ "Enter save monitoring  Up/Down choose  Esc cancel" ]
  | Coverage_view, _ ->
      if width >= 79 then
        [
          "[j/k] plan  [h/l] months  [Enter] detail  [q] back";
          "[e] replenish  [b] batch  [p] pace  [s] undecided  [n] new  [v] views";
        ]
      else if width >= 47 then
        [
          "[j/k] plan [h/l] months [Enter] detail [q] back";
          "[e] replenish [b] batch [p] pace [s] undecided";
        ]
      else [ "[j/k] plan [q] back"; "[Enter] detail [v] views" ]
  | Plan_view, _ ->
      if width >= 79 then
        [
          "[j/k] select  [c/Enter] complete  [q] overview";
          "[e] replenish  [b] batch  [r] replace  [x] cancel  [p] pace  [s] undecided";
        ]
      else if width >= 47 then
        [ "[j/k] select [c/Enter] complete [q] overview"; "[b] batch [r] replace [x] cancel" ]
      else [ "[j/k] select [q] overview"; "[c/Enter] complete [x] cancel" ]
  | Months_view, Detail_pane ->
      if width >= 79 then
        [
          "j/k PgUp/Dn Home/End scroll  Tab/q Months";
          "Enter/c complete  g generate  b batch  x cancel  v List";
        ]
      else [ "j/k scroll  Tab/q Months"; "Enter complete  v List" ]
  | Months_view, _ ->
      if width >= 79 then
        [
          "j/k select  h/l months  Enter/c complete  q back";
          "i/Tab detail  b batch  r edit  e extend  p pace  g gen  x cancel  v List";
        ]
      else if width >= 47 then
        [
          "j/k select  h/l months  Enter complete  q back";
          "i detail b batch r edit x cancel n new v List";
        ]
      else [ "j/k select  h/l months  v List"; "Enter complete  i detail  q back" ]
  | List_view, Loci_pane ->
      if width >= 79 then
        [
          "[j/k] Locus  [l] occurrences  [f] scope  [i] detail  [q] back";
          "[n] new  [v] views  [/] search";
        ]
      else if width >= 47 then
        [ "[j/k] Locus [h/l] pane [f] scope [q] back"; "[l] occurrences [i] detail [v] views" ]
      else if width >= 31 then [ "[j/k] Locus [i] detail [q] back"; "[h/l] pane [f] scope" ]
      else [ "[j/k] [h/l]"; "[i] [f] [q]" ]
  | List_view, List_pane ->
      if width >= 79 then
        [
          "[j/k] select  [h/l] pane  [f] scope  [Enter] complete  [q] back  [v] views";
          "[i] detail [b] batch [r] edit [e] extend [p] pace [g] gen [x] cancel [n] new";
        ]
      else if width >= 47 then
        [
          "j/k select [h/l] pane [f] scope [q] back";
          "Enter complete [i] detail [b] batch [x] cancel";
        ]
      else if width >= 31 then [ "j/k select [f] scope [q] back"; "h/l pane [Enter] complete" ]
      else [ "[j/k] [h/l]"; "[Enter] [q]" ]
  | List_view, Detail_pane ->
      if width >= 79 then
        [
          "j/k scroll  PgUp/Dn page  Home/End range  Tab pane  q/Esc back";
          "Enter/c complete  b batch  r edit  e extend  p pace  g gen  x cancel  n new";
        ]
      else if width >= 47 then
        [ "j/k scroll  PgUp/Dn page  Tab/q back"; "Enter complete  b batch  r edit  x cancel" ]
      else [ "j/k scroll  PgDn page"; "Tab back  Enter complete" ]

let view env (geometry : Screen.geometry) t =
  let t = { t with view = current env t } in
  let overlay =
    Option.bind t.search
      (RB.search_overlay ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body)
  in
  {
    Screen.title =
      (match (t.view, selected_rule env t) with
      | _ when t.pace <> None ->
          if t.pace_mode = Created then "Scheduled / Expected pace after creation"
          else "Scheduled / Plan Monitoring"
      | Coverage_view, _ -> "Scheduled Series Calendar"
      | Plan_view, Some row -> "Scheduled / Plan / " ^ row.rule.name
      | Plan_view, None -> "Scheduled / Plan"
      | Months_view, _ -> tr "Scheduled / Months"
      | List_view, _ -> tr "Scheduled / List");
    subtitle =
      (match (t.view, selected_rule env t, coverage env) with
      | _ when t.pace <> None ->
          Screen.Text
            (if t.pace_mode = Created then
               "Monitoring only; the published Scheduled occurrence is unchanged."
             else "Monitoring only; Scheduled occurrences are unchanged.")
      | Coverage_view, _, Ok (months, _) ->
          let width = max 0 (fst geometry.content - 2) in
          let shown =
            List.filteri
              (fun i _ -> i >= t.coverage_offset && i - t.coverage_offset < month_window width)
              months
          in
          let window =
            match shown with
            | [] -> if months = [] then "(empty loaded horizon)" else "(widen for months)"
            | first :: _ -> first ^ " .. " ^ List.nth shown (List.length shown - 1)
          in
          Screen.Text ("Month window: " ^ window ^ "  |  known through " ^ env.today)
      | Coverage_view, _, Error _ -> Screen.Text "Coverage unavailable"
      | Plan_view, Some row, _ ->
          Screen.Text
            ("Pace: "
            ^ (match row.rule.every_months with
              | 0 -> "undecided"
              | 1 -> "monthly"
              | n -> "every " ^ string_of_int n ^ " months")
            ^ " from " ^ row.rule.anchor ^ "  |  Shape: "
            ^ String.concat "," row.rule.negative
            ^ " -> "
            ^ String.concat "," row.rule.positive)
      | Plan_view, None, _ -> Screen.Default
      | Months_view, _, _ -> Screen.Text "Explicit current-open plans; no recurrence inferred."
      | List_view, _, _ ->
          let scope =
            match t.list.day with
            | None -> "Scope: all current-open"
            | Some day -> "Scope: focus day " ^ day
          in
          let locus =
            match t.list.locus with None -> "Locus: all loci" | Some id -> "Locus: " ^ id
          in
          let query = if t.list.query = "" then "" else "  |  Search: " ^ t.list.query in
          Screen.Text (scope ^ "  |  " ^ locus ^ query));
    rows = lazy (paint env geometry t);
    footer = footer geometry t;
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
