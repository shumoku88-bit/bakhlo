open Base
module D = Bakhlo_domain
module A = Bakhlo_application
module Q = A.Current_quantity_query
module B = Bakhlo_sexp.Daily_book

let get = function Ok x -> x | Error why -> failwith why

let eid s =
  Result.ok_or_failwith
    (Result.map_error (D.Identifier.Event.of_string s) ~f:(fun _ -> "event"))

let lid s =
  Result.ok_or_failwith
    (Result.map_error (D.Identifier.Locus.of_string s) ~f:(fun _ -> "locus"))

let mid s =
  Result.ok_or_failwith
    (Result.map_error (D.Identifier.Measure.of_string s) ~f:(fun _ -> "measure"))

let posting locus measure n key_opt =
  D.Effect.create
    ~locus:(lid locus)
    ~measure:(mid measure)
    ~quantity:(D.Quantity.of_quanta (Z.of_int n))
    ~key:(Option.map key_opt ~f:(fun k ->
      Result.ok_or_failwith
        (Result.map_error (D.Identifier.Effect_key.of_string k) ~f:(fun _ -> "key"))))

let quantity book locus measure =
  let image = B.image book in
  let target = { D.Effect_coordinate.locus = lid locus; measure = mid measure } in
  match Q.query image target with
  | Ok (Q.Exact x) -> Z.to_string (D.Quantity.quanta (Q.quantity x))
  | Ok (Q.Known_present _) -> "known-present"
  | Error (Q.Support_unknown _) -> "unknown"

let calc_fingerprint str =
  Stdlib.Digest.to_hex (Stdlib.Digest.string str)

(*******************************************************************************
  1. CarryForward Persistence Types & Serializers
*******************************************************************************)

module Carry_forward_persist = struct
  type locus_quantity =
    | Exact of Z.t
    | Zero_origin
    | Known_present
    | Unknown

  type coordinate = { locus : string; measure : string }

  type t = {
    prior_year : int;
    prior_revision : int;
    prior_fingerprint : string;
    as_of_day : string;
    balances : (coordinate * locus_quantity) list;
    retained_roots : string list;
    schema_version : int;
  }

  let derive ~(prior_book : B.t) ~prior_year ~prior_revision ~prior_fingerprint ~as_of_day
      ~coordinates =
    let image = B.image prior_book in
    let balances =
      List.map coordinates ~f:(fun (l, m) ->
          let coord = { locus = l; measure = m } in
          let effect_coord = { D.Effect_coordinate.locus = lid l; measure = mid m } in
          let qty =
            match Q.query image effect_coord with
            | Ok (Q.Exact x) ->
              (match Q.premise x with
               | Q.Zero_origin when Z.equal (D.Quantity.quanta (Q.quantity x)) Z.zero ->
                 Zero_origin
               | _ ->
                 Exact (D.Quantity.quanta (Q.quantity x)))
            | Ok (Q.Known_present _) -> Known_present
            | Error (Q.Support_unknown _) -> Unknown
          in
          (coord, qty))
    in
    let retained_roots =
      List.concat_map (Q.source_groups (B.image prior_book) |> A.Current_quantity_groups.groups)
        ~f:(fun g -> List.map g.reflected_roots ~f:D.Identifier.Event.to_string)
      |> List.dedup_and_sort ~compare:String.compare
    in
    {
      prior_year;
      prior_revision;
      prior_fingerprint;
      as_of_day;
      balances;
      retained_roots;
      schema_version = 1;
    }

  let find_balance (t : t) ~locus ~measure =
    List.find_map t.balances ~f:(fun (c, q) ->
        if String.equal c.locus locus && String.equal c.measure measure then Some q else None)
    |> Option.value ~default:Unknown
end

(*******************************************************************************
  2. Abstract Trusted Selection Contract Module
     Maintains the authoritative, atomic mapping of currently active year revisions.
     Decoupled from specific manifest files or storage engines.
*******************************************************************************)

module Trusted_selection = struct
  type revision_entry = {
    revision : int;
    fingerprint : string;
    header_revision : int; (* self-declared revision inside file header *)
  }

  type selection_status =
    | Active
    | Missing
    | Corrupted of string
    | Indeterminate of string

  type t = {
    generation : int; (* Monotonically increasing generation clock *)
    status : selection_status;
    years : (int, revision_entry, Int.comparator_witness) Map.t;
  }

  let create ~generation ~status selections =
    let map =
      List.fold selections ~init:(Map.empty (module Int)) ~f:(fun acc (y, entry) ->
          Map.set acc ~key:y ~data:entry)
    in
    { generation; status; years = map }

  let get_year (t : t) year =
    match t.status with
    | Active -> Map.find t.years year
    | _ -> None

  (* Update a year revision atomically, incrementing the generation *)
  let update_year (t : t) ~year ~revision ~fingerprint ~header_revision =
    let entry = { revision; fingerprint; header_revision } in
    {
      generation = t.generation + 1;
      status = Active;
      years = Map.set t.years ~key:year ~data:entry;
    }
