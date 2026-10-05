open Base
module C = Bakhlo_cli.Movement_command

let show arguments =
  let output = C.render (C.evaluate arguments) in
  Stdlib.Printf.printf "exit: %d\n" output.exit_code;
  List.iter
    [ ("stdout", output.stdout); ("stderr", output.stderr) ]
    ~f:(fun (name, text) ->
      if String.is_empty text then Stdlib.Printf.printf "%s: <empty>\n" name
      else Stdlib.Printf.printf "%s:\n%s" name text)

let%expect_test "help explicitly excludes recording and display-unit inference" =
  show [ "--help" ];
  [%expect
    {|
    exit: 0
    stdout:
    Usage: bakhlo check-movement --effect LOCUS MEASURE QUANTA [--effect ...]

    Validate an ordinary single-Measure movement without recording it.
    QUANTA is an exact signed decimal integer, not display currency units.
    No household data is read or written.
    stderr: <empty> |}]

let%expect_test "preview preserves split Effects and exact huge quantities" =
  show
    [
      "check-movement";
      "--effect";
      "wallet";
      "jpy";
      "-18446744073709551616";
      "--effect";
      "food";
      "jpy";
      "+18446744073709551615";
      "--effect";
      "food";
      "jpy";
      "0001";
    ];
  [%expect
    {|
    exit: 0
    stdout:
    Movement structurally valid (not recorded).
    Measure: "jpy"
    Effects:
      1. "wallet": -18446744073709551616 quanta
      2. "food": +18446744073709551615 quanta
      3. "food": +1 quanta
    Positive total: 18446744073709551616 quanta
    stderr: <empty> |}]

let%expect_test "syntax failures are not successful empty worlds" =
  show [];
  show [ "record" ];
  show [ "check-movement"; "--effect"; "wallet"; "jpy" ];
  show [ "check-movement"; "--file"; "/not-read" ];
  show [ "check-movement"; "--effect"; ""; "jpy"; "1" ];
  show [ "check-movement"; "--effect"; "wallet"; ""; "1" ];
  [%expect
    {|
    exit: 2
    stdout: <empty>
    stderr:
    error: a command is required.
    Run 'bakhlo --help' for usage.
    exit: 2
    stdout: <empty>
    stderr:
    error: unknown command "record".
    Run 'bakhlo --help' for usage.
    exit: 2
    stdout: <empty>
    stderr:
    error: Effect 1: --effect requires LOCUS MEASURE QUANTA.
    Run 'bakhlo --help' for usage.
    exit: 2
    stdout: <empty>
    stderr:
    error: unexpected argument "--file".
    Run 'bakhlo --help' for usage.
    exit: 2
    stdout: <empty>
    stderr:
    error: Effect 1: Locus identity must not be empty.
    Run 'bakhlo --help' for usage.
    exit: 2
    stdout: <empty>
    stderr:
    error: Effect 1: Measure identity must not be empty.
    Run 'bakhlo --help' for usage. |}]

let%expect_test "decimal grammar refuses coercion instead of using Zarith's wider grammar" =
  List.iter [ ""; "+"; "-"; "1.0"; "0x10"; "1_000"; " 1"; "1 " ] ~f:(fun text ->
      let output = C.render (C.evaluate [ "check-movement"; "--effect"; "wallet"; "jpy"; text ]) in
      if (not (Int.equal output.exit_code 2)) || not (String.is_empty output.stdout) then
        failwith "invalid decimal spelling accepted";
      Stdlib.print_string output.stderr);
  [%expect
    {|
    error: Effect 1: expected a signed decimal integer, got "".
    Run 'bakhlo --help' for usage.
    error: Effect 1: expected a signed decimal integer, got "+".
    Run 'bakhlo --help' for usage.
    error: Effect 1: expected a signed decimal integer, got "-".
    Run 'bakhlo --help' for usage.
    error: Effect 1: expected a signed decimal integer, got "1.0".
    Run 'bakhlo --help' for usage.
    error: Effect 1: expected a signed decimal integer, got "0x10".
    Run 'bakhlo --help' for usage.
    error: Effect 1: expected a signed decimal integer, got "1_000".
    Run 'bakhlo --help' for usage.
    error: Effect 1: expected a signed decimal integer, got " 1".
    Run 'bakhlo --help' for usage.
    error: Effect 1: expected a signed decimal integer, got "1 ".
    Run 'bakhlo --help' for usage. |}]

