open Base
module D = Bakhlo_domain
module Y = Bakhlo_sexp.Year_read
module B = Bakhlo_sexp.Daily_book

let fixture entries support =
  "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
   (measures (measure jpy 0)) (labels (not-supplied))\n\
   (approved-loci (not-supplied)) (entries " ^ entries ^ ") (plans)\n(support " ^ support ^ ")"

let prior =
  fixture
    "(entry spend (date 2025-06-01) (memo (none))\n\
     (postings (posting wallet jpy -3 (none)) (posting food jpy 3 (none)))\n\
     (reversal-of (none)) (exchange (none)))"
    "(zero-origin (food jpy) (tax jpy)) (openings)\n\
     (observations (observation (reflected) (quantities (wallet jpy 10))))\n\
     (presence (provided (reflected) (coordinates (bank jpy))))"

let current = fixture "" "(zero-origin) (openings) (observations) (presence (not-supplied))"

(* Synthetic authority ONLY: no fixture source is exported by the library.
   Selection and originals are captured atomically in one immutable snapshot. *)
module Source = struct
  type snapshot = { selection : Y.selection; originals : Y.original list }

  let initial =
    let originals : Y.original list =
      [
        { generation = 1; year = 2025; revision = 1; contents = prior };
        { generation = 1; year = 2026; revision = 1; contents = current };
      ]
    in
    let years =
      List.map originals ~f:(fun o ->
          { Y.year = o.year; revision = o.revision; fingerprint = Y.fingerprint o.contents })
    in
    { selection = { Y.generation = 1; years }; originals }

  let state = ref (Ok initial)
  let acquire () = !state
  let selection s = s.selection

  let read s ~year =
    match List.find s.originals ~f:(fun o -> Int.equal o.year year) with
    | Some original -> Ok original
    | None -> Error (Y.Original_missing year)
end

module R = Y.Make (Source)

let get = function Ok x -> x | Error _ -> failwith "unexpected refusal"

let session snapshot =
  Source.state := Ok snapshot;
  get (R.begin_session ())

let carry s = get (R.derive_carry_forward s (get (R.load_year s ~year:2025)))

let coordinate locus =
  {
    D.Effect_coordinate.locus = get (D.Identifier.Locus.of_string locus);
    measure = get (D.Identifier.Measure.of_string "jpy");
  }

let refusal result check =
  match result with Error e -> assert (check e) | Ok _ -> failwith "unexpected success"

let%expect_test "verified years and derived categories, without synthetic observation" =
  let s = session Source.initial in
  let read = get (R.read_with_carry s ~year:2026 (carry s)) in
  List.iter [ "wallet"; "food"; "tax"; "bank"; "salary" ] ~f:(fun locus ->
      let label =
        match R.carry_balance read (coordinate locus) with
        | Y.Exact q -> Z.to_string (D.Quantity.quanta q)
        | Y.Zero_origin -> "zero-origin"
        | Y.Known_present -> "known-present"
        | Y.Unknown -> "unknown"
      in
      Stdio.printf "%s: %s\n" locus label);
  (* Carry is not inserted into current support as an independent observation. *)
  assert (Result.is_error (B.Q.query (B.image (R.current_book read)) (coordinate "wallet")));
  [%expect
    {|
    wallet: 7
    food: 3
    tax: zero-origin
    bank: known-present
    salary: unknown
  |}]

let%expect_test "missing, corrupt and unknown selection fail closed" =
  List.iter
    [ Y.Selection_missing; Y.Selection_corrupt "checksum"; Y.Selection_unknown "unresolved" ]
    ~f:(fun error ->
      Source.state := Error error;
      refusal (R.begin_session ()) (fun actual -> Poly.equal actual error));
  let bad years =
    Source.state := Ok { Source.initial with selection = { generation = 1; years } };
    refusal (R.begin_session ()) (function Y.Selection_corrupt _ -> true | _ -> false)
  in
  let first = List.hd_exn Source.initial.selection.years in
  bad [ first; first ];
  bad [ { first with revision = 0 } ];
  let s = session { Source.initial with selection = { generation = 1; years = [] } } in
  refusal (R.load_year s ~year:2025) (function Y.Year_missing 2025 -> true | _ -> false);
  [%expect {| |}]

let%expect_test "selection changes reject stale carry; old session remains pinned" =
  let s = session Source.initial in
  let cf = carry s in
  let changed f =
    {
      Source.initial with
      selection =
        {
          generation = 2;
          years =
            List.map Source.initial.selection.years ~f:(fun selected ->
                if Int.equal selected.year 2025 then f selected else selected);
        };
    }
  in
  let updated = session (changed (fun selected -> { selected with revision = 2 })) in
  refusal (R.read_with_carry updated ~year:2026 cf) (function
    | Y.Revision_mismatch { year = 2025; expected = 2; actual = 1 } -> true
    | _ -> false);
  let changed_bytes =
    session (changed (fun selected -> { selected with fingerprint = Y.fingerprint (prior ^ "\n") }))
  in
  refusal (R.read_with_carry changed_bytes ~year:2026 cf) (function
    | Y.Fingerprint_mismatch 2025 -> true
    | _ -> false);
  let fresh = session Source.initial in
  refusal (R.read_with_carry fresh ~year:2026 cf) (function Y.Mixed_session -> true | _ -> false);
  ignore (get (R.read_with_carry s ~year:2026 cf));
  refusal (R.read_with_carry s ~year:2027 cf) (function
    | Y.Not_previous_year { prior = 2025; current = 2027 } -> true
    | _ -> false);
  [%expect {| |}]

