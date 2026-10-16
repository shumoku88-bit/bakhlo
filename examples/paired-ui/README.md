# Synthetic paired UI fixture

This fixture is a **procedure**, not a shared storage file: LOAM uses its own household directory and Bakhlo uses a separate Daily book. Both are created from scratch with synthetic data; never point either command at a household authority or an existing trial.

## Supported scenario: one balanced JPY Record

Use fresh, unique paths under ignored `scratch/` for every run. Keep both terminals at 80×24 with `TERM=xterm-256color` for the paired case.

LOAM:

```sh
mkdir -p scratch/paired-ui-LOAM-UNIQUE scratch/paired-ui-BAKHLO-UNIQUE
../loam/.lake/build/bin/loam init scratch/paired-ui-LOAM-UNIQUE/household
../loam/.lake/build/bin/loam tui scratch/paired-ui-LOAM-UNIQUE/household
```

Bakhlo:

```sh
./tools/tui --book scratch/paired-ui-BAKHLO-UNIQUE/book.sexp
```

In each UI, explicitly admit `wallet` and `food` through Commands → Household setup → Manage Loci. In Bakhlo, first-run creates an empty book with Measure `jpy`, scale `0`; confirm the displayed destination before creation. Use unique unused paths under `scratch/` for each run.

From Home, record one Actual on the selected date:

- Description: `paired snack`
- `wallet`: `-37 jpy`
- `food`: `+37 jpy`

Review the Preview, publish explicitly, inspect Actual, then exit and reopen each UI. Expected semantic result: one Actual with the same selected date, description and signed postings. Storage bytes and generated IDs are implementation-specific and are not compared. The paired semantic path has been executed; the exact setup recipe above has not yet been repeated end to end.

## Known limits

This procedure does not seed balances, roles, observations, Scheduled plans, correction/refund cases, multiple currencies, empty-vs-unknown comparisons, invalid-input refusals, or save failures. It does not provide one byte-identical fixture for both formats. The paired Record run does not qualify those cases, other terminal sizes, LOAM source/binary correspondence, IME behavior, or operational adoption. Build no LOAM source; use only the existing executable. Never use `./ui --refresh` for this fixture.
