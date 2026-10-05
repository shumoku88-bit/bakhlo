A well-typed external client compiles using only the public interfaces.
Zero is representable as a neutral Effect; it is Movement validation that refuses it.
Compiler shorthands preserve separate Domain-only and Domain/Application scopes.

  $ domain_client() { ocamlfind ocamlc -package base,zarith -I ../lib/.bakhlo_domain.objs/byte -c "$@"; }
  $ application_client() { domain_client -I ../application/.bakhlo_application.objs/byte "$@"; }

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

Effect keys are not Event identities; unqualified Event results cannot enter memory.

  $ cat >wrong_effect_key.ml <<'EOF'
  > module D = Bakhlo_domain
  > let wrong (key : D.Identifier.Event.t) locus measure =
  >   D.Effect.create ~key:(Some key) ~locus ~measure ~quantity:D.Quantity.zero
  > EOF
  $ domain_client wrong_effect_key.ml 2>error
  [2]
  $ grep -q 'Identifier.Event.t' error && grep -q 'Identifier.Effect_key.t' error
  $ cat >unqualified_event.ml <<'EOF'
  > module D = Bakhlo_domain
  > let wrong id effects = D.Event_memory.of_events [ D.Event.create ~id ~effects ]
  > EOF
  $ domain_client unqualified_event.ml 2>error
  [2]
  $ grep -q 'result' error && grep -q 'Event.t' error
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
  $ grep -q 'Unbound record field "measure"\|Unbound record field measure' error

The application can be used by a typed client without CLI or presentation CMIs.

  $ cat >application_client.ml <<'EOF'
  > module A = Bakhlo_application.Movement_check
  > let inspect effects =
  >   match A.run { effects } with
  >   | Ok answer -> Some (A.measure answer, A.effects answer, A.positive_total answer)
  >   | Error _ -> None
  > EOF
  $ application_client application_client.ml

A structured application preview cannot be forged with a false aggregate.

  $ cat >forged_preview.ml <<'EOF'
  > module A = Bakhlo_application.Movement_check
  > let forge (movement : Bakhlo_domain.Movement.t) : A.preview =
  >   { movement; positive_total = Bakhlo_domain.Quantity.zero }
  > EOF
  $ application_client forged_preview.ml 2>error
  [2]
  $ grep -q 'Unbound record field "movement"\|Unbound record field movement' error

The coordinate's identifier roles remain distinct.

  $ cat >wrong_coordinate.ml <<'EOF'
  > module D = Bakhlo_domain
  > let forge (measure : D.Identifier.Measure.t) : D.Effect_coordinate.t =
  >   { locus = measure; measure }
  > EOF
  $ domain_client wrong_coordinate.ml 2>error
  [2]
  $ grep -q 'Identifier.Measure.t' error && grep -q 'Identifier.Locus.t' error

A supported conditional answer cannot be forged with a guessed zero quantity.

  $ cat >forged_quantity.ml <<'EOF'
  > module D = Bakhlo_domain
  > module P = Bakhlo_application.Current_quantity_query
  > let forge (coordinate : D.Effect_coordinate.t) : P.exact =
  >   { coordinate; quantity = D.Quantity.zero }
  > EOF
  $ application_client forged_quantity.ml 2>error
  [2]
  $ grep -q 'Unbound record field "coordinate"\|Unbound record field coordinate' error

An endpoint-closure client compiles without CLI/presentation or private memory fields.

  $ cat >correction_client.ml <<'EOF'
  > module D = Bakhlo_domain
  > module C = Bakhlo_application.Correction_check
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
  $ application_client correction_client.ml

Locus identity cannot stand in for Event identity.

  $ cat >wrong_event_role.ml <<'EOF'
  > module D = Bakhlo_domain
  > let forge (locus : D.Identifier.Locus.t) = D.Event.create ~id:locus ~effects:[]
  > EOF
  $ domain_client wrong_event_role.ml 2>error
  [2]
  $ grep -q 'Identifier.Event.t' error && grep -q 'Identifier.Locus.t' error

The source list and memory lookup index cannot be forged into an inconsistent pair.

  $ cat >forged_memory.ml <<'EOF'
  > module D = Bakhlo_domain
  > let forge : D.Event_memory.t =
  >   { events = []; by_id = Base.Map.empty (module D.Identifier.Event) }
  > EOF
  $ domain_client forged_memory.ml 2>error
  [2]
  $ grep -q 'Unbound record field "events"\|Unbound record field events' error

