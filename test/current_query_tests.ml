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
  for support = 0 to 15 do
    let states = [ support % 4; support / 4 ] in
    let zero_origins = List.filteri cs ~f:(fun i _ -> let state = List.nth_exn states i in state = 1 || state = 3) in
    for cuts = 0 to 15 do
      let groups = List.filter_mapi cs ~f:(fun i c ->
        if List.nth_exn states i < 2 then None else
        let mask = if Int.equal i 0 then cuts % 4 else cuts / 4 in
        Some ({ reflected_roots = roots mask; assertions = [ F.assertion c (Z.neg huge) ] } : H.group)) in
      let result = Q.create ~source ~zero_origins ~groups in
      if List.mem states 3 ~equal:Int.equal then
        (match result with Error (Overlapping_support _) -> () | _ -> failwith "overlap became family priority")
      else (
        Int.incr admitted;
        let image = ok result in
        List.iteri cs ~f:(fun i c ->
          match List.nth_exn states i with
          | 0 -> (match Q.query image c with Error (Support_unknown { coordinate }) -> F.require (F.same_coordinate c coordinate) "unknown witness" | _ -> failwith "activity inferred support")
          | 1 ->
            let answer = ok (Q.query image c) in
            F.require (Z.equal (get image c) (Source_oracle.sum_events (List.map pairs ~f:snd) c)) "zero-origin all terminals";
            (match Q.premise answer with Zero_origin -> () | Current_assertion _ -> failwith "invented assertion")
          | 2 ->
            let mask = if Int.equal i 0 then cuts % 4 else cuts / 4 in
            let remaining = List.filter_map pairs ~f:(fun (root, terminal) ->
              if List.mem (roots mask) root ~equal:D.Identifier.Event.equal then None else Some terminal) in
            let delta = Source_oracle.sum_events remaining c in
            F.require (Z.equal (get image c) (Z.add (Z.neg huge) delta)) "independent original-Effect anchor oracle";
            (match Q.premise (ok (Q.query image c)) with
             | Current_assertion a -> F.require (Z.equal delta (D.Quantity.quanta (P.delta a))) "decomposition retained"
             | Zero_origin -> failwith "anchor became origin")
          | _ -> failwith "table state"))
    done
  done;
  F.require (Int.equal !admitted 144) "actually admitted table cases";
  Stdlib.Printf.printf "256 support/cut cases; 144 admitted; no cross-family winner\n";
  [%expect {| 256 support/cut cases; 144 admitted; no cross-family winner |}]
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
  let image = ok (Q.create ~source ~zero_origins:origins ~groups) in
  F.require (Z.equal (get image wallet) (Z.of_int 990) && Z.equal (get image usd) (Z.of_int 5) &&
    Z.equal (get image food) (Z.of_int 160)) "not union of reflected roots";
  F.require (Z.equal (get image (F.coordinate "quiet")) Z.zero) "explicit origin, no activity";
  (match Q.query image (F.coordinate "missing") with Error (Support_unknown _) -> () | _ -> failwith "unknown to zero");
  let permuted_source = ok (S.create { draft with events = List.rev events; validities = List.rev draft.validities }) in
  let permuted = ok (Q.create ~source:permuted_source ~zero_origins:(List.rev origins) ~groups:(List.rev groups)) in
  List.iter [ wallet; food; usd; F.coordinate "quiet" ] ~f:(fun c -> F.require (Z.equal (get image c) (get permuted c)) "declaration order not priority");
  F.require (List.equal F.equal_event events (D.Event_memory.events (Frontier.retained_events (S.frontier (Q.source image))))) "source retained";
  F.require (List.equal F.same_coordinate origins (Q.zero_origins image)) "origin declarations retained";
  let stored = H.groups (Q.source_groups image) in
  F.require (List.equal (fun (a : H.group) b -> List.equal D.Identifier.Event.equal a.reflected_roots b.reflected_roots &&
    List.equal F.same_assertion a.assertions b.assertions) groups stored) "whole groups retained";
  let empty = ok (S.create (source_command [] [])) in
  let zero_group : H.group = { reflected_roots = []; assertions = [ F.assertion wallet Z.zero ] } in
  (match Q.create ~source:empty ~zero_origins:[ wallet ] ~groups:[ zero_group ] with Error (Overlapping_support _) -> () | _ -> failwith "equal zero overlap");
  Stdlib.Printf.printf "anchor 990 / 5; origin 160 / 0; unknown; retained premises and source\n";
  [%expect {| anchor 990 / 5; origin 160 / 0; unknown; retained premises and source |}]
