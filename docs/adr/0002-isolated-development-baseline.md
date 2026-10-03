# ADR 0002 — Isolated locked development baseline

Status: implemented/tested on macOS x86_64, initially 2026-10-02; user authorized
repository-local setup, not a global environment change or full platform matrix.

## Decision

- Official checksummed opam 2.6.0 in ignored `.tools/opam`; platform digests in bootstrap.
- Local `.opam-root/`, independently compiled OCaml 5.3.0 switch `_opam/`, no shell hooks.
- Registry `ac27950e5eac6c981ad809dff370c937820b7893`; tracked manifest/exact lock.
- Dependencies installed `--locked --with-test`; absent lock/corrupt manager fails closed.
- Wrapper fixes root/switch and clears inherited OCaml overrides; no automatic OS setup.

| Package | Baseline |
| --- | --- |
| Dune | 3.24.2 |
| Base | v0.17.3 |
| Zarith | 1.14 |
| ppx_expect | v0.17.3 |
| Base_quickcheck | v0.17.1 |

This compatible OCaml/v0.17 baseline avoids coupling to host upgrades. Global/system
switch and latest/unlocked selection were rejected; containers/Nix add no presently
needed capability. Host compiler is not support policy. [ADR 0001](0001-initial-scope-and-dependencies.md)
owns direct capability reasons; the lock includes 50 entries with native/build/test transitives.

## Earned evidence and limits

Initial local installation/rerun and a second fresh root/switch reproduced all 50
locked versions. Missing-lock/corrupt-manager controls failed before unsafe setup.
Normal/package checks and a source-only temporary package install were exercised;
these historical results are not freshly rerun for every dependency-unchanged code edit.
Current check scope belongs in VERIFICATION; fresh source installation is not implied
by @install mapping alone.

Only macOS x86_64 was exercised. Configured Linux/arm64 binaries are not qualification.
C/GMP/OS prerequisites are detected, not installed or hermetically pinned. Selection
and checksums are not bit-identical builds, complete supply-chain audit or permanent
package availability. Licensing/package public metadata remain unresolved.

Inline tests stay enabled in package/release mode so qualification is not a no-op.
Scratch is excluded from Dune as well as Git; compiler artifacts/local logs are disposable.

## Revisit

Review compiler, registry and lock upgrades as semantic environment changes. Replay
isolated bootstrap, clean builds and forced tests; qualify platforms actually claimed.
Never change global configuration or regenerate the lock for an unrelated code failure.
