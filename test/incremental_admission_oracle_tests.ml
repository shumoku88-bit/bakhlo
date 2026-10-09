open Base
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query

let get = function Ok x -> x | Error why -> failwith why

let fixture =
  "(bakhlo-daily 1) (scope corrected-entries explicit-plans)\n\
   (measures (measure jpy 0) (measure eur 2) (measure usd 2))\n\
   (labels (provided (label wallet 財布 現金) (label bank 銀行 預金) (label food 食費 経費)))\n\
   (approved-loci (provided wallet food bank expense reserve))\n\
   (entries\n\
     (entry init (date 2026-10-01) (memo (some initial))\n\
       (postings (posting bank jpy 50000 (none)) (posting wallet jpy -50000 (none)))\n\
       (reversal-of (none))))\n\
   (plans\n\
     (plan rent (date 2026-10-25) (measure jpy) (changes (bank -10000) (expense 10000))\n\
       (paid-by (none)))\n\
     (plan sub (date 2026-10-20) (measure usd) (changes (wallet -15) (expense 15))\n\
       (paid-by (none))))\n\
   (support (zero-origin (food jpy) (expense jpy) (expense usd))\n\
     (openings (bank jpy init))\n\
     (observations (observation (reflected) (quantities (wallet jpy 100000) (wallet usd 500))))\n\
     (presence (not-supplied)))\n"

let posting locus measure n key =
  D.Effect.create
    ~locus:
      (Result.ok_or_failwith
         (Result.map_error (D.Identifier.Locus.of_string locus) ~f:(fun _ -> "locus")))
    ~measure:
      (Result.ok_or_failwith
         (Result.map_error (D.Identifier.Measure.of_string measure) ~f:(fun _ -> "measure")))
    ~quantity:(D.Quantity.of_quanta (Z.of_int n))
    ~key:
      (Option.map key ~f:(fun k ->
           Result.ok_or_failwith
             (Result.map_error (D.Identifier.Effect_key.of_string k) ~f:(fun _ -> "key"))))

let query_str book locus measure =
  let locus =
    Result.ok_or_failwith
      (Result.map_error (D.Identifier.Locus.of_string locus) ~f:(fun _ -> "locus"))
  in
  let measure =
    Result.ok_or_failwith
      (Result.map_error (D.Identifier.Measure.of_string measure) ~f:(fun _ -> "measure"))
  in
  match Q.query (B.image book) { D.Effect_coordinate.locus; measure } with
  | Ok (Q.Exact x) -> Z.to_string (D.Quantity.quanta (Q.quantity x))
  | Ok (Q.Known_present _) -> "presence"
  | Error (Q.Support_unknown _) -> "unknown"

let assert_books_equal label inc full =
  let str_inc = B.to_string inc in
  let str_full = B.to_string full in
  if not (String.equal str_inc str_full) then
    failwith (Printf.sprintf "[%s] Serialized S-expression mismatch:\nINC:\n%s\nFULL:\n%s" label str_inc str_full);
  let loci = [ "wallet"; "bank"; "food"; "expense"; "reserve" ] in
  let measures = [ "jpy"; "eur"; "usd" ] in
  List.iter loci ~f:(fun loc ->
      List.iter measures ~f:(fun m ->
          let q_inc = query_str inc loc m in
          let q_full = query_str full loc m in
          if not (String.equal q_inc q_full) then
            failwith
              (Printf.sprintf "[%s] Query mismatch for %s %s: inc=%s full=%s" label loc m q_inc q_full)))

let assert_error_equal label res_inc res_full =
  match (res_inc, res_full) with
  | Ok _, Ok _ -> failwith (Printf.sprintf "[%s] Expected errors, but both succeeded" label)
  | Ok _, Error err -> failwith (Printf.sprintf "[%s] Inc succeeded, but full failed with: %s" label err)
  | Error err, Ok _ -> failwith (Printf.sprintf "[%s] Inc failed with: %s, but full succeeded" label err)
  | Error e1, Error e2 ->
      if not (String.equal e1 e2) then
        failwith (Printf.sprintf "[%s] Error reason mismatch: inc=%s full=%s" label e1 e2)

