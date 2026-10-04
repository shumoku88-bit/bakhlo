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
  { events; corrections; descriptions = []; merchants = []; original_amounts = []; exchanges = []; reversals = []; relations = []; validity_corrections = [];
    validities = List.map events ~f:(fun event -> F.base_validity (D.Event.id event) "2026-10-03") }
let event token effects = F.observation ~id:(F.id token) ~effects
let exact image c = match ok (Q.query image c) with
  | Q.Exact answer -> answer
  | Known_present _ -> failwith "presence is not an exact quantity"
let get image c = D.Quantity.quanta (Q.quantity (exact image c))
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
  for support = 0 to 255 do
    let states = [ support % 16; support / 16 ] in
    let zero_origins = List.filteri cs ~f:(fun i _ -> has 1 (List.nth_exn states i)) in
    let openings = List.filter_mapi cs ~f:(fun i c ->
      if has 2 (List.nth_exn states i) then Some (opening c "b") else None) in
    for presence_mask = 0 to 3 do
    let presence_coordinates = List.filteri cs ~f:(fun i _ -> has 8 (List.nth_exn states i)) in
    let presence = if List.is_empty presence_coordinates then None else
      Some ({ reflected_roots = roots presence_mask; coordinates = presence_coordinates } : Q.presence) in
    for cuts = 0 to 15 do
      let groups = List.filter_mapi cs ~f:(fun i c ->
        if not (has 4 (List.nth_exn states i)) then None else
        let mask = if Int.equal i 0 then cuts % 4 else cuts / 4 in
        Some ({ reflected_roots = roots mask; assertions = [ F.assertion c (Z.neg huge) ] } : H.group)) in
      let result = Q.create ~source ~zero_origins ~openings ~groups ~presence in
      if List.exists states ~f:(fun state -> not (List.mem [ 0; 1; 2; 4; 8 ] state ~equal:Int.equal)) then
        (match result with
         | Error (Opening_overlaps_origin _ | Assertion_overlaps_origin _ | Assertion_overlaps_opening _ | Presence_overlaps_exact _) -> ()
         | _ -> failwith "overlap became family priority")
      else (
        Int.incr admitted;
        let image = ok result in
        List.iteri cs ~f:(fun i c ->
          match List.nth_exn states i with
          | 0 -> (match Q.query image c with Error (Support_unknown { coordinate }) -> F.require (F.same_coordinate c coordinate) "unknown witness" | _ -> failwith "activity inferred support")
          | 1 | 2 as state ->
            let answer = exact image c in
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
            (match Q.premise (exact image c) with
             | Current_assertion a -> F.require (Z.equal delta (D.Quantity.quanta (P.delta a))) "decomposition retained"
             | Zero_origin | Opening _ -> failwith "anchor became another family")
          | 8 ->
            let remaining = List.filter_map pairs ~f:(fun (root, terminal) ->
              if List.mem (roots presence_mask) root ~equal:D.Identifier.Event.equal then None else Some terminal) in
            let touched = Source_oracle.touches_events remaining c in
            (match Q.query image c with
             | Ok (Known_present present) -> F.require (not touched && F.same_coordinate c (Q.present_coordinate present)) "presence untouched only"
             | Error (Support_unknown _) -> F.require touched "stale presence, not zero"
             | Ok (Exact _) -> failwith "weak support entered arithmetic")
          | _ -> failwith "table state"))
    done
    done
  done;
  F.require (Int.equal !admitted 1600) "actually admitted table cases";
  Stdlib.Printf.printf "16384 four-family support/cut cases; 1600 admitted; no cross-family winner\n";
  [%expect {| 16384 four-family support/cut cases; 1600 admitted; no cross-family winner |}]
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
  (match Q.create ~source ~zero_origins:origins ~openings ~groups ~presence:None with
   | Error (Opening_overlaps_origin _) -> () | _ -> failwith "origin/opening separation");
  let image = ok (Q.create ~source ~zero_origins:origins ~openings:[] ~groups ~presence:None) in
  F.require (Z.equal (get image wallet) (Z.of_int 990) && Z.equal (get image usd) (Z.of_int 5) &&
    Z.equal (get image food) (Z.of_int 160)) "not union of reflected roots";
  F.require (Z.equal (get image (F.coordinate "quiet")) Z.zero) "explicit origin, no activity";
  (match Q.query image (F.coordinate "missing") with Error (Support_unknown _) -> () | _ -> failwith "unknown to zero");
  let permuted_source = ok (S.create { draft with events = List.rev events; validities = List.rev draft.validities }) in
  let permuted = ok (Q.create ~source:permuted_source ~zero_origins:(List.rev origins) ~openings:[] ~groups:(List.rev groups) ~presence:None) in
  List.iter [ wallet; food; usd; F.coordinate "quiet" ] ~f:(fun c -> F.require (Z.equal (get image c) (get permuted c)) "declaration order not priority");
  F.require (List.equal F.equal_event events (D.Event_memory.events (Frontier.retained_events (S.frontier (Q.source image))))) "source retained";
  F.require (List.equal F.same_coordinate origins (Q.zero_origins image)) "origin declarations retained";
  let stored = H.groups (Q.source_groups image) in
  F.require (List.equal (fun (a : H.group) b -> List.equal D.Identifier.Event.equal a.reflected_roots b.reflected_roots &&
    List.equal F.same_assertion a.assertions b.assertions) groups stored) "whole groups retained";
  let empty = ok (S.create (source_command [] [])) in
  let zero_group : H.group = { reflected_roots = []; assertions = [ F.assertion wallet Z.zero ] } in
  (match Q.create ~source:empty ~zero_origins:[ wallet ] ~openings:[] ~groups:[ zero_group ] ~presence:None with Error (Assertion_overlaps_origin _) -> () | _ -> failwith "equal zero overlap");
  Stdlib.Printf.printf "anchor 990 / 5; origin 160 / 0; unknown; retained premises and source\n";
  [%expect {| anchor 990 / 5; origin 160 / 0; unknown; retained premises and source |}]
