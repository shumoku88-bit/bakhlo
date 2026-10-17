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

let calc_fingerprint str =
  Stdlib.Digest.to_hex (Stdlib.Digest.string str)

(*******************************************************************************
  1. Trusted Selection Abstract Model (from Issue A contract)
*******************************************************************************)

module Trusted_selection = struct
  type revision_entry = {
    revision : int;
    fingerprint : string;
    header_revision : int;
  }

  type status =
    | Active
    | Missing
    | Corrupted of string
    | Indeterminate of string

  type t = {
    generation : int;
    status : status;
    years : revision_entry Map.M(Int).t;
  }

  let create ~generation ~status entries =
    let map =
      List.fold entries ~init:(Map.empty (module Int)) ~f:(fun acc (y, entry) ->
          Map.set acc ~key:y ~data:entry)
    in
    { generation; status; years = map }

  let update_year (t : t) ~year ~revision ~fingerprint ~header_revision =
    let new_entry = { revision; fingerprint; header_revision } in
    let new_years = Map.set t.years ~key:year ~data:new_entry in
    { t with generation = t.generation + 1; years = new_years }

  let get_year (t : t) year = Map.find t.years year
end

(*******************************************************************************
  2. Plan Link Model & S-expression Parsing (Issue B canonical candidate)
     (plan-discharges
       (discharge (plan <id>) (by <entry-id>))
     )
*******************************************************************************)

module Plan_link_model = struct
  type discharge = {
    plan_id : string;
    entry_id : string;
    discharge_year : int;
  }

  type parse_error =
    | Duplicate_plan_discharge of string
    | Malformed_discharge of string

  let discharge_error_to_string = function
    | Duplicate_plan_discharge pid -> Printf.sprintf "duplicate-plan-discharge: %s" pid
    | Malformed_discharge msg -> Printf.sprintf "malformed-discharge: %s" msg

  let extract_discharges ~(year : int) (sexp_items : Sexp.t list) :
      (discharge list, string) Result.t =
    let discharge_block =
      List.find_map sexp_items ~f:(function
        | Sexp.List (Sexp.Atom "plan-discharges" :: xs) -> Some xs
        | _ -> None)
    in
    match discharge_block with
    | None -> Ok []
    | Some xs ->
      let rec parse seen acc = function
        | [] -> Ok (List.rev acc)
        | Sexp.List [
            Sexp.Atom "discharge";
            Sexp.List [ Sexp.Atom "plan"; Sexp.Atom pid ];
            Sexp.List [ Sexp.Atom "by"; Sexp.Atom eid ];
          ] :: rest ->
          if Set.mem seen pid then
            Error (discharge_error_to_string (Duplicate_plan_discharge pid))
          else
            parse (Set.add seen pid)
              ({ plan_id = pid; entry_id = eid; discharge_year = year } :: acc)
              rest
        | _ :: _ -> Error (discharge_error_to_string (Malformed_discharge "expected (discharge (plan ...) (by ...))"))
      in
      parse (Set.empty (module String)) [] xs

  (* Parses a partition document: extracts discharges and returns canonical B.t for entries/plans/support *)
  let parse_partition_document ~(year : int) (text : string) : (B.t * discharge list, string) Result.t =
    try
      let items =
        match Parsexp.Many.parse_string text with
        | Ok xs -> xs
        | Error _ -> failwith "syntax error in partition document"
      in
      let discharges_res = extract_discharges ~year items in
      let non_discharge_items =
        List.filter items ~f:(function
          | Sexp.List (Sexp.Atom "plan-discharges" :: _) -> false
          | _ -> true)
      in
      let clean_text =
        List.map non_discharge_items ~f:Sexp.to_string
        |> String.concat ~sep:"\n"
      in
      match (discharges_res, B.of_string clean_text) with
      | (Ok discharges, Ok book) -> Ok (book, discharges)
      | (Error err, _) -> Error err
      | (_, Error err) -> Error err
    with Failure msg -> Error msg | exn -> Error (Exn.to_string exn)
end

(*******************************************************************************
  3. Plan State Projection (Ephemeral / Derived Cache Model)
     Maintains the derived lifecycle state across multiple calendar years
     WITHOUT serving as a secondary authority.
*******************************************************************************)

