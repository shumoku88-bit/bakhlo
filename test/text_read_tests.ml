open Base
module D = Bakhlo_domain
module A = Bakhlo_application
module I = Bakhlo_text.Input
module R = Bakhlo_text.Read
module Q = A.Current_quantity_query
module F = Fixtures

let ok = function Ok value -> value | Error _ -> failwith "expected successful text read"

let document rows =
  String.concat ~sep:"\n" (("bakhlo-read 1 ordinary-actual-quantity" :: rows) @ [ "end"; "" ])

(* Independent test producer, not an encoder/API or candidate canonical spelling. *)
let quoted_bytes text =
  "\"" ^ String.concat_map text ~f:(fun c -> Printf.sprintf "\\x%02X" (Char.to_int c)) ^ "\""

let exact image coordinate =
  match ok (Q.query image coordinate) with
  | Q.Exact value -> value
  | Known_present _ -> failwith "presence is not arithmetic"

let value image coordinate = D.Quantity.quanta (Q.quantity (exact image coordinate))
let event_token event = D.Identifier.Event.to_string (D.Event.id event)
let ids events = List.map events ~f:event_token

let describe image id =
  A.Event_descriptions.find_text (A.Actual_source.descriptions (Q.source image)) (F.id id)

let base_event = [ "event \"e\" \"2026-10-03\""; "end-event" ]