let%expect_test "incremental admission matches full oracle on sequential transactions" =
  let base = get (B.of_string fixture) in
  let book_inc = ref base in
  let book_full = ref base in
  let steps =
    [
      {
        B.id = "tx1";
        day = "2026-10-02";
        memo = Some "Groceries";
        effects = [ posting "wallet" "jpy" (-3000) None; posting "food" "jpy" 3000 None ];
        reversal_of = None;
        exchange = None;
      };
      {
        B.id = "tx2";
        day = "2026-10-03";
        memo = Some "Transfer to bank";
        effects = [ posting "wallet" "jpy" (-10000) None; posting "bank" "jpy" 10000 None ];
        reversal_of = None;
        exchange = None;
      };
      {
        B.id = "tx3";
        day = "2026-10-04";
        memo = Some "USD coffee";
        effects = [ posting "wallet" "usd" (-5) None; posting "expense" "usd" 5 None ];
        reversal_of = None;
        exchange = None;
      };
      {
        B.id = "tx4";
        day = "2026-10-05";
        memo = Some "Split bill";
        effects =
          [
            posting "wallet" "jpy" (-5000) None;
            posting "food" "jpy" 2000 None;
            posting "expense" "jpy" 3000 None;
          ];
        reversal_of = None;
        exchange = None;
      };
    ]
  in
  List.iteri steps ~f:(fun i entry ->
      let res_inc = B.put_entry !book_inc ~replace:false entry ~plan:None in
      let res_full = B.put_entry_full !book_full ~replace:false entry ~plan:None in
      let label = Printf.sprintf "step_%d" (i + 1) in
      let inc = get res_inc in
      let full = get res_full in
      assert_books_equal label inc full;
      book_inc := inc;
      book_full := full);
  Stdio.printf "sequential transactions: %d steps identical\n" (List.length steps);
  Stdio.printf "wallet jpy: %s; food jpy: %s; wallet usd: %s\n"
    (query_str !book_inc "wallet" "jpy")
    (query_str !book_inc "food" "jpy")
    (query_str !book_inc "wallet" "usd");
  [%expect {|
    sequential transactions: 4 steps identical
    wallet jpy: 32000; food jpy: 5000; wallet usd: 495
    |}]

let%expect_test "incremental admission matches full oracle on plan payments" =
  let base = get (B.of_string fixture) in
  let rent_payment : B.entry =
    {
      id = "pay_rent";
      day = "2026-10-25";
      memo = Some "Paid rent";
      effects = [ posting "bank" "jpy" (-10000) None; posting "expense" "jpy" 10000 None ];
      reversal_of = None;
      exchange = None;
    }
  in
  let inc = get (B.put_entry base ~replace:false rent_payment ~plan:(Some "rent")) in
  let full = get (B.put_entry_full base ~replace:false rent_payment ~plan:(Some "rent")) in
  assert_books_equal "rent_payment" inc full;
  let p_inc = List.find_exn (B.plans inc) ~f:(fun p -> String.equal p.id "rent") in
  let p_full = List.find_exn (B.plans full) ~f:(fun p -> String.equal p.id "rent") in
  Stdio.printf "plan paid_by match: %b (%s)\n"
    (Option.equal String.equal p_inc.paid_by p_full.paid_by)
    (Option.value_exn p_inc.paid_by);
  Stdio.printf "bank jpy: %s; expense jpy: %s\n"
    (query_str inc "bank" "jpy")
    (query_str inc "expense" "jpy");
  [%expect {|
    plan paid_by match: true (pay_rent)
    bank jpy: 40000; expense jpy: 10000
    |}]