module Plan_state_projection = struct
  type plan_status =
    | Open
    | Paid of { entry_id : string; year : int }
    | Cancelled of string
    | Payment_reversed of { entry_id : string; reversal_id : string; year : int }
    | Conflicted of string

  type plan_entry = {
    plan : B.plan;
    origin_year : int;
    status : plan_status;
  }

  type t = {
    based_on_generation : int;
    plans : plan_entry Map.M(String).t;
  }

  let status_to_string = function
    | Open -> "open"
    | Paid { entry_id; year } -> Printf.sprintf "paid (by %s in %d)" entry_id year
    | Cancelled day -> Printf.sprintf "cancelled (on %s)" day
    | Payment_reversed { entry_id; reversal_id; year } ->
      Printf.sprintf "payment-reversed (entry %s reversed by %s in %d)" entry_id reversal_id year
    | Conflicted why -> Printf.sprintf "conflicted (%s)" why

  let build
      ~(generation : int)
      ~(all_year_books : (int * B.t) list)
      ~(all_discharges : Plan_link_model.discharge list) : t =
    (* Step 1: Collect original plans from creation years *)
    let initial_map =
      List.fold all_year_books ~init:(Map.empty (module String))
        ~f:(fun acc (year, book) ->
          List.fold (B.plans book) ~init:acc ~f:(fun m p ->
            let status =
              match p.cancelled_on with
              | Some d -> Cancelled d
              | None -> Open
            in
            Map.set m ~key:p.id ~data:{ plan = p; origin_year = year; status }))
    in
    (* Step 2: Apply discharges in chronological order *)
    let map_with_discharges =
      List.fold all_discharges ~init:initial_map ~f:(fun acc d ->
        match Map.find acc d.plan_id with
        | None ->
          (* Plan not found in any prior/current book *)
          Map.set acc ~key:d.plan_id
            ~data:{
              plan = { id = d.plan_id; day = ""; measure = ""; changes = []; paid_by = None; cancelled_on = None };
              origin_year = d.discharge_year;
              status = Conflicted "unresolved-plan-origin";
            }
        | Some existing ->
          let updated_status =
            match existing.status with
            | Open -> Paid { entry_id = d.entry_id; year = d.discharge_year }
            | Paid prev ->
              Conflicted (Printf.sprintf "duplicate-discharge (already paid by %s in %d, attempted %s in %d)"
                            prev.entry_id prev.year d.entry_id d.discharge_year)
            | Cancelled cday ->
              Conflicted (Printf.sprintf "discharge-of-cancelled-plan (cancelled %s, attempted pay by %s)"
                            cday d.entry_id)
            | Payment_reversed _ ->
              Conflicted "discharge-of-reversed-plan"
            | Conflicted err -> Conflicted err
          in
          Map.set acc ~key:d.plan_id ~data:{ existing with status = updated_status })
    in
    (* Step 3: Check reversals affecting paying entries *)
    let all_entries =
      List.concat_map all_year_books ~f:(fun (y, b) ->
        List.map (B.entries b) ~f:(fun e -> (y, e)))
    in
    let reversal_map =
      List.filter_map all_entries ~f:(fun (y, e) ->
        match e.reversal_of with
        | Some target -> Some (target, (e.id, y))
        | None -> None)
      |> Map.of_alist_exn (module String)
    in
    let final_map =
      Map.map map_with_discharges ~f:(fun entry ->
        match entry.status with
        | Paid { entry_id; year = _ } ->
          (match Map.find reversal_map entry_id with
           | Some (reversal_id, rev_year) ->
             { entry with status = Payment_reversed { entry_id; reversal_id; year = rev_year } }
           | None -> entry)
        | _ -> entry)
    in
    { based_on_generation = generation; plans = final_map }

  let verify_freshness (t : t) ~(current_selection : Trusted_selection.t) : (unit, string) Result.t =
    if t.based_on_generation <> current_selection.generation then
      Error (Printf.sprintf "Stale_projection: projection generation %d <> current selection generation %d"
               t.based_on_generation current_selection.generation)
    else
      Ok ()
end

(*******************************************************************************
  4. Cross-Year Plan Verifier & Ephemeral Synthesis Engine
     Enforces uniqueness, non-fabrication, and OCC validation for cross-year plans.
*******************************************************************************)

