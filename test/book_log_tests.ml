(* A snapshot plus appended records must load to exactly the book the operations
   produced in memory, at every step and across compactions; an interrupted final
   append is reported, never applied; any other damage refuses the whole file. *)
open Base
module B = Bakhlo_sexp.Daily_book
module L = Bakhlo_sexp.Book_log
module O = Daily_book_oracle_tests
module R = Stdlib.Random.State

let get = function Ok x -> x | Error why -> failwith why
let load bytes = L.load bytes

(* Admitted operations become records (sometimes two per record); every few steps
   the file is compacted to a fresh snapshot. Returns the final file, the book
   before the last record, the records since the last snapshot and all records
   written. *)
let build ~seed ~steps =
  let st = R.make [| seed |] in
  let book = ref (get (B.of_string O.fixture)) in
  let snapshot = ref (B.to_string !book) and records = Buffer.create 4096 and seq = ref 1 in
  let before_last = ref !book and written = ref 0 in
  for step = 1 to steps do
    if O.chance st 10 then (
      snapshot := B.to_string !book;
      Buffer.clear records;
      seq := 1);
    let op = O.generate st !book in
    let ops = if O.chance st 20 then [ op; O.generate st !book ] else [ op ] in
    match L.apply_all !book ops with
    | Error _ -> ()
    | Ok next ->
        before_last := !book;
        Buffer.add_string records (L.record_line ~seq:!seq ops);
        Int.incr seq;
        Int.incr written;
        book := next;
        let loaded = get (load (!snapshot ^ Buffer.contents records)) in
        if not (String.equal (O.observable loaded.book) (O.observable next)) || loaded.torn
           || loaded.records <> !seq - 1
        then failwith (Printf.sprintf "seed %d step %d: loaded book differs" seed step)
  done;
  (!snapshot ^ Buffer.contents records, !before_last, !seq - 1, !written)

let%expect_test "snapshot plus records loads to the in-memory book at every step" =
  let records = ref 0 in
  for seed = 1 to 150 do
    let _, _, _, written = build ~seed ~steps:30 in
    records := !records + written
  done;
  Stdio.printf "records replayed: more than 1000: %b\n" (!records > 1000);
  [%expect {| records replayed: more than 1000: true |}]

let last_line_start bytes =
  match String.rindex_from bytes (String.length bytes - 2) '\n' with
  | Some n -> n + 1
  | None -> 0

let%expect_test "an interrupted final append is reported and not applied" =
  let checked = ref 0 in
  for seed = 1 to 40 do
    let file, before_last, n, _ = build ~seed ~steps:20 in
    if n > 0 then
      let start = last_line_start file in
      for cut = start + 1 to String.length file - 1 do
        let loaded = get (load (String.sub file ~pos:0 ~len:cut)) in
        if not (loaded.torn && loaded.records = n - 1 && loaded.valid_length = start
                && String.equal (O.observable loaded.book) (O.observable before_last))
        then failwith (Printf.sprintf "seed %d cut %d: torn tail mishandled" seed cut);
        Int.incr checked
      done
  done;
  Stdio.printf "torn cuts checked: more than 1000: %b\n" (!checked > 1000);
  [%expect {| torn cuts checked: more than 1000: true |}]

let refusal file = match load file with Ok _ -> "loaded" | Error why -> why

let%expect_test "damage before the final line refuses the whole file" =
  let base = get (B.of_string O.fixture) in
  let snapshot = B.to_string base in
  let entry n : B.entry =
    { id = Printf.sprintf "e%d" n; day = "2026-10-05"; memo = Some "lunch"; reversal_of = None;
      effects = [ O.posting "wallet" "jpy" (-100); O.posting "food" "jpy" 100 ];
      exchange = None; original_amount = None; merchant = None }
  in
  let put n = L.Put_entry { replace = false; entry = entry n; plan = None } in
  let r1 = L.record_line ~seq:1 [ put 1 ] and r2 = L.record_line ~seq:2 [ put 2 ] in
  let r3 = L.record_line ~seq:3 [ put 3 ] in
  let edit line ~pattern ~with_ = String.substr_replace_first line ~pattern ~with_ in
  Stdio.printf "intact: %s\n" (refusal (snapshot ^ r1 ^ r2 ^ r3));
  Stdio.printf "edited amount: %s\n" (refusal (snapshot ^ edit r1 ~pattern:"100" ~with_:"900" ^ r2 ^ r3));
  Stdio.printf "garbled line: %s\n" (refusal (snapshot ^ r1 ^ edit r2 ~pattern:")" ~with_:"" ^ r3));
  Stdio.printf "repeated record: %s\n" (refusal (snapshot ^ r1 ^ r1 ^ r2));
  Stdio.printf "missing record: %s\n" (refusal (snapshot ^ r1 ^ r3));
  Stdio.printf "replay refused: %s\n"
    (refusal (snapshot ^ r1 ^ L.record_line ~seq:2 [ put 1 ]));
  Stdio.printf "terminated bad final line: %s\n" (refusal (snapshot ^ r1 ^ "(record 2 x)\n"));
  Stdio.printf "plain book: %s\n" (refusal snapshot);
  [%expect {|
    intact: loaded
    edited amount: log-corrupt-at-record-1
    garbled line: log-corrupt-at-record-2
    repeated record: log-corrupt-at-record-2
    missing record: log-corrupt-at-record-2
    replay refused: log-replay-refused-at-record-2: duplicate-entry
    terminated bad final line: log-corrupt-at-record-2
    plain book: loaded
    |}]

