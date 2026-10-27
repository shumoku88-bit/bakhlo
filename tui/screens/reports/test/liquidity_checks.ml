(* Liquidity: conditional selected-balance outlook over explicitly selected
   balance-view coordinates. Both unconditional statements stay UNKNOWN; numbers
   exist only after an explicitly accepted assumed-complete-through horizon. *)
module B = Bakhlo_household.Daily_book
module R = Liquidity_report
module S = Liquidity_screen

let contains text sub =
  let n = String.length text and m = String.length sub in
  let rec at i = i + m <= n && (String.sub text i m = sub || at (i + 1)) in
  at 0

let get = function Ok x -> x | Error why -> failwith why
let require condition why = if not condition then failwith why
let is_error = Result.is_error
let z n = Z.of_int n

(* Synthetic book construction in book.txt: no household file is ever read. *)
let posting locus measure n = Printf.sprintf "EFFECT\t%s\t%s\t%s\n" locus measure (Z.to_string n)

let entry id day postings =
  Printf.sprintf "TX\t%s\t%s\n%sENDTX\n" id day (String.concat "" postings)

let plan ?paid ?cancelled id day measure changes =
  let change (locus, n) = Printf.sprintf "CHANGE\t%s\t%s\n" locus (Z.to_string n) in
  let ending =
    match (paid, cancelled) with
    | Some tx, _ -> "PAID-BY\t" ^ tx ^ "\n"
    | None, Some day -> "CANCELLED\t" ^ day ^ "\n"
    | None, None -> ""
  in
  Printf.sprintf "PLAN\t%s\t%s\t%s\n%s%sENDPLAN\n" id day measure
    (String.concat "" (List.map change changes))
    ending

let book ?(approved = [ "wallet"; "bank"; "ext"; "ghost" ]) ?support ~entries ~plans () =
  "BOOK\t1\nMEASURE\tjpy\t0\nMEASURE\teur\t2\n"
  ^ String.concat "" (List.map (fun l -> Printf.sprintf "LOCUS\t%s\t%s\t\n" l l) approved)
  ^ entries ^ plans
  ^ Option.value ~default:"ZERO-ORIGIN\twallet\tjpy\nZERO-ORIGIN\tbank\tjpy\n" support
  ^ "END\n"

let read text = Bakhlo_household.Daily_txt.book text
let support_flow = "ZERO-ORIGIN\twallet\tjpy\nZERO-ORIGIN\tbank\tjpy\nZERO-ORIGIN\twallet\teur\n"

(* wallet 1000 jpy, bank 500 jpy: current selected 1500. *)
let flow_entries =
  String.concat ""
    [
      entry "e1" "2026-10-01" [ posting "wallet" "jpy" (z 1000); posting "bank" "jpy" (z (-1000)) ];
      entry "e2" "2026-10-02" [ posting "bank" "jpy" (z 1500); posting "ext" "jpy" (z (-1500)) ];
    ]

let flow_plans =
  String.concat ""
    [
      (* Overdue but an internal transfer: zero selected net is dropped before the
         overdue check. *)
      plan "past_zero" "2026-10-05" "jpy" [ ("wallet", z (-50)); ("bank", z 50) ];
      (* Overdue in another Measure: irrelevant to the selected jpy question. *)
      plan "past_foreign" "2026-10-05" "eur" [ ("wallet", z (-5)); ("ext", z 5) ];
      (* Same-day cross-plan net zero still emits one zero point. *)
      plan "same_day_a" "2026-10-22" "jpy" [ ("wallet", z 70); ("ext", z (-70)) ];
      plan "same_day_b" "2026-10-22" "jpy" [ ("wallet", z (-70)); ("ext", z 70) ];
      (* Paid and cancelled plans are not open. *)
      plan ~paid:"e2" "paid" "2026-10-24" "jpy" [ ("wallet", z 999); ("ext", z (-999)) ];
      plan ~cancelled:"2026-10-21" "cancelled" "2026-10-24" "jpy"
        [ ("bank", z (-999)); ("ext", z 999) ];
      (* Conditional inflow, outflow, inclusive horizon, later exclusion. *)
      plan "inflow" "2026-10-25" "jpy" [ ("wallet", z 200); ("ext", z (-200)) ];
      plan "outflow" "2026-10-27" "jpy" [ ("bank", z (-100)); ("ext", z 100) ];
      plan "horizon" "2026-10-31" "jpy" [ ("wallet", z 30); ("ext", z (-30)) ];
      plan "later" "2026-11-01" "jpy" [ ("wallet", z 40); ("ext", z (-40)) ];
    ]

