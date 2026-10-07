# Bakhlo

A household question machine that works without AI. An independent OCaml engine for
small explicit questions, exact quantities, retained evidence and honest uncertainty.
Friendly presentation stays separate from strict meanings. AI is an optional untrusted entrance,
not a household-specialist language model, required runtime or source of facts.

**Development-only. Existing Lean LOAM remains the sole operational household authority.**
No household writes, migration, production storage, durable Saved or full-household admission.

## What works now

- An immutable, presentation-independent engine: Base + Zarith, unbounded signed integer
  quanta, distinct identity roles and Measures. No float conversion or identity normalization.
- Whole supplied-source admission before lookup, retained correction/date/metadata evidence,
  and independent quantity support. Activity or net zero never establishes support.
- Structured exact quantities with supplied premises/provenance, known nonzero presence with
  unknown amount, or typed unavailable/refusal. Terminal text is not the shared API.
- A [narrow quantity answer](application/current_quantity_answer.mli) and Japanese `--summary`:
  exact/presence/unknown without raw history or input diagnostics. Not auth or a sandbox.
- [Pure ordinary Movement proposals](text/propose.mli) for the experimental text profile:
  add/correct explicit supplied facts, retain every base byte, whole-admit the candidate.
  Not recording permission, a full-world encoder or an adopted storage format.
- Read-only CLI entrances and three scoped pure readers:
  - [`bakhlo.sexp`](sexp/book.mli): minimal versioned ordinary-quantity evidence book,
    explicit Measure/scale, initial support, expense and retained correction history.
    Pure whole-admitted proposals and fresh candidate-file staging; never overwrite or claim Saved.
  - [`bakhlo.text`](text/read.mli): experimental ordinary-Actual text profile.
  - [`bakhlo.loam_read`](loam_read/read.mli): supplied LOAM HouseholdImage v2, representable
    Actual plus four explicit quantity-support sections. Unsupported Actual evidence refuses;
    other sections remain opaque and unadmitted.

These are conditional answers about supplied evidence, not household truth, spending rights
or recording. File reading alone does not establish a coherent live snapshot. Fixture v2
remains a synthetic comparison input, not canonical storage.

## Build and try

```sh
./tools/bootstrap
./tools/check
./tools/opam exec -- dune exec bakhlo -- --help
./tools/opam exec -- dune exec bakhlo -- check-movement \
  --effect wallet jpy -1000 --effect food jpy 1000
./tools/opam exec -- dune exec bakhlo -- inspect-current-text --summary \
  examples/ordinary-quantity.bakhlo wallet jpy food jpy
./tools/opam exec -- dune exec bakhlo -- inspect-current-text --explain \
  examples/ordinary-quantity.bakhlo wallet jpy
./tools/opam exec -- dune exec bakhlo -- inspect-loam-quantity \
  examples/loam-quantity.loam-input wallet jpy
```

The [synthetic S-expression walkthrough](examples/ordinary-sexp/README.md) runs start → expense →
correction → cold read using fresh candidate files. Wallet `1000 → 900 → 850`; unknown Bank stays
unknown. It does not adopt a store/UI or authorize real recording.

Both text/LOAM wallet queries yield supplied assertion `1000` + unreflected delta `-10` = `990`.
All three readers accept multiple `LOCUS MEASURE` pairs on one admitted input;
Choose `--summary` for Japanese answers/check guidance or `--explain` for owner provenance.
Summary withholds raw success/failure detail, but permitted quantities/coordinates remain sensitive.
No subtotal or activity-derived support. Exit 3 if any question is unsupported, else 4 for
known presence/unknown amount, else 0 (stdout). Failures use stderr: 1 for input/admission,
2 for arguments; text/S-expression syntax/profile refusals also use 2.
Candidate staging uses 5 for uncertain output attempts and retains any artifacts; no blind retry.
Use `COMMAND --help` for scope. Checking a Movement is **not recording it**.
Setup is repository-local; [development](docs/DEVELOPMENT.md) owns prerequisites and commands.
Tests use existing native OCaml `ppx_expect` / `Base_quickcheck`; no Python bridge or generated
payload pipeline. Qualified hosts and per-increment limits are in [verification](docs/VERIFICATION.md).