let%expect_test
    "profile read connects exact support, original evidence and independent fixture/oracle" =
  let rows =
    [
      "correct \"a\" \"b\"";
      "describe \"a\" \"original\\nrecognizer\"";
      "describe \"b\" \"\"";
      "event \"a\" \"2026-10-03\"";
      "effect key \"physical\" \"wallet\" \"jpy\" -100";
      "effect anonymous \"food\" \"jpy\" 100";
      "end-event";
      "event \"b\" \"1900-01-01\"";
      "effect key \"physical\" \"wallet\" \"jpy\" -150";
      "effect anonymous \"food\" \"jpy\" 150";
      "end-event";
      "event \"x\" \"2026-10-02\"";
      "effect anonymous \"wallet\" \"jpy\" -10";
      "effect anonymous \"food\" \"jpy\" 10";
      "end-event";
      "event \"t\" \"2026-10-03\"";
      "effect anonymous \"stale\" \"jpy\" 1";
      "effect anonymous \"stale\" \"jpy\" -1";
      "end-event";
      "origin \"food\" \"jpy\"";
      "origin \"quiet\" \"jpy\"";
      "opening \"wallet\" \"usd\" \"u\"";
      "event \"u\" \"2026-10-03\"";
      "effect anonymous \"wallet\" \"usd\" 7";
      "effect anonymous \"offset\" \"usd\" -7";
      "end-event";
      "group";
      "reflect \"a\"";
      "assert \"wallet\" \"jpy\" 1000";
      "end-group";
      "presence";
      "present \"pantry\" \"jpy\"";
      "present \"stale\" \"jpy\"";
      "end-presence";
    ]
  in
  (* Independently supplied fixture, not translation/filtering of a richer world. *)
  let fixture_rows =
    [
      "CORRECTION\ta\tb";
      "EVENT\ta\t2026-10-03";
      "KEYED-EFFECT\tphysical\twallet\tjpy\t-100";
      "EFFECT\tfood\tjpy\t100";
      "END-EVENT";
      "EVENT\tb\t1900-01-01";
      "KEYED-EFFECT\tphysical\twallet\tjpy\t-150";
      "EFFECT\tfood\tjpy\t150";
      "END-EVENT";
      "EVENT\tx\t2026-10-02";
      "EFFECT\twallet\tjpy\t-10";
      "EFFECT\tfood\tjpy\t10";
      "END-EVENT";
      "EVENT\tt\t2026-10-03";
      "EFFECT\tstale\tjpy\t1";
      "EFFECT\tstale\tjpy\t-1";
      "END-EVENT";
      "EVENT\tu\t2026-10-03";
      "EFFECT\twallet\tusd\t7";
      "EFFECT\toffset\tusd\t-7";
      "END-EVENT";
      "ZERO-ORIGIN\tfood\tjpy";
      "ZERO-ORIGIN\tquiet\tjpy";
      "OPENING\twallet\tusd\tu";
      "GROUP";
      "REFLECT\ta";
      "ASSERT\twallet\tjpy\t1000";
      "END-GROUP";
      "PRESENCE";
      "PRESENT\tpantry\tjpy";
      "PRESENT\tstale\tjpy";
      "END-PRESENCE";
    ]
  in
  let fixture =
    String.concat ~sep:"\n" (("BAKHLO-ACTUAL-FIXTURE\t2" :: fixture_rows) @ [ "END"; "" ])
  in
  let decoded_fixture = ok (Bakhlo_cli.Current_fixture_input.decode fixture) in
  let fixture_source = ok (A.Actual_source.create decoded_fixture.source) in
  let fixture_image =
    ok
      (Q.create ~source:fixture_source ~zero_origins:decoded_fixture.zero_origins
         ~openings:decoded_fixture.openings ~groups:decoded_fixture.groups
         ~presence:decoded_fixture.presence)
  in
  let image = ok (R.of_string (document rows)) in
  let wallet = F.coordinate "wallet"
  and food = F.coordinate "food"
  and usd = F.coordinate ~unit:"usd" "wallet" in
  List.iter
    [ wallet; food; usd; F.coordinate "quiet" ]
    ~f:(fun c ->
      F.require
        (Z.equal (value image c) (value fixture_image c))
        "independent fixture quantity connection");
  let source = Q.source image in
  let frontier = A.Actual_source.frontier source in
  let retained = D.Event_memory.events (A.Correction_frontier.retained_events frontier) in
  F.require
    (List.equal String.equal (ids retained) [ "a"; "b"; "x"; "t"; "u" ])
    "retained order/superseded Event";
  let terminals = A.Correction_frontier.frontier_events frontier in
  F.require
    (List.equal String.equal (ids terminals) [ "b"; "x"; "t"; "u" ])
    "date did not select a winner";
  F.require
    (Z.equal (value image food) (Source_oracle.sum_events terminals food))
    "independent original-Effect oracle";
  F.require
    (Z.equal (value image wallet) (Z.of_int 990)
    && Z.equal (value image food) (Z.of_int 160)
    && Z.equal (value image usd) (Z.of_int 7)
    && Z.equal (value image (F.coordinate "quiet")) Z.zero)
    "four exact values";
  (match Q.premise (exact image wallet) with
  | Current_assertion a ->
      F.require
        (Z.equal
           (D.Quantity.quanta (A.Current_quantity_projection.asserted_quantity a))
           (Z.of_int 1000)
        && Z.equal (D.Quantity.quanta (A.Current_quantity_projection.delta a)) (Z.of_int (-10)))
        "assertion/decomposition"
  | Zero_origin | Opening _ -> failwith "independent assertion lost");
  (match Q.premise (exact image usd) with
  | Opening { coordinate; opening_event } ->
      F.require
        (F.same_coordinate coordinate usd && D.Identifier.Event.equal opening_event (F.id "u"))
        "opening witness"
  | Zero_origin | Current_assertion _ -> failwith "opening lost");
  let projection =
    Option.value_exn (A.Current_quantity_groups.group_for (Q.source_groups image) wallet)
  in
  let cut = A.Current_quantity_projection.source_cut projection in
  F.require
    (List.equal D.Identifier.Event.equal (A.Reflected_root_cut.reflected_roots cut) [ F.id "a" ]
    && List.equal String.equal (ids (A.Reflected_root_cut.remaining_events cut)) [ "x"; "t"; "u" ])
    "cut/provenance not merged";
  let edge = List.hd_exn (A.Correction_frontier.corrections frontier) in
  F.require
    (D.Identifier.Event.equal edge.target (F.id "a")
    && D.Identifier.Event.equal edge.replacement (F.id "b"))
    "correction retained";
  F.require
    (Option.equal String.equal (describe image "a") (Some "original\nrecognizer")
    && Option.equal String.equal (describe image "b") (Some "")
    && Option.is_none (describe image "x"))
    "description absent/empty/no inheritance";
  (match Q.query image (F.coordinate "pantry") with
  | Ok (Known_present p) ->
      F.require
        (F.same_coordinate (Q.present_coordinate p) (F.coordinate "pantry")
        && List.is_empty (A.Reflected_root_cut.reflected_roots (Q.present_cut p)))
        "presence has its own cut"
  | Ok (Exact _) | Error (Support_unknown _) -> failwith "presence became scalar/unknown");
  List.iter
    [ F.coordinate "stale"; F.coordinate "unsupported"; F.coordinate ~unit:"USD" "wallet" ]
    ~f:(fun c ->
      match Q.query image c with
      | Error (Support_unknown { coordinate }) ->
          F.require (F.same_coordinate coordinate c) "unavailable coordinate"
      | Ok (Exact _ | Known_present _) -> failwith "touch/absence/Measure spelling became support");
  Stdlib.Printf.printf
    "990/160/7/0 exact; presence separate; unknown stays unknown; source, correction, description \
     and cut retained\n";
  [%expect
    {| 990/160/7/0 exact; presence separate; unknown stays unknown; source, correction, description and cut retained |}]

