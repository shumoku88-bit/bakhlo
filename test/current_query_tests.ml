open Base
module D = Loam_domain
module S = Loam_application.Actual_source
module Q = Loam_application.Current_quantity_query
module H = Loam_application.Current_quantity_groups
module P = Loam_application.Current_quantity_projection
module Frontier = Loam_application.Correction_frontier
module V = Loam_application.Actual_validity
module F = Fixtures
module Input = Loam_cli.Current_fixture_input
module C = Loam_cli.Current_fixture_command
let ok = function Ok value -> value | Error _ -> failwith "valid current fixture refused"
let source_command events corrections : S.command =
  { events; corrections; validities = List.map events ~f:(fun event ->
      ({ event = D.Event.id event; valid_on = "2026-10-03" } : V.fact)) }
let event token effects = D.Event.create ~id:(F.id token) ~effects
let get image c = D.Quantity.quanta (Q.quantity (ok (Q.query image c)))
let opening coordinate token : Q.opening = { coordinate; opening_event = F.id token }
let roots mask = List.filteri [ F.id "a"; F.id "x" ] ~f:(fun i _ -> if Int.equal i 0 then mask % 2 = 1 else mask / 2 = 1)
let document version rows = String.concat ~sep:"\n" (Printf.sprintf "LOAM-OCAML-ACTUAL-FIXTURE\t%d" version :: rows @ [ "END"; "" ])

let%expect_test "two-coordinate support/cut table agrees with original-list and Zarith oracle" =
  let cs = [ F.coordinate "wallet"; F.coordinate ~unit:"usd" "wallet" ] in
  let huge = Z.shift_left Z.one 160 in
  let changes j u =
    [ F.change (List.nth_exn cs 0) (Z.mul huge (Z.of_int j)); F.change (F.coordinate "offset") (Z.neg (Z.mul huge (Z.of_int j)));
      F.change (List.nth_exn cs 1) (Z.of_int u); F.change (F.coordinate ~unit:"usd" "offset") (Z.of_int (-u)) ] in
  let events = [ event "a" (changes 1 2); event "b" (changes 3 5); event "x" (changes 7 11) ] in
  let corrections = [ F.edge "a" "b" ] in
  let source = ok (S.create (source_command events corrections)) in
  let pairs = Source_oracle.expected_pairs events corrections in
  let admitted = ref 0 in
  let has bit state = state / bit % 2 = 1 in
  for support = 0 to 63 do
    let states = [ support % 8; support / 8 ] in
    let zero_origins = List.filteri cs ~f:(fun i _ -> has 1 (List.nth_exn states i)) in
    let openings = List.filter_mapi cs ~f:(fun i c ->
      if has 2 (List.nth_exn states i) then Some (opening c "b") else None) in
    for cuts = 0 to 15 do
      let groups = List.filter_mapi cs ~f:(fun i c ->
        if not (has 4 (List.nth_exn states i)) then None else
        let mask = if Int.equal i 0 then cuts % 4 else cuts / 4 in
        Some ({ reflected_roots = roots mask; assertions = [ F.assertion c (Z.neg huge) ] } : H.group)) in
      let result = Q.create ~source ~zero_origins ~openings ~groups in
      if List.exists states ~f:(fun state -> not (List.mem [ 0; 1; 2; 4 ] state ~equal:Int.equal)) then
        (match result with
         | Error (Opening_overlaps_origin _ | Assertion_overlaps_origin _ | Assertion_overlaps_opening _) -> ()
         | _ -> failwith "overlap became family priority")
      else (
        Int.incr admitted;
        let image = ok result in
        List.iteri cs ~f:(fun i c ->
          match List.nth_exn states i with
          | 0 -> (match Q.query image c with Error (Support_unknown { coordinate }) -> F.require (F.same_coordinate c coordinate) "unknown witness" | _ -> failwith "activity inferred support")
          | 1 | 2 as state ->
            let answer = ok (Q.query image c) in
            F.require (Z.equal (get image c) (Source_oracle.sum_events (List.map pairs ~f:snd) c)) "origin/opening all terminals, not just witness";
            (match state, Q.premise answer with
             | 1, Zero_origin -> ()
             | 2, Opening { coordinate; opening_event } ->
               F.require (F.same_coordinate c coordinate && D.Identifier.Event.equal opening_event (F.id "b")) "retained opening premise"
             | _ -> failwith "family tag changed")
          | 4 ->
            let mask = if Int.equal i 0 then cuts % 4 else cuts / 4 in
            let remaining = List.filter_map pairs ~f:(fun (root, terminal) ->
              if List.mem (roots mask) root ~equal:D.Identifier.Event.equal then None else Some terminal) in
            let delta = Source_oracle.sum_events remaining c in
            F.require (Z.equal (get image c) (Z.add (Z.neg huge) delta)) "independent original-Effect anchor oracle";
            (match Q.premise (ok (Q.query image c)) with
             | Current_assertion a -> F.require (Z.equal delta (D.Quantity.quanta (P.delta a))) "decomposition retained"
             | Zero_origin | Opening _ -> failwith "anchor became another family")
          | _ -> failwith "table state"))
    done
  done;
  F.require (Int.equal !admitted 256) "actually admitted table cases";
  Stdlib.Printf.printf "1024 three-family support/cut cases; 256 admitted; no cross-family winner\n";
  [%expect {| 1024 three-family support/cut cases; 256 admitted; no cross-family winner |}]
