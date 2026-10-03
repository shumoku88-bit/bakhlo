Help is honest about the validation-only scope.

  $ loam-ocaml --help
  Usage: loam-ocaml check-movement --effect LOCUS MEASURE QUANTA [--effect ...]
  
  Validate an ordinary single-Measure movement without recording it.
  QUANTA is an exact signed decimal integer, not display currency units.
  No household data is read or written.

The actual executable retains exact split quantities beyond machine range.

  $ loam-ocaml check-movement --effect wallet jpy -18446744073709551616 --effect food jpy 18446744073709551615 --effect food jpy 1
  Movement structurally valid (not recorded).
  Measure: "jpy"
  Effects:
    1. "wallet": -18446744073709551616 quanta
    2. "food": +18446744073709551615 quanta
    3. "food": +1 quanta
  Positive total: 18446744073709551616 quanta

Semantic refusal uses exit 1 and no stdout.

  $ loam-ocaml check-movement --effect wallet jpy -5 --effect food jpy 4 >out 2>err
  [1]
  $ test ! -s out
  $ cat err
  Movement refused (not recorded).
    Measure "jpy": residual -1 quanta; expected 0.

Mixed Measures cannot be made balanced by adding their numeric quanta.

  $ loam-ocaml check-movement --effect wallet jpy -5 --effect food usd 5
  Movement refused (not recorded).
    Effect 2: Measure "usd" differs from "jpy".
  [1]

Argument refusal uses exit 2 and no stdout; no rounding or file access occurs.

  $ loam-ocaml check-movement --effect wallet jpy 1.5 >out 2>err
  [2]
  $ test ! -s out
  $ cat err
  error: Effect 1: expected a signed decimal integer, got "1.5".
  Run 'loam-ocaml --help' for usage.
  $ loam-ocaml check-movement --file /not-read
  error: unexpected argument "--file".
  Run 'loam-ocaml --help' for usage.
  [2]

No-argument launch does not pretend an interactive UI is already implemented.

  $ loam-ocaml
  error: a command is required.
  Run 'loam-ocaml --help' for usage.
  [2]

Synthetic input reaches one base-validity/exact-support preview, without writes.

  $ cp ../examples/actual-preview.fixture fixture
  $ cp fixture before
  $ loam-ocaml inspect-actual-fixture fixture wallet jpy
  Conditional Actual fixture quantity (not household admission).
  "wallet" / "jpy": asserted=1000; delta=-10; quantity=990
  $ loam-ocaml inspect-actual-fixture fixture wallet usd
  Conditional Actual fixture quantity (not household admission).
  "wallet" / "usd": asserted=5; delta=0; quantity=5
  $ loam-ocaml inspect-actual-fixture fixture empty jpy
  Conditional Actual fixture quantity (not household admission).
  "empty" / "jpy": asserted=0; delta=0; quantity=0
  $ loam-ocaml inspect-actual-fixture fixture unsupported jpy
  "unsupported" / "jpy": quantity unknown (no exact assertion in supplied fixture).
  [3]
  $ cmp fixture before

Help and syntax do not read a file; missing files never become empty success.

  $ loam-ocaml inspect-actual-fixture --help
  Usage: loam-ocaml inspect-actual-fixture FILE LOCUS MEASURE
  Read ONLY a LOAM-OCAML-ACTUAL-FIXTURE v1 synthetic file; never write.
  Base occurrence validity + exact assertion support; not full household admission.
  $ loam-ocaml inspect-actual-fixture not-read >out 2>err
  [2]
  $ test ! -s out && grep -q 'expected FILE LOCUS MEASURE' err
  $ loam-ocaml inspect-actual-fixture not-present wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'Cannot read synthetic fixture' err

Truncation, unsupported fields and invalid premises fail closed.

  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t1\nEND' >truncated
  $ loam-ocaml inspect-actual-fixture truncated wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'must end with newline' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t1\nDESCRIPTION\ta\tmetadata\nEND\n' >unsupported
  $ loam-ocaml inspect-actual-fixture unsupported wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'fixture line 2' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t1\nEVENT\ta\t1900-02-29\nEND-EVENT\nEND\n' >date
  $ loam-ocaml inspect-actual-fixture date wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'invalid ISO occurrence date' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t1\nGROUP\nREFLECT\tabsent\nEND-GROUP\nEND\n' >cut
  $ loam-ocaml inspect-actual-fixture cut wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'unknown root' err
