(** daily_pace_owner_checks.ml - Dedicated verification for Daily Pace vertical owner. *)

module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module O = Daily_overlays
module Daily_pace = Daily_pace_owner
module Trend = Daily_pace_trend
module F = Daily_file
module Form = Ui_form

let require condition name =
  if not condition then failwith ("FAILED: daily_pace_owner_check: " ^ name)

let key ?(mods = []) button : Ui_input.input = `Key (button, mods)
let char_key c : Ui_input.input = `Key (`ASCII c, [])
let get = function Ok x -> x | Error why -> failwith why

let test_book_fixture =
  "(bakhlo-daily 3)\n(scope corrected-entries explicit-plans)\n\
   (measures (measure \"jpy\" 0))\n\
   (labels (provided (label \"wallet\" \"財布\" \"Cash\") (label \"bank\" \"銀行\" \"Bank\") (label \"food\" \"食費\" \"Food\")))\n\
   (approved-loci (provided \"wallet\" \"bank\" \"food\"))\n(entries)\n\
   (plans (plan p1 (date 2026-10-20) (measure jpy) (changes (wallet -1000) (food 1000)) (paid-by (none))))\n\
   (support (zero-origin (\"food\" \"jpy\")) (openings)\n\
     (observations (observation (reflected) (quantities (\"wallet\" \"jpy\" 50000) (\"bank\" \"jpy\" 200000))))\n\
     (presence (not-supplied)))\n"

let unit_checks ~width_of () =
  let book = get (B.of_string test_book_fixture) in
  let today = "2026-10-18" in
  let pool_tsv = Ok (Some "wallet\tjpy\n") in
  let presets_tsv = Ok (Some "cycle\t2026-10-15\t2026-11-15\n") in
  let owner = Daily_pace.create () in
  require (Daily_pace.pane owner = `Calendar) "initial-pane-calendar";
  require (Daily_pace.preset owner = Trend.Ten_days) "initial-preset-ten-days";
  require (not (Daily_pace.has_overlay owner)) "initial-no-overlay";

  (* 1. Current pace calculation *)
  let pace_res = Daily_pace.current_pace ~book ~measure:"jpy" ~daily_pace_tsv:pool_tsv
    ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today in
  require (Result.is_ok pace_res) "current-pace-calculated";
  let pace, _, _ = get pace_res in
  require (Z.gt pace.B.daily_pace_quanta Z.zero) "pace-positive";

  (* 2. Header summary *)
  let hdr = Daily_pace.header_summary ~book ~measure:"jpy" ~daily_pace_tsv:pool_tsv
    ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today ~width:80 ~width_of owner in
  require (Base.String.is_substring hdr ~substring:"Today:") "header-has-today";

  (* 3. Preset switching via 1..5 keys *)
  let owner_30, _ = Daily_pace.handle ~blocked:false ~book ~measure:"jpy" ~daily_pace_tsv:pool_tsv
    ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today ~dimensions:(80, 24) ~width_of
    owner (char_key '2') in
  require (Daily_pace.preset owner_30 = Trend.Thirty_days) "preset-switches-to-30d";

  let owner_month, _ = Daily_pace.handle ~blocked:false ~book ~measure:"jpy" ~daily_pace_tsv:pool_tsv
    ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today ~dimensions:(80, 24) ~width_of
    owner_30 (char_key '3') in
  require (Daily_pace.preset owner_month = Trend.Month) "preset-switches-to-month";

  let owner_cycle, _ = Daily_pace.handle ~blocked:false ~book ~measure:"jpy" ~daily_pace_tsv:pool_tsv
    ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today ~dimensions:(80, 24) ~width_of
    owner_month (char_key '4') in
  require (Daily_pace.preset owner_cycle = Trend.Cycle) "preset-switches-to-cycle";

  (* 4. Toggle detail pane *)
  let owner_detail, _ = Daily_pace.handle ~blocked:false ~book ~measure:"jpy" ~daily_pace_tsv:pool_tsv
    ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today ~dimensions:(80, 24) ~width_of
    owner_cycle (char_key 'i') in
  require (Daily_pace.pane owner_detail = `Detail) "i-opens-detail";

  let owner_back, _ = Daily_pace.handle ~blocked:false ~book ~measure:"jpy" ~daily_pace_tsv:pool_tsv
    ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today ~dimensions:(80, 24) ~width_of
    owner_detail (key `Escape) in
  require (Daily_pace.pane owner_back = `Calendar) "esc-returns-to-calendar";

  (* 5. What-if simulation form *)
  let owner_what_if, _ = Daily_pace.handle ~blocked:false ~book ~measure:"jpy" ~daily_pace_tsv:pool_tsv
    ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today ~dimensions:(80, 24) ~width_of
    owner (char_key 'w') in
  require (Daily_pace.has_overlay owner_what_if) "w-opens-what-if";
  require (Daily_pace.active_form owner_what_if <> None) "what-if-has-form";

  let owner_what_if_esc, _ = Daily_pace.handle ~blocked:false ~book ~measure:"jpy" ~daily_pace_tsv:pool_tsv
    ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today ~dimensions:(80, 24) ~width_of
    owner_what_if (key `Escape) in
  require (not (Daily_pace.has_overlay owner_what_if_esc)) "what-if-esc-closes";

  (* 6. Pool configuration editor *)
  let owner_pool, _ = Daily_pace.handle ~blocked:false ~book ~measure:"jpy" ~daily_pace_tsv:pool_tsv
    ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today ~dimensions:(80, 24) ~width_of
    owner (char_key 'c') in
  require (Daily_pace.has_overlay owner_pool) "c-opens-pool-editor";

  let owner_pool_esc, _ = Daily_pace.handle ~blocked:false ~book ~measure:"jpy" ~daily_pace_tsv:pool_tsv
    ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today ~dimensions:(80, 24) ~width_of
    owner_pool (key `Escape) in
  require (not (Daily_pace.has_overlay owner_pool_esc)) "pool-esc-closes";

  (* 7. Cycle boundaries editor *)
  let owner_cycle_ed, _ = Daily_pace.handle ~blocked:false ~book ~measure:"jpy" ~daily_pace_tsv:pool_tsv
    ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today ~dimensions:(80, 24) ~width_of
    owner (char_key 'b') in
  require (Daily_pace.has_overlay owner_cycle_ed) "b-opens-cycle-editor";

  let owner_cycle_esc, _ = Daily_pace.handle ~blocked:false ~book ~measure:"jpy" ~daily_pace_tsv:pool_tsv
    ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today ~dimensions:(80, 24) ~width_of
    owner_cycle_ed (key `Escape) in
  require (not (Daily_pace.has_overlay owner_cycle_esc)) "cycle-esc-closes";

  (* 8. Screen rendering in 3 dimensions *)
  let scr_stacked = Daily_pace.screen ~book ~measure:"jpy" ~daily_pace_tsv:pool_tsv
    ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today ~dimensions:(80, 24) ~width_of owner in
  require (List.length scr_stacked = 24) "screen-stacked-24";

  let scr_split = Daily_pace.screen ~book ~measure:"jpy" ~daily_pace_tsv:pool_tsv
    ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today ~dimensions:(120, 36) ~width_of owner in
  require (List.length scr_split = 36) "screen-split-36";

  let scr_tiny = Daily_pace.screen ~book ~measure:"jpy" ~daily_pace_tsv:pool_tsv
    ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today ~dimensions:(32, 9) ~width_of owner in
  require (List.length scr_tiny = 9) "screen-tiny-9";

  (* 9. Screen rendering fail-closed on missing pool *)
  let scr_missing = Daily_pace.screen ~book ~measure:"jpy" ~daily_pace_tsv:(Ok None)
    ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today ~dimensions:(80, 24) ~width_of owner in
  require (List.exists (fun (_, text) -> Base.String.is_substring text ~substring:"unavailable") scr_missing)
    "missing-pool-fails-closed";

  (* 10. Footer formatting *)
  let ft = Daily_pace.footer ~dimensions:(80, 24) ~width_of owner in
  require (List.length ft = 2) "footer-has-2-lines";
  (* Pool edits preserve admission and the original compare-and-write base. *)
  let step ?(config = pool_tsv) ?(blocked = false) ?(dimensions = (80, 24)) state input =
    Daily_pace.handle ~blocked ~book ~measure:"jpy" ~daily_pace_tsv:config
      ~boundary_presets_tsv:presets_tsv ~annual_bounds:None ~today ~dimensions ~width_of state input
  in
  let form state = Option.get (Daily_pace.active_form state) in
  let edit value =
    let opened, _ = step (Daily_pace.create ()) (char_key 'c') in
    let updated = Form.set_text (form opened) "pool_loci" value
      |> fun f -> Form.set_focused f 1 in
    Daily_pace.set_pool_form updated opened
  in
  List.iter (fun value ->
    let refused, command = step (edit value) (key `Enter) in
    require (command = Daily_pace.Stay && Form.id (form refused) = "configure_daily_pace"
      && Form.notice (form refused) <> "") ("pool-refuses-" ^ value))
    [ ""; "wallet,wallet"; "unknown"; "wallet,"; "wallet bank" ];
  let changed = Ok (Some "food\tjpy\n") in
  let review, command = step ~config:changed (edit "bank") (key `Enter) in
  require (command = Daily_pace.Stay && Form.id (form review) = "review_pool")
    "pool-review-does-not-write";
  let _, command = step ~config:changed review (key `Enter) in
  require (match command with
    | Daily_pace.Save_pool { expected = Some before; content } ->
        before = "wallet\tjpy\n" && content = "bank\tjpy\n"
    | _ -> false) "pool-save-carries-original-base-despite-external-change";
  List.iter (fun dimensions ->
    let refused, command = step ~dimensions review (key `Enter) in
    require (command = Daily_pace.Stay && Daily_pace.has_overlay refused)
      "pool-tiny-refuses-save") [ (48, 14); (32, 9) ];
  let refused, command = step ~blocked:true review (key `Enter) in
  require (command = Daily_pace.Stay && Daily_pace.has_overlay refused)
    "pool-blocked-refuses-save";
  let returned, command = step review (key `Escape) in
  require (command = Daily_pace.Stay && Form.get_text (form returned) "pool_loci" = Some "bank")
    "pool-review-cancel-retains-draft";
  print_endline "PASS: Daily Pace vertical owner pure unit verification (state, query, motion, overlays, screen)."

let self_check ~width_of ~directory:_ =
  unit_checks ~width_of ()
