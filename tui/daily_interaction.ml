(* English-first workspace controller. UI state never owns accounting facts. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module F = Daily_file
module A = Daily_actions
module O = Daily_overlays
module P = Ui_preferences
module W = Ui_workspace
module Cal = Daily_calendar
module M = Ui_commands
module S = Record_session

let tr = Ui_text.tr
let get = A.get
let get_id = A.get_id

type input = Ui_input.input

type style = O.style =
  | Plain
  | Active
  | Heading
  | Status
  | Chrome
  | Frame
  | Focused_frame
  | Panel
  | Panel_heading
  | Panel_active

type overlay =
  | No_overlay
  | Commands of M.t
  | Themes of { selected : int; original : P.theme }
  | Jump of string
  | Search of string

type state = {
  session : F.t;
  workspace : W.t;
  record : S.t option;
  record_visible : bool;
  overlay : overlay;
  theme : P.theme;
  message : string;
  ui_notice : string option;
  blocked : bool;
  pending : A.uncertain_evidence option;
  config_home : string option;
  scroll : int;
  paste_blocked : bool;
}

let initial ?config_home session =
  let measure = match B.measures session.F.book with (id, _) :: _ -> id | [] -> "" in
  let workspace = get (W.create ~today:(F.today ()) ~measure) in
  let notice = A.recovery_notice ~session in
  {
    session;
    workspace;
    record = None;
    record_visible = false;
    overlay = No_overlay;
    theme = P.load_theme ?config_home ();
    message = Option.value ~default:"" notice;
    ui_notice = None;
    blocked = notice <> None;
    pending = None;
    config_home;
    scroll = 0;
    paste_blocked = false;
  }

let has_record_draft state =
  match state.record with None -> false | Some record -> S.has_draft record

let editor_visible state = state.record_visible
let mode state = match state.record with None -> A.New | Some record -> S.mode record

let sync state =
  { state with workspace = W.sync ~book:state.session.book state.workspace; scroll = 0 }

let apply_commit_result state ~draft result =
  let published session message =
    sync
      {
        state with
        session;
        record = None;
        record_visible = false;
        overlay = No_overlay;
        pending = None;
        blocked = false;
        message = tr message;
      }
  in
  let stopped ?(pending = draft.pending) message =
    { draft with blocked = true; pending; message }
  in
  match result with
  | A.Published session ->
      published session "Published and read back. Previous bytes are kept separately."
  | A.Idempotent_duplicate { session; _ } ->
      published session "Already published; no duplicate was applied."
  | A.Conflict_base_changed ->
      stopped ~pending:None
        (tr "The preview generation changed. Draft retained; reload and review.")
  | A.Conflict ->
      stopped ~pending:None
        (tr "Another writer changed the book. Draft retained; reload and review.")
  | A.Conflict_lsn { expected; actual } ->
      stopped ~pending:None
        (A.format_message "Append conflict: expected LSN %d, found %d. Draft retained." expected
           actual)
  | A.Payload_drift_refused why ->
      stopped
        (A.format_message "Same ID has a different payload (%s). Retry stopped; draft retained." why)
  | A.Recovery_blocked -> stopped A.recovery_message
  | A.Storage_failed why ->
      stopped (A.format_message "Storage failed (%s). Writes stopped; draft retained." why)
  | A.Refused why ->
      { draft with message = A.format_message "Publication refused (%s). Draft retained." why }
  | A.Uncertain { message; evidence } ->
      stopped ~pending:(Some evidence)
        (A.format_message
           "Publication outcome is unknown (%s). Do not retry; reload to inspect. Draft retained."
           message)

let reload state =
  match A.reload ~session:state.session ~pending:state.pending ~mode:(mode state) with
  | A.Pending_confirmed session ->
      sync
        {
          state with
          session;
          pending = None;
          record = None;
          record_visible = false;
          blocked = false;
          message = tr "The pending publication is present now. No retry.";
        }
  | A.Pending_unconfirmed session ->
      {
        state with
        session;
        blocked = true;
        message = tr "Reloaded; the previous publication is still unconfirmed. No retry.";
      }
  | A.Edit_base_changed session ->
      {
        state with
        session;
        blocked = true;
        message =
          tr "The edited generation changed. Draft retained; discard explicitly and reselect.";
      }
  | A.Recovery_required (session, message) -> { state with session; blocked = true; message }
  | A.Reloaded session ->
      sync { state with session; blocked = false; message = tr "Reloaded. Unsaved draft retained." }
  | A.Reload_failed why ->
      {
        state with
        blocked = true;
        message = A.format_message "Reload failed (%s). Existing book and draft retained." why;
      }

let submit state =
  if state.blocked then state
  else
    match state.record with
    | None -> state
    | Some record ->
        {
          state with
          record =
            Some
              (S.preview ~book:state.session.book ~base_bytes:state.session.bytes
                 ~blocked:state.blocked record);
          record_visible = true;
        }

let discard state =
  match A.recovery_notice ~session:state.session with
  | Some message -> { state with blocked = true; message }
  | None when state.pending <> None ->
      {
        state with
        blocked = true;
        message = tr "Unconfirmed publication: inspect before discarding or retrying.";
      }
  | None ->
      {
        state with
        record = None;
        record_visible = false;
        blocked = false;
        message = tr "Draft discarded explicitly.";
      }

let open_record state =
  if state.blocked then state
  else
    match state.record with
    | Some record when S.has_draft record ->
        { state with record_visible = true; overlay = No_overlay }
    | _ ->
        {
          state with
          record =
            Some
              (S.create ~book:state.session.book ~day:state.workspace.calendar.selected_day
                 ~measure:state.workspace.measure ());
          record_visible = true;
          overlay = No_overlay;
          message = "";
        }

let open_route state route =
  sync { state with workspace = W.enter state.workspace route; overlay = No_overlay; scroll = 0 }

let selected state = W.selected_row ~book:state.session.book state.workspace

let edit_selected state =
  if state.blocked then state
  else if has_record_draft state then
    {
      state with
      message = tr "A draft is retained. Resume or discard it before correcting another Actual.";
    }
  else
    match selected state with
    | Some (W.Actual_entry entry) -> (
        match S.of_edit ~book:state.session.book entry with
        | Ok record -> { state with record = Some record; record_visible = true; message = "" }
        | Error why -> { state with message = why })
    | Some (W.Scheduled_plan _) | None -> { state with message = tr "Select an Actual to correct." }

let pay_selected state =
  if state.blocked then state
  else if has_record_draft state then
    {
      state with
      message = tr "A draft is retained. Resume or discard it before completing Scheduled.";
    }
  else
    match selected state with
    | Some (W.Scheduled_plan plan) -> (
        match S.of_plan ~day:(F.today ()) ~book:state.session.book plan with
        | Ok record -> { state with record = Some record; record_visible = true; message = "" }
        | Error why -> { state with message = why })
    | Some (W.Actual_entry _) | None ->
        { state with message = tr "Select a Scheduled occurrence to complete." }

let line ~width_of width style text = (style, O.clip_text ~width_of (max 0 width) text)

let feedback_lines ~dimensions:(width, height) ~width_of state =
  let wrap text =
    O.wrap_text ~width_of (max 1 width) text |> List.map (line ~width_of width Status)
  in
  let rows =
    (if state.message = "" then [] else wrap state.message)
    @ match state.ui_notice with None -> [] | Some notice -> wrap notice
  in
  let capacity = max 0 (height - 6) in
  if capacity = 0 then []
  else
    let rows =
      if List.length rows <= capacity then rows
      else
        List.filteri (fun i _ -> i < capacity - 1) rows
        @ [ line ~width_of width Status (tr "More feedback; enlarge the terminal.") ]
    in
    List.init (max 0 (min 1 capacity - List.length rows)) (fun _ -> (Chrome, "")) @ rows

let body_dimensions ~dimensions:((width, height) as dimensions) ~width_of state =
  (width, max 0 (height - List.length (feedback_lines ~dimensions ~width_of state) - 2))

let update_calendar state action =
  match Cal.apply state.workspace.calendar action with
  | Cal.Refused why -> { state with message = tr why }
  | Cal.Moved calendar ->
      sync
        {
          state with
          workspace = { state.workspace with calendar; pane = W.Calendar };
          scroll = 0;
          message = (if state.blocked then state.message else "");
        }
  | Cal.Open_day calendar -> open_route state (W.Selected_day calendar.selected_day)

let back state =
  if state.workspace.pane = W.Detail then
    { state with workspace = { state.workspace with pane = W.Calendar }; scroll = 0 }
  else open_route state W.Home

let open_command state = function
  | M.Record -> open_record { state with overlay = No_overlay }
  | M.Actual -> open_route state W.Actual
  | M.Scheduled -> open_route state W.Scheduled
  | M.Balances -> open_route state W.Balances
  | M.Daily_pace -> open_route state W.Daily_pace
  | M.Home -> open_route state W.Home
  | M.Theme ->
      let rec index i = function
        | [] -> 0
        | theme :: rest -> if theme = state.theme then i else index (i + 1) rest
      in
      { state with overlay = Themes { selected = index 0 P.all_themes; original = state.theme } }

let input_text value = function
  | `Key (`ASCII c, []) when Char.code c >= 32 && Char.code c <> 127 ->
      Some (value ^ String.make 1 c)
  | `Key (`Uchar c, []) when O.printable_uchar c -> Some (value ^ O.utf8 c)
  | `Key (`Backspace, []) -> Some (Daily_form.backspace value)
  | _ -> None

