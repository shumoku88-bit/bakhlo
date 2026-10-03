A well-typed external client compiles using only the public interfaces.
Zero is representable as a neutral Effect; it is Movement validation that refuses it.

  $ cat >valid.ml <<'EOF'
  > module D = Loam_domain
  > let change (locus : D.Identifier.Locus.t) (measure : D.Identifier.Measure.t) =
  >   D.Effect.create ~key:None ~locus ~measure ~quantity:D.Quantity.zero
  > let keyed (key : D.Identifier.Effect_key.t) locus measure =
  >   D.Effect.create ~key:(Some key) ~locus ~measure ~quantity:D.Quantity.zero
  > let admit id effects = D.Event.create ~id ~effects
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -c valid.ml

An abstract Measure identity cannot be supplied as a Locus identity.
Check the diagnostic as well as the exit code, so an unrelated compiler failure
cannot masquerade as protection of this boundary.

  $ cat >wrong_role.ml <<'EOF'
  > module D = Loam_domain
  > let change (measure : D.Identifier.Measure.t) =
  >   D.Effect.create ~key:None ~locus:measure ~measure ~quantity:D.Quantity.zero
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -c wrong_role.ml 2>error
  [2]
  $ grep -q 'Identifier.Measure.t' error && grep -q 'Identifier.Locus.t' error

Effect keys are not Event identities; unqualified Event results cannot enter memory.

  $ cat >wrong_effect_key.ml <<'EOF'
  > module D = Loam_domain
  > let wrong (key : D.Identifier.Event.t) locus measure =
  >   D.Effect.create ~key:(Some key) ~locus ~measure ~quantity:D.Quantity.zero
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -c wrong_effect_key.ml 2>error
  [2]
  $ grep -q 'Identifier.Event.t' error && grep -q 'Identifier.Effect_key.t' error
  $ cat >unqualified_event.ml <<'EOF'
  > module D = Loam_domain
  > let wrong id effects = D.Event_memory.of_events [ D.Event.create ~id ~effects ]
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -c unqualified_event.ml 2>error
  [2]
  $ grep -q 'result' error && grep -q 'Event.t' error
  $ cat >forged_event.ml <<'EOF'
  > module D = Loam_domain
  > let wrong id effects : D.Event.t = { id; effects }
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -c forged_event.ml 2>error
  [2]
  $ grep -q 'Unbound record field.*id' error

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
  > module P = Loam_application.Current_quantity_query
  > let forge (coordinate : D.Effect_coordinate.t) : P.exact =
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
  >   match D.Event.create ~id:target ~effects:[], D.Event.create ~id:replacement ~effects:[] with
  >   | Error error, _ | _, Error error -> Error (`Event error)
  >   | Ok original, Ok revised ->
  >     match D.Event_memory.of_events [ original; revised ] with
  >     | Error error -> Error (`Memory error)
  >     | Ok events ->
  >       let correction : D.Event_correction.t = { target; replacement } in
  >       Ok (C.run ~events ~correction)
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

Multiple anonymous groups bind to one frontier, with explicit re-observation.

  $ cat >current_groups_client.ml <<'EOF'
  > module A = Loam_application
  > module H = A.Current_quantity_groups
  > let inspect frontier assertions coordinate =
  >   let observation : H.group = { reflected_roots = []; assertions } in
  >   match H.create ~frontier ~groups:[ observation ] with
  >   | Error error -> Error error
  >   | Ok image ->
  >     Ok (H.source_frontier image, H.groups image, H.group_for image coordinate,
  >         H.query image coordinate, H.reobserve image observation)
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c current_groups_client.ml

A global ownership image cannot be forged by ordinary well-typed code.

  $ cat >forged_group_image.ml <<'EOF'
  > module A = Loam_application
  > let forge (frontier : A.Correction_frontier.t) : A.Current_quantity_groups.t =
  >   { frontier; qualified_groups = []; owners = Base.Map.empty (module Loam_domain.Effect_coordinate) }
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c forged_group_image.ml 2>error
  [2]
  $ grep -q 'Unbound record field "frontier"\|Unbound record field frontier' error