A closed endpoint answer cannot claim unrelated observations by record construction.

  $ cat >forged_closed.ml <<'EOF'
  > module D = Bakhlo_domain
  > module C = Bakhlo_application.Correction_check
  > let forge (correction : D.Event_correction.t) (target_event : D.Event.t) (replacement_event : D.Event.t) : C.closed =
  >   { correction; target_event; replacement_event }
  > EOF
  $ application_client forged_closed.ml 2>error
  [2]
  $ grep -q 'Unbound record field "correction"\|Unbound record field correction' error

A qualified frontier client needs only Domain/Application interfaces.

  $ cat >frontier_client.ml <<'EOF'
  > module D = Bakhlo_domain
  > module F = Bakhlo_application.Correction_frontier
  > let inspect (events : D.Event_memory.t) (corrections : D.Event_correction.t list) =
  >   match F.create ~events ~corrections with
  >   | Error error -> Error error
  >   | Ok answer ->
  >     let lineages = List.map (fun row -> F.root_id row, F.terminal_event row) (F.lineages answer) in
  >     Ok (F.retained_events answer, F.corrections answer, F.frontier_events answer, lineages)
  > EOF
  $ application_client frontier_client.ml

One closed edge cannot stand in for a graph-qualified frontier.

  $ cat >closure_is_not_frontier.ml <<'EOF'
  > module A = Bakhlo_application
  > let forge (closed : A.Correction_check.closed) = A.Correction_frontier.frontier_events closed
  > EOF
  $ application_client closure_is_not_frontier.ml 2>error
  [2]
  $ grep -q 'Correction_check.closed' error && grep -q 'Correction_frontier.t' error

A frontier cannot be fabricated to conceal observations without graph admission.

  $ cat >forged_frontier.ml <<'EOF'
  > module D = Bakhlo_domain
  > module F = Bakhlo_application.Correction_frontier
  > let forge (retained_events : D.Event_memory.t) : F.t =
  >   { retained_events; corrections = []; frontier_events = [] }
  > EOF
  $ application_client forged_frontier.ml 2>error
  [2]
  $ grep -q 'Unbound record field "retained_events"\|Unbound record field retained_events' error

A root-to-terminal association cannot be fabricated from unrelated observations.

  $ cat >forged_lineage.ml <<'EOF'
  > module D = Bakhlo_domain
  > module F = Bakhlo_application.Correction_frontier
  > let forge (root_id : D.Identifier.Event.t) (terminal_event : D.Event.t) : F.lineage =
  >   { root_id; terminal_event }
  > EOF
  $ application_client forged_lineage.ml 2>error
  [2]
  $ grep -q 'Unbound record field "root_id"\|Unbound record field root_id' error

A closed endpoint observation is not a qualified lineage, even when its two IDs exist.

  $ cat >closed_is_not_lineage.ml <<'EOF'
  > module A = Bakhlo_application
  > let forge (closed : A.Correction_check.closed) = A.Correction_frontier.root_id closed
  > EOF
  $ application_client closed_is_not_lineage.ml 2>error
  [2]
  $ grep -q 'Correction_check.closed' error && grep -q 'Correction_frontier.lineage' error

A reflected-root cut client uses only qualified Domain/Application values.

  $ cat >root_cut_client.ml <<'EOF'
  > module A = Bakhlo_application
  > module C = A.Reflected_root_cut
  > let inspect frontier reflected_roots =
  >   match C.create ~frontier ~reflected_roots with
  >   | Error error -> Error error
  >   | Ok answer ->
  >     Ok (C.source_frontier answer, C.reflected_roots answer,
  >         C.remaining_lineages answer, C.remaining_events answer)
  > EOF
  $ application_client root_cut_client.ml

The cut cannot be forged to conceal a source or invent exclusion results.

  $ cat >forged_root_cut.ml <<'EOF'
  > module A = Bakhlo_application
  > let forge (source_frontier : A.Correction_frontier.t) : A.Reflected_root_cut.t =
  >   { source_frontier; reflected_roots = []; remaining_lineages = []; remaining_events = [] }
  > EOF
  $ application_client forged_root_cut.ml 2>error
  [2]
  $ grep -q 'Unbound record field "source_frontier"\|Unbound record field source_frontier' error

Endpoint closure alone is not a sufficient source for a root cut.

  $ cat >closed_is_not_cut_source.ml <<'EOF'
  > module A = Bakhlo_application
  > let forge (closed : A.Correction_check.closed) =
  >   A.Reflected_root_cut.create ~frontier:closed ~reflected_roots:[]
  > EOF
  $ application_client closed_is_not_cut_source.ml 2>error
  [2]
  $ grep -q 'Correction_check.closed' error && grep -q 'Correction_frontier.t' error