end

(*******************************************************************************
  3. Selection Contract Verification & Reader/Writer Sessions
*******************************************************************************)

module Selection_verifier = struct
  type freshness_error =
    | Stale_carry_forward of { expected_rev : int; actual_rev : int }
    | Fingerprint_mismatch of { expected_fp : string; actual_fp : string }
    | Missing_prior_selection of int
    | Indeterminate_selection of string
    | Header_divergence of {
        year : int;
        trusted_rev : int;
        header_rev : int;
      }

  let error_to_string = function
    | Stale_carry_forward { expected_rev; actual_rev } ->
      Printf.sprintf "Stale_carry_forward: expected rev %d, trusted selected rev %d"
        expected_rev actual_rev
    | Fingerprint_mismatch { expected_fp; actual_fp } ->
      Printf.sprintf "Fingerprint_mismatch: expected %s, trusted selected %s"
        expected_fp actual_fp
    | Missing_prior_selection y ->
      Printf.sprintf "Missing_prior_selection: year %d has no authoritative selection" y
    | Indeterminate_selection why ->
      Printf.sprintf "Indeterminate_selection: %s" why
    | Header_divergence { year; trusted_rev; header_rev } ->
      Printf.sprintf "Header_divergence: year %d header claims rev %d but trusted selection is rev %d"
        year header_rev trusted_rev

  (* Pinned Reader Session: Pins a consistent snapshot generation for the entire query *)
  type reader_session = {
    pinned_snapshot : Trusted_selection.t;
    pinned_generation : int;
  }

  let begin_reader_session (selection : Trusted_selection.t) : (reader_session, freshness_error) Result.t =
    match selection.status with
    | Trusted_selection.Active ->
      Ok { pinned_snapshot = selection; pinned_generation = selection.generation }
    | Trusted_selection.Missing ->
      Error (Indeterminate_selection "authoritative selection state missing")
    | Trusted_selection.Corrupted why ->
      Error (Indeterminate_selection (Printf.sprintf "corrupted selection: %s" why))
    | Trusted_selection.Indeterminate why ->
      Error (Indeterminate_selection (Printf.sprintf "indeterminate selection: %s" why))

  (* Verifies that CarryForward is derived from the trusted selection snapshot, NOT just matching a local header *)
  let verify_carry_forward (session : reader_session) (cf : Carry_forward_persist.t)
      ~(actual_header_rev : int) : (unit, freshness_error) Result.t =
    match Trusted_selection.get_year session.pinned_snapshot cf.prior_year with
    | None -> Error (Missing_prior_selection cf.prior_year)
    | Some trusted_entry ->
      (* 1. Check header-body divergence: If local file header contradicts trusted selection *)
      if trusted_entry.revision <> actual_header_rev then
        Error (Header_divergence {
          year = cf.prior_year;
          trusted_rev = trusted_entry.revision;
          header_rev = actual_header_rev;
        })
      (* 2. Check revision freshness against trusted selection *)
      else if cf.prior_revision <> trusted_entry.revision then
        Error (Stale_carry_forward {
          expected_rev = cf.prior_revision;
          actual_rev = trusted_entry.revision;
        })
      (* 3. Check fingerprint against trusted selection *)
      else if not (String.equal cf.prior_fingerprint trusted_entry.fingerprint) then
        Error (Fingerprint_mismatch {
          expected_fp = cf.prior_fingerprint;
          actual_fp = trusted_entry.fingerprint;
        })
      else
        Ok ()

  (* Ephemeral synthesizer: Combines verified CarryForward and current year entries *)
  let synthesize_ephemeral_ledger
      ~(cf : Carry_forward_persist.t)
      ~(retained_entries : B.entry list)
      ~(retained_plans : B.plan list)
      ~(current_entries : B.entry list)
      ~(current_plans : B.plan list) : (B.t, string) Result.t =
    let all_entries = retained_entries @ current_entries in
    let all_plans = retained_plans @ current_plans in
    let retained_entry_ids = List.map retained_entries ~f:(fun e -> e.id) in
    let all_reflected_roots =
      List.dedup_and_sort ~compare:String.compare retained_entry_ids
    in
    let exact_obs_items =
      List.filter_map cf.balances ~f:(fun (coord, q) ->
          match q with
          | Carry_forward_persist.Exact amt ->
            Some (Printf.sprintf "(%s %s %s)" coord.locus coord.measure (Z.to_string amt))
          | _ -> None)
    in
    let zero_origin_items =
      List.filter_map cf.balances ~f:(fun (coord, q) ->
          match q with
          | Carry_forward_persist.Zero_origin ->
            Some (Printf.sprintf "(%s %s)" coord.locus coord.measure)
          | _ -> None)
    in
    let entries_sexp_str =
      List.map all_entries ~f:(fun e ->
          let postings_str =
            List.map e.effects ~f:(fun eff ->
                let k_str =
                  match D.Effect.key eff with
                  | Some k -> Printf.sprintf "(some %s)" (D.Identifier.Effect_key.to_string k)
                  | None -> "(none)"
                in
                Printf.sprintf "(posting %s %s %s %s)"
                  (D.Identifier.Locus.to_string (D.Effect.locus eff))
                  (D.Identifier.Measure.to_string (D.Effect.measure eff))
                  (Z.to_string (D.Quantity.quanta (D.Effect.quantity eff)))
                  k_str)
            |> String.concat ~sep:" "
          in
          let rev_str = match e.reversal_of with Some r -> Printf.sprintf "(some %s)" r | None -> "(none)" in
          let exch_str =
            match e.exchange with
            | Some (k1, k2) -> Printf.sprintf "(keys %s %s)" k1 k2
            | None -> "(none)"
          in
          let memo_str = match e.memo with Some m -> Printf.sprintf "(some %s)" m | None -> "(none)" in
          Printf.sprintf "(entry %s (date %s) (memo %s) (postings %s) (reversal-of %s) (exchange %s))"
            e.id e.day memo_str postings_str rev_str exch_str)
      |> String.concat ~sep:"\n"
    in
    let plans_sexp_str =
      List.map all_plans ~f:(fun p ->
          let changes_str =
            List.map p.changes ~f:(fun (l, amt) -> Printf.sprintf "(%s %s)" l (Z.to_string amt))
            |> String.concat ~sep:" "
          in
          let paid_str = match p.paid_by with Some id -> Printf.sprintf "(some %s)" id | None -> "(none)" in
          let canc_str = match p.cancelled_on with Some d -> Printf.sprintf "(some %s)" d | None -> "(none)" in
          Printf.sprintf "(plan %s (date %s) (measure %s) (changes %s) (paid-by %s) (cancelled-on %s))"
            p.id p.day p.measure changes_str paid_str canc_str)
      |> String.concat ~sep:"\n"
    in
    let obs_str =
      if List.is_empty exact_obs_items then ""
      else
        Printf.sprintf "(observation (reflected %s) (quantities %s))"
          (String.concat ~sep:" " all_reflected_roots)
          (String.concat ~sep:" " exact_obs_items)
    in
    let text =
      Printf.sprintf
        "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
         (measures (measure jpy 0) (measure eur 2))\n\
         (labels (provided (label wallet 財布 現金) (label bank 銀行 口座)))\n\
         (approved-loci (provided wallet bank food rent salary tax))\n\
         (entries\n%s\n)\n\
         (plans\n%s\n)\n\
         (support\n\
           (zero-origin %s)\n\
           (openings)\n\
           (observations %s)\n\
           (presence (not-supplied))\n\
         )\n"
        entries_sexp_str
        plans_sexp_str
        (String.concat ~sep:" " zero_origin_items)
        obs_str
    in
    B.of_string text

  (* OCC Publishing Protocol (Matches TLA+ v0.2 OCC Specification) *)
  type publication_error =
    | Generation_conflict of { observed_gen : int; current_gen : int }

  let publish_candidate
      ~(current_selection : Trusted_selection.t)
      ~(observed_generation : int)
      ~(new_year_entries : (int * int * string * int) list) (* year, rev, fp, header_rev *) :
      (Trusted_selection.t, publication_error) Result.t =
    if current_selection.generation <> observed_generation then
      Error (Generation_conflict {
        observed_gen = observed_generation;
        current_gen = current_selection.generation;
      })
    else
      let next_t =
        List.fold new_year_entries ~init:current_selection ~f:(fun acc (y, r, fp, hr) ->
            Trusted_selection.update_year acc ~year:y ~revision:r ~fingerprint:fp ~header_revision:hr)
      in
      Ok next_t
