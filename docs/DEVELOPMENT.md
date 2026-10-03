# Development environment

## First setup

From the repository root:

```sh
./tools/bootstrap
./tools/check
```

This downloads a checksummed opam 2.6.0 binary, initializes a repository-local
root without shell hooks, compiles OCaml 5.3.0, and installs the locked dependency
set including test dependencies. The first run needs network access, disk space,
and time to compile. Later runs reuse the same switch. Nothing is installed into
the system OCaml environment, and no shell profile is modified.

Prerequisites: `curl`, `git`, C compiler, `make`, `tar`, `patch`, `pkg-config`, GMP
headers/library detectable as `pkg-config gmp`, and `sha256sum` or `shasum`.
On macOS this normally means command-line developer tools plus GMP/pkg-config;
on Debian-like Linux it normally means a build toolchain, `libgmp-dev`, and
`pkg-config`. Install missing OS prerequisites yourself with the appropriate
platform procedure; the bootstrap never invokes sudo, brew, apt, or similar.

Configured binary platforms: macOS x86_64/arm64 and Linux x86_64/aarch64.
**Only macOS x86_64 has been exercised.** Other architectures/OSes and Linux
system-library requirements still need qualification; this is not a completed
support matrix.

## Everyday commands

```sh
./tools/opam exec -- dune build @all
./tools/opam exec -- dune runtest --force
./tools/opam exec -- dune runtest -p loam_ocaml --force
./tools/opam exec -- dune exec loam-ocaml -- --help
./tools/opam list --installed --short --columns=name,version
```

`tools/check` runs the first two commands and preserves a failure exit status.
Test verbosity shows that tests actually execute. The generated Quantity check
uses 10,000 cases with deterministic seed `loam-quantity-v1` and up to 10,000
shrinking attempts on failure. The Movement check uses the same counts and seed
`loam-movement-v1`. Application replay uses `loam-application-v1`, and conditional
zero-origin projection uses `loam-zero-origin-v1`, with the same counts. Event
identity/endpoint closure uses `loam-correction-endpoints-v1`, also 10,000 cases.
Supplied correction-frontier admission uses `loam-correction-frontier-v1` with
those counts, plus exhaustive three-Event graphs and a 10,000-node chain/cycle.
Root lineages use `loam-root-lineage-v1` with those counts, plus an independent
four-node transitive-closure model and full simple-graph model/code comparison.
Reflected-root cuts use `loam-reflected-root-cut-v1` with those counts, compare
1,168 relation/declaration cases and selected fresh-tail extensions, and preserve
source-binding/refusal distinctions. One-group current quantity uses
`loam-current-quantity-v1` with those counts, plus 4,864 graph/cut/support cases and
direct original-Effect Zarith oracles.
Built-in Dune cram checks run the real CLI and external-client compiler checks; no new test framework dependency was added. This is finite
testing, not a universal proof. Package mode `-p` already selects a root; do not
combine it with a repeated `--root` option.

Always use the wrapper here instead of a bare system `opam` or `dune`. It selects
this project's root/switch even if another switch is active in the parent shell.
It clears inherited OCaml search-path overrides; it is isolation of compiler and
package selection, not a container or hermetic OS environment.

## Compiler policy

Root `dune` adds strict sequencing and fatal warnings 8/9/11 to standard flags in
all profiles, including release/package mode. Non-exhaustive matches, omitted
record-pattern fields, redundant cases, and implicitly discarded non-unit results
are refused. Deliberate `ignore`/patterns remain possible and need review.

`test/compiler_policy.t` builds complete controls and four counterexamples using
that actual configuration in dev/release. This is a third cram suite, not a new
library or general static-analysis framework. See [functional-core review](ENGINEERING_STYLE.md).

## Engine-only targets

```sh
./tools/opam exec -- dune build --root . \
  lib/loam_domain.cmxa application/loam_application.cmxa
```

