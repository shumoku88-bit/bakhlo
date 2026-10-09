open Base

module D = Bakhlo_domain
module RB = Bakhlo_sexp.Records_book
module DA = Bakhlo_sexp.Durable_append

let make_temp_log () =
  let path = Stdlib.Filename.temp_file "bakhlo_test_durable_" ".log" in
  let lock_path = path ^ ".lock" in
  (* Register cleanup *)
  (path, lock_path)

let cleanup_paths (path, lock_path) =
  (try Stdlib.Sys.remove path with _ -> ());
  (try Stdlib.Sys.remove lock_path with _ -> ())

let make_test_entry id day token_opt amount_jpy : RB.entry =
  let lid = Result.ok_or_failwith (Result.map_error (D.Identifier.Locus.of_string "wallet") ~f:(fun _ -> "lid")) in
  let mid = Result.ok_or_failwith (Result.map_error (D.Identifier.Measure.of_string "jpy") ~f:(fun _ -> "mid")) in
  let p1 = D.Effect.create ~locus:lid ~measure:mid ~quantity:(D.Quantity.of_quanta (Z.of_int (-amount_jpy))) ~key:None in
  let lid2 = Result.ok_or_failwith (Result.map_error (D.Identifier.Locus.of_string "food") ~f:(fun _ -> "lid2")) in
  let p2 = D.Effect.create ~locus:lid2 ~measure:mid ~quantity:(D.Quantity.of_quanta (Z.of_int amount_jpy)) ~key:None in
  {
    id;
    day;
    token = token_opt;
    memo = Some "ランチ";
    effects = [ p1; p2 ];
    reversal_of = None;
    exchange = None;
    opaque = [];
  }

let make_test_header () : RB.header =
  {
    version = 1;
    measures = [ ("jpy", 0) ];
    labels = None;
    approved_loci = Some [ "wallet"; "food" ];
    origins = [];
    openings = [];
    observations = [];
    presence = None;
    opaque = [];
  }

let%test_unit "durable_append clean creation, sequential appends, and re-open" =
  let paths = make_temp_log () in
  let path, _ = paths in
  Stdlib.Fun.protect ~finally:(fun () -> cleanup_paths paths) (fun () ->
    (* 1. Initial open of fresh file *)
    let engine, action = match DA.recover_and_open path with
      | Ok res -> res
      | Error e -> failwith e
    in
    (match action with
    | DA.Clean { last_lsn = -1; total_frames = 0 } -> ()
    | _ -> failwith "Expected clean empty log");
    assert (DA.current_lsn engine = -1);

    let session = DA.create_session ~session_id:"sess-1" () in

    (* 2. Append header at LSN 0 *)
    let h = make_test_header () in
    let res0 = DA.append_payload engine ~session ~expected_lsn:0 ~token:None ~event_id:"header" ~payload:(RB.Header h) in
    (match res0 with
    | DA.Commit_success { lsn = 0; event_id = "header" } -> ()
    | _ -> failwith "Header append failed");
    assert (DA.current_lsn engine = 0);

    (* 3. Append entry at LSN 1 *)
    let e1 = make_test_entry "e1" "2026-10-09" (Some "tok-1") 1200 in
    let res1 = DA.append_entry engine ~session ~expected_lsn:1 e1 in
    (match res1 with
    | DA.Commit_success { lsn = 1; event_id = "e1" } -> ()
    | _ -> failwith "Entry 1 append failed");
    assert (DA.current_lsn engine = 1);

    (* 4. Close and re-open from disk *)
    DA.close_engine engine;
    let engine2, action2 = match DA.recover_and_open path with
      | Ok res -> res
      | Error e -> failwith e
    in
    (match action2 with
    | DA.Clean { last_lsn = 1; total_frames = 2 } -> ()
    | _ -> failwith "Expected clean log with 2 frames");
    assert (DA.current_lsn engine2 = 1);

    (* 5. Append entry at LSN 2 *)
    let e2 = make_test_entry "e2" "2026-10-09" (Some "tok-2") 850 in
    let res2 = DA.append_entry engine2 ~session ~expected_lsn:2 e2 in
    (match res2 with
    | DA.Commit_success { lsn = 2; event_id = "e2" } -> ()
    | _ -> failwith "Entry 2 append failed");
    assert (DA.current_lsn engine2 = 2))

