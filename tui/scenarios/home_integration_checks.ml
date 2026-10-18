(* Synthetic controller integration checks; see docs/RECONSTRUCTION_TEST_MAP.ja.md. *)
open Interaction_check_fixture

let bonsai_home_layout_check ~width_of home =
  let contains rows needle = List.exists
      (fun (_, text) -> Base.String.is_substring text ~substring:needle) rows in
  List.iter (fun ((width, height) as dimensions) ->
      let rows = R.screen ~width_of dimensions home in
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
      require (List.exists (fun (style, _) -> style = C.Bonsai) rows = tree_fits) "bonsai-foliage-style-matches-fit";
      if height >= 9 then
        require (List.exists (fun (style, _) -> style = C.Entrance) rows) "bonsai-entrance-style-present";
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
  require (H.handle home (`Key (`ASCII 'q', [])) = None) "bonsai-q-exits";
  require (H.handle home (`Key (`Escape, [])) = None) "bonsai-esc-exits";
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
      reversal_of = None; exchange = None; original_amount = None; merchant = None } in
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
      let rows = R.screen ~width_of dimensions state in
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
      let rows = R.screen ~width_of dimensions state in
      require (contains rows "[18]") "home-tiny-selected-sunday-visible";
      require (List.length rows <= height
               && List.for_all (fun (_, text) -> width_of text <= width) rows)
        "home-tiny-calendar-cell-width";
      let focused = { state with workspace = { state.workspace with pane = W.Detail } } in
      let rows = R.screen ~width_of dimensions focused in
      require (contains rows "Detail / ") "home-small-focused-detail-visible")
    [ 32, 9; 48, 14 ];
  let month = { state with workspace = { state.workspace with
      calendar = { state.workspace.calendar with zoom = Cal.Month } } } in
  let year = { state with workspace = { state.workspace with
      calendar = { state.workspace.calendar with zoom = Cal.Year } } } in
  List.iter (fun state ->
      let rows = R.screen ~width_of (80, 24) state in
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
    require (R.footer picker = [ "j/k or Up/Down preview theme"; "Enter save  Esc/q cancel" ])
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
      require (saved.theme = theme && no_modal saved
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
  require (failed.theme = P.Bakhlo_light && no_modal failed
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