A previously qualified cut is not a fresh source frontier; rebinding is explicit.

  $ cat >cut_is_not_source.ml <<'EOF'
  > module A = Bakhlo_application
  > let forge (cut : A.Reflected_root_cut.t) =
  >   A.Reflected_root_cut.create ~frontier:cut ~reflected_roots:[]
  > EOF
  $ application_client cut_is_not_source.ml 2>error
  [2]
  $ grep -q 'Reflected_root_cut.t' error && grep -q 'Correction_frontier.t' error

Conditional current quantity uses an exact independent assertion and qualified cut.

  $ cat >current_quantity_client.ml <<'EOF'
  > module D = Bakhlo_domain
  > module P = Bakhlo_application.Current_quantity_projection
  > let inspect cut (coordinate : D.Effect_coordinate.t) (quantity : D.Quantity.t) =
  >   let assertion : P.assertion = { coordinate; quantity } in
  >   match P.create ~cut ~assertions:[ assertion ] with
  >   | Error error -> Error error
  >   | Ok group -> Ok (P.source_cut group, P.assertions group, P.query group coordinate)
  > let components answer =
  >   P.coordinate answer, P.asserted_quantity answer, P.delta answer, P.quantity answer
  > EOF
  $ application_client current_quantity_client.ml

A group cannot be forged to mismatch its source, assertions and aggregate.

  $ cat >forged_current_group.ml <<'EOF'
  > module D = Bakhlo_domain
  > module A = Bakhlo_application
  > let forge (source_cut : A.Reflected_root_cut.t) : A.Current_quantity_projection.t =
  >   { source_cut; assertions = []; answers = Base.Map.empty (module D.Effect_coordinate) }
  > EOF
  $ application_client forged_current_group.ml 2>error
  [2]
  $ grep -q 'Unbound record field "source_cut"\|Unbound record field source_cut' error

A supported answer cannot be manufactured from a guessed zero decomposition.

  $ cat >forged_current_answer.ml <<'EOF'
  > module D = Bakhlo_domain
  > module P = Bakhlo_application.Current_quantity_projection
  > let forge (coordinate : D.Effect_coordinate.t) : P.answer =
  >   { coordinate; asserted_quantity = D.Quantity.zero; delta = D.Quantity.zero; quantity = D.Quantity.zero }
  > EOF
  $ application_client forged_current_answer.ml 2>error
  [2]
  $ grep -q 'Unbound record field "coordinate"\|Unbound record field coordinate' error

A qualified frontier is not independent reflected-root evidence for this quantity.

  $ cat >frontier_is_not_quantity_cut.ml <<'EOF'
  > module A = Bakhlo_application
  > let forge (frontier : A.Correction_frontier.t) =
  >   A.Current_quantity_projection.create ~cut:frontier ~assertions:[]
  > EOF
  $ application_client frontier_is_not_quantity_cut.ml 2>error
  [2]
  $ grep -q 'Correction_frontier.t' error && grep -q 'Reflected_root_cut.t' error

The shared aggregate is not a public support/balance API.

  $ cat >private_sum_is_not_support.ml <<'EOF'
  > let forge coordinate =
  >   Bakhlo_application.Effect_sum.at Bakhlo_application.Effect_sum.empty coordinate
  > EOF
  $ application_client private_sum_is_not_support.ml 2>error
  [2]
  $ grep -q 'Unbound module.*Effect_sum' error

Multiple anonymous groups bind to one frontier, with explicit re-observation.

  $ cat >current_groups_client.ml <<'EOF'
  > module A = Bakhlo_application
  > module H = A.Current_quantity_groups
  > let inspect frontier assertions coordinate =
  >   let observation : H.group = { reflected_roots = []; assertions } in
  >   match H.create ~frontier ~groups:[ observation ] with
  >   | Error error -> Error error
  >   | Ok image ->
  >     Ok (H.source_frontier image, H.groups image, H.group_for image coordinate,
  >         H.query image coordinate, H.reobserve image observation)
  > EOF
  $ application_client current_groups_client.ml

A global ownership image cannot be forged by ordinary well-typed code.

  $ cat >forged_group_image.ml <<'EOF'
  > module A = Bakhlo_application
  > let forge (frontier : A.Correction_frontier.t) : A.Current_quantity_groups.t =
  >   { frontier; qualified_groups = []; owners = Base.Map.empty (module Bakhlo_domain.Effect_coordinate) }
  > EOF
  $ application_client forged_group_image.ml 2>error
  [2]
  $ grep -q 'Unbound record field "frontier"\|Unbound record field frontier' error

Separately source-bound projections cannot be combined as raw group declarations.

  $ cat >separately_bound_group.ml <<'EOF'
  > module A = Bakhlo_application
  > let mix frontier (projection : A.Current_quantity_projection.t) =
  >   A.Current_quantity_groups.create ~frontier ~groups:[ projection ]
  > EOF
  $ application_client separately_bound_group.ml 2>error
  [2]
  $ grep -q 'Current_quantity_projection.t' error && grep -q 'Current_quantity_groups.group' error