;;

let%expect_test "ordinary frontier and group cuts stay separate, including equal zero and unknown" =
  let wallet = F.coordinate "wallet" and food = F.coordinate "food" and usd = F.coordinate ~unit:"usd" "wallet" in
  let changes n = [ F.change wallet (Z.of_int (-n)); F.change food (Z.of_int n) ] in
  let events = [ event "a" (changes 100); event "b" (changes 150); event "x" (changes 10) ] in
  let draft = source_command events [ F.edge "a" "b" ] in
  let source = ok (S.create draft) in
  let groups : H.group list =
    [ { reflected_roots = [ F.id "a" ]; assertions = [ F.assertion wallet (Z.of_int 1000) ] };
      { reflected_roots = [ F.id "a"; F.id "x" ]; assertions = [ F.assertion usd (Z.of_int 5) ] } ] in
  let origins = [ food; F.coordinate "quiet" ] in
  let openings = [ opening food "b" ] in
  (* Other-family ownership of food is a global refusal, not query priority. *)
  (match Q.create ~source ~zero_origins:origins ~openings ~groups with
   | Error (Opening_overlaps_origin _) -> () | _ -> failwith "origin/opening separation");
  let image = ok (Q.create ~source ~zero_origins:origins ~openings:[] ~groups) in
  F.require (Z.equal (get image wallet) (Z.of_int 990) && Z.equal (get image usd) (Z.of_int 5) &&
    Z.equal (get image food) (Z.of_int 160)) "not union of reflected roots";
  F.require (Z.equal (get image (F.coordinate "quiet")) Z.zero) "explicit origin, no activity";
  (match Q.query image (F.coordinate "missing") with Error (Support_unknown _) -> () | _ -> failwith "unknown to zero");
  let permuted_source = ok (S.create { draft with events = List.rev events; validities = List.rev draft.validities }) in
  let permuted = ok (Q.create ~source:permuted_source ~zero_origins:(List.rev origins) ~openings:[] ~groups:(List.rev groups)) in
  List.iter [ wallet; food; usd; F.coordinate "quiet" ] ~f:(fun c -> F.require (Z.equal (get image c) (get permuted c)) "declaration order not priority");
  F.require (List.equal F.equal_event events (D.Event_memory.events (Frontier.retained_events (S.frontier (Q.source image))))) "source retained";
  F.require (List.equal F.same_coordinate origins (Q.zero_origins image)) "origin declarations retained";
  let stored = H.groups (Q.source_groups image) in
  F.require (List.equal (fun (a : H.group) b -> List.equal D.Identifier.Event.equal a.reflected_roots b.reflected_roots &&
    List.equal F.same_assertion a.assertions b.assertions) groups stored) "whole groups retained";
  let empty = ok (S.create (source_command [] [])) in
  let zero_group : H.group = { reflected_roots = []; assertions = [ F.assertion wallet Z.zero ] } in
  (match Q.create ~source:empty ~zero_origins:[ wallet ] ~openings:[] ~groups:[ zero_group ] with Error (Assertion_overlaps_origin _) -> () | _ -> failwith "equal zero overlap");
  Stdlib.Printf.printf "anchor 990 / 5; origin 160 / 0; unknown; retained premises and source\n";
  [%expect {| anchor 990 / 5; origin 160 / 0; unknown; retained premises and source |}]
