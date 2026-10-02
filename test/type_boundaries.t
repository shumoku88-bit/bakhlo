A well-typed external client compiles using only the public interfaces.
Zero is representable as a neutral Effect; it is Movement validation that refuses it.

  $ cat >valid.ml <<'EOF'
  > module D = Loam_domain
  > let change (locus : D.Identifier.Locus.t) (measure : D.Identifier.Measure.t) =
  >   D.Effect.create ~locus ~measure ~quantity:D.Quantity.zero
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -c valid.ml

An abstract Measure identity cannot be supplied as a Locus identity.
Check the diagnostic as well as the exit code, so an unrelated compiler failure
cannot masquerade as protection of this boundary.

  $ cat >wrong_role.ml <<'EOF'
  > module D = Loam_domain
  > let change (measure : D.Identifier.Measure.t) =
  >   D.Effect.create ~locus:measure ~measure ~quantity:D.Quantity.zero
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -c wrong_role.ml 2>error
  [2]
  $ grep -q 'Identifier.Measure.t' error && grep -q 'Identifier.Locus.t' error

The private Movement record cannot be forged to admit an empty Effect list.
This check does not claim to protect against unsafe OCaml escape hatches.

  $ cat >forged.ml <<'EOF'
  > module D = Loam_domain
  > let forge (measure : D.Identifier.Measure.t) : D.Movement.t =
  >   { measure; effects = [] }
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -c forged.ml 2>error
  [2]
  $ grep -q 'Unbound record field "measure"\|Unbound record field measure' error

The application can be used by a typed client without CLI or presentation CMIs.

  $ cat >application_client.ml <<'EOF'
  > module A = Loam_application.Movement_check
  > let inspect effects =
  >   match A.run { effects } with
  >   | Ok answer -> Some (A.measure answer, A.effects answer, A.positive_total answer)
  >   | Error _ -> None
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c application_client.ml

A structured application preview cannot be forged with a false aggregate.

  $ cat >forged_preview.ml <<'EOF'
  > module A = Loam_application.Movement_check
  > let forge (movement : Loam_domain.Movement.t) : A.preview =
  >   { movement; positive_total = Loam_domain.Quantity.zero }
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c forged_preview.ml 2>error
  [2]
  $ grep -q 'Unbound record field "movement"\|Unbound record field movement' error

Conditional projection is usable without CLI/presentation or private record fields.

  $ cat >zero_origin_client.ml <<'EOF'
  > module D = Loam_domain
  > module P = Loam_application.Zero_origin_projection
  > let inspect movements (locus : D.Identifier.Locus.t) (measure : D.Identifier.Measure.t) =
  >   let coordinate : D.Effect_coordinate.t = { locus; measure } in
  >   match D.Zero_origin_coverage.of_coordinates [ coordinate ] with
  >   | Error error -> Error error
  >   | Ok coverage ->
  >     let model = P.create ~movements ~coverage in
  >     Ok (P.query model coordinate)
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c zero_origin_client.ml

The coordinate's identifier roles remain distinct.

  $ cat >wrong_coordinate.ml <<'EOF'
  > module D = Loam_domain
  > let forge (measure : D.Identifier.Measure.t) : D.Effect_coordinate.t =
  >   { locus = measure; measure }
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -c wrong_coordinate.ml 2>error
  [2]
  $ grep -q 'Identifier.Measure.t' error && grep -q 'Identifier.Locus.t' error

A supported conditional answer cannot be forged with a guessed zero quantity.

  $ cat >forged_quantity.ml <<'EOF'
  > module D = Loam_domain
  > module P = Loam_application.Zero_origin_projection
  > let forge (coordinate : D.Effect_coordinate.t) : P.answer =
  >   { coordinate; quantity = D.Quantity.zero }
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c forged_quantity.ml 2>error
  [2]
  $ grep -q 'Unbound record field "coordinate"\|Unbound record field coordinate' error
