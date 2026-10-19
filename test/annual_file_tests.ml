open Base
module B = Bakhlo_sexp.Daily_book
module Scope = Bakhlo_sexp.Annual_scope
module File = Daily_file
module D = Bakhlo_domain
module Y = Bakhlo_sexp.Year_read

let get = function Ok x -> x | Error why -> failwith why
let require x msg = if not x then failwith msg

let fixture day =
  let bytes =
    "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
     (measures (measure jpy 0)) (labels (not-supplied))\n\
     (approved-loci (not-supplied))\n\
     (entries (entry spend (date " ^ day ^ ") (memo (none))\n\
     (postings (posting wallet jpy -3 (none)) (posting food jpy 3 (none)))\n\
     (reversal-of (none)) (exchange (none))))\n\
     (plans) (support (zero-origin (food jpy)) (openings)\n\
     (observations (observation (reflected) (quantities (wallet jpy 10))))\n\
     (presence (not-supplied)))"
  in
  get (B.of_string bytes)

let%expect_test "year guard checks path, dates and correction moves" =
  require (Poly.equal (Scope.of_string "2026") (Ok 2026)) "parse";
  require (Result.is_error (Scope.of_string "0000")) "zero-year";
  require (Result.is_error (Scope.of_string "26")) "short-year";
  require (Result.is_error (Scope.of_string "202x")) "invalid-year";
  require (Poly.equal (Scope.check_path ~year:2026 "/tmp/books/2026.sexp") (Ok ())) "year-name";
  require (Result.is_error (Scope.check_path ~year:2026 "/tmp/books/2027.sexp")) "wrong-name";
  require (Poly.equal (Scope.check_book ~year:2026 (fixture "2026-12-31")) (Ok ())) "last-day";
  require (Poly.equal (Scope.check_book ~year:2027 (fixture "2027-01-01")) (Ok ())) "next-year";
  require
    (Poly.equal (Scope.check_book ~year:2026 (fixture "2027-01-01"))
      (Error "annual-entry-outside-year:spend"))
    "cross-year-correction";
  [%expect {| |}]

