(* Trend / Locus owner checks: focus-day capture, grain and scope keys, selection
   clamping and containment, inline series picker, session annotations, modal
   closing and stale-config/book requery. Synthetic books only. *)
module B = Bakhlo_sexp.Daily_book
module R = Trend_locus_report
module S = Trend_locus_screen
module Roles = Locus_roles

let get = function Ok x -> x | Error why -> failwith why
let require condition why = if not condition then failwith why
let z = Z.of_int
let coord locus measure : R.coordinate = { locus; measure }

let header =
  "(bakhlo-daily 1) (scope corrected-entries explicit-plans)\n\
   (measures (measure jpy 0) (measure eur 2))\n\
   (labels (not-supplied)) (approved-loci (provided a b c delta epsilon gamma))\n\
   (entries\n"

let footer =
  ")\n\
   (plans)\n\
   (support (zero-origin (a jpy) (b jpy)) (openings) (observations) (presence (not-supplied)))\n"

let posting locus n = Printf.sprintf "(posting %s jpy %s (none))" locus (Z.to_string n)
let ab n = posting "a" n ^ " " ^ posting "b" (Z.neg n)

let row id day postings =
  Printf.sprintf " (entry %s (date %s) (memo (none)) (postings %s) (reversal-of (none)))\n" id day
    postings

let rows =
  row "sep" "2026-09-30" (ab (z 900))
  ^ row "oct1" "2026-10-01" (ab (z 5))
  ^ row "oct2" "2026-10-02" (ab (z (-2)))
  ^ row "oct3" "2026-10-03" (ab (z (-4)))
  ^ row "oct4" "2026-10-04" (ab (z 100))

let make_book extra = get (B.of_string (header ^ rows ^ extra ^ footer))
let book = make_book ""
let changed_book = make_book (row "extra" "2026-10-02" (ab (z 10)))
let boundaries = "household\t2026-10-01\t2026-10-03\t2026-11-01\n"
let long_boundaries = "long\t2026-08-01\t2026-11-01\n"

let env_with ?(book = book) ?(measure = "jpy") boundaries =
  Screen.env_for_checks
    ~accounting_roles:[ ("a", Roles.Expense); ("b", Roles.Expense) ]
    ~config:(fun name ->
      if List.mem name S.config_files then Ok (Some boundaries) else Error ("undeclared " ^ name))
    ~book ~measure ~today:"2040-01-01" ()

let geometry : Screen.geometry =
  { screen = (100, 30); body = (100, 27); content = (100, 25); width_of = String.length }

let press env owner key = S.handle env geometry owner (`Key (key, []))
let press_with env owner key mods = S.handle env geometry owner (`Key (key, mods))
let after env owner key = fst (press env owner key)

let press_n env owner key count =
  let rec loop owner count = if count <= 0 then owner else loop (after env owner key) (count - 1) in
  loop owner count

