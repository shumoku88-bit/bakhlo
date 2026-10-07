open Base

module C = Bakhlo_text.Canonical_sexp

let ok = function Ok value -> value | Error _ -> failwith "expected S-expression syntax success"

let error_name = function
  | C.Syntax _ -> "syntax"
  | Missing_format_marker -> "missing-marker"
  | Invalid_format_marker -> "invalid-marker"
  | Unsupported_format_version _ -> "unsupported-version"
  | Duplicate_format_marker -> "duplicate-marker"

let%expect_test "multiple forms round-trip structurally and retain unknown forms" =
  let source =
    {|
; layout/comment bytes are intentionally not canonical evidence
(bakhlo 1)

(event "e1"
  (day (date "2000-01-10"))
  (effect
    (key (named "cash"))
    (locus "wallet")
    (measure "jpy")
    (quanta -10)))

(future-family
  (opaque
    (nested "kept")))
|}
  in
  let first = ok (C.of_string source) in
  let rendered = C.to_string first in
  let second = ok (C.of_string rendered) in
  Printf.printf
    "stable=%b unknown=%b comment-retained=%b\n"
    (String.equal rendered (C.to_string second))
    (String.is_substring rendered ~substring:"future-family")
    (String.is_substring rendered ~substring:"layout/comment");
  [%expect {| stable=true unknown=true comment-retained=false |}]

let%expect_test "format marker failures stay distinct from syntax failures" =
  let cases =
    [
      "";
      "(event \"e1\")";
      "(bakhlo)";
      "(bakhlo 2)";
      "(bakhlo 1) (bakhlo 1)";
      "(bakhlo 1";
    ]
  in
  List.iter cases ~f:(fun input ->
      match C.of_string input with
      | Ok _ -> print_endline "unexpected-success"
      | Error error -> print_endline (error_name error));
  [%expect
    {|
    missing-marker
    missing-marker
    invalid-marker
    unsupported-version
    duplicate-marker
    syntax |}]

let%expect_test "parse refusal carries a source location and message" =
  match C.of_string "(bakhlo 1\n" with
  | Error (C.Syntax { line; column; message }) ->
      Printf.printf
        "line=%d nonnegative-column=%b message=%b\n"
        line
        (column >= 0)
        (not (String.is_empty message))
  | Error _ -> print_endline "wrong-error"
  | Ok _ -> print_endline "unexpected-success";
  [%expect {| line=1 nonnegative-column=true message=true |}]
