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

let%expect_test "opening rows preserve forward references/order; decode never implies witness validity" =
  let rows = [ "OPENING\t wallet \tUSD\t event "; "OPENING\toffset\tUSD\t event ";
    "EVENT\t event \t2026-10-03"; "EFFECT\t wallet \tUSD\t+0007"; "EFFECT\toffset\tUSD\t-7"; "END-EVENT" ] in
  let decoded = ok (Input.decode (document rows)) in
  F.require (List.equal String.equal (List.map decoded.openings ~f:(fun declared -> D.Identifier.Event.to_string declared.opening_event)) [ " event "; " event " ]) "exact Event references, no allocation";
  F.require (List.equal F.same_coordinate (List.map decoded.openings ~f:(fun declared -> declared.coordinate)) [ F.coordinate ~unit:"USD" " wallet "; F.coordinate ~unit:"USD" "offset" ]) "exact coordinates and declaration order";
  let request : C.request = { path = "synthetic"; coordinate = F.coordinate ~unit:"USD" " wallet " } in
  let exact = C.evaluate request (Ok (document rows)) in
  F.require (exact.exit_code = 0 && String.is_empty exact.stderr && String.is_substring exact.stdout ~substring:"opening Event" && String.is_substring exact.stdout ~substring:"quantity=7") "opening end-to-end";
  let stale = document (rows @ [ "EVENT\treplacement\t2026-10-02"; "END-EVENT"; "CORRECTION\t event \treplacement" ]) in
  F.require (Result.is_ok (Input.decode stale)) "parser does not select frontier";
  let refused = C.evaluate request (Ok stale) in
  F.require (refused.exit_code = 1 && String.is_empty refused.stdout && String.is_substring refused.stderr ~substring:"is not current") "source-bound semantic gate";
  Stdlib.Printf.printf "explicit opening rows; exact forward references; source-bound admission before answer\n";
  [%expect {| explicit opening rows; exact forward references; source-bound admission before answer |}]
;;

let%expect_test "one shared presence block retains exact forward roots/coordinates without a scalar" =
  let rows = [ "PRESENCE"; "REFLECT\t a "; "PRESENT\t wallet \tUSD"; "PRESENT\tquiet\tjpy"; "END-PRESENCE";
    "EVENT\t a \t2026-10-03"; "END-EVENT"; "EVENT\tb\t2026-10-02";
    "EFFECT\t wallet \tUSD\t1"; "EFFECT\t wallet \tUSD\t-1"; "END-EVENT"; "CORRECTION\t a \tb" ] in
  let decoded = ok (Input.decode (document rows)) in
  (match decoded.presence with
   | Some { reflected_roots; coordinates } ->
     F.require (List.equal D.Identifier.Event.equal reflected_roots [ F.id " a " ] &&
       List.equal F.same_coordinate coordinates [ F.coordinate ~unit:"USD" " wallet "; F.coordinate "quiet" ]) "exact order/identity, no aliases"
   | None -> failwith "presence disappeared");
  let request : C.request = { path = "synthetic"; coordinate = F.coordinate ~unit:"USD" " wallet " } in
  let known = C.evaluate request (Ok (document rows)) in
  F.require (known.exit_code = 4 && String.is_empty known.stderr && String.is_substring known.stdout ~substring:"known nonzero" &&
    not (String.is_substring known.stdout ~substring:"quantity=")) "presence output cannot fabricate a number";
  let stale = C.evaluate request (Ok (document (rows @ [ "EVENT\tx\t2026-10-01"; "EFFECT\t wallet \tUSD\t7"; "EFFECT\t wallet \tUSD\t-7"; "END-EVENT" ]))) in
  F.require (stale.exit_code = 3 && String.is_empty stale.stderr && String.is_substring stale.stdout ~substring:"no supported premise") "net-zero touch invalidates, not date order";
  (match (ok (Input.decode (document []))).presence, (ok (Input.decode (document [ "PRESENCE"; "END-PRESENCE" ]))).presence with
   | None, Some { reflected_roots = []; coordinates = [] } -> () | _ -> failwith "absence/explicit empty block lost");
  (match Input.decode (document [ "PRESENCE"; "END-PRESENCE"; "PRESENCE"; "END-PRESENCE" ]) with
   | Error (Syntax { line = 4; message }) -> F.require (String.is_substring message ~substring:"repeated") "repeat diagnostic"
   | _ -> failwith "second presence overwrote first");
  Stdlib.Printf.printf "one explicit block; exact roots/coordinates; known-present 4 vs stale 3, never a scalar\n";
  [%expect {| one explicit block; exact roots/coordinates; known-present 4 vs stale 3, never a scalar |}]
;;