let%expect_test "domain refusal is ordered, exact, and confined to stderr" =
  show [ "check-movement" ];
  show [ "check-movement"; "--effect"; "wallet"; "jpy"; "0"; "--effect"; "food"; "usd"; "-0" ];
  show [ "check-movement"; "--effect"; "wallet"; "jpy"; "-1000"; "--effect"; "food"; "jpy"; "999" ];
  [%expect
    {|
    exit: 1
    stdout: <empty>
    stderr:
    Movement refused (not recorded).
      at least one Effect is required.
    exit: 1
    stdout: <empty>
    stderr:
    Movement refused (not recorded).
      Effect 1: quantity must be nonzero.
      Effect 2: quantity must be nonzero.
      Effect 2: Measure "usd" differs from "jpy".
    exit: 1
    stdout: <empty>
    stderr:
    Movement refused (not recorded).
      Measure "jpy": residual -1 quanta; expected 0. |}]

let%expect_test "opaque input cannot inject terminal controls or extra lines" =
  show [ "bad\027[31m\ncommand" ];
  show
    [
      "check-movement";
      "--effect";
      "wallet\nfood";
      "jpy\027[31m";
      "-1";
      "--effect";
      "food";
      "jpy\027[31m";
      "1";
    ];
  [%expect
    {|
    exit: 2
    stdout: <empty>
    stderr:
    error: unknown command "bad\027[31m\ncommand".
    Run 'bakhlo --help' for usage.
    exit: 0
    stdout:
    Movement structurally valid (not recorded).
    Measure: "jpy\027[31m"
    Effects:
      1. "wallet\nfood": -1 quanta
      2. "food": +1 quanta
    Positive total: 1 quanta
    stderr: <empty> |}]

let%expect_test "both quantity shells plan every exact coordinate pair before acquisition" =
  let module T = Bakhlo_cli.Current_text_command in
  let module L = Bakhlo_cli.Loam_quantity_command in
  let read path view =
    let label =
      match view with
      | Bakhlo_cli.Quantity_questions.Inspect -> "inspect"
      | Explain -> "explain"
      | Summary -> "summary"
    in
    Printf.sprintf "read %S; view=%s" path label
  in
  let text arguments =
    match T.plan arguments with
    | Help -> "help"
    | Refused message -> "refused: " ^ message
    | Read { path; questions = _; view } -> read path view
  in
  let loam arguments =
    match L.plan arguments with
    | Help -> "help"
    | Refused message -> "refused: " ^ message
    | Read { path; questions = _; view } -> read path view
  in
  List.iter
    [
      [ "--help" ];
      [ "--explain" ];
      [ "not-read"; "wallet"; "jpy"; "quiet" ];
      [ "not-read"; "wallet"; "jpy"; "quiet"; "" ];
      [ "--explain"; " exact path "; " wallet "; "JPY"; "wallet"; "jpy"; "wallet"; "jpy" ];
      [ "--summary"; "synthetic"; "wallet"; "jpy" ];
      [ "--summary"; "--explain"; "not-read"; "wallet"; "jpy" ];
      [ "--explain"; "--summary"; "not-read"; "wallet"; "jpy" ];
      [ "--summary"; "--summary"; "not-read"; "wallet"; "jpy" ];
    ]
    ~f:(fun arguments ->
      let t = text arguments and l = loam arguments in
      Fixtures.require (String.equal t l) "same pair mechanics, independent source profiles";
      Stdlib.print_endline t);
  [%expect
    {|
    help
    refused: expected FILE LOCUS MEASURE [LOCUS MEASURE ...]
    refused: expected FILE LOCUS MEASURE [LOCUS MEASURE ...]
    refused: coordinate identities must not be empty
    read " exact path "; view=explain
    read "synthetic"; view=summary
    refused: choose only one of --summary or --explain
    refused: choose only one of --summary or --explain
    refused: choose only one of --summary or --explain
    |}]