let flow_book = read (book ~support:support_flow ~entries:flow_entries ~plans:flow_plans ())
let coords_wallet_bank = [ ("wallet", "jpy"); ("bank", "jpy") ]

let compute ?(today = "2026-10-20") ?(through = "2026-10-31") ?(coords = coords_wallet_bank) book =
  R.compute ~book ~today ~coords ~assumed_complete_through:through

let expect_error label result = require (is_error result) (label ^ " must refuse")

(* ------------------------------------------------------------------ *)
(* Conditional path: exact selected sum, grouped days, horizon boundary. *)

let check_report_path () =
  let snapshot = get (compute flow_book) in
  require
    (snapshot.R.as_of = "2026-10-20"
    && snapshot.R.assumed_complete_through = "2026-10-31"
    && snapshot.R.measure = "jpy")
    "conditional snapshot must echo the explicit question";
  require
    (Z.equal snapshot.R.current_selected (z 1500))
    "current selected balance is the exact sum of the selected coordinates";
  let points =
    List.map (fun (p : R.point) -> (p.R.date, p.R.scheduled_change, p.R.balance)) snapshot.R.points
  in
  require
    (points
    = [
        ("2026-10-22", Z.zero, z 1500);
        ("2026-10-25", z 200, z 1700);
        ("2026-10-27", z (-100), z 1600);
        ("2026-10-31", z 30, z 1630);
      ])
    "paths must group same days, include the inclusive horizon, drop paid/cancelled, later plans \
     and irrelevant overdue plans, and keep a zero-net day point";
  require
    (Z.equal (R.final_at_horizon snapshot) (z 1630))
    "conditional balance at horizon uses every point";
  require
    (Z.equal (R.low_water snapshot) (z 1500))
    "low-water includes the current baseline and every day boundary";
  (* A horizon before a due day excludes it. *)
  let shorter = get (compute ~through:"2026-10-26" flow_book) in
  require
    (List.for_all (fun (p : R.point) -> p.R.date <= "2026-10-26") shorter.R.points
    && Z.equal (R.final_at_horizon shorter) (z 1700))
    "plans after the typed assumption are excluded";
  (* The horizon is an inclusive day boundary. *)
  let exact = get (compute ~through:"2026-10-31" flow_book) in
  require
    (List.exists (fun (p : R.point) -> p.R.date = "2026-10-31") exact.R.points)
    "a plan due on the assumption date is included"

let compute_refusals () =
  expect_error "empty selection" (compute ~coords:[] flow_book);
  expect_error "mixed-Measure selection"
    (compute ~coords:[ ("wallet", "jpy"); ("bank", "eur") ] flow_book);
  expect_error "duplicate coordinate selection"
    (compute ~coords:[ ("wallet", "jpy"); ("wallet", "jpy") ] flow_book);
  expect_error "malformed locus" (compute ~coords:[ ("", "jpy") ] flow_book);
  expect_error "malformed measure" (compute ~coords:[ ("wallet", "") ] flow_book);
  expect_error "unparsable today" (compute ~today:"2026-02-30" flow_book);
  expect_error "non-canonical today" (compute ~today:"2026-2-3" flow_book);
  expect_error "unparsable assumption" (compute ~through:"2026-10-32" flow_book);
  expect_error "non-canonical assumption" (compute ~through:"2026-10-1" flow_book);
  expect_error "assumption before today" (compute ~through:"2026-10-19" flow_book);
  (* Every selected coordinate is queried exactly: one unknown refuses the sum. *)
  expect_error "partially unknown selection"
    (compute ~coords:[ ("wallet", "jpy"); ("ghost", "jpy") ] flow_book);
  (* Overdue selected money refuses the whole query; it is never shifted or settled. *)
  let overdue =
    read
      (book ~support:support_flow ~entries:flow_entries
         ~plans:
           (String.concat ""
              [ plan "late" "2026-10-10" "jpy" [ ("wallet", z (-10)); ("ext", z 10) ] ])
         ())
  in
  expect_error "overdue selected plan" (compute overdue);
  let due_today =
    read
      (book ~entries:""
         ~plans:(plan "due_today" "2026-10-20" "jpy" [ ("wallet", z (-9)); ("ext", z 9) ])
         ())
  in
  let today = get (compute ~through:"2026-10-20" ~coords:[ ("wallet", "jpy") ] due_today) in
  require
    (match today.R.points with
    | [ point ] ->
        point.R.date = "2026-10-20"
        && Z.equal point.R.scheduled_change (z (-9))
        && Z.equal point.R.balance (z (-9))
    | _ -> false)
    "a due-today change is not overdue and remains inside an inclusive today horizon"

