(* Synthetic conformance checks for the English workspace controller. *)
module C = Daily_interaction
module B = Bakhlo_sexp.Daily_book
module F = Daily_file
module W = Ui_workspace
module Cal = Daily_calendar
module M = Ui_commands
module S = Record_session
module P = Ui_preferences

let require = F.require
let get = function Ok value -> value | Error cause -> raise (F.Refused cause)

let key ?(dimensions = (140, 40)) ?(width_of = String.length) state button =
  match C.handle ~dimensions ~width_of state (`Key (button, [])) with
  | Some state -> state
  | None -> raise (F.Refused "unexpected-controller-exit")

let text ~width_of state value =
  Uutf.String.fold_utf_8
    (fun state _ -> function
      | `Uchar char -> key ~width_of state (`Uchar char)
      | `Malformed _ -> raise (F.Refused "malformed-test-input"))
    state value

let prepare_record ~width_of state =
  let state = key ~width_of state (`ASCII 'r') in
  let state = text ~width_of state "English UI / 日本語のメモ" in
  let state = key ~width_of (key ~width_of state `Tab) `Tab in
  let state = key ~width_of (text ~width_of state "wallet") `Enter in
  let state = key ~width_of (text ~width_of state "-37") `Tab in
  let state = key ~width_of (text ~width_of state "food") `Enter in
  text ~width_of state "+37"

let render_cases state =
  let home =
    { state with C.overlay = C.No_overlay; record = None; record_visible = false; message = "" }
  in
  let record = C.open_record home in
  let record =
    match record.record with
    | None -> record
    | Some draft ->
        {
          record with
          record =
            Some
              (S.with_notice draft
                 "Record notice: long text remains separate from household feedback.");
        }
  in
  let review = prepare_record ~width_of:String.length home |> C.submit in
  let entry =
    get
      (Result.map_error
         (fun error -> error.Daily_actions.message)
         (Daily_actions.build_transaction ~book:home.session.book ~mode:Daily_actions.New
            (Daily_actions.Multiple
               {
                 day = home.workspace.calendar.selected_day;
                 memo = "Synthetic / 日本語";
                 draft =
                   {
                     Posting_draft.measure = "jpy";
                     rows =
                       [
                         {
                           Posting_draft.key = None;
                           locus = "wallet";
                           negative = true;
                           amount = String.make 70 '9';
                         };
                         {
                           Posting_draft.key = None;
                           locus = "food";
                           negative = false;
                           amount = String.make 70 '9';
                         };
                       ];
                   };
               })))
  in
  let book = get (B.put_entry home.session.book ~replace:false entry.entry ~plan:None) in
  let rich = { home with session = { home.session with book } } in
  let detail route =
    let view = C.open_route rich route in
    { view with workspace = { view.workspace with pane = W.Detail } }
  in
  [
    home;
    key home `Tab;
    C.open_route home W.Actual;
    C.open_route home W.Scheduled;
    C.open_route home W.Balances;
    C.open_route home W.Daily_pace;
    record;
    review;
    detail (W.Selected_day home.workspace.calendar.selected_day);
    detail W.Actual;
    detail W.Scheduled;
    detail W.Balances;
    { home with overlay = C.Commands M.initial };
    { home with overlay = C.Commands { M.page = M.Analysis; selected = 1 } };
    { home with overlay = C.Themes { selected = 0; original = home.theme; return_menu = M.initial } };
    { home with overlay = C.Jump "2026-10" };
    { home with overlay = C.Search "財布" };
  ]

let home_layout_check ~width_of home =
  let module D = Bakhlo_domain in
  let day = "2026-10-18" in
  let posting locus quanta = D.Effect.create ~key:None
      ~locus:(C.get_id (D.Identifier.Locus.of_string locus))
      ~measure:(C.get_id (D.Identifier.Measure.of_string "jpy"))
      ~quantity:(D.Quantity.of_quanta (Z.of_int quanta)) in
  let entry : B.entry =
    { id = "home-layout-entry"; day; memo = Some "選択日の買い物";
      effects = [ posting "wallet" (-37); posting "food" 37 ];
      reversal_of = None; exchange = None } in
  let book = get (B.put_entry home.C.session.book ~replace:false entry ~plan:None) in
  let plan : B.plan =
    { id = "home-layout-plan"; day; measure = "jpy";
      changes = [ "wallet", Z.of_int (-200); "food", Z.of_int 200 ];
      paid_by = None; cancelled_on = None } in
  let book = get (B.put_plan book ~replace:false plan) in
  let state = { home with C.session = { home.session with book };
      workspace = { home.workspace with route = W.Home; pane = W.Calendar;
                    calendar = get (Cal.create day) }; scroll = 0; message = "" } in
  let contains rows needle = List.exists
      (fun (_, text) -> Base.String.is_substring text ~substring:needle) rows in
  List.iter (fun ((width, height) as dimensions) ->
      let rows = C.screen ~width_of dimensions state in
      require (List.length rows <= height
               && List.for_all (fun (_, text) -> width_of text <= width) rows)
        "home-polish-bounded-layout";
      require (contains rows "Calendar / 2026-10" && contains rows "Detail / 2026-10-18")
        "home-selected-day-detail-nearby";
      require (contains rows "Actual 1   Open Scheduled 1" && contains rows "選択日の買い物")
        "home-day-counts-and-japanese-record-visible";
      require (contains rows "Flow unavailable") "home-does-not-invent-money-flow";
      if width >= 120 then (
        let border_rows = List.filter (fun (_, text) -> String.starts_with ~prefix:"╭" text) rows in
        require (List.length border_rows = 1) "home-wide-two-pane-composition";
        let last_frame = List.fold_left (fun last (index, (_, text)) ->
            if String.starts_with ~prefix:"╰" text then index else last) 0
            (List.mapi (fun index row -> index, row) rows) in
        require (last_frame < 20) "home-calendar-not-empty-full-height"))
    [ 80, 24; 90, 24; 120, 40; 140, 40 ];
  List.iter (fun ((width, height) as dimensions) ->
      let rows = C.screen ~width_of dimensions state in
      require (contains rows "[18]") "home-tiny-selected-sunday-visible";
      require (List.length rows <= height
               && List.for_all (fun (_, text) -> width_of text <= width) rows)
        "home-tiny-calendar-cell-width";
      let focused = { state with workspace = { state.workspace with pane = W.Detail } } in
      let rows = C.screen ~width_of dimensions focused in
      require (contains rows "Detail / ") "home-small-focused-detail-visible")
    [ 32, 9; 48, 14 ];
  let month = { state with workspace = { state.workspace with
      calendar = { state.workspace.calendar with zoom = Cal.Month } } } in
  let year = { state with workspace = { state.workspace with
      calendar = { state.workspace.calendar with zoom = Cal.Year } } } in
  List.iter (fun state ->
      let rows = C.screen ~width_of (80, 24) state in
      require (contains rows "Detail / ") "home-period-detail-visible-at-80-columns";
      require (contains rows "q quit" && contains rows "Space Commands")
        "home-primary-footer-not-clipped") [ state; month; year ];
  require (B.entry_count home.session.book = 0) "home-polish-mutated-original-book";
  print_endline "PASS: responsive Home context, compact calendar, tiny Sunday selection, exact period counts and restrained frame height."

let theme_check ~width_of ~directory home =
  let path = home.C.session.path in
  let before = F.read path in
  require (home.theme = P.Terminal) "theme-default-follows-terminal";
  let retained = C.open_record home in
  let base = { retained with C.record_visible = false; blocked = true;
                            message = "household-warning" } in
  let unchanged state =
    require
      (state.C.session == base.session && state.workspace = base.workspace
       && state.record = base.record && not state.record_visible
       && state.blocked && state.message = base.message && F.read path = before)
      "theme-change-preserves-household-context-draft-and-warning"
  in
  let choose index =
    let setup = { base with C.overlay = C.Commands { M.page = M.Setup; selected = 0 } } in
    let picker = key ~width_of setup `Enter in
    require (C.footer picker = [ "j/k or Up/Down preview theme"; "Enter save  Esc/q cancel" ])
      "theme-picker-contextual-operations";
    List.fold_left (fun state _ -> key ~width_of state (`Arrow `Down)) picker
      (List.init index Fun.id)
  in
  List.iteri
    (fun index theme ->
      require (P.theme_of_id (P.theme_id theme) = Some theme) "theme-id-roundtrip";
      let saved_before = P.load_theme ~config_home:directory () in
      let preview = choose index in
      require (preview.theme = theme && P.load_theme ~config_home:directory () = saved_before)
        "theme-preview-is-not-saved";
      unchanged preview;
      List.iter (fun button ->
          let cancelled = key ~width_of preview button in
          require (cancelled.theme = base.theme
                   && P.load_theme ~config_home:directory () = saved_before)
            "theme-cancel-restores-original-without-save";
          unchanged cancelled) [ `Escape; `ASCII 'q' ];
      let saved = key ~width_of preview `Enter in
      require (saved.theme = theme && saved.overlay = C.No_overlay
               && saved.ui_notice = Some "Theme saved.") "theme-enter-saves";
      require ((C.initial ~config_home:directory (F.load path)).theme = theme)
        "theme-cold-reopen";
      unchanged saved)
    P.all_themes;
  let root = { base with C.overlay = C.Commands { M.page = M.Root; selected = 4 } } in
  let root_picker = key ~width_of root `Enter in
  require (match root_picker.overlay with C.Themes _ -> true | _ -> false)
    "root-command-palette-opens-theme-directly";
  let cancelled = key ~width_of (key ~width_of root_picker (`Arrow `Down)) `Escape in
  require (cancelled.overlay = root.overlay && cancelled.theme = base.theme)
    "theme-cancel-restores-exact-command-menu";
  unchanged cancelled;
  let preview = choose 1 in
  let failed = key ~width_of { preview with C.config_home = Some path } `Enter in
  require (failed.theme = P.Bakhlo_light && failed.overlay = C.No_overlay
           && failed.ui_notice = Some
                "Theme changed for this session only; settings could not be saved.")
    "theme-save-failure-keeps-session-choice-and-reports-limit";
  unchanged failed;
  let settings = Filename.concat directory "ui-theme" in
  List.iter (fun contents ->
      let channel = open_out_bin settings in
      Fun.protect ~finally:(fun () -> close_out_noerr channel)
        (fun () -> output_string channel contents);
      require (P.load_theme ~config_home:directory () = P.Terminal)
        "invalid-theme-falls-back-to-terminal")
    [ "unknown\n"; "bakhlo-light\nbakhlo-dark\n"; String.make 33 'x' ];
  get (P.save_theme ~config_home:directory P.Terminal);
  print_endline "PASS: terminal/original theme preview, cancel, cold settings and isolated save failure."

let self_check ~width_of () =
  let directory = "scratch/english-ui-check-" ^ F.new_id () in
  Unix.mkdir directory 0o700;
  let path = directory ^ "/book.sexp" in
  F.create_copy ~source:"examples/daily-book.sexp" ~target:path;
  let home = C.initial ~config_home:directory (F.load path) in
  home_layout_check ~width_of home;
  theme_check ~width_of ~directory home;
  let before = F.read path in
  require
    (home.workspace.route = W.Home && home.workspace.pane = W.Calendar && not home.record_visible)
    "english-starts-calendar";
  let year = key ~width_of (key ~width_of home (`ASCII 'z')) (`ASCII 'z') in
  require (year.workspace.calendar.zoom = Cal.Year) "calendar-year-zoom";
  let month = key ~width_of year `Enter in
  let day = key ~width_of month `Enter in
  let selected = key ~width_of day `Enter in
  require
    (selected.workspace.route = W.Selected_day day.workspace.calendar.selected_day)
    "selected-day-drill";
  require ((key ~width_of selected (`ASCII 'q')).workspace.route = W.Home) "child-q-does-not-quit";
  let detail = key ~width_of home `Tab in
  require ((key ~width_of detail (`ASCII 'q')).workspace.pane = W.Calendar) "home-detail-q-back";
  require (C.handle home (`Key (`ASCII 'q', [])) = None) "calendar-q-exits";
  let outside_paste =
    match C.handle home (`Paste `Start) with
    | Some state -> state
    | None -> raise (F.Refused "paste-start-exited")
  in
  let outside_paste = key ~width_of (key ~width_of outside_paste (`ASCII 'r')) (`ASCII 'j') in
  let outside_paste =
    match C.handle outside_paste (`Paste `End) with
    | Some state -> state
    | None -> raise (F.Refused "paste-end-exited")
  in
  require
    (outside_paste.workspace = home.workspace
    && (not outside_paste.record_visible)
    && (not (C.has_record_draft outside_paste))
    && F.read path = before)
    "paste-executed-home-commands";
  let jump =
    key ~width_of home (`ASCII '/') |> fun s ->
    text ~width_of s "2024-2" |> fun s -> key ~width_of s `Enter
  in
  require
    (jump.workspace.calendar.selected_day = "2024-02-01" && jump.workspace.calendar.zoom = Cal.Month)
    "jump-month";
  let invalid =
    key ~width_of jump (`ASCII '/') |> fun s ->
    text ~width_of s "2024-02-30" |> fun s -> key ~width_of s `Enter
  in
  require (invalid.workspace.calendar = jump.workspace.calendar) "invalid-jump-mutated-date";
  require (get (Cal.shift_months "2024-01-31" 1) = "2024-02-29") "calendar-month-clamp";
  require (get (Cal.shift_years "2024-02-29" 1) = "2025-02-28") "calendar-year-clamp";
  require
    (get (Cal.weekday "0001-01-01") = 0 && get (Cal.weekday "2026-10-11") = 6)
    "calendar-weekday";
  require
    (Result.is_error (Cal.shift_days "0001-01-01" (-1))
    && Result.is_error (Cal.shift_days "9999-12-31" 1))
    "calendar-boundary";
  let menu =
    key ~width_of home (`ASCII ' ') |> fun s ->
    key ~width_of s (`Arrow `Down) |> fun s -> key ~width_of s (`Arrow `Right)
  in
  require
    (match menu.overlay with C.Commands { page = M.Planning; _ } -> true | _ -> false)
    "commands-enter-group";
  let leaf = key ~width_of menu (`Arrow `Right) in
  require (leaf.overlay = menu.overlay && leaf.workspace = menu.workspace) "right-leaf-no-action";
  let parent = key ~width_of leaf `Escape in
  require
    (match parent.overlay with C.Commands { page = M.Root; selected = 1 } -> true | _ -> false)
    "commands-parent-selection";
  let scheduled = key ~width_of menu `Enter in
  require (scheduled.workspace.route = W.Scheduled) "commands-scheduled-route";
  let inspected = key ~width_of scheduled `Enter in
  require
    (inspected.workspace.pane = W.Detail && not inspected.record_visible)
    "scheduled-enter-detail-only";
  let completion = key ~width_of inspected (`ASCII 'c') in
  require completion.record_visible "scheduled-completion-explicit";
  let draft = prepare_record ~width_of home in
  require (C.has_record_draft draft) "controller-record-draft";
  let review = key ~width_of draft `Enter in
  require (F.read path = before) "preview-published";
  let edit = key ~width_of (key ~width_of review `Tab) `Enter in
  require (C.has_record_draft edit && F.read path = before) "preview-edit-lost-draft";
  let cancelled = key ~width_of edit `Escape in
  require ((not cancelled.record_visible) && C.has_record_draft cancelled) "cancel-lost-held-draft";
  let navigated = key ~width_of cancelled (`ASCII 'l') in
  require (C.has_record_draft navigated) "calendar-navigation-lost-draft";
  let resumed = key ~width_of navigated (`ASCII 'r') in
  let review = key ~width_of resumed `Enter in
  let tiny = key ~dimensions:(24, 8) ~width_of review `Enter in
  require (tiny.record_visible && F.read path = before) "tiny-publish-bypassed-review";
  let published = key ~width_of review `Enter in
  require
    ((not (C.has_record_draft published)) && not published.record_visible)
    "published-draft-not-cleared";
  let cold = F.load path in
  let entries = B.entries cold.book in
  require
    (List.length entries = 1 && (List.hd entries).memo = Some "English UI / 日本語のメモ")
    "english-record-cold-roundtrip";
  require
    (Daily_overlays.quantity ~book:cold.book ~measure:"jpy" "wallet" = "963")
    "english-record-exact-balance";
  require
    (Daily_overlays.quantity ~book:cold.book ~measure:"jpy" "bank" = "Unknown")
    "unknown-not-zero";
  let records_path = directory ^ "/records.sexp" in
  F.write_new records_path (B.to_records_string home.session.book);
  let records = F.load records_path in
  let records_before = F.read records_path in
  let publication_state () =
    ( Option.map Bakhlo_sexp.Durable_append.current_lsn records.engine,
      Option.map
        (fun client ->
          ( client.Bakhlo_sexp.Durable_append.last_acknowledged_token,
            client.Bakhlo_sexp.Durable_append.last_acknowledged_lsn ))
        records.session )
  in
  let publication_before = publication_state () in
  let plan = List.hd (B.open_plans records.book) in
  let payment =
    get
      (Result.map_error
         (fun error -> error.Daily_actions.message)
         (Daily_actions.build_transaction ~book:records.book ~mode:(Daily_actions.Pay plan.id)
            (Daily_actions.Multiple
               {
                 day = F.today ();
                 memo = "Records refusal / 合成";
                 draft =
                   {
                     Posting_draft.measure = "jpy";
                     rows =
                       [
                         {
                           Posting_draft.key = None;
                           locus = "wallet";
                           negative = true;
                           amount = "200";
                         };
                         {
                           Posting_draft.key = None;
                           locus = "food";
                           negative = false;
                           amount = "200";
                         };
                       ];
                   };
               })))
  in
  (match Daily_actions.commit_transaction ~session:records ~base_bytes:records.bytes payment with
  | Daily_actions.Refused _ -> ()
  | _ -> raise (F.Refused "records-payment-was-partially-published"));
  (match
     Daily_actions.commit_transaction ~session:records ~base_bytes:records.bytes
       { payment with plan = None; replace = true }
   with
  | Daily_actions.Refused _ -> ()
  | _ -> raise (F.Refused "records-replacement-not-refused"));
  let records_cold = F.load records_path in
  require
    (F.read records_path = records_before
    && B.entry_count records_cold.book = 0
    && (List.hd (B.plans records_cold.book)).paid_by = None)
    "records-refusal-changed-bytes-or-link";
  require (publication_state () = publication_before) "records-refusal-changed-lsn-or-ack";
  (match
     Daily_actions.commit_transaction ~session:records ~base_bytes:records.bytes
       { payment with plan = None; replace = false }
   with
  | Daily_actions.Published _ -> ()
  | _ -> raise (F.Refused "ordinary-records-append-refused"));
  let appended = F.load records_path in
  require
    (B.entry_count appended.book = 1
    && (List.hd (B.plans appended.book)).paid_by = None
    && Daily_overlays.quantity ~book:appended.book ~measure:"jpy" "wallet" = "800")
    "ordinary-records-append-cold-roundtrip";
  let stopped = { home with blocked = true; message = "household-warning" } in
  require (C.submit stopped == stopped) "blocked-submit-identity";
  let moved = key ~width_of stopped (`ASCII 'l') in
  require (moved.blocked && moved.message = stopped.message) "navigation-hid-stop";
  List.iter
    (fun dimensions ->
      List.iter
        (fun state ->
          let rows = C.screen ~width_of dimensions state in
          require
            (List.length rows <= snd dimensions
            && List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows)
            "controller-terminal-cell-geometry")
        (review :: render_cases home))
    [ (48, 14); (80, 24); (140, 40); (20, 5) ];
  print_endline
    "PASS: English Calendar / Commands / Record / child navigation / exact cold save and safety \
     guards.";
  home