module Cross_year_plan_verifier = struct
  type verification_error =
    | Unresolved_plan of { plan_id : string; year : int }
    | Plan_already_closed of { plan_id : string; closed_by : string; closed_year : int }
    | Plan_already_cancelled of { plan_id : string; cancelled_on : string }
    | Unresolved_paying_entry of { entry_id : string; plan_id : string }
    | Payment_reversal_conflict of { plan_id : string; paying_entry : string; reversal_entry : string }
    | Duplicate_discharge_within_year of string
    | Stale_prior_year of { year : int; expected_rev : int; actual_rev : int }
    | Generation_conflict of { observed_gen : int; current_gen : int }
    | Core_admission_failure of string

  let error_to_string = function
    | Unresolved_plan { plan_id; year } ->
      Printf.sprintf "Unresolved_plan: plan %s not found in authoritative year %d" plan_id year
    | Plan_already_closed { plan_id; closed_by; closed_year } ->
      Printf.sprintf "Plan_already_closed: plan %s already discharged by %s in %d" plan_id closed_by closed_year
    | Plan_already_cancelled { plan_id; cancelled_on } ->
      Printf.sprintf "Plan_already_cancelled: plan %s was cancelled on %s" plan_id cancelled_on
    | Unresolved_paying_entry { entry_id; plan_id } ->
      Printf.sprintf "Unresolved_paying_entry: entry %s paying plan %s does not exist" entry_id plan_id
    | Payment_reversal_conflict { plan_id; paying_entry; reversal_entry } ->
      Printf.sprintf "Payment_reversal_conflict: plan %s paying entry %s was reversed by %s without explicit discharge revocation"
        plan_id paying_entry reversal_entry
    | Duplicate_discharge_within_year pid ->
      Printf.sprintf "Duplicate_discharge_within_year: %s" pid
    | Stale_prior_year { year; expected_rev; actual_rev } ->
      Printf.sprintf "Stale_prior_year: year %d expected rev %d, active rev %d" year expected_rev actual_rev
    | Generation_conflict { observed_gen; current_gen } ->
      Printf.sprintf "Generation_conflict: observed generation %d <> current generation %d" observed_gen current_gen
    | Core_admission_failure why ->
      Printf.sprintf "Core_admission_failure: %s" why

  (* Verifies a new candidate discharge against historical facts *)
  let verify_candidate_discharge
      ~(candidate_discharge : Plan_link_model.discharge)
      ~(candidate_year_entries : B.entry list)
      ~(all_historical_books : (int * B.t) list)
      ~(all_historical_discharges : Plan_link_model.discharge list) :
      (unit, verification_error) Result.t =
    let pid = candidate_discharge.plan_id in
    let eid = candidate_discharge.entry_id in

    (* 1. Validate paying entry exists in the candidate year *)
    let candidate_entry_ids = List.map candidate_year_entries ~f:(fun e -> e.id) in
    if not (List.mem candidate_entry_ids eid ~equal:String.equal) then
      Error (Unresolved_paying_entry { entry_id = eid; plan_id = pid })
    else
      (* 2. Find plan definition in historical books or candidate year *)
      let found_plan_opt =
        List.find_map all_historical_books ~f:(fun (y, book) ->
            List.find (B.plans book) ~f:(fun p -> String.equal p.id pid)
            |> Option.map ~f:(fun p -> (y, p)))
      in
      match found_plan_opt with
      | None -> Error (Unresolved_plan { plan_id = pid; year = candidate_discharge.discharge_year })
      | Some (_origin_year, orig_plan) ->
        (* 3. Check if plan was already cancelled *)
        (match orig_plan.cancelled_on with
         | Some cday -> Error (Plan_already_cancelled { plan_id = pid; cancelled_on = cday })
         | None ->
           (* 4. Check if plan was ALREADY discharged in historical discharges *)
           let prior_discharge =
             List.find all_historical_discharges ~f:(fun d ->
                 String.equal d.plan_id pid &&
                 not (String.equal d.entry_id eid && d.discharge_year = candidate_discharge.discharge_year))
           in
           (match prior_discharge with
            | Some d_prev ->
              Error (Plan_already_closed {
                plan_id = pid;
                closed_by = d_prev.entry_id;
                closed_year = d_prev.discharge_year;
              })
            | None ->
              (* 5. Check if the paying entry itself has been reversed in historical entries *)
              let all_reversals =
                List.concat_map all_historical_books ~f:(fun (_y, b) ->
                    List.filter_map (B.entries b) ~f:(fun e ->
                        Option.map e.reversal_of ~f:(fun target -> (target, e.id))))
              in
              match List.Assoc.find all_reversals eid ~equal:String.equal with
              | Some rev_id ->
                Error (Payment_reversal_conflict {
                  plan_id = pid;
                  paying_entry = eid;
                  reversal_entry = rev_id;
                })
              | None -> Ok ()))

  (* Ephemeral synthesizer: merges retained plans with active paid_by annotations *)
  let synthesize_ephemeral_ledger
      ~(retained_plans : B.plan list)
      ~(current_entries : B.entry list)
      ~(current_plans : B.plan list) : (B.t, string) Result.t =
    let all_plans = retained_plans @ current_plans in
    let entries_sexp_str =
      List.map current_entries ~f:(fun e ->
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
          let exch_str = match e.exchange with Some (k1, k2) -> Printf.sprintf "(keys %s %s)" k1 k2 | None -> "(none)" in
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
    let text =
      Printf.sprintf
        "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
         (measures (measure jpy 0))\n\
         (labels (provided (label wallet 財布 現金) (label rent 家賃 口座)))\n\
         (approved-loci (provided wallet rent))\n\
         (entries\n%s\n)\n\
         (plans\n%s\n)\n\
         (support\n\
           (zero-origin (rent jpy))\n\
           (openings)\n\
           (observations)\n\
           (presence (not-supplied))\n\
         )\n"
        entries_sexp_str
        plans_sexp_str
    in
    B.of_string text

  (* OCC Publishing Protocol *)
  let publish_candidate
      ~(current_selection : Trusted_selection.t)
      ~(observed_generation : int)
      ~(new_year_entries : (int * int * string * int) list) :
      (Trusted_selection.t, verification_error) Result.t =
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

let get_selection = function
  | Ok s -> s
  | Error err -> failwith (Cross_year_plan_verifier.error_to_string err)

(*******************************************************************************
  5. Synthetic Document Fixtures for 2025, 2026, 2027
*******************************************************************************)

let fixture_2025_v1_text =
  "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
   (measures (measure jpy 0))\n\
   (labels (provided (label wallet 財布 現金) (label rent 家賃 口座)))\n\
   (approved-loci (provided wallet rent))\n\
   (entries\n\
     (entry e_2025_seed (date 2025-01-05) (memo (some initial))\n\
       (postings (posting wallet jpy 100000 (none)) (posting rent jpy -100000 (none)))\n\
       (reversal-of (none))\n\
       (exchange (none)))\n\
   )\n\
   (plans\n\
     (plan p_2025_rent (date 2026-02-15) (measure jpy)\n\
       (changes (wallet -12000) (rent 12000))\n\
       (paid-by (none))\n\
       (cancelled-on (none)))\n\
   )\n\
   (support\n\
     (zero-origin (rent jpy))\n\
     (openings)\n\
     (observations)\n\
     (presence (not-supplied))\n\
   )\n"

(* 2025 v2 amended: The plan p_2025_rent was cancelled on 2025-12-01 *)
let fixture_2025_v2_cancelled_text =
  String.substr_replace_all fixture_2025_v1_text
    ~pattern:"(cancelled-on (none))"
    ~with_:"(cancelled-on (some 2025-12-01))"

(* 2026 v1 partition: records e_2026_pay_rent and discharges p_2025_rent *)
let fixture_2026_v1_text =
  "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
   (measures (measure jpy 0))\n\
   (labels (provided (label wallet 財布 現金) (label rent 家賃 口座)))\n\
   (approved-loci (provided wallet rent))\n\
   (entries\n\
     (entry e_2026_pay_rent (date 2026-02-15) (memo (some paid-feb-rent))\n\
       (postings (posting wallet jpy -12000 (none)) (posting rent jpy 12000 (none)))\n\
       (reversal-of (none))\n\
       (exchange (none)))\n\
   )\n\
   (plans)\n\
   (plan-discharges\n\
     (discharge (plan p_2025_rent) (by e_2026_pay_rent))\n\
   )\n\
   (support\n\
     (zero-origin (rent jpy))\n\
     (openings)\n\
     (observations)\n\
     (presence (not-supplied))\n\
   )\n"

(* 2026 v2 amended: e_2026_pay_rent was deleted, leaving orphaned discharge *)
let fixture_2026_v2_deleted_payment_text =
  "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
   (measures (measure jpy 0))\n\
   (labels (provided (label wallet 財布 現金) (label rent 家賃 口座)))\n\
   (approved-loci (provided wallet rent))\n\
   (entries)\n\
   (plans)\n\
   (plan-discharges\n\
     (discharge (plan p_2025_rent) (by e_2026_pay_rent))\n\
   )\n\
   (support\n\
     (zero-origin (rent jpy))\n\
     (openings)\n\
     (observations)\n\
     (presence (not-supplied))\n\
   )\n"

(* 2027 v1 partition: Attempted duplicate payment of p_2025_rent *)
let fixture_2027_v1_duplicate_payment_text =
  "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
   (measures (measure jpy 0))\n\
   (labels (provided (label wallet 財布 現金) (label rent 家賃 口座)))\n\
   (approved-loci (provided wallet rent))\n\
   (entries\n\
     (entry e_2027_dup_pay (date 2027-01-15) (memo (some duplicate-rent))\n\
       (postings (posting wallet jpy -12000 (none)) (posting rent jpy 12000 (none)))\n\
       (reversal-of (none))\n\
       (exchange (none)))\n\
   )\n\
   (plans)\n\
   (plan-discharges\n\
     (discharge (plan p_2025_rent) (by e_2027_dup_pay))\n\
   )\n\
   (support\n\
     (zero-origin (rent jpy))\n\
     (openings)\n\
     (observations)\n\
     (presence (not-supplied))\n\
   )\n"

(* 2027 v1 reversal partition: Reversal of 2026 rent payment with retained reference closure *)
let fixture_2027_v1_reversal_text =
  "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
   (measures (measure jpy 0))\n\
   (labels (provided (label wallet 財布 現金) (label rent 家賃 口座)))\n\
   (approved-loci (provided wallet rent))\n\
   (entries\n\
     (entry e_2026_pay_rent (date 2026-02-15) (memo (some retained-for-reversal))\n\
       (postings (posting wallet jpy -12000 (none)) (posting rent jpy 12000 (none)))\n\
       (reversal-of (none))\n\
       (exchange (none)))\n\
     (entry e_2027_reversal (date 2027-01-20) (memo (some refund-rent))\n\
       (postings (posting wallet jpy 12000 (none)) (posting rent jpy -12000 (none)))\n\
       (reversal-of (some e_2026_pay_rent))\n\
       (exchange (none)))\n\
   )\n\
   (plans)\n\
   (plan-discharges)\n\
   (support\n\
     (zero-origin (rent jpy))\n\
     (openings)\n\
     (observations)\n\
     (presence (not-supplied))\n\
   )\n"

(*******************************************************************************
  6. Synthetic Test Suite (Cases A to H)
*******************************************************************************)

let%expect_test "Case A: Normal Cross-Year Payment (2025 Plan Discharged in 2026)" =
  let book_2025 = get (B.of_string fixture_2025_v1_text) in
  let (book_2026, discharges_2026) =
    get (Plan_link_model.parse_partition_document ~year:2026 fixture_2026_v1_text)
  in

  (* Validate the discharge *)
  let d = List.hd_exn discharges_2026 in
  let verify_res =
    Cross_year_plan_verifier.verify_candidate_discharge
      ~candidate_discharge:d
      ~candidate_year_entries:(B.entries book_2026)
      ~all_historical_books:[ (2025, book_2025) ]
      ~all_historical_discharges:[]
  in
  Stdio.printf "Discharge verification result: %b\n" (Result.is_ok verify_res);

  (* Synthesize ephemeral ledger to verify Core admission *)
  let orig_plan = Option.value_exn (List.find (B.plans book_2025) ~f:(fun p -> String.equal p.id d.plan_id)) in
  let discharged_plan = { orig_plan with paid_by = Some d.entry_id } in
  let ephemeral_ledger =
    get (Cross_year_plan_verifier.synthesize_ephemeral_ledger
           ~retained_plans:[ discharged_plan ]
           ~current_entries:(B.entries book_2026)
           ~current_plans:[])
  in
  let synth_plan = Option.value_exn (List.find (B.plans ephemeral_ledger) ~f:(fun p -> String.equal p.id "p_2025_rent")) in
  Stdio.printf "Core plan_is_open in synthesized ledger: %b\n" (B.plan_is_open synth_plan);
  Stdio.printf "Plan paid_by: %s\n" (Option.value ~default:"none" synth_plan.paid_by);
  Stdio.printf "Original 2025 canonical plan modified: %b\n" (Option.is_some orig_plan.paid_by);
  [%expect {|
    Discharge verification result: true
    Core plan_is_open in synthesized ledger: false
    Plan paid_by: e_2026_pay_rent
    Original 2025 canonical plan modified: false
  |}]

let%expect_test "Case B: Serial Duplicate Payment in Following Year Rejected (OCC Alone Insufficient)" =
  let book_2025 = get (B.of_string fixture_2025_v1_text) in
  let (book_2026, discharges_2026) =
    get (Plan_link_model.parse_partition_document ~year:2026 fixture_2026_v1_text)
  in
  let (book_2027, discharges_2027) =
    get (Plan_link_model.parse_partition_document ~year:2027 fixture_2027_v1_duplicate_payment_text)
  in

  (* Setup authoritative selection: 2026 commit has succeeded and advanced generation to 2 *)
  let selection_gen2 =
    Trusted_selection.create ~generation:2 ~status:Trusted_selection.Active
      [
        (2025, { revision = 1; fingerprint = calc_fingerprint fixture_2025_v1_text; header_revision = 1 });
        (2026, { revision = 1; fingerprint = calc_fingerprint fixture_2026_v1_text; header_revision = 1 });
      ]
  in

  (* Crucial observation: When a user starts editing 2027 serially, they observe generation 2.
     Therefore, OCC check at publish time WOULD PASS if only checking generations! *)
  let observed_gen = selection_gen2.generation in
  let occ_pass_check =
    Cross_year_plan_verifier.publish_candidate
      ~current_selection:selection_gen2
      ~observed_generation:observed_gen
      ~new_year_entries:[ (2027, 1, calc_fingerprint fixture_2027_v1_duplicate_payment_text, 1) ]
  in
  Stdio.printf "OCC check alone passes on serial operation: %b\n" (Result.is_ok occ_pass_check);

  (* But semantic cross-year plan verification must REJECT because 2026 already discharged it! *)
  let d_2027 = List.hd_exn discharges_2027 in
  let verify_res =
    Cross_year_plan_verifier.verify_candidate_discharge
      ~candidate_discharge:d_2027
      ~candidate_year_entries:(B.entries book_2027)
      ~all_historical_books:[ (2025, book_2025); (2026, book_2026) ]
      ~all_historical_discharges:discharges_2026
  in
  Stdio.printf "Cross-year duplicate discharge rejected: %b\n" (Result.is_error verify_res);
  (match verify_res with
   | Error err -> Stdio.printf "Refusal reason: %s\n" (Cross_year_plan_verifier.error_to_string err)
   | Ok _ -> ());
  [%expect {|
    OCC check alone passes on serial operation: true
    Cross-year duplicate discharge rejected: true
    Refusal reason: Plan_already_closed: plan p_2025_rent already discharged by e_2026_pay_rent in 2026
  |}]

let%expect_test "Case C: Concurrent Duplicate Discharge Blocked by OCC" =
  let fp_2025 = calc_fingerprint fixture_2025_v1_text in
  let fp_2026 = calc_fingerprint fixture_2026_v1_text in

  (* State 1: Active selection generation 1 *)
  let current_selection = ref (
    Trusted_selection.create ~generation:1 ~status:Trusted_selection.Active
      [
        (2025, { revision = 1; fingerprint = fp_2025; header_revision = 1 });
      ]
  ) in

  (* Worker 1 and Worker 2 both observe generation 1 with p_2025_rent open *)
  let worker1_observed_gen = (!current_selection).generation in
  let worker2_observed_gen = (!current_selection).generation in

  (* Worker 1 publishes 2026 discharge first *)
  let publish1 =
    Cross_year_plan_verifier.publish_candidate
      ~current_selection:!current_selection
      ~observed_generation:worker1_observed_gen
      ~new_year_entries:[ (2026, 1, fp_2026, 1) ]
  in
  current_selection := get_selection publish1;
  Stdio.printf "Worker 1 publish succeeded, generation advanced to: %d\n" (!current_selection).generation;

  (* Worker 2 attempts to publish concurrent discharge based on observed generation 1 *)
  let publish2 =
    Cross_year_plan_verifier.publish_candidate
      ~current_selection:!current_selection
      ~observed_generation:worker2_observed_gen
      ~new_year_entries:[ (2026, 2, "fp-worker2-conflict", 2) ]
  in
  Stdio.printf "Worker 2 concurrent publish rejected: %b\n" (Result.is_error publish2);
  (match publish2 with
   | Error err -> Stdio.printf "Refusal reason: %s\n" (Cross_year_plan_verifier.error_to_string err)
   | Ok _ -> ());
  [%expect {|
    Worker 1 publish succeeded, generation advanced to: 2
    Worker 2 concurrent publish rejected: true
    Refusal reason: Generation_conflict: observed generation 1 <> current generation 2
  |}]

let%expect_test "Case D: Payment Entry Reversal Semantics (Accounting & Explicit Reconciliation)" =
  let book_2025 = get (B.of_string fixture_2025_v1_text) in
  let (book_2026, discharges_2026) =
    get (Plan_link_model.parse_partition_document ~year:2026 fixture_2026_v1_text)
  in
  let (book_2027, _discharges_2027) =
    get (Plan_link_model.parse_partition_document ~year:2027 fixture_2027_v1_reversal_text)
  in

  (* Build plan state projection over 2025, 2026, and 2027 *)
  let projection =
    Plan_state_projection.build
      ~generation:3
      ~all_year_books:[ (2025, book_2025); (2026, book_2026); (2027, book_2027) ]
      ~all_discharges:discharges_2026
  in
  let plan_entry = Option.value_exn (Map.find projection.plans "p_2025_rent") in
  Stdio.printf "Plan p_2025_rent status after payment reversal: %s\n"
    (Plan_state_projection.status_to_string plan_entry.status);

  (* Verify that without explicit revocation, candidate re-payment is blocked *)
  let candidate_d = { Plan_link_model.plan_id = "p_2025_rent"; entry_id = "e_2027_new_pay"; discharge_year = 2027 } in
  let fake_entry = { B.id = "e_2027_new_pay"; day = "2027-02-01"; memo = None; effects = []; reversal_of = None; exchange = None; original_amount = None } in
  let verify_res =
    Cross_year_plan_verifier.verify_candidate_discharge
      ~candidate_discharge:candidate_d
      ~candidate_year_entries:[ fake_entry ]
      ~all_historical_books:[ (2025, book_2025); (2026, book_2026); (2027, book_2027) ]
      ~all_historical_discharges:discharges_2026
  in
  Stdio.printf "Re-discharge without explicit resolution rejected: %b\n" (Result.is_error verify_res);
  (match verify_res with
   | Error err -> Stdio.printf "Refusal reason: %s\n" (Cross_year_plan_verifier.error_to_string err)
   | Ok _ -> ());
  [%expect {|
    Plan p_2025_rent status after payment reversal: payment-reversed (entry e_2026_pay_rent reversed by e_2027_reversal in 2027)
    Re-discharge without explicit resolution rejected: true
    Refusal reason: Plan_already_closed: plan p_2025_rent already discharged by e_2026_pay_rent in 2026
  |}]

let%expect_test "Case E: Payment Entry Correction & Deletion (Missing Paying Entry Fails Closed)" =
  let book_2025 = get (B.of_string fixture_2025_v1_text) in
  let (book_2026_bad, discharges_2026) =
    get (Plan_link_model.parse_partition_document ~year:2026 fixture_2026_v2_deleted_payment_text)
  in
  let d = List.hd_exn discharges_2026 in

  (* Candidate verification fails because paying entry e_2026_pay_rent was deleted *)
  let verify_res =
    Cross_year_plan_verifier.verify_candidate_discharge
      ~candidate_discharge:d
      ~candidate_year_entries:(B.entries book_2026_bad)
      ~all_historical_books:[ (2025, book_2025) ]
      ~all_historical_discharges:[]
  in
  Stdio.printf "Deleted paying entry rejected: %b\n" (Result.is_error verify_res);
  (match verify_res with
   | Error err -> Stdio.printf "Refusal reason: %s\n" (Cross_year_plan_verifier.error_to_string err)
   | Ok _ -> ());
  [%expect {|
    Deleted paying entry rejected: true
    Refusal reason: Unresolved_paying_entry: entry e_2026_pay_rent paying plan p_2025_rent does not exist
  |}]

let%expect_test "Case F: Prior Year Plan Cancellation / Amendment Invalidates Downstream Discharge" =
  let book_2025_cancelled = get (B.of_string fixture_2025_v2_cancelled_text) in
  let (book_2026, discharges_2026) =
    get (Plan_link_model.parse_partition_document ~year:2026 fixture_2026_v1_text)
  in
  let d = List.hd_exn discharges_2026 in

  (* Verifying 2026 discharge against amended 2025 where plan was cancelled *)
  let verify_res =
    Cross_year_plan_verifier.verify_candidate_discharge
      ~candidate_discharge:d
      ~candidate_year_entries:(B.entries book_2026)
      ~all_historical_books:[ (2025, book_2025_cancelled) ]
      ~all_historical_discharges:[]
  in
  Stdio.printf "Discharge of cancelled plan rejected: %b\n" (Result.is_error verify_res);
  (match verify_res with
   | Error err -> Stdio.printf "Refusal reason: %s\n" (Cross_year_plan_verifier.error_to_string err)
   | Ok _ -> ());
  [%expect {|
    Discharge of cancelled plan rejected: true
    Refusal reason: Plan_already_cancelled: plan p_2025_rent was cancelled on 2025-12-01
  |}]

let%expect_test "Case G: Cold Start End-to-End Reconstruction from Raw Synthetic S-Expressions" =
  (* Discard all in-memory structures and parse purely from raw text *)
  let book_2025 = get (B.of_string fixture_2025_v1_text) in
  let (book_2026, discharges_2026) =
    get (Plan_link_model.parse_partition_document ~year:2026 fixture_2026_v1_text)
  in
  let (book_2027, discharges_2027) =
    get (Plan_link_model.parse_partition_document ~year:2027 fixture_2027_v1_duplicate_payment_text)
  in

  (* Cold-start reconstruct projection *)
  let cold_projection =
    Plan_state_projection.build
      ~generation:1
      ~all_year_books:[ (2025, book_2025); (2026, book_2026) ]
      ~all_discharges:discharges_2026
  in
  let plan_cold = Option.value_exn (Map.find cold_projection.plans "p_2025_rent") in
  Stdio.printf "Cold start reconstructed status: %s\n"
    (Plan_state_projection.status_to_string plan_cold.status);

  (* Cold-start verify 2027 duplicate payment *)
  let d_2027 = List.hd_exn discharges_2027 in
  let verify_cold_dup =
    Cross_year_plan_verifier.verify_candidate_discharge
      ~candidate_discharge:d_2027
      ~candidate_year_entries:(B.entries book_2027)
      ~all_historical_books:[ (2025, book_2025); (2026, book_2026) ]
      ~all_historical_discharges:discharges_2026
  in
  Stdio.printf "Cold start duplicate rejection: %b\n" (Result.is_error verify_cold_dup);
  (match verify_cold_dup with
   | Error err -> Stdio.printf "Cold refusal reason: %s\n" (Cross_year_plan_verifier.error_to_string err)
   | Ok _ -> ());
  [%expect {|
    Cold start reconstructed status: paid (by e_2026_pay_rent in 2026)
    Cold start duplicate rejection: true
    Cold refusal reason: Plan_already_closed: plan p_2025_rent already discharged by e_2026_pay_rent in 2026
  |}]

let%expect_test "Case H: Detection and Rejection of Stale Plan State Projection Cache" =
  let book_2025 = get (B.of_string fixture_2025_v1_text) in
  let (book_2026, discharges_2026) =
    get (Plan_link_model.parse_partition_document ~year:2026 fixture_2026_v1_text)
  in

  (* Projection built based on generation 10 *)
  let projection =
    Plan_state_projection.build
      ~generation:10
      ~all_year_books:[ (2025, book_2025); (2026, book_2026) ]
      ~all_discharges:discharges_2026
  in

  (* Trusted selection has advanced to generation 11 due to a concurrent 2025 amendment *)
  let selection_gen11 =
    Trusted_selection.create ~generation:11 ~status:Trusted_selection.Active
      [
        (2025, { revision = 2; fingerprint = calc_fingerprint fixture_2025_v2_cancelled_text; header_revision = 2 });
        (2026, { revision = 1; fingerprint = calc_fingerprint fixture_2026_v1_text; header_revision = 1 });
      ]
  in

  (* Freshness verification rejects stale projection *)
  let freshness_check =
    Plan_state_projection.verify_freshness projection ~current_selection:selection_gen11
  in
  Stdio.printf "Stale projection rejected: %b\n" (Result.is_error freshness_check);
  (match freshness_check with
   | Error msg -> Stdio.printf "Freshness failure: %s\n" msg
   | Ok _ -> ());
  [%expect {|
    Stale projection rejected: true
    Freshness failure: Stale_projection: projection generation 10 <> current selection generation 11
  |}]
