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
./tools/opam exec -- dune runtest -p bakhlo --force
./tools/opam exec -- dune build --root . @install
./tools/opam exec -- dune build --root . \
  lib/bakhlo_domain.cmxa application/bakhlo_application.cmxa
./tools/opam exec -- dune exec bakhlo -- --help
./tools/opam list --installed --short --columns=name,version
```

`tools/check` builds @all and forces tests. Root traversal excludes `scratch` and `experiments`;
isolated trial dependencies never become prerequisites of this check. Run a trial from its own
directory with explicit `dune ... --root .` and its separately selected environment.
Seeds, counts and finite scopes are in
tests/[verification](VERIFICATION.md), not another inventory here. Package tests
explicitly enable inline tests; `-p` already selects root, so never combine it with
`--root`. Clean engine-only builds must leave Presentation/CLI CMIs/libraries unbuilt.

The public Application namespace is explicitly curated, excluding arithmetic-only
helpers. Logical aliases support clean dependency discovery. Cram compiler clients
currently depend on generated CMIs/wrapper CMI: pinned Dune integration details, not
API/storage compatibility. Do not suppress missing-CMI warnings or export internals.

## Optional formatting

`.ocamlformat` pins **0.29.0**, target syntax **5.3.0**, default profile and 100-column margin.
Comment/docstring rewriting is disabled to keep evidence prose intact. Use
`./tools/format --check` or `./tools/format --apply` (Dune @fmt / fmt); the wrapper rejects a
missing/wrong local formatter, never installs or falls back to a global tool. Apply finishes
with a clean @fmt check: Dune 3.24.2 can return 1 for diffs it has already promoted.
Formatting is optional developer tooling, NOT a main runtime/test dependency or CI gate;
`bootstrap`, `check` and normal builds still use the unchanged main 50 packages without it.
Separate formatting-only commits from meaning/refactor changes. Do not reflow payload fixtures,
normalize identities or weaken compiler policy to make layout pass.

Optional setup below uses the existing checksummed opam and frozen LOCAL registry checkout,
a separate ignored root/switch, and complete aliases of the already bootstrapped native compiler.
Aliases prevent opam stripping a managed compiler path and accidentally selecting a global
compiler/`.opt`/helper. No system install, shell/editor hooks, third-party patch or main lock
change. The tool is tied to the main compiler's current location; recreate after relocation.
Qualified here on macOS x86_64 only; this is not a fresh-platform formatter bootstrap claim.

```sh
./tools/bootstrap
mkdir -p .tools/format-compiler/bin
for executable in "$PWD"/_opam/bin/ocaml*; do
  name=${executable##*/}
  case "$name" in ocamlfind|ocamlbuild*) continue ;; esac
  ln -sf "$executable" ".tools/format-compiler/bin/$name"
done
.tools/format-compiler/bin/ocamlc -version  # must be 5.3.0
fmt_opam() {
  env PATH="$PWD/.tools/format-compiler/bin:$PATH" \
    OPAMROOT="$PWD/.tools/format-root" OPAMSWITCH= \
    OPAMVAR_sys_ocaml_version=5.3.0 OPAMNODEPEXTS=true OPAMNOENVNOTICE=true \
    .tools/opam "$@"
}
fmt_opam init --bare --no-setup --yes default \
  "git+file://$PWD/.opam-root/repo/default#ac27950e5eac6c981ad809dff370c937820b7893"
fmt_opam switch create "$PWD/.tools/format" ocaml-system.5.3.0 --yes --no-depexts
fmt_opam install --switch "$PWD/.tools/format" \
  dune.3.24.2 ocamlformat.0.29.0 --yes --no-depexts
./tools/format --check
```

Do not use `--with-test` for the formatter's vendor package: its own tests require Dune <3.22,
separate from Bakhlo's existing native suite on 3.24.2. This trial exercised our syntax/layout/
AST preservation and tests, not the vendor's test suite. Formatter upgrades require a bounded
representative trial and fresh version/config review, not a blind version-check bypass.

## Reference versus experimental builds

[Current direction](ARCHITECTURE.md#selected-product-direction) prioritizes inspectable canonical
text/data sovereignty; SQLite canonical adapter adoption is PAUSED. Unix is the near-term
validation runtime; MirageOS is an explicit future goal with experimental support today.
No ordinary SQLite package/adapter/index/shared backend runner is present. Preserve engine
Base + Zarith/inward dependencies; optional derived indexes need a concrete consumer, never a
second authority. Review binding/build/runtime/OS costs before any future lock/adoption change;
this direction is not a compiler upgrade or global OS installation. Bootstrap still
refuses missing prerequisites rather than installing them. Record actual SQLite library/
synchronisation settings, not just the OCaml binding version. A separate ignored root/switch
now exercises sqlite3 5.4.2 against system SQLite 3.43.2 with unchanged compiler/main 50;
[bounded native evidence](VERIFICATION.md#unixsqlite-synthetic-persistence-bounded-outer-trial-no-saved-qualification)
is not permanent installation, Saved or a canonical-format decision.

Shared tests will assert the same logical save/reopen/stale/conflict/corrupt/uncertain/
restore outcomes and engine bytes/answers. Each runner owns native/Lwt/process lifecycle and
physical fault mapping. There is no generic I/O monad requirement and no already shared
suite; unsupported capabilities are explicit blockers, not silently skipped PASS. Hardware/
OS/cache and backup assumptions remain per target. Irmin commit details/Solo5 devices never
enter application admission/publication meanings or normal reference build requirements.

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

The bounded Irmin block trial is also ignored guest scratch, not an installed product.
Its one 32 MiB synthetic disk is owned exclusively by one tender process; no shared mounts,
network device or simultaneous writer. Formatting is explicit provisioning, NEVER a read/
recovery fallback. Clean process/VM restart is not abrupt-crash/power-loss evidence.
Two external dependency fixes were needed; no permanent backend/schema/support promise.
[Verification](VERIFICATION.md#irmin-block-persistence-bounded-two-trial-dependency-fixes-required)
owns exact selections/failures; keep generation admission, retry/conflicts, durability and
backup/restore as separate contracts. These fixes do not block near-term Unix/representation
work; preserve the experiment and evidence rather than promote or delete it.
VM remains stopped between checkpoints.

## Dependency changes

[ADR 0001](adr/0001-initial-scope-and-dependencies.md) requires a capability, named
consumer, alternatives, scope/transitive cost and revisit condition before additions.
For approved updates, review compiler/registry/direct constraints, resolve an isolated
set including tests, generate `./tools/opam lock ./bakhlo.opam`, review provenance
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
