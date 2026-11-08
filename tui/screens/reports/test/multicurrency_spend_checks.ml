(* Multicurrency Spend: one explicit half-open Actual window kept as separate
   exact families. Original amounts, recorded Expense per Measure and exchange
   legs are never converted, merged or silently dropped. *)
module B = Bakhlo_household.Book
module MS = Bakhlo_household.Multicurrency_spend
module R = Multicurrency_spend_report
module S = Multicurrency_spend_screen

let contains text sub =
  let n = String.length text and m = String.length sub in
  let rec at i = i + m <= n && (String.sub text i m = sub || at (i + 1)) in
  at 0

let get = function Ok x -> x | Error why -> failwith why
let require condition why = if not condition then failwith why
let is_error = Result.is_error
let expect_error label result = require (is_error result) (label ^ " must refuse")
let z n = Z.of_int n

(* Synthetic book construction in book.txt: no household file is ever read. *)
let posting locus measure n = Printf.sprintf "EFFECT\t%s\t%s\t%s\n" locus measure (Z.to_string n)

let entry id day postings =
  Printf.sprintf "TX\t%s\t%s\n%sENDTX\n" id day (String.concat "" postings)

(* Loci outside [approved] that entries use are kept, hidden from new entries. *)
let book ?(approved = [ "wallet"; "bank"; "ext"; "mystery"; "hotel"; "shop" ]) ~entries ~plans () =
  let locus hidden l =
    Printf.sprintf "LOCUS\t%s\t%s\t%s\n" l l (if hidden then "\tHIDDEN" else "")
  in
  let support =
    List.concat_map
      (fun m ->
        List.map (fun l -> Printf.sprintf "ZERO-ORIGIN\t%s\t%s\n" l m) [ "wallet"; "bank"; "ext" ])
      [ "jpy"; "eur"; "usd" ]
  in
  "BOOK\t1\nMEASURE\tjpy\t0\nMEASURE\teur\t2\nMEASURE\tusd\t2\n"
  ^ String.concat "" (List.map (locus false) approved)
  ^ String.concat "" (List.map (locus true) [ "food"; "rent" ])
  ^ entries ^ plans ^ String.concat "" support ^ "END\n"

(* jpy 0 scale, eur/usd scale 2. A refund nets its Expense Measure; an unclassified
   Locus never joins any total. Counterparty loci carry explicit Asset roles, so
   only a genuinely unclassified Locus is an unresolved witness. *)
let roles =
  [
    ("food", Locus_roles.Expense);
    ("rent", Locus_roles.Expense);
    ("wallet", Locus_roles.Asset);
    ("bank", Locus_roles.Asset);
    ("ext", Locus_roles.Asset);
  ]

let read text = get (B.set_roles (get (B.read text)) roles)

let mixed_entries =
  String.concat ""
    [
      entry "e1" "2026-10-01" [ posting "food" "jpy" (z 1000); posting "wallet" "jpy" (z (-1000)) ];
      (* A negative Expense Effect (refund) reduces that Measure, never zeroes it. *)
      entry "e2" "2026-10-02" [ posting "food" "jpy" (z (-200)); posting "wallet" "jpy" (z 200) ];
      entry "e3" "2026-10-03" [ posting "rent" "eur" (z 5000); posting "bank" "eur" (z (-5000)) ];
      (* A role-absent nonzero Effect stays a visible witness, never a zero row. *)
      entry "e4" "2026-10-04" [ posting "mystery" "usd" (z 700); posting "wallet" "usd" (z (-700)) ];
      "TX\tx1\t2026-10-10\tDESC\ttrip-exchange\n\
       EFFECT\twallet\tjpy\t-100100\tsrc\n\
       EFFECT\twallet\teur\t5000\tdst\n\
       EFFECT\tfood\tjpy\t100\n\
       EXCHANGE\tjpy\teur\n\
       ENDTX\n";
      (* Outside the explicit window. *)
      entry "e5" "2026-11-05" [ posting "food" "jpy" (z 9999); posting "wallet" "jpy" (z (-9999)) ];
    ]

let mixed_book = read (book ~entries:mixed_entries ~plans:"" ())

let total_of measure totals =
  match List.find_opt (fun (row : MS.total) -> row.measure = measure) totals with
  | Some row -> Some row.quanta
  | None -> None

let check_render () =
  let snapshot =
    get (Result.map_error MS.message @@ MS.compute mixed_book ~start:"2026-10-01" ~stop:"2026-11-01")
  in
  let text =
    String.concat "\n" (List.map (fun (_, line) -> line) (R.render_lines ~book:mixed_book snapshot))
  in
  require (contains text "Window [2026-10-01, 2026-11-01)") "the explicit window is painted";
  require (contains text "trip-exchange") "an exchange's description remains visible";
  require (contains text "No FX rate") "the no-conversion disclaimer is painted";
  require (contains text "50.00 eur") "EUR is painted at its own scale";
  require (contains text "800 jpy") "JPY is painted at its own scale";
  require (contains text "+7.00 usd") "the unresolved witness is painted exactly";
  require
    (contains text "Unresolved ordinary Effects: 1")
    "every unresolved witness is counted and painted";
  require
    (contains text "not a complete spending total")
    "unresolved evidence qualifies the classified figures";
  require (contains text "Original presented Expense") "the original section is always present";
  require (contains text "Exchange occurrences") "the exchange section is always present"