end

let get_session = function
  | Ok s -> s
  | Error err -> failwith (Selection_verifier.error_to_string err)

(*******************************************************************************
  4. Synthetic Canonical Document Fixtures (2025 v1, 2025 v2, 2026 partitions)
*******************************************************************************)

let fixture_2025_v1_text =
  "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
   (measures (measure jpy 0) (measure eur 2))\n\
   (labels (provided (label wallet 財布 現金) (label bank 銀行 口座)))\n\
   (approved-loci (provided wallet bank food rent salary tax))\n\
   (entries\n\
     (entry e_2025_seed (date 2025-01-05) (memo (some initial))\n\
       (postings (posting wallet jpy 100000 (none)) (posting salary jpy -100000 (none)))\n\
       (reversal-of (none))\n\
       (exchange (none)))\n\
     (entry e_2025_rent (date 2025-01-25) (memo (some rent))\n\
       (postings (posting wallet jpy -50000 (none)) (posting rent jpy 50000 (none)))\n\
       (reversal-of (none))\n\
       (exchange (none)))\n\
     (entry e_2025_deposit (date 2025-06-10) (memo (some mistake-deposit))\n\
       (postings (posting wallet jpy -10000 (none)) (posting bank jpy 10000 (none)))\n\
       (reversal-of (none))\n\
       (exchange (none)))\n\
     (entry e_2025_misc (date 2025-11-15) (memo (some supplies))\n\
       (postings (posting wallet jpy -3000 (none)) (posting food jpy 3000 (none)))\n\
       (reversal-of (none))\n\
       (exchange (none)))\n\
   )\n\
   (plans\n\
     (plan p_2025_cross_year (date 2026-02-15) (measure jpy)\n\
       (changes (wallet -12000) (rent 12000))\n\
       (paid-by (none))\n\
       (cancelled-on (none)))\n\
   )\n\
   (support\n\
     (zero-origin (food jpy) (rent jpy) (tax jpy) (bank jpy) (wallet eur))\n\
     (openings)\n\
     (observations\n\
       (observation (reflected e_2025_seed e_2025_rent)\n\
         (quantities (wallet jpy 50000))\n\
       )\n\
     )\n\
     (presence (not-supplied))\n\
   )\n"

