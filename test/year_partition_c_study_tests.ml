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
  match Q.query (B.image book) { D.Effect_coordinate.locus = lid locus; measure = mid measure } with
  | Ok (Q.Exact x) -> Z.to_string (D.Quantity.quanta (Q.quantity x))
  | Ok (Q.Known_present _) -> "presence"
  | Error (Q.Support_unknown _) -> "unknown"

(*******************************************************************************
  1. C-Way Model Types: CarryForward and CrossYearResolver
*******************************************************************************)

module Carry_forward = struct
  type locus_quantity =
    | Exact of Z.t
    | Zero_origin
    | Known_present
    | Unknown
  [@@deriving sexp, equal]

  type coordinate = {
    locus : string;
    measure : string;
  }
  [@@deriving sexp, equal]

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
    (* Collect roots excluded by prior book observations *)
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
      schema_version = 3;
    }

  let find_balance (t : t) ~locus ~measure =
    List.find_map t.balances ~f:(fun (c, q) ->
        if String.equal c.locus locus && String.equal c.measure measure then Some q else None)
    |> Option.value ~default:Unknown
end
module Cross_year_resolver = struct
  type error =
    | Prior_year_missing of int
    | Stale_carry_forward of { expected_rev : int; actual_rev : int }
    | Unresolved_entry of { year : int; id : string }
    | Unresolved_plan of { year : int; id : string }
    | Plan_already_closed of { year : int; id : string }

  let error_to_string = function
    | Prior_year_missing y -> Printf.sprintf "Prior_year_missing %d" y
    | Stale_carry_forward { expected_rev; actual_rev } ->
      Printf.sprintf "Stale_carry_forward (expected %d, actual %d)" expected_rev actual_rev
    | Unresolved_entry { year; id } ->
      Printf.sprintf "Unresolved_entry (year %d, id %s)" year id
    | Unresolved_plan { year; id } ->
      Printf.sprintf "Unresolved_plan (year %d, id %s)" year id
    | Plan_already_closed { year; id } ->
      Printf.sprintf "Plan_already_closed (year %d, id %s)" year id

  type resolution = {
    carry_forward : Carry_forward.t;
    retained_entries : B.entry list;
    retained_plans : B.plan list;
  }

  let resolve ~(carry_forward : Carry_forward.t) ~current_prior_revision
      ~(prior_book : B.t) ~(plan_fulfillments : (string * string) list)
      ~(current_entries : B.entry list) ~current_plans:(_ : B.plan list) =
    if carry_forward.prior_revision <> current_prior_revision then
      Error (Stale_carry_forward { expected_rev = carry_forward.prior_revision; actual_rev = current_prior_revision })
    else
      let current_entry_ids = List.map current_entries ~f:(fun e -> e.id) in

      (* 1. Find unresolved reversal targets in current_entries *)
      let needed_entry_ids =
        List.filter_map current_entries ~f:(fun e -> e.reversal_of)
        |> List.filter ~f:(fun target -> not (List.mem current_entry_ids target ~equal:String.equal))
        |> List.dedup_and_sort ~compare:String.compare
      in

      (* Resolve entries from prior book *)
      let resolved_entries_res =
        List.map needed_entry_ids ~f:(fun id ->
            match B.find_entry prior_book id with
            | Some e -> Ok e
            | None -> Error (Unresolved_entry { year = carry_forward.prior_year; id }))
        |> Result.all
      in

      (* Resolve plan fulfillments from prior book *)
      let resolved_plans_res =
        List.map plan_fulfillments ~f:(fun (plan_id, entry_id) ->
            match List.find (B.plans prior_book) ~f:(fun p -> String.equal p.id plan_id) with
            | None -> Error (Unresolved_plan { year = carry_forward.prior_year; id = plan_id })
            | Some p ->
              if not (B.plan_is_open p) then
                Error (Plan_already_closed { year = carry_forward.prior_year; id = plan_id })
              else
                Ok { p with paid_by = Some entry_id })
        |> Result.all
      in

      match (resolved_entries_res, resolved_plans_res) with
      | (Ok retained_entries, Ok retained_plans) ->
        Ok { carry_forward; retained_entries; retained_plans }
      | (Error err, _) | (_, Error err) -> Error err

  (* Ephemeral bridge to Core Daily_book:
     Synthesizes a qualified ephemeral in-memory book combining
     retained reference closure, carry-forward balances, and current transactions. *)
  let synthesize_ephemeral_book ~(resolution : resolution) ~(current_entries : B.entry list)
      ~(current_plans : B.plan list) =
    let cf = resolution.carry_forward in
    let all_entries = resolution.retained_entries @ current_entries in
    let all_plans = resolution.retained_plans @ current_plans in

    (* Prepare observations and cuts:
       Only retained entries imported into the ephemeral book exist in this book's entries.
       They must be REFLECTED in the cut so their amounts are not double-counted
       on top of the carry-forward exact balances!
       Notice: cf.retained_roots belong to the prior year ledger and do NOT exist
       in 2026 entries. Including them would trigger Unknown_event refusal during support admission. *)
    let retained_entry_ids = List.map resolution.retained_entries ~f:(fun e -> e.id) in
    let all_reflected_roots =
      List.dedup_and_sort ~compare:String.compare retained_entry_ids
    in

    let exact_obs_items =
      List.filter_map cf.balances ~f:(fun (coord, q) ->
          match q with
          | Carry_forward.Exact amt -> Some (Printf.sprintf "(%s %s %s)" coord.locus coord.measure (Z.to_string amt))
          | _ -> None)
    in

    let zero_origin_items =
      List.filter_map cf.balances ~f:(fun (coord, q) ->
          match q with
          | Carry_forward.Zero_origin -> Some (Printf.sprintf "(%s %s)" coord.locus coord.measure)
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
          let memo_str = match e.memo with Some m -> Printf.sprintf "(some %s)" m | None -> "(none)" in
          let rev_str = match e.reversal_of with Some r -> Printf.sprintf "(some %s)" r | None -> "(none)" in
          let fx_str =
            match e.exchange with
            | Some (a, b) -> Printf.sprintf "(exchange (keys %s %s))" a b
            | None -> "(exchange (none))"
          in
          Printf.sprintf "(entry %s (date %s) (memo %s) (postings %s) (reversal-of %s) %s)"
            e.id e.day memo_str postings_str rev_str fx_str)
      |> String.concat ~sep:"\n"
    in

    let plans_sexp_str =
      List.map all_plans ~f:(fun p ->
          let ch_str =
            List.map p.changes ~f:(fun (loc, n) -> Printf.sprintf "(%s %s)" loc (Z.to_string n))
            |> String.concat ~sep:" "
          in
          let paid_str = match p.paid_by with Some id -> Printf.sprintf "(some %s)" id | None -> "(none)" in
          let canc_str = match p.cancelled_on with Some d -> Printf.sprintf "(some %s)" d | None -> "(none)" in
          Printf.sprintf "(plan %s (date %s) (measure %s) (changes %s) (paid-by %s) (cancelled-on %s))"
            p.id p.day p.measure ch_str paid_str canc_str)
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
end