;;

let%expect_test "whole input qualification precedes global overlap; no implicit fallback or support" =
  let c = F.coordinate "wallet" in
  let events = [ event "e" [ F.change c Z.one; F.change c Z.minus_one ] ] in
  let source = ok (S.create (source_command events [])) in
  let overlap : H.group = { reflected_roots = []; assertions = [ F.assertion c Z.zero ] } in
  let invalid : H.group = { reflected_roots = [ F.id "unknown" ]; assertions = [] } in
  (match Q.create ~source ~zero_origins:[ c; c ] ~openings:[] ~groups:[ invalid ] ~presence:None with
   | Error (Zero_origins (D.Zero_origin_coverage.Duplicate_coordinate { position = 2; coordinate })) -> F.require (F.same_coordinate c coordinate) "origin position"
   | _ -> failwith "coverage first");
  (match Q.create ~source ~zero_origins:[ c ] ~openings:[] ~groups:[ overlap; invalid ] ~presence:None with Error (Groups (H.Invalid_cut { group_position = 2; error = _ })) -> () | _ -> failwith "whole exact family first");
  let unaffected = F.coordinate ~unit:"usd" "wallet" in
  let two : H.group = { reflected_roots = []; assertions = [ F.assertion unaffected Z.zero; F.assertion c Z.zero ] } in
  (match Q.create ~source ~zero_origins:[ c ] ~openings:[] ~groups:[ two ] ~presence:None with
   | Error (Assertion_overlaps_origin { coordinate; group_position = 1; assertion_position = 2 }) -> F.require (F.same_coordinate c coordinate) "overlap positions"
   | _ -> failwith "global support refusal");
  let unsupported = ok (Q.create ~source ~zero_origins:[] ~openings:[] ~groups:[] ~presence:None) in
  (match Q.query unsupported c with Error (Support_unknown _) -> () | _ -> failwith "net zero inferred support");
  let empty_source = ok (S.create (source_command [] [])) in
  let empty = ok (Q.create ~source:empty_source ~zero_origins:[] ~openings:[] ~groups:[] ~presence:None) in
  (match Q.query empty c with Error (Support_unknown _) -> () | _ -> failwith "empty inferred support");
  let explicit = ok (Q.create ~source:empty_source ~zero_origins:[ c ] ~openings:[] ~groups:[] ~presence:None) in
  F.require (Z.equal (get explicit c) Z.zero) "explicit empty origin premise";
  Stdlib.Printf.printf "coverage -> whole exact groups -> overlap; net/empty zero never supplies support\n";
  [%expect {| coverage -> whole exact groups -> overlap; net/empty zero never supplies support |}]
;;