let%expect_test "original bytes and tags checked, not just a matching header" =
  let test f check =
    let snapshot = { Source.initial with originals = List.map Source.initial.originals ~f } in
    refusal (R.load_year (session snapshot) ~year:2025) check
  in
  let prior_only f (o : Y.original) = if Int.equal o.year 2025 then f o else o in
  test
    (prior_only (fun o -> { o with generation = 2 }))
    (function Y.Mixed_generation { expected = 1; actual = 2 } -> true | _ -> false);
  test
    (prior_only (fun o -> { o with revision = 2 }))
    (function Y.Revision_mismatch { year = 2025; expected = 1; actual = 2 } -> true | _ -> false);
  test
    (prior_only (fun o -> { o with contents = prior ^ "\n" }))
    (function Y.Fingerprint_mismatch 2025 -> true | _ -> false);
  let module Wrong_year = struct
    include Source

    let read snapshot ~year =
      Result.map (Source.read snapshot ~year) ~f:(fun o -> { o with year = year + 1 })
  end in
  let module Wrong_reader = Y.Make (Wrong_year) in
  Source.state := Ok Source.initial;
  refusal
    (Wrong_reader.load_year (get (Wrong_reader.begin_session ())) ~year:2025)
    (function Y.Year_mismatch { expected = 2025; actual = 2026 } -> true | _ -> false);
  let missing = session { Source.initial with originals = [] } in
  refusal (R.load_year missing ~year:2025) (function Y.Original_missing 2025 -> true | _ -> false);
  let s =
    session
      {
        Source.initial with
        originals =
          List.map Source.initial.originals ~f:(fun o ->
              if Int.equal o.year 2026 then { o with generation = 2 } else o);
      }
  in
  refusal
    (R.read_with_carry s ~year:2026 (carry s))
    (function Y.Mixed_generation _ -> true | _ -> false);
  [%expect {| |}]

let%expect_test "matching fingerprint does not bypass format or Core admission" =
  let test contents check =
    let originals =
      List.map Source.initial.originals ~f:(fun o ->
          if Int.equal o.year 2025 then { o with contents } else o)
    in
    let years =
      List.map Source.initial.selection.years ~f:(fun selected ->
          if Int.equal selected.year 2025 then
            { selected with fingerprint = Y.fingerprint contents }
          else selected)
    in
    let s = session { Source.selection = { generation = 1; years }; originals } in
    refusal (R.load_year s ~year:2025) check
  in
  test "(bakhlo-records 1)" (function Y.Unsupported_format 2025 -> true | _ -> false);
  test (String.substr_replace_all prior ~pattern:"wallet jpy -3" ~with_:"wallet jpy -4") (function
    | Y.Admission_failed { year = 2025; reason = _ } -> true
    | _ -> false);
  test (String.substr_replace_all prior ~pattern:"2025-06-01" ~with_:"2024-06-01") (function
    | Y.Entry_outside_year { year = 2025; entry = "spend" } -> true
    | _ -> false);
  [%expect {| |}]

let%expect_test "read-only boundary leaves synthetic original bytes and metadata unchanged" =
  let path = Stdlib.Filename.temp_file "bakhlo-year-read-" ".sexp" in
  Exn.protect
    ~f:(fun () ->
      Stdlib.Out_channel.with_open_bin path (fun oc -> Stdlib.output_string oc prior);
      let before = Unix.stat path in
      let module File_source = struct
        type snapshot = Source.snapshot

        let acquire () = Ok Source.initial
        let selection = Source.selection

        let read s ~year =
          Result.map (Source.read s ~year) ~f:(fun o ->
              if Int.equal year 2025 then
                {
                  o with
                  contents = Stdlib.In_channel.with_open_bin path Stdlib.In_channel.input_all;
                }
              else o)
      end in
      let module Reader = Y.Make (File_source) in
      let s = get (Reader.begin_session ()) in
      let loaded = get (Reader.load_year s ~year:2025) in
      let cf = get (Reader.derive_carry_forward s loaded) in
      ignore (get (Reader.read_with_carry s ~year:2026 cf));
      assert (String.equal prior (Stdlib.In_channel.with_open_bin path Stdlib.In_channel.input_all));
      let after = Unix.stat path in
      assert (Float.equal before.st_mtime after.st_mtime);
      assert (Float.equal before.st_ctime after.st_ctime);
      assert (Int.equal before.st_ino after.st_ino))
    ~finally:(fun () -> Stdlib.Sys.remove path);
  [%expect {| |}]