A cut is not the common source frontier.

  $ cat >cut_is_not_group_source.ml <<'EOF'
  > module A = Bakhlo_application
  > let mix (cut : A.Reflected_root_cut.t) =
  >   A.Current_quantity_groups.create ~frontier:cut ~groups:[]
  > EOF
  $ application_client cut_is_not_group_source.ml 2>error
  [2]
  $ grep -q 'Reflected_root_cut.t' error && grep -q 'Correction_frontier.t' error

The physically admitted Actual subset source has a public smart constructor.

  $ cat >actual_source_client.ml <<'EOF'
  > module S = Bakhlo_application.Actual_source
  > let empty () = S.create { events = []; validities = []; validity_corrections = []; corrections = []; descriptions = []; merchants = []; original_amounts = []; exchanges = []; reversals = []; relations = []; discharges = [] }
  > let facts source = Bakhlo_application.Actual_validity.facts (S.validity source)
  > let descriptions source = Bakhlo_application.Event_descriptions.facts (S.descriptions source)
  > EOF
  $ application_client actual_source_client.ml
  $ cat >forged_actual_source.ml <<'EOF'
  > module A = Bakhlo_application
  > let forge frontier validity : A.Actual_source.t = { frontier; validity }
  > EOF
  $ application_client forged_actual_source.ml 2>error
  [2]
  $ grep -q 'Unbound record field.*frontier' error

Retained date history has tagged references and a distinct revision identity, not Event IDs.

  $ cat >validity_history_client.ml <<'EOF'
  > module D = Bakhlo_domain
  > module V = Bakhlo_application.Actual_validity
  > let base event valid_on : V.fact = Base { event; valid_on }
  > let revision id event valid_on : V.fact = Revision { id; event; valid_on }
  > let correction target replacement : V.correction = { target; replacement }
  > let admit events facts corrections = V.create ~events ~facts ~corrections
  > let inspect history id = V.facts history, V.corrections history, V.current_facts history, V.find_current history id
  > EOF
  $ application_client validity_history_client.ml
  $ cat >wrong_date_revision.ml <<'EOF'
  > module D = Bakhlo_domain
  > module V = Bakhlo_application.Actual_validity
  > let wrong (id : D.Identifier.Event.t) event : V.fact = Revision { id; event; valid_on = "2026-10-03" }
  > EOF
  $ application_client wrong_date_revision.ml 2>error
  [2]
  $ grep -q 'Identifier.Event.t' error && grep -q 'Identifier.Validity_revision.t' error
  $ cat >wrong_date_base.ml <<'EOF'
  > module D = Bakhlo_domain
  > module V = Bakhlo_application.Actual_validity
  > let wrong (id : D.Identifier.Validity_revision.t) = V.Base_ref id
  > EOF
  $ application_client wrong_date_base.ml 2>error
  [2]
  $ grep -q 'Identifier.Event.t' error && grep -q 'Identifier.Validity_revision.t' error
  $ cat >forged_history.ml <<'EOF'
  > module V = Bakhlo_application.Actual_validity
  > let wrong (facts : V.fact list) : V.t = facts
  > EOF
  $ application_client forged_history.ml 2>error
  [2]
  $ grep -q 'V.fact list' error && grep -q 'V.t' error
  $ cat >incomplete_date_fact.ml <<'EOF'
  > module V = Bakhlo_application.Actual_validity
  > let wrong (fact : V.fact) = match fact with Base { event; valid_on = _ } -> event
  > EOF
  $ application_client -w +8 -warn-error +8 incomplete_date_fact.ml 2>error
  [2]
  $ grep -q 'warning 8' error && grep -q 'Revision' error
  $ cat >private_cycle.ml <<'EOF'
  > module Wrong = Bakhlo_application.Replacement_cycle
  > EOF
  $ application_client private_cycle.ml 2>error
  [2]
  $ grep -q 'Unbound module.*Replacement_cycle' error

