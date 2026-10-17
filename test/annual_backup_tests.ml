module F = Daily_file
module Backup = Annual_backup

let require condition why = if not condition then failwith why
let directory () =
  let path = Filename.temp_file "bakhlo-annual-backup-" "" in
  Sys.remove path;
  Unix.mkdir path 0o700;
  path
let absent_path root name = Filename.concat root name
let refused f =
  try f (); false with F.Refused _ | Unix.Unix_error _ | Sys_error _ -> true

let%expect_test "annual archive roundtrip is exact and restoration is never adoption" =
  let root = directory () in
  let path = absent_path root "2026.sexp" in
  let before = F.create_annual_empty ~year:2026 ~path ~measure:"jpy" ~scale:0 in
  let after = F.rollover ~session:before in
  let originals = F.annual_sources after in
  let archive = absent_path root "backup.sexp" in
  ignore (Backup.backup ~session:after ~target:archive);
  let raw_archive = F.read archive in
  let restore_dir = absent_path root "restored" in
  let restored_path = Backup.restore ~source:archive ~directory:restore_dir in
  let restored = F.load ~annual_year:2027 restored_path in
  require (List.map snd originals = List.map snd (F.annual_sources restored)) "not-lossless";
  List.iter (fun (path, bytes) -> require (F.read path = bytes) "original-touched") originals;
  require (F.read archive = raw_archive) "archive-touched";
  require (refused (fun () -> ignore (Backup.restore ~source:archive ~directory:restore_dir))) "existing-destination-overwritten";
  require (refused (fun () -> ignore (Backup.backup ~session:after ~target:archive))) "archive-overwritten";
  require (F.read archive = raw_archive) "collision-changed-backup";
  [%expect {| |}]

let%expect_test "annual archive rejects replaced bytes, incomplete chains, wrong selection before creating files" =
  let root = directory () in
  let initial = F.create_annual_empty ~year:2026 ~path:(absent_path root "2026.sexp") ~measure:"jpy" ~scale:0 in
  let current = F.rollover ~session:initial in
  let files = F.annual_sources current |> List.mapi (fun index (_, bytes) -> 2026 + index, bytes) in
  let bytes = Backup.encode 2027 files in
  let incomplete = Backup.encode 2027 [List.hd files] in
  require (refused (fun () -> ignore (Backup.decode incomplete))) "missing-successor-accepted";
  require (refused (fun () -> ignore (Backup.decode (Backup.encode 2026 files)))) "wrong-selection-accepted";
  let wrong_pair = match files with
    | [(_, prior); (_, successor)] -> Backup.encode 2027 [2026, prior ^ "\n"; 2027, successor]
    | _ -> failwith "fixture-chain" in
  require (refused (fun () -> ignore (Backup.decode wrong_pair))) "mismatched-fingerprint-accepted";
  let corrupt = absent_path root "corrupt-backup.sexp" in
  F.write_new corrupt (String.sub bytes 0 (String.length bytes - 8));
  let destination = absent_path root "must-not-exist" in
  require (refused (fun () -> ignore (Backup.restore ~source:corrupt ~directory:destination))) "corrupt-backup-accepted";
  require (not (Sys.file_exists destination)) "invalid-archive-created-target";
  let _, rows = Backup.decode bytes in
  require (List.map snd rows = List.map snd files) "decoded-bytes-changed";
  [%expect {| |}]
