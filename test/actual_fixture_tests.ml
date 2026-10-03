open Base
module D = Loam_domain
module A = Loam_application.Actual_quantity_preview
module H = Loam_application.Current_quantity_groups
module P = Loam_application.Current_quantity_projection
module F = Fixtures
module Input = Loam_cli.Actual_fixture_input
module C = Loam_cli.Actual_fixture_command
let require = F.require
let ok = function Ok value -> value | Error _ -> failwith "valid fixture refused"
let validity event date : A.validity = { event = F.id event; valid_on = date }
let command events validities : A.command = { events; validities; corrections = []; groups = [] }
let document rows = String.concat ~sep:"\n" ("LOAM-OCAML-ACTUAL-FIXTURE\t1" :: rows @ [ "END"; "" ])
let quantity image coordinate = P.quantity (ok (A.query image coordinate))

let%expect_test "base Actual validity is independently unique, closed and complete" =
  let a = F.event "a" in
  let v = validity "a" "2026-10-03" in
  require (Result.is_ok (A.run (command [] []))) "explicit empty source";
  require (Result.is_ok (A.run (command [ a ] [ v ]))) "explicit base validity";
  (match A.run (command [ a; a ] [ v ]) with Error (Events _) -> () | _ -> failwith "Event identity gate");
  (match A.run (command [ a ] []) with Error (Missing_validity { event }) -> require (D.Identifier.Event.equal event (F.id "a")) "missing witness" | _ -> failwith "missing validity");
  (match A.run (command [ a ] [ v; v ]) with
   | Error (Repeated_validity { event; first_position = 1; position = 2 }) -> require (D.Identifier.Event.equal event (F.id "a")) "duplicate witness"
   | _ -> failwith "duplicate validity");
  (match A.run (command [ a ] [ validity "outside" "2026-10-03" ]) with
   | Error (Unknown_validity_event { event; position = 1 }) -> require (D.Identifier.Event.equal event (F.id "outside")) "unknown witness"
   | _ -> failwith "orphan validity");
  let invalid = { v with valid_on = "2026-02-30" } in
  (match A.run (command [ a ] [ invalid; v ]) with Error (Invalid_date { position = 1; text = "2026-02-30" }) -> () | _ -> failwith "ordered date refusal");
  Stdlib.Printf.printf "dates do not supply Event membership, precedence or quantity support\n";
  [%expect {| dates do not supply Event membership, precedence or quantity support |}]
;;

let%expect_test "strict Gregorian base dates keep leap-century and lexical boundaries" =
  let admitted date = Result.is_ok (A.run (command [ F.event "a" ] [ validity "a" date ])) in
  List.iter [ "0001-01-01"; "9999-12-31"; "2000-02-29"; "2024-02-29"; "1900-02-28"; "2026-04-30" ]
    ~f:(fun date -> require (admitted date) ("valid date " ^ date));
  List.iter [ "0000-01-01"; "1900-02-29"; "2100-02-29"; "2026-02-29"; "2026-04-31"; "2026-00-01";
      "2026-13-01"; "2026-01-00"; "2026-01-32"; "2026-1-01"; "+026-01-01"; " 2026-01-01"; "2026-01-01 " ]
    ~f:(fun date -> require (not (admitted date)) ("invalid date " ^ date));
  Stdlib.Printf.printf "six valid and thirteen invalid calendar/lexical specimens\n";
  [%expect {| six valid and thirteen invalid calendar/lexical specimens |}]
;;

let%expect_test "synthetic decoder preserves exact identities, signed quanta and neutral Effects" =
  let huge = Z.shift_left Z.one 160 in
  let input = document [ "EVENT\t a \t2026-10-03"; "EFFECT\t wallet \tUSD\t+0007";
      "EFFECT\t wallet \tUSD\t0"; "EFFECT\t wallet \tjpy\t" ^ Z.to_string (Z.neg huge);
      "END-EVENT"; "GROUP"; "ASSERT\t wallet \tUSD\t-7"; "END-GROUP" ] in
  let draft = ok (Input.decode input) in
  let event = List.hd_exn draft.events in
  require (String.equal (D.Identifier.Event.to_string (D.Event.id event)) " a ") "exact Event token";
  require (Int.equal (List.length (D.Event.effects event)) 3) "neutral zero/mixed Effects retained";
  require (Result.is_error (D.Movement.validate (D.Event.effects event))) "no ordinary Movement narrowing";
  let image = ok (A.run draft) in
  let c = F.coordinate ~unit:"USD" " wallet " in
  require (Z.equal (D.Quantity.quanta (quantity image c)) Z.zero) "exact assertion plus delta";
  let expected = Source_oracle.sum_events draft.events c in
  require (Z.equal expected (D.Quantity.quanta (P.delta (ok (A.query image c))))) "original-Effect oracle";
  Stdlib.Printf.printf "anonymous Effects and exact tokens survive decode/admission/query\n";
  [%expect {| anonymous Effects and exact tokens survive decode/admission/query |}]
;;

