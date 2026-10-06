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
- Read-only CLI entrances and two scoped pure readers:
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

Both wallet queries yield supplied assertion `1000` + unreflected delta `-10` = `990`.
The text and LOAM readers accept multiple `LOCUS MEASURE` pairs on one admitted input;
Choose `--summary` for Japanese answers/check guidance or `--explain` for owner provenance.
Summary withholds raw success/failure detail, but permitted quantities/coordinates remain sensitive.
No subtotal or activity-derived support. Exit 3 if any question is unsupported, else 4 for
known presence/unknown amount, else 0 (stdout). Failures use stderr: 1 for input/admission,
2 for arguments; experimental text syntax/profile refusals also use 2.
Use `COMMAND --help` for scope. Checking a Movement is **not recording it**.
Setup is repository-local; [development](docs/DEVELOPMENT.md) owns prerequisites and commands.
Tests use existing native OCaml `ppx_expect` / `Base_quickcheck`; no Python bridge or generated
payload pipeline. Qualified hosts and per-increment limits are in [verification](docs/VERIFICATION.md).

## Direction

Human-readable evidence and data sovereignty come before physical store adoption. Canonical
S-expression syntax is selected; exact schema/codec/store remain unadopted and SQLite canonical
adoption is paused. Unix is the near-term runtime, MirageOS an explicit future goal with
experimental support only. Permanent UI,
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
Further prototype expansion is paused after the [canonical evidence/format review](docs/ARCHITECTURE.md#canonical-evidence--inherited-format-review).
Next are [four hand-authored synthetic S-expression v1 candidates](examples/sexp-v1-candidate/README.md):
selected self-contained EVIDENCE generation, not flattened current state. Superseded Events,
relations, observations/cuts and policy/provenance remain. Parser/writer/migration are explicitly
NOT implemented or authorized in this fixture-only step.

## Where to look

- [Semantic contract](docs/SEMANTIC_CONTRACT.md): meanings that must survive.
- [Architecture](docs/ARCHITECTURE.md) and `.mli` files: boundaries, profiles and invariants.
- [Verification](docs/VERIFICATION.md): actual evidence, counterexamples and limits.
- [Development](docs/DEVELOPMENT.md): isolated toolchain and optional formatting.
- [Handoff](docs/HANDOFF.md): next work and evidence-based maintenance revisit triggers.
- [References](docs/REFERENCES.md), [contributing](CONTRIBUTING.md), [pit instructions](AGENTS.md).

No unreleased API/storage compatibility promise. No public release, licensing/source-reuse
permission or operational cutover follows from a local build, test or commit.
