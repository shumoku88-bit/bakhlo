#!/bin/sh
# Reuse Dune's dependency and virtual-library implementation resolution.
# This probe is built in an isolated, temporary copy of Bakhlo's pure Core.
# Do not alter the product Dune/opam setup or the user's installed switch.
set -eu
umask 077

out=$(mktemp -d "${TMPDIR:-/tmp}/bakhlo-irmin-core-XXXXXXXX")
trap 'rm -rf "$out"' EXIT HUP INT TERM

cp dune-project dune bakhlo.opam "$out/"
cp -R lib application sexp "$out/"
mkdir "$out/probe"
cp experiments/irmin-git-year-spike/scripts/core_bridge.ml "$out/probe/probe.ml"
cat > "$out/probe/dune" <<'DUNE'
(executable
 (name probe)
 (libraries bakhlo_domain bakhlo_application bakhlo_sexp irmin-git.unix lwt.unix unix))
DUNE

# Unlike a hand-written ocamlfind/ocamlopt link line, Dune selects the Unix
# implementations of transitive virtual libraries required by irmin-git.unix.
# The scratch project is not part of Bakhlo's product workspace.
opam exec -- dune exec --root "$out" ./probe/probe.exe