let%expect_test "two decoded groups and presence retain three independent cuts on one source" =
  let image =
    ok
      (R.of_string
         (document
            [
              "group";
              "reflect \"a\"";
              "assert \"wallet\" \"jpy\" 1000";
              "end-group";
              "group";
              "reflect \"x\"";
              "assert \"food\" \"jpy\" 500";
              "end-group";
              "presence";
              "reflect \"a\"";
              "present \"pantry\" \"jpy\"";
              "end-presence";
              "event \"a\" \"2026-10-03\"";
              "effect anonymous \"wallet\" \"jpy\" -100";
              "effect anonymous \"food\" \"jpy\" 100";
              "end-event";
              "event \"x\" \"2026-10-03\"";
              "effect anonymous \"wallet\" \"jpy\" -10";
              "effect anonymous \"food\" \"jpy\" 10";
              "end-event";
            ]))
  in
  let wallet = F.coordinate "wallet" and food = F.coordinate "food" in
  F.require
    (Z.equal (value image wallet) (Z.of_int 990) && Z.equal (value image food) (Z.of_int 600))
    "cuts not unioned";
  let groups = A.Current_quantity_groups.groups (Q.source_groups image) in
  F.require
    (List.equal
       (List.equal D.Identifier.Event.equal)
       (List.map groups ~f:(fun g -> g.reflected_roots))
       [ [ F.id "a" ]; [ F.id "x" ] ])
    "group order/roots retained";
  List.iter [ wallet; food ] ~f:(fun c ->
      let projection =
        Option.value_exn (A.Current_quantity_groups.group_for (Q.source_groups image) c)
      in
      let cut = A.Current_quantity_projection.source_cut projection in
      match Q.premise (exact image c) with
      | Current_assertion a ->
          F.require
            (Z.equal
               (D.Quantity.quanta (A.Current_quantity_projection.delta a))
               (Source_oracle.sum_events (A.Reflected_root_cut.remaining_events cut) c))
            "original-Effect delta"
      | Zero_origin | Opening _ -> failwith "group became another family");
  (match Q.query image (F.coordinate "pantry") with
  | Ok (Known_present p) ->
      F.require
        (List.equal D.Identifier.Event.equal
           (A.Reflected_root_cut.reflected_roots (Q.present_cut p))
           [ F.id "a" ])
        "presence cut retained"
  | Ok (Exact _) | Error (Support_unknown _) -> failwith "presence discarded");
  Stdlib.Printf.printf
    "wallet 990 / food 600; independent a/x group cuts and a presence cut; forward references \
     qualified\n";
  [%expect
    {| wallet 990 / food 600; independent a/x group cuts and a presence cut; forward references qualified |}]

let%expect_test
    "quoted bytes preserve every role, descriptions, multiplicity and unbounded exact quantities" =
  let all = String.init 256 ~f:Char.of_int_exn in
  let quoted = quoted_bytes all in
  let huge = Z.shift_left Z.one 180 in
  let decimal = Z.to_string huge in
  let rows =
    [
      "event " ^ quoted ^ " \"2026-10-03\"";
      "effect key " ^ quoted ^ " " ^ quoted ^ " " ^ quoted ^ " -" ^ decimal;
      "effect anonymous \"offset\" " ^ quoted ^ " +000" ^ Z.to_string (Z.pred huge);
      "effect anonymous \"offset\" " ^ quoted ^ " 1";
      "end-event";
      "describe " ^ quoted ^ " " ^ quoted;
      "origin " ^ quoted ^ " " ^ quoted;
    ]
  in
  let image = ok (R.of_string (document rows)) in
  let frontier = A.Actual_source.frontier (Q.source image) in
  let event = List.hd_exn (A.Correction_frontier.frontier_events frontier) in
  F.require (String.equal (event_token event) all) "all Event bytes";
  let changes = D.Event.effects event in
  let first = List.hd_exn changes in
  F.require
    (List.length changes = 3
    && String.equal (D.Identifier.Effect_key.to_string (Option.value_exn (D.Effect.key first))) all
    && String.equal (D.Identifier.Locus.to_string (D.Effect.locus first)) all
    && String.equal (D.Identifier.Measure.to_string (D.Effect.measure first)) all)
    "all typed roles/multiplicity";
  F.require (Option.equal String.equal (describe image all) (Some all)) "all description bytes";
  let c = F.coordinate ~unit:all all in
  F.require (Z.equal (value image c) (Z.neg huge)) "180-bit exact quantity";
  (* One escaped-byte specimen for each code, plus human-readable escape spellings. *)
  List.iter (List.init 256 ~f:Fn.id) ~f:(fun code ->
      let text = String.of_char (Char.of_int_exn code) in
      let decoded =
        ok (I.decode (document (base_event @ [ "describe \"e\" " ^ quoted_bytes text ])))
      in
      F.require
        (String.equal (List.hd_exn decoded.source.descriptions).text text)
        "single-byte quoted field");
  let recognizer = " space\tline\nreturn\r\"quote\\slash 家計 " in
  let decoded =
    ok
      (I.decode
         (document
            (base_event @ [ "describe \"e\" \" space\\tline\\nreturn\\r\\\"quote\\\\slash 家計 \"" ])))
  in
  F.require
    (String.equal (List.hd_exn decoded.source.descriptions).text recognizer)
    "literal UTF-8/space/nrt/quote/slash";
  let spaced = ok (R.of_string (document [ "origin \" wallet \" \"USD\"" ])) in
  F.require
    (Z.equal (value spaced (F.coordinate ~unit:"USD" " wallet ")) Z.zero)
    "identity not trimmed";
  (match Q.query spaced (F.coordinate ~unit:"USD" "wallet") with
  | Error (Support_unknown _) -> ()
  | Ok (Exact _ | Known_present _) -> failwith "identity normalized");
  Stdlib.Printf.printf
    "256 escaped-byte specimens + all-byte typed fields, exact 180-bit signed decimal, literal \
     text and multiplicity\n";
  [%expect
    {| 256 escaped-byte specimens + all-byte typed fields, exact 180-bit signed decimal, literal text and multiplicity |}]

