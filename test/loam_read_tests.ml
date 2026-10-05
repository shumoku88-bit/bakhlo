open Base
module L = Bakhlo_loam_read
module A = Bakhlo_application
module D = Bakhlo_domain
module Q = A.Current_quantity_query
module F = Fixtures

let print_endline = Stdlib.print_endline
let ok = function Ok x -> x | Error _ -> failwith "expected admitted read profile"

(* Tiny synthetic producer only; explicit non-ASCII count supplied independently. *)
let envelope parts =
  "LOAM-HOUSEHOLD-IMAGE\t2\n"
  ^ String.concat ~sep:""
      (List.map parts ~f:(fun (name, body, count) ->
           Printf.sprintf "SECTION\t%s\t%d\n%s" name count body))

let ascii name body = (name, body, String.length body)

let actual =
  String.concat ~sep:"\n"
    [
      "LOAM-NORMALIZED-ACTUAL\t4";
      "TX\ta\t2026-10-03\tDESC\toriginal\t家計";
      "OPERATION\t req-a ";
      "MERCHANT\t p ";
      "ORIGINAL-AMOUNT\tjpy\t100";
      "DATE-REV\tr\t1900-01-01\tREPLACES\tROOT";
      "RELATION\tunit\tSOURCE\tphysical\thousehold\texternal: p \t10";
      "KEYED-EFFECT\tphysical\twallet\tjpy\t-100";
      "EFFECT\tfood\tjpy\t100";
      "ENDTX";
      "TX\tb\t1900-01-01\tNODESC";
      "OPERATION\treq-b";
      "REPLACES\ta";
      "KEYED-EFFECT\tphysical\twallet\tjpy\t-150";
      "EFFECT\tfood\tjpy\t150";
      "ENDTX";
      "TX\tx\t2026-10-02\tNODESC";
      "NONMERCHANT";
      "DISCHARGE\tunit\t7";
      "EFFECT\twallet\tjpy\t-10";
      "EFFECT\tfood\tjpy\t10";
      "ENDTX";
      "TX\te\t2026-10-03\tNODESC";
      "EXCHANGE\tfrom\tto";
      "KEYED-EFFECT\tfrom\twallet\tjpy\t-101";
      "KEYED-EFFECT\tto\twallet\tusd\t2";
      "ENDTX";
      "TX\ter\t2026-10-03\tNODESC";
      "REVERSAL-OF\te";
      "EFFECT\twallet\tusd\t-2";
      "EFFECT\twallet\tjpy\t101";
      "ENDTX";
      "TX\tu\t2026-10-03\tNODESC";
      "EFFECT\twallet\tusd\t7";
      "EFFECT\toffset\tusd\t-7";
      "ENDTX";
      "TX\tt\t2026-10-03\tNODESC";
      "EFFECT\tstale\tjpy\t1";
      "EFFECT\tstale\tjpy\t-1";
      "ENDTX";
      "";
    ]

let origin = "LOAM-ZERO-ORIGIN-COVERAGE\t1\nCOORDINATE\tfood\tjpy\nCOORDINATE\tquiet\tjpy\n"
let anchor = "LOAM-CURRENT-QUANTITY-ANCHOR\t2\nGROUP\nROOT\ta\nASSERT\twallet\tjpy\t1000\nEND\n"

let parts actual anchor =
  [
    ("Actual", actual, String.length actual - 4);
    ascii "ZeroOrigin" origin;
    ascii "OpeningSupport" "LOAM-OPENING-SUPPORT\t1\nOPENING\twallet\tusd\tu\n";
    ascii "CurrentQuantityAnchor" anchor;
    ascii "CurrentQuantityPresence"
      "LOAM-CURRENT-QUANTITY-PRESENCE\t1\nPRESENT\tpantry\tjpy\nPRESENT\tstale\tjpy\n";
    ("Future", "家計\n\000e\204\129\240\159\152\128", 7);
    ascii "Empty" "";
  ]

let exact image c =
  match ok (Q.query image c) with Q.Exact x -> x | Known_present _ -> failwith "expected exact"

