(* Synthetic conformance checks for the English workspace controller. *)
module C = Daily_interaction
module B = Bakhlo_sexp.Daily_book
module F = Daily_file
module W = Ui_workspace
module Cal = Daily_calendar
module M = Ui_commands
module S = Record_session
module P = Ui_preferences
module Att = Attention_data

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
    C.open_route home W.Calendar;
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

let bonsai_home_layout_check ~width_of home =
  let contains rows needle = List.exists
      (fun (_, text) -> Base.String.is_substring text ~substring:needle) rows in
  List.iter (fun ((width, height) as dimensions) ->
      let rows = C.screen ~width_of dimensions home in
      require (List.length rows <= height
               && List.for_all (fun (_, text) -> width_of text <= width) rows)
        "bonsai-bounded-layout";
      if height >= 9 then (
        List.iter (fun label ->
            require (contains rows label) ("bonsai-entrance-visible-" ^ label))
          [ "Record"; "Scheduled"; "Calendar"; "Actual"; "Balances"; "Daily Pace" ];
        require (contains rows "bakhlo") "bonsai-heading-bakhlo-visible");
      let tree_fits = height >= 24 && width >= 32 in
      require (contains rows "\\___________/" = tree_fits) "bonsai-pot-visible-on-fitting-height";
      require (not (contains rows "wallet") && not (contains rows "Net:"))
        "bonsai-does-not-leak-dashboard-ledger")
    [ 32, 9; 32, 11; 48, 14; 80, 24; 120, 40; 150, 45 ];
  let cal = key ~width_of home `Enter in
  require (cal.workspace.route = W.Calendar) "bonsai-enter-opens-calendar";
  let cal_g = key ~width_of home (`ASCII 'g') in
  require (cal_g.workspace.route = W.Calendar) "bonsai-g-opens-calendar";
  let rec_r = key ~width_of home (`ASCII 'r') in
  require (rec_r.record_visible && Option.is_some rec_r.record) "bonsai-r-opens-record";
  let sched = key ~width_of home (`ASCII 's') in
  require (sched.workspace.route = W.Scheduled) "bonsai-s-opens-scheduled";
  let act = key ~width_of home (`ASCII 'a') in
  require (act.workspace.route = W.Actual) "bonsai-a-opens-actual";
  let bal = key ~width_of home (`ASCII 'b') in
  require (bal.workspace.route = W.Balances) "bonsai-b-opens-balances";
  let pace = key ~width_of home (`ASCII 'd') in
  require (pace.workspace.route = W.Daily_pace) "bonsai-d-opens-daily-pace";
  let ignored_l = key ~width_of home (`ASCII 'l') in
  require (ignored_l.workspace = home.workspace) "bonsai-ignores-calendar-nav-l";
  require (C.handle home (`Key (`ASCII 'q', [])) = None) "bonsai-q-exits";
  require (C.handle home (`Key (`Escape, [])) = None) "bonsai-esc-exits";
  print_endline "PASS: responsive bonsai launcher, entrance layout, optical centering and boundary isolation."

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
      workspace = { home.workspace with route = W.Calendar; pane = W.Calendar;
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
      require (contains rows "q/Esc Home" && contains rows "Space Commands")
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
  bonsai_home_layout_check ~width_of home;
  home_layout_check ~width_of home;
  theme_check ~width_of ~directory home;
  let before = F.read path in
  require
    (home.workspace.route = W.Home && not home.record_visible)
    "english-starts-bonsai-home";
  let cal = key ~width_of home `Enter in
  require (cal.workspace.route = W.Calendar) "home-enter-opens-calendar";
  let cal_g = key ~width_of home (`ASCII 'g') in
  require (cal_g.workspace.route = W.Calendar) "home-g-opens-calendar";
  let back = key ~width_of cal (`ASCII 'q') in
  require (back.workspace.route = W.Home) "calendar-q-returns-home";
  let back_esc = key ~width_of cal `Escape in
  require (back_esc.workspace.route = W.Home) "calendar-esc-returns-home";
  let back_g = key ~width_of cal (`ASCII 'g') in
  require (back_g.workspace.route = W.Home) "calendar-g-returns-home";
  let year = key ~width_of (key ~width_of cal (`ASCII 'z')) (`ASCII 'z') in
  require (year.workspace.calendar.zoom = Cal.Year) "calendar-year-zoom";
  let month = key ~width_of year `Enter in
  let day = key ~width_of month `Enter in
  let selected = key ~width_of day `Enter in
  require
    (selected.workspace.route = W.Selected_day day.workspace.calendar.selected_day)
    "selected-day-drill";
  require ((key ~width_of selected (`ASCII 'q')).workspace.route = W.Home) "child-q-does-not-quit";
  let detail = key ~width_of cal `Tab in
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
    key ~width_of cal (`ASCII '/') |> fun s ->
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
  let contains rows needle = List.exists
      (fun (_, text) -> Base.String.is_substring text ~substring:needle) rows in
  let wide_sched = C.screen ~width_of (120, 30) scheduled in
  require (contains wide_sched "Scheduled / List" && contains wide_sched "Plan Detail")
    "scheduled-wide-two-pane-visible";
  let inspected = key ~width_of scheduled `Enter in
  require
    (inspected.workspace.pane = W.Detail && not inspected.record_visible)
    "scheduled-enter-detail-only";
  let wide_inspected = C.screen ~width_of (120, 30) inspected in
  require (contains wide_inspected "Scheduled / List" && contains wide_inspected "Plan Detail")
    "scheduled-wide-detail-focus-retains-two-pane";
  let narrow_sched_list = C.screen ~width_of (48, 14) scheduled in
  require (contains narrow_sched_list "Scheduled / List" && not (contains narrow_sched_list "Plan Detail"))
    "scheduled-narrow-shows-list-only";
  let narrow_sched_detail = C.screen ~width_of (48, 14) inspected in
  require (contains narrow_sched_detail "Plan Detail" && not (contains narrow_sched_detail "Scheduled / List"))
    "scheduled-narrow-shows-detail-only";
  let actual_view = C.open_route home W.Actual in
  let wide_actual = C.screen ~width_of (120, 30) actual_view in
  require (contains wide_actual "Actuals (" && contains wide_actual "Actual Detail")
    "actual-wide-two-pane-visible";
  let balances_view = C.open_route home W.Balances in
  let wide_balances = C.screen ~width_of (120, 30) balances_view in
  require (contains wide_balances "Balances / Current" && contains wide_balances "Selected Balance")
    "balances-wide-two-pane-visible";
  require (contains wide_balances "Measure: jpy" && contains wide_balances "Net Worth")
    "balances-role-summary-sections";
  let bal_nav = key ~width_of balances_view (`ASCII 'j') in
  let wide_nav = C.screen ~width_of (120, 30) bal_nav in
  require (contains wide_nav "Selected Balance") "balances-navigation-retains-pane";
  let roles_path = directory ^ "/accounting-roles.tsv" in
  F.write_new roles_path "ROLE\twallet\tASSET\nROLE\tbank\tASSET\nROLE\tfood\tEXPENSE\n";
  let bal_with_roles = C.open_route { home with session = F.load path } W.Balances in
  let wide_with_roles = C.screen ~width_of (120, 30) bal_with_roles in
  require (contains wide_with_roles "Asset" && contains wide_with_roles "Expense")
    "balances-explicit-roles-displayed";
  let pace_view = C.open_route home W.Daily_pace in
  let wide_pace = C.screen ~width_of (120, 30) pace_view in
  require (contains wide_pace "Daily Pace" && contains wide_pace "Pace Detail & Evidence")
    "daily-pace-wide-two-pane-visible";
  let pace_path = directory ^ "/daily-pace.tsv" in
  let windows_path = directory ^ "/boundary-presets.tsv" in
  F.write_new pace_path "wallet\tjpy\n";
  F.write_new windows_path "month\t2026-10-01\t2026-11-01\n";
  let pace_configured = C.open_route { home with session = F.load path } W.Daily_pace in
  let wide_pace_conf = C.screen ~width_of (120, 30) pace_configured in
  require (contains wide_pace_conf "Period progress:" && contains wide_pace_conf "Through end:")
    "daily-pace-progress-and-metrics-visible";
  let completion = key ~width_of inspected (`ASCII 'c') in
  require completion.record_visible "scheduled-completion-explicit";
  let _ = C.discard completion in
  let plan_creating = key ~width_of scheduled (`ASCII 'n') in
  require (plan_creating.record_visible && Option.is_some plan_creating.record)
    "scheduled-key-n-opens-plan";
  require (S.mode (Option.get plan_creating.record) = Daily_actions.Plan_new)
    "scheduled-n-mode-plan-new";
  let plan_with_input = key ~width_of (key ~width_of plan_creating `Tab) `Tab in
  let plan_with_input = text ~width_of plan_with_input "wallet" in
  let closed_plan = key ~width_of plan_with_input `Escape in
  require ((not closed_plan.record_visible) && C.has_record_draft closed_plan)
    "scheduled-plan-draft-retained";
  let refused_e = key ~width_of closed_plan (`ASCII 'e') in
  require (refused_e.message <> "" && not refused_e.record_visible)
    "draft-retained-blocks-edit";
  let refused_c = key ~width_of closed_plan (`ASCII 'c') in
  require (refused_c.message <> "" && not refused_c.record_visible)
    "draft-retained-blocks-pay";
  let cleared = C.discard closed_plan in
  require (not (C.has_record_draft cleared)) "scheduled-draft-discarded";
  let plan_editing = key ~width_of cleared (`ASCII 'e') in
  require (plan_editing.record_visible && Option.is_some plan_editing.record)
    "scheduled-key-e-opens-edit";
  (match S.mode (Option.get plan_editing.record) with
   | Daily_actions.Plan_edit _ -> ()
   | _ -> failwith "scheduled-e-mode-plan-edit");
  let closed_edit = C.discard (key ~width_of plan_editing `Escape) in
  let plan_cancelling = key ~width_of closed_edit (`ASCII 'x') in
  require
    (C.is_cancel_plan plan_cancelling.overlay)
    "scheduled-key-x-opens-cancel-overlay";
  let cancelled_overlay = key ~width_of plan_cancelling `Escape in
  require (cancelled_overlay.overlay = C.No_overlay) "scheduled-cancel-overlay-escaped";
  let draft = prepare_record ~width_of cal in
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
  let actual_screen = C.open_route published W.Actual in
  let actual_editing = key ~width_of actual_screen (`ASCII 'c') in
  require (actual_editing.record_visible && Option.is_some actual_editing.record)
    "actual-key-c-opens-edit";
  (match S.mode (Option.get actual_editing.record) with
   | Daily_actions.Edit _ -> ()
   | _ -> failwith "actual-c-mode-edit");
  let closed_actual_edit = C.discard (key ~width_of actual_editing `Escape) in
  let actual_reversing = key ~width_of closed_actual_edit (`ASCII 'x') in
  require
    (C.is_reverse_entry actual_reversing.overlay)
    "actual-key-x-opens-reverse-overlay";
  let reversed = key ~width_of actual_reversing `Enter in
  require (not (C.has_record_draft reversed)) "reversed-draft-clean";
  let cold_after_reverse = F.load path in
  let entries_after_reverse = B.entries cold_after_reverse.book in
  require (List.length entries_after_reverse = 2) "reversal-entry-published";
  let rev_entry = List.find (fun (e : B.entry) -> e.reversal_of <> None) entries_after_reverse in
  let orig_entry = List.find (fun (e : B.entry) -> e.reversal_of = None) entries_after_reverse in
  require (rev_entry.reversal_of = Some orig_entry.id) "reversal-links-to-original";
  let actual_after = C.open_route { reversed with session = cold_after_reverse } W.Actual in
  let try_double_reverse = key ~width_of actual_after (`ASCII 'x') in
  require (try_double_reverse.overlay = C.No_overlay && try_double_reverse.message <> "")
    "double-reversal-blocked";
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
  let cancel_ledger_path = directory ^ "/cancel_plan.sexp" in
  F.write_new cancel_ledger_path (F.read path);
  let cancel_session = F.load cancel_ledger_path in
  let cancel_ctl = C.initial cancel_session |> fun s -> C.open_route s W.Scheduled in
  let cancel_modal = key ~width_of cancel_ctl (`ASCII 'x') in
  require (C.is_cancel_plan cancel_modal.overlay)
    "cancel-plan-modal-opened";
  let cancel_done = key ~width_of cancel_modal `Enter in
  require (cancel_done.overlay = C.No_overlay) "cancel-plan-committed";
  let cancelled_cold = F.load cancel_ledger_path in
  let p = List.hd (B.plans cancelled_cold.book) in
  require (p.cancelled_on <> None) "plan-cold-cancelled-on-set";
  let re_cancel = key ~width_of cancel_done (`ASCII 'x') in
  require (re_cancel.overlay = C.No_overlay && re_cancel.message <> "")
    "already-cancelled-cancel-refused";
  let re_edit = key ~width_of cancel_done (`ASCII 'e') in
  require ((not re_edit.record_visible) && re_edit.message <> "")
    "already-cancelled-edit-refused";
  let re_pay = key ~width_of cancel_done (`ASCII 'c') in
  require ((not re_pay.record_visible) && re_pay.message <> "")
    "already-cancelled-pay-refused";
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
  let form =
    Ui_form.create
      ~id:"test_form"
      ~title:"Test Modal Form"
      ~summary:["Line 1 summary"; "Line 2 summary"]
      ~fields:[
        Ui_form.text_field ~id:"memo" ~label:"Memo" ~value:"initial" ();
        Ui_form.choice_field ~id:"category" ~label:"Category" ~options:["Food"; "Transport"; "Other"] ~selected:0 ();
        Ui_form.action_buttons ~confirm:"Save" ~cancel:"Discard" ();
      ]
      ()
  in
  require (Ui_form.id form = "test_form") "form-id";
  require (Ui_form.title form = "Test Modal Form") "form-title";
  require (Ui_form.focused form = 0) "form-initial-focus-0";
  require (Ui_form.get_text form "memo" = Some "initial") "form-get-text";
  require (Ui_form.get_choice form "category" = Some 0) "form-get-choice";
  require (Ui_form.get_choice_value form "category" = Some "Food") "form-get-choice-value";
  let f_tab1 = match Ui_form.handle_input form (`Key (`Tab, [])) with Ui_form.Updated f -> f | _ -> failwith "tab1" in
  require (Ui_form.focused f_tab1 = 1) "form-tab-to-1";
  let f_tab2 = match Ui_form.handle_input f_tab1 (`Key (`Tab, [])) with Ui_form.Updated f -> f | _ -> failwith "tab2" in
  require (Ui_form.focused f_tab2 = 2) "form-tab-to-2";
  let f_tab3 = match Ui_form.handle_input f_tab2 (`Key (`Tab, [])) with Ui_form.Updated f -> f | _ -> failwith "tab3" in
  require (Ui_form.focused f_tab3 = 0) "form-tab-wrap-to-0";
  let f_stab = match Ui_form.handle_input f_tab3 (`Key (`Tab, [ `Shift ])) with Ui_form.Updated f -> f | _ -> failwith "stab" in
  require (Ui_form.focused f_stab = 2) "form-shift-tab-to-2";
  let f_typed = match Ui_form.handle_input form (`Key (`ASCII '!', [])) with Ui_form.Updated f -> f | _ -> failwith "typed" in
  require (Ui_form.get_text f_typed "memo" = Some "initial!") "form-text-appended";
  let f_bs = match Ui_form.handle_input f_typed (`Key (`Backspace, [])) with Ui_form.Updated f -> f | _ -> failwith "bs" in
  require (Ui_form.get_text f_bs "memo" = Some "initial") "form-text-backspace";
  let f_enter1 = match Ui_form.handle_input form (`Key (`Enter, [])) with Ui_form.Updated f -> f | _ -> failwith "enter1" in
  require (Ui_form.focused f_enter1 = 1) "form-enter-advances-focus";
  let f_ch_next = match Ui_form.handle_input f_enter1 (`Key ((`Arrow `Right), [])) with Ui_form.Updated f -> f | _ -> failwith "ch_next" in
  require (Ui_form.get_choice f_ch_next "category" = Some 1) "form-choice-next";
  require (Ui_form.get_choice_value f_ch_next "category" = Some "Transport") "form-choice-value-transport";
  let f_submitted = match Ui_form.handle_input f_ch_next (`Key (`Enter, [])) with Ui_form.Submit f -> f | _ -> failwith "submit" in
  require (Ui_form.id f_submitted = "test_form") "form-submitted-id";
  let f_on_btn = Ui_form.set_focused form 2 in
  let f_btn_right = match Ui_form.handle_input f_on_btn (`Key ((`Arrow `Right), [])) with Ui_form.Updated f -> f | _ -> failwith "btn_right" in
  require (Ui_form.get_button f_btn_right "action" = Some 1) "form-button-toggle-to-cancel";
  let f_cancelled = match Ui_form.handle_input f_btn_right (`Key (`Enter, [])) with Ui_form.Cancel -> true | _ -> false in
  require f_cancelled "form-enter-on-cancel-button";
  let esc_cancelled = match Ui_form.handle_input form (`Key (`Escape, [])) with Ui_form.Cancel -> true | _ -> false in
  require esc_cancelled "form-escape-cancels";
  let rows = Ui_form.render_rows form in
  require (List.length rows > 3) "form-render-rows-count";
  require (List.mem "Line 1 summary" rows) "form-render-summary";
  (* Attention workflow verification *)
  let att_state = key ~width_of home (`ASCII 'i') in
  require (att_state.workspace.route = W.Attention) "home-i-opens-attention";
  let modal_add = key ~width_of att_state (`ASCII 'n') in
  require (C.is_add_attention modal_add.overlay) "attention-n-opens-add-form";
  let form_with_text =
    match modal_add.overlay with
    | C.Modal_form f ->
        let f2 = Ui_form.set_text f "context" "Buy groceries" in
        let f3 = Ui_form.set_choice f2 "due_kind" 0 in
        let f4 = Ui_form.set_focused f3 3 in
        { modal_add with overlay = C.Modal_form f4 }
    | _ -> failwith "expected modal form"
  in
  let added_state = key ~width_of form_with_text `Enter in
  require (added_state.overlay = C.No_overlay) "attention-add-submitted";
  let open_items = C.open_attentions added_state in
  require (List.length open_items = 1) "attention-item-added";
  let item = List.hd open_items in
  require (item.Att.context = "Buy groceries") "attention-item-context";
  require (item.Att.due = Att.No_due_date) "attention-item-due";
  let modal_resolve = key ~width_of added_state (`ASCII 'r') in
  require (C.is_resolve_attention modal_resolve.overlay) "attention-r-opens-resolve-form";
  let resolved_state = key ~width_of modal_resolve `Enter in
  require (resolved_state.overlay = C.No_overlay) "attention-resolve-submitted";
  require (List.length (C.open_attentions resolved_state) = 0) "attention-item-resolved";
  let back_home = key ~width_of resolved_state (`ASCII 'q') in
  require (back_home.workspace.route = W.Home) "attention-q-back-to-home";
  print_endline
    "PASS: English Calendar / Commands / Record / child navigation / exact cold save and safety \
     guards.";
  home