let%test_unit "durable_append lsn conflict detection" =
  let paths = make_temp_log () in
  let path, _ = paths in
  Stdlib.Fun.protect ~finally:(fun () -> cleanup_paths paths) (fun () ->
    let engine, _ = Result.ok_or_failwith (DA.recover_and_open path) in
    let session = DA.create_session ~session_id:"sess-1" () in
    let h = make_test_header () in
    let _ = DA.append_payload engine ~session ~expected_lsn:0 ~token:None ~event_id:"header" ~payload:(RB.Header h) in

    (* Expected is 1, but caller erroneously requests expected_lsn: 5 *)
    let e1 = make_test_entry "e1" "2026-10-09" (Some "tok-1") 1200 in
    let res = DA.append_entry engine ~session ~expected_lsn:5 e1 in
    match res with
    | DA.Lsn_conflict { expected = 5; actual = 1 } -> ()
    | _ -> failwith "Expected LSN conflict")

let%test_unit "durable_append request_token idempotency and drift refusal" =
  let paths = make_temp_log () in
  let path, _ = paths in
  Stdlib.Fun.protect ~finally:(fun () -> cleanup_paths paths) (fun () ->
    let engine, _ = Result.ok_or_failwith (DA.recover_and_open path) in
    let session = DA.create_session ~session_id:"sess-1" () in
    let h = make_test_header () in
    let _ = DA.append_payload engine ~session ~expected_lsn:0 ~token:None ~event_id:"header" ~payload:(RB.Header h) in

    let e1 = make_test_entry "e1" "2026-10-09" (Some "tok-1") 1200 in
    let res1 = DA.append_entry engine ~session ~expected_lsn:1 e1 in
    (match res1 with
    | DA.Commit_success { lsn = 1; event_id = "e1" } -> ()
    | _ -> failwith "Initial commit failed");

    (* Retry with exact same token and same payload: Fast-Ack Idempotent Duplicate *)
    let res_retry = DA.append_entry engine ~session ~expected_lsn:2 e1 in
    (match res_retry with
    | DA.Idempotent_duplicate { lsn = 1; event_id = "e1" } -> ()
    | _ -> failwith "Expected Idempotent_duplicate for exact same payload");
    assert (DA.current_lsn engine = 1); (* LSN did not advance *)

    (* Retry with same token but DIFFERENT payload: Payload Drift Refused *)
    let e1_drift = make_test_entry "e1" "2026-10-09" (Some "tok-1") 9999 in
    let res_drift = DA.append_entry engine ~session ~expected_lsn:2 e1_drift in
    (match res_drift with
    | DA.Payload_drift_refused _ -> ()
    | _ -> failwith "Expected Payload_drift_refused for modified payload");
    assert (DA.current_lsn engine = 1))

let%test_unit "durable_append in-doubt commit detection and session reconciliation" =
  let paths = make_temp_log () in
  let path, _ = paths in
  Stdlib.Fun.protect ~finally:(fun () -> cleanup_paths paths) (fun () ->
    let engine, _ = Result.ok_or_failwith (DA.recover_and_open path) in
    let session = DA.create_session ~session_id:"client-sess" () in
    let h = make_test_header () in
    let _ = DA.append_payload engine ~session ~expected_lsn:0 ~token:None ~event_id:"header" ~payload:(RB.Header h) in

    let e1 = make_test_entry "e1" "2026-10-09" (Some "tok-1") 1200 in
    let res = DA.append_entry engine ~session ~expected_lsn:1 e1 in
    (match res with
    | DA.Commit_success { lsn = 1; event_id = "e1" } -> ()
    | _ -> failwith "Append failed");

    (* Simulate crash BEFORE client receives or records the Ack:
       session.last_acknowledged_token is None while storage holds tok-1 *)
    let status_in_doubt = DA.check_in_doubt engine ~session in
    (match status_in_doubt with
    | DA.In_doubt_detected { unacknowledged_token = "tok-1"; lsn = 1; event_id = "e1" } -> ()
    | _ -> failwith "Expected in-doubt commit detection");

    (* Client receives or recovers Ack and acknowledges session *)
    DA.acknowledge_session session ~token:"tok-1" ~lsn:1;
    let status_cleared = DA.check_in_doubt engine ~session in
    (match status_cleared with
    | DA.In_doubt_none -> ()
    | _ -> failwith "In-doubt status should be cleared after acknowledgment"))