let%expect_test "incremental admission matches full oracle on error refusals" =
  let base = get (B.of_string fixture) in
  let valid_entry : B.entry =
    {
      id = "valid";
      day = "2026-10-10";
      memo = Some "OK";
      effects = [ posting "wallet" "jpy" (-100) None; posting "food" "jpy" 100 None ];
      reversal_of = None;
      exchange = None;
    }
  in
  (* 1. Duplicate ID *)
  let err_dup = { valid_entry with id = "init" } in
  assert_error_equal "duplicate_id"
    (B.put_entry base ~replace:false err_dup ~plan:None)
    (B.put_entry_full base ~replace:false err_dup ~plan:None);
  (* 2. Unapproved locus *)
  let err_locus = { valid_entry with effects = [ posting "unapproved" "jpy" (-100) None; posting "food" "jpy" 100 None ] } in
  assert_error_equal "unapproved_locus"
    (B.put_entry base ~replace:false err_locus ~plan:None)
    (B.put_entry_full base ~replace:false err_locus ~plan:None);
  (* 3. Unknown measure *)
  let err_measure = { valid_entry with effects = [ posting "wallet" "gbp" (-100) None; posting "food" "gbp" 100 None ] } in
  assert_error_equal "unknown_measure"
    (B.put_entry base ~replace:false err_measure ~plan:None)
    (B.put_entry_full base ~replace:false err_measure ~plan:None);
  (* 4. Zero effect *)
  let err_zero = { valid_entry with effects = [ posting "wallet" "jpy" 0 None; posting "food" "jpy" 0 None ] } in
  assert_error_equal "zero_effect"
    (B.put_entry base ~replace:false err_zero ~plan:None)
    (B.put_entry_full base ~replace:false err_zero ~plan:None);
  (* 5. Unbalanced measure *)
  let err_unbalanced = { valid_entry with effects = [ posting "wallet" "jpy" (-100) None; posting "food" "jpy" 50 None ] } in
  assert_error_equal "unbalanced_measure"
    (B.put_entry base ~replace:false err_unbalanced ~plan:None)
    (B.put_entry_full base ~replace:false err_unbalanced ~plan:None);
  (* 6. Cross-measure unbalanced *)
  let err_cross = { valid_entry with effects = [ posting "wallet" "jpy" (-100) None; posting "food" "usd" 100 None ] } in
  assert_error_equal "cross_measure_unbalanced"
    (B.put_entry base ~replace:false err_cross ~plan:None)
    (B.put_entry_full base ~replace:false err_cross ~plan:None);
  (* 7. Invalid date *)
  let err_date = { valid_entry with day = "2026-02-30" } in
  assert_error_equal "invalid_date"
    (B.put_entry base ~replace:false err_date ~plan:None)
    (B.put_entry_full base ~replace:false err_date ~plan:None);
  (* 8. Unknown plan *)
  assert_error_equal "unknown_plan"
    (B.put_entry base ~replace:false valid_entry ~plan:(Some "nonexistent_plan"))
    (B.put_entry_full base ~replace:false valid_entry ~plan:(Some "nonexistent_plan"));
  (* 9. Already paid plan *)
  let with_paid = get (B.put_entry base ~replace:false valid_entry ~plan:(Some "rent")) in
  let second_pay = { valid_entry with id = "second_pay" } in
  assert_error_equal "plan_already_paid"
    (B.put_entry with_paid ~replace:false second_pay ~plan:(Some "rent"))
    (B.put_entry_full with_paid ~replace:false second_pay ~plan:(Some "rent"));
  Stdio.printf "all 9 error cases match full oracle exactly\n";
  [%expect {|
    all 9 error cases match full oracle exactly
    |}]

let%expect_test "fallback cases trigger full oracle correctly and match results" =
  let base = get (B.of_string fixture) in
  (* 1. replace = true *)
  let orig : B.entry =
    {
      id = "mod_me";
      day = "2026-10-05";
      memo = Some "Original";
      effects = [ posting "wallet" "jpy" (-1000) None; posting "food" "jpy" 1000 None ];
      reversal_of = None;
      exchange = None;
    }
  in
  let added = get (B.put_entry base ~replace:false orig ~plan:None) in
  let edited = { orig with memo = Some "Updated"; day = "2026-10-06" } in
  let res_inc_replace = B.put_entry added ~replace:true edited ~plan:None in
  let res_full_replace = B.put_entry_full added ~replace:true edited ~plan:None in
  assert_books_equal "replace_entry" (get res_inc_replace) (get res_full_replace);

  (* 2. reversal_of <> None *)
  let reversal : B.entry =
    {
      id = "rev_tx";
      day = "2026-10-07";
      memo = Some "Reversal";
      effects = [ posting "wallet" "jpy" 1000 None; posting "food" "jpy" (-1000) None ];
      reversal_of = Some "mod_me";
      exchange = None;
    }
  in
  let res_inc_rev = B.put_entry added ~replace:false reversal ~plan:None in
  let res_full_rev = B.put_entry_full added ~replace:false reversal ~plan:None in
  assert_books_equal "reversal_entry" (get res_inc_rev) (get res_full_rev);

  (* 3. exchange <> None *)
  let fx : B.entry =
    {
      id = "fx_tx";
      day = "2026-10-08";
      memo = Some "FX trade";
      effects = [ posting "wallet" "jpy" (-15000) (Some "src"); posting "wallet" "usd" 100 (Some "dst") ];
      reversal_of = None;
      exchange = Some ("src", "dst");
    }
  in
  let res_inc_fx = B.put_entry base ~replace:false fx ~plan:None in
  let res_full_fx = B.put_entry_full base ~replace:false fx ~plan:None in
  assert_books_equal "fx_exchange" (get res_inc_fx) (get res_full_fx);

  Stdio.printf "all 3 fallback cases execute and match full oracle\n";
  [%expect {|
    all 3 fallback cases execute and match full oracle
    |}]