(* ------------------------------------------------------------------ *)
(* Exact versus unsupported evidence. *)

let check_evidence () =
  let flow_only = read (book ~entries:flow_entries ~plans:"" ()) in
  let exact = get (compute ~coords:[ ("wallet", "jpy") ] flow_only) in
  require
    (Z.equal exact.R.current_selected (z 1000))
    "a zero-origin coordinate answers an exact current quantity";
  require
    (is_error (compute ~coords:[ ("ghost", "jpy") ] flow_only))
    "unsupported evidence refuses, never zero";
  let zero_book = read (book ~entries:"" ~plans:"" ()) in
  let zero = get (compute ~coords:[ ("wallet", "jpy") ] zero_book) in
  require
    (Z.equal zero.R.current_selected Z.zero
    && zero.R.points = []
    && Z.equal (R.final_at_horizon zero) Z.zero
    && Z.equal (R.low_water zero) Z.zero)
    "a supported exact zero with no Scheduled changes is not an unknown amount"

(* ------------------------------------------------------------------ *)
(* Negative, zero and huge exact scaled amounts; render sign and scale. *)

let check_amounts () =
  let negative =
    read
      (book ~support:support_flow
         ~entries:
           (String.concat ""
              [
                entry "n1" "2026-10-01"
                  [ posting "wallet" "jpy" (z (-500)); posting "ext" "jpy" (z 500) ];
              ])
         ~plans:
           (String.concat ""
              [ plan "down" "2026-10-25" "jpy" [ ("wallet", z (-200)); ("ext", z 200) ] ])
         ())
  in
  let snapshot = get (compute ~coords:[ ("wallet", "jpy") ] negative) in
  require
    (Z.equal snapshot.R.current_selected (z (-500)))
    "negative exact selected balances stay exact";
  require
    (Z.equal (R.final_at_horizon snapshot) (z (-700)))
    "conditional outflow may take the balance negative";
  require
    (Z.equal (R.low_water snapshot) (z (-700)))
    "low-water reflects a path below the current baseline";
  let lines = R.render_lines ~book:negative snapshot in
  let text = String.concat "\n" (List.map snd lines) in
  require (contains text "-500") "negative current balance is rendered exactly";
  require (contains text "-700") "negative conditional horizon balance is rendered exactly";
  (* Scaled EUR: quanta 123456789 at scale 2 is 1,234,567.89, never the raw integer. *)
  let huge = Z.of_string "123456789012345678901234567890" in
  let eur_support = "ZERO-ORIGIN\twallet\teur\n" in
  let eur_book =
    read
      (book ~approved:[ "wallet"; "ext" ] ~support:eur_support
         ~entries:
           (String.concat ""
              [
                entry "x1" "2026-10-01"
                  [ posting "wallet" "eur" (z 123456789); posting "ext" "eur" (z (-123456789)) ];
              ])
         ~plans:
           (String.concat ""
              [ plan "top_up" "2026-10-25" "eur" [ ("wallet", huge); ("ext", Z.neg huge) ] ])
         ())
  in
  let eur = get (compute ~coords:[ ("wallet", "eur") ] eur_book) in
  require
    (eur.R.measure = "eur" && Z.equal eur.R.current_selected (z 123456789))
    "the selection, not the Shell environment, decides the single Measure";
  require
    (Z.equal (R.final_at_horizon eur) (Z.add (z 123456789) huge))
    "huge conditional totals stay exact";
  let eur_text = String.concat "\n" (List.map snd (R.render_lines ~book:eur_book eur)) in
  require
    (contains eur_text "1,234,567.89")
    "scaled EUR uses the household scale with grouped digits";
  require
    (not (contains eur_text "123456789012345678901234567890"))
    "raw quanta are never painted as an amount";
  require
    (contains eur_text "1,234,567,890,123,456,789,013,580,246.79")
    "huge scaled amounts are grouped, never clipped into another number"

(* ------------------------------------------------------------------ *)
(* Display limit: 12 point rows, totals over every point. *)