;;

let%expect_test "whole input qualification precedes global overlap; no implicit fallback or support" =
  let c = F.coordinate "wallet" in
  let events = [ event "e" [ F.change c Z.one; F.change c Z.minus_one ] ] in
  let source = ok (S.create (source_command events [])) in
  let overlap : H.group = { reflected_roots = []; assertions = [ F.assertion c Z.zero ] } in
  let invalid : H.group = { reflected_roots = [ F.id "unknown" ]; assertions = [] } in
  (match Q.create ~source ~zero_origins:[ c; c ] ~openings:[] ~groups:[ invalid ] with
   | Error (Zero_origins (D.Zero_origin_coverage.Duplicate_coordinate { position = 2; coordinate })) -> F.require (F.same_coordinate c coordinate) "origin position"
   | _ -> failwith "coverage first");
  (match Q.create ~source ~zero_origins:[ c ] ~openings:[] ~groups:[ overlap; invalid ] with Error (Groups (H.Invalid_cut { group_position = 2; error = _ })) -> () | _ -> failwith "whole exact family first");
  let unaffected = F.coordinate ~unit:"usd" "wallet" in
  let two : H.group = { reflected_roots = []; assertions = [ F.assertion unaffected Z.zero; F.assertion c Z.zero ] } in
  (match Q.create ~source ~zero_origins:[ c ] ~openings:[] ~groups:[ two ] with
   | Error (Assertion_overlaps_origin { coordinate; group_position = 1; assertion_position = 2 }) -> F.require (F.same_coordinate c coordinate) "overlap positions"
   | _ -> failwith "global support refusal");
  let unsupported = ok (Q.create ~source ~zero_origins:[] ~openings:[] ~groups:[]) in
  (match Q.query unsupported c with Error (Support_unknown _) -> () | _ -> failwith "net zero inferred support");
  let empty_source = ok (S.create (source_command [] [])) in
  let empty = ok (Q.create ~source:empty_source ~zero_origins:[] ~openings:[] ~groups:[]) in
  (match Q.query empty c with Error (Support_unknown _) -> () | _ -> failwith "empty inferred support");
  let explicit = ok (Q.create ~source:empty_source ~zero_origins:[ c ] ~openings:[] ~groups:[]) in
  F.require (Z.equal (get explicit c) Z.zero) "explicit empty origin premise";
  Stdlib.Printf.printf "coverage -> whole exact groups -> overlap; net/empty zero never supplies support\n";
  [%expect {| coverage -> whole exact groups -> overlap; net/empty zero never supplies support |}]
;;

let%expect_test "opening witnesses require current Event membership, exact coordinates and uniqueness" =
  let c = F.coordinate " wallet " in
  let changes n = [ F.change c (Z.of_int n); F.change (F.coordinate "offset") (Z.of_int (-n)) ] in
  let events = [ event "a" (changes 5); event " b " (changes 7); event "x" (changes 11); event "empty" [] ] in
  let source = ok (S.create (source_command events [ F.edge "a" " b " ])) in
  let qualify openings = Q.create ~source ~zero_origins:[] ~openings ~groups:[] in
  List.iter [ "a"; "missing"; "b" ] ~f:(fun token ->
    match qualify [ opening c token ] with
    | Error (Opening_event_not_current { opening = { coordinate; opening_event }; position = 1 }) ->
      F.require (F.same_coordinate c coordinate && D.Identifier.Event.equal opening_event (F.id token)) "exact closure witness"
    | _ -> failwith "retained/nonexistent/normalized Event admitted");
  List.iter [ opening (F.coordinate "wallet") " b "; opening (F.coordinate ~unit:"JPY" " wallet ") " b "; opening c "empty" ] ~f:(fun declared ->
    match qualify [ declared ] with
    | Error (Opening_event_missing_coordinate { opening = actual; position = 1 }) ->
      F.require (F.same_coordinate declared.coordinate actual.coordinate && D.Identifier.Event.equal declared.opening_event actual.opening_event) "coordinate witness"
    | _ -> failwith "coordinate inferred from Event identity");
  List.iter [ " b "; "x"; "missing" ] ~f:(fun token ->
    match qualify [ opening c " b "; opening c token ] with
    | Error (Duplicate_opening_coordinate { coordinate; first_position = 1; position = 2 }) -> F.require (F.same_coordinate c coordinate) "duplicate precedence"
    | _ -> failwith "duplicate opening deduplicated/retargeted");
  let image = ok (qualify [ opening c " b " ]) in
  F.require (Z.equal (get image c) (Z.of_int 18)) "all terminals not only opening witness";
  (match Q.query image (F.coordinate "offset") with Error (Support_unknown _) -> () | _ -> failwith "balanced counterpart inferred support");
  Stdlib.Printf.printf "current/exact membership; duplicates refuse before second witness; counterpart unknown\n";
  [%expect {| current/exact membership; duplicates refuse before second witness; counterpart unknown |}]
