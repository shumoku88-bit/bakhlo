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

An endpoint-closure client compiles without CLI/presentation or private memory fields.

  $ cat >correction_client.ml <<'EOF'
  > module D = Loam_domain
  > module C = Loam_application.Correction_check
  > let inspect (target : D.Identifier.Event.t) (replacement : D.Identifier.Event.t) =
  >   let original = D.Event.create ~id:target ~effects:[] in
  >   let revised = D.Event.create ~id:replacement ~effects:[] in
  >   match D.Event_memory.of_events [ original; revised ] with
  >   | Error error -> Error error
  >   | Ok events ->
  >     let correction : D.Event_correction.t = { target; replacement } in
  >     Ok (C.run ~events ~correction)
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c correction_client.ml

Locus identity cannot stand in for Event identity.

  $ cat >wrong_event_role.ml <<'EOF'
  > module D = Loam_domain
  > let forge (locus : D.Identifier.Locus.t) = D.Event.create ~id:locus ~effects:[]
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -c wrong_event_role.ml 2>error
  [2]
  $ grep -q 'Identifier.Event.t' error && grep -q 'Identifier.Locus.t' error

The source list and memory lookup index cannot be forged into an inconsistent pair.

  $ cat >forged_memory.ml <<'EOF'
  > module D = Loam_domain
  > let forge : D.Event_memory.t =
  >   { events = []; by_id = Base.Map.empty (module D.Identifier.Event) }
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -c forged_memory.ml 2>error
  [2]
  $ grep -q 'Unbound record field "events"\|Unbound record field events' error

A closed endpoint answer cannot claim unrelated observations by record construction.

  $ cat >forged_closed.ml <<'EOF'
  > module D = Loam_domain
  > module C = Loam_application.Correction_check
  > let forge (correction : D.Event_correction.t) (target_event : D.Event.t) (replacement_event : D.Event.t) : C.closed =
  >   { correction; target_event; replacement_event }
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c forged_closed.ml 2>error
  [2]
  $ grep -q 'Unbound record field "correction"\|Unbound record field correction' error

A qualified frontier client needs only Domain/Application interfaces.

  $ cat >frontier_client.ml <<'EOF'
  > module D = Loam_domain
  > module F = Loam_application.Correction_frontier
  > let inspect (events : D.Event_memory.t) (corrections : D.Event_correction.t list) =
  >   match F.create ~events ~corrections with
  >   | Error error -> Error error
  >   | Ok answer ->
  >     let lineages = List.map (fun row -> F.root_id row, F.terminal_event row) (F.lineages answer) in
  >     Ok (F.retained_events answer, F.corrections answer, F.frontier_events answer, lineages)
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c frontier_client.ml

One closed edge cannot stand in for a graph-qualified frontier.

  $ cat >closure_is_not_frontier.ml <<'EOF'
  > module A = Loam_application
  > let forge (closed : A.Correction_check.closed) = A.Correction_frontier.frontier_events closed
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c closure_is_not_frontier.ml 2>error
  [2]
  $ grep -q 'Correction_check.closed' error && grep -q 'Correction_frontier.t' error

A frontier cannot be fabricated to conceal observations without graph admission.

  $ cat >forged_frontier.ml <<'EOF'
  > module D = Loam_domain
  > module F = Loam_application.Correction_frontier
  > let forge (retained_events : D.Event_memory.t) : F.t =
  >   { retained_events; corrections = []; frontier_events = [] }
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c forged_frontier.ml 2>error
  [2]
  $ grep -q 'Unbound record field "retained_events"\|Unbound record field retained_events' error

A root-to-terminal association cannot be fabricated from unrelated observations.

  $ cat >forged_lineage.ml <<'EOF'
  > module D = Loam_domain
  > module F = Loam_application.Correction_frontier
  > let forge (root_id : D.Identifier.Event.t) (terminal_event : D.Event.t) : F.lineage =
  >   { root_id; terminal_event }
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c forged_lineage.ml 2>error
  [2]
  $ grep -q 'Unbound record field "root_id"\|Unbound record field root_id' error

A closed endpoint observation is not a qualified lineage, even when its two IDs exist.

  $ cat >closed_is_not_lineage.ml <<'EOF'
  > module A = Loam_application
  > let forge (closed : A.Correction_check.closed) = A.Correction_frontier.root_id closed
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c closed_is_not_lineage.ml 2>error
  [2]
  $ grep -q 'Correction_check.closed' error && grep -q 'Correction_frontier.lineage' error