let%expect_test "opt-in annual storage uses existing writer; wrong-year commits cannot alter file" =
  let root = Stdlib.Filename.temp_file "bakhlo-annual-scope-" "" in
  Stdlib.Sys.remove root;
  Unix.mkdir root 0o700;
  let p26 = Stdlib.Filename.concat root "2026.sexp" in
  let p27 = Stdlib.Filename.concat root "2027.sexp" in
  let annual26 = File.create_annual_empty ~year:2026 ~path:p26 ~measure:"jpy" ~scale:0 in
  let annual27 = File.create_annual_empty ~year:2027 ~path:p27 ~measure:"jpy" ~scale:0 in
  let old27 = File.read p27 in
  let original26 = fixture "2026-12-31" in
  let saved26 =
    match File.publish annual26 original26 with
    | File.Written saved -> saved
    | _ -> failwith "first-save-refused"
  in
  require (B.entry_count (File.load ~annual_year:2026 p26).book = 1) "cold-open-2026";
  require (B.entry_count (File.load ~annual_year:2027 p27).book = 0) "cold-open-2027";
  require (String.equal (File.read p27) old27) "other-year-mutated";
  let original26_bytes = File.read p26 in
  (match File.publish saved26 (fixture "2027-01-01") with
   | File.Refused_input "annual-entry-outside-year:spend" -> ()
   | _ -> failwith "wrong-year-publication-not-refused");
  require (String.equal (File.read p26) original26_bytes) "cross-year-mutated-original";
  let reloaded26 = File.reload saved26 in
  require (Poly.equal reloaded26.annual_year (Some 2026)) "annual-reload-lost-scope";
  (match File.publish reloaded26 (fixture "2027-01-01") with
   | File.Refused_input "annual-entry-outside-year:spend" -> ()
   | _ -> failwith "reloaded-annual-scope-bypassed");
  require (String.equal (File.read p26) original26_bytes) "reload-cross-year-mutated";
  let corrected26 = fixture "2026-11-30" in
  (match File.publish saved26 corrected26 with
   | File.Written _ -> ()
   | _ -> failwith "within-year-correction-refused");
  require
    (Poly.equal
      (List.map (B.entries (File.load ~annual_year:2026 p26).book) ~f:(fun e -> e.day))
      [ "2026-11-30" ])
    "same-year-cold-correction";
  require (String.equal (File.read p27) old27) "correction-touched-other-year";
  require (Result.is_error (Scope.check_path ~year:2026 p27)) "year-mismatch";
  let refused f = try f (); false with File.Refused _ -> true in
  require (refused (fun () -> ignore (File.load ~annual_year:2026 p27))) "wrong-year-selection";
  require (refused (fun () -> ignore (File.create_annual_empty ~year:2026
    ~path:(Stdlib.Filename.concat root "wrong.sexp") ~measure:"jpy" ~scale:0)))
    "unsafe-annual-create";
  let bytes26_before = File.read p26 in
  let saved27 =
    match File.publish annual27 (fixture "2027-01-01") with
    | File.Written saved -> saved
    | _ -> failwith "publish-2027-refused"
  in
  let reloaded27 = File.load ~annual_year:2027 p27 in
  require (B.entry_count reloaded27.book = 1) "cold-reload-2027";
  require (String.equal (File.read p26) bytes26_before) "2026-bytes-unchanged-after-2027-publish";
  require
    (try
       ignore (File.create_annual_empty ~year:2026 ~path:p26 ~measure:"jpy" ~scale:0);
       false
     with Unix.Unix_error (Unix.EEXIST, _, _) -> true)
    "create-collision-refused";
  require (String.equal (File.read p26) bytes26_before) "collision-preserved-existing-book";
  let missing_path = Stdlib.Filename.concat root "2025.sexp" in
  require
    (try ignore (File.load ~annual_year:2025 missing_path); false
     with Unix.Unix_error (Unix.ENOENT, _, _) -> true)
    "load-missing-refused";
  let corrupt_path = Stdlib.Filename.concat root "2028.sexp" in
  File.write_new corrupt_path "(not valid sexp";
  require (refused (fun () -> ignore (File.load ~annual_year:2028 corrupt_path))) "load-corrupt-refused";
  ignore saved27;
  [%expect {| |}]

let coordinate locus =
  {
    D.Effect_coordinate.locus =
      (match D.Identifier.Locus.of_string locus with Ok l -> l | Error _ -> failwith "invalid-locus");
    measure =
      (match D.Identifier.Measure.of_string "jpy" with Ok m -> m | Error _ -> failwith "invalid-measure");
  }

let rich_book entries plans support =
  let s =
    "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
     (measures (measure jpy 0)) (labels (not-supplied))\n\
     (approved-loci (not-supplied))\n\
     (entries " ^ entries ^ ")\n\
     (plans " ^ plans ^ ")\n\
     (support " ^ support ^ ")"
  in
  get (B.of_string s)

