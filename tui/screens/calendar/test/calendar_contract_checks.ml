(* Pure owner checks for legacy contracts that are easy to change during extraction. *)
module C = Calendar_home_screen
module B = Bakhlo_sexp.Daily_book
let require condition name = if not condition then failwith name
let get = function Ok x -> x | Error why -> failwith why
let book = get (B.of_string
  "(bakhlo-daily 3)\n(scope corrected-entries explicit-plans)\n(measures (measure \"jpy\" 0))\n(labels (not-supplied))\n(approved-loci (not-supplied))\n(entries)\n(plans)\n(support (zero-origin) (openings) (observations) (presence (not-supplied)))\n")
let env = Screen.env_for_checks ~book ~measure:"jpy" ~today:"2026-10-18" ()
let geometry : Screen.geometry = { screen = (80,24); body = (80,21); content = (80,19); width_of = String.length }
let press ?(mods=[]) env owner key = C.handle env geometry owner (`Key (key,mods))
let () =
  let home = C.create () in
  let searched, _ = press env home (`ASCII '/') in
  let searched, _ = press env searched (`ASCII 'x') in
  require (C.modal searched && (C.browser searched).query = "") "home-search-deferred";
  List.iter (fun c -> let after, request = press ~mods:[`Ctrl] env searched (`ASCII c) in
    require (after = searched && request = Screen.Stay) "calendar-search-consumes-control") ['q';'r';'n'];
  let accepted, _ = press env searched `Enter in
  let calendar = C.entered Screen.Calendar ~focus_day:env.today accepted in
  require ((C.browser calendar).query = "x") "home-search-retained-by-calendar";
  let year = { env with calendar = { env.calendar with zoom = Daily_calendar.Year } } in
  let _, escape = press year calendar `Escape in
  require (match escape with Screen.Set_calendar { calendar; clear_message = false } -> calendar.zoom = Daily_calendar.Month | _ -> false)
    "calendar-escape-zoom-preserves-feedback";
  let _, quit = press year calendar (`ASCII 'q') in
  require (quit = Screen.Open_route Screen.Home) "calendar-q-home-at-year";
  let detail, _ = press year calendar `Tab in
  let first_back, request = press year detail `Escape in
  require (not (C.detail_focused first_back) && request = Screen.Stay) "calendar-detail-escape-before-zoom";
  let page, _ = press env detail (`Page `Down) in
  require (C.detail_focused page && C.scroll page = 16) "calendar-detail-page-uses-screen-height";
  let ended, _ = press env detail `End in
  require (C.scroll ended = max_int / 4) "calendar-end-retains-raw-offset";
  let jump, _ = press env detail (`ASCII '/') in
  let invalid, _ = press env jump (`ASCII 'x') in
  let refused, request = press env invalid `Enter in
  require (not (C.modal refused) && C.detail_focused refused && (match request with Screen.Message _ -> true | _ -> false))
    "calendar-invalid-jump-closes-and-retains-focus";
  let browser = { (C.browser calendar) with selected = 7; selected_id = Some (Record_browser.Actual_row,"prior") } in
  let calendar = C.with_browser calendar browser in
  let entered_day = C.entered (Screen.Selected_day env.today) ~focus_day:env.today calendar in
  let retained = C.synchronize ~route:(Screen.Selected_day env.today) ~book ~calendar:env.calendar entered_day in
  require (C.browser retained = browser) "calendar-selected-day-keeps-browser";
  let returned = C.entered Screen.Actual ~focus_day:env.today retained in
  require (C.browser returned = browser && not (C.detail_focused returned)) "calendar-drill-return-notifies-without-sync";
  let home_reset = C.synchronize ~route:Screen.Home ~book ~calendar:env.calendar
      (C.entered Screen.Home ~focus_day:env.today calendar) in
  require ((C.browser home_reset).selected = 0 && (C.browser home_reset).selected_id = None
           && (C.browser home_reset).query = "x") "calendar-home-entry-resets-selection-only";
  let cleared = C.synchronize ~route:Screen.Actual ~book ~calendar:env.calendar calendar in
  require ((C.browser cleared).selected = 0 && (C.browser cleared).selected_id = None && (C.browser cleared).query = "x")
    "calendar-external-route-resets-selection-only";
  let view = C.view env geometry home in

  require (List.length (Lazy.force view.rows) = snd geometry.body) "home-owner-uses-entire-headerless-body"
