open Base
module D = Loam_domain
module S = Loam_application.Actual_source
module F = Fixtures
module Input = Loam_cli.Current_fixture_input
module C = Loam_cli.Current_fixture_command
let ok = function Ok value -> value | Error _ -> failwith "valid syntax refused"
let document rows = String.concat ~sep:"\n" ("LOAM-OCAML-ACTUAL-FIXTURE\t2" :: rows @ [ "END"; "" ])

let%expect_test "decoding preserves exact identities and neutral Effects; source admission is separate" =
  let huge = Z.shift_left Z.one 160 in
  let text = document [ "EVENT\t a \t2026-10-03"; "EFFECT\t wallet \tUSD\t+0007";
    "EFFECT\t wallet \tUSD\t0"; "EFFECT\t wallet \tjpy\t" ^ Z.to_string (Z.neg huge); "END-EVENT" ] in
  let decoded = ok (Input.decode text) in
  let original = List.hd_exn decoded.source.events in
  F.require (String.equal (D.Identifier.Event.to_string (D.Event.id original)) " a ") "exact Event identity";
  let changes = D.Event.effects original in
  F.require (List.length changes = 3 && String.equal (D.Identifier.Locus.to_string (D.Effect.locus (List.hd_exn changes))) " wallet ") "no trimming or occurrence pruning";
  F.require (List.equal Z.equal (List.map changes ~f:(fun c -> D.Quantity.quanta (D.Effect.quantity c))) [ Z.of_int 7; Z.zero; Z.neg huge ]) "exact signed quanta and multiplicity";
  (match S.create decoded.source with Error (Zero_effect { event_position = 1; effect_position = 2; event = _ }) -> () | _ -> failwith "invalid source became usable");
  Stdlib.Printf.printf "exact raw evidence preserved; separate physical admission refuses it\n";
  [%expect {| exact raw evidence preserved; separate physical admission refuses it |}]
;;

let%expect_test "malformed/truncated/misplaced rows and obsolete formats never become partial success" =
  let invalid = [ ""; "LOAM-NORMALIZED-ACTUAL\t1\nEND\n"; "LOAM-OCAML-ACTUAL-FIXTURE\t1\nEND\n";
    document [ "SCHEDULED\ta" ]; document [ "DESCRIPTION\ta\tmetadata" ]; document [ "KEYED-EFFECT\tkey\twallet\tjpy\t1" ];
    document [ "EVENT\ta\t2026-10-03" ]; document [ "GROUP" ]; document [ "EFFECT\twallet\tjpy\t1" ]; document [ "" ];
    document [ "EVENT\ta\t2026-10-03"; "EFFECT\twallet\tjpy\t0x10"; "END-EVENT" ];
    document [ "EVENT\ta\t2026-10-03"; "EFFECT\twallet\tjpy\t 1"; "END-EVENT" ];
    "LOAM-OCAML-ACTUAL-FIXTURE\t2\nEND"; document [] ^ "END\n" ] in
  List.iter invalid ~f:(fun text -> match Input.decode text with
    | Error { line; message } -> F.require (line > 0 && not (String.is_empty message)) "useful syntax refusal"
    | Ok _ -> failwith "malformed evidence ignored");
  (match Input.decode (document [ "GROUP"; "ASSERT\t\tjpy\t1"; "END-GROUP" ]) with
   | Error { line = 3; message = _ } -> () | _ -> failwith "one-based line witness");
  Stdlib.Printf.printf "one format; no fallback, discarded rows or partial image\n";
  [%expect {| one format; no fallback, discarded rows or partial image |}]
;;

let%expect_test "read failures and cycle identities are escaped; help/syntax require no file" =
  let request : C.request = { path = "file\nname"; coordinate = F.coordinate "wallet" } in
  let failed = C.evaluate request (Error "failure\027\n") in
  F.require (failed.exit_code = 1 && String.is_empty failed.stdout &&
    not (String.exists failed.stderr ~f:(Char.equal '\027')) &&
    String.count failed.stderr ~f:(Char.equal '\n') = 1) "honest escaped read failure";
  let cycle = Loam_presentation.Current_quantity_text.source_refusal
    (S.Corrections (Loam_application.Correction_frontier.Cycle { path = [ F.id "event\027\n" ] })) in
  F.require (not (String.exists cycle ~f:(Char.equal '\027')) && String.count cycle ~f:(Char.equal '\n') = 1) "escaped cycle provenance";
  (match C.plan [ "--help" ] with Help -> () | _ -> failwith "help plan");
  (match C.plan [] with Refused _ -> () | _ -> failwith "syntax plan");
  Stdlib.Printf.printf "escaped provenance/errors; explicit read result; no help/syntax I/O\n";
  [%expect {| escaped provenance/errors; explicit read result; no help/syntax I/O |}]
;;
