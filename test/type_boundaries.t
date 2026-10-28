A well-typed external client compiles using only the public interfaces.
Zero is representable as a neutral Effect; it is Movement validation that refuses it.

  $ domain_client() { ocamlfind ocamlc -package base,zarith -I ../lib/.bakhlo_domain.objs/byte -c "$@"; }
  $ book_client() { ocamlfind ocamlc -package zarith -I ../book_txt/.bakhlo_book_txt.objs/byte -c "$@"; }

  $ cat >valid.ml <<'EOF'
  > module D = Bakhlo_domain
  > let change (locus : D.Identifier.Locus.t) (measure : D.Identifier.Measure.t) =
  >   D.Effect.create ~key:None ~locus ~measure ~quantity:D.Quantity.zero
  > let keyed (key : D.Identifier.Effect_key.t) locus measure =
  >   D.Effect.create ~key:(Some key) ~locus ~measure ~quantity:D.Quantity.zero
  > let admit id effects = D.Event.create ~id ~effects
  > EOF
  $ domain_client valid.ml

An abstract Measure identity cannot be supplied as a Locus identity.
Check the diagnostic as well as the exit code, so an unrelated compiler failure
cannot masquerade as protection of this boundary.

  $ cat >wrong_role.ml <<'EOF'
  > module D = Bakhlo_domain
  > let change (measure : D.Identifier.Measure.t) =
  >   D.Effect.create ~key:None ~locus:measure ~measure ~quantity:D.Quantity.zero
  > EOF
  $ domain_client wrong_role.ml 2>error
  [2]
  $ grep -q 'Identifier.Measure.t' error && grep -q 'Identifier.Locus.t' error

Effect keys are not Event identities, and an Event is built only by its constructor.

  $ cat >wrong_effect_key.ml <<'EOF'
  > module D = Bakhlo_domain
  > let wrong (key : D.Identifier.Event.t) locus measure =
  >   D.Effect.create ~key:(Some key) ~locus ~measure ~quantity:D.Quantity.zero
  > EOF
  $ domain_client wrong_effect_key.ml 2>error
  [2]
  $ grep -q 'Identifier.Event.t' error && grep -q 'Identifier.Effect_key.t' error
  $ cat >forged_event.ml <<'EOF'
  > module D = Bakhlo_domain
  > let wrong id effects : D.Event.t = { id; effects }
  > EOF
  $ domain_client forged_event.ml 2>error
  [2]
  $ grep -q 'Unbound record field.*id' error

The private Movement record cannot be forged to admit an empty Effect list.
This check does not claim to protect against unsafe OCaml escape hatches.

  $ cat >forged.ml <<'EOF'
  > module D = Bakhlo_domain
  > let forge (measure : D.Identifier.Measure.t) : D.Movement.t =
  >   { measure; effects = [] }
  > EOF
  $ domain_client forged.ml 2>error
  [2]
  $ grep -q 'measure' error && grep -Eqi 'record|field|abstract|private' error

The coordinate's identifier roles remain distinct.

  $ cat >wrong_coordinate.ml <<'EOF'
  > module D = Bakhlo_domain
  > let forge (measure : D.Identifier.Measure.t) : D.Effect_coordinate.t =
  >   { locus = measure; measure }
  > EOF
  $ domain_client wrong_coordinate.ml 2>error
  [2]
  $ grep -q 'Identifier.Measure.t' error && grep -q 'Identifier.Locus.t' error

Locus identity cannot stand in for Event identity.

  $ cat >wrong_event_role.ml <<'EOF'
  > module D = Bakhlo_domain
  > let forge (locus : D.Identifier.Locus.t) = D.Event.create ~id:locus ~effects:[]
  > EOF
  $ domain_client wrong_event_role.ml 2>error
  [2]
  $ grep -q 'Identifier.Event.t' error && grep -q 'Identifier.Locus.t' error

An admitted book.txt is reached only by reading or changing one; its balances and
printed lines cannot be supplied by hand.

  $ cat >book_client.ml <<'EOF'
  > module T = Bakhlo_book_txt.Book_txt
  > let read text = Result.map (fun b -> T.print b) (T.read text)
  > EOF
  $ book_client book_client.ml
  $ cat >forged_book.ml <<'EOF'
  > module T = Bakhlo_book_txt.Book_txt
  > let forge (value : T.t) : T.book = { value; next = 0 }
  > EOF
  $ book_client forged_book.ml 2>error
  [2]
  $ grep -Eqi 'record|field|abstract|unbound' error

A store session can be read by callers, but its admitted book, file path and
revision cannot be replaced independently of the writer.

  $ store_client() { ocamlfind ocamlc -package base,zarith,sexplib0,unix -I ../store/.bakhlo_store.objs/byte -I ../sexp/.bakhlo_household.objs/byte -I ../book_txt/.bakhlo_book_txt.objs/byte -I ../lib/.bakhlo_domain.objs/byte -c "$@"; }
  $ cat >session_reader.ml <<'EOF'
  > let facts (session : Book_file.t) =
  >   (session.path, session.revision, session.book, session.sidecars)
  > let reload = Book_file.reload
  > EOF
  $ store_client session_reader.ml
  $ cat >forged_session.ml <<'EOF'
  > let forge (session : Book_file.t) book =
  >   { session with book; path = "different-book.txt"; revision = "forged" }
  > EOF
  $ store_client forged_session.ml 2>error
  [2]
  $ grep -qi 'private' error && grep -q 'Book_file.t' error