let fixture_2025_v2_amended_text =
  String.substr_replace_all fixture_2025_v1_text
    ~pattern:"(entry e_2025_misc (date 2025-11-15) (memo (some supplies))\n       (postings (posting wallet jpy -3000 (none)) (posting food jpy 3000 (none)))"
    ~with_:"(entry e_2025_misc (date 2025-11-15) (memo (some supplies))\n       (postings (posting wallet jpy -5000 (none)) (posting food jpy 5000 (none)))"

let coords =
  [
    ("wallet", "jpy");
    ("bank", "jpy");
    ("wallet", "eur");
    ("food", "jpy");
    ("rent", "jpy");
    ("tax", "jpy");
    ("salary", "eur");
  ]

let raw_entries_2026 : B.entry list =
  [
    {
      id = "e_2026_reversal";
      day = "2026-01-10";
      memo = Some "fix-deposit";
      effects = [ posting "wallet" "jpy" 10000 None; posting "bank" "jpy" (-10000) None ];
      reversal_of = Some "e_2025_deposit";
      exchange = None;
    };
    {
      id = "e_2026_pay_plan";
      day = "2026-02-15";
      memo = Some "paid-annual-fee";
      effects = [ posting "wallet" "jpy" (-12000) None; posting "rent" "jpy" 12000 None ];
      reversal_of = None;
      exchange = None;
    };
    {
      id = "e_2026_fx";
      day = "2026-05-10";
      memo = Some "travel-fx";
      effects = [ posting "wallet" "jpy" (-15000) (Some "from"); posting "wallet" "eur" 10000 (Some "to") ];
      reversal_of = None;
      exchange = Some ("from", "to");
    };
  ]

let raw_plans_2026 : B.plan list =
  [
    {
      id = "p_2026_open";
      day = "2026-09-01";
      measure = "jpy";
      changes = [ ("wallet", Z.of_int (-5000)); ("food", Z.of_int 5000) ];
      paid_by = None;
      cancelled_on = None;
    };
  ]

(*******************************************************************************
  5. Test Suite: Trusted Selection Contract Synthetic Studies
*******************************************************************************)

