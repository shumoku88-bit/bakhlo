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
