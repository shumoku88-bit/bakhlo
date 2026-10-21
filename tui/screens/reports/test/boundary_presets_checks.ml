(* boundary-presets.tsv is read by Daily Pace, its Trend, Income & Expense,
   Trend / Locus and Multicurrency Spend through one parser, so they agree. *)
let require condition why = if not condition then failwith why

let self_check () =
  let plain = "pension\t2026-08-15\t2026-10-15\t2026-12-15\nsalary\t2026-10-01\t2026-11-01\n" in
  let expected =
    Ok
      [
        ("pension", [ "2026-08-15"; "2026-10-15"; "2026-12-15" ]);
        ("salary", [ "2026-10-01"; "2026-11-01" ]);
      ]
  in
  require (Boundary_presets.parse plain = expected) "plain-presets";
  (* CRLF, comments, blank lines and surrounding spaces read the same. *)
  let crlf =
    "# cycles\r\npension\t2026-08-15\t2026-10-15\t2026-12-15\r\n\r\n  salary\t2026-10-01\t2026-11-01  \r\n"
  in
  require (Boundary_presets.parse crlf = expected) "crlf-comment-blank-presets";
  List.iter
    (fun (label, text) -> require (Boundary_presets.parse text = Error ()) label)
    [
      ("one-date", "pension\t2026-08-15\n");
      ("repeated-name", "a\t2026-01-01\t2026-02-01\na\t2026-03-01\t2026-04-01\n");
      ("not-increasing", "a\t2026-02-01\t2026-01-01\n");
      ("not-canonical", "a\t2026-1-01\t2026-02-01\n");
      ("not-real", "a\t2026-02-30\t2026-03-01\n");
      ("name-with-space", "a b\t2026-01-01\t2026-02-01\n");
    ];
  let presets = Result.get_ok expected in
  require
    (Boundary_presets.windows presets
    = [
        ("pension", "2026-08-15", "2026-10-15");
        ("pension", "2026-10-15", "2026-12-15");
        ("salary", "2026-10-01", "2026-11-01");
      ])
    "half-open-windows-in-file-order";
  require
    (Boundary_presets.containing "2026-10-15" presets
    = [ ("pension", "2026-10-15", "2026-12-15"); ("salary", "2026-10-01", "2026-11-01") ])
    "start-inclusive-end-exclusive";
  require (Boundary_presets.containing "2026-12-15" presets = []) "end-exclusive";
  print_endline
    "PASS: boundary presets parse once for every screen: CRLF/comments/blank lines, refusals, \
     half-open windows."