let%test_unit "durable_append torn-write trailing truncation recovery" =
  let paths = make_temp_log () in
  let path, _ = paths in
  Stdlib.Fun.protect ~finally:(fun () -> cleanup_paths paths) (fun () ->
    let engine, _ = Result.ok_or_failwith (DA.recover_and_open path) in
    let session = DA.create_session ~session_id:"sess-1" () in
    let h = make_test_header () in
    let _ = DA.append_payload engine ~session ~expected_lsn:0 ~token:None ~event_id:"header" ~payload:(RB.Header h) in
    let e1 = make_test_entry "e1" "2026-10-09" (Some "tok-1") 1200 in
    let _ = DA.append_entry engine ~session ~expected_lsn:1 e1 in
    DA.close_engine engine;

    (* Inject trailing torn-write (half-written line without ending newline) *)
    let oc = Stdlib.open_out_gen [ Stdlib.Open_wronly; Stdlib.Open_append ] 0o600 path in
    Stdlib.output_string oc "(frame (lsn 2) (crc \"cbf43926\") (payload (entry (id \"e2\") (day \"2026-";
    Stdlib.close_out oc;

    (* Re-open: should safely detect trailing torn-write and truncate it back to LSN 1 *)
    let engine2, action = match DA.recover_and_open path with
      | Ok res -> res
      | Error e -> failwith e
    in
    (match action with
    | DA.Torn_write_truncated { valid_lsn = 1; truncated_bytes } ->
        assert (truncated_bytes > 0)
    | _ -> failwith "Expected Torn_write_truncated");
    assert (DA.current_lsn engine2 = 1);

    (* Verify storage is fully operable and can accept next append at LSN 2 *)
    let e2 = make_test_entry "e2" "2026-10-09" (Some "tok-2") 5000 in
    let res2 = DA.append_entry engine2 ~session ~expected_lsn:2 e2 in
    (match res2 with
    | DA.Commit_success { lsn = 2; event_id = "e2" } -> ()
    | _ -> failwith "Append after torn-write recovery failed");
    assert (DA.current_lsn engine2 = 2))

let%test_unit "durable_append mid-file corruption fail-closed protection" =
  let paths = make_temp_log () in
  let path, _ = paths in
  Stdlib.Fun.protect ~finally:(fun () -> cleanup_paths paths) (fun () ->
    let engine, _ = Result.ok_or_failwith (DA.recover_and_open path) in
    let session = DA.create_session ~session_id:"sess-1" () in
    let h = make_test_header () in
    let _ = DA.append_payload engine ~session ~expected_lsn:0 ~token:None ~event_id:"header" ~payload:(RB.Header h) in
    let e1 = make_test_entry "e1" "2026-10-09" (Some "tok-1") 1200 in
    let _ = DA.append_entry engine ~session ~expected_lsn:1 e1 in
    let e2 = make_test_entry "e2" "2026-10-09" (Some "tok-2") 2500 in
    let _ = DA.append_entry engine ~session ~expected_lsn:2 e2 in
    DA.close_engine engine;

    (* Read lines and tamper with the middle line (e1) *)
    let content = Stdlib.In_channel.with_open_bin path Stdlib.In_channel.input_all in
    let lines = String.split_lines content in
    let tampered_lines =
      match lines with
      | l0 :: _l1 :: l2 :: rest -> l0 :: "BROKEN_MIDDLE_FRAME" :: l2 :: rest
      | _ -> failwith "Not enough lines"
    in
    let tampered_content = String.concat ~sep:"\n" tampered_lines ^ "\n" in
    Stdlib.Out_channel.with_open_bin path (fun oc -> Stdlib.Out_channel.output_string oc tampered_content);

    (* Re-open: must fail closed and NEVER truncate the committed history *)
    let _, action = match DA.recover_and_open path with
      | Ok res -> res
      | Error e -> failwith e
    in
    match action with
    | DA.Corrupt_fail_closed _ -> ()
    | _ -> failwith "Mid-file corruption must trigger Corrupt_fail_closed")