Closed discharges require one qualified relation generation; remainders never become physical support.

  $ cat >discharge_client.ml <<'EOF'
  > module D = Bakhlo_domain
  > module P = Bakhlo_application.Relation_discharges
  > module R = Bakhlo_application.Open_relations
  > module S = Bakhlo_application.Actual_source
  > let admit relations event target quantity = P.create ~relations ~facts:[ { event; target; quantity } ]
  > let retained source = P.source_relations (S.discharges source), P.facts (S.discharges source), P.admitted (S.discharges source)
  > let rows source = P.remainders (S.discharges source)
  > let lookup source id = P.find_remainder (S.discharges source) id
  > let provenance row = P.fact row, P.event row, P.target_relation row
  > let projection remainder = P.relation remainder, P.discharges remainder, P.discharged_quantity remainder, P.remaining_quantity remainder, D.Effect.measure (R.source_effect (P.relation remainder))
  > EOF
  $ application_client discharge_client.ml
  $ cat >events_are_not_discharge_generation.ml <<'EOF'
  > module D = Bakhlo_domain
  > module P = Bakhlo_application.Relation_discharges
  > let wrong (relations : D.Event_memory.t) = P.create ~relations ~facts:[]
  > EOF
  $ application_client events_are_not_discharge_generation.ml 2>error
  [2]
  $ grep -q 'Open_relations.t' error
  $ cat >event_is_not_discharge_target.ml <<'EOF'
  > module D = Bakhlo_domain
  > module P = Bakhlo_application.Relation_discharges
  > let wrong (target : D.Identifier.Event.t) event quantity : P.fact = { event; target; quantity }
  > EOF
  $ application_client event_is_not_discharge_target.ml 2>error
  [2]
  $ grep -q 'Identifier.Relation.t' error
  $ cat >forged_discharges.ml <<'EOF'
  > module P = Bakhlo_application.Relation_discharges
  > let wrong (facts : P.fact list) : P.t = facts
  > EOF
  $ application_client forged_discharges.ml 2>error
  [2]
  $ grep -q 'P.t' error
  $ cat >forged_admitted_discharge.ml <<'EOF'
  > module P = Bakhlo_application.Relation_discharges
  > let wrong (fact : P.fact) : P.admitted = fact
  > EOF
  $ application_client forged_admitted_discharge.ml 2>error
  [2]
  $ grep -q 'P.admitted' error
  $ cat >forged_remainder.ml <<'EOF'
  > module P = Bakhlo_application.Relation_discharges
  > module R = Bakhlo_application.Open_relations
  > let wrong (relation : R.admitted) : P.remainder = relation
  > EOF
  $ application_client forged_remainder.ml 2>error
  [2]
  $ grep -q 'P.remainder' error
  $ cat >remainder_is_not_physical_quantity.ml <<'EOF'
  > module P = Bakhlo_application.Relation_discharges
  > module Q = Bakhlo_application.Current_quantity_query
  > let wrong (remainder : P.remainder) = Q.quantity remainder
  > EOF
  $ application_client remainder_is_not_physical_quantity.ml 2>error
  [2]
  $ grep -q 'Q.exact' error
  $ cat >incomplete_discharge_error.ml <<'EOF'
  > module P = Bakhlo_application.Relation_discharges
  > let wrong = function P.Unknown_event { event; position = _ } -> event
  > EOF
  $ application_client -w +8 -warn-error +8 incomplete_discharge_error.ml 2>error
  [2]
  $ grep -q 'partial-match' error

Relation units keep independent IDs, explicit endpoints and abstract source-qualified positive views.

  $ cat >relation_client.ml <<'EOF'
  > module D = Bakhlo_domain
  > module R = Bakhlo_application.Open_relations
  > module S = Bakhlo_application.Actual_source
  > let admit events id source_event source_effect debtor creditor quantity = R.create ~events ~facts:[ { id; source_event; source_effect; debtor; creditor; quantity } ]
  > let retained source = R.source_events (S.relations source), R.facts (S.relations source), R.admitted (S.relations source)
  > let provenance row = R.fact row, R.source_event row, R.source_effect row, D.Effect.measure (R.source_effect row)
  > let lookup memory id = R.find_by_id memory id
  > let endpoint = function R.Household -> None | External party -> Some party
  > let parse = D.Identifier.Relation.of_string
  > EOF
  $ application_client relation_client.ml
  $ cat >event_is_not_relation_id.ml <<'EOF'
  > module D = Bakhlo_domain
  > module R = Bakhlo_application.Open_relations
  > let wrong (id : D.Identifier.Event.t) source_event source_effect quantity : R.fact = { id; source_event; source_effect; debtor = Household; creditor = Household; quantity }
  > EOF
  $ application_client event_is_not_relation_id.ml 2>error
  [2]
  $ grep -q 'Identifier.Relation.t' error
  $ cat >forged_relations.ml <<'EOF'
  > module R = Bakhlo_application.Open_relations
  > let wrong (facts : R.fact list) : R.t = facts
  > EOF
  $ application_client forged_relations.ml 2>error
  [2]
  $ grep -q 'R.t' error
  $ cat >forged_relation_view.ml <<'EOF'
  > module R = Bakhlo_application.Open_relations
  > let wrong (fact : R.fact) : R.admitted = fact
  > EOF
  $ application_client forged_relation_view.ml 2>error
  [2]
  $ grep -q 'R.admitted' error
  $ cat >relation_is_not_current_quantity.ml <<'EOF'
  > module R = Bakhlo_application.Open_relations
  > module Q = Bakhlo_application.Current_quantity_query
  > let wrong (row : R.admitted) = Q.quantity row
  > EOF
  $ application_client relation_is_not_current_quantity.ml 2>error
  [2]
  $ grep -q 'Q.exact' error
  $ cat >incomplete_relation_endpoint.ml <<'EOF'
  > module R = Bakhlo_application.Open_relations
  > let wrong = function R.Household -> "household"
  > EOF
  $ application_client -w +8 -warn-error +8 incomplete_relation_endpoint.ml 2>error
  [2]
  $ grep -q 'partial-match' error && grep -q 'External' error
  $ cat >raw_events_are_not_relation_memory.ml <<'EOF'
  > module D = Bakhlo_domain
  > module R = Bakhlo_application.Open_relations
  > let wrong (events : D.Event.t list) = R.create ~events ~facts:[]
  > EOF
  $ application_client raw_events_are_not_relation_memory.ml 2>error
  [2]
  $ grep -q 'Event_memory.t' error