let%expect_test "a record carries every operation kind through its own codec" =
  let party = Result.ok_or_failwith
      (Result.map_error ~f:(fun _ -> "party")
         (Bakhlo_domain.Identifier.External_party.of_string "shop \"quoted\"")) in
  let plan : B.plan =
    { id = "p\n2"; day = "2026-10-30"; measure = "jpy"; changes = [ ("bank", Z.of_int (-5)); ("expense", Z.of_int 5) ];
      paid_by = None; cancelled_on = None }
  in
  let ops =
    [ L.Put_plan { replace = false; plan };
      L.Cancel_plan { id = "p\n2"; day = "2026-10-31" };
      L.Observe [ ("wallet", "jpy", Z.of_string "-123456789012345678901234567890") ];
      L.Add_locus "ghost";
      L.Set_locus_label { id = "ghost"; label = "幽霊 \"x\""; help = None };
      L.Put_entry
        { replace = false; plan = None;
          entry =
            { id = "m1"; day = "2026-10-06"; memo = Some "tab\tand \\ slash"; reversal_of = None;
              effects = [ O.posting ~key:"a" "wallet" "jpy" (-7); O.posting "food" "jpy" 7 ];
              exchange = None; original_amount = Some ("usd", Z.of_int 120); merchant = None } };
      L.Correct_entry_date { id = "m1"; day = "2026-10-07" };
      L.Classify_merchant { id = "m1"; disposition = Bakhlo_application.Event_merchants.Merchant party } ]
  in
  let base = get (B.of_string O.fixture) in
  let expected = get (L.apply_all base ops) in
  let line = L.record_line ~seq:1 ops in
  let loaded = get (load (B.to_string base ^ line)) in
  Stdio.printf "one line: %b; same book: %b\n"
    (String.count line ~f:(Char.equal '\n') = 1)
    (String.equal (O.observable loaded.book) (O.observable expected));
  [%expect {| one line: true; same book: true |}]

let historical_fixture =
  String.substr_replace_first O.fixture
    ~pattern:"(approved-loci (provided wallet food bank expense))"
    ~with_:"(approved-loci (provided food expense))"

let entry book id =
  List.find_exn (B.entries book) ~f:(fun (candidate : B.entry) -> String.equal candidate.id id)

let%expect_test "date correction has its own codec and replays without reapproving historical loci" =
  let base = get (B.of_string historical_fixture) in
  let before = entry base "init" in
  let op = L.Correct_entry_date { id = "init"; day = "2026-10-09" } in
  let line = L.record_line ~seq:1 [ op ] in
  (match get (L.decode_record_line ~seq:1 line) with
  | [ L.Correct_entry_date { id; day } ] -> Stdio.printf "decoded %s %s\n" id day
  | _ -> Stdio.printf "decoded wrong operation\n");
  let loaded = get (load (B.to_string base ^ line)) in
  let after = entry loaded.book "init" in
  Stdio.printf "date %s; all other fields preserved: %b; records %d\n" after.day
    (Poly.equal before { after with day = before.day }) loaded.records;
  [%expect {|
    decoded init 2026-10-09
    date 2026-10-09; all other fields preserved: true; records 1
    |}]

let%expect_test "date correction replay refuses invalid input without a partial book" =
  let base = get (B.of_string historical_fixture) in
  let snapshot = B.to_string base in
  let attempt op = refusal (snapshot ^ L.record_line ~seq:1 [ op ]) in
  Stdio.printf "unknown: %s\n"
    (attempt (L.Correct_entry_date { id = "missing"; day = "2026-10-09" }));
  Stdio.printf "invalid date: %s\n"
    (attempt (L.Correct_entry_date { id = "init"; day = "2026-02-30" }));
  [%expect {|
    unknown: log-replay-refused-at-record-1: unknown-entry
    invalid date: log-replay-refused-at-record-1: invalid-date
    |}]
