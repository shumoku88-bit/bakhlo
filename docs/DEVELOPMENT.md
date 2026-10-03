# Development

## Isolated setup

```sh
./tools/bootstrap
./tools/check
```

Bootstrap downloads checksummed opam 2.6.0, initializes a repository-local root
without shell hooks, compiles OCaml 5.3.0 and installs the locked test/runtime set.
First setup needs network/time/disk; later runs reuse it. No global OCaml or shell
configuration is changed. [ADR 0002](adr/0002-isolated-development-baseline.md) owns
exact version/snapshot rationale and prior fresh-switch qualification.

Prerequisites: curl, git, C compiler, make, tar, patch, pkg-config, detectable GMP
headers/library, sha256sum or shasum. Install missing OS prerequisites yourself:
bootstrap never invokes sudo/brew/apt. macOS developer tools + GMP/pkg-config or
Linux build tools + libgmp-dev/pkg-config are typical, not a qualified OS recipe.

Configured binary platforms: macOS x86_64/arm64, Linux x86_64/aarch64.
**Only macOS x86_64 is exercised.** OS prerequisites are not hermetically pinned;
lock/checksums establish selection/integrity, not bit-identical binaries, complete
supply-chain verification or permanent upstream availability.

## Commands

Always use wrappers, not global opam/dune. The wrapper selects this root/switch
and clears inherited OCaml search-path overrides, not the whole OS environment.

```sh
./tools/check
./tools/opam exec -- dune runtest -p loam_ocaml --force
./tools/opam exec -- dune build --root . @install
./tools/opam exec -- dune build --root . \
  lib/loam_domain.cmxa application/loam_application.cmxa
./tools/opam exec -- dune exec loam-ocaml -- --help
./tools/opam list --installed --short --columns=name,version
```

`tools/check` builds @all and forces tests. Seeds, counts and finite scopes are in
tests/[verification](VERIFICATION.md), not another inventory here. Package tests
explicitly enable inline tests; `-p` already selects root, so never combine it with
`--root`. Clean engine-only builds must leave Presentation/CLI CMIs/libraries unbuilt.

The public Application namespace is explicitly curated, excluding arithmetic-only
helpers. Logical aliases support clean dependency discovery. Cram compiler clients
currently depend on generated CMIs/wrapper CMI: pinned Dune integration details, not
API/storage compatibility. Do not suppress missing-CMI warnings or export internals.

## Disposable state

Track manifests, lock and bootstrap. Never commit `.tools/`, `.opam-root/`, `_opam/`,
`_build/`, install output or `scratch/`. Opam logs may expose environment/local paths;
do not publish wholesale. Scratch is excluded from Dune discovery as well as Git.
`tools/check` fixes project root so nested experimental copies do not run parent tests.
Relocating a compiled switch is unsupported; recreate it in a new checkout.

## Dependency changes

[ADR 0001](adr/0001-initial-scope-and-dependencies.md) requires a capability, named
consumer, alternatives, scope/transitive cost and revisit condition before additions.
For approved updates, review compiler/registry/direct constraints, resolve an isolated
set including tests, generate `./tools/opam lock ./loam_ocaml.opam`, review provenance
and replay locked bootstrap/checks. Never regenerate a lock for an unrelated code error.
Missing lock/checksum mismatch fails closed; no unlocked/latest fallback.

## Optional specification

Normal checks/releases never invoke/install Lean. Only for the selected artifact:

```sh
LEAN=/absolute/path/to/lean-4.33.1/bin/lean ./tools/check-root-cut-laws
```

[formal/README](../formal/README.md) owns statements, assumptions, trusted components,
axioms, version and reproduction. The script installs nothing and rejects missing,
relative/wrong-version binaries or proof-hole/custom-axiom tokens. It is not an
independent checker/security sandbox or an OCaml refinement proof.

## Release limits

Public names within the package let local builds/install mappings be checked; they
are not publication or stable-API promises. Test dependencies stay test-only.
License/author/homepage/issue metadata and contributor ownership remain unresolved;
resolve before release, never invent values to silence lint. No ordinary source-opam
installation/fresh platform replay is newly claimed by @install alone.

No operational data/migration, canonical storage, backup/restore, recovery, household
admission or production adoption follows from these development checks.