Separately source-bound projections cannot be combined as raw group declarations.

  $ cat >separately_bound_group.ml <<'EOF'
  > module A = Loam_application
  > let mix frontier (projection : A.Current_quantity_projection.t) =
  >   A.Current_quantity_groups.create ~frontier ~groups:[ projection ]
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c separately_bound_group.ml 2>error
  [2]
  $ grep -q 'Current_quantity_projection.t' error && grep -q 'Current_quantity_groups.group' error

A cut is not the common source frontier.

  $ cat >cut_is_not_group_source.ml <<'EOF'
  > module A = Loam_application
  > let mix (cut : A.Reflected_root_cut.t) =
  >   A.Current_quantity_groups.create ~frontier:cut ~groups:[]
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c cut_is_not_group_source.ml 2>error
  [2]
  $ grep -q 'Reflected_root_cut.t' error && grep -q 'Correction_frontier.t' error

The physically admitted base Actual source has a public smart constructor.

  $ cat >actual_source_client.ml <<'EOF'
  > module S = Loam_application.Actual_source
  > let empty () = S.create { events = []; validities = []; corrections = [] }
  > let facts source = Loam_application.Actual_validity.facts (S.validity source)
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c actual_source_client.ml
  $ cat >forged_actual_source.ml <<'EOF'
  > module A = Loam_application
  > let forge frontier validity : A.Actual_source.t = { frontier; validity }
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c forged_actual_source.ml 2>error
  [2]
  $ grep -q 'Unbound record field.*frontier' error

The composed query needs an admitted source, not a frontier or separate projections.

  $ cat >current_query_client.ml <<'EOF'
  > module A = Loam_application
  > let opening coordinate opening_event : A.Current_quantity_query.opening = { coordinate; opening_event }
  > module Q = A.Current_quantity_query
  > let create source = Q.create ~source ~zero_origins:[] ~openings:[] ~groups:[] ~presence:None
  > let inspect image coordinate = match Q.query image coordinate with
  >   | Error (Support_unknown { coordinate = _ }) -> None
  >   | Ok (Exact answer) -> Some (`Exact (Q.quantity answer, Q.premise answer))
  >   | Ok (Known_present answer) -> Some (`Present (Q.present_coordinate answer, Q.present_evidence answer, Q.present_cut answer))
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c current_query_client.ml

Presence cannot be consumed as a Quantity or omitted from outcome handling.

  $ cat >presence_is_not_quantity.ml <<'EOF'
  > module Q = Loam_application.Current_quantity_query
  > let wrong (answer : Q.present) = Q.quantity answer
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c presence_is_not_quantity.ml 2>error
  [2]
  $ grep -q 'Q.present' error && grep -q 'Q.exact' error
  $ cat >outcome_requires_presence.ml <<'EOF'
  > module Q = Loam_application.Current_quantity_query
  > let incomplete (answer : Q.outcome) = match answer with Q.Exact value -> Q.quantity value
  > EOF
  $ ocamlfind ocamlc -w +8 -warn-error +8 -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c outcome_requires_presence.ml 2>error
  [2]
  $ grep -q 'warning 8' error && grep -q 'Known_present' error

An opening still requires an Event identity, not a Locus.

  $ cat >opening_locus_is_not_event.ml <<'EOF'
  > module D = Loam_domain
  > module Q = Loam_application.Current_quantity_query
  > let wrong coordinate (opening_event : D.Identifier.Locus.t) : Q.opening = { coordinate; opening_event }
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c opening_locus_is_not_event.ml 2>error
  [2]
  $ grep -q 'Identifier.Locus.t' error && grep -q 'Identifier.Event.t' error
  $ cat >frontier_is_not_current_source.ml <<'EOF'
  > module A = Loam_application
  > let use (source : A.Correction_frontier.t) =
  >   A.Current_quantity_query.create ~source ~zero_origins:[] ~openings:[] ~groups:[] ~presence:None
  > EOF
  $ ocamlfind ocamlc -package base,zarith -I ../lib/.loam_domain.objs/byte -I ../application/.loam_application.objs/byte -c frontier_is_not_current_source.ml 2>error
  [2]
  $ grep -q 'Correction_frontier.t' error && grep -q 'Actual_source.t' error
