(* Synthetic conformance checks for the English workspace controller. *)
module C = Daily_interaction
module B = Bakhlo_sexp.Daily_book
module F = Daily_file
module W = Ui_workspace
module Cal = Daily_calendar
module M = Ui_commands
module S = Record_session
module Rev = Reversal_session
module P = Ui_preferences
module Att = Attention_data
module Roles = Locus_roles
module D = Bakhlo_domain
module Stl = Settlement_data

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
  let reversal = C.reverse_entry_selected (C.open_route rich W.Actual) in
  let reversal_preview = key reversal `Enter in
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
    reversal;
    reversal_preview;
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

let safety_checks ~width_of ~directory () =
  let dir = directory ^ "/safety" in
  Unix.mkdir dir 0o700;
  let path = dir ^ "/book.sexp" in
  F.create_copy ~source:"examples/daily-book.sexp" ~target:path;
  let home = C.initial ~config_home:dir (F.load path) in
  let contains rows needle = List.exists (fun (_, text) -> Base.String.is_substring text ~substring:needle) rows in
  let failed state = match state.C.overlay with C.Modal_form f -> Ui_form.notice f <> "" | _ -> false in
  List.iter (fun raw -> require (Result.is_error (Att.of_string raw)) "attention-invalid-input-refused")
    [ "unknown-row\n"; "LOAM-ATTENTION-MEMORY\t2\n";
      "ITEM\ta\tDUE_ON\t2026-02-30\tbad date\n";
      "ITEM\ta\tDUE_ON\t2026/10/14\tnoncanonical date\n";
      "ITEM\ta\tNO_DUE_DATE\t-\tbad\\x\n";
      "ITEM\ta\tNO_DUE_DATE\t-\tfirst\nITEM\ta\tNO_DUE_DATE\t-\tduplicate\n";
      "CLOSE\tmissing\t2026-10-14\tRESOLVED\n" ];
  let att = get (Att.add_item Att.empty ~id:"attention-2" ~context:"合成\\text\nnext"
    ~due:Att.Due_undetermined) in
  require (get (Att.of_string (Att.to_string att)) = att) "attention-escape-round-trip";
  require (Att.next_id att <> "attention-2") "attention-id-does-not-collide";
  let att_path = Att.file_path ~config_home:dir path in
  get (Att.save_file att_path ~expected:Att.empty att);
  require (Result.is_error (Att.save_file att_path ~expected:Att.empty Att.empty)) "attention-stale-write-refused";
  let att_bytes = F.read att_path in
  let state = C.initial ~config_home:dir (F.load path) in
  Unix.mkdir (att_path ^ ".lock.block") 0o700;
  Unix.unlink (att_path ^ ".lock");
  Unix.rename (att_path ^ ".lock.block") (att_path ^ ".lock");
  let form = C.add_attention_form ~today:(F.today ()) |> fun f -> Ui_form.set_text f "context" "Retain me" in
  let ready = { state with C.overlay = C.Modal_form (Ui_form.set_focused form 3) } in
  let refused = key ~width_of ready `Enter in
  require (failed refused && refused.attention = state.attention) "attention-save-failure-preserves-state";
  (match refused.overlay with C.Modal_form f -> require (Ui_form.get_text f "context" = Some "Retain me")
      "attention-save-failure-preserves-draft" | _ -> require false "attention-draft-lost");
  require (F.read att_path = att_bytes) "attention-save-failure-preserves-file";
  Unix.rmdir (att_path ^ ".lock");
  Unix.unlink att_path;
  F.write_new att_path "broken\n";
  let broken = C.initial ~config_home:dir (F.load path) in
  require (Result.is_error broken.attention) "attention-load-failure-is-not-empty";
  require (contains (C.screen ~width_of (120, 30) (C.open_route broken W.Attention)) "Unavailable")
    "attention-load-failure-visible";
  require (failed (key ~width_of { broken with overlay = ready.overlay } `Enter)) "attention-invalid-load-blocks-save";
  require (F.read att_path = "broken\n") "attention-invalid-bytes-preserved";
  Unix.unlink att_path;
  Unix.mkdir att_path 0o700;
  require (Result.is_error (Att.load_file att_path)) "attention-nonregular-read-refused";
  Unix.rmdir att_path;
  Unix.symlink (dir ^ "/missing-target") att_path;
  require (Att.file_path ~config_home:dir path = att_path && Result.is_error (Att.load_file att_path))
    "attention-dangling-link-refuses-without-fallback";
  Unix.unlink att_path;
  get (Att.save_file att_path ~expected:Att.empty att);
  require ((C.reload broken).attention = Ok att) "explicit-reload-refreshes-sidecar";
  List.iter (fun raw -> require (Result.is_error (Stl.of_string raw)) "settlement-invalid-input-refused")
    [ "broken\n"; "id\t\ta\tb\tjpy\tbad\t0\t0\n";
      "id\t\ta\tb\tjpy\t10\t11\t0\n"; "id\t\ta\tb\tjpy\t10\t-1\t0\n";
      "id\t\ta\tb\tjpy\t10\t0\t0\nid\t\ta\tb\tjpy\t10\t0\t0\n" ];
  let stl_path = Stl.file_path ~config_home:dir path in
  F.write_new stl_path "id\t\ta\tb\tjpy\tbad\t0\t0\n";
  let broken = C.initial ~config_home:dir (F.load path) in
  require (Result.is_error broken.settlements) "settlement-load-failure-is-not-zero";
  require (contains (C.screen ~width_of (120, 30) (C.open_route broken W.Settlements)) "Unavailable")
    "settlement-load-failure-visible";
  require (Result.is_error (Stl.save_file stl_path ~expected:Stl.empty Stl.empty)) "settlement-corruption-blocks-save";
  let stl_bytes = F.read stl_path in
  let form = C.add_settlement_form home in
  let form = Ui_form.set_text form "debtor" "a" |> fun f -> Ui_form.set_text f "creditor" "b"
    |> fun f -> Ui_form.set_text f "amount" "10" |> fun f -> Ui_form.set_focused f 5 in
  require (failed (key ~width_of { broken with overlay = C.Modal_form form } `Enter)) "settlement-corruption-ui-refuses";
  require (F.read stl_path = stl_bytes) "settlement-corruption-preserved";
  Unix.unlink stl_path;
  Unix.mkdir (stl_path ^ ".lock.block") 0o700;
  Unix.unlink (stl_path ^ ".lock");
  Unix.rename (stl_path ^ ".lock.block") (stl_path ^ ".lock");
  let refused = key ~width_of { home with overlay = C.Modal_form form } `Enter in
  require (failed refused && refused.settlements = home.settlements) "settlement-save-failure-preserves-state";
  require (not (Sys.file_exists stl_path)) "settlement-save-failure-no-file";
  Unix.rmdir (stl_path ^ ".lock");
  let huge = Z.pow (Z.of_int 10) 70 in
  let commitments = get (Stl.add_row Stl.empty ~id:"huge" ~label:"合成のみ"
    ~debtor:"a" ~creditor:"b" ~measure:"jpy" ~committed:huge ()) in
  get (Stl.save_file stl_path ~expected:Stl.empty commitments);
  require (get (Stl.load_file stl_path) = commitments) "settlement-exact-huge-cold-round-trip";
  require (Result.is_error (Stl.save_file stl_path ~expected:Stl.empty Stl.empty)) "settlement-stale-write-refused";
  require (get (Stl.load_file stl_path) = commitments) "settlement-stale-write-preserves-evidence";
  require (Result.is_error (C.resolve_pace_pool home)) "missing-pool-is-not-inferred";
  require (Result.is_error (C.resolve_pace_window home)) "missing-window-is-not-month-end";
  let pool_path = dir ^ "/daily-pace.tsv" and windows_path = dir ^ "/boundary-presets.tsv" in
  let replace path bytes = if Sys.file_exists path then Unix.unlink path; F.write_new path bytes in
  List.iter (fun raw -> replace pool_path raw;
    require (Result.is_error (C.resolve_pace_pool home)) "pool-rejects-bad-duplicate-or-mixed-rows")
    ["wallet\tjpy\nbad\n"; "wallet\tjpy\nwallet\tjpy\n"; "wallet\tjpy\nbank\teur\n"];
  replace pool_path "wallet\tjpy\n";
  let today = F.today () and stop = get (Cal.shift_days (F.today ()) 7) in
  let window = "cycle\t" ^ today ^ "\t" ^ stop ^ "\n" in
  List.iter (fun raw -> replace windows_path raw;
    require (Result.is_error (C.resolve_pace_window home)) "window-rejects-malformed-or-ambiguous-presets")
    [window ^ "other\t" ^ today ^ "\t" ^ stop ^ "\n";
     window ^ "old\t2026-02-30\t2026-03-01\n";
     window ^ "old\t1900/01/01\t1901/01/01\n";
     "cycle\t" ^ stop ^ "\t" ^ today ^ "\n"];
  let boundaries = "old\t1900-01-01\t1901-01-01\n" ^ window in
  replace windows_path boundaries;
  let pace, _, _ = get (C.current_pace_result home) in
  let amount = Z.add pace.B.available_through_end Z.one in
  let form = C.what_if_form home |> fun f -> Ui_form.set_text f "amount" (Z.to_string amount)
    |> fun f -> Ui_form.set_focused f 1 in
  let simulated = key ~width_of { home with overlay = C.Modal_form form } `Enter in
  require (match simulated.overlay with C.Modal_form f ->
    Base.String.is_substring (Ui_form.notice f) ~substring:"Simulated pace: -1 jpy/day" | _ -> false)
    "negative-what-if-uses-floor-division-without-clamping";
  let form = C.configure_pace_form home |> fun f -> Ui_form.set_text f "pool_loci" "wallet, bank"
    |> fun f -> Ui_form.set_focused f 1 in
  let saved = key ~width_of { home with overlay = C.Modal_form form } `Enter in
  require (saved.overlay = C.No_overlay && F.read windows_path = boundaries) "pool-save-preserves-all-presets";
  let stale = C.configure_pace_form home |> fun f -> Ui_form.set_focused f 1 in
  replace pool_path "bank\tjpy\n";
  require (failed (key ~width_of { home with overlay = C.Modal_form stale } `Enter)) "stale-pool-editor-refused";
  require (F.read pool_path = "bank\tjpy\n" && F.read windows_path = boundaries) "stale-config-preserved";
  Unix.unlink windows_path;
  let form = C.configure_pace_form home |> fun f -> Ui_form.set_focused f 1 in
  let saved = key ~width_of { home with overlay = C.Modal_form form } `Enter in
  require (saved.overlay = C.No_overlay && not (Sys.file_exists windows_path)) "pool-save-does-not-invent-period";
  print_endline "PASS: sidecar refusal/draft preservation, strict inputs, explicit Pace, negative What-if and non-destructive Pool edits."

let panel_checks ~width_of () =
  let module Panel = Ui_panel in
  require (Panel.capacity ~height:8 ~heading:false=6
    && Panel.capacity ~height:8 ~heading:true=5
    && Panel.capacity ~height:3 ~heading:true=1
    && Panel.capacity ~height:min_int ~heading:true=0) "panel-data-capacity";
  List.iter (fun last -> List.iter (fun position -> List.iter (fun delta ->
    let moved = Panel.move ~last ~position delta in
    require (moved>=0 && moved<=max 0 last) "panel-motion-bounded")
    [min_int;-1;0;1;max_int]) [min_int;0;1;max_int]) [min_int;0;1;max_int];
  require (Panel.move ~last:max_int ~position:max_int max_int=max_int
    && Panel.move ~last:max_int ~position:max_int min_int=0
    && Panel.move ~last:10 ~position:max_int (-1)=9) "panel-motion-clamps-before-stepping";
  let view = Panel.window ~capacity:3 ~count:10 ~scroll:max_int ~selected:(Some 8) in
  require (view.capacity=3 && view.start=6 && view.last=7) "panel-selection-follows-window";
  let ended = Panel.window ~capacity:3 ~count:10 ~scroll:max_int ~selected:None in
  require (ended.start=7 && Panel.move ~last:ended.last ~position:ended.start (-1)=6)
    "panel-scroll-bottom-and-immediate-up";
  let empty = Panel.window ~capacity:0 ~count:0 ~scroll:max_int ~selected:(Some max_int) in
  require (empty.start=0 && empty.last=0) "panel-empty-zero-capacity";
  let huge = Panel.window ~capacity:max_int ~count:max_int ~scroll:max_int ~selected:(Some max_int) in
  require (huge.start=0 && huge.last=0) "panel-window-machine-boundary";
  let content = List.init 10 (fun n -> Printf.sprintf "row-%02d 日本語" n) in
  let contains rows needle = List.exists (fun (_,line)->Base.String.is_substring line ~substring:needle) rows in
  let render focused = Panel.frame ~heading:"Columns" ~width_of ~width:32 ~height:6
    ~focused ~title:"Panel" ~scroll:0 ~selected:(Some 9) content in
  let active = render true and inactive = render false in
  require (contains active "row-07" && contains active "row-09"
    && not (contains active "row-06") && contains active "8–10 / 10") "panel-paint-uses-same-window";
  require (List.exists (fun (style,line)->style=Daily_overlays.Active
    && Base.String.is_substring line ~substring:"row-09") active
    && not (List.exists (fun (style,_)->style=Daily_overlays.Active) inactive)
    && List.map snd active=List.map snd inactive) "panel-focus-not-selection";
  List.iter (fun (width,height) -> List.iter (fun selected ->
    let rows = Panel.frame ~heading:"Columns" ~width_of ~width ~height ~focused:true
      ~title:"Panel" ~scroll:max_int ~selected content in
    require (List.length rows=max 0 height && List.for_all (fun (_,line)->width_of line<=width) rows)
      "panel-bounded-render") [None;Some 0;Some 9;Some max_int])
    [0,0;1,1;6,2;8,3;18,4;32,9;48,14;80,24];
  require (not (contains (Panel.frame ~heading:"Columns" ~width_of ~width:32 ~height:3
    ~focused:true ~title:"Panel" ~scroll:0 ~selected:(Some 0) content) "Columns"))
    "panel-low-height-keeps-data-not-heading";
  print_endline "PASS: independent shared panel capacity/window, integer-safe motion, focus/selection and bounded Unicode painting."

let scheduled_panel_checks ~width_of ~directory home =
  let huge = Z.of_string (String.make 600 '9') in
  let plan n : B.plan = {id=Printf.sprintf "panel-plan-%02d-%s" n (String.make 180 'p');
    day=Printf.sprintf "2026-10-%02d" (n+1); measure="jpy";
    changes=["wallet", Z.neg huge; "food", huge]; paid_by=None; cancelled_on=None} in
  let book = List.fold_left (fun book n -> get (B.put_plan book ~replace:false (plan n)))
    home.C.session.book (List.init 20 Fun.id) in
  let path = directory ^ "/scheduled-panels.sexp" in
  F.write_new path (B.to_string book);
  let before = F.read path in
  let state = C.open_route (C.initial ~config_home:directory (F.load path)) W.Scheduled in
  let count = List.length (W.rows ~book state.workspace) in
  List.iter (fun dimensions ->
    let key = key ~dimensions ~width_of in
    let detail = key state `Enter in
    let height, view = C.browser_viewport ~dimensions ~width_of detail in
    let identity = (W.browser detail.workspace).selected_id in
    require (view.last>0) "scheduled-long-detail-overflows";
    let ended = key detail `End in
    require (ended.scroll=view.last && (W.browser ended.workspace).selected_id=identity)
      "scheduled-detail-end-preserves-identity";
    require ((key ended (`ASCII 'j')).scroll=view.last
      && (key ended (`ASCII 'k')).scroll=view.last-1
      && (key ended `Home).scroll=0) "scheduled-detail-endpoints-and-immediate-up";
    require ((key detail (`Page `Down)).scroll=min view.last (max 1 view.capacity))
      "scheduled-detail-page-visible-rows";
    let ctrl_down = get (match C.handle ~dimensions ~width_of detail (`Key (`ASCII 'd',[`Ctrl])) with
      | Some state -> Ok state | None -> Error "scheduled-ctrl-page-exited") in
    require (ctrl_down.scroll=(key detail (`Page `Down)).scroll) "scheduled-ctrl-page-same-capacity";
    let listed = key ended `Tab in
    let restored = key listed `Tab in
    require (listed.workspace.pane=W.Calendar && restored.workspace.pane=W.Detail
      && restored.scroll=ended.scroll && (W.browser restored.workspace).selected_id=identity)
      "scheduled-focus-roundtrip-retains-detail-and-selection";
    require ((key detail (`ASCII 'h')).workspace.pane=W.Calendar
      && (key (key detail (`ASCII 'h')) (`ASCII 'l')).workspace.pane=W.Detail)
      "scheduled-browser-horizontal-focus";
    let back = key ended `Escape in
    require (back.workspace.pane=W.Calendar && (W.browser back.workspace).selected_id=identity)
      "scheduled-back-keeps-selection";
    require ((key ended (`ASCII 'f')).scroll=0) "scheduled-filter-resets-detail";
    let reloaded = get (match C.handle ~dimensions ~width_of ended (`Key (`ASCII 'r',[`Ctrl])) with
      | Some state -> Ok state | None -> Error "scheduled-reload-exited") in
    require (reloaded.scroll=0 && (W.browser reloaded.workspace).selected_id=identity)
      "scheduled-reload-anchors-identity-and-resets-detail";
    let page = key state (`Page `Down) in
    require ((W.browser page.workspace).selected=min (count-1) (max 1 (height-2)))
      "scheduled-list-page-excludes-borders-no-heading";
    require ((W.browser (key state `End).workspace).selected=count-1
      && (W.browser (key (key state `End) `Home).workspace).selected=0) "scheduled-list-real-endpoints";
    List.iter (fun state ->
      let rows = C.screen ~width_of dimensions state in
      require (List.length rows<=snd dimensions && List.for_all (fun (_,line)->width_of line<=fst dimensions) rows)
        "scheduled-shared-panels-bounded") [state;page;ended]) [32,9;48,14;80,24;120,36];
  let small = key ~dimensions:(32,9) ~width_of state `Enter |> fun s -> key ~dimensions:(32,9) ~width_of s `End in
  let resized = key ~dimensions:(120,36) ~width_of small (`ASCII '!') in
  let _, view = C.browser_viewport ~dimensions:(120,36) ~width_of resized in
  require (resized.scroll=view.last && (W.browser resized.workspace).selected_id=(W.browser small.workspace).selected_id)
    "scheduled-resize-clamps-offset-not-identity";
  let editing = key ~width_of state (`ASCII 'e') in
  let draft = text ~width_of editing "q 日本語" in
  let closed = key ~width_of draft `Escape in
  require (closed.workspace=state.workspace && C.has_record_draft closed && not closed.record_visible)
    "scheduled-edit-cancel-retains-draft-and-parent";
  let resumed = C.open_command closed M.Record in
  require (S.screen ~book ~dimensions:(72,20) ~width_of (Option.get draft.record)
    = S.screen ~book ~dimensions:(72,20) ~width_of (Option.get resumed.record))
    "scheduled-draft-resumed-through-existing-record-command";
  let cancelled = key ~width_of (key ~width_of state (`ASCII 'x')) `Escape in
  require (cancelled.workspace=state.workspace && cancelled.overlay=C.No_overlay)
    "scheduled-cancel-overlay-return-context";
  require (F.read path=before) "scheduled-shared-panels-no-write";
  print_endline "PASS: Scheduled uses shared viewport, clamped detail/list paging, focus/resize, retained draft and cancelled action context (synthetic)."

let actual_browsing_checks ~width_of ~directory home =
  let posting ?(measure="jpy") locus quanta = D.Effect.create ~key:None
    ~locus:(C.get_id (D.Identifier.Locus.of_string locus))
    ~measure:(C.get_id (D.Identifier.Measure.of_string measure))
    ~quantity:(D.Quantity.of_quanta quanta) in
  let huge = Z.of_string (String.make 70 '9') in
  let entry n : B.entry =
    { id = Printf.sprintf "actual-%02d" n; day = Printf.sprintf "2026-10-%02d" (n+1);
      memo = Some (if n=17 then String.concat " " (List.init 80 (fun _ -> "日本語の長い説明"))
        else Printf.sprintf "Synthetic purchase %02d" n);
      effects = [posting "wallet" (Z.neg (if n=17 then huge else Z.of_int (1234+n)));
        posting "food" (if n=17 then huge else Z.of_int (1234+n))];
      reversal_of = None; exchange = None } in
  let book = List.fold_left (fun book n -> get (B.put_entry book ~replace:false (entry n) ~plan:None))
    home.C.session.book (List.init 18 Fun.id) in
  let path = directory ^ "/actual-browsing.sexp" in
  F.write_new path (B.to_string book);
  let before = F.read path in
  let state = C.open_route (C.initial ~config_home:directory (F.load path)) W.Actual in
  let contains rows needle = List.exists (fun (_, line) -> Base.String.is_substring line ~substring:needle) rows in
  require (C.actual_amount book (entry 0) = "+1,234 jpy") "actual-grouped-exact-amount";
  let euro = { (entry 0) with effects = [posting ~measure:"eur" "food" (Z.of_int 123456)] } in
  require (C.actual_amount book euro = "+1,234.56 eur") "actual-grouping-retains-decimals";
  require (C.actual_amount book {euro with effects=[posting ~measure:"eur" "food" (Z.of_int (-123456))]}
    = "-1,234.56 eur") "actual-negative-amount-sign";
  require (C.actual_amount book {euro with effects=[]} = "—") "actual-missing-effects-not-zero";
  require (C.actual_amount book {euro with effects=[posting "food" Z.zero]} = "0 jpy") "actual-explicit-zero";
  require (C.actual_amount book {euro with effects=[posting "wallet" (Z.of_int (-3));
    posting "food" Z.one; posting "bank" (Z.of_int 2)]} = "split") "actual-split-not-invented-total";
  require (C.actual_amount book {euro with effects=posting "food" Z.one :: euro.effects} = "multi (2)")
    "actual-mixed-measures-not-summed";
  let heading, titles = C.actual_table ~width_of ~width:58 book [W.Actual_entry (entry 0); W.Actual_entry (entry 17)] in
  require (Base.String.is_substring heading ~substring:"Amount"
    && Base.String.is_substring (List.hd titles) ~substring:"+1,234 jpy"
    && Base.String.is_substring (List.nth titles 1) ~substring:"see details"
    && Base.String.is_substring (List.nth titles 1) ~substring:"…"
    && List.for_all (fun line -> width_of line=52) titles) "actual-fixed-columns-safe-ellipsis";
  List.iter (fun dimensions ->
    let key = key ~dimensions ~width_of in
    let detail = key state `Enter in
    let height, view = C.browser_viewport ~dimensions ~width_of detail in
    let capacity = view.Ui_panel.capacity and last = view.last in
    let identity = (W.browser detail.workspace).selected_id in
    let ended = key detail `End in
    require (ended.scroll=last && (W.browser ended.workspace).selected_id=identity)
      "actual-detail-end-does-not-reselect";
    require ((key ended (`ASCII 'j')).scroll=last && (key ended (`ASCII 'k')).scroll=max 0 (last-1))
      "actual-detail-bottom-is-clamped-and-up-is-immediate";
    require ((key ended `Home).scroll=0 && (W.browser (key ended `Home).workspace).selected_id=identity)
      "actual-detail-home-does-not-reselect";
    require ((key detail (`Page `Down)).scroll=min last (max 1 capacity)) "actual-detail-page-visible-capacity";
    let listed = key ended `Escape in
    require (listed.workspace.pane=W.Calendar && (W.browser listed.workspace).selected_id=identity)
      "actual-back-retains-selection";
    let page = key state (`Page `Down) in
    require ((W.browser page.workspace).selected=min 17 (max 1 (height-2-(if height>=4 then 1 else 0))))
      "actual-list-page-excludes-borders-and-heading";
    let last_row = key state `End in
    require ((W.browser last_row.workspace).selected=17 && last_row.scroll=0) "actual-list-end-real-last";
    List.iter (fun state ->
      let rows = C.screen ~width_of dimensions state in
      require (List.length rows<=snd dimensions && List.for_all (fun (_,line)->width_of line<=fst dimensions) rows)
        "actual-bounded-layout";
      if snd dimensions>=14 && state.workspace.pane=W.Detail then
        require (contains rows "ID: actual-17") "actual-long-detail-complete-id-at-end") [state;page;ended])
    [32,9;48,14;80,24;120,36];
  let detail = key ~dimensions:(32,9) ~width_of state `Enter |> fun s -> key ~dimensions:(32,9) ~width_of s `End in
  let resized = key ~dimensions:(120,36) ~width_of detail (`ASCII '!') in
  let _, resized_view = C.browser_viewport ~dimensions:(120,36) ~width_of resized in
  require (resized.scroll=resized_view.Ui_panel.last && (W.browser resized.workspace).selected_id=(W.browser detail.workspace).selected_id)
    "actual-resize-clamps-without-reselection";
  let searched = key ~width_of state (`ASCII '/') |> fun s -> text ~width_of s "purchase 03" in
  require (List.length (W.rows ~book searched.workspace)=1 && (W.browser searched.workspace).query="purchase 03")
    "actual-search-filters-while-typing";
  let kept = key ~width_of searched `Enter in
  require ((W.browser kept.workspace).query="purchase 03") "actual-search-enter-keeps";
  let cleared = key ~width_of (key ~width_of kept (`ASCII '/')) `Escape in
  require ((W.browser cleared.workspace).query="" && List.length (W.rows ~book cleared.workspace)=18)
    "actual-search-escape-clears";
  let parent = key ~width_of state (`ASCII 'j') in
  let draft = prepare_record ~width_of parent in
  let draft_rows = S.screen ~book ~dimensions:(72,20) ~width_of (Option.get draft.record) in
  let closed = key ~width_of draft `Escape in
  require (closed.workspace=parent.workspace && C.has_record_draft closed && not closed.record_visible)
    "actual-record-cancel-retains-parent-and-draft";
  let resumed = key ~width_of closed (`ASCII 'n') in
  require (resumed.record_visible && S.screen ~book ~dimensions:(72,20) ~width_of (Option.get resumed.record)=draft_rows)
    "actual-record-resumes-exact-draft";
  require (F.read path=before) "actual-browsing-and-draft-did-not-write";
  print_endline "PASS: Actual exact aligned summaries, live search, clamped detail/list paging, tiny resize, stable selection and retained Record drafts (synthetic)."

let reversal_checks ~width_of ~directory home =
  let directory = directory ^ "/reversal" in
  Unix.mkdir directory 0o700;
  let effect locus quantity = D.Effect.create
    ~key:(Some (C.get_id (D.Identifier.Effect_key.of_string ("reverse-" ^ locus))))
    ~locus:(C.get_id (D.Identifier.Locus.of_string locus))
    ~measure:(C.get_id (D.Identifier.Measure.of_string "jpy"))
    ~quantity:(D.Quantity.of_quanta (Z.of_int quantity)) in
  let target : B.entry = { id = "reverse-target"; day = "2026-10-10";
    memo = Some "Original / 日本語"; effects = [effect "wallet" (-37); effect "food" 37];
    reversal_of = None; exchange = None } in
  let book = get (B.put_entry home.C.session.book ~replace:false target ~plan:None) in
  let path = directory ^ "/book.sexp" in
  F.write_new path (B.to_string book);
  F.write_new (directory ^ "/input.sexp") (B.to_string book);
  let base = C.initial ~config_home:directory (F.load path) |> fun s -> C.open_route s W.Actual in
  let before = F.read path in
  let names () = Sys.readdir directory |> Array.to_list |> List.sort String.compare in
  let before_names = names () in
  let unchanged label = require (F.read path = before && names () = before_names) label in
  let editor state = match state.C.overlay with
    | C.Reversal editor -> editor | _ -> raise (F.Refused "reversal-editor-lost") in
  let input state event = match C.handle ~width_of state event with
    | Some s -> s | None -> raise (F.Refused "reversal-exited-controller") in
  let date state value =
    let state = List.fold_left (fun s _ -> key ~width_of s `Backspace) state
      (List.init (String.length (Rev.day (editor state))) Fun.id) in
    text ~width_of state value in
  let opened = key ~width_of base (`ASCII 'x') in
  let entered = date opened "2026/10/09" in
  let invalid = key ~width_of (date opened "2026-02-30") `Enter in
  require (not (Rev.is_preview (editor invalid)) && Rev.day (editor invalid) = "2026-02-30")
    "reversal-invalid-date-retained";
  let review = key ~width_of entered `Enter in
  require (Rev.is_preview (editor review) && Rev.day (editor review) = "2026-10-09")
    "reversal-date-enters-canonical-preview";
  let ctrl_review = input entered (`Key (`Enter, [ `Ctrl ])) in
  require (Rev.is_preview (editor ctrl_review)) "reversal-ctrl-enter-only-previews-date";
  let same_review state = Rev.is_preview (editor state)
    && Rev.day (editor state) = Rev.day (editor review)
    && Rev.base_bytes (editor state) = Rev.base_bytes (editor review)
    && C.overlay_screen ~dimensions:(80,24) ~width_of state
       = C.overlay_screen ~dimensions:(80,24) ~width_of review in
  require (same_review (input review (`Key (`Enter, [ `Ctrl ]))))
    "reversal-ctrl-enter-does-not-publish";
  let body = Option.get (C.overlay_screen ~dimensions:(80,24) ~width_of review) in
  let contains needle = List.exists (fun (_, text) -> Base.String.is_substring text ~substring:needle) body in
  List.iter (fun s -> require (contains s) ("reversal-review-missing-" ^ s))
    ["reverse-target"; "2026-10-10"; "2026-10-09"; "日本語"; "Original postings";
      "Inverse postings"; "wallet  -37 jpy"; "wallet  +37 jpy"; "food  +37 jpy"; "food  -37 jpy"];
  require (C.cursor_position ~width_of (80,24) opened <> None
           && C.cursor_position ~width_of (80,24) review = None)
    "reversal-date-caret-only";
  List.iter (fun dimensions ->
    let date_view = Option.get (C.overlay_screen ~dimensions ~width_of opened) in
    let preview = Option.get (C.overlay_screen ~dimensions ~width_of review) in
    List.iter (fun rows -> require
      (List.length rows <= snd dimensions
       && List.for_all (fun (_, s) -> width_of s <= fst dimensions) rows)
      "reversal-surface-cell-bounds") [date_view; preview])
    [(80,24); (120,36); (48,14); (32,9)];
  List.iter (fun dimensions ->
    let refused = key ~dimensions ~width_of review `Enter in
    require (Rev.is_preview (editor refused)) "reversal-tiny-publish-refused") [(48,14); (32,9)];
  let editing = key ~width_of review `Escape in
  require (not (Rev.is_preview (editor editing)) && Rev.day (editor editing) = "2026-10-09")
    "reversal-preview-escape-retains-date";
  let edit_action = key ~width_of (key ~width_of review `Tab) `Enter in
  require (not (Rev.is_preview (editor edit_action))) "reversal-selected-edit";
  List.iter (fun cancelled ->
    require (cancelled.C.overlay = C.No_overlay && cancelled.workspace = opened.workspace
             && cancelled.scroll = opened.scroll) "reversal-cancel-retains-parent")
    [key ~width_of opened `Escape; key ~width_of review (`ASCII 'q');
      key ~width_of (key ~width_of (key ~width_of review `Tab) `Tab) `Enter];
  let day_view = C.open_route base (W.Selected_day target.day) in
  let day_cancel = key ~width_of (key ~width_of day_view (`ASCII 'x')) `Escape in
  require (day_cancel.workspace = day_view.workspace) "reversal-selected-day-parent-retained";
  let held = prepare_record ~width_of base |> fun s -> key ~width_of s `Escape in
  let guarded = key ~width_of held (`ASCII 'x') in
  require (guarded.overlay = C.No_overlay && guarded.record = held.record && C.has_record_draft guarded)
    "reversal-does-not-destroy-retained-record-draft";
  let paste = input review (`Paste `Start) in
  let paste = input paste (`Key (`Enter, [])) |> fun s -> input s (`Key (`ASCII 'q', [])) in
  let paste = input paste (`Paste `End) in
  require (same_review paste) "reversal-paste-cannot-confirm-or-cancel";
  unchanged "reversal-input-review-cancel-refusal-do-not-write-or-allocate-artifacts";
  let missing = { review with session = { review.session with path = directory ^ "/missing/book.sexp" } } in
  let failed = key ~width_of missing `Enter in
  require (C.is_reverse_entry failed.overlay && not (Rev.is_preview (editor failed))
           && Rev.day (editor failed) = "2026-10-09"
           && Rev.base_bytes (editor failed) = before && failed.message <> "")
    "reversal-storage-refusal-keeps-date-target-and-base";
  unchanged "reversal-failed-storage-keeps-original";
  let records_path = directory ^ "/records.sexp" in
  F.write_new records_path (B.to_records_string book);
  let records = C.initial ~config_home:directory (F.load records_path) |> fun s -> C.open_route s W.Actual in
  let records_bytes = F.read records_path in
  let records_refused = key ~width_of (key ~width_of (key ~width_of records (`ASCII 'x')) `Enter) `Enter in
  require (C.is_reverse_entry records_refused.overlay && not (Rev.is_preview (editor records_refused))
           && F.read records_path = records_bytes
           && Bakhlo_sexp.Durable_append.current_lsn (Option.get records.session.engine)
              = Bakhlo_sexp.Durable_append.current_lsn (Option.get records_refused.session.engine))
    "reversal-records-refusal-keeps-draft-and-lsn";
  let large = Z.of_string (String.make 225 '9' ^ "03") in
  let eur_effect locus n = D.Effect.create ~key:None
    ~locus:(C.get_id (D.Identifier.Locus.of_string locus))
    ~measure:(C.get_id (D.Identifier.Measure.of_string "eur")) ~quantity:(D.Quantity.of_quanta n) in
  let long_target = { target with memo = Some (String.concat "" (List.init 100 (fun _ -> "長い日本語")));
    effects = [eur_effect "wallet" (Z.neg large); eur_effect "food" large] } in
  F.write_new (directory ^ "/large-input.sexp")
    (B.to_string (get (B.put_entry home.session.book ~replace:false long_target ~plan:None)));
  let long = Rev.create ~book ~base_bytes:before ~day:"2026-10-09" long_target in
  let long = match Rev.handle ~blocked:false ~dimensions:(80,24) ~width_of long (`Key (`Enter, [])) with
    | Rev.Updated t -> t | _ -> raise (F.Refused "reversal-long-date-preview") in
  let rows = Rev.screen ~dimensions:(160,100) ~width_of long in
  List.iter (fun (locus, n) ->
    let s = locus ^ "  " ^ (if Z.sign n > 0 then "+" else "") ^ B.format book "eur" n ^ " eur" in
    List.iter (fun piece -> require
      (List.exists (fun (_, s) -> Base.String.is_substring s ~substring:piece) rows)
      "reversal-huge-exact-decimal-is-wrapped-not-clipped") (Daily_overlays.wrap_text ~width_of 154 s))
    ["wallet", Z.neg large; "food", large; "wallet", large; "food", Z.neg large];
  (match Rev.handle ~blocked:false ~dimensions:(80,24) ~width_of long (`Key (`Enter, [])) with
   | Rev.Updated _ -> () | _ -> raise (F.Refused "reversal-unreviewed-end-published"));
  let ended = match Rev.handle ~blocked:false ~dimensions:(80,24) ~width_of long (`Key (`End, [])) with
    | Rev.Updated t -> t | _ -> raise (F.Refused "reversal-end") in
  (match Rev.handle ~blocked:false ~dimensions:(80,24) ~width_of ended (`Key (`Enter, [])) with
   | Rev.Publish (id, day, bytes) -> require (id = target.id && day = "2026-10-09" && bytes = before)
       "reversal-fixed-intent" | _ -> raise (F.Refused "reversal-reviewed-end-not-publishable"));
  let compact = match Rev.handle ~blocked:false ~dimensions:(48,14) ~width_of ended (`Key (`End, [])) with
    | Rev.Updated t -> t | _ -> raise (F.Refused "reversal-compact-end") in
  (match Rev.handle ~blocked:false ~dimensions:(48,14) ~width_of compact (`Key (`Enter, [])) with
   | Rev.Updated _ -> () | _ -> raise (F.Refused "reversal-compact-end-bypassed-gate"));
  let changed_target = { target with memo = Some "Concurrent correction" } in
  let changed_book = get (B.put_entry book ~replace:true changed_target ~plan:None) in
  (match F.publish base.session changed_book with F.Written _ -> () | _ -> raise (F.Refused "reversal-conflict-setup"));
  let changed_bytes = F.read path in
  let conflict = key ~width_of review `Enter in
  require (conflict.blocked && Rev.day (editor conflict) = "2026-10-09"
           && F.read path = changed_bytes) "reversal-disk-conflict-retains-draft";
  let reloaded = input review (`Key (`ASCII 'r', [ `Ctrl ])) in
  require (reloaded.blocked && Rev.base_bytes (editor reloaded) = before
           && reloaded.session.bytes = changed_bytes) "reversal-reload-cannot-bless-stale-preview";
  let stopped = key ~width_of reloaded `Enter in
  require (stopped.blocked && F.read path = changed_bytes) "reversal-stale-preview-cannot-publish";
  let reset = input (key ~width_of reloaded (`ASCII 'q')) (`Key (`ASCII 'r', [ `Ctrl ])) in
  require (not reset.blocked) "reversal-explicit-cancel-reload-unblocks";
  let fresh = key ~width_of (key ~width_of (key ~width_of reset (`ASCII 'x')) `Enter) `Enter in
  let cold = F.load path in
  let reversal = List.find (fun (e : B.entry) -> e.reversal_of = Some target.id) (B.entries cold.book) in
  require (fresh.overlay = C.No_overlay && B.find_entry cold.book target.id = Some changed_target
           && reversal.day = F.today () && List.length reversal.effects = List.length target.effects)
    "reversal-cold-readback-original-and-relation";
  List.iter2 (fun original inverse -> require
    (D.Effect.locus original = D.Effect.locus inverse
     && D.Effect.measure original = D.Effect.measure inverse
     && D.Effect.key original = D.Effect.key inverse
     && Z.equal (Daily_actions.quanta inverse) (Z.neg (Daily_actions.quanta original)))
    "reversal-cold-exact-inverse-keys-coordinates") target.effects reversal.effects;
  let unknown_path = directory ^ "/unknown.sexp" in
  F.write_new unknown_path before;
  let unknown_base = C.initial ~config_home:directory (F.load unknown_path) |> fun s -> C.open_route s W.Actual in
  let unknown_review = key ~width_of (key ~width_of unknown_base (`ASCII 'x')) `Enter in
  let candidate = get (B.put_entry book ~replace:false { reversal with id = "unknown-reversal" } ~plan:None) in
  let draft = { unknown_review with overlay = C.Reversal (Rev.with_publish_error (editor unknown_review)) } in
  let unknown () = C.apply_commit_result unknown_review ~draft
    (Daily_actions.Uncertain { message = "synthetic lost acknowledgement";
      evidence = Daily_actions.Monolithic_candidate (B.to_string candidate) }) in
  let unconfirmed = input (unknown ()) (`Key (`ASCII 'r', [ `Ctrl ])) in
  require (unconfirmed.blocked && unconfirmed.pending <> None
           && C.is_reverse_entry unconfirmed.overlay && F.read unknown_path = before)
    "reversal-unknown-reload-does-not-retry";
  let attempted = key ~width_of unconfirmed `Enter in
  require (not (Rev.is_preview (editor attempted)) && attempted.pending = unconfirmed.pending)
    "reversal-unknown-stays-stopped-with-date";
  (match F.publish unknown_base.session candidate with F.Written _ -> () | _ -> raise (F.Refused "reversal-ack-setup"));
  let present_bytes = F.read unknown_path in
  let confirmed = input (unknown ()) (`Key (`ASCII 'r', [ `Ctrl ])) in
  require (not confirmed.blocked && confirmed.pending = None && confirmed.overlay = C.No_overlay
           && F.read unknown_path = present_bytes && List.length (B.entries confirmed.session.book) = 2)
    "reversal-confirmed-reload-closes-draft-without-duplicate";
  print_endline "PASS: reversal date/Preview, exact signed quantities, tiny/end gates, cancel/draft retention, stale base, storage/Records refusal, unknown/reload and cold inverse (synthetic)."

let self_check ~width_of () =
  let directory = "scratch/english-ui-check-" ^ F.new_id () in
  Unix.mkdir directory 0o700;
  let path = directory ^ "/book.sexp" in
  F.create_copy ~source:"examples/daily-book.sexp" ~target:path;
  let home = C.initial ~config_home:directory (F.load path) in
  bonsai_home_layout_check ~width_of home;
  home_layout_check ~width_of home;
  theme_check ~width_of ~directory home;
  panel_checks ~width_of ();
  actual_browsing_checks ~width_of ~directory home;
  scheduled_panel_checks ~width_of ~directory home;
  reversal_checks ~width_of ~directory home;
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
  let opened = key ~width_of home (`ASCII ' ') in
  (match C.overlay_screen ~dimensions:(80, 24) ~width_of opened with
   | None -> failwith "commands-overlay-missing"
   | Some rows ->
       require (List.exists (fun (_, text) -> Base.String.is_substring text ~substring:"Home / Commands") rows)
         "commands-header-path-visible";
       require (List.exists (fun (_, text) -> Base.String.is_substring text ~substring:"Choose a command group.") rows)
         "commands-header-description-visible";
       require (List.exists (fun (_, text) -> Base.String.is_substring text ~substring:"select") rows)
         "commands-footer-navigation-visible";
       require (List.exists (fun (style, text) -> style = C.Active && Base.String.is_substring text ~substring:"> Transactions") rows)
         "commands-active-selection-visible");
  let menu =
    opened |> fun s ->
    key ~width_of s (`Arrow `Down) |> fun s -> key ~width_of s (`Arrow `Right)
  in
  require
    (match menu.overlay with C.Commands { page = M.Planning; _ } -> true | _ -> false)
    "commands-enter-group";
  (match C.overlay_screen ~dimensions:(80, 24) ~width_of menu with
   | None -> failwith "commands-group-overlay-missing"
   | Some rows ->
       require (List.exists (fun (_, text) -> Base.String.is_substring text ~substring:"Commands / Plans and attention") rows)
         "commands-group-header-path-visible";
       require (List.exists (fun (_, text) -> Base.String.is_substring text ~substring:"Scheduled household work.") rows)
         "commands-group-header-description-visible");
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
  (* Test 'v' view toggle to Current neutral coordinates view *)
  let bal_current = key ~width_of bal_with_roles (`ASCII 'v') in
  let wide_current = C.screen ~width_of (120, 30) bal_current in
  require (contains wide_current "Balances / Current [Neutral]" && contains wide_current "Selected current balances")
    "balances-v-toggles-to-neutral-current-view";
  (* Write a balance-view.tsv and test configuration ordering *)
  let bv_path = directory ^ "/balance-view.tsv" in
  F.write_new bv_path "bank\tjpy\nwallet\tjpy\n";
  let bal_custom_bv = C.open_route { home with session = F.load path } W.Balances in
  let bal_custom_bv_neutral = key ~width_of bal_custom_bv (`ASCII 'v') in
  let wide_custom_bv = C.screen ~width_of (120, 30) bal_custom_bv_neutral in
  require (contains wide_custom_bv "bank" && contains wide_custom_bv "wallet")
    "balances-custom-balance-view-loaded";
  (* Test 'p' print preview modal *)
  let bal_print = key ~width_of bal_custom_bv_neutral (`ASCII 'p') in
  (match bal_print.overlay with
   | C.Modal_form f ->
       require (Ui_form.id f = "balance_print_preview") "balances-p-opens-print-preview";
       require (Ui_form.title f = "Balances / Print Preview") "balances-print-title"
   | _ -> failwith "expected print preview modal");
  let bal_after_print = key ~width_of bal_print `Escape in
  require (bal_after_print.overlay = C.No_overlay) "balances-print-escapes";
  (* Test 'o' observe prefill from selected balance *)
  let items = C.balance_items bal_with_roles in
  let acct_idx =
    let rec find i = function
      | [] -> 0
      | Daily_overlays.Account_row _ :: _ -> i
      | _ :: rest -> find (i + 1) rest
    in
    find 0 items
  in
  let bal_on_account = { bal_with_roles with workspace = { bal_with_roles.workspace with balance_selected = acct_idx } } in
  let bal_obs = key ~width_of bal_on_account (`ASCII 'o') in
  (match bal_obs.overlay with
   | C.Modal_form f ->
       require (Ui_form.id f = "observe_quantity") "balances-o-opens-observe-form";
       require (Ui_form.get_text f "locus" <> Some "") "balances-o-prefilled-locus";
       require (Ui_form.focused f = Ui_form.find_field_index f "amount") "balances-o-focuses-amount"
   | _ -> failwith "expected observe quantity modal");
  let bal_obs_cancel = key ~width_of bal_obs `Escape in
  require (bal_obs_cancel.overlay = C.No_overlay) "balances-observe-cancel-escapes";
  (* Test toggle back to Accounting view with 'v' *)
  let bal_back_acct = key ~width_of bal_custom_bv_neutral (`ASCII 'v') in
  let wide_back_acct = C.screen ~width_of (120, 30) bal_back_acct in
  require (contains wide_back_acct "Balances / Current [Accounting]")
    "balances-v-toggles-back-to-accounting";
  let pace_view = C.open_route home W.Daily_pace in
  let wide_pace = C.screen ~width_of (120, 30) pace_view in
  require (contains wide_pace "Daily Pace" && contains wide_pace "Pace Detail & Evidence")
    "daily-pace-wide-two-pane-visible";
  let pace_path = directory ^ "/daily-pace.tsv" in
  let windows_path = directory ^ "/boundary-presets.tsv" in
  F.write_new pace_path "wallet\tjpy\n";
  F.write_new windows_path ("test-cycle\t" ^ F.today () ^ "\t"
    ^ get (Cal.shift_days (F.today ()) 7) ^ "\n");
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
  let reversal_preview = key ~width_of actual_reversing `Enter in
  require (F.read path = cold.bytes) "reversal-date-enter-is-preview-only";
  let reversed = key ~width_of reversal_preview `Enter in
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
  (* Common IME cursor offset verification on Ui_form *)
  let cursor_initial = Ui_form.cursor_offset form ~width_of in
  (* summary: 3 lines ("Line 1 summary", "Line 2 summary", "") -> summary_count = 3 *)
  (* memo field: label="Memo: " (6), value="initial" (7) -> col = 13, row = 3 *)
  require (cursor_initial = Some (13, 3)) "form-cursor-initial-text";
  (* Unicode Japanese text width check: "メモ" (4) + ": " (2) + "昼食代" (6) = 12 *)
  let form_ja = Ui_form.create ~id:"ja_form" ~title:"Japanese"
    ~fields:[ Ui_form.text_field ~id:"memo" ~label:"メモ" ~value:"昼食代" () ] () in
  let cursor_ja = Ui_form.cursor_offset form_ja ~width_of in
  require (cursor_ja = Some (12, 0)) "form-cursor-japanese-fullwidth";
  (* Choice field focused -> None (no floating cursor/IME window) *)
  let cursor_choice = Ui_form.cursor_offset f_tab1 ~width_of in
  require (cursor_choice = None) "form-cursor-choice-none";
  (* Buttons field focused -> None *)
  let cursor_btn = Ui_form.cursor_offset f_tab2 ~width_of in
  require (cursor_btn = None) "form-cursor-buttons-none";
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
  (* Manage Loci workflow verification *)
  let current_home = C.initial ~config_home:directory (F.load path) in
  let loci_state = C.open_route current_home W.Loci in
  require (loci_state.workspace.route = W.Loci) "open-route-loci";
  let loci_modal_add = key ~width_of loci_state (`ASCII 'n') in
  require (C.is_admit_locus loci_modal_add.overlay) "loci-n-opens-admit-form";
  let admit_form_ready =
    match loci_modal_add.overlay with
    | C.Modal_form f ->
        let f2 = Ui_form.set_text f "token" "metro" in
        let f3 = Ui_form.set_choice f2 "role" 1 in (* Asset *)
        let f4 = Ui_form.set_focused f3 2 in (* focus confirm button *)
        { loci_modal_add with overlay = C.Modal_form f4 }
    | _ -> failwith "expected modal form for admit locus"
  in
  let admitted_state = key ~width_of admit_form_ready `Enter in
  require (admitted_state.overlay = C.No_overlay) "admit-locus-submitted";
  let all_loci = C.admitted_loci admitted_state in
  require (List.mem "metro" all_loci) "admitted-locus-present-in-catalog";
  let roles_after = C.accounting_roles admitted_state in
  require (List.assoc_opt "metro" roles_after = Some Roles.Asset) "admitted-locus-has-asset-role";
  let sel_idx =
    let rec find i = function
      | [] -> 0
      | x :: rest -> if x = "metro" then i else find (i + 1) rest
    in
    find 0 all_loci
  in
  let state_on_metro =
    { admitted_state with workspace = { admitted_state.workspace with loci = { admitted_state.workspace.loci with selected = sel_idx } } }
  in
  let role_modal = key ~width_of state_on_metro (`ASCII 'r') in
  require (C.is_set_locus_role role_modal.overlay) "loci-r-opens-set-role-form";
  let role_form_ready =
    match role_modal.overlay with
    | C.Modal_form f ->
        let f2 = Ui_form.set_choice f "role" 5 in (* Expense *)
        let f3 = Ui_form.set_focused f2 1 in (* focus confirm button *)
        { role_modal with overlay = C.Modal_form f3 }
    | _ -> failwith "expected modal form for set locus role"
  in
  let updated_role_state = key ~width_of role_form_ready `Enter in
  require (updated_role_state.overlay = C.No_overlay) "set-locus-role-submitted";
  let roles_final = C.accounting_roles updated_role_state in
  require (List.assoc_opt "metro" roles_final = Some Roles.Expense) "locus-role-updated-to-expense";
  let loci_back = key ~width_of updated_role_state (`ASCII 'q') in
  require (loci_back.workspace.route = W.Home) "loci-q-back-to-home";
  (* Exchange test *)
  let cmd_root = key ~width_of loci_back (`ASCII ' ') in
  let tx_menu = key ~width_of cmd_root `Enter in
  let to_exch = key ~width_of (key ~width_of (key ~width_of tx_menu (`Arrow `Down)) (`Arrow `Down)) (`Arrow `Down) in
  let exch_modal = key ~width_of to_exch `Enter in
  require (C.is_exchange exch_modal.overlay) "commands-opens-exchange-form";
  (* Validate error on same measure *)
  let err_form =
    match exch_modal.overlay with
    | C.Modal_form f ->
        let f = Ui_form.set_text f "source_locus" "wallet" in
        let f = Ui_form.set_text f "source_measure" "jpy" in
        let f = Ui_form.set_text f "source_amount" "100" in
        let f = Ui_form.set_text f "destination_locus" "bank" in
        let f = Ui_form.set_text f "destination_measure" "jpy" in
        let f = Ui_form.set_text f "destination_amount" "100" in
        let f = Ui_form.set_focused f 8 in (* action buttons *)
        { exch_modal with overlay = C.Modal_form f }
    | _ -> failwith "expected modal form for exchange"
  in
  let err_submitted = key ~width_of err_form `Enter in
  require (match err_submitted.overlay with
           | C.Modal_form f -> Ui_form.notice f = "Source and destination Measures must differ."
           | _ -> false)
    "exchange-rejects-same-measure";
  (* Successful exchange JPY -> EUR *)
  let ok_form =
    match err_submitted.overlay with
    | C.Modal_form f ->
        let f = Ui_form.set_text f "date" "2026-10-14" in
        let f = Ui_form.set_text f "memo" "Exchange JPY to EUR" in
        let f = Ui_form.set_text f "source_locus" "wallet" in
        let f = Ui_form.set_text f "source_measure" "jpy" in
        let f = Ui_form.set_text f "source_amount" "1500" in
        let f = Ui_form.set_text f "destination_locus" "bank" in
        let f = Ui_form.set_text f "destination_measure" "eur" in
        let f = Ui_form.set_text f "destination_amount" "10.00" in
        let f = Ui_form.set_focused f 8 in
        { err_submitted with overlay = C.Modal_form f }
    | _ -> failwith "expected modal form for exchange"
  in
  let exch_done = key ~width_of ok_form `Enter in
  require (exch_done.overlay = C.No_overlay) "exchange-committed";
  require (exch_done.message = "Published and read back. Previous bytes are kept separately.") "exchange-success-message";
  let reloaded_book = (F.load path).book in
  let latest_entry = List.hd (List.rev (B.entries reloaded_book)) in
  require (latest_entry.exchange = Some ("exchange-source", "exchange-destination")) "exchange-keys-retained";
  require (latest_entry.memo = Some "Exchange JPY to EUR") "exchange-memo-retained";
  require (latest_entry.day = "2026-10-14") "exchange-day-retained";
  require (List.length latest_entry.effects = 2) "exchange-has-two-effects";
  let src_eff = List.nth latest_entry.effects 0 in
  let dst_eff = List.nth latest_entry.effects 1 in
  require (D.Identifier.Locus.to_string (D.Effect.locus src_eff) = "wallet") "exchange-source-locus";
  require (D.Identifier.Measure.to_string (D.Effect.measure src_eff) = "jpy") "exchange-source-measure";
  require (Z.equal (D.Quantity.quanta (D.Effect.quantity src_eff)) (Z.of_int (-1500))) "exchange-source-amount-negative";
  require (D.Identifier.Locus.to_string (D.Effect.locus dst_eff) = "bank") "exchange-destination-locus";
  require (D.Identifier.Measure.to_string (D.Effect.measure dst_eff) = "eur") "exchange-destination-measure";
  require (Z.equal (D.Quantity.quanta (D.Effect.quantity dst_eff)) (Z.of_int 1000)) "exchange-destination-amount-positive";
  (* Settlements (UI-27, UI-28) test suite *)
  let contains rows needle = List.exists (fun (_, text) -> Base.String.is_substring text ~substring:needle) rows in
  let cmd_root = key ~width_of exch_done (`ASCII ' ') in
  let to_planning = key ~width_of cmd_root (`Arrow `Down) in (* Planning is index 1 *)
  let plan_menu = key ~width_of to_planning `Enter in
  let to_settlements = key ~width_of (key ~width_of (key ~width_of plan_menu (`Arrow `Down)) (`Arrow `Down)) (`Arrow `Down) in (* Scheduled 0, New Plan 1, Attention 2, Settlements 3 *)
  let stl_view = key ~width_of to_settlements `Enter in
  require (stl_view.workspace.route = W.Settlements) "commands-opens-settlements-view";
  let wide_stl = C.screen ~width_of (120, 30) stl_view in
  require (contains wide_stl "Settlements [Open]" && contains wide_stl "Commitment Details") "settlements-wide-two-pane-visible";
  (* Add settlement commitment *)
  let add_modal = key ~width_of stl_view (`ASCII 'n') in
  require (C.is_add_settlement add_modal.overlay) "n-opens-add-settlement-form";
  let add_ready =
    match add_modal.overlay with
    | C.Modal_form f ->
        let f = Ui_form.set_text f "label" "Dinner reimbursement" in
        let f = Ui_form.set_text f "debtor" "yamada" in
        let f = Ui_form.set_text f "creditor" "household" in
        let f = Ui_form.set_text f "measure" "jpy" in
        let f = Ui_form.set_text f "amount" "5000" in
        let f = Ui_form.set_focused f 5 in (* Action buttons *)
        { add_modal with overlay = C.Modal_form f }
    | _ -> failwith "expected modal form for add settlement"
  in
  let added_state = key ~width_of add_ready `Enter in
  require (added_state.overlay = C.No_overlay) "add-settlement-submitted";
  let stl_rows = C.settlement_rows added_state in
  require (List.length stl_rows = 1) "settlement-row-added";
  let r = List.hd stl_rows in
  require (r.Stl.id = "comm-1" && r.label = Some "Dinner reimbursement") "settlement-row-fields";
  require (Z.equal (Stl.outstanding r) (Z.of_int 5000)) "settlement-outstanding-5000";
  (* Settle partial amount: 3,000 jpy *)
  let act_modal = key ~width_of added_state (`ASCII 'a') in
  require (C.is_action_settlement act_modal.overlay) "a-opens-action-settlement-form";
  let act_ready =
    match act_modal.overlay with
    | C.Modal_form f ->
        let f = Ui_form.set_choice f "action_kind" 0 in (* Settle *)
        let f = Ui_form.set_text f "amount" "3000" in
        let f = Ui_form.set_focused f 2 in
        { act_modal with overlay = C.Modal_form f }
    | _ -> failwith "expected modal form for action settlement"
  in
  let settled_state = key ~width_of act_ready `Enter in
  require (settled_state.overlay = C.No_overlay) "settle-action-submitted";
  let r2 = List.hd (C.settlement_rows settled_state) in
  require (Z.equal (Stl.outstanding r2) (Z.of_int 2000)) "settlement-outstanding-after-settle-2000";
  require (Z.equal r2.settled (Z.of_int 3000)) "settled-amount-3000";
  (* Reduce without payment: 1,000 jpy *)
  let act_modal2 = key ~width_of settled_state (`ASCII 'a') in
  let act_ready2 =
    match act_modal2.overlay with
    | C.Modal_form f ->
        let f = Ui_form.set_choice f "action_kind" 1 in (* Reduce *)
        let f = Ui_form.set_text f "amount" "1000" in
        let f = Ui_form.set_focused f 2 in
        { act_modal2 with overlay = C.Modal_form f }
    | _ -> failwith "expected modal form for action settlement"
  in
  let reduced_state = key ~width_of act_ready2 `Enter in
  require (reduced_state.overlay = C.No_overlay) "reduce-action-submitted";
  let r3 = List.hd (C.settlement_rows reduced_state) in
  require (Z.equal (Stl.outstanding r3) (Z.of_int 1000)) "settlement-outstanding-after-reduce-1000";
  require (Z.equal r3.extinguished (Z.of_int 1000)) "extinguished-amount-1000";
  (* Full final settlement of remaining 1,000 jpy *)
  let act_modal3 = key ~width_of reduced_state (`ASCII 'a') in
  let act_ready3 =
    match act_modal3.overlay with
    | C.Modal_form f ->
        let f = Ui_form.set_choice f "action_kind" 0 in (* Settle *)
        let f = Ui_form.set_text f "amount" "1000" in
        let f = Ui_form.set_focused f 2 in
        { act_modal3 with overlay = C.Modal_form f }
    | _ -> failwith "expected modal form for action settlement"
  in
  let fully_settled_state = key ~width_of act_ready3 `Enter in
  require (C.settlement_rows fully_settled_state = []) "open-rows-empty-after-full-settle";
  (* Scope cycle to All current *)
  let all_scope_state = key ~width_of fully_settled_state (`ASCII 's') in
  require (all_scope_state.settlement_scope = Stl.All) "scope-toggled-to-all";
  let all_rows = C.settlement_rows all_scope_state in
  require (List.length all_rows = 1) "all-scope-has-completed-row";
  let wide_all = C.screen ~width_of (120, 30) all_scope_state in
  require (contains wide_all "done") "all-scope-shows-done-marker";
  (* q returns to Home *)
  let back_home = key ~width_of all_scope_state (`ASCII 'q') in
  require (back_home.workspace.route = W.Home) "settlements-q-back-to-home";
  (* Disk persistence verify *)
  let stl_file = get (Stl.load_file (Stl.file_path ~config_home:directory path)) in
  require (List.length stl_file.rows = 1) "settlements-persisted-to-file";
  (* Observe Quantities modal form workflow *)
  (* 1. Launch via 'o' key from back_home *)
  let obs_modal = key ~width_of back_home (`ASCII 'o') in
  let form_obs =
    match obs_modal.overlay with
    | C.Modal_form f ->
        require (Ui_form.id f = "observe_quantity") "observe-modal-form-id";
        require (Ui_form.get_text f "measure" = Some "jpy") "observe-default-measure-jpy";
        f
    | _ -> failwith "expected modal form for observe_quantity"
  in
  (* 2. Test validation failure on unapproved locus *)
  let invalid_locus_form = Ui_form.set_text form_obs "locus" "unknown_card" in
  let invalid_locus_form = Ui_form.set_text invalid_locus_form "amount" "1000" in
  let invalid_locus_form = Ui_form.set_focused invalid_locus_form 2 in
  let invalid_locus_state =
    match C.handle ~width_of { obs_modal with overlay = C.Modal_form invalid_locus_form } (`Key (`Enter, [])) with
    | Some s -> s
    | None -> failwith "unexpected exit on invalid locus submit"
  in
  (match invalid_locus_state.overlay with
   | C.Modal_form f ->
       require (Ui_form.notice f = "Locus 'unknown_card' is not in approved vocabulary.") "refuses-unapproved-locus"
   | _ -> failwith "expected modal form with notice");
  (* Cancel out with Esc *)
  let cancelled_obs = key ~width_of invalid_locus_state `Escape in
  require (cancelled_obs.overlay = C.No_overlay) "observe-cancel-escapes";
  (* 3. Successfully observe wallet = 5,000 JPY *)
  let obs_modal2 = key ~width_of back_home (`ASCII 'o') in
  let valid_form =
    match obs_modal2.overlay with
    | C.Modal_form f ->
        let f = Ui_form.set_text f "locus" "wallet" in
        let f = Ui_form.set_text f "amount" "5000" in
        Ui_form.set_focused f 2
    | _ -> failwith "expected modal form for observe_quantity"
  in
  let observed_state =
    match C.handle ~width_of { obs_modal2 with overlay = C.Modal_form valid_form } (`Key (`Enter, [])) with
    | Some s -> s
    | None -> failwith "unexpected exit on valid observe submit"
  in
  require (observed_state.overlay = C.No_overlay) "observe-submitted-overlay-cleared";
  require (Base.String.is_substring observed_state.message ~substring:"Observed wallet jpy = 5000.") "observe-success-message";
  let check_qty book locus measure =
    let module Q = Bakhlo_application.Current_quantity_query in
    let locus = C.get_id (D.Identifier.Locus.of_string locus) in
    let measure = C.get_id (D.Identifier.Measure.of_string measure) in
    match Q.query (B.image book) { D.Effect_coordinate.locus; measure } with
    | Ok (Q.Exact x) -> Z.to_string (D.Quantity.quanta (Q.quantity x))
    | _ -> "unexpected"
  in
  require (check_qty observed_state.session.book "wallet" "jpy" = "5000") "wallet-balance-observed-5000";
  (* 4. Successfully observe bank = 0 JPY *)
  let obs_modal3 = key ~width_of observed_state (`ASCII 'o') in
  let valid_form_zero =
    match obs_modal3.overlay with
    | C.Modal_form f ->
        let f = Ui_form.set_text f "locus" "bank" in
        let f = Ui_form.set_text f "amount" "0" in
        Ui_form.set_focused f 2
    | _ -> failwith "expected modal form for observe_quantity zero"
  in
  let zero_state =
    match C.handle ~width_of { obs_modal3 with overlay = C.Modal_form valid_form_zero } (`Key (`Enter, [])) with
    | Some s -> s
    | None -> failwith "unexpected exit on valid zero observe submit"
  in
  require (check_qty zero_state.session.book "bank" "jpy" = "0") "bank-balance-observed-0";
  require (check_qty zero_state.session.book "wallet" "jpy" = "5000") "wallet-balance-retained-5000";
  (* Daily Pace workflow & what-if simulator *)
  (* 1. Navigate to Daily Pace from Home via 'd' *)
  let pace_home = key ~width_of zero_state (`ASCII 'd') in
  require (pace_home.workspace.route = W.Daily_pace) "route-daily-pace";
  let screen_pace = C.screen ~width_of (120, 30) pace_home in
  require (contains screen_pace "Daily Pace:") "daily-pace-explicitly-configured";
  require (contains screen_pace "Period progress:") "daily-pace-progress-bar";
  require (contains screen_pace "w what-if") "pace-footer-what-if-hint";
  require (contains screen_pace "c configure") "pace-footer-configure-hint";
  (* 2. What-If simulator modal via 'w' *)
  let what_if_state = key ~width_of pace_home (`ASCII 'w') in
  let form_wi =
    match what_if_state.overlay with
    | C.Modal_form f ->
        require (Ui_form.id f = "daily_pace_what_if") "what-if-modal-id";
        f
    | _ -> failwith "expected what_if modal"
  in
  let form_wi_filled = Ui_form.set_text form_wi "amount" "2000" in
  let form_wi_filled = Ui_form.set_focused form_wi_filled 1 in
  let sim_res_state =
    match C.handle ~width_of { what_if_state with overlay = C.Modal_form form_wi_filled } (`Key (`Enter, [])) with
    | Some s -> s
    | None -> failwith "unexpected exit on what-if submit"
  in
  (match sim_res_state.overlay with
   | C.Modal_form f_res ->
       require (Base.String.is_substring (Ui_form.notice f_res) ~substring:"Simulated pace:") "what-if-result-calculated";
       require (Base.String.is_substring (Ui_form.notice f_res) ~substring:"Remaining available:") "what-if-remaining-shown"
   | _ -> failwith "expected what_if result modal");
  (* Close simulator with Escape without altering ledger *)
  let closed_sim = key ~width_of sim_res_state `Escape in
  require (closed_sim.overlay = C.No_overlay) "what-if-closed-on-esc";
  require (check_qty closed_sim.session.book "wallet" "jpy" = "5000") "what-if-does-not-alter-ledger";
  (* 3. Configure Daily Pace modal via 'c' *)
  let cfg_state = key ~width_of closed_sim (`ASCII 'c') in
  let form_cfg =
    match cfg_state.overlay with
    | C.Modal_form f ->
        require (Ui_form.id f = "configure_daily_pace") "cfg-pace-modal-id";
        f
    | _ -> failwith "expected cfg modal"
  in
  require (Ui_form.get_text form_cfg "end_date" = None) "period-is-read-only-in-pool-editor";
  let boundaries_before = F.read windows_path in
  (* Invalid/duplicate pool must not save either configuration. *)
  let form_cfg_err = Ui_form.set_text form_cfg "pool_loci" "wallet, wallet" in
  let form_cfg_err = Ui_form.set_focused form_cfg_err 1 in
  let err_state =
    match C.handle ~width_of { cfg_state with overlay = C.Modal_form form_cfg_err } (`Key (`Enter, [])) with
    | Some s -> s
    | None -> failwith "unexpected exit on cfg err submit"
  in
  (match err_state.overlay with
   | C.Modal_form f_notice ->
       require (Ui_form.notice f_notice = "Choose distinct admitted Locus tokens, separated by commas.")
         "cfg-pace-validates-pool"
   | _ -> failwith "expected notice on invalid pool");
  let form_cfg_valid = Ui_form.set_text form_cfg "pool_loci" "wallet" in
  let form_cfg_valid = Ui_form.set_focused form_cfg_valid 1 in
  let saved_state =
    match C.handle ~width_of { cfg_state with overlay = C.Modal_form form_cfg_valid } (`Key (`Enter, [])) with
    | Some s -> s
    | None -> failwith "unexpected exit on cfg save"
  in
  require (saved_state.overlay = C.No_overlay) "cfg-pace-saved-overlay-cleared";
  require (saved_state.message = "Daily Pace pool saved. Period presets unchanged.") "cfg-pace-saved-message";
  require (F.read windows_path = boundaries_before) "pool-editor-preserves-boundaries-byte-exactly";
  let screen_reloaded = C.screen ~width_of (120, 30) saved_state in
  require (contains screen_reloaded "Source: Pool [config/daily-pace.tsv]") "shows-configured-pool-source";
  let back_home2 = key ~width_of saved_state (`ASCII 'q') in
  require (back_home2.workspace.route = W.Home) "pace-q-back-to-home";
  (* Common hardware cursor position & IME anchor verification across UI *)
  (* 1. Home workspace (browse mode) -> None (cursor hidden) *)
  require (C.cursor_position ~width_of (80, 24) home = None) "cursor-hidden-on-home";
  (* 2. Modal form active on text field -> Some (col, row) *)
  let form_ja_state = { home with overlay = C.Modal_form form_ja } in
  (match C.cursor_position ~width_of (80, 24) form_ja_state with
   | Some (col, row) ->
       require (col > 0 && col < 80) "cursor-modal-col-bounded";
       require (row > 0 && row < 24) "cursor-modal-row-bounded"
   | None -> failwith "expected-modal-form-cursor");
  (* 3. Record session active -> Some (col, row) matches Input caret cell *)
  let rec_state = key ~width_of home (`ASCII 'r') in
  require rec_state.record_visible "record-visible";
  (match C.cursor_position ~width_of (80, 24) rec_state with
   | Some (col, row) ->
       require (col > 0 && col < 80) "cursor-record-col-bounded";
       require (row > 0 && row < 24) "cursor-record-row-bounded"
   | None -> failwith "expected-record-session-cursor");
  (* 4. Jump and Search overlays -> Some (col, row) *)
  let jump_state = { home with overlay = C.Jump "2026-10" } in
  (match C.cursor_position ~width_of (80, 24) jump_state with
   | Some (col, row) ->
       require (col > 0 && col < 80) "cursor-jump-col-bounded";
       require (row > 0 && row < 24) "cursor-jump-row-bounded"
   | None -> failwith "expected-jump-overlay-cursor");
  let search_state = { home with overlay = C.Search "ramen" } in
  (match C.cursor_position ~width_of (80, 24) search_state with
   | Some (col, row) ->
       require (col > 0 && col < 80) "cursor-search-col-bounded";
       require (row > 0 && row < 24) "cursor-search-row-bounded"
   | None -> failwith "expected-search-overlay-cursor");
  (* 5. Single source of truth: resolve_overlay must strictly match cursor_position across overlays *)
  let check_overlay_sync state label =
    match C.resolve_overlay ~dimensions:(80, 24) ~width_of state with
    | None -> failwith ("expected-overlay-frame-" ^ label)
    | Some frame ->
        require (C.cursor_position ~width_of (80, 24) state = frame.cursor)
          ("overlay-cursor-sync-" ^ label);
        (match frame.cursor with
        | Some (col, row) ->
            require (col >= frame.origin_x && col < frame.origin_x + frame.pane_width)
              ("cursor-within-pane-width-" ^ label);
            require (row >= frame.origin_y && row < frame.origin_y + frame.pane_height)
              ("cursor-within-pane-height-" ^ label)
        | None -> ())
  in
  check_overlay_sync form_ja_state "modal-form";
  check_overlay_sync rec_state "record-session";
  check_overlay_sync jump_state "jump";
  check_overlay_sync search_state "search";
  (* 6. Japanese text IME cursor anchor stability *)
  let rec_ja = text ~width_of rec_state "コンビニ" in
  check_overlay_sync rec_ja "record-with-japanese-text";
  let search_ja = { home with overlay = C.Search "食費" } in
  check_overlay_sync search_ja "search-with-japanese-text";
  safety_checks ~width_of ~directory ();
  print_endline
    "PASS: English Calendar / Commands / Record / child navigation / exact cold save and safety \
     guards.";
  home
