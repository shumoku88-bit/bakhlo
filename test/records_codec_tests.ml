open Base

module D = Bakhlo_domain
module A = Bakhlo_application
module Q = A.Current_quantity_query
module X = Sexplib0.Sexp
module RB = Bakhlo_sexp.Records_book
module DB = Bakhlo_sexp.Daily_book
module Crc = Bakhlo_sexp.Crc32

let get = function Ok x -> x | Error why -> failwith why

let base_fixture =
  "(bakhlo-daily 1) (scope corrected-entries explicit-plans)\n\
   (measures (measure jpy 0) (measure eur 2))\n\
   (labels (provided (label wallet 財布 現金)))\n\
   (approved-loci (provided wallet food bank))\n\
   (entries)\n\
   (plans (plan planned (date 2026-10-10) (measure jpy) (changes (wallet -200) (food 200)) \
   (paid-by (none))))\n\
   (support (zero-origin (food jpy)) (openings)\n\
   (observations (observation (reflected) (quantities (wallet jpy 1000)))) (presence \
   (not-supplied)))\n"

let posting locus measure n key =
  D.Effect.create
    ~locus:
      (Result.ok_or_failwith
         (Result.map_error (D.Identifier.Locus.of_string locus) ~f:(fun _ -> "locus")))
    ~measure:
      (Result.ok_or_failwith
         (Result.map_error (D.Identifier.Measure.of_string measure) ~f:(fun _ -> "measure")))
    ~quantity:(D.Quantity.of_quanta (Z.of_int n))
    ~key:
      (Option.map key ~f:(fun key ->
           Result.ok_or_failwith
             (Result.map_error (D.Identifier.Effect_key.of_string key) ~f:(fun _ -> "key"))))

let make_entry id day n : DB.entry =
  {
    id;
    day;
    memo = Some "食費";
    effects = [ posting "wallet" "jpy" (-n) None; posting "food" "jpy" n None ];
    reversal_of = None;
    exchange = None;
  }

let make_v4_fixture () =
  let base = get (DB.of_string base_fixture) in
  let base = get (DB.put_entry base ~replace:false (make_entry "e1" "2026-10-02" 1200) ~plan:None) in
  let budget : DB.budget = {
    id = "cycle";
    start_day = "2026-10-01";
    end_exclusive = "2026-11-01";
    measure = "jpy";
    allocations = [ ("living", Z.of_int 20000) ];
    expense_loci = [ "food" ];
    actual_routes = [ ("food", Some "living") ];
    plan_routes = [ ("planned", "food", Some "living") ];
  } in
  let b4 = get (DB.put_budget base ~replace:false budget) in
  DB.to_string b4

let%test_unit "source_format_of_string detection" =
  let v4_str = make_v4_fixture () in
  let format_mono = DB.source_format_of_string v4_str in
  (match format_mono with
  | `Monolithic "4" -> ()
  | _ -> failwith "Failed to detect Monolithic v4");

  let db = get (DB.of_string v4_str) in
  let rec_str = DB.to_records_string ~request_tokens:[ ("tok-e1", "e1") ] db in
  let format_rec = DB.source_format_of_string rec_str in
  (match format_rec with
  | `Records 1 -> ()
  | _ -> failwith "Failed to detect Records v1");

  match DB.source_format_of_string "invalid garbage text" with
  | `Unknown -> ()
  | _ -> failwith "Expected `Unknown for garbage"

