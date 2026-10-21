(* Cross-screen, publication, recovery and persistence scenarios through the Shell.
   Each suite owns its scenario; this runner only registers them in order. *)
open Interaction_check_fixture
open Home_integration_checks
open Ui_primitive_checks
open Actual_integration_checks
open Scheduled_integration_checks
open Pace_integration_checks
open Balances_integration_checks

let run ~width_of () =
  Recovery_checks.self_check ();
  let directory = "scratch/english-ui-check-" ^ F.new_id () in
  Unix.mkdir directory 0o700;
  let path = directory ^ "/book.sexp" in
  F.create_copy ~source:Interaction_check_fixture.example_book ~target:path;
  let home = C.initial ~config_home:directory (F.load path) in
  bonsai_home_layout_check ~width_of home;
  home_layout_check ~width_of home;
  theme_check ~width_of ~directory home;
  panel_checks ~width_of ();
  input_checks ~width_of ();
  actual_browsing_checks ~width_of ~directory home;
  scheduled_panel_checks ~width_of ~directory home;
  reversal_checks ~width_of ~directory home;
  date_correction_checks ~width_of ~directory home;
  cancellation_checks ~width_of ~directory home;
  months_checks ~width_of ~directory home;
  coverage_checks ~width_of ~directory home;
  continuation_checks ~width_of ~directory home;
  original_amount_integration_checks ~width_of ~directory ();
  event_merchant_integration_checks ~width_of ~directory ();
  unresolved_enable_checks ~width_of ~directory ();
  quick_capture_integration_checks ~width_of ~directory ();
  daily_pace_trend_fail_closed_checks ~width_of ~directory ();
  daily_pace_today_sample_checks ();
  daily_pace_activity_checks ();
  daily_pace_selection_clamp_checks ~width_of ~directory ();
  daily_pace_graph_render_checks ~width_of ();
  pool_review_checks ~width_of ~directory ();
  balance_display_checks ~width_of ~directory ();
  balance_picker_checks ~width_of ~directory ();
  observe_multi_checks ~width_of ~directory ();
  Publication_integration_checks.run ~width_of ~directory ~path home;
  let form_ja = Form_integration_checks.run ~width_of home in
  Attention_integration_checks.run ~width_of home;
  let exchanged = Setup_integration_checks.run ~width_of ~directory ~path in
  let back_home = Settlement_integration_checks.run ~width_of ~directory ~path exchanged in
  Reports_integration_checks.run ~width_of ~directory back_home;
  Observation_pace_integration_checks.run ~width_of ~directory back_home;
  Form_integration_checks.cursor_checks ~width_of home form_ja;
  Sidecar_integration_checks.safety_checks ~width_of ~directory ();
  print_endline
    "PASS: English Calendar / Commands / Record / child navigation / exact cold save and safety \
     guards.";
  Scheduled_bulk_checks.self_check ~width_of ();
  Scheduled_generation_checks.self_check ~width_of ()