## Direction

Human-readable evidence and data sovereignty come before physical store adoption. Canonical
S-expression syntax is selected; the bounded development book above is implemented with
Parsexp v0.17.0. Whole-household schema and physical store remain unadopted; SQLite canonical
adoption is paused. User prioritizes an ordinary record/reopen/correct/backup loop, not full
LOAM parity. Readability/maintenance/extension remain requirements; [safe data interchange](docs/ARCHITECTURE.md#safe-data-interchange)
is deferred behind daily use. Its adapters are not implemented or compatibility-qualified.
Unix is the near-term runtime, MirageOS an explicit future goal with experimental support only.
Permanent UI,
AI/voice/network adapters and operational publication remain separate work. Prior storage/runtime
trials are comparison evidence, not dependencies or production defaults. Both ignored native TUIs
now connect the existing Unix trial: synthetic record/select → exit → reopen → correction, retained
original history, ja/en display and honest uncertain-result checks. Same-currency Wallet/Bank
transfer and income to either receiver are now included; normal display keeps internal IDs in
detail view. Explicit closed synthetic backup/verification and fresh-namespace restore now
retain complete history/receipts; existing targets and incomplete copies refuse.
[Handoff](docs/HANDOFF.md#completed-bounded-task--synthetic-closed-backuprestore)
owns launch instructions; [verification](docs/VERIFICATION.md#synthetic-closed-backuprestore)
owns controls/limits. It does **not** qualify durable Saved, real-data recording or a main store.
[Explicit synthetic initial quantities](docs/VERIFICATION.md#explicit-synthetic-initial-quantities)
now let BOTH existing trials start from supplied Wallet/Bank values in all four currencies,
without missing -> zero, overwriting or changing old support. Record/reopen/correct and complete
backup/fresh restore connections pass; this still uses the experimental text Store, not an
adopted canonical codec or permission for real recording. Those paragraphs describe earlier text
trials. The latest [simple S-expression UI loop](docs/VERIFICATION.md#simple-s-expression-ui-loop)
now uses Book in BOTH existing screens: input → write → exit/reopen → correction, preserving originals.
No new UI/backend, legacy conversion or real-data use. [Handoff](docs/HANDOFF.md#completed-bounded-task--existing-synthetic-ui--s-expression-connection)
links the ready-to-try initial-1000 synthetic demo; human feedback comes before more infrastructure.
Review [four synthetic S-expression candidates](examples/sexp-v1-candidate/README.md) alongside
[the same four in delimiter-free plain text](examples/plain-v1-candidate/README.md):
selected self-contained EVIDENCE generation, not flattened current state. Superseded Events,
relations, observations/cuts and policy/provenance remain. Parser/writer/migration are explicitly
NOT implemented or authorized by those broader fixture-only steps; the separate ordinary-quantity
profile above is the currently implemented bounded codec.

## Where to look

- [Semantic contract](docs/SEMANTIC_CONTRACT.md): meanings that must survive.
- [Architecture](docs/ARCHITECTURE.md) and `.mli` files: boundaries, profiles and invariants.
- [Verification](docs/VERIFICATION.md): actual evidence, counterexamples and limits.
- [Development](docs/DEVELOPMENT.md): isolated toolchain and optional formatting.
- [Handoff](docs/HANDOFF.md): next work and evidence-based maintenance revisit triggers.
- [References](docs/REFERENCES.md), [contributing](CONTRIBUTING.md), [pit instructions](AGENTS.md).

No unreleased API/storage compatibility promise. No public release, licensing/source-reuse
permission or operational cutover follows from a local build, test or commit.