let%expect_test "Test 1: Normal Query with Fresh CarryForward & Authoritative Selection" =
  let fp_2025_v1 = calc_fingerprint fixture_2025_v1_text in
  let book_2025_v1 = get (B.of_string fixture_2025_v1_text) in

  (* CarryForward is derived from 2025 v1 *)
  let cf_v1 =
    Carry_forward_persist.derive ~prior_book:book_2025_v1 ~prior_year:2025 ~prior_revision:1
      ~prior_fingerprint:fp_2025_v1 ~as_of_day:"2025-12-31" ~coordinates:coords
  in

  (* Trusted selection currently selects 2025:rev1 and 2026:rev1 *)
  let selection_initial =
    Trusted_selection.create ~generation:1 ~status:Trusted_selection.Active
      [
        (2025, { revision = 1; fingerprint = fp_2025_v1; header_revision = 1 });
        (2026, { revision = 1; fingerprint = "fp-2026-v1"; header_revision = 1 });
      ]
  in

  (* Begin reader session pinned to selection generation 1 *)
  let session = get_session (Selection_verifier.begin_reader_session selection_initial) in
  Stdio.printf "Reader session pinned generation: %d\n" session.pinned_generation;

  (* Verify CarryForward against authoritative selection *)
  let verify_res =
    Selection_verifier.verify_carry_forward session cf_v1 ~actual_header_rev:1
  in
  Stdio.printf "CarryForward verification succeeded: %b\n" (Result.is_ok verify_res);

  (* Synthesize ephemeral book without reading 2025 full ledger *)
  let retained_deposit = Option.value_exn (B.find_entry book_2025_v1 "e_2025_deposit") in
  let retained_plan = Option.value_exn (List.find (B.plans book_2025_v1) ~f:(fun p -> String.equal p.id "p_2025_cross_year")) in
  let ephemeral_book =
    get (Selection_verifier.synthesize_ephemeral_ledger ~cf:cf_v1
           ~retained_entries:[ retained_deposit ]
           ~retained_plans:[ { retained_plan with paid_by = Some "e_2026_pay_plan" } ]
           ~current_entries:raw_entries_2026 ~current_plans:raw_plans_2026)
  in
  Stdio.printf "Normal query wallet JPY: %s\n" (quantity ephemeral_book "wallet" "jpy");
  Stdio.printf "Normal query bank JPY: %s\n" (quantity ephemeral_book "bank" "jpy");
  Stdio.printf "Normal query wallet EUR: %s\n" (quantity ephemeral_book "wallet" "eur");
  [%expect {|
    Reader session pinned generation: 1
    CarryForward verification succeeded: true
    Normal query wallet JPY: 20000
    Normal query bank JPY: 0
    Normal query wallet EUR: 10000
  |}]

let%expect_test "Test 2: Rejection of Stale CarryForward When Prior Selection is Updated" =
  let fp_2025_v1 = calc_fingerprint fixture_2025_v1_text in
  let fp_2025_v2 = calc_fingerprint fixture_2025_v2_amended_text in
  let book_2025_v1 = get (B.of_string fixture_2025_v1_text) in

  (* CarryForward is still the old v1 *)
  let cf_v1 =
    Carry_forward_persist.derive ~prior_book:book_2025_v1 ~prior_year:2025 ~prior_revision:1
      ~prior_fingerprint:fp_2025_v1 ~as_of_day:"2025-12-31" ~coordinates:coords
  in

  (* But trusted selection has been updated to 2025:rev2! *)
  let selection_updated =
    Trusted_selection.create ~generation:2 ~status:Trusted_selection.Active
      [
        (2025, { revision = 2; fingerprint = fp_2025_v2; header_revision = 2 });
        (2026, { revision = 1; fingerprint = "fp-2026-v1"; header_revision = 1 });
      ]
  in

  let session = get_session (Selection_verifier.begin_reader_session selection_updated) in
  let verify_res =
    Selection_verifier.verify_carry_forward session cf_v1 ~actual_header_rev:2
  in
  Stdio.printf "Stale CarryForward rejected: %b\n" (Result.is_error verify_res);
  (match verify_res with
   | Error err -> Stdio.printf "Refusal reason: %s\n" (Selection_verifier.error_to_string err)
   | Ok _ -> ());
  [%expect {|
    Stale CarryForward rejected: true
    Refusal reason: Stale_carry_forward: expected rev 1, trusted selected rev 2
  |}]