let handle ?(dimensions = (80, 24)) ?(width_of = String.length) state (input : input) =
  if state.paste_blocked then
    match input with
    | `Paste `End ->
        Some
          {
            state with
            paste_blocked = false;
            message =
              (if state.blocked then state.message
               else tr "Paste ignored outside Record input; no commands were run.");
          }
    | `End -> None
    | _ -> Some state
  else if input = `Paste `Start && ((not state.record_visible) || Option.is_none state.record) then
    Some { state with paste_blocked = true }
  else if state.record_visible then
    match state.record with
    | None -> Some { state with record_visible = false }
    | Some record -> (
        match
          S.handle ~book:state.session.book ~base_bytes:state.session.bytes ~blocked:state.blocked
            ~dimensions:(body_dimensions ~dimensions ~width_of state)
            ~width_of record input
        with
        | S.Updated record -> Some { state with record = Some record }
        | S.Closed record -> Some { state with record = Some record; record_visible = false }
        | S.Publish (transaction, base_bytes, record) ->
            let draft = { state with record = Some record } in
            Some
              (if state.blocked then draft
               else
                 apply_commit_result state ~draft
                   (A.commit_transaction ~session:state.session ~base_bytes transaction)))
  else
    match state.overlay with
    | Commands menu -> (
        match M.handle menu input with
        | M.Updated menu -> Some { state with overlay = Commands menu }
        | M.Closed -> Some { state with overlay = No_overlay }
        | M.Chosen action -> Some (open_command state action))
    | Themes { selected; original } -> (
        let count = List.length P.all_themes in
        match input with
        | `Key ((`Escape | `ASCII 'q'), []) ->
            Some
              { state with theme = original; overlay = Commands { M.page = M.Setup; selected = 0 } }
        | `Key ((`Arrow `Up | `Arrow `Left | `ASCII 'k'), [])
        | `Key ((`Arrow `Down | `Arrow `Right | `ASCII 'j'), []) ->
            let delta =
              match input with `Key ((`Arrow `Up | `Arrow `Left | `ASCII 'k'), []) -> -1 | _ -> 1
            in
            let selected = max 0 (min (count - 1) (selected + delta)) in
            Some
              {
                state with
                theme = List.nth P.all_themes selected;
                overlay = Themes { selected; original };
              }
        | `Key (`Enter, []) ->
            let notice =
              match P.save_theme ?config_home:state.config_home state.theme with
              | Ok () -> tr "Theme saved."
              | Error _ -> tr "Theme changed for this session only; settings could not be saved."
            in
            Some { state with overlay = No_overlay; ui_notice = Some notice }
        | _ -> Some state)
    | Jump value -> (
        match input with
        | `Key (`Escape, []) -> Some { state with overlay = No_overlay }
        | `Key (`Enter, []) ->
            Some (update_calendar { state with overlay = No_overlay } (Cal.Jump value))
        | _ ->
            Some
              (match input_text value input with
              | None -> state
              | Some value -> { state with overlay = Jump value }))
    | Search value -> (
        match input with
        | `Key (`Escape, []) ->
            Some
              (sync { state with overlay = No_overlay; workspace = W.set_query state.workspace "" })
        | `Key (`Enter, []) ->
            Some
              (sync
                 { state with overlay = No_overlay; workspace = W.set_query state.workspace value })
        | _ ->
            Some
              (match input_text value input with
              | None -> state
              | Some value -> { state with overlay = Search value }))
    | No_overlay -> (
        let key = match input with `Key (key, mods) -> Some (key, mods) | _ -> None in
        let normalize (key, mods) =
          match key with `ASCII c -> (`ASCII (Char.lowercase_ascii c), mods) | _ -> (key, mods)
        in
        match Option.map normalize key with
        | Some (`ASCII 'q', [ `Ctrl ]) -> None
        | Some (`ASCII 'r', [ `Ctrl ]) -> Some (reload state)
        | Some (`ASCII 'n', [ `Ctrl ]) -> Some (discard state)
        | Some (`ASCII ' ', []) -> Some { state with overlay = Commands M.initial }
        | Some (`Uchar c, []) when Uchar.to_int c = 32 ->
            Some { state with overlay = Commands M.initial }
        | Some ((`Escape | `ASCII 'q'), []) ->
            if state.workspace.route = W.Home && state.workspace.pane = W.Calendar then
              if fst (Option.get key) = `Escape then
                Some
                  (sync
                     {
                       state with
                       workspace =
                         {
                           state.workspace with
                           calendar =
                             {
                               state.workspace.calendar with
                               zoom =
                                 (match state.workspace.calendar.zoom with
                                 | Cal.Year -> Cal.Month
                                 | Cal.Month -> Cal.Day
                                 | Cal.Day -> Cal.Day);
                             };
                         };
                     })
              else None
            else Some (back state)
        | Some ((`Tab | `ASCII 'w'), []) | Some (`Tab, [ `Shift ]) ->
            Some
              {
                state with
                workspace =
                  {
                    state.workspace with
                    pane = (if state.workspace.pane = W.Calendar then W.Detail else W.Calendar);
                  };
                scroll = 0;
              }
        | Some (`ASCII 't', []) when state.workspace.route = W.Home ->
            Some (update_calendar state (Cal.Today (F.today ())))
        | Some (`ASCII 'z', []) when state.workspace.route = W.Home ->
            Some (update_calendar state Cal.Cycle_zoom)
        | Some (`ASCII '/', []) ->
            Some
              {
                state with
                overlay = (if state.workspace.route = W.Home then Jump "" else Search "");
              }
        | Some (`ASCII 'r', []) | Some (`ASCII 'n', []) -> Some (open_record state)
        | Some (`ASCII 'a', []) when state.workspace.route = W.Home ->
            Some (open_route state W.Actual)
        | Some (`ASCII 's', []) when state.workspace.route = W.Home ->
            Some (open_route state W.Scheduled)
        | Some (`ASCII 'b', []) when state.workspace.route = W.Home ->
            Some (open_route state W.Balances)
        | Some (`ASCII 'd', []) when state.workspace.route = W.Home ->
            Some (open_route state W.Daily_pace)
        | Some (`ASCII 's', []) when state.workspace.route = W.Actual ->
            Some (sync { state with workspace = W.cycle_order state.workspace })
        | Some (`ASCII 'f', [])
          when state.workspace.route = W.Actual || state.workspace.route = W.Scheduled ->
            Some (sync { state with workspace = W.toggle_day_filter state.workspace })
        | Some (`ASCII 'c', []) when state.workspace.route = W.Scheduled ->
            Some (pay_selected state)
        | Some (`ASCII 'c', []) | Some (`ASCII 'e', [ `Ctrl ]) -> Some (edit_selected state)
        | Some (`ASCII 'i', []) ->
            Some { state with workspace = { state.workspace with pane = W.Detail }; scroll = 0 }
        | Some (`Enter, []) ->
            if state.workspace.route = W.Home && state.workspace.pane = W.Calendar then
              Some (update_calendar state Cal.Drill)
            else if state.workspace.route = W.Home then
              match selected state with
              | None -> Some state
              | Some row -> Some (open_route state (W.Selected_day (W.date row)))
            else
              Some { state with workspace = { state.workspace with pane = W.Detail }; scroll = 0 }
        | (Some ((`ASCII 'h' | `Arrow `Left), []) | Some ((`ASCII 'l' | `Arrow `Right), []))
          when state.workspace.route = W.Home && state.workspace.pane = W.Calendar ->
            let action =
              match Option.get key with
              | (`ASCII 'h' | `Arrow `Left), _ -> Cal.Left
              | _ -> Cal.Right
            in
            Some (update_calendar state action)
        | Some ((`ASCII 'k' | `Arrow `Up), []) | Some ((`ASCII 'j' | `Arrow `Down), []) ->
            let delta =
              match Option.map normalize key with
              | Some ((`ASCII 'k' | `Arrow `Up), _) -> -1
              | _ -> 1
            in
            if state.workspace.route = W.Home && state.workspace.pane = W.Calendar then
              Some (update_calendar state (if delta < 0 then Cal.Up else Cal.Down))
            else if state.workspace.pane = W.Detail && state.workspace.route <> W.Home then
              Some { state with scroll = max 0 (state.scroll + delta) }
            else if state.workspace.route = W.Balances then
              let count =
                List.length (Option.value ~default:[] (B.approved_loci state.session.book))
                * List.length (B.measures state.session.book)
              in
              Some
                {
                  state with
                  workspace =
                    {
                      state.workspace with
                      balance_selected =
                        max 0 (min (max 0 (count - 1)) (state.workspace.balance_selected + delta));
                    };
                }
            else
              Some
                {
                  state with
                  workspace = W.move_selection ~book:state.session.book state.workspace delta;
                  scroll = 0;
                }
        | Some (`Page _, []) | Some (`ASCII ('u' | 'd'), [ `Ctrl ]) ->
            let delta =
              match Option.map normalize key with
              | Some (`Page `Up, _) | Some (`ASCII 'u', _) -> -1
              | _ -> 1
            in
            let step = delta * max 1 (snd dimensions - 8) in
            if
              state.workspace.pane = W.Calendar && state.workspace.route <> W.Home
              && state.workspace.route <> W.Balances
              && state.workspace.route <> W.Daily_pace
              || (state.workspace.route = W.Home && state.workspace.pane = W.Detail)
            then
              Some
                {
                  state with
                  workspace = W.move_selection ~book:state.session.book state.workspace step;
                  scroll = 0;
                }
            else Some { state with scroll = max 0 (state.scroll + step) }
        | Some (`Home, []) ->
            Some
              {
                state with
                scroll = 0;
                workspace = W.move_selection ~book:state.session.book state.workspace (-max_int);
              }
        | Some (`End, []) ->
            Some
              {
                state with
                scroll = max_int / 4;
                workspace = W.move_selection ~book:state.session.book state.workspace max_int;
              }
        | _ -> ( match input with `End -> None | _ -> Some state))

let frame ~width_of ~width ~height ~focused ~title ~scroll ~selected rows =
  if width < 6 || height < 2 then List.init (max 0 height) (fun _ -> (Plain, ""))
  else
    let capacity = max 0 (height - 2) in
    let last = max 0 (List.length rows - capacity) in
    let start =
      match selected with
      | None -> min last (max 0 scroll)
      | Some index -> min last (max 0 (index - capacity + 1))
    in
    let shown = rows |> List.filteri (fun i _ -> i >= start && i < start + capacity) in
    let shown =
      List.mapi
        (fun i text ->
          O.panel_line ~width ~width_of
            (match selected with
            | Some index when index = i + start -> if focused then Active else Chrome
            | _ -> Plain)
            ((match selected with Some index when index = i + start -> "> " | _ -> "  ") ^ text))
        shown
    in
    let style = if focused then Focused_frame else Frame in
    (O.panel_border ~width ~style ~width_of (tr title) :: shown)
    @ List.init
        (max 0 (capacity - List.length shown))
        (fun _ -> O.panel_line ~width ~width_of Plain "")
    @ [
        O.panel_bottom ~width ~style ~width_of
          ~title:
            (Printf.sprintf "%d–%d / %d"
               (if rows = [] then 0 else start + 1)
               (min (List.length rows) (start + capacity))
               (List.length rows))
          ();
      ]

let row_title book = function
  | W.Actual_entry entry ->
      let amount =
        match entry.B.effects with
        | [ a; b ] when D.Identifier.Measure.equal (D.Effect.measure a) (D.Effect.measure b) ->
            let positive = if Z.sign (A.quanta a) > 0 then a else b in
            let measure = A.mstr (D.Effect.measure positive) in
            let amount = B.format book measure (A.quanta positive) in
            if String.length amount > 20 then tr "see details" else amount ^ " " ^ measure
        | _ -> tr "split / see details"
      in
      entry.day ^ "  " ^ Option.value ~default:"(no description)" entry.memo ^ "  " ^ amount
  | W.Scheduled_plan plan -> plan.B.day ^ "  Scheduled  " ^ plan.id ^ "  " ^ plan.measure

let row_detail book = function
  | W.Actual_entry entry -> O.entry_lines book entry
  | W.Scheduled_plan plan -> O.plan_lines book plan

let calendar_rows state =
  let calendar = state.workspace.calendar and book = state.session.book in
  let count prefix =
    List.length
      (List.filter (fun (e : B.entry) -> String.starts_with ~prefix e.day) (B.entries book))
  in
  match calendar.Cal.zoom with
  | Cal.Day ->
      let slots = get (Cal.month_slots calendar.selected_day) in
      let rec weeks = function
        | [] -> []
        | xs ->
            let week = List.filteri (fun i _ -> i < 7) xs in
            let rest = List.filteri (fun i _ -> i >= 7) xs in
            let dates =
              List.map
                (function
                  | None -> "      "
                  | Some day ->
                      let dd = String.sub day 8 2 in
                      if day = calendar.selected_day then "[" ^ dd ^ "]  "
                      else " " ^ dd ^ if day = F.today () then "*  " else "   ")
                week
            in
            let marks =
              List.map
                (function
                  | None -> "      "
                  | Some day ->
                      let actual = count day in
                      let planned =
                        List.length
                          (List.filter (fun (p : B.plan) -> p.day = day) (B.open_plans book))
                      in
                      if actual = 0 && planned = 0 then "      "
                      else
                        let text = Printf.sprintf "A%d S%d" actual planned in
                        if String.length text > 6 then "more  "
                        else text ^ String.make (6 - String.length text) ' ')
                week
            in
            String.concat "" dates :: String.concat "" marks :: weeks rest
      in
      [ String.sub calendar.selected_day 0 7; tr " Mon   Tue   Wed   Thu   Fri   Sat   Sun" ]
      @ weeks slots
      @ [
          tr "[ ] selected; * today; A Actual; S open Scheduled";
          tr "Income / expense flow unavailable: classification not supplied.";
        ]
  | Cal.Month ->
      let year = String.sub calendar.selected_day 0 4 in
      let names =
        [| "Jan"; "Feb"; "Mar"; "Apr"; "May"; "Jun"; "Jul"; "Aug"; "Sep"; "Oct"; "Nov"; "Dec" |]
      in
      List.init 12 (fun i ->
          let prefix = Printf.sprintf "%s-%02d" year (i + 1) in
          Printf.sprintf "%s%02d %s  %d Actual"
            (if String.starts_with ~prefix calendar.selected_day then "> " else "  ")
            (i + 1) names.(i) (count prefix))
  | Cal.Year ->
      let year = int_of_string (String.sub calendar.selected_day 0 4) in
      List.init 5 (fun i -> year + i - 2)
      |> List.filter (fun y -> y >= 1 && y <= 9999)
      |> List.map (fun y ->
          let prefix = Printf.sprintf "%04d" y in
          Printf.sprintf "%s%s  %d Actual" (if y = year then "> " else "  ") prefix (count prefix))

let balances state =
  List.concat_map
    (fun locus -> List.map (fun (measure, _) -> (locus, measure)) (B.measures state.session.book))
    (Option.value ~default:[] (B.approved_loci state.session.book))

let balance_lines state =
  balances state
  |> List.map (fun (locus, measure) ->
      B.label state.session.book locus ^ " [" ^ locus ^ "]  " ^ measure ^ "  "
      ^ O.quantity ~book:state.session.book ~measure locus)

let read_config state name =
  let directory = Filename.dirname state.session.F.path in
  let candidates =
    List.filter_map Fun.id
      [
        Option.map (fun home -> Filename.concat home name) state.config_home;
        Some (Filename.concat directory name);
        Some (Filename.concat (Filename.concat directory "config") name);
      ]
  in
  let rec read = function
    | [] -> None
    | filename :: rest -> (
        if not (Sys.file_exists filename) then read rest
        else
          try Some (F.read filename) with F.Refused _ | Unix.Unix_error _ | Sys_error _ -> Some "")
  in
  read candidates

let pace_lines state =
  let today = F.today () and measure = state.workspace.measure in
  match (read_config state "daily-pace.tsv", read_config state "boundary-presets.tsv") with
  | None, _ | _, None ->
      [
        tr "Not configured.";
        tr "Supply a balance pool and exclusive period end.";
        tr "Historical Trend is unavailable.";
      ]
  | Some pool, Some windows -> (
      let tokens line = String.split_on_char '\t' line in
      let meaningful text =
        String.split_on_char '\n' text
        |> List.filter (fun line ->
            String.trim line <> "" && not (String.starts_with ~prefix:"#" (String.trim line)))
      in
      let rec coordinates acc = function
        | [] -> Ok (List.rev acc)
        | line :: rest -> (
            match tokens line with
            | [ locus; m ] when m <> measure -> coordinates acc rest
            | [ locus; m ] -> (
                match (D.Identifier.Locus.of_string locus, D.Identifier.Measure.of_string m) with
                | Ok locus, Ok measure ->
                    coordinates ({ D.Effect_coordinate.locus; measure } :: acc) rest
                | _ -> Error "Invalid Daily Pace coordinate.")
            | _ -> Error "Invalid daily-pace.tsv row; expected Locus<TAB>Measure.")
      in
      let rec find_window = function
        | [] -> Error "No boundary contains today."
        | line :: rest -> (
            let rec window = function
              | a :: b :: tail -> (
                  match (Cal.parts a, Cal.parts b) with
                  | Ok _, Ok _ when a <= today && today < b -> Ok b
                  | Ok _, Ok _ -> window (b :: tail)
                  | _ -> Error "Invalid boundary date.")
              | _ -> find_window rest
            in
            match tokens line with _preset :: dates -> window dates | [] -> find_window rest)
      in
      match (coordinates [] (meaningful pool), find_window (meaningful windows)) with
      | Error why, _ | _, Error why -> [ tr "Daily Pace unavailable:"; tr why ]
      | Ok [], _ -> [ tr "Daily Pace unavailable: no selected-Measure pool supplied." ]
      | Ok pool, Ok end_exclusive -> (
          match
            B.daily_pace state.session.book ~measure ~pool ~observed_at:today ~end_exclusive
          with
          | Error why -> [ tr "Daily Pace unavailable:"; why ]
          | Ok pace ->
              let amount n = B.format state.session.book measure n ^ " " ^ measure in
              [
                tr "Daily Pace / Current";
                "Observed: " ^ pace.observed_at;
                "End (exclusive): " ^ pace.end_exclusive;
                "Daily Pace: " ^ amount pace.daily_pace_quanta;
                "Pool: " ^ amount pace.eligible_pool;
                "Open Scheduled deductions: " ^ amount pace.automatic_deductions;
                "Through end: " ^ amount pace.available_through_end;
                "Days remaining: " ^ string_of_int pace.remaining_days;
              ]
              @ List.map
                  (fun (coordinate, n) ->
                    A.lstr coordinate.D.Effect_coordinate.locus ^ ": " ^ amount n)
                  pace.pool_balances
              @ List.map (fun (id, n) -> "Scheduled " ^ id ^ ": " ^ amount n) pace.plan_deductions
              @ [ tr "Current evidence; not a historical Trend or spending permission." ]))

let workspace_rows ~width_of ~width ~height state =
  let book = state.session.book and workspace = state.workspace in
  let rows = W.rows ~book workspace in
  let titles = List.map (row_title book) rows in
  let title =
    match workspace.W.route with
    | W.Home -> "Home / Calendar"
    | W.Selected_day day -> "Household Day Workspace / " ^ day
    | W.Actual -> "Actual"
    | W.Scheduled -> "Scheduled / List"
    | W.Balances -> "Balances / Current"
    | W.Daily_pace -> "Daily Pace"
  in
  let frame ?(width = width) ~focused ~title ~scroll ~selected rows =
    frame ~width_of ~width ~height ~focused ~title ~scroll ~selected rows
  in
  if workspace.route = W.Home && workspace.pane = W.Calendar then
    let calendar = calendar_rows state in
    let selected =
      if workspace.calendar.zoom = Cal.Day then None
      else
        Some
          (match workspace.calendar.zoom with
          | Cal.Month -> int_of_string (String.sub workspace.calendar.selected_day 5 2) - 1
          | Cal.Year -> min 2 (int_of_string (String.sub workspace.calendar.selected_day 0 4) - 1)
          | Cal.Day -> 0)
    in
    let calendar_scroll =
      if state.scroll <> 0 || workspace.calendar.zoom <> Cal.Day then state.scroll
      else
        let first = String.sub workspace.calendar.selected_day 0 8 ^ "01" in
        let index =
          (get (Cal.weekday first)
          + int_of_string (String.sub workspace.calendar.selected_day 8 2)
          - 1)
          / 7
        in
        max 0 (2 + (index * 2) - max 1 (height - 2) + 1)
    in
    if width >= 120 then
      let right = min 72 (max 50 (width * 36 / 100)) in
      let left = width - right - 1 in
      let left_rows =
        frame ~width:left ~focused:true ~title:"Calendar" ~scroll:calendar_scroll ~selected calendar
      in
      let right_rows =
        frame ~width:right ~focused:false ~title:"Detail" ~scroll:0
          ~selected:(Some (W.browser workspace).selected) titles
      in
      List.map2 (fun (style, left) (_, right) -> (style, left ^ " " ^ right)) left_rows right_rows
    else frame ~focused:true ~title:"Calendar" ~scroll:calendar_scroll ~selected calendar
  else if workspace.route = W.Balances then
    let lines = balance_lines state in
    if workspace.pane = W.Detail then
      let detail =
        match List.nth_opt (balances state) workspace.balance_selected with
        | None -> [ tr "No supplied Locus / Measure coordinates." ]
        | Some (locus, measure) ->
            [
              B.label book locus;
              "Locus: " ^ locus;
              "Measure: " ^ measure;
              "Quantity: " ^ O.quantity ~book ~measure locus;
              tr "Unknown and present-without-amount are distinct from explicit zero.";
            ]
      in
      frame ~focused:true ~title:"Selected Balance" ~scroll:state.scroll ~selected:None
        (List.concat_map (O.wrap_text ~width_of (max 1 (width - 6))) detail)
    else
      frame ~focused:true ~title ~scroll:state.scroll ~selected:(Some workspace.balance_selected)
        lines
  else if workspace.route = W.Daily_pace then
    frame ~focused:true ~title ~scroll:state.scroll ~selected:None
      (List.concat_map (O.wrap_text ~width_of (max 1 (width - 6))) (pace_lines state))
  else if workspace.pane = W.Detail && workspace.route <> W.Home then
    let detail =
      match selected state with
      | None -> [ tr "No selected record." ]
      | Some row -> row_detail book row
    in
    frame ~focused:true ~title:"Selected record" ~scroll:state.scroll ~selected:None
      (List.concat_map (O.wrap_text ~width_of (max 1 (width - 6))) detail)
  else
    frame ~focused:true
      ~title:(if workspace.route = W.Home then "Detail" else title)
      ~scroll:state.scroll ~selected:(Some (W.browser workspace).selected)
      (if titles = [] then [ tr "No records in this view." ] else titles)

let footer state =
  match (state.workspace.W.route, state.workspace.pane) with
  | W.Home, W.Calendar ->
      [
        "h/l previous/next  k/j week/quarter  z zoom  t today  / jump";
        "Tab/w Detail  r Record  a Actual  s Scheduled  b Balances  d Pace  Space Commands  q quit";
      ]
  | W.Home, W.Detail ->
      [
        "j/k select  Enter Selected Day  Tab/w/Esc/q Calendar";
        "r Record  a Actual  s Scheduled  b Balances  d Pace  Space Commands";
      ]
  | W.Scheduled, W.Calendar ->
      [
        "j/k select  Enter/i/Tab Detail  c Complete  f Focus Day / All Current-Open";
        "n Record  / search  Space Commands  q/Esc Home  Ctrl-r reload";
      ]
  | W.Actual, W.Calendar ->
      [
        "j/k select  Enter/i/Tab Detail  c Correct  f Focus Day / All Current  s order";
        "n Record  / search  Space Commands  q/Esc Home  Ctrl-r reload";
      ]
  | W.Selected_day _, W.Calendar ->
      [
        "j/k select  Enter/i/Tab Detail  c Correct  r Record";
        "Space Commands  q/Esc Home  Ctrl-r reload";
      ]
  | W.Balances, W.Calendar ->
      [ "j/k select  Enter/i/Tab Detail"; "Space Commands  q/Esc Home  Ctrl-r reload" ]
  | _, _ ->
      [
        "j/k scroll  Page Up/Down page  Home/End range"; "q/Esc back  Space Commands  Ctrl-r reload";
      ]

let screen ?(width_of = String.length) ((width, height) as dimensions) state =
  let feedback = feedback_lines ~dimensions ~width_of state in
  let usable = max 0 (height - List.length feedback) in
  if state.record_visible then
    match state.record with
    | Some record ->
        let rows = S.screen ~book:state.session.book ~dimensions:(width, usable) ~width_of record in
        let body = List.filteri (fun i _ -> i < max 0 (usable - 2)) rows in
        let help = List.filteri (fun i _ -> i >= max 0 (usable - 2)) rows in
        body @ feedback @ help
    | None -> List.init height (fun _ -> (Plain, ""))
  else
    let body_height = max 0 (height - List.length feedback - 2) in
    let headers =
      [
        line ~width_of width Heading (tr "Bakhlo Home / Calendar");
        line ~width_of width Chrome
          ("Focus: " ^ state.workspace.calendar.selected_day ^ "   View: "
          ^ Cal.title state.workspace.calendar
          ^ if has_record_draft state then "   Draft retained" else "");
      ]
    in
    let body =
      List.filteri (fun i _ -> i < body_height) headers
      @ workspace_rows ~width_of ~width ~height:(max 0 (body_height - 2)) state
    in
    body @ feedback @ List.map (line ~width_of width Chrome) (footer state)

let overlay_screen ~dimensions ~width_of state =
  let width, height = body_dimensions ~dimensions ~width_of state in
  if state.overlay = No_overlay || width < 8 || height < 3 then None
  else
    let width = min 54 (max 8 (width - 4)) in
    let title, rows, selected =
      match state.overlay with
      | Commands menu -> (M.title menu.page, List.map snd (M.items menu.page), Some menu.selected)
      | Themes { selected; _ } -> ("Theme", List.map P.theme_label P.all_themes, Some selected)
      | Jump value ->
          ("Jump to date / month / year", [ value ^ "|"; tr "Enter apply; Esc cancel" ], None)
      | Search value ->
          ("Search Actual / Scheduled", [ value ^ "|"; tr "Enter apply; Esc clear" ], None)
      | No_overlay -> ("", [], None)
    in
    let height = min height (max 5 (List.length rows + 2)) in
    Some (frame ~width_of ~width ~height ~focused:true ~title ~scroll:0 ~selected rows)

let overlay_position ~dimensions ~width_of state ~pane_width ~pane_height =
  let width, height = body_dimensions ~dimensions ~width_of state in
  (max 0 ((width - pane_width) / 2), max 0 ((height - pane_height) / 2))