These targets have no dependency on presentation/CLI or any UI package. A clean
build was checked not to build their outer library artifacts. Do not introduce
frameworks or speculative state/caches to prepare for a future interface.
The Application root namespace is now explicit to omit its private arithmetic
helper. Public aliases use logical module names so clean Dune dependency discovery
works; cram supplies generated `loam_application__.cmi` as well as public unit
CMIs. These physical names are pinned-toolchain integration details, not a public
transport/storage/API compatibility promise. Update the export list deliberately.

## Optional root-cut laws — not product requirements

Six narrow Lean row-selection and signed-delta/answerability laws now have an
optional development artifact.
Normal Dune/opam build, tests and release never invoke it; bootstrap installs no
Lean. See [statements, pinned version, assumptions and reproduction](../formal/README.md).
Only if inspecting that artifact, explicitly select an already installed native
Lean 4.33.1 binary for `tools/check-root-cut-laws`. The script installs nothing and
rejects missing/relative/wrong-version selections and proof-hole/axiom tokens.
The specification is not an OCaml refinement or unrestricted graph proof.

## Tracked versus disposable state

Tracked:

- `loam_ocaml.opam`: direct constraints and runtime/test distinctions.
- `loam_ocaml.opam.locked`: exact transitive dependency versions.
- `tools/bootstrap`: opam version, platform digests, registry snapshot, compiler.

Ignored:

- `.tools/`: downloaded local opam.
- `.opam-root/`: registry metadata, cache, logs, and manager state.
- `_opam/`: compiled local switch.
- `_build/`, `*.install`, and `scratch/`: build and synthetic experimental output.

The root `dune` file excludes `scratch/` from package discovery. Keep temporary
package copies there; Git ignore rules alone do not stop Dune from finding them.
`tools/check` sets `--root .` so a nested test checkout does not run parent tests.

Do not copy or commit ignored state. In particular opam logs can contain the
invoking environment and machine-local paths. Do not publish them wholesale.
Relocating a built switch is not supported; recreate it in the new checkout.

## Dependency changes

Every new direct library needs the capability rationale required by ADR 0001.
To update an approved baseline deliberately:

1. Review the compiler/library versions and registry snapshot; update bootstrap
   and direct constraints only as needed.
2. Resolve the intended set in an isolated switch, inspecting native and test
   transitives. Do not silently remove `--with-test`.
3. Generate the lock with `./tools/opam lock ./loam_ocaml.opam`.
4. Review both the lock and package provenance; rerun locked bootstrap and checks.
5. Record version/platform evidence and residual limits in the ADR/handoff.

A missing lock or opam checksum mismatch fails closed; bootstrap does not fall
back to an unlocked/latest install. Tests do not require Lean or actual data.

## Package and release limitations

The internal libraries have Dune public names `loam_ocaml.domain`,
`loam_ocaml.application`, `loam_ocaml.presentation`, and `loam_ocaml.cli`;
the executable is `loam-ocaml`, so local package/install paths can be exercised.
These are project library boundaries within one package, not extra third-party
runtime dependencies. This is not external publication, licensing,
or a stable-API promise. Test libraries remain private and test dependencies are
filtered with `with-test` in opam metadata and lock.

`opam lint` warns about unresolved author/license/homepage/issue metadata. Those
warnings must be resolved before publication, not with fabricated values.

Use `--deps-only` for ordinary setup. Before the initial commit, a normal Git-based
source pin failed; that is historical, not a current missing-commit blocker.
An initial commit and user-authorized private GitHub repository now exist. Ordinary
source installation after that change has not been newly qualified here. Do not
use `--working-dir` to copy ignored local environments: package smoke testing uses
a separate source-only synthetic copy, never the full workspace or real data.

## Guarantee boundary

The snapshot/lock pins package selection and checks downloaded integrity. System
compiler prerequisites and GMP are not pinned by opam, and package availability
still depends on upstream hosting. This is not bit-for-bit build reproducibility,
full supply-chain verification, or a qualified migration/release.

A second fresh root/switch on the same macOS x86_64 host replayed the lock,
matched all 50 package versions, and passed the Quantity checks. Missing-lock
and corrupt-local-manager rejection were also exercised. This does not extend
platform coverage beyond that host.

See [ADR 0002](adr/0002-isolated-development-baseline.md) for exact versions,
qualification, and revisit triggers.