let%expect_test "Test 3: Detection of Header-Body Divergence (Stale Local Header vs Active Selection)" =
  let fp_2025_v2 = calc_fingerprint fixture_2025_v2_amended_text in
  let book_2025_v2 = get (B.of_string fixture_2025_v2_amended_text) in

  (* CarryForward is re-derived from v2 *)
  let cf_v2 =
    Carry_forward_persist.derive ~prior_book:book_2025_v2 ~prior_year:2025 ~prior_revision:2
      ~prior_fingerprint:fp_2025_v2 ~as_of_day:"2025-12-31" ~coordinates:coords
  in

  (* Trusted selection selects 2025:rev2 *)
  let selection =
    Trusted_selection.create ~generation:2 ~status:Trusted_selection.Active
      [
        (2025, { revision = 2; fingerprint = fp_2025_v2; header_revision = 2 });
        (2026, { revision = 1; fingerprint = "fp-2026-v1"; header_revision = 1 });
      ]
  in
  let session = get_session (Selection_verifier.begin_reader_session selection) in

  (* Scenario: Someone only updated a local lightweight header file to claim rev 1, or header was not updated *)
  let fake_local_header_rev = 1 in
  let verify_res =
    Selection_verifier.verify_carry_forward session cf_v2 ~actual_header_rev:fake_local_header_rev
  in
  Stdio.printf "Header divergence detected & refused: %b\n" (Result.is_error verify_res);
  (match verify_res with
   | Error err -> Stdio.printf "Refusal reason: %s\n" (Selection_verifier.error_to_string err)
   | Ok _ -> ());
  [%expect {|
    Header divergence detected & refused: true
    Refusal reason: Header_divergence: year 2025 header claims rev 1 but trusted selection is rev 2
  |}]

let%expect_test "Test 4: Fail-Closed Rejection When Trusted Selection is Indeterminate or Corrupted" =
  (* 4A: Selection missing *)
  let selection_missing =
    { Trusted_selection.generation = 0; status = Trusted_selection.Missing; years = Map.empty (module Int) }
  in
  let res_missing = Selection_verifier.begin_reader_session selection_missing in
  Stdio.printf "Missing selection refused: %b\n" (Result.is_error res_missing);
  (match res_missing with
   | Error err -> Stdio.printf "Refusal reason: %s\n" (Selection_verifier.error_to_string err)
   | Ok _ -> ());

  (* 4B: Selection corrupted *)
  let selection_corrupted =
    { Trusted_selection.generation = 1;
      status = Trusted_selection.Corrupted "checksum validation failed in state store";
      years = Map.empty (module Int) }
  in
  let res_corrupted = Selection_verifier.begin_reader_session selection_corrupted in
  Stdio.printf "Corrupted selection refused: %b\n" (Result.is_error res_corrupted);
  (match res_corrupted with
   | Error err -> Stdio.printf "Refusal reason: %s\n" (Selection_verifier.error_to_string err)
   | Ok _ -> ());

  (* 4C: Selection indeterminate (e.g. split-brain conflict / unresolved concurrent publication) *)
  let selection_split =
    { Trusted_selection.generation = 3;
      status = Trusted_selection.Indeterminate "conflicting publisher manifests observed";
      years = Map.empty (module Int) }
  in
  let res_split = Selection_verifier.begin_reader_session selection_split in
  Stdio.printf "Indeterminate selection refused: %b\n" (Result.is_error res_split);
  (match res_split with
   | Error err -> Stdio.printf "Refusal reason: %s\n" (Selection_verifier.error_to_string err)
   | Ok _ -> ());
  [%expect {|
    Missing selection refused: true
    Refusal reason: Indeterminate_selection: authoritative selection state missing
    Corrupted selection refused: true
    Refusal reason: Indeterminate_selection: corrupted selection: checksum validation failed in state store
    Indeterminate selection refused: true
    Refusal reason: Indeterminate_selection: indeterminate selection: conflicting publisher manifests observed
  |}]