let tag = function
  | Ok _ -> "admitted"
  | Error (L.Read.Envelope _) -> "envelope refused"
  | Error (Input (L.Input.Missing_section _)) -> "missing profile section"
  | Error (Input (Unsupported_header _ | Unsupported_actual_evidence _)) -> "unsupported evidence"
  | Error (Input (Syntax _ | Invalid_event _)) -> "input refused"
  | Error (Source _) -> "source refused"
  | Error (Operation_origins _) -> "origins refused"
  | Error (Support _) -> "support refused"

let%expect_test "native profile retains all wire evidence and connects typed quantity premises" =
  let bytes = envelope (parts actual anchor) in
  let read = ok (L.Read.of_string bytes) in
  F.require (String.equal (L.Read.original_bytes read) bytes) "original wire lost";
  let sections = L.Read.sections read in
  F.require (List.length sections = 7) "opaque/empty sections lost";
  F.require
    (String.equal (List.nth_exn sections 5).body "家計\n\000e\204\129\240\159\152\128")
    "Unicode scalar extent changed bytes";
  let origins = L.Read.operation_origins read in
  F.require
    (List.equal String.equal
       (List.map origins ~f:(fun o -> o.L.Input.request_token))
       [ " req-a "; "req-b" ])
    "request identity trimmed";
  F.require
    (List.equal D.Identifier.Event.equal
       (List.map origins ~f:(fun o -> o.L.Input.event))
       [ F.id "a"; F.id "b" ])
    "superseded origin retargeted";
  let image = L.Read.quantity_image read in
  let source = Q.source image in
  F.require
    (Option.equal String.equal
       (A.Event_descriptions.find_text (A.Actual_source.descriptions source) (F.id "a"))
       (Some "original\t家計"))
    "description erased";
  F.require
    (Option.is_none
       (A.Event_descriptions.find_text (A.Actual_source.descriptions source) (F.id "b")))
    "description inherited";
  F.require
    (List.length (A.Event_merchants.facts (A.Actual_source.merchants source)) = 2
    && List.length (A.Original_amounts.facts (A.Actual_source.original_amounts source)) = 1
    && List.length (A.Actual_validity.facts (A.Actual_source.validity source)) = 8
    && List.length (A.Exchange_evidence.facts (A.Actual_source.exchanges source)) = 1
    && List.length (A.Actual_reversals.pairs (A.Actual_source.reversals source)) = 1
    && List.length (A.Open_relations.facts (A.Actual_source.relations source)) = 1
    && List.length (A.Relation_discharges.facts (A.Actual_source.discharges source)) = 1)
    "source metadata omitted";
  let wallet = exact image (F.coordinate "wallet") in
  let food = exact image (F.coordinate "food") in
  F.require
    (Z.equal
       (D.Quantity.quanta (Q.quantity food))
       (Source_oracle.sum_events
          (A.Correction_frontier.frontier_events (A.Actual_source.frontier source))
          (F.coordinate "food")))
    "original-Effect oracle";
  let values =
    List.map
      [
        wallet;
        food;
        exact image (F.coordinate ~unit:"usd" "wallet");
        exact image (F.coordinate "quiet");
      ]
      ~f:(fun a -> Z.to_string (D.Quantity.quanta (Q.quantity a)))
  in
  print_endline (String.concat ~sep:", " values);
  (match Q.premise wallet with
  | Q.Current_assertion p ->
      print_endline (Z.to_string (D.Quantity.quanta (A.Current_quantity_projection.delta p)))
  | Zero_origin | Opening _ -> failwith "assertion premise lost");
  F.require
    (Result.is_ok (Q.query image (F.coordinate "pantry"))
    && Result.is_error (Q.query image (F.coordinate "stale")))
    "touch is not net delta";
  [%expect {|
    990, 160, 7, 0
    -10
    |}]