let%expect_test
    "decimal acceptance agrees with independent digit arithmetic, not floats or default zero" =
  let oracle text =
    (* Spaces/tabs delimit bare tokens in this profile, not quantity field bytes.
       Model that lexical boundary; never trim any quoted identity/text. *)
    let text = String.strip text ~drop:(function ' ' | '\t' -> true | _ -> false) in
    let negative, digits =
      match String.to_list text with
      | '-' :: rest -> (true, rest)
      | '+' :: rest -> (false, rest)
      | rest -> (false, rest)
    in
    if
      List.is_empty digits
      || not (List.for_all digits ~f:(function '0' .. '9' -> true | _ -> false))
    then None
    else
      let n =
        List.fold digits ~init:Z.zero ~f:(fun n c ->
            Z.add (Z.mul n (Z.of_int 10)) (Z.of_int (Char.to_int c - 48)))
      in
      Some (if negative then Z.neg n else n)
  in
  let alphabet = [ "+"; "-"; "0"; "9"; "x"; "_"; " "; "." ] in
  let rec words n =
    if n = 0 then [ "" ]
    else
      List.concat_map
        (words (n - 1))
        ~f:(fun prefix -> List.map alphabet ~f:(fun byte -> prefix ^ byte))
  in
  let huge = Z.to_string (Z.shift_left Z.one 180) in
  let literals =
    List.concat_map [ 0; 1; 2; 3 ] ~f:words
    @ List.init 256 ~f:(fun c -> String.of_char (Char.of_int_exn c))
    @ [ "000"; "+000"; "-000"; huge; "+" ^ huge; "-" ^ huge ]
  in
  let admitted = ref 0 in
  List.iter literals ~f:(fun literal ->
      let decoded =
        I.decode (document [ "group"; "assert \"wallet\" \"jpy\" " ^ literal; "end-group" ])
      in
      match (oracle literal, decoded) with
      | None, Error (Syntax _) -> ()
      | Some expected, Ok input ->
          Int.incr admitted;
          let assertion = List.hd_exn (List.hd_exn input.groups).assertions in
          F.require
            (Z.equal expected (D.Quantity.quanta assertion.quantity))
            "decimal interpretation"
      | _ -> failwith "literal grammar changed");
  F.require (List.length literals = 847 && !admitted = 68) "literal specimens actually executed";
  Stdlib.Printf.printf
    "847 reused bounded literal shapes; 68 token successes with whitespace delimiters; separate \
     admission\n";
  [%expect
    {| 847 reused bounded literal shapes; 68 token successes with whitespace delimiters; separate admission |}]

let%expect_test
    "whole-profile decoding refuses unsupported evidence, malformed quoting, frames and every \
     truncation" =
  (match I.decode "bakhlo-read 2 ordinary-actual-quantity\nend\n" with
  | Error (Unsupported_version { line = 1; version = "2" }) -> ()
  | _ -> failwith "version silently accepted");
  (match I.decode "bakhlo-read 1 household\nend\n" with
  | Error (Unsupported_profile { line = 1; profile = "household" }) -> ()
  | _ -> failwith "profile silently accepted");
  let outside =
    [
      "merchant";
      "nonmerchant";
      "original-amount";
      "exchange";
      "reversal";
      "relation";
      "discharge";
      "validity-revision";
      "validity-correction";
      "scheduled";
      "settlement";
      "purpose";
      "#";
    ]
  in
  List.iter outside ~f:(fun name ->
      match I.decode (document (base_event @ [ name ^ " \"e\"" ])) with
      | Error (Unsupported_record { line = 4; name = observed }) ->
          F.require (String.equal name observed) "unsupported identity"
      | _ -> failwith "unsupported record erased");
  let malformed =
    [
      "origin wallet \"jpy\"";
      "origin \"\" \"jpy\"";
      "origin \"wallet\"\"jpy\"";
      "origin \"wallet\" \"jpy\" extra";
      "origin \"wallet\" \"jpy";
      "origin \"wallet\\q\" \"jpy\"";
      "origin \"wallet\\x0\" \"jpy\"";
      "origin \"wallet\\xGG\" \"jpy\"";
      "origin \"wallet\t\" \"jpy\"";
      "origin \"wallet\000\" \"jpy\"";
      "event \"e\"";
      "event \"e\" 2026-10-03";
      "end-event";
      "end-group";
      "end-presence";
      "group\npresence\nend-group";
      "presence\nassert \"w\" \"jpy\" 1\nend-presence";
      "event \"e\" none\norigin \"w\" \"jpy\"\nend-event";
      "presence\nend-presence\npresence\nend-presence";
      "group\nassert \"w\" \"jpy\" \"1\"\nend-group";
    ]
  in
  List.iter malformed ~f:(fun row ->
      match I.decode (document [ row ]) with
      | Error (Syntax _) -> ()
      | _ -> failwith "malformed profile accepted");
  let complete =
    document (base_event @ [ "describe \"e\" \"quoted\\n\\x00text\""; "origin \"wallet\" \"jpy\"" ])
  in
  ignore (ok (R.of_string complete) : Q.t);
  for length = 0 to String.length complete - 1 do
    F.require
      (Result.is_error (I.decode (String.prefix complete length)))
      "proper byte prefix became a complete image"
  done;
  F.require
    (Result.is_error (I.decode (complete ^ "origin \"w\" \"jpy\"\n")))
    "trailing evidence ignored";
  F.require
    (Result.is_error (I.decode "bakhlo-read 1 ordinary-actual-quantity\r\nend\r\n"))
    "CR normalization invented";
  Stdlib.Printf.printf
    "version/profile + 13 unsupported families/comments + 20 malformed shapes + all proper byte \
     prefixes refuse\n";
  [%expect
    {| version/profile + 13 unsupported families/comments + 20 malformed shapes + all proper byte prefixes refuse |}]