Reversal evidence retains typed Event endpoints and abstract pairs; no quantity authorization.

  $ cat >reversal_client.ml <<'EOF'
  > module R = Bakhlo_application.Actual_reversals
  > module S = Bakhlo_application.Actual_source
  > let admit events target reversal = R.create ~events ~facts:[ { target; reversal } ]
  > let retained source = R.source_events (S.reversals source), R.facts (S.reversals source), R.pairs (S.reversals source)
  > let provenance pair = R.fact pair, R.target_event pair, R.reversal_event pair
  > let lookup memory id = R.find_by_target memory id, R.find_by_reversal memory id
  > let role = function R.Target -> "target" | Reversal -> "reversal"
  > EOF
  $ application_client reversal_client.ml
  $ cat >key_is_not_reversal_event.ml <<'EOF'
  > module D = Bakhlo_domain
  > module R = Bakhlo_application.Actual_reversals
  > let wrong (target : D.Identifier.Effect_key.t) reversal : R.fact = { target; reversal }
  > EOF
  $ application_client key_is_not_reversal_event.ml 2>error
  [2]
  $ grep -q 'Identifier.Event.t' error
  $ cat >forged_reversals.ml <<'EOF'
  > module R = Bakhlo_application.Actual_reversals
  > let wrong (facts : R.fact list) : R.t = facts
  > EOF
  $ application_client forged_reversals.ml 2>error
  [2]
  $ grep -q 'R.t' error
  $ cat >forged_reversal_pair.ml <<'EOF'
  > module R = Bakhlo_application.Actual_reversals
  > let wrong (fact : R.fact) : R.pair = fact
  > EOF
  $ application_client forged_reversal_pair.ml 2>error
  [2]
  $ grep -q 'R.pair' error
  $ cat >reversal_is_not_quantity.ml <<'EOF'
  > module R = Bakhlo_application.Actual_reversals
  > module Q = Bakhlo_application.Current_quantity_query
  > let wrong (pair : R.pair) = Q.quantity pair
  > EOF
  $ application_client reversal_is_not_quantity.ml 2>error
  [2]
  $ grep -q 'Q.exact' error
  $ cat >incomplete_reversal_role.ml <<'EOF'
  > module R = Bakhlo_application.Actual_reversals
  > let wrong = function R.Target -> "target"
  > EOF
  $ application_client -w +8 -warn-error +8 incomplete_reversal_role.ml 2>error
  [2]
  $ grep -q 'partial-match' error && grep -q 'Reversal' error