let%expect_test "unknown formats, metadata, unsupported support and truncated blocks refuse" =
  let invalid =
    [ ""; "LOAM-NORMALIZED-ACTUAL\t1\nEND\n"; "LOAM-OCAML-ACTUAL-FIXTURE\t2\nEND\n";
      document [ "SCHEDULED\ta" ]; document [ "OPENING\twallet\tjpy\ta" ];
      document [ "ZERO-ORIGIN\twallet\tjpy" ]; document [ "PRESENCE\twallet\tjpy" ];
      document [ "DESCRIPTION\ta\tindependent metadata" ]; document [ "KEYED-EFFECT\tkey\twallet\tjpy\t1" ];
      document [ "EVENT\ta\t2026-10-03" ]; document [ "GROUP" ];
      document [ "EFFECT\twallet\tjpy\t1" ]; document [ "" ];
      document [ "EVENT\ta\t2026-10-03"; "EFFECT\twallet\tjpy\t0x10"; "END-EVENT" ];
      document [ "EVENT\ta\t2026-10-03"; "EFFECT\twallet\tjpy\t 1"; "END-EVENT" ];
      "LOAM-OCAML-ACTUAL-FIXTURE\t1\nEND"; document [] ^ "END\n" ] in
  List.iter invalid ~f:(fun text -> match Input.decode text with
    | Error { line; message } -> require (line > 0 && not (String.is_empty message)) "useful syntax refusal"
    | Ok _ -> failwith "unsupported/truncated input silently admitted");
  (match Input.decode (document [ "GROUP"; "ASSERT\t\tjpy\t1"; "END-GROUP" ]) with
   | Error { line = 3; message = _ } -> () | _ -> failwith "one-based line witness");
  Stdlib.Printf.printf "no fallback, discarded rows or partial image\n";
  [%expect {| no fallback, discarded rows or partial image |}]
;;

let%expect_test "one source composes correction roots, independent group cuts and assertion unknown" =
  let source = [ F.event "a"; D.Event.create ~id:(F.id "b") ~effects:[ F.change (F.coordinate "wallet") (Z.of_int 999) ];
    D.Event.create ~id:(F.id "x") ~effects:[ F.change (F.coordinate "wallet") (Z.of_int (-10)) ] ] in
  let groups : H.group list =
    [ { reflected_roots = [ F.id "a" ]; assertions = [ F.assertion (F.coordinate "wallet") (Z.of_int 1000) ] };
      { reflected_roots = [ F.id "a"; F.id "x" ]; assertions = [ F.assertion (F.coordinate ~unit:"usd" "wallet") Z.zero ] } ] in
  let draft : A.command = { events = source; validities = [ validity "a" "2026-10-03"; validity "b" "2026-01-01"; validity "x" "2026-02-01" ];
    corrections = [ F.edge "a" "b" ]; groups } in
  let image = ok (A.run draft) in
  require (Z.equal (D.Quantity.quanta (quantity image (F.coordinate "wallet"))) (Z.of_int 990)) "root cut contribution";
  require (Z.equal (D.Quantity.quanta (quantity image (F.coordinate ~unit:"usd" "wallet"))) Z.zero) "explicit known zero";
  (match A.query image (F.coordinate "missing") with Error (P.Assertion_unknown _) -> () | _ -> failwith "unknown became zero");
  let reversed = ok (A.run { draft with events = List.rev source; validities = List.rev draft.validities; groups = List.rev groups }) in
  require (D.Quantity.equal (quantity image (F.coordinate "wallet")) (quantity reversed (F.coordinate "wallet"))) "dates/list order not winner";
  require (List.equal F.equal_event source (D.Event_memory.events (Loam_application.Correction_frontier.retained_events
    (H.source_frontier (A.source_groups image))))) "source retained";
  require (List.equal (fun (a : A.validity) b -> D.Identifier.Event.equal a.event b.event && String.equal a.valid_on b.valid_on)
    draft.validities (A.validities image)) "independent base dates retained";
  (match A.run { draft with corrections = [ F.edge "a" "missing" ] } with Error (Corrections _) -> () | _ -> failwith "open correction");
  (match A.run { draft with groups = groups @ groups } with Error (Groups _) -> () | _ -> failwith "group overlap");
  Stdlib.Printf.printf "990 / known zero / unknown; no date shortcut or merged cuts\n";
  [%expect {| 990 / known zero / unknown; no date shortcut or merged cuts |}]
;;

let%expect_test "file failure cannot become an empty successful source; empty fixture remains unsupported" =
  let request : C.request = { path = "synthetic.fixture"; coordinate = F.coordinate "wallet" } in
  let failed = C.evaluate request (Error "simulated read failure") in
  require (Int.equal failed.exit_code 1 && String.is_empty failed.stdout) "honest read failure";
  require (String.is_substring failed.stderr ~substring:"simulated read failure") "retained failure diagnostic";
  let escaped = C.evaluate { request with path = "file\nname" } (Error "failure\027\n") in
  require (not (String.exists escaped.stderr ~f:(Char.equal '\027')) &&
    Int.equal (String.count escaped.stderr ~f:(Char.equal '\n')) 1) "escaped shell diagnostics";
  let cycle = Loam_presentation.Actual_quantity_text.refusal
      (A.Corrections (Loam_application.Correction_frontier.Cycle { path = [ F.id "event\027\n" ] })) in
  require (not (String.exists cycle ~f:(Char.equal '\027')) &&
    Int.equal (String.count cycle ~f:(Char.equal '\n')) 1) "escaped retained cycle identities";
  let empty = C.evaluate request (Ok (document [])) in
  require (Int.equal empty.exit_code 3 && String.is_empty empty.stderr) "explicit unknown outcome";
  require (String.is_substring empty.stdout ~substring:"quantity unknown") "unknown not zero";
  (match C.plan [ "--help" ] with Help -> () | _ -> failwith "help plan");
  (match C.plan [] with Refused _ -> () | _ -> failwith "syntax plan");
  Stdlib.Printf.printf "read error exit 1; explicit unsupported exit 3; syntax/help without I/O\n";
  [%expect {| read error exit 1; explicit unsupported exit 3; syntax/help without I/O |}]
;;