let%expect_test
    "whole read preserves typed decode/source/support refusals and preempts unrelated lookup" =
  let zero = [ "event \"e\" \"bad date\""; "effect anonymous \"w\" \"jpy\" 0"; "end-event" ] in
  let overlap = [ "origin \"w\" \"jpy\""; "group"; "assert \"w\" \"jpy\" 0"; "end-group" ] in
  (match R.of_string (document (zero @ overlap @ [ "merchant \"e\" \"p\"" ])) with
  | Error (Input (Unsupported_record _)) -> ()
  | _ -> failwith "later decode error hidden by source failure");
  (match R.of_string (document (zero @ overlap)) with
  | Error (Source (Zero_effect { event_position = 1; effect_position = 1; event = _ })) -> ()
  | _ -> failwith "physical error hidden by date/support");
  (match R.of_string (document [ "event \"e\" none"; "end-event" ]) with
  | Error (Source (Validity (Missing_validity { event }))) ->
      F.require (D.Identifier.Event.equal event (F.id "e")) "missing date identity"
  | _ -> failwith "absent date defaulted");
  (match R.of_string (document [ "event \"e\" \"bad date\""; "end-event" ]) with
  | Error (Source (Validity (Invalid_date _))) -> ()
  | _ -> failwith "date ignored");
  (match R.of_string (document (base_event @ base_event)) with
  | Error (Source (Events (Duplicate_id _))) -> ()
  | _ -> failwith "duplicate Event overwritten");
  (match R.of_string (document (base_event @ [ "correct \"e\" \"missing\"" ])) with
  | Error (Source (Corrections (Unresolved_correction _))) -> ()
  | _ -> failwith "broken reference filtered");
  (match R.of_string (document (base_event @ [ "correct \"e\" \"e\"" ])) with
  | Error (Source (Corrections (Cycle _))) -> ()
  | _ -> failwith "cycle hidden");
  (match
     R.of_string
       (document
          [
            "event \"e\" \"2026-10-03\"";
            "effect key \"k\" \"w\" \"jpy\" 1";
            "effect key \"k\" \"w\" \"jpy\" -1";
            "end-event";
          ])
   with
  | Error
      (Input
         (Invalid_event
            {
              line = 5;
              event = _;
              error = Duplicate_effect_key { first_position = 1; position = 2; key = _ };
            })) ->
      ()
  | _ -> failwith "duplicate key overwritten");
  (match
     R.of_string
       (document [ "event \"e\" \"2026-10-03\""; "effect anonymous \"w\" \"jpy\" 1"; "end-event" ])
   with
  | Error (Source (Unbalanced_measure _)) -> ()
  | _ -> failwith "ordinary profile became Exchange");
  (match R.of_string (document (base_event @ overlap)) with
  | Error (Support (Assertion_overlaps_origin _)) -> ()
  | _ -> failwith "equal-zero overlap became a winner");
  (match R.of_string (document (base_event @ [ "group"; "reflect \"missing\""; "end-group" ])) with
  | Error (Support (Groups (Invalid_cut _))) -> ()
  | _ -> failwith "empty group skipped closure");
  let none = ok (R.of_string (document [])) in
  let explicit = ok (R.of_string (document [ "presence"; "end-presence" ])) in
  F.require
    (Option.is_none (Q.presence none) && Option.is_some (Q.presence explicit))
    "None differs from explicit empty";
  List.iter [ none; explicit ] ~f:(fun image ->
      match Q.query image (F.coordinate "w") with
      | Error (Support_unknown _) -> ()
      | Ok (Exact _ | Known_present _) -> failwith "empty evidence invented support");
  let future =
    ok
      (R.of_string
         (document
            [
              "opening \"w\" \"jpy\" \"e\"";
              "event \"e\" \"2026-10-03\"";
              "effect anonymous \"w\" \"jpy\" 1";
              "effect anonymous \"other\" \"jpy\" -1";
              "end-event";
            ]))
  in
  F.require (Z.equal (value future (F.coordinate "w")) Z.one) "forward opening was not qualified";
  Stdlib.Printf.printf
    "decode -> whole source -> whole support; structured witnesses; empty is not zero; explicit \
     forward opening\n";
  [%expect
    {| decode -> whole source -> whole support; structured witnesses; empty is not zero; explicit forward opening |}]