A reflected-root cut client uses only qualified Domain/Application values.

  $ cat >root_cut_client.ml <<'EOF'
  > module A = Loam_application
  > module C = A.Reflected_root_cut
  > let inspect frontier reflected_roots =
  >   match C.create ~frontier ~reflected_roots with
  >   | Error error -> Error error
  >   | Ok answer ->
  >     Ok (C.source_frontier answer, C.reflected_roots answer,
  >         C.remaining_lineages answer, C.remaining_events answer)
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c root_cut_client.ml

The cut cannot be forged to conceal a source or invent exclusion results.

  $ cat >forged_root_cut.ml <<'EOF'
  > module A = Loam_application
  > let forge (source_frontier : A.Correction_frontier.t) : A.Reflected_root_cut.t =
  >   { source_frontier; reflected_roots = []; remaining_lineages = []; remaining_events = [] }
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c forged_root_cut.ml 2>error
  [2]
  $ grep -q 'Unbound record field "source_frontier"\|Unbound record field source_frontier' error

Endpoint closure alone is not a sufficient source for a root cut.

  $ cat >closed_is_not_cut_source.ml <<'EOF'
  > module A = Loam_application
  > let forge (closed : A.Correction_check.closed) =
  >   A.Reflected_root_cut.create ~frontier:closed ~reflected_roots:[]
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c closed_is_not_cut_source.ml 2>error
  [2]
  $ grep -q 'Correction_check.closed' error && grep -q 'Correction_frontier.t' error

A previously qualified cut is not a fresh source frontier; rebinding is explicit.

  $ cat >cut_is_not_source.ml <<'EOF'
  > module A = Loam_application
  > let forge (cut : A.Reflected_root_cut.t) =
  >   A.Reflected_root_cut.create ~frontier:cut ~reflected_roots:[]
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c cut_is_not_source.ml 2>error
  [2]
  $ grep -q 'Reflected_root_cut.t' error && grep -q 'Correction_frontier.t' error

Conditional current quantity uses an exact independent assertion and qualified cut.

  $ cat >current_quantity_client.ml <<'EOF'
  > module D = Loam_domain
  > module P = Loam_application.Current_quantity_projection
  > let inspect cut (coordinate : D.Effect_coordinate.t) (quantity : D.Quantity.t) =
  >   let assertion : P.assertion = { coordinate; quantity } in
  >   match P.create ~cut ~assertions:[ assertion ] with
  >   | Error error -> Error error
  >   | Ok group -> Ok (P.source_cut group, P.assertions group, P.query group coordinate)
  > let components answer =
  >   P.coordinate answer, P.asserted_quantity answer, P.delta answer, P.quantity answer
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c current_quantity_client.ml

A group cannot be forged to mismatch its source, assertions and aggregate.

  $ cat >forged_current_group.ml <<'EOF'
  > module D = Loam_domain
  > module A = Loam_application
  > let forge (source_cut : A.Reflected_root_cut.t) : A.Current_quantity_projection.t =
  >   { source_cut; assertions = []; answers = Base.Map.empty (module D.Effect_coordinate) }
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c forged_current_group.ml 2>error
  [2]
  $ grep -q 'Unbound record field "source_cut"\|Unbound record field source_cut' error

A supported answer cannot be manufactured from a guessed zero decomposition.

  $ cat >forged_current_answer.ml <<'EOF'
  > module D = Loam_domain
  > module P = Loam_application.Current_quantity_projection
  > let forge (coordinate : D.Effect_coordinate.t) : P.answer =
  >   { coordinate; asserted_quantity = D.Quantity.zero; delta = D.Quantity.zero; quantity = D.Quantity.zero }
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c forged_current_answer.ml 2>error
  [2]
  $ grep -q 'Unbound record field "coordinate"\|Unbound record field coordinate' error

A qualified frontier is not independent reflected-root evidence for this quantity.

  $ cat >frontier_is_not_quantity_cut.ml <<'EOF'
  > module A = Loam_application
  > let forge (frontier : A.Correction_frontier.t) =
  >   A.Current_quantity_projection.create ~cut:frontier ~assertions:[]
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c frontier_is_not_quantity_cut.ml 2>error
  [2]
  $ grep -q 'Correction_frontier.t' error && grep -q 'Reflected_root_cut.t' error

The shared aggregate is not a public support/balance API.

  $ cat >private_sum_is_not_support.ml <<'EOF'
  > let forge coordinate =
  >   Loam_application.Effect_sum.at Loam_application.Effect_sum.empty coordinate
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c private_sum_is_not_support.ml 2>error
  [2]
  $ grep -q 'Unbound module.*Effect_sum' error