let check_display_limit () =
  let dates =
    List.init 14 (fun index ->
        let day = 21 + index in
        if day <= 31 then Printf.sprintf "2026-10-%02d" day
        else Printf.sprintf "2026-11-%02d" (day - 31))
  in
  let plans =
    String.concat ""
      (List.mapi
         (fun index day ->
           let amount = z (if index = 13 then -200 else 10) in
           plan (Printf.sprintf "p%02d" index) day "jpy"
             [ ("wallet", amount); ("ext", Z.neg amount) ])
         dates)
  in
  let many = read (book ~support:support_flow ~entries:"" ~plans ()) in
  let snapshot = get (compute ~through:"2026-11-05" ~coords:[ ("wallet", "jpy") ] many) in
  require (List.length snapshot.R.points = 14) "all fourteen day points exist";
  require
    (Z.equal (R.final_at_horizon snapshot) (z (-70)) && Z.equal (R.low_water snapshot) (z (-70)))
    "totals and low-water use every point, not only the displayed rows";
  let lines = R.render_lines ~book:many snapshot in
  let rows = List.map snd lines in
  let shown date = List.exists (fun line -> contains line date) rows in
  let shown_count = List.length (List.filter shown dates) in
  require (shown_count = 12) "at most twelve point rows are displayed";
  require
    ((not (shown (List.nth dates 12))) && not (shown (List.nth dates 13)))
    "points beyond the display limit are not painted as rows";
  let text = String.concat "\n" rows in
  require (contains text "-70") "the omitted points still contribute to the painted horizon total";
  require (contains text "omitted") "an explicit omitted-count note replaces the hidden rows"

(* ------------------------------------------------------------------ *)
(* Screen owner: unknown-first presentation, explicit Run, draft, no writes. *)

let screen_env ?(measure = "jpy") ?(today = "2026-10-20")
    ?(balance_view = Some "wallet\tjpy\nbank\tjpy\n") book =
  let config name =
    if name = "balance-view.tsv" then Ok balance_view
    else Error ("Configuration " ^ name ^ " was not declared by this screen.")
  in
  Screen.env_for_checks ~config ~book ~measure ~today ()

let geometry (width, height) : Screen.geometry =
  {
    Screen.screen = (width, height);
    body = (width, max 0 (height - 3));
    content = (width, max 0 (height - 5));
    width_of = String.length;
  }