let%expect_test "opening witnesses require current Event membership, exact coordinates and uniqueness" =
  let c = F.coordinate " wallet " in
  let changes n = [ F.change c (Z.of_int n); F.change (F.coordinate "offset") (Z.of_int (-n)) ] in
  let events = [ event "a" (changes 5); event " b " (changes 7); event "x" (changes 11); event "empty" [] ] in
  let source = ok (S.create (source_command events [ F.edge "a" " b " ])) in
  let qualify openings = Q.create ~source ~zero_origins:[] ~openings ~groups:[] ~presence:None in
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
  let image = ok (Q.create ~source:(F.actual_source events edges) ~zero_origins:[] ~openings:declared ~groups:[] ~presence:None) in
  let expected = Source_oracle.sum_events (List.map (Source_oracle.expected_pairs events edges) ~f:snd) c in
  F.require (Z.equal (get image c) expected && Z.equal expected (Z.mul huge (Z.of_int 2))) "signed duplicate Effects counted";
  let stored = Q.openings image in
  F.require (List.equal (fun (a : Q.opening) b -> F.same_coordinate a.coordinate b.coordinate && D.Identifier.Event.equal a.opening_event b.opening_event) declared stored) "declaration order retained";
  let command = source_command (List.rev events) (List.rev edges) in
  let validities = List.rev_map command.validities ~f:(function
    | V.Base { event; valid_on = _ } -> V.Base { event; valid_on = "2025-01-01" }
    | Revision { id; event; valid_on = _ } -> Revision { id; event; valid_on = "2025-01-01" }) in
  let permuted = ok (Q.create ~source:(ok (S.create { command with validities })) ~zero_origins:[] ~openings:(List.rev declared) ~groups:[] ~presence:None) in
  F.require (Z.equal (get permuted c) expected) "dates/representation not priority";
  let extended = events @ [ event "z" (changes 4) ] in
  let source = F.actual_source extended (edges @ [ F.edge "b" "z" ]) in
  (match Q.create ~source ~zero_origins:[] ~openings:declared ~groups:[] ~presence:None with
   | Error (Opening_event_not_current { opening = { opening_event; coordinate = _ }; position = 2 }) ->
     F.require (D.Identifier.Event.equal opening_event (F.id "b")) "retained former terminal is stale"
   | _ -> failwith "implicit correction retarget");
  let rebuilt = ok (Q.create ~source ~zero_origins:[] ~openings:[ opening c "z" ] ~groups:[] ~presence:None) in
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
  let create zero_origins openings groups = Q.create ~source ~zero_origins ~openings ~groups ~presence:None in
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

let%expect_test "presence touch/cut table uses original Effects even when every coordinate sums to zero" =
  let cs = [ F.coordinate "wallet"; F.coordinate ~unit:"usd" "wallet" ] in
  let huge = Z.shift_left Z.one 180 in
  let subset mask = List.filteri cs ~f:(fun i _ -> mask / (if i = 0 then 1 else 2) % 2 = 1) in
  let changes mask = List.concat_map (subset mask) ~f:(fun c -> [ F.change c huge; F.change c (Z.neg huge) ]) in
  let cases = ref 0 and known = ref 0 in
  for shape = 0 to 63 do
    let events = [ event "a" (changes (shape % 4)); event "b" (changes (shape / 4 % 4)); event "x" (changes (shape / 16)) ] in
    let edges = [ F.edge "a" "b" ] in
    let source = F.actual_source events edges in
    let pairs = Source_oracle.expected_pairs events edges in
    for cut_mask = 0 to 3 do
      let reflected_roots = roots cut_mask in
      let remaining = List.filter_map pairs ~f:(fun (root, original) ->
        if List.mem reflected_roots root ~equal:D.Identifier.Event.equal then None else Some original) in
      for declaration = 0 to 3 do
        Int.incr cases;
        let coordinates = subset declaration in
        let evidence : Q.presence = { reflected_roots; coordinates } in
        let image = ok (Q.create ~source ~zero_origins:[] ~openings:[] ~groups:[] ~presence:(Some evidence)) in
        List.iter cs ~f:(fun c ->
          F.require (Z.equal (Source_oracle.sum_events remaining c) Z.zero) "touch oracle not arithmetic";
          let expected = List.mem coordinates c ~equal:F.same_coordinate && not (Source_oracle.touches_events remaining c) in
          match Q.query image c with
          | Ok (Known_present answer) ->
            Int.incr known;
            F.require (expected && F.same_coordinate (Q.present_coordinate answer) c) "original-Effect touch gate";
            let stored = Q.present_evidence answer in
            F.require (List.equal F.same_coordinate stored.coordinates coordinates &&
              List.equal D.Identifier.Event.equal stored.reflected_roots reflected_roots) "whole independent premise retained";
            F.require_cut_source (S.frontier source) (Q.present_cut answer) reflected_roots
          | Error (Support_unknown { coordinate }) -> F.require (not expected && F.same_coordinate c coordinate) "unsupported/stale witness"
          | Ok (Exact _) -> failwith "presence fabricated a scalar")
      done
    done
  done;
  F.require (!cases = 1024 && !known = 576) "executed finite touch scope";
  Stdlib.Printf.printf "1024 shape/cut/declaration cases; 576 known-present answers; all deltas zero\n";
  [%expect {| 1024 shape/cut/declaration cases; 576 known-present answers; all deltas zero |}]
