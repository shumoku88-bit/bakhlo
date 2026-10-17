#!/bin/sh
# Build only in a fresh isolated runner; do not modify the user's product switch.
set -eu
umask 077
opam exec -- dune build \
  lib/bakhlo_domain.cmxa application/bakhlo_application.cmxa sexp/bakhlo_sexp.cmxa
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
src=_build/default
incs="-I $src/lib/.bakhlo_domain.objs/byte -I $src/lib/.bakhlo_domain.objs/native -I $src/application/.bakhlo_application.objs/byte -I $src/application/.bakhlo_application.objs/native -I $src/sexp/.bakhlo_sexp.objs/byte -I $src/sexp/.bakhlo_sexp.objs/native"
# shellcheck disable=SC2086
opam exec -- ocamlfind ocamlopt -strict-sequence -w +8+9+11 -warn-error +8+9+11 \
  # The Irmin Git dependency graph exposes these modules through transitive
  # ocamlfind packages; manual ocamlopt linkage must name them explicitly.
  -package base,zarith,parsexp,unix,lwt.unix,irmin-git.unix,digestif.ocaml,checkseum,mirage-mtime,mirage-sleep,mirage-ptime -linkpkg $incs \
  "$src/lib/bakhlo_domain.cmxa" \
  "$src/application/bakhlo_application.cmxa" \
  "$src/sexp/bakhlo_sexp.cmxa" \
  experiments/irmin-git-year-spike/scripts/core_bridge.ml -o "$out/core-bridge"
"$out/core-bridge"