let%expect_test "new native boundary refuses malformed or unmapped input before any quantity" =
  let read p = print_endline (tag (L.Read.of_string (envelope p))) in
  read (List.tl_exn (parts actual anchor));
  read (parts (actual ^ "SETTLEMENT-NETTING\tid\tjpy\tZERO\n") anchor);
  read
    (parts
       (String.substr_replace_all actual ~pattern:"OPERATION\treq-b" ~with_:"OPERATION\t req-a ")
       anchor);
  read
    (parts
       (String.substr_replace_all actual ~pattern:"REPLACES\ta" ~with_:"REPLACES\tmissing")
       anchor);
  read
    (List.map (parts actual anchor) ~f:(fun (name, body, count) ->
         if String.equal name "ZeroOrigin" then ascii name (body ^ "COORDINATE\twallet\tjpy\n")
         else (name, body, count)));
  read (parts actual anchor @ [ ascii "Empty" "" ]);
  print_endline (tag (L.Read.of_string (envelope (parts actual anchor) ^ "garbage\n")));
  print_endline (tag (L.Read.of_string ("LOAM-HOUSEHOLD-IMAGE\t2\nSECTION\tx\t1\n" ^ "\255")));
  print_endline (tag (L.Read.of_string "LOAM-HOUSEHOLD-IMAGE\t2\nSECTION\tx\t3\n家"));
  print_endline
    (tag (L.Read.of_string "LOAM-HOUSEHOLD-IMAGE\t2\nSECTION\tx\t999999999999999999999\n"));
  [%expect
    {|
    missing profile section
    unsupported evidence
    origins refused
    source refused
    support refused
    envelope refused
    envelope refused
    envelope refused
    envelope refused
    envelope refused
    |}]

let%expect_test "native read keeps huge quanta, version-one cuts and terminal-only outcomes" =
  let huge = Z.shift_left Z.one 180 in
  let anchor =
    "LOAM-CURRENT-QUANTITY-ANCHOR\t1\nROOT\ta\nASSERT\twallet\tjpy\t-" ^ Z.to_string huge ^ "\n"
  in
  let bytes = envelope (parts actual anchor) in
  let read = ok (L.Read.of_string bytes) in
  let quantity = Q.quantity (exact (L.Read.quantity_image read) (F.coordinate "wallet")) in
  F.require
    (Z.equal (D.Quantity.quanta quantity) (Z.sub (Z.neg huge) (Z.of_int 10)))
    "unbounded signed literal narrowed";
  let module C = Bakhlo_cli.Loam_quantity_command in
  List.iter [ "wallet"; "pantry"; "stale" ] ~f:(fun locus ->
      match C.plan [ "synthetic"; locus; "jpy" ] with
      | C.Read request ->
          let response = C.evaluate request (Ok bytes) in
          F.require
            (String.is_empty response.stderr && not (String.is_empty response.stdout))
            "terminal streams";
          print_endline (Int.to_string response.exit_code)
      | Help | Refused _ -> failwith "valid question refused");
  [%expect {|
    0
    4
    3
    |}]

let%expect_test "native batch explanation keeps query outcomes and refuses the whole bad image" =
  let module C = Bakhlo_cli.Loam_quantity_command in
  let evaluate arguments bytes =
    match C.plan arguments with
    | Read request -> C.evaluate request (Ok bytes)
    | Help | Refused _ -> failwith "valid batch refused"
  in
  let bytes = envelope (parts actual anchor) in
  let output =
    evaluate
      [
        "--explain"; "synthetic"; "wallet"; "jpy"; "pantry"; "jpy"; "stale"; "jpy"; "wallet"; "jpy";
      ]
      bytes
  in
  F.require (output.exit_code = 3 && String.is_empty output.stderr) "mixed batch unavailable exit";
  List.iter
    [
      "Question 1:";
      "Question 2:";
      "Question 3:";
      "Question 4:";
      "asserted=1000; delta=-10; quantity=990";
      "Correction \"a\" -> \"b\"";
      "known nonzero (presence premise); exact quantity unknown";
      "ANY unreflected matching Effect invalidates it, even net zero";
    ] ~f:(fun substring ->
      F.require (String.is_substring output.stdout ~substring) "native explanation connection");
  F.require
    (List.length
       (String.substr_index_all output.stdout ~may_overlap:false
          ~pattern:"asserted=1000; delta=-10; quantity=990")
    = 2)
    "duplicate question retained";
  List.iter
    [
      parts (actual ^ "SETTLEMENT-NETTING\tid\tjpy\tZERO\n") anchor;
      List.tl_exn (parts actual anchor);
      parts
        (String.substr_replace_all actual ~pattern:"REPLACES\ta" ~with_:"REPLACES\tmissing")
        anchor;
      List.map (parts actual anchor) ~f:(fun (name, body, count) ->
          if String.equal name "ZeroOrigin" then ascii name (body ^ "COORDINATE\twallet\tjpy\n")
          else (name, body, count));
    ]
    ~f:(fun bad ->
      let refused =
        evaluate [ "--explain"; "synthetic"; "quiet"; "jpy"; "wallet"; "jpy" ] (envelope bad)
      in
      F.require
        (refused.exit_code = 1 && String.is_empty refused.stdout
        && not (String.is_empty refused.stderr))
        "whole input/source/support refusal before ALL questions");
  print_endline
    "One admitted image: exact/presence/unknown/duplicate explanations; whole \
     unsupported/missing/source/support refusal.";
  [%expect
    {| One admitted image: exact/presence/unknown/duplicate explanations; whole unsupported/missing/source/support refusal. |}]

