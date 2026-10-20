# Irmin Phase 2 — frozen synthetic reproduction appendix

This is an archive of the **already-tested** scratch experiment, not a product backend,
new storage implementation, automatic installer, or next task. Irmin integration is on hold;
see [results/limits](../IRMIN_PHASE2_RESULTS.ja.md) and the
[next calendar-year S-expression plan](../YEAR_PARTITIONED_SEXP_RESEARCH.ja.md).
Normal Dune/product tools do not compile or invoke these files; there is no Dune stanza here.

## What is preserved

- `trial_image.ml`: synthetic 20-entry image, Core admission, reversible cells/archive codec.
- `trial_worker.ml`: standard Irmin HEAD/CAS/flush and readback; no manifest/merge/GC.
- `trial_restore.ml`: independent Core/codec/Digestif restore, no Irmin/Lwt linkage.
- `trial_checks.ml`: fresh-process checks, cooperative ownership, stale/refusal/fault cases.
- `io_fault.c`: macOS-only write/pwrite/fsync interposition, armed inside the trial child,
  restricted to explicitly supplied repository descriptors. Never load into another application.
- `build.sh`, `env-opam.sh`: original scripts; copy to the layout below before execution.
- `packages.txt`, `dependencies.export`: exact 67-package installed version set.
  `install-atoms.txt` freezes the 56 additions after compiler/base switch creation.
- `SHA256SUMS`: relative-path hashes of the frozen code/recipe, without host paths.

Source/scripts are byte-identical to the final local Phase 2 version (495 physical lines).
Original Core snapshot is Bakhlo commit `a81d0df1e2c35aa0ba98dd1810bf54ba403dfeca`.
Public source metadata: opam repository commit
`ac27950e5eac6c981ad809dff370c937820b7893`.
Required trial platform: macOS/x86_64, tested on macOS 15.7.9, existing Apple C tools and GMP;
OCaml 5.3.0, opam 2.6.0, Dune 3.24.2. All OCaml package versions are in `packages.txt`.
These prerequisites are not permission to install system packages or alter product dependencies.

No original/private household data, installed switch, binaries, raw environment/space logs,
absolute home paths, credentials, or failed repository contents are included.
Original source snapshots, all intermediate failures/logs and damaged repositories remain in
ignored `scratch/irmin-phase2-oKzeZW`; Phase 1 downloads remain in
`scratch/irmin-research-xHxxdu`. Do not delete or repair these evidence copies.

## Manual replay — separate approval required for installing dependencies

The recipe records the earlier experiment; the current organization task does **not**
authorize another install. Check free space, review a dry-run plan, and use a fresh ignored
root/switch only. Stop if system packages or baseline versions would need to change.
Do not use the product `tools/opam` wrapper to install trial packages.
The archived `env-opam.sh` uses the existing `.tools/opam` binary but points all package
operations at the fresh root/switch. No global init/shell setup or automatic depext.

From repository root, after the above approvals/prerequisites:

```sh
set -eu
umask 077
run=$(mktemp -d "$PWD/scratch/irmin-replay-XXXXXX")
mkdir "$run/source" "$run/experiment" "$run/results" "$run/plan"
git archive a81d0df1e2c35aa0ba98dd1810bf54ba403dfeca | tar -xf - -C "$run/source"
(cd docs/archive/irmin-phase2 && shasum -a 256 -c SHA256SUMS)
cp docs/archive/irmin-phase2/trial_*.ml docs/archive/irmin-phase2/io_fault.c "$run/experiment/"
cp docs/archive/irmin-phase2/build.sh "$run/experiment/build"
cp docs/archive/irmin-phase2/env-opam.sh "$run/env-opam"
cp docs/archive/irmin-phase2/install-atoms.txt "$run/plan/"
df -k "$run" > "$run/plan/space-before.txt"
sh "$run/env-opam" init --bare --no-setup --yes default \
  'git+https://github.com/ocaml/opam-repository.git#ac27950e5eac6c981ad809dff370c937820b7893'
sh "$run/env-opam" switch create "$run/source" ocaml-base-compiler.5.3.0 \
  --no-install --yes --no-depexts
sh "$run/env-opam" install --dry-run --yes --no-depexts \
  $(tr '\n' ' ' < "$run/plan/install-atoms.txt") > "$run/plan/solve.txt" 2>&1
# Inspect solve.txt and free space before the next command. Stop on changed prerequisites.
sh "$run/env-opam" install --yes --no-depexts --jobs=4 \
  $(tr '\n' ' ' < "$run/plan/install-atoms.txt")
sh "$run/env-opam" list --installed --columns=name,version --color=never \
  > "$run/plan/packages.txt"
cmp docs/archive/irmin-phase2/packages.txt "$run/plan/packages.txt"
sh "$run/env-opam" switch export "$run/plan/dependencies.export"
sh "$run/env-opam" exec -- dune build --root "$run/source" \
  lib/bakhlo_domain.cmxa application/bakhlo_application.cmxa sexp/bakhlo_sexp.cmxa
sh "$run/experiment/build" > "$run/plan/build.txt" 2>&1
"$run/experiment/checks" "$run" replay-1 > "$run/plan/checks.txt" 2>&1
```

Compiler provisioning belongs to the approved isolated setup; the 56-package dry-run above
covers the additions, not a claim that compiler creation is cost-free. Package metadata URLs
may become unavailable; keep a fresh attempt and report failures, never silently change pins.
`--root` is essential: without it Dune can select the outer product workspace.
`build` compiles native executables plus the Darwin-only interposer; it has fatal warnings
8/9/11 and strict sequencing. Duplicate-interface/deprecated-clock warnings were retained.
This organization task checks byte-identical sources, hashes/script syntax and existing tests,
and replays the 65 checks using the already-qualified isolated binaries in fresh synthetic copies.
It does not perform a new clean install on another machine. Other platforms remain unqualified.

## Expected evidence and interpretation

The driver creates `results/replay-1/summary.tsv`, each process's stdout/stderr and
fresh repository/archive copies. It refuses reuse of an existing output directory.
The final recorded local run was `results/run-3/summary.tsv` (65 cases):

- Six normal operations, restarted selected image and standalone archive restore agree.
- Nine API checkpoints × exception/SIGKILL for payment and support give observed old/new states.
- CAS/stale draft/ownership/unbalanced/duplicate inputs refuse as specified.
- Three write failures on each dict/suffix/control/branches and three pack fsync failures.
- Half of the 72-byte branch write then EIO/SIGKILL leaves `Branch.mem=true`, `Head.find=None`.
  Report `corrupt-selected-branch-refused`, not old/new success or an empty ledger.
- Reseeding damaged copies is refused. Original damaged evidence is retained.

Child outcome and selected image are different observations. A printed HEAD-update success
is **not durable Saved**; SIGKILL does not flush/drop OS page cache or test power loss.
The codec's fixed-basis relation test is a limited read/admission probe, not full combined C
or broader writer permission. Archive provenance/checksum is not authentication of an Irmin
commit, and this is not a whole-household/migration/off-host/physical-durability qualification.