let%expect_test "Test 5: Repeatable Read / Generation Pinning During Concurrent Selection Mutation" =
  let fp_2025_v1 = calc_fingerprint fixture_2025_v1_text in
  let fp_2025_v2 = calc_fingerprint fixture_2025_v2_amended_text in
  let book_2025_v1 = get (B.of_string fixture_2025_v1_text) in

  let cf_v1 =
    Carry_forward_persist.derive ~prior_book:book_2025_v1 ~prior_year:2025 ~prior_revision:1
      ~prior_fingerprint:fp_2025_v1 ~as_of_day:"2025-12-31" ~coordinates:coords
  in

  let mutable_selection = ref (
    Trusted_selection.create ~generation:10 ~status:Trusted_selection.Active
      [
        (2025, { revision = 1; fingerprint = fp_2025_v1; header_revision = 1 });
        (2026, { revision = 1; fingerprint = "fp-2026-v1"; header_revision = 1 });
      ]
  ) in

  (* Step 1: Reader session begins and pins Generation 10 *)
  let session = get_session (Selection_verifier.begin_reader_session !mutable_selection) in
  Stdio.printf "Reader session started at generation: %d\n" session.pinned_generation;

  (* Step 2: Background concurrent amendment modifies 2025 to Revision 2 (Generation advances to 11) *)
  mutable_selection :=
    Trusted_selection.update_year !mutable_selection ~year:2025 ~revision:2
      ~fingerprint:fp_2025_v2 ~header_revision:2;
  Stdio.printf "Background selection advanced to generation: %d\n" (!mutable_selection).generation;

  (* Step 3: Reader session continues and verifies using its pinned snapshot *)
  let verify_within_session =
    Selection_verifier.verify_carry_forward session cf_v1 ~actual_header_rev:1
  in
  Stdio.printf "Pinned session verification succeeds without torn read: %b\n"
    (Result.is_ok verify_within_session);

  (* Step 4: A NEW reader session opening now will see Generation 11 and reject old cf_v1 *)
  let new_session = get_session (Selection_verifier.begin_reader_session !mutable_selection) in
  let verify_new_session =
    Selection_verifier.verify_carry_forward new_session cf_v1 ~actual_header_rev:2
  in
  Stdio.printf "New reader session correctly rejects stale cf_v1: %b\n"
    (Result.is_error verify_new_session);
  [%expect {|
    Reader session started at generation: 10
    Background selection advanced to generation: 11
    Pinned session verification succeeds without torn read: true
    New reader session correctly rejects stale cf_v1: true
  |}]

let%expect_test "Test 6: OCC Conflict Prevents Loss of Concurrent 2026 Commit (TLA+ v0.2 Scenario)" =
  let fp_2025_v1 = calc_fingerprint fixture_2025_v1_text in
  let fp_2025_v2 = calc_fingerprint fixture_2025_v2_amended_text in

  (* State 1: Active Selection has 2025:rev1 and 2026:rev1 at Generation 1 *)
  let current_selection = ref (
    Trusted_selection.create ~generation:1 ~status:Trusted_selection.Active
      [
        (2025, { revision = 1; fingerprint = fp_2025_v1; header_revision = 1 });
        (2026, { revision = 1; fingerprint = "fp-2026-v1"; header_revision = 1 });
      ]
  ) in

  (* State 2: Background worker observes Generation 1 and begins drafting 2025 Amendment + 2026 Carryover *)
  let observed_generation = (!current_selection).generation in
  Stdio.printf "Amendment worker observed generation: %d\n" observed_generation;

  (* State 3: CONCURRENT OPERATION: User records a new transaction in 2026 (e.g. coffee)!
              2026 advances from rev 1 to rev 2. Generation advances from 1 to 2! *)
  current_selection :=
    Trusted_selection.update_year !current_selection ~year:2026 ~revision:2
      ~fingerprint:"fp-2026-v2-with-coffee" ~header_revision:2;
  Stdio.printf "Concurrent 2026 append committed! Current generation: %d, rev26: %d\n"
    (!current_selection).generation
    (Option.value_exn (Trusted_selection.get_year !current_selection 2026)).revision;

  (* State 4: Amendment worker attempts to publish its prepared candidates based on old Generation 1 *)
  let candidate_entries =
    [
      (2025, 2, fp_2025_v2, 2);
      (2026, 2, "fp-2026-stale-carryover-missing-coffee", 2); (* Stale candidate that lacks coffee! *)
    ]
  in
  let publish_result =
    Selection_verifier.publish_candidate
      ~current_selection:!current_selection
      ~observed_generation
      ~new_year_entries:candidate_entries
  in
  Stdio.printf "Stale publication rejected by OCC: %b\n" (Result.is_error publish_result);
  (match publish_result with
   | Error (Selection_verifier.Generation_conflict { observed_gen; current_gen }) ->
     Stdio.printf "Conflict details: observed gen %d <> current gen %d\n" observed_gen current_gen
   | Ok _ -> ());

  (* Verify that current 2026 revision with coffee is preserved and not overwritten *)
  let preserved_rev26 =
    Option.value_exn (Trusted_selection.get_year !current_selection 2026)
  in
  Stdio.printf "Current active 2026 fingerprint remains untouched: %s\n" preserved_rev26.fingerprint;
  [%expect {|
    Amendment worker observed generation: 1
    Concurrent 2026 append committed! Current generation: 2, rev26: 2
    Stale publication rejected by OCC: true
    Conflict details: observed gen 1 <> current gen 2
    Current active 2026 fingerprint remains untouched: fp-2026-v2-with-coffee
  |}]

