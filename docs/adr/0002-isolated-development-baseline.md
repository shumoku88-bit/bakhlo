# ADR 0002 — Isolated locked development baseline

Status: implemented/tested on macOS x86_64, initially 2026-10-02; user authorized
repository-local setup, not a global environment change or full platform matrix.

Superseded in part, 2026-10-26: the active compiler baseline is OCaml 5.4.1 (manifest,
bootstrap, CI, formatter target syntax). The 5.3.0 decision and evidence below stay as
the historical record of the first baseline; they are not retroactively rewritten.
The fresh 5.4.1 switch/bootstrap replay was qualified on macOS x86_64 on 2026-10-27,
first in a separate stage copy and then at the main checkout's permanent prefix, which now
builds, tests and formats on 5.4.1. Opam, registry, lock policy and fail-closed rules are
unchanged; an existing 5.3.0 switch is not upgraded in place, and keeping the old
root/switch/`_build` and the formatter artifacts
(`.tools/format`, `.tools/format-root`, `.tools/format-compiler`) as a restorable backup
then recreating at the original paths is the supported way back.

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
owns direct capability reasons; the lock then held 50 entries with native/build/test
transitives (56 today, three of them compiler entries).

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

5.4.1 replay (2026-10-27, separate stage copy, macOS x86_64): a new isolated root and
switch compiled 5.4.1; checked opam 2.6.0, the frozen registry and the regenerated lock
(only the three compiler entries moved to 5.4.1, every other pin unchanged);
`tools/bootstrap --locked --with-test` passed and kept its wrong-compiler fail-closed
guard; `dune build @all` and `dune runtest --force` passed in a cleared environment; the
real PTY smoke passed on the synthetic fixture at four sizes. The optional formatter was
recreated with ocaml-system 5.4.1, Dune 3.24.2 and ocamlformat 0.29.0 and its version
checks passed, while `tools/format --check` still reports the same 15 pre-existing layout
diffs as the 5.3.0 baseline. Linux CI was updated to 5.4.1 and not run; no other platform
is claimed. Commands and scope are in VERIFICATION.

5.4.1 main cutover (2026-10-27, macOS x86_64): the old 5.3.0 root/switch, `_build` and the
formatter artifacts were moved whole into a private ignored backup, and a fresh isolated
root/switch was bootstrapped at the original paths with the checked opam 2.6.0, the frozen
registry and the regenerated lock (three compiler entries at 5.4.1, the other 53 pins
unchanged, 56 entries including the compiler). A cold `dune build @all` and a full forced
`dune runtest` passed in a cleared environment; the real PTY smoke passed on the synthetic
fixture at four sizes with unchanged fixture bytes; the formatter root was recreated with
ocaml-system 5.4.1, Dune 3.24.2 and ocamlformat 0.29.0 at that prefix, and
`tools/format --check` still reports exactly the 15 pre-existing layout diffs of the 5.3.0
baseline, so it stays red at baseline and is not a gate. A GUI Emacs smoke on a clean PATH
selected the main 5.4.1 switch and its real ocaml-lsp 1.26.0 binary, and project/study UTop
REPLs stayed independent. Restoring the backup requires the matching tracked 5.3.0
pin/lock/bootstrap/CI/formatter configuration; the moved artifacts alone are refused by the
fail-closed guards. Linux CI was not run, nothing was committed or pushed, and no
household, LOAM, IME or operational `.run` data is claimed. Commands and scope are in
VERIFICATION.

## Revisit

Review compiler, registry and lock upgrades as semantic environment changes. Replay
isolated bootstrap, clean builds and forced tests; qualify platforms actually claimed.
Never change global configuration or regenerate the lock for an unrelated code failure.
