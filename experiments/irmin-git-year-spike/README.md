# Irmin-Git annual storage spike (synthetic, non-production)

Purpose: isolate exactly one question: can `irmin-git` store distinct
calendar-year paths in one history, preserve a prior commit, and publish
changes to both years through a single logical root update?

This standalone Dune project is excluded from Bakhlo's root build by
`(dirs :standard \\ scratch experiments tui)`. It does not alter
`bakhlo.opam.locked`, the Core, the UI, existing source data, or LOAM.

## Test cases

1. Seed 2026 and 2027 entries and a **synthetic, unverified** 2027 opening marker.
2. Edit 2027 and confirm 2026 is unchanged and the former commit is readable.
3. Update 2026 and the 2027 marker via **one** `Store.set_tree_exn` call.
4. Close and reopen a repository handle, confirm current contents.

The labels and opening marker are **not Bakhlo Daily_book values**. A passed
test does not certify opening balances, planned payments, unknown-versus-zero,
Core admission, actual old-year invalidation, or logical serializability.

## Run in a fresh isolated environment

The GitHub workflow uses a fresh temporary runner and OCaml 5.3.0,
installs `irmin-git.3.11.0`, then calls:

```sh
opam exec -- dune exec --root experiments/irmin-git-year-spike ./spike.exe
```

No dependency is installed automatically on the user's Mac. Do not use
Bakhlo's product switch or modify its lockfile for this experiment.

## Explicit stop/go boundary

Passing this spike qualifies **only** Git backend API/build + simple immutable
snapshot behavior. It does **not** qualify:

- `durable Saved`, fsync or power-loss consistency of Git refs and objects;
- competing readers/writers, cross-process locks, observed-HEAD CAS, retries;
- multiple family updates after crashes, lost acknowledgement (P7);
- independent one-year Core admission, carry-forward provenance and expiry;
- cross-year scheduled completion or correction/double-payment refusal;
- backup/restore off-host, object GC, long-running growth and speed.

Next authorized work should first connect a verified root selection and actual
Bakhlo Core to a two-year synthetic fixture, then inject failure around ref
selection before any product backend adoption. If the proof becomes more
complicated than the year-per-book goal, stop and compare to plain year-S-expressions
and SQLite rather than developing a second persistence framework.

References: `docs/archive/IRMIN_PHASE2_RESULTS.ja.md`,
`docs/archive/YEAR_PARTITION_RESEARCH_INVENTORY.ja.md`,
`sexp/year_read.mli`.