let%expect_test "explanation retains traversal edges, terminal multiplicity and each answer's cut" =
  let image =
    ok
      (R.of_string
         (document
            [
              "correct \"b\" \"c\"";
              "correct \"a\" \"b\"";
              "event \"c\" \"1900-01-01\"";
              "effect key \"physical\" \"wallet\" \"jpy\" -4";
              "effect anonymous \"food\" \"jpy\" 8";
              "effect anonymous \"wallet\" \"jpy\" -4";
              "end-event";
              "event \"b\" \"2026-10-03\"";
              "effect anonymous \"wallet\" \"jpy\" -3";
              "effect anonymous \"food\" \"jpy\" 3";
              "end-event";
              "event \"x\" \"2026-10-03\"";
              "effect anonymous \"wallet\" \"jpy\" -1";
              "effect anonymous \"food\" \"jpy\" 1";
              "end-event";
              "event \"a\" \"2026-10-03\"";
              "effect anonymous \"wallet\" \"jpy\" -2";
              "effect anonymous \"food\" \"jpy\" 2";
              "end-event";
              "group";
              "reflect \"a\"";
              "assert \"wallet\" \"jpy\" 100";
              "end-group";
              "group";
              "reflect \"x\"";
              "assert \"food\" \"jpy\" 200";
              "end-group";
            ]))
  in
  List.iter
    [ F.coordinate "wallet"; F.coordinate "food" ]
    ~f:(fun coordinate ->
      let outcome, text =
        Bakhlo_presentation.Current_quantity_explanation.explain image coordinate
      in
      (match outcome with
      | Ok (Exact answer) -> (
          let projection =
            Option.value_exn
              (A.Current_quantity_groups.group_for (Q.source_groups image) coordinate)
          in
          match Q.premise answer with
          | Current_assertion a ->
              let cut = A.Current_quantity_projection.answer_cut a in
              F.require
                (phys_equal cut (A.Current_quantity_projection.source_cut projection))
                "answer retains the exact owning cut";
              F.require
                (Z.equal
                   (D.Quantity.quanta (A.Current_quantity_projection.delta a))
                   (Source_oracle.sum_events (A.Reflected_root_cut.remaining_events cut) coordinate))
                "answer-bound cut agrees with earned original-Effect oracle"
          | Zero_origin | Opening _ -> failwith "assertion premise lost")
      | Ok (Known_present _) | Error (Support_unknown _) -> failwith "explanation changed outcome");
      Stdlib.print_string text);
  [%expect
    {|
    Conditional evidence explanation; not household authority or spending rights.
    exact assertion; "wallet" / "jpy": asserted=100; delta=-1; quantity=99
      Supplied assertion + unreflected delta; independent answer-bound cut.
      Reflected roots (supplied): ["a"].
      Matching terminal Effect occurrences (root order; Event-local positions):
        Root "x"; terminal "x"; unreflected (contributes to delta).
          Correction path: none.
          Effect 1: anonymous; quanta=-1
        Root "a"; terminal "c"; reflected (excluded).
          Correction "a" -> "b"
          Correction "b" -> "c"
          Effect 1: key "physical"; quanta=-4
          Effect 3: anonymous; quanta=-4
    Conditional evidence explanation; not household authority or spending rights.
    exact assertion; "food" / "jpy": asserted=200; delta=8; quantity=208
      Supplied assertion + unreflected delta; independent answer-bound cut.
      Reflected roots (supplied): ["x"].
      Matching terminal Effect occurrences (root order; Event-local positions):
        Root "x"; terminal "x"; reflected (excluded).
          Correction path: none.
          Effect 2: anonymous; quanta=1
        Root "a"; terminal "c"; unreflected (contributes to delta).
          Correction "a" -> "b"
          Correction "b" -> "c"
          Effect 2: anonymous; quanta=8
    |}]