let%expect_test "PR 6b entry map index and reversed list invariants" =
  let base = get (B.of_string fixture) in
  (* 1. Initial Monolithic state check *)
  assert (B.entry_count base = 1);
  assert (B.mem_entry base "init");
  assert (not (B.mem_entry base "nonexistent"));
  assert (Option.is_some (B.find_entry base "init"));
  assert (Option.is_none (B.find_entry base "nonexistent"));
  assert (List.length (B.entries_rev base) = 1);
  assert (String.equal (List.hd_exn (B.entries base)).id "init");
  assert (String.equal (List.hd_exn (B.entries_rev base)).id "init");

  (* 2. Normal append with past date: record order vs transaction date *)
  let past_tx : B.entry =
    {
      id = "past_e";
      day = "2026-09-01"; (* Older than init (2026-10-01) *)
      memo = Some "Past entry";
      effects = [ posting "wallet" "jpy" (-3000) None; posting "food" "jpy" 3000 None ];
      reversal_of = None;
      exchange = None;
    }
  in
  let inc_past = get (B.put_entry base ~replace:false past_tx ~plan:None) in
  let full_past = get (B.put_entry_full base ~replace:false past_tx ~plan:None) in
  assert_books_equal "past_date_append" inc_past full_past;

  assert (B.entry_count inc_past = 2);
  assert (B.mem_entry inc_past "past_e");
  (* Recorded order must be oldest-recorded first, NOT chronological date order *)
  let fwd_ids = List.map (B.entries inc_past) ~f:(fun e -> e.id) in
  let rev_ids = List.map (B.entries_rev inc_past) ~f:(fun e -> e.id) in
  assert (List.equal String.equal fwd_ids [ "init"; "past_e" ]);
  assert (List.equal String.equal rev_ids [ "past_e"; "init" ]);

  (* 3. Correction / Replacement (replace = true): Map must point to new entry, not old *)
  let corrected_past : B.entry =
    { past_tx with memo = Some "Corrected past memo"; day = "2026-09-02" }
  in
  let inc_replaced = get (B.put_entry inc_past ~replace:true corrected_past ~plan:None) in
  let full_replaced = get (B.put_entry_full inc_past ~replace:true corrected_past ~plan:None) in
  assert_books_equal "replace_entry" inc_replaced full_replaced;

  assert (B.entry_count inc_replaced = 2);
  let lookup_e = Option.value_exn (B.find_entry inc_replaced "past_e") in
  assert (Option.equal String.equal lookup_e.memo (Some "Corrected past memo"));
  assert (String.equal lookup_e.day "2026-09-02");
  (* Forward order remains [ "init"; "past_e" ] *)
  let fwd_replaced = List.map (B.entries inc_replaced) ~f:(fun e -> e.id) in
  assert (List.equal String.equal fwd_replaced [ "init"; "past_e" ]);

  (* 4. Reversal *)
  let rev_tx : B.entry =
    {
      id = "rev_e";
      day = "2026-10-05";
      memo = Some "Reversal of past_e";
      effects = [ posting "wallet" "jpy" 3000 None; posting "food" "jpy" (-3000) None ];
      reversal_of = Some "past_e";
      exchange = None;
    }
  in
  let inc_rev = get (B.put_entry inc_replaced ~replace:false rev_tx ~plan:None) in
  let full_rev = get (B.put_entry_full inc_replaced ~replace:false rev_tx ~plan:None) in
  assert_books_equal "reversal_entry" inc_rev full_rev;
  assert (B.entry_count inc_rev = 3);
  assert (B.mem_entry inc_rev "rev_e");
  assert (List.equal String.equal (List.map (B.entries inc_rev) ~f:(fun e -> e.id)) [ "init"; "past_e"; "rev_e" ]);

  (* 5. FX Exchange *)
  let fx_tx : B.entry =
    {
      id = "fx_e";
      day = "2026-10-06";
      memo = Some "FX exchange";
      effects = [ posting "wallet" "jpy" (-15000) (Some "src"); posting "wallet" "usd" 100 (Some "dst") ];
      reversal_of = None;
      exchange = Some ("src", "dst");
    }
  in
  let inc_fx = get (B.put_entry inc_rev ~replace:false fx_tx ~plan:None) in
  let full_fx = get (B.put_entry_full inc_rev ~replace:false fx_tx ~plan:None) in
  assert_books_equal "fx_entry" inc_fx full_fx;
  assert (B.entry_count inc_fx = 4);
  assert (B.mem_entry inc_fx "fx_e");

  (* 6. Plan Payment *)
  let pay_tx : B.entry =
    {
      id = "pay_rent";
      day = "2026-10-25";
      memo = Some "Pay rent plan";
      effects = [ posting "bank" "jpy" (-10000) None; posting "expense" "jpy" 10000 None ];
      reversal_of = None;
      exchange = None;
    }
  in
  let inc_pay = get (B.put_entry inc_fx ~replace:false pay_tx ~plan:(Some "rent")) in
  let full_pay = get (B.put_entry_full inc_fx ~replace:false pay_tx ~plan:(Some "rent")) in
  assert_books_equal "plan_pay_entry" inc_pay full_pay;
  assert (B.entry_count inc_pay = 5);
  assert (B.mem_entry inc_pay "pay_rent");
  let paid_plan = Option.value_exn (List.find (B.plans inc_pay) ~f:(fun p -> String.equal p.id "rent")) in
  assert (Option.equal String.equal paid_plan.paid_by (Some "pay_rent"));

  (* 7. Records S-expression format export & reload *)
  let rec_str = B.to_records_string inc_pay in
  let reloaded_rec = get (B.of_string rec_str) in
  assert (B.entry_count reloaded_rec = 5);
  let rec_fwd_ids = List.map (B.entries reloaded_rec) ~f:(fun e -> e.id) in
  let rec_rev_ids = List.map (B.entries_rev reloaded_rec) ~f:(fun e -> e.id) in
  assert (List.equal String.equal rec_fwd_ids [ "init"; "past_e"; "rev_e"; "fx_e"; "pay_rent" ]);
  assert (List.equal String.equal rec_rev_ids [ "pay_rent"; "fx_e"; "rev_e"; "past_e"; "init" ]);
  List.iter rec_fwd_ids ~f:(fun id ->
    assert (B.mem_entry reloaded_rec id);
    assert (Option.is_some (B.find_entry reloaded_rec id)));
  let loci = [ "wallet"; "bank"; "food"; "expense"; "reserve" ] in
  let measures = [ "jpy"; "usd" ] in
  List.iter loci ~f:(fun l ->
      List.iter measures ~f:(fun m ->
          let q_orig = query_str inc_pay l m in
          let q_rec = query_str reloaded_rec l m in
          if not (String.equal q_orig q_rec) then
            failwith (Printf.sprintf "records_roundtrip balance mismatch at (%s, %s): %s vs %s" l m q_orig q_rec)));

  Stdio.printf "PR 6b comprehensive regression invariants hold\n";
  [%expect {|
    PR 6b comprehensive regression invariants hold
    |}]