let%test_unit "durable_append multiple consecutive crashes and recoveries" =
  let paths = make_temp_log () in
  let path, _ = paths in
  Stdlib.Fun.protect ~finally:(fun () -> cleanup_paths paths) (fun () ->
    let engine, _ = Result.ok_or_failwith (DA.recover_and_open path) in
    let session = DA.create_session ~session_id:"sess-1" () in
    let h = make_test_header () in
    let _ = DA.append_payload engine ~session ~expected_lsn:0 ~token:None ~event_id:"header" ~payload:(RB.Header h) in
    let e1 = make_test_entry "e1" "2026-10-09" (Some "tok-1") 1000 in
    let _ = DA.append_entry engine ~session ~expected_lsn:1 e1 in
    DA.close_engine engine;

    (* Crash 1: torn write on e2 *)
    let oc1 = Stdlib.open_out_gen [ Stdlib.Open_wronly; Stdlib.Open_append ] 0o600 path in
    Stdlib.output_string oc1 "(frame (lsn 2) (crc \"11111111\") (payload (ent";
    Stdlib.close_out oc1;

    (* Recover 1 *)
    let engine1, act1 = Result.ok_or_failwith (DA.recover_and_open path) in
    (match act1 with DA.Torn_write_truncated { valid_lsn = 1; _ } -> () | _ -> failwith "Recovery 1 failed");

    (* Append valid e2 *)
    let e2 = make_test_entry "e2" "2026-10-09" (Some "tok-2") 2000 in
    let _ = DA.append_entry engine1 ~session ~expected_lsn:2 e2 in
    DA.close_engine engine1;

    (* Crash 2: another torn write on e3 *)
    let oc2 = Stdlib.open_out_gen [ Stdlib.Open_wronly; Stdlib.Open_append ] 0o600 path in
    Stdlib.output_string oc2 "(frame (lsn 3) (crc \"22222222\") (payload (entry (id \"e3\")";
    Stdlib.close_out oc2;

    (* Recover 2 *)
    let engine2, act2 = Result.ok_or_failwith (DA.recover_and_open path) in
    (match act2 with DA.Torn_write_truncated { valid_lsn = 2; _ } -> () | _ -> failwith "Recovery 2 failed");

    (* Append valid e3 *)
    let e3 = make_test_entry "e3" "2026-10-09" (Some "tok-3") 3000 in
    let res3 = DA.append_entry engine2 ~session ~expected_lsn:3 e3 in
    (match res3 with DA.Commit_success { lsn = 3; event_id = "e3" } -> () | _ -> failwith "Append e3 failed");
    assert (DA.current_lsn engine2 = 3))

let%test_unit "durable_append concurrent session race and LSN conflict rejection" =
  let paths = make_temp_log () in
  let path, _ = paths in
  Stdlib.Fun.protect ~finally:(fun () -> cleanup_paths paths) (fun () ->
    let engine, _ = Result.ok_or_failwith (DA.recover_and_open path) in
    let sess_a = DA.create_session ~session_id:"worker-A" () in
    let sess_b = DA.create_session ~session_id:"worker-B" () in
    let h = make_test_header () in
    let _ = DA.append_payload engine ~session:sess_a ~expected_lsn:0 ~token:None ~event_id:"header" ~payload:(RB.Header h) in

    (* Both workers observe current LSN is 0, so both prepare next write expecting LSN 1 *)
    let e_a = make_test_entry "ea" "2026-10-09" (Some "tok-a") 100 in
    let e_b = make_test_entry "eb" "2026-10-09" (Some "tok-b") 200 in

    (* Worker A wins race *)
    let res_a = DA.append_entry engine ~session:sess_a ~expected_lsn:1 e_a in
    (match res_a with DA.Commit_success { lsn = 1; event_id = "ea" } -> () | _ -> failwith "Worker A should succeed");

    (* Worker B attempts with stale expected_lsn: 1 -> must be rejected with Lsn_conflict *)
    let res_b = DA.append_entry engine ~session:sess_b ~expected_lsn:1 e_b in
    (match res_b with
    | DA.Lsn_conflict { expected = 1; actual = 2 } -> ()
    | _ -> failwith "Worker B must be rejected due to LSN conflict");

    (* Worker B adapts to new LSN 2 and succeeds *)
    let res_b_retry = DA.append_entry engine ~session:sess_b ~expected_lsn:2 e_b in
    (match res_b_retry with
    | DA.Commit_success { lsn = 2; event_id = "eb" } -> ()
    | _ -> failwith "Worker B should succeed with adapted LSN"))