let%expect_test "explanation never turns cancelling activity or presence into an exact scalar" =
  let image =
    ok
      (R.of_string
         (document
            [
              "event \"touch\" \"2026-10-03\"";
              "effect anonymous \"stale\" \"jpy\" 1";
              "effect anonymous \"stale\" \"jpy\" -1";
              "end-event";
              "origin \"quiet\" \"jpy\"";
              "presence";
              "present \"stale\" \"jpy\"";
              "present \"pantry\" \"jpy\"";
              "end-presence";
            ]))
  in
  List.iter [ "quiet"; "stale"; "pantry"; "missing" ] ~f:(fun place ->
      let outcome, text =
        Bakhlo_presentation.Current_quantity_explanation.explain image (F.coordinate place)
      in
      (match (place, outcome) with
      | "quiet", Ok (Exact answer) ->
          F.require (D.Quantity.equal (Q.quantity answer) D.Quantity.zero) "explicit zero"
      | "pantry", Ok (Known_present _) -> ()
      | ("stale" | "missing"), Error (Support_unknown _) -> ()
      | _ -> failwith "explanation manufactured support");
      Stdlib.print_string text);
  [%expect
    {|
    Conditional evidence explanation; not household authority or spending rights.
    "quiet" / "jpy": zero-origin; quantity=0
      Selection: all qualified terminal Events (no reflected cut).
      Matching terminal Effect occurrences (root order; Event-local positions):
        none.
    Conditional evidence explanation; not household authority or spending rights.
    "stale" / "jpy": quantity unknown (no supported premise in supplied evidence).
      Supplied presence is stale: ANY unreflected matching Effect invalidates it, even net zero.
      Reflected roots (supplied): [].
      Matching terminal Effect occurrences (root order; Event-local positions):
        Root "touch"; terminal "touch"; unreflected (invalidates presence).
          Correction path: none.
          Effect 1: anonymous; quanta=1
          Effect 2: anonymous; quanta=-1
    Conditional evidence explanation; not household authority or spending rights.
    "pantry" / "jpy": known nonzero (presence premise); exact quantity unknown.
      Independent presence premise; no unreflected matching Effect; no scalar.
      Reflected roots (supplied): [].
      Matching terminal Effect occurrences (root order; Event-local positions):
        none.
    Conditional evidence explanation; not household authority or spending rights.
    "missing" / "jpy": quantity unknown (no supported premise in supplied evidence).
      Activity or net zero does not establish quantity support.
      Matching terminal Effect occurrences (root order; Event-local positions):
        none.
    |}]

let%expect_test
    "explanation preserves opening/Measure identity, huge signed quanta and escaped tokens" =
  let place = " wallet\n\027 " and unit = "JPY\027" and token = "event\n\027" in
  let huge = Z.shift_left Z.one 180 in
  let image =
    ok
      (R.of_string
         (document
            [
              "event " ^ quoted_bytes token ^ " \"2026-10-03\"";
              "effect key " ^ quoted_bytes "key\n\027" ^ " " ^ quoted_bytes place ^ " "
              ^ quoted_bytes unit ^ " -" ^ Z.to_string huge;
              "effect anonymous \"offset\" " ^ quoted_bytes unit ^ " " ^ Z.to_string huge;
              "end-event";
              "opening " ^ quoted_bytes place ^ " " ^ quoted_bytes unit ^ " " ^ quoted_bytes token;
            ]))
  in
  let outcome, text =
    Bakhlo_presentation.Current_quantity_explanation.explain image (F.coordinate ~unit place)
  in
  (match outcome with
  | Ok (Exact answer) -> (
      F.require (Z.equal (D.Quantity.quanta (Q.quantity answer)) (Z.neg huge)) "huge exact";
      match Q.premise answer with
      | Opening { coordinate; opening_event } ->
          F.require
            (F.same_coordinate coordinate (F.coordinate ~unit place)
            && D.Identifier.Event.equal opening_event (F.id token))
            "original opening witness, not just its Effects"
      | Zero_origin | Current_assertion _ -> failwith "opening was relabelled")
  | Ok (Known_present _) | Error (Support_unknown _) -> failwith "opening lost");
  F.require
    ((not (String.contains text '\027'))
    && String.is_substring text ~substring:(Printf.sprintf "%S" token)
    && String.is_substring text ~substring:(Printf.sprintf "%S" "key\n\027")
    && String.is_substring text ~substring:(Z.to_string (Z.neg huge)))
    "terminal controls escaped without normalization or truncation";
  let wrong, _ =
    Bakhlo_presentation.Current_quantity_explanation.explain image (F.coordinate ~unit "wallet")
  in
  F.require (Result.is_error wrong) "identity not trimmed";
  Stdlib.print_endline
    "Opening witness and 180-bit signed quanta retained; identities/keys escaped, never normalized.";
  [%expect
    {| Opening witness and 180-bit signed quanta retained; identities/keys escaped, never normalized. |}]

