# Correction endpoint closure — not currentness

Status: implemented and locally tested after the user's request to continue
professional-quality engine development. Synthetic, read-only, pure OCaml only.

## One question

Does an explicitly supplied correction name two Events present in the same
identity-unique Event memory, and can we return both retained observations?

This is a prerequisite for correction handling, not a correction-frontier policy.
A closed edge does not say which Event is currently authoritative. Self-edges,
cycles, competing replacements, and shared replacements can have closed endpoints;
this slice neither adopts nor rejects them as current corrections. There is no
apply/update/publish operation, date ordering, balance query, or Actual image.

## Obligations before implementation

- D: existing Effects are neutral, signed, exact, and anonymous; ordinary Movement
  has narrower nonempty/nonzero/single-Measure/conservation rules. No Event
  identity, memory, or correction type exists in OCaml at this task's baseline.
- P: semantic contract S1/S4/S5/S6/S8/S9/S10. Existing LOAM separates Event,
  identity-unique EventMemory, raw EventCorrection endpoint projection, and later
  application correction-frontier admission. Source order is not authority.
- R: typed Event identity, faithful immutable observation retention, unambiguous
  indexed identity lookup, ordered missing-endpoint errors, abstract closed answer,
  independent lookup oracle, and explicit non-claims about currentness.

## Evidence/provenance

Inspected upstream at `80e50c7c20ee35d9d22ec95ff5e6626e1286ab82`:
`Loam/Core/Event.lean`, `Loam/Core/EventMemory.lean`, and
`Loam/Core/EventCorrection.lean`. These files are unchanged relative to the earlier
reference `180707c58647dc7cad3361458c1801be184d15af`; the checkout itself has moved.
No implementation text is imported. Lean results are design evidence, not proofs
of this handwritten OCaml implementation. No Lean build or private-data access.

## Small contracts and named consumers

- `Identifier.Event`: distinct nonempty opaque identity, exact spelling/equality,
  mechanical lexical comparator for memory indexing. It does not encode time,
  event kind, purpose, or revision rank; identity is supplied, never allocated.
  Nonempty follows OCaml's existing identifier policy, not upstream's unconstrained
  raw String representation. No migration/import compatibility claim is made.
- `Event`: one identity and a retained list of anonymous neutral Effects. Preserve
  order/multiplicity/exact values. Empty, zero, mixed-Measure, and nonconserving
  observations are representable here; **Event is not ordinary Movement**.
  Keyed Effects and other upstream evidence fields are not represented: never
  import such evidence by dropping its independent keys or metadata.
- `Event_memory`: abstract immutable list plus identity index with matching contents.
  Reject the first repeated identity, even for equal payloads, with original/repeated
  one-based positions. Preserve the supplied list. This is collection validity,
  not publisher retry/idempotency, source completeness, truth, or chronology.
- `Event_correction`: immutable raw target/replacement identities. Raw construction
  makes no claim about existence, graph shape, authority, or compatibility.
- `Correction_check.run`: explicit memory/correction inputs, abstract `closed`
  success retaining both Events and the edge, or nonempty missing-Event errors.
  Check target then replacement; report both if both are absent (including the
  same absent identity requested in both roles). Query uses the memory index;
  it never rewrites/removes observations or chooses a graph terminal.

Existing Base Map is the memory-index consumer; no new dependency or framework.
Private memory/closed representation prevents an inconsistent index or false
endpoint association from being fabricated by ordinary well-typed clients.
No redundant mutable flags, generic command bus, cache, or clock abstraction.

## Laws and acceptance

1. Memory success preserves Event and Effect order/multiplicity and exact payloads.
2. Duplicate identity is refused independently of payload equality/source order.
3. Unique-ID lookup agrees with a simple source-list oracle; absent means None,
   not a synthetic empty Event, empty payload, or zero quantity.
4. Reordering a valid memory changes representation order, never identity lookup
   or which two observations a correction resolves.
5. Success returns the target/replacement actually named by the edge, without
   following another correction or selecting the last record in the list.
6. Missing endpoint roles/identities are explicit and deterministic; errors are
   nonempty. Successful resolution cannot be manufactured via public constructors.
7. Closure of self/cyclic/competing raw edges is not evidence of a current frontier.
8. Lookup/resolution/source inspection do not mutate retained evidence.

Test tiny fixtures, empty/zero/mixed-Measure Events, equal/different-payload duplicate
IDs, exact spelling, huge quantities, both missing roles, self/cyclic/competing edges,
permutation/replay and a generated list oracle with asserted deterministic counts.
Compile a valid external Domain/Application client, reject identifier-role mixups,
forged memory, and forged closed answer. Run normal/package-mode tests, install,
and independently build the engine; preserve all existing CLI golden output.

Qualification on macOS x86_64: seven new expect tests and 10,000 generated cases
(`loam-correction-endpoints-v1`, up to 10,000 shrink attempts, count asserted).
Complete normal/package-mode suites and install pass: 30 expect tests, 50,000
generated cases across five seeds, three cram suites. A clean engine-only build
leaves outer CLI/presentation CMIs and native libraries unbuilt. No external
package/toolchain/lock change; neither operational data nor upstream was changed.

## Stop point and limits

This does not implement admitted current Actual, correction reference closure for
a whole graph, acyclicity, noncompetition, stable correction roots, exclusion cuts,
current anchors, occurrence dates, storage, migration, or publication. Missing or
failed data loading must not be replaced with `Event_memory.of_events []`.

Construction uses a persistent identity map once; individual resolution performs
two indexed lookups, not a source-list or whole-history rebuild. Comparator costs
depend on spelling length. No measured latency/scale guarantee or formal proof.
Next work must specify the separately admitted correction-frontier contract before
using replacements for balances; never wire this endpoint answer straight into
`Zero_origin_projection` as current authority.
