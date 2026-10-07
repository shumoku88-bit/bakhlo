# Isolated Parsexp codec trial

This directory is a **disposable synthetic experiment**, not the Bakhlo production package and
not a canonical-format cutover.

It asks whether the current minimal S-expression direction is mechanically pleasant enough to
justify a later production codec decision.

## What it exercises

The trial uses Jane Street `parsexp v0.17.0` and `sexplib0 v0.17.0` outside the main package.

The executable:

- parses multiple top-level S-expressions with `Parsexp.Many.parse_string`;
- decodes a deliberately bounded explicit Wire V1 subset: header, collection states, Measure,
  Event, Effect, arbitrary-precision quanta;
- refuses malformed known records instead of treating them as opaque;
- preserves unsupported top-level forms as opaque `Sexplib0.Sexp.t` values;
- canonicalizes decoded known records back to S-expressions;
- reparses and checks writer stability;
- verifies a `Zarith` quantity far beyond machine integer range;
- verifies one unknown future top-level form survives the bounded decoder unchanged;
- emits a small machine-readable-ish summary suitable for an export-boundary sanity check;
- reports an informational 10,000-parse timing/allocation sample.

The normal parser intentionally does **not** preserve comments or original whitespace. This trial
tests semantic/AST retention and canonical rewriting, not byte-for-byte source reproduction.
If lexical preservation becomes a requirement, Parsexp's CST parser is a separate later question.

## Important limits

This is not full Bakhlo admission. Most current household forms in
`examples/syntax-bakeoff/01-minimal.sexp` are intentionally opaque to the bounded decoder.

That is useful here: it tests whether a V1 reader can understand a small owned subset while
retaining unrelated top-level evidence without pretending to validate it.

The trial does not:

- change `bakhlo.opam`, `bakhlo.opam.locked` or any production Dune library;
- read or write private household data;
- implement Saved, persistence, migration, recovery or publication;
- prove unknown nested fields inside a known record can be retained;
- establish performance guarantees from GitHub-hosted runner timings;
- select Parsexp or S-expressions for production.

## Run locally

From this directory, with OCaml 5.3.0 and the trial dependencies installed. The main root
excludes `experiments`; explicit `--root .` keeps these commands in this independent workspace:

```sh
opam install . --deps-only -y
opam exec -- dune build --root .

opam exec -- dune exec --root . ./codec_trial.exe -- \
  check ../../examples/syntax-bakeoff/01-minimal.sexp probe.sexp

opam exec -- dune exec --root . ./codec_trial.exe -- \
  bench ../../examples/syntax-bakeoff/01-minimal.sexp 10000
```

The repository PR workflow runs exactly this isolated experiment. A merge would retain the
experiment and its path-scoped workflow, but would still **not** make Parsexp a dependency of the
main Bakhlo package.