let%expect_test "keyed decoding retains exact identities; duplicate Event keys are semantic not syntax failures" =
  let huge = Z.shift_left Z.one 160 in
  let rows = [ "EVENT\t a \t2026-10-03"; "KEYED-EFFECT\t key \twallet\tjpy\t" ^ Z.to_string huge;
    "EFFECT\twallet\tjpy\t" ^ Z.to_string (Z.neg huge); "END-EVENT";
    "EVENT\tb\t2026-10-02"; "KEYED-EFFECT\t key \twallet\tjpy\t1"; "KEYED-EFFECT\tkey\twallet\tjpy\t-1"; "END-EVENT";
    "CORRECTION\t a \tb"; "ZERO-ORIGIN\twallet\tjpy" ] in
  let decoded = ok (Input.decode (document rows)) in
  let tokens = List.map decoded.source.events ~f:(fun e -> List.map (D.Event.effects e) ~f:(fun fx -> Option.map (D.Effect.key fx) ~f:D.Identifier.Effect_key.to_string)) in
  F.require (List.equal (List.equal (Option.equal String.equal)) tokens [ [ Some " key "; None ]; [ Some " key "; Some "key" ] ]) "key scope/order/exact spelling preserved";
  let request : C.request = { path = "synthetic"; coordinate = F.coordinate "wallet" } in
  let exact = C.evaluate request (Ok (document rows)) in
  F.require (exact.exit_code = 0 && String.is_empty exact.stderr && String.is_substring exact.stdout ~substring:"quantity=0") "keyed source through real query";
  let duplicate = document [ "EVENT\te\t2026-10-03"; "KEYED-EFFECT\tkey\twallet\tjpy\t1";
    "EFFECT\twallet\tjpy\t1"; "KEYED-EFFECT\tkey\tother\tjpy\t1"; "END-EVENT" ] in
  (match Input.decode duplicate with
   | Error (Invalid_event { line = 6; event; error = D.Event.Duplicate_effect_key { key; first_position = 1; position = 3 } }) ->
     F.require (D.Identifier.Event.equal event (F.id "e") && String.equal (D.Identifier.Effect_key.to_string key) "key") "typed structural refusal witness"
   | _ -> failwith "duplicate was ignored or classified as syntax");
  let refused = C.evaluate request (Ok duplicate) in
  F.require (refused.exit_code = 1 && String.is_empty refused.stdout && String.is_substring refused.stderr ~substring:"duplicate Effect key" &&
    not (String.is_substring refused.stderr ~substring:"residual")) "key admission before physical source";
  F.require ((C.evaluate request (Ok (document [ "EVENT\te\t2026-10-03"; "KEYED-EFFECT\t\twallet\tjpy\t1"; "END-EVENT" ]))).exit_code = 2) "empty key is syntax";
  F.require ((C.evaluate request (Ok (document (rows @ [ "MERCHANT\tb\tnot-yet-supported" ])))).exit_code = 2) "metadata not silently discarded";
  Stdlib.Printf.printf "exact optional keys retained; Event duplicate exit 1 vs syntax exit 2; no discarded metadata\n";
  [%expect {| exact optional keys retained; Event duplicate exit 1 vs syntax exit 2; no discarded metadata |}]
;;

let%expect_test "description rows retain optional literal text and forward references; closure precedes lookup" =
  let rows = [ "DESCRIPTION\tb\t"; "DESCRIPTION\t a \t  merchant?\\n日本語  ";
    "EVENT\t a \t2026-10-03"; "END-EVENT"; "EVENT\tb\t2026-10-02"; "END-EVENT";
    "CORRECTION\t a \tb"; "ZERO-ORIGIN\twallet\tjpy" ] in
  let decoded = ok (Input.decode (document rows)) in
  let source = ok (S.create decoded.source) in
  let module E = Loam_application.Event_descriptions in
  F.require (List.equal String.equal (List.map decoded.source.descriptions ~f:(fun fact -> D.Identifier.Event.to_string fact.event)) [ "b"; " a " ]) "forward reference/order/exact IDs";
  F.require (Option.equal String.equal (E.find_text (S.descriptions source) (F.id "b")) (Some "") &&
    Option.equal String.equal (E.find_text (S.descriptions source) (F.id " a ")) (Some "  merchant?\\n日本語  ")) "empty/spaces and backslash are literal text";
  let request : C.request = { path = "synthetic"; coordinate = F.coordinate "wallet" } in
  let exact = C.evaluate request (Ok (document rows)) in
  F.require (exact.exit_code = 0 && String.is_empty exact.stderr && String.is_substring exact.stdout ~substring:"quantity=0") "description-aware read path unchanged";
  let unknown = document (rows @ [ "DESCRIPTION\tunknown\thuman text" ]) in
  F.require (Result.is_ok (Input.decode unknown)) "reference closure is not syntax";
  let refusal = C.evaluate request (Ok unknown) in
  F.require (refusal.exit_code = 1 && String.is_empty refusal.stdout && String.is_substring refusal.stderr ~substring:"description 3: unknown Event") "whole source before unrelated query";
  let repeated = C.evaluate request (Ok (document (rows @ [ "DESCRIPTION\tb\t" ]))) in
  F.require (repeated.exit_code = 1 && String.is_empty repeated.stdout && String.is_substring repeated.stderr ~substring:"duplicate description" &&
    String.is_substring repeated.stderr ~substring:"at 3 (first 1)") "identical text not deduplicated, description positions";
  let unsupported = C.evaluate request (Ok (document [ "EVENT\tb\t2026-10-03"; "END-EVENT"; "DESCRIPTION\tb\topening balance" ])) in
  F.require (unsupported.exit_code = 3 && String.is_empty unsupported.stderr) "recognizer text became support";
  Stdlib.Printf.printf "exact optional literal text; forward retained references; admission 1 vs syntax 2, no inferred support\n";
  [%expect {| exact optional literal text; forward retained references; admission 1 vs syntax 2, no inferred support |}]
