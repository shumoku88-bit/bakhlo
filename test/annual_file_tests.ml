open Base
module B = Bakhlo_sexp.Daily_book
module Scope = Bakhlo_sexp.Annual_scope
module File = Daily_file

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
  require (Scope.of_string "2026" = Ok 2026) "parse";
  require (Result.is_error (Scope.of_string "0000")) "zero-year";
  require (Result.is_error (Scope.of_string "26")) "short-year";
  require (Result.is_error (Scope.of_string "202x")) "invalid-year";
  require (Scope.check_path ~year:2026 "/tmp/books/2026.sexp" = Ok ()) "year-name";
  require (Result.is_error (Scope.check_path ~year:2026 "/tmp/books/2027.sexp")) "wrong-name";
  require (Scope.check_book ~year:2026 (fixture "2026-12-31") = Ok ()) "last-day";
  require (Scope.check_book ~year:2027 (fixture "2027-01-01") = Ok ()) "next-year";
  require
    (Scope.check_book ~year:2026 (fixture "2027-01-01")
      = Error "annual-entry-outside-year:spend")
    "cross-year-correction";
  [%expect {| |}]

let%expect_test "opt-in annual storage uses existing writer; wrong-year commits cannot alter file" =
  let root = Stdlib.Filename.temp_file "bakhlo-annual-scope-" "" in
  Stdlib.Sys.remove root;
  Unix.mkdir root 0o700;
  let p26 = Stdlib.Filename.concat root "2026.sexp" in
  let p27 = Stdlib.Filename.concat root "2027.sexp" in
  let annual26 = File.create_empty ~annual_year:2026 ~path:p26 ~measure:"jpy" ~scale:0 in
  let annual27 = File.create_empty ~annual_year:2027 ~path:p27 ~measure:"jpy" ~scale:0 in
  let old27 = File.read p27 in
  let original26 = fixture "2026-12-31" in
  let saved26 =
    match File.publish annual26 original26 with
    | File.Written saved -> saved
    | _ -> failwith "first-save-refused"
  in
  require (B.entry_count (File.load ~annual_year:2026 p26).book = 1) "cold-open-2026";
  require (B.entry_count (File.load ~annual_year:2027 p27).book = 0) "cold-open-2027";
  require (File.read p27 = old27) "other-year-mutated";
  let original26_bytes = File.read p26 in
  (match File.publish saved26 (fixture "2027-01-01") with
   | File.Refused_input "annual-entry-outside-year:spend" -> ()
   | _ -> failwith "wrong-year-publication-not-refused");
  require (File.read p26 = original26_bytes) "cross-year-mutated-original";
  let corrected26 = fixture "2026-11-30" in
  (match File.publish saved26 corrected26 with
   | File.Written _ -> ()
   | _ -> failwith "within-year-correction-refused");
  require
    (List.map (B.entries (File.load ~annual_year:2026 p26).book) ~f:(fun e -> e.day)
      = [ "2026-11-30" ])
    "same-year-cold-correction";
  require (File.read p27 = old27) "correction-touched-other-year";
  require (Result.is_error (Scope.check_path ~year:2026 p27)) "year-mismatch";
  let refused f = try f (); false with File.Refused _ -> true in
  require (refused (fun () -> ignore (File.load ~annual_year:2026 p27))) "wrong-year-selection";
  require (refused (fun () -> ignore (File.create_empty ~annual_year:2026
    ~path:(Stdlib.Filename.concat root "wrong.sexp") ~measure:"jpy" ~scale:0)))
    "unsafe-annual-create";
  ignore annual27;
  [%expect {| |}]