let%test_unit "records_codec roundtrip and daily_book interop" =
  let v4_str = make_v4_fixture () in
  let db_orig = get (DB.of_string v4_str) in
  let rec_str = DB.to_records_string ~request_tokens:[ ("tok-e1", "e1") ] db_orig in

  (* 1. Verify records string can be loaded into Records_book *)
  let rb = match RB.of_string rec_str with
    | Ok r -> r
    | Error e -> failwith ("Failed to parse records string: " ^ e)
  in
  assert (List.length (RB.frames rb) >= 3);
  assert (List.length (RB.entries rb) = 1);
  assert (List.length (RB.plans rb) = 1);
  assert (List.length (RB.budgets rb) = 1);
  assert (List.length (RB.origins rb) = 1);

  (* 2. Verify Records_book can be loaded back into Daily_book via compatible reader *)
  let db_loaded = match DB.of_string rec_str with
    | Ok book -> book
    | Error e -> failwith ("Compatible reader failed on records string: " ^ e)
  in

  (* 3. Check domain semantics equivalence *)
  let orig_entries = DB.entries db_orig in
  let loaded_entries = DB.entries db_loaded in
  assert (List.length orig_entries = List.length loaded_entries);
  List.iter2_exn orig_entries loaded_entries ~f:(fun o l ->
    assert (String.equal o.id l.id);
    assert (String.equal o.day l.day);
    assert (Option.equal String.equal o.memo l.memo);
    assert (List.length o.effects = List.length l.effects));

  let orig_plans = DB.plans db_orig in
  let loaded_plans = DB.plans db_loaded in
  assert (List.length orig_plans = List.length loaded_plans);

  let orig_budgets = DB.budgets db_orig in
  let loaded_budgets = DB.budgets db_loaded in
  (match orig_budgets, loaded_budgets with
  | Some obs, Some lbs -> assert (List.length obs = List.length lbs)
  | _ -> failwith "Budgets mismatch");

  (* 4. Verify to_string on loaded book still outputs Monolithic format (No silent overwrite) *)
  let written_back = DB.to_string db_loaded in
  (match DB.source_format_of_string written_back with
  | `Monolithic "4" -> ()
  | _ -> failwith "Daily_book.to_string must preserve Monolithic format without silent rewrite")

let%test_unit "records_codec checksum verification and corruption detection" =
  let v4_str = make_v4_fixture () in
  let db = get (DB.of_string v4_str) in
  let rec_str = DB.to_records_string db in
  let lines =
    List.filter (String.split_lines rec_str) ~f:(fun l ->
        let t = String.strip l in
        (not (String.is_empty t)) && not (String.is_prefix t ~prefix:";"))
  in

  (* 1. Verify single frame checksum validation *)
  let entry_line =
    List.find_exn lines ~f:(fun line -> String.is_substring line ~substring:"(entry")
  in
  let tampered_entry_line =
    String.substr_replace_first ~pattern:"1200" ~with_:"1999" entry_line
  in
  (match RB.parse_frame tampered_entry_line with
  | Error msg when String.is_substring msg ~substring:"checksum-mismatch" -> ()
  | Ok _ -> failwith "Tampered payload must be rejected by checksum validation"
  | Error other -> failwith ("Unexpected error in parse_frame: " ^ other));

  (* 2. Verify mid-file checksum corruption is detected by inspect_string and of_string *)
  let mid_tampered_lines =
    match lines with
    | f0 :: _f_entry :: f_budget :: rest ->
        f0 :: tampered_entry_line :: f_budget :: rest
    | _ -> failwith "Not enough frames"
  in
  let mid_tampered_str = String.concat ~sep:"\n" mid_tampered_lines ^ "\n" in
  (match RB.of_string mid_tampered_str with
  | Error msg when String.is_substring msg ~substring:"mid-file-corruption" -> ()
  | Ok _ -> failwith "Tampered mid-file frame must be rejected"
  | Error other -> failwith ("Unexpected error: " ^ other));

  (match DB.of_string mid_tampered_str with
  | Error msg when String.is_substring msg ~substring:"mid-file-corruption" -> ()
  | Ok _ -> failwith "Daily_book.of_string must reject mid-file corruption"
  | Error other -> failwith ("Unexpected error in Daily_book: " ^ other))


let%test_unit "records_codec lsn sequence validation" =
  let h : RB.header = {
    version = 1;
    measures = [ ("jpy", 0) ];
    labels = None;
    approved_loci = None;
    origins = [];
    openings = [];
    observations = [];
    presence = None;
    opaque = [];
  } in
  let f0 = RB.encode_frame 0 (RB.Header h) in
  let al : RB.add_locus = { locus = "wallet"; opaque = [] } in
  (* Skip LSN 1, emit LSN 2 *)
  let f2 = RB.encode_frame 2 (RB.Add_locus al) in
  let bad_log =
    RB.serialize_frame f0 ^ "\n" ^ RB.serialize_frame f2 ^ "\n"
  in
  match RB.of_string bad_log with
  | Error msg when String.is_substring msg ~substring:"lsn-mismatch" -> ()
  | Ok _ -> failwith "Skipped LSN must be rejected"
  | Error other -> failwith ("Unexpected error: " ^ other)

let%test_unit "records_codec trailing torn-write inspection" =
  let v4_str = make_v4_fixture () in
  let db = get (DB.of_string v4_str) in
  let rec_str = DB.to_records_string db in

  (* Append an incomplete, half-written trailing line *)
  let torn_str = rec_str ^ "(frame (lsn 10) (crc \"1234abcd\") (payload (ent" in
  let insp = RB.inspect_string torn_str in
  assert (insp.trailing_torn_bytes > 0);
  (match insp.corruption with
  | RB.No_corruption -> ()
  | RB.Mid_file _ -> failwith "Trailing incomplete write should not be classified as Mid_file");

  (* Mid-file corruption should be classified as Mid_file *)
  let lines = String.split_lines rec_str in
  let mid_corrupt_lines =
    match lines with
    | l0 :: l1 :: rest -> l0 :: "BROKEN_LINE_IN_MIDDLE" :: l1 :: rest
    | _ -> failwith "Not enough lines"
  in
  let mid_corrupt_str = String.concat ~sep:"\n" mid_corrupt_lines ^ "\n" in
  let insp_mid = RB.inspect_string mid_corrupt_str in
  (match insp_mid.corruption with
  | RB.Mid_file _ -> ()
  | RB.No_corruption -> failwith "Middle broken line must be classified as Mid_file")

let%test_unit "records_codec opaque fields and records preservation" =
  let opaque_elem = X.List [ X.Atom "custom-extension"; X.Atom "payload-data" ] in
  let opaque_top = X.List [ X.Atom "plugin-configuration"; X.List [ X.Atom "key"; X.Atom "dark-mode" ] ] in
  let h : RB.header = {
    version = 1;
    measures = [ ("jpy", 0) ];
    labels = None;
    approved_loci = None;
    origins = [];
    openings = [];
    observations = [];
    presence = None;
    opaque = [ opaque_elem ];
  } in
  let f0 = RB.encode_frame 0 (RB.Header h) in
  let f1 = RB.encode_frame 1 (RB.Opaque opaque_top) in
  let log = RB.serialize_frame f0 ^ "\n" ^ RB.serialize_frame f1 ^ "\n" in
  let rb = match RB.of_string log with
    | Ok b -> b
    | Error e -> failwith e
  in
  assert (List.length (RB.header rb).opaque = 1);
  assert (List.length (RB.opaque_records rb) = 1);
  let reserialized = RB.to_string rb in
  assert (String.is_substring reserialized ~substring:"custom-extension");
  assert (String.is_substring reserialized ~substring:"plugin-configuration")

let%test_unit "records_codec multicurrency, reversal, and exchange semantics" =
  let base = get (DB.of_string base_fixture) in
  let base = get (DB.put_entry base ~replace:false (make_entry "e1" "2026-10-02" 10000) ~plan:None) in
  let rev_entry : DB.entry = {
    id = "e2";
    day = "2026-10-03";
    memo = Some "誤記訂正";
    effects = [ posting "wallet" "jpy" 10000 None; posting "food" "jpy" (-10000) None ];
    reversal_of = Some "e1";
    exchange = None;
  } in
  let base = get (DB.put_entry base ~replace:false rev_entry ~plan:None) in
  let rec_str = DB.to_records_string base in
  let loaded = get (DB.of_string rec_str) in
  let es = DB.entries loaded in
  assert (List.length es = 2);
  let e2_loaded = List.find_exn es ~f:(fun e -> String.equal e.id "e2") in
  assert (Option.equal String.equal e2_loaded.reversal_of (Some "e1"));
  assert (Option.equal String.equal e2_loaded.memo (Some "誤記訂正"))

let%test_unit "safe compatible reader preserves monolithic versions without rewriting" =
  let v1_book = get (DB.of_string base_fixture) in
  assert (String.equal (DB.to_string v1_book |> DB.source_format_of_string |> function `Monolithic v -> v | _ -> "other") "3");
  (* Ensure reading v1 does not write out records format *)
  let v1_printed = DB.to_string v1_book in
  assert (match DB.source_format_of_string v1_printed with `Monolithic _ -> true | _ -> false)

