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
