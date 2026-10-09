open Base

module D = Bakhlo_domain
module B = Bakhlo_sexp.Daily_book
module RB = Bakhlo_sexp.Records_book
module DA = Bakhlo_sexp.Durable_append

let id_ok = function
  | Ok v -> v
  | Error _ -> failwith "id error"

let make_temp_dir () =
  let path = Stdlib.Filename.temp_file "bakhlo_integ_" "_dir" in
  Stdlib.Sys.remove path;
  Unix.mkdir path 0o700;
  path

let cleanup_dir dir =
  try
    let files = Stdlib.Sys.readdir dir |> Array.to_list in
    List.iter files ~f:(fun f ->
      try Stdlib.Sys.remove (Stdlib.Filename.concat dir f) with _ -> ());
    Unix.rmdir dir
  with _ -> ()

let make_test_header () : RB.header = {
  version = 1;
  measures = [ ("jpy", 0); ("usd", 2) ];
  labels = None;
  approved_loci = Some [ "wallet"; "bank"; "food"; "income" ];
  origins = [];
  openings = [];
  observations = [];
  presence = None;
  opaque = [];
}

let make_test_entry id day token amount : RB.entry =
  let lw = id_ok (D.Identifier.Locus.of_string "wallet") in
  let lf = id_ok (D.Identifier.Locus.of_string "food") in
  let mj = id_ok (D.Identifier.Measure.of_string "jpy") in
  let p1 = D.Effect.create ~locus:lw ~measure:mj ~quantity:(D.Quantity.of_quanta (Z.of_int (-amount))) ~key:None in
  let p2 = D.Effect.create ~locus:lf ~measure:mj ~quantity:(D.Quantity.of_quanta (Z.of_int amount)) ~key:None in
  {
    id;
    day;
    token;
    memo = Some "テスト支出";
    effects = [ p1; p2 ];
    reversal_of = None;
    exchange = None;
    opaque = [];
  }

let%test_unit "application_integration: transparent compatible reader loads both formats" =
  let dir = make_temp_dir () in
  Stdlib.Fun.protect ~finally:(fun () -> cleanup_dir dir) (fun () ->
    let rec_path = Stdlib.Filename.concat dir "records.log" in
    let mono_path = Stdlib.Filename.concat dir "mono.sexp" in

    (* 1. Populate records file *)
    let engine, _ = Result.ok_or_failwith (DA.recover_and_open rec_path) in
    let session = DA.create_session ~session_id:"sess-1" () in
    let _ = DA.append_payload engine ~session ~expected_lsn:0 ~token:None ~event_id:"header" ~payload:(RB.Header (make_test_header ())) in
    let e1 = make_test_entry "e1" "2026-10-09" (Some "tok-1") 1000 in
    let _ = DA.append_entry engine ~session ~expected_lsn:1 e1 in
    DA.close_engine engine;

    (* 2. Load records file via Daily_book.of_string *)
    let rec_text = Stdlib.In_channel.with_open_bin rec_path Stdlib.In_channel.input_all in
    let rec_book = Result.ok_or_failwith (B.of_string rec_text) in
    assert (List.length (B.entries rec_book) = 1);

    (* 3. Write monolithic file via Daily_book.to_string *)
    let mono_text = B.to_string rec_book in
    Stdlib.Out_channel.with_open_bin mono_path (fun oc -> Stdlib.Out_channel.output_string oc mono_text);

    (* 4. Load monolithic file via Daily_book.of_string *)
    let loaded_mono_text = Stdlib.In_channel.with_open_bin mono_path Stdlib.In_channel.input_all in
    let mono_book = Result.ok_or_failwith (B.of_string loaded_mono_text) in
    assert (List.length (B.entries mono_book) = 1);
    assert (String.equal (List.hd_exn (B.entries mono_book)).id "e1"))

let%test_unit "application_integration: non-destructive format boundary enforcement" =
  let dir = make_temp_dir () in
  Stdlib.Fun.protect ~finally:(fun () -> cleanup_dir dir) (fun () ->
    let rec_path = Stdlib.Filename.concat dir "records.log" in
    let engine, _ = Result.ok_or_failwith (DA.recover_and_open rec_path) in
    let session = DA.create_session ~session_id:"sess-1" () in
    let _ = DA.append_payload engine ~session ~expected_lsn:0 ~token:None ~event_id:"header" ~payload:(RB.Header (make_test_header ())) in
    let e1 = make_test_entry "e1" "2026-10-09" (Some "tok-1") 1500 in
    let _ = DA.append_entry engine ~session ~expected_lsn:1 e1 in
    DA.close_engine engine;

    let rec_text = Stdlib.In_channel.with_open_bin rec_path Stdlib.In_channel.input_all in
    let loaded_rb = Result.ok_or_failwith (RB.of_string rec_text) in

    (* Daily_book.to_string always outputs monolithic, preserving old contract *)
    let daily_book = Result.ok_or_failwith (B.of_records loaded_rb) in
    let output_mono = B.to_string daily_book in
    assert (String.is_substring output_mono ~substring:"(bakhlo-daily");

    (* Records_book.to_string outputs canonical records with CRC *)
    let output_records = RB.to_string loaded_rb in
    assert (String.is_substring output_records ~substring:"(lsn 1)"))

let%test_unit "application_integration: durable append recovery and idempotent retry" =
  let dir = make_temp_dir () in
  Stdlib.Fun.protect ~finally:(fun () -> cleanup_dir dir) (fun () ->
    let rec_path = Stdlib.Filename.concat dir "records.log" in
    let engine, _ = Result.ok_or_failwith (DA.recover_and_open rec_path) in
    let session = DA.create_session ~session_id:"sess-1" () in
    let _ = DA.append_payload engine ~session ~expected_lsn:0 ~token:None ~event_id:"header" ~payload:(RB.Header (make_test_header ())) in
    let e1 = make_test_entry "e1" "2026-10-09" (Some "tok-1") 2000 in
    let res1 = DA.append_entry engine ~session ~expected_lsn:1 e1 in
    (match res1 with
    | DA.Commit_success { lsn = 1; event_id = "e1" } -> ()
    | _ -> failwith "First append should succeed");

    (* Idempotent retry with same token and payload: Fast-Ack *)
    let res_dup = DA.append_entry engine ~session ~expected_lsn:1 e1 in
    (match res_dup with
    | DA.Idempotent_duplicate { lsn = 1; event_id = "e1" } -> ()
    | _ -> failwith "Duplicate append should return Idempotent_duplicate");

    (* Payload drift with same token: rejected *)
    let e1_drift = make_test_entry "e1" "2026-10-09" (Some "tok-1") 9999 in
    let res_drift = DA.append_entry engine ~session ~expected_lsn:2 e1_drift in
    (match res_drift with
    | DA.Payload_drift_refused _ -> ()
    | _ -> failwith "Payload drift must be refused");
    DA.close_engine engine)