let%test_unit "durable_append tail CRC mismatch NEVER truncated (fails closed to protect committed data)" =
  let paths = make_temp_log () in
  let path, _ = paths in
  Stdlib.Fun.protect ~finally:(fun () -> cleanup_paths paths) (fun () ->
    let engine, _ = Result.ok_or_failwith (DA.recover_and_open path) in
    let session = DA.create_session ~session_id:"sess-1" () in
    let h = make_test_header () in
    let _ = DA.append_payload engine ~session ~expected_lsn:0 ~token:None ~event_id:"header" ~payload:(RB.Header h) in
    let e1 = make_test_entry "e1" "2026-10-09" (Some "tok-1") 1200 in
    let _ = DA.append_entry engine ~session ~expected_lsn:1 e1 in
    DA.close_engine engine;

    (* Corrupt the CRC of the final committed record e1 *)
    let content = Stdlib.In_channel.with_open_bin path Stdlib.In_channel.input_all in
    let tampered =
      match String.substr_index content ~pattern:"(crc " with
      | Some idx ->
          let prefix = String.prefix content (idx + 5) in
          let rest = String.drop_prefix content (idx + 13) in
          prefix ^ "00000000" ^ rest
      | None -> failwith "crc pattern not found"
    in
    Stdlib.Out_channel.with_open_bin path (fun oc -> Stdlib.Out_channel.output_string oc tampered);

    (* Re-open: MUST FAIL CLOSED! It must NOT truncate e1 just because it's the last line! *)
    let _, action = match DA.recover_and_open path with
      | Ok res -> res
      | Error e -> failwith e
    in
    match action with
    | DA.Corrupt_fail_closed { reason; _ } ->
        assert (String.is_substring reason ~substring:"checksum-mismatch")
    | _ -> failwith "Tail CRC mismatch must NEVER be auto-truncated; must fail closed")

let%test_unit "durable_append newline-terminated syntax error at tail fails closed" =
  let paths = make_temp_log () in
  let path, _ = paths in
  Stdlib.Fun.protect ~finally:(fun () -> cleanup_paths paths) (fun () ->
    let engine, _ = Result.ok_or_failwith (DA.recover_and_open path) in
    let session = DA.create_session ~session_id:"sess-1" () in
    let h = make_test_header () in
    let _ = DA.append_payload engine ~session ~expected_lsn:0 ~token:None ~event_id:"header" ~payload:(RB.Header h) in
    DA.close_engine engine;

    (* Append a line that has a terminating newline '\n' but has invalid syntax *)
    let oc = Stdlib.open_out_gen [ Stdlib.Open_wronly; Stdlib.Open_append ] 0o600 path in
    Stdlib.output_string oc "(frame (lsn 1) BAD SYNTAX LINE)\n";
    Stdlib.close_out oc;

    (* Because it has a newline '\n', it is a full completed line on disk, not an interrupted write.
       Therefore, it must fail closed and NOT truncate! *)
    let _, action = match DA.recover_and_open path with
      | Ok res -> res
      | Error e -> failwith e
    in
    match action with
    | DA.Corrupt_fail_closed _ -> ()
    | _ -> failwith "Newline-terminated tail syntax error must fail closed")

let%test_unit "durable_append sync_from_disk fails closed when log is corrupted on disk" =
  let paths = make_temp_log () in
  let path, _ = paths in
  Stdlib.Fun.protect ~finally:(fun () -> cleanup_paths paths) (fun () ->
    let engine, _ = Result.ok_or_failwith (DA.recover_and_open path) in
    let session = DA.create_session ~session_id:"sess-1" () in
    let h = make_test_header () in
    let _ = DA.append_payload engine ~session ~expected_lsn:0 ~token:None ~event_id:"header" ~payload:(RB.Header h) in
    let e1 = make_test_entry "e1" "2026-10-09" (Some "tok-1") 1000 in
    let _ = DA.append_entry engine ~session ~expected_lsn:1 e1 in

    (* Corrupt the file externally while engine is open *)
    let oc = Stdlib.open_out_gen [ Stdlib.Open_wronly; Stdlib.Open_append ] 0o600 path in
    Stdlib.output_string oc "BROKEN_CORRUPT_TRAILING_DATA_WITHOUT_NEWLINE";
    Stdlib.close_out oc;

    (* Next append must fail closed immediately *)
    let e2 = make_test_entry "e2" "2026-10-09" (Some "tok-2") 2000 in
    let res = DA.append_entry engine ~session ~expected_lsn:2 e2 in
    match res with
    | DA.Storage_error msg ->
        assert (String.is_substring msg ~substring:"storage-corrupted-fail-closed")
    | _ -> failwith "Append on corrupted log must fail closed with Storage_error")

let%test_unit "durable_append idempotent retry succeeds even with stale expected_lsn" =
  let paths = make_temp_log () in
  let path, _ = paths in
  Stdlib.Fun.protect ~finally:(fun () -> cleanup_paths paths) (fun () ->
    let engine, _ = Result.ok_or_failwith (DA.recover_and_open path) in
    let session = DA.create_session ~session_id:"sess-1" () in
    let h = make_test_header () in
    let _ = DA.append_payload engine ~session ~expected_lsn:0 ~token:None ~event_id:"header" ~payload:(RB.Header h) in
    let e1 = make_test_entry "e1" "2026-10-09" (Some "tok-1") 1000 in
    let _ = DA.append_entry engine ~session ~expected_lsn:1 e1 in
    let e2 = make_test_entry "e2" "2026-10-09" (Some "tok-2") 2000 in
    let _ = DA.append_entry engine ~session ~expected_lsn:2 e2 in
    assert (DA.current_lsn engine = 2);

    (* Retry e1 with STALE expected_lsn = 1 (or 0): token idempotency MUST take priority over LSN check *)
    let res_retry = DA.append_entry engine ~session ~expected_lsn:1 e1 in
    (match res_retry with
    | DA.Idempotent_duplicate { lsn = 1; event_id = "e1" } -> ()
    | _ -> failwith "Idempotent retry with stale expected_lsn must succeed");

    (* Token duplicate with payload drift must refuse even with stale expected_lsn *)
    let e1_drift = make_test_entry "e1" "2026-10-09" (Some "tok-1") 9999 in
    let res_drift = DA.append_entry engine ~session ~expected_lsn:1 e1_drift in
    (match res_drift with
    | DA.Payload_drift_refused _ -> ()
    | _ -> failwith "Drift with stale expected_lsn must still refuse"))

let%test_unit "durable_append recovery fails closed when truncate fails" =
  let paths = make_temp_log () in
  let path, _ = paths in
  Stdlib.Fun.protect ~finally:(fun () -> cleanup_paths paths) (fun () ->
    let engine, _ = Result.ok_or_failwith (DA.recover_and_open path) in
    let session = DA.create_session ~session_id:"sess-1" () in
    let h = make_test_header () in
    let _ = DA.append_payload engine ~session ~expected_lsn:0 ~token:None ~event_id:"header" ~payload:(RB.Header h) in
    DA.close_engine engine;

    (* Add trailing torn write *)
    let oc = Stdlib.open_out_gen [ Stdlib.Open_wronly; Stdlib.Open_append ] 0o600 path in
    Stdlib.output_string oc "(frame (lsn 1) (torn";
    Stdlib.close_out oc;

    (* Make file read-only so ftruncate / write fails *)
    Unix.chmod path 0o400;

    let res = DA.recover_and_open path in
    (* Reset chmod for cleanup *)
    (try Unix.chmod path 0o600 with _ -> ());
    match res with
    | Error msg ->
        assert (String.is_substring msg ~substring:"truncate-failed-fail-closed")
    | Ok _ -> failwith "Recovery must fail closed when truncate fails")

let%test_unit "durable_append latest_token and latest_event_id tracking" =
  let paths = make_temp_log () in
  let path, _ = paths in
  Stdlib.Fun.protect ~finally:(fun () -> cleanup_paths paths) (fun () ->
    let engine, _ = Result.ok_or_failwith (DA.recover_and_open path) in
    let session = DA.create_session ~session_id:"sess-1" () in
    let h = make_test_header () in
    let _ = DA.append_payload engine ~session ~expected_lsn:0 ~token:None ~event_id:"header" ~payload:(RB.Header h) in
    assert (Option.is_none (DA.latest_token engine));

    let e1 = make_test_entry "e1" "2026-10-09" (Some "tok-1") 1000 in
    let _ = DA.append_entry engine ~session ~expected_lsn:1 e1 in
    assert (Option.equal String.equal (DA.latest_token engine) (Some "tok-1"));
    assert (Option.equal String.equal (DA.latest_event_id engine) (Some "e1")))