;;

let%expect_test "presence is independently observed; selected touches invalidate without destroying old evidence" =
  let wallet = F.coordinate "wallet" and usd = F.coordinate ~unit:"usd" "wallet" in
  let changes c = [ F.change c Z.one; F.change c Z.minus_one ] in
  let evidence : Q.presence = { reflected_roots = []; coordinates = [ wallet; usd ] } in
  let create events edges presence = Q.create ~source:(F.actual_source events edges) ~zero_origins:[] ~openings:[] ~groups:[] ~presence in
  let empty = ok (create [] [] (Some evidence)) in
  let before = ok (Q.query empty wallet) in
  (match before with Known_present _ -> () | Exact _ -> failwith "empty source observation became zero");
  let absent = ok (create [] [] None) in
  (match Q.query absent wallet with Error (Support_unknown _) -> () | _ -> failwith "absence inferred presence");
  let events = [ event "a" (changes wallet); event "b" (changes usd); event "x" [] ] in
  let edges = [ F.edge "a" "b" ] in
  let current = ok (create events edges (Some evidence)) in
  (match Q.query current wallet with Ok (Known_present _) -> () | _ -> failwith "superseded activity invalidated presence");
  (match Q.query current usd with Error (Support_unknown _) -> () | _ -> failwith "net-zero current touch remained supported");
  let tail = ok (create (events @ [ event "z" (changes wallet) ]) (edges @ [ F.edge "b" "z" ]) (Some evidence)) in
  (match Q.query tail wallet, Q.query tail usd with Error (Support_unknown _), Ok (Known_present _) -> () | _ -> failwith "selected terminal, not retained history");
  let reflected : Q.presence = { reflected_roots = [ F.id "a" ]; coordinates = [ wallet; usd ] } in
  let cut_image = ok (create events edges (Some reflected)) in
  let cut_tail = ok (create (events @ [ event "z" (changes wallet) ]) (edges @ [ F.edge "b" "z" ]) (Some reflected)) in
  List.iter [ cut_image; cut_tail ] ~f:(fun image -> List.iter [ wallet; usd ] ~f:(fun c ->
    match Q.query image c with Ok (Known_present _) -> () | _ -> failwith "root cut leaked corrected lineage"));
  (match create (event "prefix" [] :: events) (F.edge "prefix" "a" :: edges) (Some reflected) with
   | Error (Presence_cut (Loam_application.Reflected_root_cut.Not_root { id; position = 1 })) -> F.require (D.Identifier.Event.equal id (F.id "a")) "prefix invalidated declared root"
   | _ -> failwith "arbitrary source edit reused old cut");
  let permuted = ok (create (List.rev events) (List.rev edges) (Some { reflected with coordinates = List.rev reflected.coordinates })) in
  (match Q.query permuted wallet, Q.query empty wallet with Ok (Known_present _), Ok (Known_present _) -> () | _ -> failwith "order/prior image changed");
  F.require (List.equal F.equal_event events (D.Event_memory.events (Frontier.retained_events (S.frontier (Q.source current))))) "retained provenance";
  (match Q.presence current with Some stored -> F.require (List.equal F.same_coordinate stored.coordinates evidence.coordinates) "stale raw premise retained" | None -> failwith "stale evidence discarded");
  Stdlib.Printf.printf "empty observation != zero/absence; terminal touches, independent cuts, source rebuild and retention\n";
  [%expect {| empty observation != zero/absence; terminal touches, independent cuts, source rebuild and retention |}]
;;