let rows_of view = Lazy.force view.Screen.rows
let has rows needle = List.exists (fun (_, text) -> contains text needle) rows
let joined rows = String.concat "\n" (List.map snd rows)
let press env geom t key = S.handle env geom t (`Key (key, []))

let no_write = function
  | Screen.Stay | Screen.Ignored | Screen.Message _ | Screen.Home | Screen.Commands -> true
  | _ -> false

let check_screen () =
  let env = screen_env ~measure:"eur" flow_book in
  let geom = geometry (80, 24) in
  let created = S.create () in
  expect_error "new report has no result before Run" (S.result env created);
  let opened = S.enter ~focus_day:"2026-10-16" created in
  require
    (S.assumption opened = "2026-10-31")
    "first entry seeds the selected day's Gregorian month end";
  require (S.run_focused opened) "first entry focuses Run only";
  expect_error "seeded assumption alone must not query" (S.result env opened);
  let view = S.view env geom opened in
  let rows = rows_of view in
  require
    (match rows with
    | (_, first) :: (_, second) :: _ ->
        contains first "Forecast path: UNKNOWN" && contains second "Known low-water mark: UNKNOWN"
    | _ -> false)
    "both unconditional statements are UNKNOWN and painted first";
  require
    (has rows "Run" && has rows "conditional")
    "Run and the conditional disclaimer are visible";
  List.iter
    (fun (width, height) ->
      let g = geometry (width, height) in
      let v = S.view env g opened in
      let rows = rows_of v in
      require
        (List.length rows <= snd g.Screen.content)
        (Printf.sprintf "rows must fit %dx%d content" width height);
      List.iter
        (fun (_, text) ->
          require
            (String.length text <= fst g.Screen.content)
            (Printf.sprintf "row too wide at %dx%d: %S" width height text))
        rows;
      require (has rows "UNKNOWN") "UNKNOWN statements survive every size")
    [ (80, 24); (120, 36); (48, 14); (32, 9) ];
  (* Enter on the field only advances focus; Enter on Run requests the answer. *)
  let field, _ = press env geom opened `Tab in
  require (not (S.run_focused field)) "Tab moves focus to the horizon field";
  let field_view = S.view env geom field in
  require
    (Option.is_some field_view.Screen.cursor)
    "the physical caret exists only on the focused horizon field";
  expect_error "editing focus never queries" (S.result env field);
  let back_on_run, _ = press env geom field `Enter in
  require (S.run_focused back_on_run) "Enter on the field advances to Run";
  expect_error "advancing focus is not an explicit Run" (S.result env back_on_run);
  let ran, _ = press env geom back_on_run `Enter in
  let snapshot = get (S.result env ran) in
  require
    (snapshot.R.measure = "jpy" && Z.equal (R.final_at_horizon snapshot) (z 1630))
    "explicit Run answers in the selected Measure, not the Shell's ambient Measure";
  require
    (List.for_all (fun (p : R.point) -> p.R.date <= S.assumption ran) snapshot.R.points)
    "the answer follows the typed assumption exactly";
  require (Option.is_none (S.view env geom ran).Screen.cursor) "no caret while Run has focus";
  (* Editing the assumption invalidates the prior numbers. *)
  let editing, _ = press env geom ran `Tab in
  let edited, _ = press env geom editing `Backspace in
  require (S.assumption edited <> "2026-10-31") "Backspace edits the seeded assumption text";
  expect_error "editing the assumption invalidates the requested answer" (S.result env edited);
  require (S.run_focused edited = false) "editing keeps the field focused";
  (* Explicit invalid and past horizons are visible refusals with the input kept. *)
  let typed = ref editing in
  List.iter
    (fun _ ->
      let t, _ = press env geom !typed `Backspace in
      typed := t)
    (List.init (String.length (S.assumption editing)) (fun _ -> ()));
  List.iter
    (fun ch ->
      let t, _ = press env geom !typed (`ASCII ch) in
      typed := t)
    ("2026-13-01" |> String.to_seq |> List.of_seq);
  let bad, _ = press env geom !typed `Enter in
  expect_error "invalid explicit assumption refuses" (S.result env bad);
  require (S.assumption bad = "2026-13-01") "a refused assumption keeps the typed text";
  require (has (rows_of (S.view env geom bad)) "2026-13-01") "the refused assumption stays visible";
  let past_env = screen_env flow_book in
  let past_open = S.enter ~focus_day:"2026-09-10" (S.create ()) in
  require (S.assumption past_open = "2026-09-30") "month end follows the focus day";
  let past, _ = press past_env geom past_open `Enter in
  expect_error "assumption before today refuses" (S.result past_env past);
  let invalid_seed = S.enter ~focus_day:"not-a-date" (S.create ()) in
  expect_error "invalid focus day seed must refuse visibly"
    (S.result env (fst (press env geom invalid_seed `Enter)));
  (* q/Esc leave for Home even from the field; Space opens Commands. *)
  let home, request = press env geom editing (`ASCII 'q') in
  require (request = Screen.Home) "q leaves for Home from the field";
  ignore home;
  let _, request = press env geom field `Escape in
  require (request = Screen.Home) "Esc leaves for Home";
  let _, request = press env geom ran (`ASCII ' ') in
  require (request = Screen.Commands) "Space opens the Commands menu";
  (* m resets to the current Shell focus month end, focusing Run and clearing results. *)
  let feb_env = screen_env ~today:"2026-02-10" flow_book in
  let feb, _ = press feb_env geom ran (`ASCII 'm') in
  require (S.assumption feb = "2026-02-28") "m uses today, not the entry day";
  require (S.run_focused feb) "m focuses Run";
  expect_error "m clears the requested answer" (S.result feb_env feb);
  let leap_env = screen_env ~today:"2028-02-11" flow_book in
  let leap, _ = press leap_env geom ran (`ASCII 'm') in
  require (S.assumption leap = "2028-02-29") "m uses the Gregorian month length of the focus month";
  (* Re-entry keeps an edited draft; only m resets it. *)
  let draft = S.enter ~focus_day:"2026-10-16" editing in
  require
    (S.assumption draft = S.assumption editing)
    "re-entry preserves an edited assumption draft";
  (* A book change or reload clears the requested numbers; Run is required again. *)
  let changed, _ = S.book_changed ~before:flow_book ~after:flow_book ran in
  expect_error "book change invalidates the requested answer" (S.result env changed);
  let reloaded, _ = S.reloaded env ran in
  expect_error "reload invalidates the requested answer" (S.result env reloaded);
  (* No interaction ever persists or publishes anything. *)
  List.iter
    (fun (_, request) -> require (no_write request) "Liquidity must never write")
    [
      press env geom created `Enter;
      press env geom opened `Tab;
      press env geom field (`ASCII 'x');
      press env geom ran (`ASCII 'm');
      press env geom ran (`ASCII 'j');
      press env geom ran (`Page `Down);
      press env geom ran `End;
      S.saved env geom (Ok ()) ran;
      S.reloaded env ran;
    ];
  ()

(* ------------------------------------------------------------------ *)
(* Malformed/missing configuration and the four terminal geometries. *)

let check_configuration_and_resize () =
  let dims = [ (80, 24); (120, 36); (48, 14); (32, 9) ] in
  List.iter
    (fun (width, height) ->
      let geom = geometry (width, height) in
      let missing_env = screen_env ~balance_view:None flow_book in
      let missing =
        fst (press missing_env geom (S.enter ~focus_day:"2026-10-16" (S.create ())) `Enter)
      in
      expect_error "missing selection refuses" (S.result missing_env missing);
      let malformed_env = screen_env ~balance_view:(Some "wallet\tjpy\nbad row\n") flow_book in
      let malformed =
        fst (press malformed_env geom (S.enter ~focus_day:"2026-10-16" (S.create ())) `Enter)
      in
      expect_error "malformed selection refuses" (S.result malformed_env malformed);
      let empty_env = screen_env ~balance_view:(Some "") flow_book in
      let empty =
        fst (press empty_env geom (S.enter ~focus_day:"2026-10-16" (S.create ())) `Enter)
      in
      expect_error "empty selection refuses" (S.result empty_env empty);
      (* Errors are visible and wrapped without stale success numbers. *)
      let rows = rows_of (S.view malformed_env geom malformed) in
      require
        (List.length rows <= snd geom.Screen.content)
        (Printf.sprintf "error rows must fit %dx%d" width height);
      List.iter
        (fun (_, text) ->
          require
            (String.length text <= fst geom.Screen.content)
            (Printf.sprintf "error row too wide at %dx%d" width height))
        rows)
    dims;
  (* A focus field stays visible and caret-bounded at the smallest sizes. *)
  let env = screen_env flow_book in
  let geometries =
    List.concat_map
      (fun dimensions ->
        let geom = geometry dimensions in
        [
          geom;
          {
            geom with
            body = (fst geom.body, max 0 (snd geom.body - 1));
            content = (fst geom.content, max 0 (snd geom.content - 1));
          };
        ])
      dims
  in
  List.iter
    (fun (geom : Screen.geometry) ->
      let width, height = geom.screen in
      let field, _ = press env geom (S.enter ~focus_day:"2026-10-16" (S.create ())) `Tab in
      let view = S.view env geom field in
      (match view.Screen.cursor with
      | None -> failwith (Printf.sprintf "missing caret at %dx%d" width height)
      | Some (col, row) ->
          require
            (row >= 0 && row < snd geom.Screen.body && col >= 0 && col < fst geom.Screen.body)
            (Printf.sprintf "caret outside the Shell body at %dx%d" width height));
      require (has (rows_of view) (S.assumption field)) "the focused assumption stays visible")
    geometries;
  (* Scrolling reaches the last painted result rows while Run keeps focus. *)
  let geom = geometry (32, 9) in
  let opened = S.enter ~focus_day:"2026-10-16" (S.create ()) in
  let ran, _ = press env geom opened `Enter in
  let before = joined (rows_of (S.view env geom ran)) in
  require
    (not (contains before "1,500 jpy"))
    "the first viewport has not painted the conditional quantity";
  let scrolled, _ = press env geom ran (`ASCII 'j') in
  let after_j = joined (rows_of (S.view env geom scrolled)) in
  require (after_j <> before) "j scrolls the result";
  let paged, _ = press env geom scrolled (`Page `Down) in
  require (joined (rows_of (S.view env geom paged)) <> after_j) "Page Down scrolls the result";
  let ended, _ = press env geom ran `End in
  require
    (contains (joined (rows_of (S.view env geom ended))) "1,500 jpy")
    "End reaches the exact conditional low-water quantity";
  ()

let self_check () =
  check_report_path ();
  compute_refusals ();
  check_evidence ();
  check_amounts ();
  check_display_limit ();
  check_screen ();
  check_configuration_and_resize ();
  print_endline
    "PASS: Liquidity keeps both unconditional statements UNKNOWN, answers only after an explicit \
     dated assumption, and exactly covers selected balances, conditional day paths, low-water, \
     evidence, scale, display limit, draft invalidation and no-write screen transitions."
