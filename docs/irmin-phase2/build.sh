#!/bin/sh
set -eu
run=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
src="$run/source/_build/default"
cd "$run/experiment"
incs="-I $src/lib/.bakhlo_domain.objs/byte -I $src/lib/.bakhlo_domain.objs/native -I $src/application/.bakhlo_application.objs/byte -I $src/application/.bakhlo_application.objs/native -I $src/sexp/.bakhlo_sexp.objs/byte -I $src/sexp/.bakhlo_sexp.objs/native"
libs="$src/lib/bakhlo_domain.cmxa $src/application/bakhlo_application.cmxa $src/sexp/bakhlo_sexp.cmxa"
sh "$run/env-opam" exec -- ocamlfind ocamlopt -strict-sequence -w +8+9+11 -warn-error +8+9+11 -package base,zarith,parsexp,unix,digestif.ocaml -linkpkg $incs $libs trial_image.ml trial_restore.ml -o restore
sh "$run/env-opam" exec -- ocamlfind ocamlopt -strict-sequence -w +8+9+11 -warn-error +8+9+11 -package base,zarith,parsexp,unix,digestif.ocaml,irmin-pack.unix -linkpkg $incs $libs trial_image.ml trial_worker.ml -o worker
sh "$run/env-opam" exec -- ocamlfind ocamlopt -strict-sequence -w +8+9+11 -warn-error +8+9+11 -package base,zarith,parsexp,unix,digestif.ocaml -linkpkg $incs $libs trial_image.ml trial_checks.ml -o checks
cc -dynamiclib -Wall -Wextra -Werror -O2 io_fault.c -o io_fault.dylib