let%expect_test "native summary consumes projected answers only and withholds input failures" =
  let module C = Bakhlo_cli.Loam_quantity_command in
  let evaluate contents =
    match
      C.plan
        [
          "--summary";
          "INTERNAL-FILE";
          "wallet";
          "jpy";
          "pantry";
          "jpy";
          "stale";
          "jpy";
          "wallet";
          "jpy";
        ]
    with
    | Read request -> C.evaluate request contents
    | Help | Refused _ -> failwith "valid summary question refused"
  in
  let bytes = envelope (parts actual anchor) in
  let read = ok (L.Read.of_string bytes) in
  F.require (String.equal (L.Read.original_bytes read) bytes) "raw owner input retained";
  let response = evaluate (Ok bytes) in
  F.require (response.exit_code = 3 && String.is_empty response.stderr) "mixed unknown precedence";
  List.iter [ "990 quanta"; "正確な数量はまだ分かりません"; "数量を確定できません"; "質問 4:" ] ~f:(fun substring ->
      F.require
        (String.is_substring response.stdout ~substring)
        "native friendly outcome connection");
  List.iter
    [
      " req-a ";
      "req-b";
      "original";
      "家計";
      "physical";
      "Future";
      "Correction";
      "Root ";
      "INTERNAL-FILE";
    ] ~f:(fun substring ->
      F.require
        (not (String.is_substring response.stdout ~substring))
        "raw data not in native summary");
  List.iter
    [
      Error "INTERNAL-I/O";
      Ok "INTERNAL-INVALID-FRAME\n";
      Ok (envelope (List.tl_exn (parts actual anchor)));
      Ok (envelope (parts (actual ^ "SETTLEMENT-NETTING\tid\tjpy\tZERO\n") anchor));
      Ok
        (envelope
           (parts
              (String.substr_replace_all actual ~pattern:"REPLACES\ta"
                 ~with_:"REPLACES\tINTERNAL-MISSING")
              anchor));
      Ok
        (envelope
           (parts
              (String.substr_replace_all actual ~pattern:"OPERATION\treq-b"
                 ~with_:"OPERATION\t req-a ")
              anchor));
      Ok
        (envelope
           (List.map (parts actual anchor) ~f:(fun (name, body, count) ->
                if String.equal name "ZeroOrigin" then
                  ascii name (body ^ "COORDINATE\twallet\tjpy\n")
                else (name, body, count))));
    ]
    ~f:(fun contents ->
      let failed = evaluate contents in
      F.require
        (failed.exit_code = 1 && String.is_empty failed.stdout
        && String.is_substring failed.stderr ~substring:"数量には答えていません"
        && (not (String.is_substring failed.stderr ~substring:"INTERNAL-"))
        && not (String.is_substring failed.stderr ~substring:"req-a"))
        "all native input failures remain refused without payload disclosure");
  print_endline
    "Native summary preserves exact/presence/unknown/duplicates, retains private owner evidence, \
     and gives no partial answer or raw diagnostics on seven input failures.";
  [%expect
    {| Native summary preserves exact/presence/unknown/duplicates, retains private owner evidence, and gives no partial answer or raw diagnostics on seven input failures. |}]