let screen_env ?(today = "2026-10-20") book =
  let config name =
    if name = "boundary-presets.tsv" then Ok None
    else Error ("Configuration " ^ name ^ " was not declared by this screen.")
  in
  Screen.env_for_checks ~config ~book ~measure:"jpy" ~today ~accounting_roles:roles ()

let geometry (width, height) : Screen.geometry =
  {
    Screen.screen = (width, height);
    body = (width, max 0 (height - 3));
    content = (width, max 0 (height - 5));
    width_of = String.length;
  }

let press env geom t key = S.handle env geom t (`Key (key, []))

let no_write = function
  | Screen.Stay | Screen.Ignored | Screen.Message _ | Screen.Home | Screen.Commands -> true
  | _ -> false

let check_screen () =
  let env = screen_env mixed_book in
  let geom = geometry (80, 24) in
  require
    (S.config_files = [ "boundary-presets.tsv" ])
    "the report reads only the explicit boundary presets";
  let created = S.create () in
  require (S.modal created = false) "the report has no modal";
  expect_error "no answer before Run" (S.result created);
  let opened = S.enter env ~focus_day:"2026-10-20" created in
  require
    (S.window opened = ("2026-10-01", "2026-11-01"))
    "first entry seeds the selected day's calendar month";
  require (S.source_label opened = "Calendar Month") "the seeded source is Calendar Month";
  expect_error "seeding alone never queries" (S.result opened);
  (* Seeded focus is Run; a single Enter runs the query. *)
  let on_run, _ = press env geom opened `Enter in
  let answer = get (S.result on_run) in
  require
    (total_of "jpy" answer.MS.ordinary_expense = Some (z 800))
    "explicit Run answers the exact window";
  (* Tab reaches a date without discarding the answer; only an edit invalidates it. *)
  let editing, _ = press env geom on_run `Tab in
  require (not (is_error (S.result editing))) "moving focus to a date preserves the cached answer";
  let advanced, _ = press env geom editing `Enter in
  require
    (not (is_error (S.result advanced)))
    "Enter on a date only advances focus, never queries or invalidates";
  let edited, _ = press env geom advanced `Backspace in
  require (S.window edited <> S.window on_run) "Backspace edits the date draft";
  require (S.source_label edited = "Custom") "any edit makes the source explicitly Custom";
  expect_error "an edit invalidates the answer" (S.result edited);
  (* A refused Run never leaves a stale successful answer. *)
  let bad, _ = press env geom edited `Enter in
  expect_error "an invalid date refuses" (S.result bad);
  (* m restores the selected month and clears the answer. *)
  let reset, _ = press env geom bad (`ASCII 'm') in
  require
    (S.source_label reset = "Calendar Month" && S.window reset = ("2026-10-01", "2026-11-01"))
    "m restores the selected month window";
  expect_error "m clears the answer" (S.result reset);
  (* q/Esc leave for Home even from a date; Space opens Commands. *)
  let _, request = press env geom editing (`ASCII 'q') in
  require (request = Screen.Home) "q leaves for Home from the field";
  let _, request = press env geom editing `Escape in
  require (request = Screen.Home) "Esc leaves for Home";
  let _, request = press env geom on_run (`ASCII ' ') in
  require (request = Screen.Commands) "Space opens the Commands menu";
  (* Lifecycle events invalidate the answer. *)
  let reloaded, _ = S.reloaded env on_run in
  expect_error "a reload invalidates the answer" (S.result reloaded);
  let changed, _ = S.book_changed ~before:mixed_book ~after:mixed_book on_run in
  expect_error "a book change invalidates the answer" (S.result changed);
  (* No interaction ever persists or publishes anything. *)
  List.iter
    (fun (_, request) -> require (no_write request) "Multicurrency Spend never writes")
    [
      press env geom created `Enter;
      press env geom opened `Tab;
      press env geom editing (`ASCII 'x');
      press env geom on_run (`ASCII 'm');
      press env geom on_run (`ASCII 'j');
      press env geom on_run (`Page `Down);
      press env geom on_run `End;
      S.saved env geom (Ok ()) on_run;
      S.reloaded env on_run;
    ];
  ignore (S.book_changed ~before:mixed_book ~after:mixed_book on_run);
  (* The date caret exists only on the focused date, and the answer is scrollable. *)
  List.iter
    (fun (width, height) ->
      let g = geometry (width, height) in
      let field, _ = press env g opened `Tab in
      (match (S.view env g field).Screen.cursor with
      | None -> failwith (Printf.sprintf "missing caret at %dx%d" width height)
      | Some (col, row) ->
          require
            (row >= 0 && row < snd g.Screen.body && col >= 0 && col < fst g.Screen.body)
            (Printf.sprintf "caret outside the Shell body at %dx%d" width height));
      let view = S.view env g on_run in
      require (Option.is_none view.Screen.cursor) "no caret while Run has focus";
      let rows = Lazy.force view.Screen.rows in
      require
        (List.length rows <= snd g.Screen.content)
        (Printf.sprintf "rows must fit %dx%d content" width height);
      List.iter
        (fun (_, text) ->
          require
            (String.length text <= fst g.Screen.content)
            (Printf.sprintf "row too wide at %dx%d: %S" width height text))
        rows)
    [ (80, 24); (120, 36); (48, 14); (32, 9) ]

let self_check () =
  check_render ();
  check_screen ();
  print_endline
    "PASS: Multicurrency Spend formatting, explicit windows, draft/cache invalidation, wrapping \
     and no-write screen transitions."
