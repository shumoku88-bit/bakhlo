No unchecked fingerprint string or claimed balance can manufacture validated inputs.
These are ordinary OCaml abstraction checks, not protection against unsafe code or
an implementation that violates VERIFIED_SELECTION_SOURCE's authority contract.

  $ client() { ocamlfind ocamlc -package base,zarith -I ../lib/.bakhlo_domain.objs/byte -I ../application/.bakhlo_application.objs/byte -I ../sexp/.bakhlo_sexp.objs/byte -c "$@"; }
  $ cat >unchecked_hash.ml <<'EOF'
  > let unchecked : Bakhlo_sexp.Year_read.fingerprint = "self-declared-hash"
  > EOF
  $ client unchecked_hash.ml 2>error
  [2]
  $ grep -q 'fingerprint' error && grep -q 'string' error

A carry handle cannot be replaced by an exact scalar or a Daily_book.

  $ cat >forged_carry.ml <<'EOF'
  > module Y = Bakhlo_sexp.Year_read
  > module Test (Source : Y.VERIFIED_SELECTION_SOURCE) = struct
  >   module R = Y.Make (Source)
  >   let scalar : R.carry_forward = Y.Exact Bakhlo_domain.Quantity.zero
  > end
  > EOF
  $ client forged_carry.ml 2>error
  [2]
  $ grep -q 'carry_forward' error && grep -q 'balance' error
  $ cat >unverified_book.ml <<'EOF'
  > module Test (Source : Bakhlo_sexp.Year_read.VERIFIED_SELECTION_SOURCE) = struct
  >   module R = Bakhlo_sexp.Year_read.Make (Source)
  >   let wrong (book : Bakhlo_sexp.Daily_book.t) : R.year_version = book
  > end
  > EOF
  $ client unverified_book.ml 2>error
  [2]
  $ grep -q 'year_version' error && grep -q 'Daily_book.t' error