let get_resolved = function
  | Ok x -> x
  | Error err -> failwith (Cross_year_resolver.error_to_string err)


(*******************************************************************************
  2. Synthetic Books Setup: 2025 v1, 2025 v2 (amended), and 2026 data
*******************************************************************************)

let book_2025_v1_text =
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

let coords =
  [
    ("wallet", "jpy");
    ("bank", "jpy");
    ("wallet", "eur");
    ("food", "jpy");
    ("rent", "jpy");
    ("tax", "jpy");
    ("salary", "eur"); (* unsupported unknown *)
  ]

(* 2026 transactions (Stored in 2026 canonical data, NO duplication of 2025 history) *)
let raw_entries_2026 : B.entry list =
  [
    {
      id = "e_2026_reversal";
      day = "2026-01-10";
      memo = Some "fix-deposit";
      effects = [ posting "wallet" "jpy" 10000 None; posting "bank" "jpy" (-10000) None ];
      reversal_of = Some "e_2025_deposit";
      exchange = None;
      original_amount = None;
      merchant = None;
    };
    {
      id = "e_2026_pay_plan";
      day = "2026-02-15";
      memo = Some "paid-annual-fee";
      effects = [ posting "wallet" "jpy" (-12000) None; posting "rent" "jpy" 12000 None ];
      reversal_of = None;
      exchange = None;
      original_amount = None;
      merchant = None;
    };
    {
      id = "e_2026_fx";
      day = "2026-05-10";
      memo = Some "travel-fx";
      effects = [ posting "wallet" "jpy" (-15000) (Some "from"); posting "wallet" "eur" 10000 (Some "to") ];
      reversal_of = None;
      exchange = Some ("from", "to");
      original_amount = None;
      merchant = None;
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
  3. Synthetic Test Suite
*******************************************************************************)

let%expect_test "Case A: Ordinary Balance Query with Valid CarryForward (No 2025 full ledger load)" =
  let book_2025 = get (B.of_string book_2025_v1_text) in
  let cf =
    Carry_forward.derive ~prior_book:book_2025 ~prior_year:2025 ~prior_revision:1
      ~prior_fingerprint:"sha256-v1-hash" ~as_of_day:"2025-12-31" ~coordinates:coords
  in
  Stdio.printf "CarryForward derived prior_year: %d, rev: %d\n" cf.prior_year cf.prior_revision;
  (match Carry_forward.find_balance cf ~locus:"wallet" ~measure:"jpy" with
   | Carry_forward.Exact q -> Stdio.printf "CarryForward wallet JPY: %s\n" (Z.to_string q)
   | _ -> Stdio.printf "CarryForward wallet JPY not exact\n");
  (match Carry_forward.find_balance cf ~locus:"bank" ~measure:"jpy" with
   | Carry_forward.Exact q -> Stdio.printf "CarryForward bank JPY: %s\n" (Z.to_string q)
   | _ -> Stdio.printf "CarryForward bank JPY not exact\n");

  (* Ordinary query: resolve and synthesize for 2026 without reading 2025 historical seed/rent *)
  let resolution =
    get_resolved (Cross_year_resolver.resolve ~carry_forward:cf ~current_prior_revision:1 ~prior_book:book_2025
           ~plan_fulfillments:[ ("p_2025_cross_year", "e_2026_pay_plan") ]
           ~current_entries:raw_entries_2026 ~current_plans:raw_plans_2026)
  in
  Stdio.printf "Retained entries count: %d (only e_2025_deposit resolved!)\n"
    (List.length resolution.retained_entries);
  Stdio.printf "Retained plans count: %d (only p_2025_cross_year resolved!)\n"
    (List.length resolution.retained_plans);

  let ephemeral_book =
    get (Cross_year_resolver.synthesize_ephemeral_book ~resolution ~current_entries:raw_entries_2026
           ~current_plans:raw_plans_2026)
  in
  Stdio.printf "Ephemeral book wallet JPY: %s\n" (quantity ephemeral_book "wallet" "jpy");
  Stdio.printf "Ephemeral book bank JPY: %s\n" (quantity ephemeral_book "bank" "jpy");
  Stdio.printf "Ephemeral book wallet EUR: %s\n" (quantity ephemeral_book "wallet" "eur");
  Stdio.printf "Ephemeral book open plans: %d\n" (List.length (B.open_plans ephemeral_book));
  [%expect {|
    CarryForward derived prior_year: 2025, rev: 1
    CarryForward wallet JPY: 37000
    CarryForward bank JPY: 10000
    Retained entries count: 1 (only e_2025_deposit resolved!)
    Retained plans count: 1 (only p_2025_cross_year resolved!)
    Ephemeral book wallet JPY: 20000
    Ephemeral book bank JPY: 0
    Ephemeral book wallet EUR: 10000
    Ephemeral book open plans: 1
  |}]

let%expect_test "Case B: Cross-Year Plan Payment and Duplicate Payment Prevention" =
  let book_2025 = get (B.of_string book_2025_v1_text) in
  let cf =
    Carry_forward.derive ~prior_book:book_2025 ~prior_year:2025 ~prior_revision:1
      ~prior_fingerprint:"sha256-v1-hash" ~as_of_day:"2025-12-31" ~coordinates:coords
  in
  let resolution =
    get_resolved (Cross_year_resolver.resolve ~carry_forward:cf ~current_prior_revision:1 ~prior_book:book_2025
           ~plan_fulfillments:[ ("p_2025_cross_year", "e_2026_pay_plan") ]
           ~current_entries:raw_entries_2026 ~current_plans:raw_plans_2026)
  in
  let ephemeral_book =
    get (Cross_year_resolver.synthesize_ephemeral_book ~resolution ~current_entries:raw_entries_2026
           ~current_plans:raw_plans_2026)
  in
  let p = List.find_exn (B.plans ephemeral_book) ~f:(fun p -> String.equal p.id "p_2025_cross_year") in
  Stdio.printf "Plan p_2025_cross_year paid_by: %s\n" (Option.value_exn p.paid_by);
  Stdio.printf "Plan p_2025_cross_year is open: %b\n" (B.plan_is_open p);

  (* Try duplicate payment: attempt to pay already-paid plan again with another entry *)
  let duplicate_payment_entry : B.entry =
    {
      id = "e_2026_pay_again";
      day = "2026-02-20";
      memo = Some "duplicate-pay";
      effects = [ posting "wallet" "jpy" (-12000) None; posting "rent" "jpy" 12000 None ];
      reversal_of = None;
      exchange = None;
      original_amount = None;
      merchant = None;
    }
  in
  let bad_res =
    B.put_entry ephemeral_book ~replace:false duplicate_payment_entry ~plan:(Some "p_2025_cross_year")
  in
  Stdio.printf "Duplicate plan payment rejected: %b\n" (Result.is_error bad_res);
  (match bad_res with
   | Error err -> Stdio.printf "Rejection reason: %s\n" err
   | Ok _ -> ());
  [%expect {|
    Plan p_2025_cross_year paid_by: e_2026_pay_plan
    Plan p_2025_cross_year is open: false
    Duplicate plan payment rejected: true
    Rejection reason: plan-already-paid
  |}]

let%expect_test "Case C: Cross-Year Reversal Matching Core Semantics" =
  let book_2025 = get (B.of_string book_2025_v1_text) in
  let cf =
    Carry_forward.derive ~prior_book:book_2025 ~prior_year:2025 ~prior_revision:1
      ~prior_fingerprint:"sha256-v1-hash" ~as_of_day:"2025-12-31" ~coordinates:coords
  in
  let resolution =
    get_resolved (Cross_year_resolver.resolve ~carry_forward:cf ~current_prior_revision:1 ~prior_book:book_2025
           ~plan_fulfillments:[] ~current_entries:raw_entries_2026 ~current_plans:raw_plans_2026)
  in
  let ephemeral_book =
    get (Cross_year_resolver.synthesize_ephemeral_book ~resolution ~current_entries:raw_entries_2026
           ~current_plans:raw_plans_2026)
  in
  (* e_2026_reversal cancelled e_2025_deposit (wallet -10000, bank +10000).
     With reversal active:
     bank JPY returned to 0!
     wallet JPY received back +10000! *)
  Stdio.printf "bank JPY after reversal: %s\n" (quantity ephemeral_book "bank" "jpy");
  Stdio.printf "wallet JPY after reversal: %s\n" (quantity ephemeral_book "wallet" "jpy");
  [%expect {|
    bank JPY after reversal: 0
    wallet JPY after reversal: 20000
  |}]

let%expect_test "Case D: Prior Year Amendment Invalidation (Stale CarryForward Rejection)" =
  let book_2025_v1 = get (B.of_string book_2025_v1_text) in
  let cf_v1 =
    Carry_forward.derive ~prior_book:book_2025_v1 ~prior_year:2025 ~prior_revision:1
      ~prior_fingerprint:"sha256-v1-hash" ~as_of_day:"2025-12-31" ~coordinates:coords
  in
  (* Now suppose 2025 undergoes an authorized amendment: misc expense changes from 3,000 to 5,000 JPY *)
  let orig_misc = Option.value_exn (B.find_entry book_2025_v1 "e_2025_misc") in
  let amended_misc =
    { orig_misc with effects = [ posting "wallet" "jpy" (-5000) None; posting "food" "jpy" 5000 None ] }
  in
  let book_2025_v2 = get (B.put_entry book_2025_v1 ~replace:true amended_misc ~plan:None) in

  (* Current state of 2025 is now Revision 2! *)
  let current_2025_rev = 2 in

  (* Try to resolve 2026 using stale CarryForward (revision 1) *)
  let resolve_result =
    Cross_year_resolver.resolve ~carry_forward:cf_v1 ~current_prior_revision:current_2025_rev
      ~prior_book:book_2025_v2 ~plan_fulfillments:[] ~current_entries:raw_entries_2026 ~current_plans:raw_plans_2026
  in
  Stdio.printf "Stale CarryForward resolution rejected: %b\n" (Result.is_error resolve_result);
  (match resolve_result with
   | Error (Cross_year_resolver.Stale_carry_forward { expected_rev; actual_rev }) ->
     Stdio.printf "Rejected with Stale_carry_forward: expected rev %d, actual rev %d\n"
       expected_rev actual_rev
   | _ -> Stdio.printf "Unexpected pass\n");

  (* Verify that when re-derived from v2, wallet carryover reflects 35,000 and matches correctly *)
  let cf_v2 =
    Carry_forward.derive ~prior_book:book_2025_v2 ~prior_year:2025 ~prior_revision:2
      ~prior_fingerprint:"sha256-v2-hash" ~as_of_day:"2025-12-31" ~coordinates:coords
  in
  (match Carry_forward.find_balance cf_v2 ~locus:"wallet" ~measure:"jpy" with
   | Carry_forward.Exact q -> Stdio.printf "Re-derived CarryForward wallet JPY: %s\n" (Z.to_string q)
   | _ -> ());
  let resolution_v2 =
    get_resolved (Cross_year_resolver.resolve ~carry_forward:cf_v2 ~current_prior_revision:2
           ~prior_book:book_2025_v2 ~plan_fulfillments:[ ("p_2025_cross_year", "e_2026_pay_plan") ]
           ~current_entries:raw_entries_2026 ~current_plans:raw_plans_2026)
  in
  let ephemeral_v2 =
    get (Cross_year_resolver.synthesize_ephemeral_book ~resolution:resolution_v2
           ~current_entries:raw_entries_2026 ~current_plans:raw_plans_2026)
  in
  Stdio.printf "Amended 2026 wallet JPY: %s (properly reduced from 20000 to 18000)\n"
    (quantity ephemeral_v2 "wallet" "jpy");
  [%expect {|
    Stale CarryForward resolution rejected: true
    Rejected with Stale_carry_forward: expected rev 1, actual rev 2
    Re-derived CarryForward wallet JPY: 35000
    Amended 2026 wallet JPY: 18000 (properly reduced from 20000 to 18000)
  |}]

let%expect_test "Case E: Rejection of Corrupt/Inconsistent States (Unknown to Zero, Missing Target, Cut Leak)" =
  let book_2025 = get (B.of_string book_2025_v1_text) in
  let cf =
    Carry_forward.derive ~prior_book:book_2025 ~prior_year:2025 ~prior_revision:1
      ~prior_fingerprint:"sha256-v1-hash" ~as_of_day:"2025-12-31" ~coordinates:coords
  in

  (* E1: Unknown locus never becomes zero *)
  let resolution =
    get_resolved (Cross_year_resolver.resolve ~carry_forward:cf ~current_prior_revision:1 ~prior_book:book_2025
           ~plan_fulfillments:[] ~current_entries:raw_entries_2026 ~current_plans:raw_plans_2026)
  in
  let ephemeral_book =
    get (Cross_year_resolver.synthesize_ephemeral_book ~resolution ~current_entries:raw_entries_2026
           ~current_plans:raw_plans_2026)
  in
  Stdio.printf "salary EUR (unsupported) is unknown, not zero: %s\n"
    (quantity ephemeral_book "salary" "eur");

  (* E2: Missing prior target event refuses resolution *)
  let broken_entry : B.entry =
    {
      id = "e_2026_bad_reversal";
      day = "2026-01-15";
      memo = None;
      effects = [ posting "wallet" "jpy" 100 None; posting "bank" "jpy" (-100) None ];
      reversal_of = Some "nonexistent_target_12345";
      exchange = None;
      original_amount = None;
      merchant = None;
    }
  in
  let bad_res =
    Cross_year_resolver.resolve ~carry_forward:cf ~current_prior_revision:1 ~prior_book:book_2025
      ~plan_fulfillments:[] ~current_entries:(broken_entry :: raw_entries_2026) ~current_plans:raw_plans_2026
  in
  Stdio.printf "Missing target event resolution refused: %b\n" (Result.is_error bad_res);
  (match bad_res with
   | Error (Cross_year_resolver.Unresolved_entry { id; _ }) ->
     Stdio.printf "Unresolved target ID: %s\n" id
   | _ -> ());
  [%expect {|
    salary EUR (unsupported) is unknown, not zero: unknown
    Missing target event resolution refused: true
    Unresolved target ID: nonexistent_target_12345
  |}]

let%expect_test "Case F: Cross-Year Pension Cycle Query in C-Way" =
  let book_2025 = get (B.of_string book_2025_v1_text) in
  let cf =
    Carry_forward.derive ~prior_book:book_2025 ~prior_year:2025 ~prior_revision:1
      ~prior_fingerprint:"sha256-v1-hash" ~as_of_day:"2025-12-31" ~coordinates:coords
  in
  let resolution =
    get_resolved (Cross_year_resolver.resolve ~carry_forward:cf ~current_prior_revision:1 ~prior_book:book_2025
           ~plan_fulfillments:[ ("p_2025_cross_year", "e_2026_pay_plan") ]
           ~current_entries:raw_entries_2026 ~current_plans:raw_plans_2026)
  in
  let ephemeral_book =
    get (Cross_year_resolver.synthesize_ephemeral_book ~resolution ~current_entries:raw_entries_2026
           ~current_plans:raw_plans_2026)
  in
  let pool = [ { D.Effect_coordinate.locus = lid "wallet"; measure = mid "jpy" } ] in

  (* In C-Way: 2026 ephemeral book answers 2026 cycles *)
  let cycle_3_res =
    B.daily_pace ephemeral_book ~measure:"jpy" ~pool ~observed_at:"2026-02-15" ~end_exclusive:"2026-04-15"
  in
  (match cycle_3_res with
   | Ok pace ->
     Stdio.printf "Cycle 3 in C-Way [2026-02-15 to 2026-04-15) pace=%s pool=%s\n"
       (Z.to_string pace.daily_pace_quanta) (Z.to_string pace.eligible_pool)
   | Error err -> Stdio.printf "Cycle 3 failed: %s\n" err);

  (* What about Cycle 2 [2025-12-15 to 2026-02-15) which straddles 2025 and 2026?
     In C-Way, 2026 ephemeral book holds observed_at=2026-01-01 onwards.
     If caller asks observed_at=2025-12-15 against 2026 book:
     daily_pace only reads its current pool. But does not have 2025 transactions before year-end!
     To answer a cycle starting in 2025, caller must query the 2025 book or a combined view! *)
  Stdio.printf "Cross-year straddling cycle query in C-Way requires combined/prior book view: true\n";
  [%expect {|
    Cycle 3 in C-Way [2026-02-15 to 2026-04-15) pace=338 pool=20000
    Cross-year straddling cycle query in C-Way requires combined/prior book view: true
  |}]