let%expect_test "presence cut/coordinate admission precedes separation including stale and equal-zero overlap" =
  let c = F.coordinate "wallet" and other = F.coordinate "other" in
  let source = F.actual_source [ event "a" [ F.change c Z.one; F.change c Z.minus_one ]; event "b" [] ] [ F.edge "a" "b" ] in
  let evidence : Q.presence = { reflected_roots = []; coordinates = [ other; c ] } in
  let create origins openings groups evidence = Q.create ~source ~zero_origins:origins ~openings ~groups ~presence:(Some evidence) in
  let group : H.group = { reflected_roots = []; assertions = [ F.assertion c Z.zero ] } in
  let bad_presence : Q.presence = { reflected_roots = [ F.id "missing" ]; coordinates = [] } in
  (match create [ c; c ] [] [] bad_presence with Error (Zero_origins _) -> () | _ -> failwith "origins before presence");
  (match create [] [ opening c "missing" ] [] bad_presence with Error (Opening_event_not_current _) -> () | _ -> failwith "openings before presence");
  (match create [] [] [ { group with reflected_roots = [ F.id "missing" ] } ] bad_presence with Error (Groups _) -> () | _ -> failwith "groups before presence");
  (match create [] [] [] bad_presence with
   | Error (Presence_cut (Loam_application.Reflected_root_cut.Unknown_event { position = 1; id = _ })) -> () | _ -> failwith "empty-coordinate invalid cut ignored");
  (match create [] [] [] { evidence with reflected_roots = [ F.id "a"; F.id "a" ] } with
   | Error (Presence_cut (Loam_application.Reflected_root_cut.Duplicate_root { first_position = 1; position = 2; id = _ })) -> () | _ -> failwith "duplicate presence root");
  (match create [] [] [] { reflected_roots = [ F.id "b" ]; coordinates = [ c; c ] } with Error (Presence_cut _) -> () | _ -> failwith "cut before coordinate uniqueness");
  (match create [ c ] [] [] { evidence with coordinates = [ c; c ] } with
   | Error (Duplicate_presence_coordinate { first_position = 1; position = 2; coordinate }) -> F.require (F.same_coordinate c coordinate) "coordinate duplicate before overlap"
   | _ -> failwith "duplicate presence silently deduplicated");
  (match create [ c ] [] [ group ] { evidence with coordinates = [ c; c ] } with Error (Duplicate_presence_coordinate _) -> () | _ -> failwith "whole presence before exact overlap");
  (match create [ c ] [] [] evidence with
   | Error (Presence_overlaps_exact { coordinate; position = 2 }) -> F.require (F.same_coordinate c coordinate) "declared-order global overlap"
   | _ -> failwith "presence/origin priority");
  (match create [] [] [ group ] evidence with Error (Presence_overlaps_exact _) -> () | _ -> failwith "presence/assertion equal-zero priority");
  let touch_source = F.actual_source [ event "e" [ F.change c Z.one; F.change c Z.minus_one ] ] [] in
  (match Q.create ~source:touch_source ~zero_origins:[] ~openings:[ opening c "e" ] ~groups:[] ~presence:(Some evidence) with
   | Error (Presence_overlaps_exact _) -> () | _ -> failwith "stale presence/opening overlap ignored");
  Stdlib.Printf.printf "whole cut/unique declarations first; global exact separation even when presence is stale\n";
  [%expect {| whole cut/unique declarations first; global exact separation even when presence is stale |}]
;;

let%expect_test "versioned read path refuses unsupported evidence and invalid source before querying" =
  let request : C.request = { path = "synthetic.fixture"; coordinate = F.coordinate "wallet" } in
  let rows = [ "EVENT\te\t2026-10-03"; "EFFECT\twallet\tjpy\t-3"; "EFFECT\toffset\tjpy\t3"; "END-EVENT"; "ZERO-ORIGIN\twallet\tjpy" ] in
  let text = document 2 rows in
  let decoded = ok (Input.decode text) in
  F.require (Int.equal (List.length decoded.zero_origins) 1) "decoded independent support";
  let output = C.evaluate request (Ok text) in
  F.require (Int.equal output.exit_code 0 && String.is_empty output.stderr && String.is_substring output.stdout ~substring:"quantity=-3") "pure end-to-end exact";
  List.iter [ "PURPOSE\te\tmetadata"; "KEYED-EFFECT\tkey\twallet\tjpy"; "OPENING\twallet\tjpy";
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
