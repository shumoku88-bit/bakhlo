Compiler evolution checks must apply to development and release/package builds.
Copy the actual root Dune configuration: this test must fail if its policy is
removed. Fixtures below test the OCaml language, not household quantities/state.

  $ mkdir policy
  $ cp ../dune policy/dune
  $ chmod u+w policy/dune
  $ printf '\n(library (name probe))\n' >>policy/dune
  $ printf '(lang dune 3.0)\n' >policy/dune-project
  $ cat >complete.txt <<'EOF'
  > type choice = Left | Right
  > type pair = { left : int; right : int }
  > let choose = function Left -> 0 | Right -> 1
  > let project { left; right = _ } = left
  > let discard_explicitly () = ignore (Ok () : (unit, string) result)
  > EOF
  $ cat >partial.txt <<'EOF'
  > type choice = Left | Right
  > let choose = function Left -> 0
  > EOF
  $ cat >omitted.txt <<'EOF'
  > type pair = { left : int; right : int }
  > let project { left } = left
  > EOF
  $ cat >redundant.txt <<'EOF'
  > type choice = Left | Right
  > let choose = function Left -> 0 | Right -> 1 | Left -> 2
  > EOF
  $ cat >dropped_result.txt <<'EOF'
  > let check () = Error "refused"
  > let sequence () = check (); Ok ()
  > EOF

A successful control distinguishes policy failures from unrelated build failures.
Each rejection checks both failure status and the specific compiler diagnostic.
Explicitly naming an ignored record field/value is permitted. Accidental omission
and implicitly discarding a typed result in a sequence are not.

  $ for profile in dev release; do
  >   cp complete.txt policy/probe.ml
  >   dune build --root policy --profile "$profile" probe.cmxa >build-log 2>&1 || { echo "control failed: $profile"; exit 1; }
  >   echo "$profile: complete control compiled"
  >   for specimen in partial:8 omitted:9 redundant:11; do
  >     name=${specimen%:*}
  >     warning=${specimen#*:}
  >     cp "$name.txt" policy/probe.ml
  >     if dune build --root policy --profile "$profile" probe.cmxa >build-log 2>&1; then
  >       echo "unexpected success: $profile warning $warning"
  >       exit 1
  >     fi
  >     grep -Eq "Error.*\\(warning $warning " build-log || { echo "wrong failure: $profile warning $warning"; exit 1; }
  >   done
  >   echo "$profile: warnings 8, 9, 11 rejected"
  >   cp dropped_result.txt policy/probe.ml
  >   if dune build --root policy --profile "$profile" probe.cmxa >build-log 2>&1; then
  >     echo "unexpected result discard: $profile"
  >     exit 1
  >   fi
  >   if ! grep -Eq 'expected of type "?unit"?' build-log || ! grep -q 'left-hand side of a sequence' build-log; then
  >     echo "wrong sequence failure: $profile"
  >     cat build-log
  >     exit 1
  >   fi
  >   echo "$profile: implicit result discard rejected"
  > done
  dev: complete control compiled
  dev: warnings 8, 9, 11 rejected
  dev: implicit result discard rejected
  release: complete control compiled
  release: warnings 8, 9, 11 rejected
  release: implicit result discard rejected