let%expect_test "nonempty batches preserve each outcome, ordering and duplicates without a subtotal"
    =
  let module T = Bakhlo_cli.Current_text_command in
  let bytes =
    "bakhlo-read 1 ordinary-actual-quantity\n\
     origin \"quiet\" \"jpy\"\n\
     group\n\
     assert \"wallet\" \"jpy\" 100\n\
     end-group\n\
     presence\n\
     present \"pantry\" \"jpy\"\n\
     end-presence\n\
     end\n"
  in
  let evaluate coordinates =
    match T.plan ("synthetic" :: coordinates) with
    | Read request -> T.evaluate request (Ok bytes)
    | Help | Refused _ -> failwith "valid batch refused"
  in
  List.iter
    [
      [ "wallet"; "jpy"; "wallet"; "jpy"; "quiet"; "jpy" ];
      [ "pantry"; "jpy"; "quiet"; "jpy" ];
      [ "missing"; "jpy"; "pantry"; "jpy" ];
      [ "pantry"; "jpy"; "missing"; "jpy" ];
    ]
    ~f:(fun coordinates ->
      let output = evaluate coordinates in
      Fixtures.require (String.is_empty output.stderr) "query outcomes stay on stdout";
      Stdlib.Printf.printf "exit: %d\n%s" output.exit_code output.stdout);
  [%expect
    {|
    exit: 0
    One supplied read image; independent questions (no subtotal).
    Question 1:
    Conditional text quantity (ordinary-actual-quantity v1; synthetic).
    exact assertion; "wallet" / "jpy": asserted=100; delta=0; quantity=100
    Question 2:
    Conditional text quantity (ordinary-actual-quantity v1; synthetic).
    exact assertion; "wallet" / "jpy": asserted=100; delta=0; quantity=100
    Question 3:
    Conditional text quantity (ordinary-actual-quantity v1; synthetic).
    "quiet" / "jpy": zero-origin; quantity=0
    exit: 4
    One supplied read image; independent questions (no subtotal).
    Question 1:
    "pantry" / "jpy": known nonzero (presence premise); exact quantity unknown.
    Question 2:
    Conditional text quantity (ordinary-actual-quantity v1; synthetic).
    "quiet" / "jpy": zero-origin; quantity=0
    exit: 3
    One supplied read image; independent questions (no subtotal).
    Question 1:
    "missing" / "jpy": quantity unknown (no supported premise in supplied evidence).
    Question 2:
    "pantry" / "jpy": known nonzero (presence premise); exact quantity unknown.
    exit: 3
    One supplied read image; independent questions (no subtotal).
    Question 1:
    "pantry" / "jpy": known nonzero (presence premise); exact quantity unknown.
    Question 2:
    "missing" / "jpy": quantity unknown (no supported premise in supplied evidence).
    |}]

let%expect_test
    "summary input failures preserve refusal class without raw diagnostics or partial answers" =
  let module T = Bakhlo_cli.Current_text_command in
  let doc rows =
    String.concat ~sep:"\n" (("bakhlo-read 1 ordinary-actual-quantity" :: rows) @ [ "end"; "" ])
  in
  let evaluate view contents =
    match T.plan (view @ [ "INTERNAL-FILE"; "quiet"; "jpy"; "wallet"; "jpy" ]) with
    | Read request -> T.evaluate request contents
    | Help | Refused _ -> failwith "valid planned question refused"
  in
  List.iter
    [
      (1, Error "INTERNAL-READ-ERROR");
      (2, Ok "bakhlo-read INTERNAL-VERSION ordinary-actual-quantity\nend\n");
      (2, Ok (doc [ "INTERNAL-RECORD"; "origin \"quiet\" \"jpy\"" ]));
      ( 1,
        Ok
          (doc
             [
               "event \"INTERNAL-EVENT\" \"INTERNAL-DATE\""; "end-event"; "origin \"quiet\" \"jpy\"";
             ]) );
      (1, Ok (doc [ "group"; "reflect \"INTERNAL-ROOT\""; "end-group"; "origin \"quiet\" \"jpy\"" ]));
      ( 1,
        Ok
          (doc
             [
               "event \"INTERNAL-EVENT\" \"2026-10-03\"";
               "effect key \"INTERNAL-KEY\" \"w\" \"jpy\" 1";
               "effect key \"INTERNAL-KEY\" \"other\" \"jpy\" -1";
               "end-event";
               "origin \"quiet\" \"jpy\"";
             ]) );
    ]
    ~f:(fun (code, contents) ->
      let detail = evaluate [] contents and summary = evaluate [ "--summary" ] contents in
      Fixtures.require
        (detail.exit_code = code && summary.exit_code = code && String.is_empty detail.stdout
       && String.is_empty summary.stdout)
        "failure stays failure before all questions";
      Fixtures.require
        (String.is_substring detail.stderr ~substring:"INTERNAL-")
        "owner diagnostic positive control";
      Fixtures.require
        ((not (String.is_substring summary.stderr ~substring:"INTERNAL-"))
        && String.is_substring summary.stderr ~substring:"数量には答えていません")
        "summary failure contains no raw path/payload");
  Stdlib.print_endline
    "Six acquisition/profile/structural/source/support refusals retain 1/2 and no partial stdout; \
     summary withholds diagnostics, owner detail survives.";
  [%expect
    {| Six acquisition/profile/structural/source/support refusals retain 1/2 and no partial stdout; summary withholds diagnostics, owner detail survives. |}]