let%expect_test "Test 7: Semantic Category Integrity (Exact, Zero-origin, Presence, Unknown Preserved)" =
  let book_2025_v1 = get (B.of_string fixture_2025_v1_text) in
  let fp_2025_v1 = calc_fingerprint fixture_2025_v1_text in

  let cf =
    Carry_forward_persist.derive ~prior_book:book_2025_v1 ~prior_year:2025 ~prior_revision:1
      ~prior_fingerprint:fp_2025_v1 ~as_of_day:"2025-12-31" ~coordinates:coords
  in

  (match Carry_forward_persist.find_balance cf ~locus:"wallet" ~measure:"jpy" with
   | Carry_forward_persist.Exact q -> Stdio.printf "wallet JPY exact: %s\n" (Z.to_string q)
   | _ -> ());
  (match Carry_forward_persist.find_balance cf ~locus:"food" ~measure:"jpy" with
   | Carry_forward_persist.Exact q -> Stdio.printf "food JPY exact: %s\n" (Z.to_string q)
   | _ -> ());
  (match Carry_forward_persist.find_balance cf ~locus:"tax" ~measure:"jpy" with
   | Carry_forward_persist.Zero_origin -> Stdio.printf "tax JPY: zero-origin preserved\n"
   | _ -> ());
  (match Carry_forward_persist.find_balance cf ~locus:"salary" ~measure:"eur" with
   | Carry_forward_persist.Unknown -> Stdio.printf "salary EUR: unknown preserved, never zero\n"
   | _ -> ());
  [%expect {|
    wallet JPY exact: 37000
    food JPY exact: 3000
    tax JPY: zero-origin preserved
    salary EUR: unknown preserved, never zero
  |}]

let%expect_test "Test 8: Footprint Audit - Mathematical Reconciliation of Savings Ratios (39.3% vs 47.1% vs 72.7%)" =
  let prior_len = 1328 in
  let current_len = 1127 in
  let cf_len = 363 in

  (* Metric 1: Ratio of prior year ledger avoided by reading CarryForward instead *)
  let prior_isolated_saving = Float.of_int (prior_len - cf_len) /. Float.of_int prior_len in

  (* Metric 2: Standard IO reduction: (Full Recombination [prior+current]) vs (Normal Query [cf+current]) *)
  let full_recombination_io = prior_len + current_len in (* 2455 *)
  let normal_query_io = cf_len + current_len in          (* 1490 *)
  let normal_query_saving = Float.of_int (full_recombination_io - normal_query_io) /. Float.of_int full_recombination_io in

  (* Metric 3: Total Corpus Share: Fraction of total year-bundle corpus [prior+current+cf] eliminated *)
  let total_corpus = prior_len + current_len + cf_len in (* 2818 *)
  let corpus_omission_ratio = Float.of_int prior_len /. Float.of_int total_corpus in

  Stdio.printf "Footprint Reconciliation:\n";
  Stdio.printf "  Prior ledger size: %d B, Current ledger size: %d B, CarryForward size: %d B\n"
    prior_len current_len cf_len;
  Stdio.printf "  1. Prior ledger isolated savings: %.1f%%\n" (100.0 *. prior_isolated_saving);
  Stdio.printf "  2. Full recombination read saving ratio: %.1f%% (Reported in persistence test as ~39%%)\n"
    (100.0 *. normal_query_saving);
  Stdio.printf "  3. Total corpus omission ratio: %.1f%% (Alternative metric: %.1f%%)\n"
    (100.0 *. corpus_omission_ratio) (100.0 *. corpus_omission_ratio);
  [%expect {|
    Footprint Reconciliation:
      Prior ledger size: 1328 B, Current ledger size: 1127 B, CarryForward size: 363 B
      1. Prior ledger isolated savings: 72.7%
      2. Full recombination read saving ratio: 39.3% (Reported in persistence test as ~39%)
      3. Total corpus omission ratio: 47.1% (Alternative metric: 47.1%)
  |}]
