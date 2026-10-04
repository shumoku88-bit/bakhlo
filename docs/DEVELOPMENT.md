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
Linux build tools + libgmp-dev/pkg-config are typical, not a hermetic OS recipe.
Linux opam initialization additionally requires bubblewrap and permitted user namespaces;
Ubuntu's AppArmor profile for /usr/bin/opam does not cover our local .tools/opam. In the
approved VM only, the same userns allowance was scoped to the checked local binary via
/etc/apparmor.d/loam-local-opam (abi 4.0, flags=(unconfined), userns). AppArmor's global
restriction stays enabled and opam's sandbox stays enabled. Bootstrap still installs or
changes NONE of these prerequisites/policies itself; no global host exception is implied.

Configured binary platforms: macOS x86_64/arm64, Linux x86_64/aarch64.
**macOS x86_64 and Ubuntu 24.04 x86_64 are exercised.** ARM recipes remain unqualified.
OS prerequisites are not hermetically pinned;
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

## Approved isolated Linux VM (development trial)

Lima 2.2.1/VZ `loam-spt` is installed locally under ignored `scratch/linux_vm`, NOT
Homebrew/system PATH. State, private SSH key and 24 GiB sparse guest disk are there;
no host shares/agent forwarding/containerd/automatic application port forwarding.
Ubuntu 24.04 x86_64, 2 vCPU/4 GiB RAM; stopped between sessions. Outbound downloads and
loopback management SSH remain, not an air gap/security certification. Evidence and
limits: [VM/SPT preflight](VERIFICATION.md#isolated-linux-vm-and-solo5spt-preflight).
No main OCaml dependency changes; this VM is not a qualified household deployment.

From project root (shell variables only, no global configuration):

```sh
vmroot="$PWD/scratch/linux_vm"
vm() {
  env HOME="$vmroot/host-home" LIMA_HOME="$vmroot/state" \
    "$vmroot/lima/bin/limactl" "$@"
}
vm list
vm start --tty=false loam-spt
vm shell --workdir=/home/loam loam-spt
vm stop loam-spt
# Explicit teardown, only when its disposable guest contents are no longer wanted:
# vm delete --force loam-spt
```

Do not omit HOME/LIMA_HOME or add shared mounts, --preserve-env, SSH agent forwarding,
autostart or public port forwarding. Transfer only selected source/synthetic archives
with `vm copy`, verifying their checksums in the guest; never mount the workspace/home
or copy operational data. This is a local trial recipe, not a general tooling/CI choice.
Its generated config/logs/downloads/VM image are excluded from version control. Guest
prerequisites are installed only within the user-approved disposable VM; ordinary host
bootstrap still refuses OS installations. Linux locked OCaml/bootstrap, ordinary tests, package/install/Lean-free and clean engine-only
checks now pass. Freestanding evidence is separate; see VERIFICATION for target results.

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
