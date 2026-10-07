Development-only native S-expression book: separate-process fresh staging/reopen,
retained original history, explicit independent support and no recording/Saved claim.

  $ cp ../examples/ordinary-sexp/initial.sexp base.sexp
  $ cp base.sexp before.sexp
  $ bakhlo stage-current-sexp --canonicalize base.sexp start.sexp
  S-expression candidate staged; not recording or durable Saved.
  $ bakhlo stage-current-sexp start.sexp ../examples/ordinary-sexp/purchase.sexp purchase.sexp
  S-expression candidate staged; not recording or durable Saved.
  $ bakhlo inspect-current-sexp purchase.sexp wallet jpy
  Conditional S-expression quantity (ordinary-quantity v1; supplied evidence).
  exact assertion; "wallet" / "jpy": asserted=1000; delta=-100; quantity=900
  $ bakhlo stage-current-sexp --correct purchase purchase.sexp ../examples/ordinary-sexp/correction.sexp current.sexp
  S-expression candidate staged; not recording or durable Saved.
  $ bakhlo inspect-current-sexp current.sexp wallet jpy food jpy
  One supplied read image; independent questions (no subtotal).
  Question 1:
  Conditional S-expression quantity (ordinary-quantity v1; supplied evidence).
  exact assertion; "wallet" / "jpy": asserted=1000; delta=-150; quantity=850
  Question 2:
  Conditional S-expression quantity (ordinary-quantity v1; supplied evidence).
  "food" / "jpy": zero-origin; quantity=150
  $ bakhlo inspect-current-sexp current.sexp bank jpy
  "bank" / "jpy": quantity unknown (no supported premise in supplied evidence).
  [3]
  $ cmp base.sexp before.sexp
  $ grep '^(event ' current.sexp
  (event "purchase"
  (event "purchase-corrected"
  $ grep '^  (day ' current.sexp
    (day (date "2000-01-10"))
    (day (date "1900-01-01"))
  $ grep '^  (description ' current.sexp
    (description (text "架空の支出：訂正前も残す。"))
    (description (not-supplied))
  $ grep '^  (effect ' current.sexp
    (effect (key (named "cash")) (locus "wallet") (measure "jpy") (quanta -100))
    (effect (key (unkeyed)) (locus "food") (measure "jpy") (quanta 100)))
    (effect (key (named "cash")) (locus "wallet") (measure "jpy") (quanta -150))
    (effect (key (unkeyed)) (locus "food") (measure "jpy") (quanta 150)))
  $ grep '^[(]event-correction ' current.sexp
  (event-correction (target "purchase") (replacement "purchase-corrected"))

Physical target refusal: no overwrite, alias/symlink repair or source effects.
Errors are captured here to avoid platform-specific OS wording; status/bytes stay exact.

  $ bakhlo stage-current-sexp --canonicalize base.sexp base.sexp >out 2>err
  [1]
  $ test ! -s out && test -s err && cmp base.sexp before.sexp
  $ ln -s base.sexp alias.sexp
  $ bakhlo stage-current-sexp --canonicalize current.sexp alias.sexp >out 2>err
  [1]
  $ test ! -s out && test -s err && test -L alias.sexp && cmp base.sexp before.sexp

A failed creation attempt other than a definite existing collision is conservative
UNCERTAIN, not a claimed rollback or retry permission; no guessed cleanup.

  $ bakhlo stage-current-sexp --canonicalize base.sexp absent-parent/new.sexp >out 2>err
  [5]
  $ test ! -e absent-parent && test ! -s out && grep '^Candidate output UNCERTAIN' err >/dev/null && cmp base.sexp before.sexp

Unsupported/malformed/missing inputs refuse the WHOLE book before file creation,
including fields irrelevant to the asked coordinate. No empty/zero/success fallback.

  $ bakhlo stage-current-sexp --correct base.sexp bad-arguments.sexp >out 2>err
  [2]
  $ test ! -e bad-arguments.sexp && test ! -s out && test -s err
  $ bakhlo stage-current-sexp --typo base.sexp bad-option.sexp >out 2>err
  [2]
  $ test ! -e bad-option.sexp && test ! -s out && test -s err
  $ cp base.sexp future.sexp
  $ chmod u+w future.sexp
  $ printf '\n(scheduled-occurrence "future")\n' >>future.sexp
  $ bakhlo inspect-current-sexp --summary future.sexp wallet jpy >out 2>err
  [2]
  $ test ! -s out && test -s err
  $ bakhlo stage-current-sexp --canonicalize future.sexp refused.sexp >out 2>err
  [2]
  $ test ! -e refused.sexp && test ! -s out && test -s err
  $ bakhlo stage-current-sexp missing.sexp ../examples/ordinary-sexp/purchase.sexp missing-out.sexp >out 2>err
  [1]
  $ test ! -e missing-out.sexp && test ! -s out && test -s err
  $ bakhlo stage-current-sexp --correct absent purchase.sexp ../examples/ordinary-sexp/correction.sexp bad-correction.sexp >out 2>err
  [1]
  $ test ! -e bad-correction.sexp && test ! -s out && test -s err

Boundary type: callers cannot forge a qualified book using OCaml record construction.

  $ printf 'let forge : Bakhlo_sexp.Book.t = { bytes = ""; wire = (); image = () }\n' >forge.ml
  $ ocamlc -I ../sexp/.bakhlo_sexp.objs/byte -c forge.ml >out 2>err
  [2]
  $ grep 'Unbound record field "bytes"' err
  Error: Unbound record field "bytes"