;;

let%expect_test "opening reconstruction retains facts, signed multiplicity and old immutable answers" =
  let c = F.coordinate "wallet" and offset = F.coordinate "offset" in
  let huge = Z.shift_left Z.one 180 in
  let changes n = [ F.change c (Z.mul huge (Z.of_int n)); F.change c (Z.mul huge (Z.of_int n));
                    F.change offset (Z.mul huge (Z.of_int (-2 * n))) ] in
  let events = [ event "a" (changes 1); event "b" (changes (-2)); event "x" (changes 3) ] in
  let edges = [ F.edge "a" "b" ] in
  let declared = [ opening offset "x"; opening c "b" ] in
  let image = ok (Q.create ~source:(F.actual_source events edges) ~zero_origins:[] ~openings:declared ~groups:[]) in
  let expected = Source_oracle.sum_events (List.map (Source_oracle.expected_pairs events edges) ~f:snd) c in
  F.require (Z.equal (get image c) expected && Z.equal expected (Z.mul huge (Z.of_int 2))) "signed duplicate Effects counted";
  let stored = Q.openings image in
  F.require (List.equal (fun (a : Q.opening) b -> F.same_coordinate a.coordinate b.coordinate && D.Identifier.Event.equal a.opening_event b.opening_event) declared stored) "declaration order retained";
  let command = source_command (List.rev events) (List.rev edges) in
  let validities = List.rev_map command.validities ~f:(fun ({ event; valid_on = _ } : V.fact) ->
    ({ event; valid_on = "2025-01-01" } : V.fact)) in
  let permuted = ok (Q.create ~source:(ok (S.create { command with validities })) ~zero_origins:[] ~openings:(List.rev declared) ~groups:[]) in
  F.require (Z.equal (get permuted c) expected) "dates/representation not priority";
  let extended = events @ [ event "z" (changes 4) ] in
  let source = F.actual_source extended (edges @ [ F.edge "b" "z" ]) in
  (match Q.create ~source ~zero_origins:[] ~openings:declared ~groups:[] with
   | Error (Opening_event_not_current { opening = { opening_event; coordinate = _ }; position = 2 }) ->
     F.require (D.Identifier.Event.equal opening_event (F.id "b")) "retained former terminal is stale"
   | _ -> failwith "implicit correction retarget");
  let rebuilt = ok (Q.create ~source ~zero_origins:[] ~openings:[ opening c "z" ] ~groups:[]) in
  F.require (Z.equal (get rebuilt c) (Z.mul huge (Z.of_int 14)) && Z.equal (get image c) expected) "explicit rebuild; old image unchanged";
  F.require (List.equal F.equal_event events (D.Event_memory.events (Frontier.retained_events (S.frontier (Q.source image))))) "provenance retained";
  Stdlib.Printf.printf "huge signed multiplicity; retained facts/source; fresh tail needs explicit witness rebuild\n";
  [%expect {| huge signed multiplicity; retained facts/source; fresh tail needs explicit witness rebuild |}]
;;