let type_chars env owner text =
  let rec loop owner index =
    if index >= String.length text then owner
    else loop (after env owner (`ASCII text.[index])) (index + 1)
  in
  loop owner 0

let first_series (snap : R.snapshot) = snap.R.series.(0)
let point_of (snap : R.snapshot) index = (first_series snap).R.points.(index)
let total (snap : R.snapshot) index = (point_of snap index).R.total

let () =
  let env = env_with boundaries in
  let owned = S.enter ~focus_day:"2026-10-03" (S.create ()) in
  let snapshot = get (S.result env owned) in
  require
    (snapshot.R.observed_at = "2026-10-03" && snapshot.R.scope_end_exclusive = "2026-10-04")
    "the chart observes the focused day, not env.today";
  require
    (S.grain owned = R.Cycle && S.scope owned = R.All_history)
    "the initial grain is an all-history cycle";
  require (S.selected env owned = 1) "the initial selection is the last point";
  require (Result.is_error (S.result env (S.create ()))) "an unfocused chart has no clock fallback";
  let starting_period = S.selected_period owned in
  let starting_index = S.selected env owned in

  (* Default series: the Expense-role Loci with the most entries in the history. *)
  let busy_book =
    make_book (row "busy" "2026-10-02" (posting "b" (z 1) ^ " " ^ posting "c" (z (-1))))
  in
  let busy_env = env_with ~book:busy_book boundaries in
  let busy = S.enter ~focus_day:"2026-10-03" (S.create ()) in
  let defaults = S.coordinates busy_env busy in
  require
    (match defaults with
    | coordinate :: _ -> coordinate.R.locus = "b" && coordinate.R.measure = "jpy"
    | [] -> false)
    "default series start with the busiest Expense Locus";
  require (List.length defaults <= 3) "at most three default series";

  (* [?] opens the help overlay that now holds the disclaimers. *)
  let help = after env owned (`ASCII '?') in
  require (S.modal help) "the help overlay is modal";
  let help_closed = after env help `Escape in
  require (not (S.modal help_closed)) "Esc closes the help overlay";

  (* The chart is braille, starts at a zero axis row and names the window ends. *)
  let painted = (S.view env geometry owned).Screen.rows |> Lazy.force in
  let is_braille = function
    | `Uchar u -> let n = Uchar.to_int u in n >= 0x2800 && n <= 0x28FF
    | `Malformed _ -> false
  in
  let has_braille =
    List.exists
      (fun (_, text) -> Uutf.String.fold_utf_8 (fun found _ c -> found || is_braille c) false text)
      painted
  in
  require has_braille "the chart paints braille cells";
  let contains text needle =
    let length = String.length needle in
    let rec loop index =
      index + length <= String.length text
      && (String.sub text index length = needle || loop (index + 1))
    in
    length = 0 || loop 0
  in
  let window_start =
    match get (S.result env owned) with
    | snap ->
        let points = (first_series snap).R.points in
        if Array.length points = 0 then "" else String.sub points.(0).R.start_day 5 5
  in
  require
    (window_start <> "" && List.exists (fun (_, text) -> contains text window_start) painted)
    "the x axis names the window start";
  require
    (List.exists (fun (_, text) -> contains text " jpy") painted)
    "series values name the Measure";
  ignore (S.view env geometry owned);
  ignore (S.result env owned);
  ignore (after env owned `End);
  require
    (S.selected_period owned = starting_period && S.selected env owned = starting_index)
    "viewing and navigating never mutate an older owner's selection";

  (* Grain and scope keys. *)
  require (S.grain (after env owned (`ASCII '[')) = R.Cycle) "coarser clamps at cycle";
  let month = after env owned (`ASCII ']') in
  require (S.grain month = R.Month) "] selects the finer month grain";
  let day = after env month (`ASCII ']') in
  require (S.grain day = R.Day) "] selects the finer day grain";
  require (S.grain (after env day (`ASCII ']')) = R.Day) "finer clamps at day";
  let cycle_scope = after env day (`ASCII 's') in
  require (S.scope cycle_scope = R.Current_cycle) "s rotates to the current cycle";
  let monthly = after env cycle_scope (`ASCII 's') in
  require (S.scope monthly = R.Current_month) "s rotates to the current month";
  let non_day = after env monthly (`ASCII '[') in
  require
    (S.grain non_day = R.Month && S.scope non_day = R.All_history)
    "leaving the day grain reports the effective all-history scope";
  let non_day_s = after env non_day (`ASCII 's') in
  require (S.scope non_day_s = R.All_history) "day scopes are a no-op outside the day grain";
  let non_day_S = after env non_day_s (`ASCII 'S') in
  require (S.scope non_day_S = R.All_history) "S is also a no-op outside the day grain";
  let remembered = after env non_day_S (`ASCII ']') in
  require
    (S.grain remembered = R.Day && S.scope remembered = R.Current_month)
    "returning to the day grain restores the remembered day scope";
  let last30 = after env monthly (`ASCII 's') in
  require (S.scope last30 = R.Last_30_days) "s rotates to the last 30 days";
  let all = after env last30 (`ASCII 's') in
  require (S.scope all = R.All_history) "s wraps back to all history";
  let reverse = after env all (`ASCII 'S') in
  require (S.scope reverse = R.Last_30_days) "S rotates the day scope backward";
  let reverse_again = after env reverse (`ASCII 'S') in
  require (S.scope reverse_again = R.Current_month) "S keeps rotating backward";

  (* Selection movement. *)
  let ended = after env owned `End in
  require (S.selected env ended = 1) "End selects the last point";
  require (S.selected env (after env ended (`Arrow `Down)) = 1) "next clamps at the last point";
  let started = after env ended `Home in
  require (S.selected env started = 0) "Home selects the first point";
  require (S.selected env (after env started (`Arrow `Up)) = 0) "previous clamps at the first point";
  require (S.selected env (after env started (`Arrow `Right)) = 1) "next advances the selection";

  (* A grain change keeps the period that contains the old one. *)
  let long_env = env_with long_boundaries in
  let capture = after long_env (S.enter ~focus_day:"2026-10-03" (S.create ())) (`ASCII ']') in
  let capture_snapshot = get (S.result long_env capture) in
  require
    (S.grain capture = R.Month
    && (first_series capture_snapshot).R.points.(0).R.start_day = "2026-08-01"
    && S.selected long_env capture = 0)
    "the first grain change captures the effective last-point start";
  let long = S.enter ~focus_day:"2026-10-03" (S.create ()) in
  let long = after long_env (after long_env long (`ASCII ']')) (`ASCII ']') in
  require (S.grain long = R.Day) "the containment check runs in the day grain";
  let sep10 = press_n long_env (after long_env long `Home) (`Arrow `Down) 40 in
  require (S.selected long_env sep10 = 40) "the long day history selects 2026-09-10";
  let month = after long_env sep10 (`ASCII '[') in
  let month_snapshot = get (S.result long_env month) in
  require
    (S.grain month = R.Month
    && Array.length (first_series month_snapshot).R.points = 3
    && S.selected long_env month = 1)
    "changing grain keeps the containing September period";
  let round_trip = after long_env month (`ASCII ']') in
  require
    (S.selected long_env round_trip = 31)
    "the month capture locates its first day when the grain becomes finer";
  let crossing_env = env_with "cross\t2026-09-15\t2026-10-15\t2026-11-15\n" in
  let crossing = after crossing_env (S.enter ~focus_day:"2026-10-03" (S.create ())) `Home in
  let crossing_month = after crossing_env crossing (`ASCII ']') in
  let crossing_snapshot = get (S.result crossing_env crossing_month) in
  require
    (S.grain crossing_month = R.Month
    && (first_series crossing_snapshot).R.points.(0).R.start_day = "2026-09-15"
    && S.selected crossing_env crossing_month = 0)
    "a cycle crossing months locates the bucket containing its start";

  (* Inline series picker. *)
  let plotted = List.length (S.coordinates env owned) in
  let picker = after env owned (`ASCII 'a') in
  require (S.picker_open picker) "a opens the inline series picker";
  require (S.picker_target picker = Some plotted) "the picker targets the next empty slot";
  let gap = after env picker (`ASCII '5') in
  require
    (S.picker_target gap = Some plotted
    && S.picker_open gap
    && S.coordinates env gap = S.coordinates env picker)
    "a gap slot is refused and keeps the actual target";
  require (S.picker_cursor gap = Some 0) "a refused slot keeps the candidate cursor";
  let wrapped = after env picker (`Arrow `Up) in
  require (S.picker_cursor wrapped = Some 5) "picker movement wraps to the last candidate";
  let wrapped_back = after env wrapped (`Arrow `Down) in
  require (S.picker_cursor wrapped_back = Some 0) "picker movement wraps to the first candidate";
  let chosen = after env gap (`ASCII '2') in
  require (S.picker_target chosen = Some 1) "an occupied slot can be targeted";
  let gap_again = after env chosen (`ASCII '5') in
  require
    (S.picker_target gap_again = Some 1 && S.picker_open gap_again)
    "a gap slot never replaces the chosen target";
  let duplicate, duplicate_request = press env picker `Enter in
  require
    (S.picker_open duplicate && duplicate_request = Screen.Stay
    && S.coordinates env duplicate = S.coordinates env owned)
    "Enter applies the chosen catalog coordinate to the next empty slot";
  let catalog = S.catalog env owned in
  let catalog_index locus =
    match List.find_index (fun (c : R.coordinate) -> c.R.locus = locus) catalog with
    | Some index -> index
    | None -> failwith ("catalog is missing " ^ locus)
  in
  let choose name state =
    let opened = after env state (`ASCII 'a') in
    after env (press_n env opened (`Arrow `Down) (catalog_index name)) `Enter
  in
  let added = choose "delta" owned in
  require
    ((not (S.picker_open added))
    && List.length (S.coordinates env added) = plotted + 1
    && List.nth (S.coordinates env added) plotted = coord "delta" "jpy")
    "Enter applies the chosen catalog coordinate to the next empty slot";
  let added5 = choose "gamma" added in
  require
    (List.length (S.coordinates env added5) = plotted + 2
    && List.mem (coord "gamma" "jpy") (S.coordinates env added5))
    "a fifth coordinate fills the last slot";
  let full = choose "c" added5 in
  require (List.length (S.coordinates env full) = 5) "a fifth coordinate fills the last slot";
  let replaced = choose "epsilon" full in
  require
    (List.length (S.coordinates env replaced) = 5
    && List.nth (S.coordinates env replaced) 0 = coord "epsilon" "jpy")
    "five series replace an occupied slot instead of adding a sixth";
  let picker_remove = after env owned (`ASCII 'a') in
  let removed = after env picker_remove (`ASCII 'x') in
  require
    ((not (S.picker_open removed)) && List.length (S.coordinates env removed) = plotted - 1)
    "x removes the next empty slot's last occupied series";
  let one_left = after env (after env removed (`ASCII 'a')) (`ASCII 'x') in
  require
    (List.length (S.coordinates env one_left) = 1)
    "removal keeps the last plotted series";
  let picker_keep = after env one_left (`ASCII 'a') in
  let kept, kept_request = press env picker_keep (`ASCII 'x') in
  require
    (S.picker_open kept && kept_request = Screen.Stay && List.length (S.coordinates env kept) = 1)
    "the last plotted series cannot be removed";
  let closed, closed_request = press env picker_keep (`ASCII 'q') in
  require ((not (S.picker_open closed)) && closed_request = Screen.Stay) "q closes only the picker";
  let escaped, escaped_request = press env picker_keep `Escape in
  require
    ((not (S.picker_open escaped)) && escaped_request = Screen.Stay)
    "Esc closes only the picker";
  let eur_env = env_with ~measure:"eur" boundaries in
  let inherited = get (S.result eur_env added) in
  require (inherited.R.measure = "jpy") "an explicit series selection keeps its common measure";
  let eur_picker = after eur_env added (`ASCII 'a') in
  let eur_added = after eur_env (press_n eur_env eur_picker (`Arrow `Down) 4) `Enter in
  require
    (List.length (S.coordinates env eur_added) = plotted + 2
    && List.nth (S.coordinates env eur_added) (plotted + 1) = coord "epsilon" "jpy")
    "the picker inherits the plotted common measure after a measure change";
  let eur_picker5 = after eur_env replaced (`ASCII 'a') in
  let eur_replaced = after eur_env eur_picker5 `Enter in
  require
    (List.length (S.coordinates env eur_replaced) = 5
    && List.nth (S.coordinates env eur_replaced) 0 = coord "epsilon" "jpy")
    "the picker replaces with the plotted common measure too";

  (* Session annotations. *)
  let day_owner = after env (after env owned (`ASCII ']')) (`ASCII ']') in
  require (S.grain day_owner = R.Day) "the annotation checks run in the day grain";
  let cycle_editor = after env owned (`ASCII 'o') in
  require
    ((not (S.editor_open cycle_editor)) && S.overlay_count cycle_editor = 0)
    "o outside the day grain refuses instead of mutating";
  let editor = after env day_owner (`ASCII 'o') in
  require
    (S.editor_open editor && S.editor_field editor = `Name && S.editor_name editor = "")
    "o opens an empty annotation editor";
  let empty_enter = after env editor `Enter in
  require
    (S.editor_open empty_enter
    && S.editor_field empty_enter = `Name
    && S.overlay_count empty_enter = 0)
    "Enter never advances an empty annotation name";
  let typed = type_chars env editor "rent" in
  require (S.editor_name typed = "rent") "printable input lands in the annotation name";
  let typed_q, typed_q_request = press env typed (`ASCII 'q') in
  require
    (S.editor_name typed_q = "rentq" && typed_q_request = Screen.Stay && S.modal typed_q)
    "q types into the modal instead of leaving";
  let deleted = after env typed_q `Backspace in
  require (S.editor_name deleted = "rent") "backspace deletes one character";
  let unicode = after env deleted (`Uchar (Uchar.of_int 0x3042)) in
  require (S.editor_name unicode = "rent\227\129\130") "a Unicode character is retained";
  let unicode_deleted = after env unicode `Backspace in
  require (S.editor_name unicode_deleted = "rent") "backspace removes a whole Unicode character";
  let days_field = after env unicode_deleted `Tab in
  require (S.editor_field days_field = `Days) "Tab moves to the days field";
  require
    (S.editor_field (fst (press_with env days_field `Tab [ `Shift ])) = `Name)
    "Shift-Tab moves back to the name field";
  require
    (snd (press_with env days_field `Tab [ `Shift ]) = Screen.Stay)
    "field switching stays in the modal";
  let bad_chars = type_chars env days_field "1;2" in
  let refused, refused_request = press env bad_chars `Enter in
  require
    (S.editor_open refused && S.overlay_count refused = 0 && refused_request = Screen.Stay)
    "only space, comma and dot separate day numbers";
  require
    (S.editor_days refused = "1;2")
    "an invalid separator keeps the entered text instead of selecting another day";
  let cancelled, cancelled_request = press env refused `Escape in
  require
    ((not (S.editor_open cancelled))
    && S.overlay_count cancelled = 0
    && cancelled_request = Screen.Stay)
    "Esc cancels the annotation without committing";
  let editor = type_chars env (after env day_owner (`ASCII 'o')) "rent" in
  let editor = after env editor `Enter in
  require (S.editor_field editor = `Days) "Enter moves from the name to the days field";
  let committed = after env (type_chars env editor "1,2 3.4") `Enter in
  require
    ((not (S.editor_open committed)) && S.overlay_count committed = 1)
    "a valid annotation commits";
  require
    (S.overlays committed = [ ("2026-10", "rent", [ 1; 2; 3; 4 ]) ])
    "day numbers parse across space, comma and dot separators in entered order";
  let editor = type_chars env (after env committed (`ASCII 'o')) "x" in
  let editor = type_chars env (after env editor `Enter) "32" in
  let out_of_month = after env editor `Enter in
  require
    (S.editor_open out_of_month && S.overlay_count out_of_month = 1)
    "a day past the month's real length is refused";
  let cleared = after env (after env out_of_month `Backspace) `Backspace in
  let zero = after env (type_chars env cleared "0") `Enter in
  require (S.editor_open zero && S.overlay_count zero = 1) "day zero is refused";
  let long_digits = String.make 96 '1' in
  let big_days =
    type_chars env
      (after env (type_chars env (after env day_owner (`ASCII 'o')) "big") `Enter)
      long_digits
  in
  let huge_refused = after env big_days `Enter in
  require
    (S.editor_open huge_refused
    && S.editor_days huge_refused = long_digits
    && S.overlay_count huge_refused = 0)
    "a 96-digit day number is refused and its text retained";
  let cancelled = after env zero `Escape in
  require
    (S.overlay_count cancelled = 1 && not (S.editor_open cancelled))
    "cancelling keeps committed annotations";
  let add_overlay env owner name days =
    let owner = type_chars env (after env owner (`ASCII 'o')) name in
    after env (type_chars env (after env owner `Enter) days) `Enter
  in
  let three = add_overlay env (add_overlay env committed "two" "2") "three" "3" in
  require (S.overlay_count three = 3) "three session annotations are allowed";
  let fourth = after env three (`ASCII 'o') in
  require
    ((not (S.editor_open fourth)) && S.overlay_count fourth = 3)
    "a fourth annotation is refused";
  let guided = after env three (`ASCII 'v') in
  require (S.guides guided <> S.guides three) "v toggles the session guides";
  let cleared = after env guided (`ASCII 'O') in
  require
    (S.overlay_count cleared = 0 && (not (S.guides cleared)) && S.grain cleared = R.Day)
    "O clears only session annotations and guides";

  (* An annotation keeps the month captured when it was committed. *)
  let month_owner =
    after long_env
      (after long_env (S.enter ~focus_day:"2026-10-03" (S.create ())) (`ASCII ']'))
      (`ASCII ']')
  in
  require (S.grain month_owner = R.Day) "the month capture check runs in the day grain";
  let oct_editor =
    type_chars long_env (after long_env (after long_env month_owner `End) (`ASCII 'o')) "oct"
  in
  let oct_committed =
    after long_env (type_chars long_env (after long_env oct_editor `Enter) "1") `Enter
  in
  require
    (S.overlays oct_committed = [ ("2026-10", "oct", [ 1 ]) ])
    "an annotation captures the month of its selected day";
  let september_day = press_n long_env (after long_env oct_committed `Home) (`Arrow `Down) 40 in
  require
    (S.overlays september_day = S.overlays oct_committed && S.overlay_count september_day = 1)
    "a captured annotation keeps its month and is not repeated after navigation";
  let sep_editor = type_chars long_env (after long_env september_day (`ASCII 'o')) "sep" in
  let sep_committed =
    after long_env (type_chars long_env (after long_env sep_editor `Enter) "2") `Enter
  in
  require
    (S.overlays sep_committed = [ ("2026-10", "oct", [ 1 ]); ("2026-09", "sep", [ 2 ]) ])
    "annotations keep their captured month and are not repeated across months";
  let year_env = env_with "years\t2025-10-01\t2026-01-01\t2026-11-01\n" in
  let year_owner =
    after year_env
      (after year_env (S.enter ~focus_day:"2026-10-03" (S.create ())) (`ASCII ']'))
      (`ASCII ']')
  in
  require (S.grain year_owner = R.Day) "the cross-year capture check runs in the day grain";
  let old_editor =
    type_chars year_env (after year_env (after year_env year_owner `Home) (`ASCII 'o')) "old"
  in
  let old_committed =
    after year_env (type_chars year_env (after year_env old_editor `Enter) "1") `Enter
  in
  require
    (S.overlays old_committed = [ ("2025-10", "old", [ 1 ]) ])
    "an annotation in the previous year's October keeps its year";
  let new_editor =
    type_chars year_env (after year_env (after year_env old_committed `End) (`ASCII 'o')) "new"
  in
  let new_committed =
    after year_env (type_chars year_env (after year_env new_editor `Enter) "1") `Enter
  in
  require
    (S.overlays new_committed = [ ("2025-10", "old", [ 1 ]); ("2026-10", "new", [ 1 ]) ])
    "the same calendar month in two years stays distinct";

  (* Leaving and modal closing. *)
  let _, quit_request = press env owned (`ASCII 'q') in
  require (quit_request = Screen.Home) "q outside a modal returns Home";
  let _, escape_request = press env owned `Escape in
  require (escape_request = Screen.Home) "Esc outside a modal returns Home";

  (* Requery never keeps a stale chart. *)
  require (Z.equal (total snapshot 0) (z 3)) "the first cycle window totals the recorded effects";
  let broken =
    Screen.env_for_checks
      ~config:(fun _ -> Error "boundary presets unreadable")
      ~book ~measure:"jpy" ~today:"2040-01-01" ()
  in
  require (Result.is_error (S.result broken owned)) "a config read failure clears the chart";
  (* An unreadable accounting-roles.tsv refuses the default series by name; an
     explicit series does not need the roles. *)
  let roles_broken =
    { env with Screen.accounting_roles = lazy (Error "accounting-roles.tsv is malformed") }
  in
  (match S.result roles_broken owned with
  | Ok _ -> failwith "a roles read failure must clear the default chart"
  | Error why ->
      require (contains why "accounting-roles.tsv") "the refusal names accounting-roles.tsv");
  let roles_picker = after roles_broken owned (`ASCII 'a') in
  let roles_explicit =
    after roles_broken (press_n roles_broken roles_picker (`Arrow `Down) 3) `Enter
  in
  require
    (Result.is_ok (S.result roles_broken roles_explicit))
    "an explicit series does not need the roles file";
  let malformed =
    Screen.env_for_checks
      ~config:(fun _ -> Ok (Some "not a preset"))
      ~book ~measure:"jpy" ~today:"2040-01-01" ()
  in
  require (Result.is_error (S.result malformed owned)) "a malformed config leaves no stale chart";
  let reloaded = env_with ~book:changed_book boundaries in
  let changed = get (S.result reloaded owned) in
  require
    (Z.equal (total changed 0) (z 13))
    "a changed book requery shows current totals instead of a cached chart";
  let refreshed = get (S.result reloaded (after reloaded owned `Enter)) in
  require (Z.equal (total refreshed 0) (z 13)) "Enter refreshes the projection";
  print_endline
    "PASS: Trend/Locus owner focus capture, grain keys with remembered day scope, selection \
     relocation by prior start, series picker, month-scoped session annotations, modal closing and \
     stale requery."
