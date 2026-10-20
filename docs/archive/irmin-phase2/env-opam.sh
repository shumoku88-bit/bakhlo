#!/bin/sh
set -eu
run=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
root=$(CDPATH= cd -- "$run/../.." && pwd -P)
export OPAMROOT="$run/opam-root"
export OPAMSWITCH="$run/source"
export OPAMNOENVNOTICE=true
export OPAMNODEPEXTS=true
unset OCAMLPATH CAML_LD_LIBRARY_PATH OCAML_TOPLEVEL_PATH
exec "$root/.tools/opam" "$@"
