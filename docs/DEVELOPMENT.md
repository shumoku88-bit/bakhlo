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
Linux opam initialization additionally requires bubblewrap and permitted user namespaces.

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
./tools/opam list --installed --short --columns=name,version
```

`tools/check` builds @all and forces tests. Root traversal excludes `scratch`.
Seeds, counts and finite scopes are in
tests/[verification](VERIFICATION.md), not another inventory here. Package tests
explicitly enable inline tests; `-p` already selects root, so never combine it with
`--root`.

The public Application namespace is explicitly curated, excluding arithmetic-only
helpers. Logical aliases support clean dependency discovery. Cram compiler clients
currently depend on generated CMIs/wrapper CMI: pinned Dune integration details, not
API/storage compatibility. Do not suppress missing-CMI warnings or export internals.

### Bonsai isolated linker recipe

`tools/build-bonsai-tui` uses the separate
`scratch/tui_comparison_review/bonsai-env` switch/root, not the main switch.
Its Zarith `1.12+ox3` macOS recipe used to pass both MacPorts and Intel Homebrew
paths unconditionally, embedding `-L/opt/local/lib` in zarith.cmxa even when absent.
Do not create an empty system directory or suppress linker warnings to mask this.

The user-authorized repair retains the same patched release sources under ignored
`scratch/tui_comparison_review/zarith-link-path-repair`, pinned as `zarith.1.12+ox3`.
Only its macOS build recipe drops `-L/opt/local/lib` and `-I/opt/local/include`;
`-L/usr/local/lib` and `-I/usr/local/include` remain for the installed GMP.
The local recipe also declares the license stated in the release LICENSE.
Keep that directory while the local pin exists. The pre-repair switch export is
`scratch/tui_comparison_review/zarith-link-path-before.export`.

To reproduce the repair in another explicitly authorized isolated switch, use
`opam source zarith.1.12+ox3 --require-checksums --dir=NEW_DIRECTORY` with that
switch/root explicitly selected; opam applies the existing Ox patches.
Edit the extracted `zarith.opam` macOS flags as above, pin the directory with
`opam pin add zarith.1.12+ox3 NEW_DIRECTORY --kind=path --no-action`,
then inspect `opam reinstall zarith.1.12+ox3 --show-actions` before reinstalling.
Require no added/upgraded packages; rebuild reverse dependencies normally rather
than rewriting installed archives or bypassing their rebuild. Rebuild Bakhlo and
run native self-check afterward. This is not part of automatic bootstrap/build;
new environment repair still requires approval.

## OCaml-aware engineering review

[OCaml-aware design and runtime review](LANGUAGE_AWARE_DESIGN_REVIEW.md) owns the
lightweight recurring standard from [issue #28](https://github.com/shumoku88-bit/bakhlo/issues/28):
check relevant changed paths during feature work, and occasionally review accumulated
changes against existing native measurements. Algorithms/ownership come before GC,
representation or parser tuning. It is not another mandatory build/test pipeline.
Reports are short issue/PR notes; `HANDOFF.md` stays focused on current work.

## Optional formatting

`.ocamlformat` pins **0.29.0**, target syntax **5.3.0**, default profile and 100-column margin.
Comment/docstring rewriting is disabled to keep evidence prose intact. Use
`./tools/format --check` or `./tools/format --apply` (Dune @fmt / fmt); the wrapper rejects a
missing/wrong local formatter, never installs or falls back to a global tool. Apply finishes
with a clean @fmt check: Dune 3.24.2 can return 1 for diffs it has already promoted.
Formatting is optional developer tooling, NOT a main runtime/test dependency or CI gate;
`bootstrap`, `check` and normal builds use the main 51 locked packages without it.
Approved Parsexp v0.17.0 is the only addition to the previous 50; no compiler/existing-package
upgrades. It belongs to the outer S-expression adapter, not Domain/Application.
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

## Other runtimes

Unix (macOS, Linux) is the runtime. MirageOS may be tried as an experiment: keep the pure
core on Base + Zarith (+ Parsexp in `sexp/`) and put runtime-specific code in a separate edge
beside `store/`, never in admission or query meaning. Earlier SQLite, Irmin and Solo5-SPT
trials and the Lima VM recipe are in Git at `90a5867` (`docs/DEVELOPMENT.md`,
`docs/VERIFICATION.md`).

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
set including tests, generate `./tools/opam lock ./bakhlo.opam`, review provenance
and replay locked bootstrap/checks. Never regenerate a lock for an unrelated code error.
Missing lock/checksum mismatch fails closed; no unlocked/latest fallback.

## Release limits

Public names within the package let local builds/install mappings be checked; they
are not publication or stable-API promises. Test dependencies stay test-only.
License/author/homepage/issue metadata and contributor ownership remain unresolved;
resolve before release, never invent values to silence lint. No ordinary source-opam
installation/fresh platform replay is newly claimed by @install alone.