;;

let%expect_test "whole input qualification precedes global overlap; no implicit fallback or support" =
  let c = F.coordinate "wallet" in
  let events = [ event "e" [ F.change c Z.one; F.change c Z.minus_one ] ] in
  let source = ok (S.create (source_command events [])) in
  let overlap : H.group = { reflected_roots = []; assertions = [ F.assertion c Z.zero ] } in
  let invalid : H.group = { reflected_roots = [ F.id "unknown" ]; assertions = [] } in
  (match Q.create ~source ~zero_origins:[ c; c ] ~groups:[ invalid ] with
   | Error (Zero_origins (D.Zero_origin_coverage.Duplicate_coordinate { position = 2; coordinate })) -> F.require (F.same_coordinate c coordinate) "origin position"
   | _ -> failwith "coverage first");
  (match Q.create ~source ~zero_origins:[ c ] ~groups:[ overlap; invalid ] with Error (Groups (H.Invalid_cut { group_position = 2; error = _ })) -> () | _ -> failwith "whole exact family first");
  let unaffected = F.coordinate ~unit:"usd" "wallet" in
  let two : H.group = { reflected_roots = []; assertions = [ F.assertion unaffected Z.zero; F.assertion c Z.zero ] } in
  (match Q.create ~source ~zero_origins:[ c ] ~groups:[ two ] with
   | Error (Overlapping_support { coordinate; group_position = 1; assertion_position = 2 }) -> F.require (F.same_coordinate c coordinate) "overlap positions"
   | _ -> failwith "global support refusal");
  let unsupported = ok (Q.create ~source ~zero_origins:[] ~groups:[]) in
  (match Q.query unsupported c with Error (Support_unknown _) -> () | _ -> failwith "net zero inferred support");
  let empty_source = ok (S.create (source_command [] [])) in
  let empty = ok (Q.create ~source:empty_source ~zero_origins:[] ~groups:[]) in
  (match Q.query empty c with Error (Support_unknown _) -> () | _ -> failwith "empty inferred support");
  let explicit = ok (Q.create ~source:empty_source ~zero_origins:[ c ] ~groups:[]) in
  F.require (Z.equal (get explicit c) Z.zero) "explicit empty origin premise";
  Stdlib.Printf.printf "coverage -> whole exact groups -> overlap; net/empty zero never supplies support\n";
  [%expect {| coverage -> whole exact groups -> overlap; net/empty zero never supplies support |}]
;;

let%expect_test "versioned read path refuses unsupported evidence and invalid source before querying" =
  let request : C.request = { path = "synthetic.fixture"; coordinate = F.coordinate "wallet" } in
  let rows = [ "EVENT\te\t2026-10-03"; "EFFECT\twallet\tjpy\t-3"; "EFFECT\toffset\tjpy\t3"; "END-EVENT"; "ZERO-ORIGIN\twallet\tjpy" ] in
  let text = document 2 rows in
  let decoded = ok (Input.decode text) in
  F.require (Int.equal (List.length decoded.zero_origins) 1) "decoded independent support";
  let output = C.evaluate request (Ok text) in
  F.require (Int.equal output.exit_code 0 && String.is_empty output.stderr && String.is_substring output.stdout ~substring:"quantity=-3") "pure end-to-end exact";
  List.iter [ "DESCRIPTION\te\tmetadata"; "KEYED-EFFECT\tkey\twallet\tjpy\t1"; "OPENING\twallet\tjpy\te";
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