Exchange selections require retained memory and typed Effect keys; aggregate helpers stay private.

  $ cat >exchange_client.ml <<'EOF'
  > module E = Bakhlo_application.Exchange_evidence
  > module S = Bakhlo_application.Actual_source
  > let admit events corrections event source destination = E.create ~events ~corrections ~facts:[ { event; source; destination } ]
  > let retained source = E.source_events (S.exchanges source), E.corrections (S.exchanges source), E.facts (S.exchanges source)
  > let selected memory event = Option.map (fun selection -> E.fact selection, E.event selection, E.source_effect selection, E.destination_effect selection) (E.find_by_event memory event)
  > let side = function E.Source -> "source" | Destination -> "destination"
  > EOF
  $ application_client exchange_client.ml
  $ cat >event_is_not_effect_selector.ml <<'EOF'
  > module D = Bakhlo_domain
  > module E = Bakhlo_application.Exchange_evidence
  > let wrong (event : D.Identifier.Event.t) (destination : D.Identifier.Effect_key.t) : E.fact = { event; source = event; destination }
  > EOF
  $ application_client event_is_not_effect_selector.ml 2>error
  [2]
  $ grep -q 'Effect_key.t' error
  $ cat >forged_exchanges.ml <<'EOF'
  > module E = Bakhlo_application.Exchange_evidence
  > let wrong (facts : E.fact list) : E.t = facts
  > EOF
  $ application_client forged_exchanges.ml 2>error
  [2]
  $ grep -q 'E.t' error
  $ cat >incomplete_exchange_side.ml <<'EOF'
  > module E = Bakhlo_application.Exchange_evidence
  > let wrong = function E.Source -> "source"
  > EOF
  $ application_client -w +8 -warn-error +8 incomplete_exchange_side.ml 2>error
  [2]
  $ grep -q 'partial-match' error && grep -q 'Destination' error
  $ cat >private_measure_totals.ml <<'EOF'
  > module A = Bakhlo_application
  > let wrong = A.Measure_totals.empty
  > EOF
  $ application_client private_measure_totals.ml 2>error
  [2]
  $ grep -q 'Unbound module "A.Measure_totals"' error

Original amounts require a qualified frontier; current associations are not current quantity answers.

  $ cat >original_amount_client.ml <<'EOF'
  > module D = Bakhlo_domain
  > module A = Bakhlo_application.Original_amounts
  > module S = Bakhlo_application.Actual_source
  > let admit frontier root measure quantity = A.create ~frontier ~facts:[ { root; measure; quantity } ]
  > let retained source = A.source_frontier (S.original_amounts source), A.facts (S.original_amounts source)
  > let rows source = A.currents (S.original_amounts source)
  > let provenance current = (A.retained_fact current).root, D.Event.id (A.terminal_event current)
  > let lookup amounts id = A.find_current amounts id
  > EOF
  $ application_client original_amount_client.ml
  $ cat >memory_is_not_amount_frontier.ml <<'EOF'
  > module D = Bakhlo_domain
  > module A = Bakhlo_application.Original_amounts
  > let wrong (memory : D.Event_memory.t) = A.create ~frontier:memory ~facts:[]
  > EOF
  $ application_client memory_is_not_amount_frontier.ml 2>error
  [2]
  $ grep -q 'Correction_frontier.t' error
  $ cat >forged_original_amounts.ml <<'EOF'
  > module A = Bakhlo_application.Original_amounts
  > let wrong (facts : A.fact list) : A.t = facts
  > EOF
  $ application_client forged_original_amounts.ml 2>error
  [2]
  $ grep -q 'A.t' error
  $ cat >forged_current_amount.ml <<'EOF'
  > module D = Bakhlo_domain
  > module A = Bakhlo_application.Original_amounts
  > let wrong (fact : A.fact) (event : D.Event.t) : A.current = { retained_fact = fact; terminal_event = event }
  > EOF
  $ application_client forged_current_amount.ml 2>error
  [2]
  $ grep -q 'Unbound record field "retained_fact"' error
  $ cat >original_is_not_current_quantity.ml <<'EOF'
  > module A = Bakhlo_application.Original_amounts
  > module Q = Bakhlo_application.Current_quantity_query
  > let wrong (amount : A.current) = Q.quantity amount
  > EOF
  $ application_client original_is_not_current_quantity.ml 2>error
  [2]
  $ grep -q 'Q.exact' error

