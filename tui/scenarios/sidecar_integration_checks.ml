(* Synthetic controller integration checks; see docs/RECONSTRUCTION_TEST_MAP.ja.md. *)
open Interaction_check_fixture

let safety_checks ~width_of ~directory () =
  let dir = directory ^ "/safety" in
  Unix.mkdir dir 0o700;
  let path = dir ^ "/book.txt" in
  F.create_copy ~source:Interaction_check_fixture.example_book ~target:path;
  let home = C.initial ~config_home:dir (F.load path) in
  let contains rows needle =
    List.exists (fun (_, text) -> Base.String.is_substring text ~substring:needle) rows
  in
  let failed state =
    match visible_form state with Some f -> Ui_form.notice f <> "" | None -> false
  in
  let att =
    get
      (Att.add_item Att.empty ~id:"attention-2" ~context:"合成\\text\nnext" ~due:Att.Due_undetermined)
  in
  require (Att.next_id att <> "attention-2") "attention-id-does-not-collide";
  (* Attention is a section of the book: every save goes through the single writer. *)
  let base = C.initial ~config_home:dir (F.load path) in
  let saved, result = Shell_files.save_attention base ~expected:Att.empty att in
  get result;
  require
    (C.attention saved = Ok att && C.attention (C.initial ~config_home:dir (F.load path)) = Ok att)
    "attention-saved-in-book";
  require
    (Result.is_error (snd (Shell_files.save_attention saved ~expected:Att.empty Att.empty)))
    "attention-stale-write-refused";
  let book_bytes = F.read path in
  let state = C.initial ~config_home:dir (F.load path) in
  Unix.mkdir (path ^ ".lock.block") 0o700;
  (try Unix.unlink (path ^ ".lock") with Unix.Unix_error (Unix.ENOENT, _, _) -> ());
  Unix.rename (path ^ ".lock.block") (path ^ ".lock");
  let adding state = key ~width_of (C.open_route state W.Attention) (`ASCII 'n') in
  let form =
    Option.get (visible_form (adding state)) |> fun f -> Ui_form.set_text f "context" "Retain me"
  in
  let ready = with_visible_form (adding state) (Ui_form.set_focused form 3) in
  let refused = key ~width_of ready `Enter in
  require
    (failed refused && C.attention refused = C.attention state)
    "attention-save-failure-preserves-state";
  (match visible_form refused with
  | Some f ->
      require
        (Ui_form.get_text f "context" = Some "Retain me")
        "attention-save-failure-preserves-draft"
  | None -> require false "attention-draft-lost");
  require (F.read path = book_bytes) "attention-save-failure-preserves-file";
  Unix.rmdir (path ^ ".lock");
  (* A broken Attention section refuses the whole book, never an empty Attention. *)
  let broken_path = dir ^ "/broken-attention.txt" in
  F.write_new broken_path
    (Base.String.substr_replace_first book_bytes ~pattern:"\nEND\n"
       ~with_:"\nITEM\tbroken\tDUE_ON\t2026-02-30\tbad date\nEND\n");
  require
    (match F.load broken_path with _ -> false | exception F.Refused _ -> true)
    "attention-broken-section-refuses-the-book";
  (* Another writer's Attention appears after an explicit reload. *)
  let other = C.initial ~config_home:dir (F.load path) in
  let att2 =
    get (Att.add_item att ~id:(Att.next_id att) ~context:"other writer" ~due:Att.No_due_date)
  in
  get (snd (Shell_files.save_attention other ~expected:att att2));
  require
    (C.attention (Shell_dispatch.reload state) = Ok att2)
    "explicit-reload-refreshes-attention";
  List.iter
    (fun raw -> require (Result.is_error (Stl.of_string raw)) "settlement-invalid-input-refused")
    [
      "broken\n";
      "id\t\ta\tb\tjpy\tbad\t0\t0\n";
      "id\t\ta\tb\tjpy\t10\t11\t0\n";
      "id\t\ta\tb\tjpy\t10\t-1\t0\n";
      "id\t\ta\tb\tjpy\t10\t0\t0\nid\t\ta\tb\tjpy\t10\t0\t0\n";
    ];
  let stl_path = Settlement_file.file_path ~config_home:dir path in
  F.write_new stl_path "id\t\ta\tb\tjpy\tbad\t0\t0\n";
  let broken = C.initial ~config_home:dir (F.load path) in
  require (Result.is_error broken.settlements) "settlement-load-failure-is-not-zero";
  require
    (contains (R.screen ~width_of (120, 30) (C.open_route broken W.Settlements)) "Unavailable")
    "settlement-load-failure-visible";
  require
    (Result.is_error (Settlement_file.save_file stl_path ~expected:Stl.empty Stl.empty))
    "settlement-corruption-blocks-save";
  let stl_bytes = F.read stl_path in
  let adding_stl state = key ~width_of (C.open_route state W.Settlements) (`ASCII 'n') in
  let form = Option.get (visible_form (adding_stl home)) in
  let form =
    Ui_form.set_text form "debtor" "a" |> fun f ->
    Ui_form.set_text f "creditor" "b" |> fun f ->
    Ui_form.set_text f "amount" "10" |> fun f -> Ui_form.set_focused f 5
  in
  require
    (failed (key ~width_of (with_visible_form (adding_stl broken) form) `Enter))
    "settlement-corruption-ui-refuses";
  require (F.read stl_path = stl_bytes) "settlement-corruption-preserved";
  Unix.unlink stl_path;
  Unix.mkdir (stl_path ^ ".lock.block") 0o700;
  Unix.unlink (stl_path ^ ".lock");
  Unix.rename (stl_path ^ ".lock.block") (stl_path ^ ".lock");
  let refused = key ~width_of (with_visible_form (adding_stl home) form) `Enter in
  require
    (failed refused && refused.settlements = home.settlements)
    "settlement-save-failure-preserves-state";
  require (not (Sys.file_exists stl_path)) "settlement-save-failure-no-file";
  Unix.rmdir (stl_path ^ ".lock");
  let huge = Z.pow (Z.of_int 10) 70 in
  let commitments =
    get
      (Stl.add_row Stl.empty ~id:"huge" ~label:"合成のみ" ~debtor:"a" ~creditor:"b" ~measure:"jpy"
         ~committed:huge ())
  in
  get (Settlement_file.save_file stl_path ~expected:Stl.empty commitments);
  require
    (get (Settlement_file.load_file stl_path) = commitments)
    "settlement-exact-huge-cold-round-trip";
  require
    (Result.is_error (Settlement_file.save_file stl_path ~expected:Stl.empty Stl.empty))
    "settlement-stale-write-refused";
  require
    (get (Settlement_file.load_file stl_path) = commitments)
    "settlement-stale-write-preserves-evidence";
  require (Result.is_error (resolve_pace_pool home)) "missing-pool-is-not-inferred";
  require (Result.is_error (resolve_pace_window home)) "missing-window-is-not-month-end";
  let pool_path = dir ^ "/daily-pace.tsv" and windows_path = dir ^ "/boundary-presets.tsv" in
  let replace path bytes =
    if Sys.file_exists path then Unix.unlink path;
    F.write_new path bytes
  in
  List.iter
    (fun raw ->
      replace pool_path raw;
      require (Result.is_error (resolve_pace_pool home)) "pool-rejects-bad-duplicate-or-mixed-rows")
    [ "wallet\tjpy\nbad\n"; "wallet\tjpy\nwallet\tjpy\n"; "wallet\tjpy\nbank\teur\n" ];
  replace pool_path "wallet\tjpy\n";
  let today = Clock.today () and stop = get (Day.shift_days (Clock.today ()) 7) in
  let window = "cycle\t" ^ today ^ "\t" ^ stop ^ "\n" in
  List.iter
    (fun raw ->
      replace windows_path raw;
      require
        (Result.is_error (resolve_pace_window home))
        "window-rejects-malformed-or-ambiguous-presets")
    [
      window ^ "other\t" ^ today ^ "\t" ^ stop ^ "\n";
      window ^ "old\t2026-02-30\t2026-03-01\n";
      window ^ "old\t1900/01/01\t1901/01/01\n";
      "cycle\t" ^ stop ^ "\t" ^ today ^ "\n";
    ];
  let boundaries = "old\t1900-01-01\t1901-01-01\n" ^ window in
  replace windows_path boundaries;
  let pace, _, _ = get (current_pace_result home) in
  let amount = Z.add pace.B.available_through_end Z.one in
  let simulated =
    String.fold_left
      (fun s c -> key ~width_of s (`ASCII c))
      (open_what_if ~width_of home) (Z.to_string amount)
  in
  require
    (match R.overlay_screen ~dimensions:(80, 24) ~width_of simulated with
    | Some rows ->
        List.exists
          (fun (_, row) -> Base.String.is_substring row ~substring:"After purchase: -1 jpy/day")
          rows
    | None -> false)
    "negative-what-if-uses-floor-division-without-clamping";
  let reviewed = key ~width_of (pool_toggle ~width_of (open_pool_editor home) "food") `Enter in
  require
    (pool_reviewing ~width_of reviewed
    && F.read pool_path = "wallet\tjpy\n"
    && F.read windows_path = boundaries)
    "pool-review-does-not-save";
  let saved = key ~width_of reviewed `Enter in
  require
    (no_modal saved
    && F.read pool_path = "wallet\tjpy\nfood\tjpy\n"
    && F.read windows_path = boundaries)
    "pool-save-preserves-all-presets";
  let stale_open = open_pool_editor home in
  replace pool_path "bank\tjpy\n";
  let stale_review = key ~width_of stale_open `Enter in
  require (F.read pool_path = "bank\tjpy\n") "stale-pool-review-does-not-save";
  require
    (Base.String.is_substring
       (pool_text ~width_of (key ~width_of stale_review `Enter))
       ~substring:"Pool save not confirmed")
    "stale-pool-save-refused";
  require
    (F.read pool_path = "bank\tjpy\n" && F.read windows_path = boundaries)
    "stale-config-preserved";
  Unix.unlink windows_path;
  let reviewed = key ~width_of (pool_toggle ~width_of (open_pool_editor home) "food") `Enter in
  let saved = key ~width_of reviewed `Enter in
  require
    (no_modal saved && F.read pool_path = "food\tjpy\n" && not (Sys.file_exists windows_path))
    "pool-save-does-not-invent-period";
  print_endline
    "PASS: sidecar refusal/draft preservation, strict inputs, explicit Pace, negative What-if and \
     non-destructive Pool edits."