let%expect_test "quantity answer copies all support families without raw-answer backreferences" =
  let module Answer = A.Current_quantity_answer in
  let module Summary = Bakhlo_presentation.Current_quantity_summary in
  let huge = Z.neg (Z.shift_left Z.one 180) in
  let image =
    ok
      (R.of_string
         (document
            [
              "event \"INTERNAL-ROOT\" \"2026-10-03\"";
              "effect anonymous \"wallet\" \"jpy\" -100";
              "effect anonymous \"food\" \"jpy\" 100";
              "end-event";
              "event \"INTERNAL-TERMINAL\" \"2026-10-03\"";
              "effect key \"INTERNAL-KEY\" \"wallet\" \"jpy\" -150";
              "effect anonymous \"food\" \"jpy\" 150";
              "end-event";
              "correct \"INTERNAL-ROOT\" \"INTERNAL-TERMINAL\"";
              "describe \"INTERNAL-ROOT\" \"INTERNAL-DESCRIPTION\"";
              "event \"INTERNAL-EXTRA\" \"2026-10-03\"";
              "effect anonymous \"wallet\" \"jpy\" -10";
              "effect anonymous \"food\" \"jpy\" 10";
              "end-event";
              "event \"INTERNAL-OPENING\" \"2026-10-03\"";
              "effect anonymous \"wallet\" \"usd\" 7";
              "effect anonymous \"offset\" \"usd\" -7";
              "end-event";
              "origin \"food\" \"jpy\"";
              "origin \"quiet\" \"jpy\"";
              "opening \"wallet\" \"usd\" \"INTERNAL-OPENING\"";
              "group";
              "reflect \"INTERNAL-ROOT\"";
              "assert \"wallet\" \"jpy\" " ^ Z.to_string huge;
              "end-group";
              "presence";
              "present \"pantry\" \"jpy\"";
              "end-presence";
              "origin " ^ quoted_bytes " place\n\027 " ^ " " ^ quoted_bytes "unit\027";
            ]))
  in
  List.iter
    [
      F.coordinate "wallet";
      F.coordinate "food";
      F.coordinate ~unit:"usd" "wallet";
      F.coordinate "quiet";
      F.coordinate "pantry";
      F.coordinate "missing";
      F.coordinate ~unit:"unit\027" " place\n\027 ";
    ]
    ~f:(fun coordinate ->
      let original = Q.query image coordinate in
      let projected = Answer.project original in
      (match (original, projected) with
      | Ok (Q.Exact original), Ok (Answer.Exact answer) -> (
          F.require
            (F.same_coordinate (Answer.coordinate answer) coordinate
            && D.Quantity.equal (Answer.quantity answer) (Q.quantity original))
            "exact coordinate/quantity connection";
          match (Q.premise original, Answer.premise answer) with
          | Zero_origin, Zero_origin | Opening _, Opening | Current_assertion _, Current_assertion
            ->
              ()
          | _ -> failwith "projection changed supplied premise family")
      | Ok (Known_present original), Ok (Known_present answer) ->
          F.require
            (F.same_coordinate (Answer.present_coordinate answer) (Q.present_coordinate original))
            "scalar-free presence coordinate connection"
      | Error (Support_unknown original), Error (Support_unknown projected) ->
          F.require
            (F.same_coordinate original.coordinate projected.coordinate)
            "unknown connection"
      | _ -> failwith "projection manufactured or erased support");
      let text = Summary.render projected in
      F.require
        ((not (String.is_substring text ~substring:"INTERNAL-"))
        && not (String.contains text '\027'))
        "raw provenance/control bytes not in projected presentation");
  F.require
    (Z.equal (value image (F.coordinate "wallet")) (Z.sub huge (Z.of_int 10)))
    "negative 180-bit quantity not truncated";
  F.require
    (Option.equal String.equal (describe image "INTERNAL-ROOT") (Some "INTERNAL-DESCRIPTION"))
    "owner evidence not deleted";
  let _, detailed =
    Bakhlo_presentation.Current_quantity_explanation.explain image (F.coordinate "wallet")
  in
  F.require (String.is_substring detailed ~substring:"INTERNAL-KEY") "owner detail positive control";
  Stdlib.print_endline
    "Exact support families, signed 180-bit quantity and exact roles preserved; presence/unknown \
     stay distinct; full evidence retained for owner inspection.";
  [%expect
    {| Exact support families, signed 180-bit quantity and exact roles preserved; presence/unknown stay distinct; full evidence retained for owner inspection. |}]

let%expect_test
    "friendly answers distinguish explicit zero, unknown amount and net-zero stale support" =
  let module Answer = A.Current_quantity_answer in
  let image =
    ok
      (R.of_string
         (document
            [
              "origin \"quiet\" \"jpy\"";
              "event \"touch\" \"2026-10-03\"";
              "effect anonymous \"stale\" \"jpy\" 1";
              "effect anonymous \"stale\" \"jpy\" -1";
              "end-event";
              "presence";
              "present \"pantry\" \"jpy\"";
              "present \"stale\" \"jpy\"";
              "end-presence";
            ]))
  in
  List.iter [ "quiet"; "pantry"; "stale"; "missing" ] ~f:(fun place ->
      Stdlib.print_string
        (Bakhlo_presentation.Current_quantity_summary.render
           (Answer.project (Q.query image (F.coordinate place)))));
  [%expect
    {|
    "quiet" / "jpy": この入力から求めた数量は 0 quanta です。
    根拠の種類: 明示されたゼロ起点。
    "pantry" / "jpy": この入力にはゼロではないという根拠がありますが、正確な数量はまだ分かりません。
    確認の手がかり: 正確な数量を示す根拠を確認してください（推測では埋めません）。
    "stale" / "jpy": この入力では数量を確定できません。0としては扱いません。
    確認の手がかり: 数量の根拠と、反映済みの記録の範囲を確認してください。
    "missing" / "jpy": この入力では数量を確定できません。0としては扱いません。
    確認の手がかり: 数量の根拠と、反映済みの記録の範囲を確認してください。
    |}]
