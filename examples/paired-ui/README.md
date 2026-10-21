# Synthetic paired UI fixture

This fixture is a **procedure**, not a shared storage file: LOAM uses its own household directory and Bakhlo uses a separate Daily book. Both are created from scratch with synthetic data; never point either command at a household authority or an existing trial.

## Supported scenario: two balanced JPY Records and Actual search

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

From Home, record two Actuals with explicit dates and jpy postings:

- `paired snack`, 2026-10-16: `wallet -37`, `food +37`
- `other meal`, 2026-10-17: `wallet -11`, `food +11`

After both are published, inspect Actual. At 80×24, press `/` and search `paired`
(only the first record), then replace it with `other` (only the second), then
search `zzzz` (no matches). Escape restores both entries.
With search active on `paired`, resize through 48×14 and 32×9; at 32×9 replace
it with `other`, then restore 48×14 and 80×24. Escape returns both entries.
Exit and reopen: Actual is unfiltered and still contains both dates, descriptions and
signed postings. Bytes and IDs differ by format and are not compared.

The first-run Record flow and search were exercised at 80×24 in separate fresh roots.
The search roots started with the paired synthetic entry and added `other meal` via
both UIs; the combined procedure above was not rerun end to end from empty roots. See
[Record evidence](../../docs/VERIFICATION.md#fresh-root-paired-record-and-cold-reopen-2026-10-16)
and [search evidence](../../docs/VERIFICATION.md#paired-actual-search-2026-10-17).

## Known limits

This procedure does not seed balances, roles, observations, Scheduled plans, correction/refund cases, multiple currencies, empty-vs-unknown comparisons, invalid-input refusals, or save failures. Search evidence covers two matching records, no-match and Escape at 80×24; the rebuilt Bakhlo binary retained active `/paired` through resize to 48×14 with `+37 jpy` visible, and `/other` at 48×14 showed `+11 jpy`. The 32×9 Description-only/clipped result is from an earlier binary and was not rerun after the fix. Other dimensions, caret position, scope/sort interaction, long/CJK input, LOAM source/binary correspondence, IME behavior, and operational adoption remain unqualified. Build no LOAM source; use only the existing executable. Never use `./tools/compare refresh` for this fixture.
