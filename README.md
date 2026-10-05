# Bakhlo

A household machine humans and AI can converse with. An independent OCaml engine for
exact quantities, explicit evidence, retained correction provenance and honest uncertainty.
AI proposes and explains; it does not manufacture facts or become the authority.

**Development-only. Existing Lean LOAM remains the sole operational household authority.**
No household writes, migration, production storage, durable Saved or full-household admission.

## What works now

- An immutable, presentation-independent engine: Base + Zarith, unbounded signed integer
  quanta, distinct identity roles and Measures. No float conversion or identity normalization.
- Whole supplied-source admission before lookup, retained correction/date/metadata evidence,
  and independent quantity support. Activity or net zero never establishes support.
- Structured exact quantities with supplied premises/provenance, known nonzero presence with
  unknown amount, or typed unavailable/refusal. Terminal text is not the shared API.
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
./tools/opam exec -- dune exec bakhlo -- inspect-current-text --explain \
  examples/ordinary-quantity.bakhlo wallet jpy food jpy
./tools/opam exec -- dune exec bakhlo -- inspect-loam-quantity \
  examples/loam-quantity.loam-input wallet jpy
```

Both wallet queries yield supplied assertion `1000` + unreflected delta `-10` = `990`.
The text and LOAM readers accept multiple `LOCUS MEASURE` pairs on one admitted input;
`--explain` shows supplied premises, Effect occurrences and actual correction paths.
No subtotal or activity-derived support. Exit 3 if any question is unsupported, else 4 for
known presence/unknown amount, else 0 (stdout). Failures use stderr: 1 for input/admission,
2 for arguments; experimental text syntax/profile refusals also use 2.
Use `COMMAND --help` for scope. Checking a Movement is **not recording it**.
Setup is repository-local; [development](docs/DEVELOPMENT.md) owns prerequisites and commands.
Tests use existing native OCaml `ppx_expect` / `Base_quickcheck`; no Python bridge or generated
payload pipeline. Qualified hosts and per-increment limits are in [verification](docs/VERIFICATION.md).

## Direction

Human-readable evidence and data sovereignty come before physical store adoption. Canonical
text is a candidate, not an adopted format; SQLite canonical adoption is paused. Unix is the
near-term runtime, MirageOS an explicit future goal with experimental support only. UI,
AI/voice/network adapters and publication remain separate work. Prior storage/runtime trials
are comparison evidence, not dependencies or production defaults.

## Where to look

- [Semantic contract](docs/SEMANTIC_CONTRACT.md): meanings that must survive.
- [Architecture](docs/ARCHITECTURE.md) and `.mli` files: boundaries, profiles and invariants.
- [Verification](docs/VERIFICATION.md): actual evidence, counterexamples and limits.
- [Development](docs/DEVELOPMENT.md): isolated toolchain and optional formatting.
- [Handoff](docs/HANDOFF.md): next work and evidence-based maintenance revisit triggers.
- [References](docs/REFERENCES.md), [contributing](CONTRIBUTING.md), [pit instructions](AGENTS.md).

No unreleased API/storage compatibility promise. No public release, licensing/source-reuse
permission or operational cutover follows from a local build, test or commit.
