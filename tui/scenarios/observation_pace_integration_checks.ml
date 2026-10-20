(* Synthetic controller integration checks; see docs/RECONSTRUCTION_TEST_MAP.ja.md. *)
open Interaction_check_fixture

open Balances_integration_checks

let run ~width_of ~directory (back_home : C.state) =
  let pace_path = directory ^ "/daily-pace.tsv" in
  let windows_path = directory ^ "/boundary-presets.tsv" in
  (* Observe Quantities: open writes nothing; invalid input refused with a
     notice; cancel closes; valid observations land and persist. *)
  let q_before = b2_check_qty back_home.C.session.book "wallet" "jpy" in
  let obs_modal = key ~width_of back_home (`ASCII 'o') in
  require (b2_overlay_open obs_modal) "observe-modal-opens";
  let form_obs =
    match visible_form obs_modal with
    | Some f -> f
    | None -> failwith "expected modal form for observe_quantity" in
  let invalid_form = Ui_form.set_text form_obs "locus" "unknown_card" in
  let invalid_form = Ui_form.set_text invalid_form "amount" "abc" in
  let invalid_form = Ui_form.set_focused invalid_form 2 in
  let invalid_state =
    match H.handle ~width_of (with_visible_form obs_modal invalid_form) (`Key (`Enter, [])) with
    | Some s -> s
    | None -> failwith "unexpected exit on invalid observe submit" in
  require ((match visible_form invalid_state with Some f -> Ui_form.notice f <> "" | None -> false)
    && b2_check_qty invalid_state.C.session.book "wallet" "jpy" = q_before) "refuses-invalid-observe";
  let cancelled_obs = key ~width_of invalid_state `Escape in
  require (no_modal cancelled_obs) "observe-cancel-escapes";
  let check_qty book locus measure = b2_check_qty book locus measure in
  let observe_one base_state locus amount =
    let st = key ~width_of base_state (`ASCII 'o') in
    let form = match visible_form st with Some f -> f | None -> raise (F.Refused "observe-open") in
    let form = Ui_form.set_text form "locus" locus in
    let form = Ui_form.set_text form "measure" "jpy" in
    let form = Ui_form.set_text form "amount" amount in
    let form = Ui_form.set_focused form (Ui_form.find_field_index form "action") in
    let st = match H.handle ~width_of ~dimensions:(100, 30) (with_visible_form st form) (`Key (`Enter, [])) with
      | Some s -> s | None -> raise (F.Refused "observe-exit") in
    let pick idx s =
      (match visible_form s with
       | Some f ->
           let form = Ui_form.update_field f "action" (function
             | Ui_form.Buttons b -> Ui_form.Buttons { b with selected = idx } | other -> other) in
           let form = Ui_form.set_focused form (Ui_form.find_field_index form "action") in
           (match H.handle ~width_of ~dimensions:(100, 30) (with_visible_form s form) (`Key (`Enter, [])) with
            | Some s -> s | None -> raise (F.Refused "observe-advance"))
       | None -> s) in
    pick 0 (pick 1 st) in
  let observed_state = observe_one back_home "wallet" "5000" in
  require (check_qty observed_state.session.book "wallet" "jpy" = "5000") "wallet-balance-observed-5000";
  let zero_state = observe_one observed_state "bank" "0" in
  require (check_qty zero_state.session.book "bank" "jpy" = "0") "bank-balance-observed-0";
  require (check_qty zero_state.session.book "wallet" "jpy" = "5000") "wallet-balance-retained-5000";
  (* Daily Pace workflow & what-if simulator *)
  (* 1. Navigate to Daily Pace from Home via 'd' *)
  let pace_home = key ~width_of zero_state (`ASCII 'd') in
  require (pace_home.workspace.route = W.Daily_pace) "route-daily-pace";
  (* 2. What-If simulator modal via 'w' *)
  let what_if_state = key ~width_of pace_home (`ASCII 'w') in
  require (not (no_modal what_if_state)) "what-if-modal-opens";
  let sim_res_state = String.fold_left (fun s c -> key ~width_of s (`ASCII c)) what_if_state "2000" in
  let painted =
    Option.value ~default:[] (R.overlay_screen ~dimensions:(120, 36) ~width_of sim_res_state)
    |> List.map snd |> String.concat "\n" in
  require (Base.String.is_substring painted ~substring:"After purchase:") "what-if-result-calculated";
  require (Base.String.is_substring painted ~substring:"Available after:") "what-if-remaining-shown";
  (* Close simulator with Escape without altering ledger *)
  let closed_sim = key ~width_of sim_res_state `Escape in
  require (no_modal closed_sim) "what-if-closed-on-esc";
  require (check_qty closed_sim.session.book "wallet" "jpy" = "5000") "what-if-does-not-alter-ledger";
  (* 3. Configure Daily Pace modal via 'c' *)
  let cfg_state = key ~width_of closed_sim (`ASCII 'c') in
  let form_cfg =
    match visible_form cfg_state with
    | Some f ->
        require (Ui_form.id f = "configure_daily_pace") "cfg-pace-modal-id";
        f
    | None -> failwith "expected cfg modal"
  in
  require (Ui_form.get_text form_cfg "end_date" = None) "period-is-read-only-in-pool-editor";
  let boundaries_before = F.read windows_path in
  (* Invalid/duplicate pool must not save either configuration. *)
  let form_cfg_err = Ui_form.set_text form_cfg "pool_loci" "wallet, wallet" in
  let form_cfg_err = Ui_form.set_focused form_cfg_err 1 in
  let err_state =
    match H.handle ~width_of (with_visible_form cfg_state form_cfg_err) (`Key (`Enter, [])) with
    | Some s -> s
    | None -> failwith "unexpected exit on cfg err submit"
  in
  require
    (F.read pace_path = "wallet\tjpy\n"
    && (match visible_form err_state with Some f ->
         Ui_form.get_text f "pool_loci" = Some "wallet, wallet" | None -> false))
    "cfg-pace-invalid-retains-input-and-config";
  let form_cfg_valid = Ui_form.set_text form_cfg "pool_loci" "wallet, bank" in
  let form_cfg_valid = Ui_form.set_focused form_cfg_valid 1 in
  let reviewed_state =
    match H.handle ~width_of (with_visible_form cfg_state form_cfg_valid) (`Key (`Enter, [])) with
    | Some s -> s
    | None -> failwith "unexpected exit on cfg review"
  in
  require (visible_form_id reviewed_state = Some "review_pool"
    && F.read pace_path = "wallet\tjpy\n") "cfg-pace-review-does-not-save";
  let back_to_edit = key ~width_of reviewed_state `Escape in
  require (visible_form_id back_to_edit = Some "configure_daily_pace"
    && F.read pace_path = "wallet\tjpy\n") "cfg-pace-review-escape-retains-draft";
  let re_reviewed = key ~width_of back_to_edit `Enter in
  require (visible_form_id re_reviewed = Some "review_pool"
    && F.read pace_path = "wallet\tjpy\n") "cfg-pace-re-review-does-not-save";
  let saved_state = key ~width_of re_reviewed `Enter in
  require (no_modal saved_state) "cfg-pace-saved-overlay-cleared";
  require (F.read windows_path = boundaries_before) "pool-editor-preserves-boundaries-byte-exactly";
  require (F.read pace_path = "wallet\tjpy\nbank\tjpy\n") "cfg-pace-saved-bytes";
  let back_home2 = key ~width_of saved_state (`ASCII 'q') in
  (* 4. Cycle boundary setup via 'b' and Commands -> Household setup *)
  let cyc_state = key ~width_of saved_state (`ASCII 'b') in
  let cyc_form = match visible_form cyc_state with
    | Some f ->
        require (Ui_form.id f = "configure_cycle_boundaries") "cyc-boundaries-modal-id";
        f
    | None -> failwith "expected cycle boundaries modal" in
  require (Ui_form.get_text cyc_form "name" = Some "test-cycle") "cyc-loads-active-preset-name";
  let new_stop = get (Cal.shift_days (F.today ()) 14) in
  let cyc_edited =
    with_visible_form cyc_state (Ui_form.set_text cyc_form "dates" (F.today () ^ ", " ^ new_stop)) in
  let cyc_reviewed = key ~width_of (key ~width_of cyc_edited `Enter) `Enter in
  require (F.read windows_path = boundaries_before) "cyc-review-does-not-save";
  let cyc_narrow = key ~dimensions:(48, 14) ~width_of cyc_reviewed `Enter in
  require (F.read windows_path = boundaries_before
           && visible_form_id cyc_narrow = Some "review_cycle_boundaries")
    "cyc-review-hidden-refused";
  let cyc_esc = key ~width_of cyc_narrow `Escape in
  require (visible_form_id cyc_esc = Some "configure_cycle_boundaries"
           && F.read windows_path = boundaries_before)
    "cyc-review-escape-retains-draft";
  let cyc_published = key ~width_of (key ~width_of (key ~width_of cyc_esc `Enter) `Enter) `Enter in
  require (no_modal cyc_published
           && F.read windows_path = "test-cycle\t" ^ F.today () ^ "\t" ^ new_stop ^ "\n")
    "cyc-boundaries-saved";
  let setup_menu = { cyc_published with overlay = C.Commands { M.page = M.Setup; selected = 4 } } in
  let from_cmd = key ~width_of setup_menu `Enter in
  require (visible_form_id from_cmd = Some "configure_cycle_boundaries")
    "commands-setup-opens-cycle-boundaries";
  require (let closed = key ~width_of from_cmd `Escape in
           no_modal closed) "commands-setup-cycle-escapes";
  require (back_home2.workspace.route = W.Home) "pace-q-back-to-home";
  ()