Role-free external party identity cannot be confused with Event/Locus; dispositions are qualified.

  $ cat >merchant_client.ml <<'EOF'
  > module D = Bakhlo_domain
  > module M = Bakhlo_application.Event_merchants
  > module S = Bakhlo_application.Actual_source
  > let admit events event party = M.create ~events ~facts:[ { event; disposition = M.Merchant party } ]
  > let retained source = M.source_events (S.merchants source), M.facts (S.merchants source)
  > let lookup memory id = match M.find_disposition memory id with
  >   | None -> `Unresolved
  >   | Some Nonmerchant -> `Outside
  >   | Some (Merchant party) -> `Provider party
  > EOF
  $ application_client merchant_client.ml
  $ cat >locus_is_not_party.ml <<'EOF'
  > module D = Bakhlo_domain
  > module M = Bakhlo_application.Event_merchants
  > let wrong (place : D.Identifier.Locus.t) = M.Merchant place
  > EOF
  $ application_client locus_is_not_party.ml 2>error
  [2]
  $ grep -q 'External_party.t' error
  $ cat >party_is_not_event.ml <<'EOF'
  > module D = Bakhlo_domain
  > module M = Bakhlo_application.Event_merchants
  > let wrong (party : D.Identifier.External_party.t) : M.fact = { event = party; disposition = M.Nonmerchant }
  > EOF
  $ application_client party_is_not_event.ml 2>error
  [2]
  $ grep -q 'Identifier.Event.t' error
  $ cat >forged_merchants.ml <<'EOF'
  > module M = Bakhlo_application.Event_merchants
  > let wrong (facts : M.fact list) : M.t = facts
  > EOF
  $ application_client forged_merchants.ml 2>error
  [2]
  $ grep -q 'M.t' error
  $ cat >incomplete_disposition.ml <<'EOF'
  > module M = Bakhlo_application.Event_merchants
  > let wrong = function M.Merchant party -> party
  > EOF
  $ application_client -w +8 -warn-error +8 incomplete_disposition.ml 2>error
  [2]
  $ grep -q 'partial-match' error && grep -q 'Nonmerchant' error

Description facts use Event IDs; only the smart constructor yields qualified descriptions.

  $ cat >description_client.ml <<'EOF'
  > module A = Bakhlo_application
  > module E = A.Event_descriptions
  > let fact event text : E.fact = { event; text }
  > let admit events facts = E.create ~events ~facts
  > let retained descriptions = E.source_events descriptions, E.facts descriptions
  > let lookup = E.find_text
  > EOF
  $ application_client description_client.ml
  $ cat >wrong_description_role.ml <<'EOF'
  > module D = Bakhlo_domain
  > module E = Bakhlo_application.Event_descriptions
  > let wrong (event : D.Identifier.Effect_key.t) : E.fact = { event; text = "memo" }
  > EOF
  $ application_client wrong_description_role.ml 2>error
  [2]
  $ grep -q 'Identifier.Effect_key.t' error && grep -q 'Identifier.Event.t' error
  $ cat >forged_descriptions.ml <<'EOF'
  > module E = Bakhlo_application.Event_descriptions
  > let wrong (facts : E.fact list) : E.t = facts
  > EOF
  $ application_client forged_descriptions.ml 2>error
  [2]
  $ grep -q 'E.fact list' error && grep -q 'E.t' error

The composed query needs an admitted source, not a frontier or separate projections.

  $ cat >current_query_client.ml <<'EOF'
  > module A = Bakhlo_application
  > let opening coordinate opening_event : A.Current_quantity_query.opening = { coordinate; opening_event }
  > module Q = A.Current_quantity_query
  > let create source = Q.create ~source ~zero_origins:[] ~openings:[] ~groups:[] ~presence:None
  > let inspect image coordinate = match Q.query image coordinate with
  >   | Error (Support_unknown { coordinate = _ }) -> None
  >   | Ok (Exact answer) -> Some (`Exact (Q.quantity answer, Q.premise answer))
  >   | Ok (Known_present answer) -> Some (`Present (Q.present_coordinate answer, Q.present_evidence answer, Q.present_cut answer))
  > EOF
  $ application_client current_query_client.ml

Presence cannot be consumed as a Quantity or omitted from outcome handling.

  $ cat >presence_is_not_quantity.ml <<'EOF'
  > module Q = Bakhlo_application.Current_quantity_query
  > let wrong (answer : Q.present) = Q.quantity answer
  > EOF
  $ application_client presence_is_not_quantity.ml 2>error
  [2]
  $ grep -q 'Q.present' error && grep -q 'Q.exact' error
  $ cat >outcome_requires_presence.ml <<'EOF'
  > module Q = Bakhlo_application.Current_quantity_query
  > let incomplete (answer : Q.outcome) = match answer with Q.Exact value -> Q.quantity value
  > EOF
  $ application_client -w +8 -warn-error +8 outcome_requires_presence.ml 2>error
  [2]
  $ grep -q 'warning 8' error && grep -q 'Known_present' error

An opening still requires an Event identity, not a Locus.

  $ cat >opening_locus_is_not_event.ml <<'EOF'
  > module D = Bakhlo_domain
  > module Q = Bakhlo_application.Current_quantity_query
  > let wrong coordinate (opening_event : D.Identifier.Locus.t) : Q.opening = { coordinate; opening_event }
  > EOF
  $ application_client opening_locus_is_not_event.ml 2>error
  [2]
  $ grep -q 'Identifier.Locus.t' error && grep -q 'Identifier.Event.t' error
  $ cat >frontier_is_not_current_source.ml <<'EOF'
  > module A = Bakhlo_application
  > let use (source : A.Correction_frontier.t) =
  >   A.Current_quantity_query.create ~source ~zero_origins:[] ~openings:[] ~groups:[] ~presence:None
  > EOF
  $ application_client frontier_is_not_current_source.ml 2>error
  [2]
  $ grep -q 'Correction_frontier.t' error && grep -q 'Actual_source.t' error