let%expect_test "date-only checks agree with full Actual validity admission" =
  let module V = Bakhlo_application.Actual_validity in
  let id =
    match D.Identifier.Event.of_string "date-probe" with
    | Ok id -> id
    | Error _ -> failwith "invalid synthetic Event ID"
  in
  let event =
    match D.Event.create ~id ~effects:[] with
    | Ok event -> event
    | Error _ -> failwith "invalid synthetic Event"
  in
  let events =
    match D.Event_memory.of_events [ event ] with
    | Ok events -> events
    | Error _ -> failwith "invalid synthetic Event memory"
  in
  let cases =
    [
      ("2026-10-09", true);
      ("2000-02-29", true);
      ("2004-02-29", true);
      ("1900-02-28", true);
      ("2024-02-29", true);
      ("9999-12-31", true);
      ("0000-01-01", false);
      ("1900-02-29", false);
      ("2026-02-29", false);
      ("2026-02-30", false);
      ("2026-04-31", false);
      ("2026-13-01", false);
      ("2026-00-01", false);
      ("2026-01-00", false);
      ("2026-01-32", false);
      ("2026-1-09", false);
      ("2026/10/09", false);
      ("2026-10-09 ", false);
      (" 2026-10-09", false);
      ("", false);
    ]
  in
  List.iter cases ~f:(fun (day, expected) ->
      let direct = V.valid_date day in
      let qualified =
        Result.is_ok
          (V.create ~events ~facts:[ V.Base { event = id; valid_on = day } ] ~corrections:[])
      in
      if not (Bool.equal direct expected && Bool.equal qualified expected) then
        failwith (Printf.sprintf "date disagreement for %S" day));
  Stdio.printf "direct date and admitted singleton agree: %d cases\n" (List.length cases);
  [%expect {|direct date and admitted singleton agree: 20 cases|}]