let%expect_test "annual rollover preview verifies adjacent years, closing states, open plans, and exclusion" =
  let root = Stdlib.Filename.temp_file "bakhlo-annual-preview-" "" in
  Stdlib.Sys.remove root;
  Unix.mkdir root 0o700;
  let p26 = Stdlib.Filename.concat root "2026.sexp" in
  let p27 = Stdlib.Filename.concat root "2027.sexp" in
  let annual26 = File.create_annual_empty ~year:2026 ~path:p26 ~measure:"jpy" ~scale:0 in
  let annual27 = File.create_annual_empty ~year:2027 ~path:p27 ~measure:"jpy" ~scale:0 in
  let prior_entries =
    "(entry e_seed (date 2026-01-01) (memo (none))\n\
     (postings (posting wallet jpy 10 (none)) (posting food jpy -10 (none)))\n\
     (reversal-of (none)) (exchange (none)))\n\
     (entry spend (date 2026-06-01) (memo (none))\n\
     (postings (posting wallet jpy -3 (none)) (posting food jpy 3 (none)))\n\
     (reversal-of (none)) (exchange (none)))\n\
     (entry spend_cash (date 2026-06-02) (memo (none))\n\
     (postings (posting cash jpy -5 (none)) (posting food jpy 5 (none)))\n\
     (reversal-of (none)) (exchange (none)))"
  in
  let prior_plans =
    "(plan p_open (date 2026-10-10) (measure jpy) (changes (wallet -200) (food 200)) (paid-by (none)) (cancelled-on (none)))\n\
     (plan p_paid (date 2026-10-11) (measure jpy) (changes (wallet -100) (food 100)) (paid-by (some spend)) (cancelled-on (none)))\n\
     (plan p_cancelled (date 2026-10-12) (measure jpy) (changes (wallet -50) (food 50)) (paid-by (none)) (cancelled-on (some 2026-10-15)))"
  in
  let prior_support =
    "(zero-origin (food jpy) (tax jpy))\n\
     (openings)\n\
     (observations (observation (reflected e_seed) (quantities (wallet jpy 10) (cash jpy 5))))\n\
     (presence (provided (reflected e_seed) (coordinates (bank jpy))))"
  in
  let book26 = rich_book prior_entries prior_plans prior_support in
  let saved26 = match File.publish annual26 book26 with File.Written s -> s | _ -> failwith "pub-26-failed" in
  ignore saved26;
  ignore annual27;
  let initial_bytes26 = File.read p26 in
  let initial_bytes27 = File.read p27 in
  let coords = [
    coordinate "wallet";
    coordinate "cash";
    coordinate "tax";
    coordinate "food";
    coordinate "bank";
    coordinate "salary";
  ] in
  let preview = File.preview_annual_rollover ~directory:root ~year:2027 ~coordinates:coords in
  require (preview.prior_year = 2026) "preview-prior-year";
  require (preview.year = 2027) "preview-target-year";
  require (String.equal preview.prior_fingerprint (Stdlib.Digest.to_hex (Stdlib.Digest.string initial_bytes26))) "prior-fp";
  require (String.equal preview.current_fingerprint (Stdlib.Digest.to_hex (Stdlib.Digest.string initial_bytes27))) "current-fp";
  (* Source bytes unchanged *)
  require (String.equal (File.read p26) initial_bytes26) "prior-bytes-preserved";
  require (String.equal (File.read p27) initial_bytes27) "current-bytes-preserved";
  (* All 4 closing states *)
  let find_balance locus =
    List.Assoc.find_exn preview.balances (coordinate locus) ~equal:D.Effect_coordinate.equal
  in
  (* 1. Exact nonzero: wallet 10 - 3 = 7 *)
  (match find_balance "wallet" with
   | Y.Exact q -> require (Z.equal (D.Quantity.quanta q) (Z.of_int 7)) "wallet-7"
   | _ -> failwith "wallet-not-exact");
  (* 2. Exact zero: cash assertion 5 - 5 = 0 (exact zero under assertion premise) *)
  (match find_balance "cash" with
   | Y.Exact q -> require (Z.equal (D.Quantity.quanta q) Z.zero) "cash-exact-zero"
   | _ -> failwith "cash-not-exact-zero");
  (* 3. Zero_origin: tax with zero-origin support and no postings *)
  (match find_balance "tax" with
   | Y.Zero_origin -> ()
   | _ -> failwith "tax-not-zero-origin");
  (* 4. Nonzero zero-origin: food with independent premise (no observation cut), so all roots -10 + 3 + 5 = -2 *)
  (match find_balance "food" with
   | Y.Exact q -> require (Z.equal (D.Quantity.quanta q) (Z.of_int (-2))) "food-minus-2"
   | _ -> failwith "food-not-exact-nonzero");
  (* 5. Known_present: bank *)
  (match find_balance "bank" with
   | Y.Known_present -> ()
   | _ -> failwith "bank-not-known-present");
  (* 6. Unknown: salary *)
  (match find_balance "salary" with
   | Y.Unknown -> ()
   | _ -> failwith "salary-not-unknown");
  (* Reflected observation cut: cut at e_seed prevents double-counting (10 - 3 = 7, not 17) *)
  let double_count_support =
    "(zero-origin (food jpy) (tax jpy)) (openings) (observations (observation (reflected) (quantities (wallet jpy 10) (cash jpy 5)))) (presence (not-supplied))"
  in
  let dc_book = rich_book prior_entries prior_plans double_count_support in
  (match B.Q.query (B.image dc_book) (coordinate "wallet") with
   | Ok (B.Q.Exact ans) -> require (Z.equal (B.Q.quantity ans |> D.Quantity.quanta) (Z.of_int 17)) "missing-cut-double-counts"
   | _ -> failwith "dc-query-failed");
  (* Current book does not inherit prior observation *)
  let current_book = (File.load ~annual_year:2027 p27).book in
  require (Result.is_error (B.Q.query (B.image current_book) (coordinate "wallet"))) "wallet-not-in-current";
  (* Open plans: exactly p_open survives, retains stable id/date/measure/changes *)
  require (List.length preview.open_plans = 1) "only-one-open-plan";
  let op = List.hd_exn preview.open_plans in
  require (String.equal op.id "p_open") "plan-id";
  require (String.equal op.day "2026-10-10") "plan-day";
  require (String.equal op.measure "jpy") "plan-measure";
  require (Poly.equal op.changes [ ("wallet", Z.of_int (-200)); ("food", Z.of_int 200) ]) "plan-changes";
  require (Option.is_none op.paid_by) "plan-not-paid";
  require (Option.is_none op.cancelled_on) "plan-not-cancelled";
  (* Changed prior re-derivation *)
  let saved26_updated =
    let add_entry =
      "(entry extra (date 2026-07-01) (memo (none))\n\
       (postings (posting wallet jpy -1 (none)) (posting food jpy 1 (none)))\n\
       (reversal-of (none)) (exchange (none)))\n" ^ prior_entries
    in
    let book26_up = rich_book add_entry prior_plans prior_support in
    match File.publish (File.load ~annual_year:2026 p26) book26_up with
    | File.Written s -> s
    | _ -> failwith "republish-26-failed"
  in
  ignore saved26_updated;
  let preview2 = File.preview_annual_rollover ~directory:root ~year:2027 ~coordinates:coords in
  require (not (String.equal preview2.prior_fingerprint preview.prior_fingerprint)) "prior-fp-changed";
  (match List.Assoc.find_exn preview2.balances (coordinate "wallet") ~equal:D.Effect_coordinate.equal with
   | Y.Exact q -> require (Z.equal (D.Quantity.quanta q) (Z.of_int 6)) "wallet-now-6"
   | _ -> failwith "wallet-not-exact-6");
  (* Invalid inputs check *)
  let refused f = try f (); false with File.Refused _ -> true in
  require (refused (fun () -> ignore (File.preview_annual_rollover ~directory:root ~year:1 ~coordinates:coords))) "year-1-refused";
  require (refused (fun () -> ignore (File.preview_annual_rollover ~directory:root ~year:0 ~coordinates:coords))) "year-0-refused";
  require (refused (fun () -> ignore (File.preview_annual_rollover ~directory:root ~year:10000 ~coordinates:coords))) "year-10000-refused";
  require (refused (fun () -> ignore (File.preview_annual_rollover ~directory:root ~year:2025 ~coordinates:coords))) "missing-prior-refused";
  require (refused (fun () -> ignore (File.preview_annual_rollover ~directory:root ~year:2029 ~coordinates:coords))) "missing-both-refused";
  (* Unresolved artifact check *)
  let artifact = p26 ^ ".attempt-0123456789abcdef01234567.sexp" in
  File.write_new artifact "artifact";
  require (refused (fun () -> ignore (File.preview_annual_rollover ~directory:root ~year:2027 ~coordinates:coords))) "artifact-refused";
  Unix.unlink artifact;
  (* Duplicate / overlapping plan ID across prior and current *)
  let current_with_dup_plan =
    rich_book "" "(plan p_open (date 2027-01-10) (measure jpy) (changes (wallet -10) (food 10)) (paid-by (none)) (cancelled-on (none)))"
      "(zero-origin) (openings) (observations) (presence (not-supplied))"
  in
  let _ = match File.publish (File.load ~annual_year:2027 p27) current_with_dup_plan with File.Written s -> s | _ -> failwith "pub-dup-plan-failed" in
  require (refused (fun () -> ignore (File.preview_annual_rollover ~directory:root ~year:2027 ~coordinates:coords))) "dup-plan-refused";
  (* Restore clean 2027 *)
  let _ = match File.publish (File.load ~annual_year:2027 p27) (rich_book "" "" "(zero-origin) (openings) (observations) (presence (not-supplied))") with File.Written s -> s | _ -> failwith "pub-clean-failed" in
  (* Duplicate / overlapping entry ID across prior and current *)
  let current_with_dup_entry =
    rich_book "(entry spend (date 2027-01-01) (memo (none)) (postings (posting wallet jpy -1 (none)) (posting food jpy 1 (none))) (reversal-of (none)) (exchange (none)))" ""
      "(zero-origin) (openings) (observations) (presence (not-supplied))"
  in
  let _ = match File.publish (File.load ~annual_year:2027 p27) current_with_dup_entry with File.Written s -> s | _ -> failwith "pub-dup-entry-failed" in
  require (refused (fun () -> ignore (File.preview_annual_rollover ~directory:root ~year:2027 ~coordinates:coords))) "dup-entry-refused";
  (* Restore clean 2027 again *)
  let _ = match File.publish (File.load ~annual_year:2027 p27) (rich_book "" "" "(zero-origin) (openings) (observations) (presence (not-supplied))") with File.Written s -> s | _ -> failwith "pub-clean-failed" in
  (* Cross-process lock contention check via deterministic pipe handshake *)
  let ready_r, ready_w = Unix.pipe () in
  let release_r, release_w = Unix.pipe () in
  let pid = Unix.fork () in
  if pid = 0 then (
    Unix.close ready_r;
    Unix.close release_w;
    (try
       File.with_writer p26 (fun () ->
         let _ = Unix.write ready_w (Bytes.of_string "L") 0 1 in
         let buf = Bytes.create 1 in
         let _ = Unix.read release_r buf 0 1 in
         ());
       Unix.close ready_w;
       Unix.close release_r;
       Unix._exit 0
     with _ -> Unix._exit 1)
  ) else (
    Unix.close ready_w;
    Unix.close release_r;
    Stdlib.Fun.protect
      ~finally:(fun () ->
        (try ignore (Unix.write release_w (Bytes.of_string "R") 0 1) with Unix.Unix_error _ -> ());
        (try Unix.close release_w with Unix.Unix_error _ -> ());
        (try Unix.close ready_r with Unix.Unix_error _ -> ());
        let _, status = Unix.waitpid [] pid in
        require (Poly.equal status (Unix.WEXITED 0)) "child-clean-exit")
      (fun () ->
        let ready_buf = Bytes.create 1 in
        let count = Unix.read ready_r ready_buf 0 1 in
        require (count = 1) "child-lock-ready";
        let contention_refused =
          try
            ignore (File.preview_annual_rollover ~directory:root ~year:2027 ~coordinates:coords);
            false
          with File.Refused _ -> true
        in
        require contention_refused "lock-contention-refused")
  );
  [%expect {| |}]

let%expect_test "annual envelopes refuse bounded history support instead of dropping it" =
  let prior = fixture "2026-03-01" in
  let bounded = get (B.with_bounded_history prior [ ("wallet", "jpy", "2026-01-01") ]) in
  let reference = { Bakhlo_sexp.Annual_book.year = 2026; fingerprint = String.make 32 '0' } in
  Stdio.print_endline
    (match Bakhlo_sexp.Annual_book.start ~year:2027 ~reference ~prior:bounded with
    | Ok _ -> "written"
    | Error why -> why);
  [%expect {| annual-bounded-history-unsupported |}]