;;

let%expect_test "malformed/truncated/misplaced rows and obsolete formats never become partial success" =
  let invalid = [ ""; "LOAM-NORMALIZED-ACTUAL\t1\nEND\n"; "LOAM-OCAML-ACTUAL-FIXTURE\t1\nEND\n";
    document [ "SCHEDULED\ta" ]; document [ "MERCHANT\ta\tmetadata" ];
    document [ "DESCRIPTION\ta" ]; document [ "DESCRIPTION\t\tmemo" ]; document [ "DESCRIPTION\ta\tone\ttwo" ];
    document [ "EVENT\ta\t2026-10-03"; "DESCRIPTION\ta\tmisplaced"; "END-EVENT" ];
    document [ "GROUP"; "DESCRIPTION\ta\tmisplaced"; "END-GROUP" ];
    document [ "PRESENCE"; "DESCRIPTION\ta\tmisplaced"; "END-PRESENCE" ];
    document [ "DESCRIPTION\ta\ttext\ncontinued" ]; document [ "KEYED-EFFECT\tkey\twallet\tjpy\t1" ];
    document [ "EVENT\ta\t2026-10-03" ]; document [ "GROUP" ]; document [ "EFFECT\twallet\tjpy\t1" ]; document [ "" ];
    document [ "OPENING\twallet\tjpy" ]; document [ "OPENING\twallet\tjpy\t" ];
    document [ "GROUP"; "OPENING\twallet\tjpy\te"; "END-GROUP" ]; document [ "PRESENCE\twallet\tjpy" ];
    document [ "PRESENCE" ]; document [ "PRESENT\twallet\tjpy" ]; document [ "END-PRESENCE" ];
    document [ "GROUP"; "PRESENCE"; "END-PRESENCE"; "END-GROUP" ];
    document [ "PRESENCE"; "ASSERT\twallet\tjpy\t1"; "END-PRESENCE" ];
    document [ "PRESENCE"; "PRESENT\twallet\tjpy\t1"; "END-PRESENCE" ];
    document [ "EVENT\ta\t2026-10-03"; "EFFECT\twallet\tjpy\t0x10"; "END-EVENT" ];
    document [ "EVENT\ta\t2026-10-03"; "EFFECT\twallet\tjpy\t 1"; "END-EVENT" ];
    "LOAM-OCAML-ACTUAL-FIXTURE\t2\nEND"; document [] ^ "END\n" ] in
  List.iter invalid ~f:(fun text -> match Input.decode text with
    | Error (Syntax { line; message }) -> F.require (line > 0 && not (String.is_empty message)) "useful syntax refusal"
    | Error (Invalid_event _) -> failwith "wrong failure phase for malformed syntax"
    | Ok _ -> failwith "malformed evidence ignored");
  (match Input.decode (document [ "GROUP"; "ASSERT\t\tjpy\t1"; "END-GROUP" ]) with
   | Error (Syntax { line = 3; message = _ }) -> () | _ -> failwith "one-based line witness");
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
  let opening = Loam_presentation.Current_quantity_text.refusal
    (Loam_application.Current_quantity_query.Opening_event_not_current
       { opening = { coordinate = F.coordinate "wallet\027\n"; opening_event = F.id "event\027\n" }; position = 1 }) in
  F.require (not (String.exists opening ~f:(Char.equal '\027')) && String.count opening ~f:(Char.equal '\n') = 1) "escaped opening provenance";
  let duplicate = Loam_presentation.Current_quantity_text.event_refusal (F.id "e\027\n")
    (D.Event.Duplicate_effect_key { key = F.identifier D.Identifier.Effect_key.of_string "k\027\n"; first_position = 1; position = 2 }) in
  F.require (not (String.exists duplicate ~f:(Char.equal '\027')) && String.count duplicate ~f:(Char.equal '\n') = 1) "escaped key and Event identities";
  List.iter [ S.Descriptions (Loam_application.Event_descriptions.Repeated_description { event = F.id "event\027\n"; first_position = 1; position = 2 });
    S.Descriptions (Loam_application.Event_descriptions.Unknown_description_event { event = F.id "event\027\n"; position = 1 }) ] ~f:(fun error ->
      let rendered = Loam_presentation.Current_quantity_text.source_refusal error in
      F.require (not (String.exists rendered ~f:(Char.equal '\027')) && String.count rendered ~f:(Char.equal '\n') = 1) "escaped description references");
  (match C.plan [ "--help" ] with Help -> () | _ -> failwith "help plan");
  (match C.plan [] with Refused _ -> () | _ -> failwith "syntax plan");
  Stdlib.Printf.printf "escaped provenance/errors; explicit read result; no help/syntax I/O\n";
  [%expect {| escaped provenance/errors; explicit read result; no help/syntax I/O |}]
;;