let%expect_test "whole opening admission and global separation hold even for exact zero" =
  let c = F.coordinate "wallet" in
  let source = F.actual_source [ event "e" [ F.change c Z.one; F.change c Z.minus_one ] ] [] in
  let declared = [ opening c "e" ] in
  let group : H.group = { reflected_roots = []; assertions = [ F.assertion c Z.zero ] } in
  let invalid : H.group = { reflected_roots = [ F.id "missing" ]; assertions = [] } in
  let create zero_origins openings groups = Q.create ~source ~zero_origins ~openings ~groups in
  (match create [ c; c ] [ opening c "missing" ] [ invalid ] with Error (Zero_origins _) -> () | _ -> failwith "origin first");
  (match create [] [ opening c "missing" ] [ invalid ] with Error (Opening_event_not_current _) -> () | _ -> failwith "opening before groups");
  (match create [ c ] (declared @ [ opening (F.coordinate "bad") "missing" ]) [] with
   | Error (Opening_event_not_current { position = 2; opening = _ }) -> () | _ -> failwith "whole openings before overlap");
  (match create [ c ] declared [ invalid ] with Error (Groups _) -> () | _ -> failwith "whole groups before overlap");
  (match create [ c ] declared [ group ] with
   | Error (Opening_overlaps_origin { opening_position = 1; coordinate }) -> F.require (F.same_coordinate c coordinate) "overlap position"
   | _ -> failwith "opening/origin first, even equal zero");
  (match create [] declared [ { group with assertions = [ F.assertion (F.coordinate "other") Z.zero; F.assertion c Z.zero ] } ] with
   | Error (Assertion_overlaps_opening { opening = actual; group_position = 1; assertion_position = 2 }) ->
     F.require (D.Identifier.Event.equal actual.opening_event (F.id "e")) "opening/exact overlap witness"
   | _ -> failwith "global opening/exact overlap");
  F.require (Z.equal (get (ok (create [] declared [])) c) Z.zero) "supported zero distinct from unknown";
  Stdlib.Printf.printf "origins -> openings -> groups -> global overlap; explicit opening can justify zero\n";
  [%expect {| origins -> openings -> groups -> global overlap; explicit opening can justify zero |}]
;;

let%expect_test "versioned read path refuses unsupported evidence and invalid source before querying" =
  let request : C.request = { path = "synthetic.fixture"; coordinate = F.coordinate "wallet" } in
  let rows = [ "EVENT\te\t2026-10-03"; "EFFECT\twallet\tjpy\t-3"; "EFFECT\toffset\tjpy\t3"; "END-EVENT"; "ZERO-ORIGIN\twallet\tjpy" ] in
  let text = document 2 rows in
  let decoded = ok (Input.decode text) in
  F.require (Int.equal (List.length decoded.zero_origins) 1) "decoded independent support";
  let output = C.evaluate request (Ok text) in
  F.require (Int.equal output.exit_code 0 && String.is_empty output.stderr && String.is_substring output.stdout ~substring:"quantity=-3") "pure end-to-end exact";
  List.iter [ "DESCRIPTION\te\tmetadata"; "KEYED-EFFECT\tkey\twallet\tjpy\t1"; "OPENING\twallet\tjpy";
    "PRESENCE\twallet\tjpy"; "VALIDITY-REVISION\te\t2026-10-04"; "EXCHANGE\te"; "REVERSAL\te" ] ~f:(fun row ->
      F.require (Int.equal (C.evaluate request (Ok (document 2 (rows @ [ row ])))).exit_code 2) "unsupported row not dropped");
  F.require (Result.is_error (Input.decode (document 1 []))) "obsolete input rejected, no version guessing";
  F.require (Int.equal (C.evaluate request (Ok (String.drop_suffix text 1))).exit_code 2) "truncation";
  let invalid = document 2 [ "EVENT\te\t2026-10-03"; "EFFECT\twallet\tjpy\t1"; "END-EVENT"; "ZERO-ORIGIN\twallet\tjpy"; "ZERO-ORIGIN\twallet\tjpy" ] in
  let refused = C.evaluate request (Ok invalid) in
  F.require (Int.equal refused.exit_code 1 && String.is_empty refused.stdout && String.is_substring refused.stderr ~substring:"residual 1") "source before duplicate support";
  let failed = C.evaluate request (Error "simulated read failure") in
  F.require (Int.equal failed.exit_code 1 && String.is_empty failed.stdout) "honest failed read";
  F.require (Int.equal (C.evaluate request (Ok (document 2 []))).exit_code 3) "explicit empty still unknown";
  Stdlib.Printf.printf "v2 only; qualified source first; exact/unknown/refusal streams; no loader fallback\n";
  [%expect {| v2 only; qualified source first; exact/unknown/refusal streams; no loader fallback |}]
;;
