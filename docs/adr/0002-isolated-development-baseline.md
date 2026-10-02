# ADR 0002 — Isolated, locked development baseline

Status: IMPLEMENTED and locally tested on macOS x86_64, 2026-10-02.
Authorization: the user approved creating an isolated project opam environment.
The following version choices are the resulting engineering baseline, not a
claim that the user separately selected each version or that all targets pass.

## Problem

The host OCaml 5.4.1 and Dune 3.23.1 did not provide the approved libraries.
Global package installation and shell changes would couple this project to other
work. A successor needs concrete versions and commands, not only dependency names.

## Decision

- Download official opam 2.6.0 into ignored `.tools/opam` and verify the fixed
  SHA-256 for the selected platform before execution.
- Keep its root in `.opam-root/` and an independently compiled local OCaml 5.3.0
  switch in `_opam/`. Do not use `ocaml-system` or the global 5.4.1 compiler.
- Use the official opam repository snapshot
  `ac27950e5eac6c981ad809dff370c937820b7893`.
- Track `loam_ocaml.opam` and its transitive `loam_ocaml.opam.locked` baseline.
- `tools/bootstrap` installs dependencies with `--locked --with-test`, refuses
  an absent lock, and does not update an incompatible existing switch silently.
- `tools/opam` fixes root/switch for every invocation; no shell initialization
  changes, global switch selection, or automatic OS-package installation.

Initial resolved direct versions:

| Package | Version | Scope |
| --- | --- | --- |
| dune | 3.24.2 | Build tool |
| base | v0.17.3 | Runtime |
| zarith | 1.14 | Runtime |
| ppx_expect | v0.17.3 | Test PPX |
| base_quickcheck | v0.17.1 | Test generation |

OCaml 5.3.0 is a conservative compatible baseline for the v0.17 library family,
not an assertion that 5.4 is unusable. The host compiler is deliberately not the
support policy. New compiler/platform combinations need actual qualification.

## Alternatives

- Homebrew/global opam: rejected to avoid changing unrelated environments.
- System compiler switch: rejected because it inherits host upgrades.
- Latest/unlocked registry: rejected because repeated setup can drift.
- Containers or Nix: deferred; no present need to add another build platform.

## Consequences and limits

The lock contains 50 dependency entries including compiler/toolchain support,
native configuration checks, runtime transitives, and test transitives. Test-only
entries retain `with-test`. PPX infrastructure is sizeable; transitive dependencies
such as ppx_bench or stdio are not additional direct product libraries. Core,
Async, ppx_jane, and storage bindings are absent. See ADR 0001 for capability reasons.

OS prerequisites (C toolchain, GMP development files, pkg-config, Unix utilities)
are detected, not installed or hermetically pinned. This establishes a reproducible
package/version selection, not byte-identical binaries or complete supply-chain
independence. Checksums establish integrity relative to trusted release metadata;
they are not an independent audit of opam or downloaded package source.

The package is local development metadata, not a published release. License,
authors, homepage, and issue URL remain deliberately unresolved; `opam lint`
reports warnings for those fields. Do not invent metadata to silence them.

## Qualification

- Local isolated compiler/library installation succeeded; bootstrap rerun succeeds.
- A second fresh root/switch installed from the lock and reproduced all 50 package
  versions exactly; the Quantity checks pass there too. No compiled switch or
  package root was copied into that replay.
- `dune build @all`, forced `dune runtest`, and package-mode
  `dune runtest -p loam_ocaml --force` succeed.
- Three expect tests execute; the arithmetic property check executes 10,000
  cases with explicit seed `loam-quantity-v1`.
- A source-only temporary package copy installed through opam with tests and was
  then removed/unpinned. The uncommitted Git checkout itself cannot be used as
  a normal Git source pin before its first commit.
- Global OCaml/Dune remain 5.4.1/3.23.1; no `~/.opam` was created.
- Missing lock, missing local manager, and a corrupt executable were tested to
  fail before initialization or executing the corrupt manager.
- Linux/Apple Silicon qualification has not been performed. Platform binary
  entries are not test coverage.

Dune's release profile normally disables inline tests. The test directory sets
`inline_tests enabled` explicitly and is associated with the package, so package
mode is not a successful no-op. Tests remain private and are not installed as
part of the domain runtime library. Dune also excludes `scratch/` from workspace
discovery, and `tools/check` sets the project root explicitly: temporary package
copies must not produce duplicate definitions or run their parent's tests.

## Revisit

Upgrade compiler, registry snapshot, and lock as a reviewed change with clean
build and forced tests. Reassess transitive cost when a direct dependency changes.
Do not regenerate the lock merely to resolve an unrelated implementation failure.
