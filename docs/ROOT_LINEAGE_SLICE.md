# Root-to-terminal lineage — conditional on one supplied correction relation

Status: implemented and locally tested; contract/instrument selection recorded
before implementation. User accepted the next evidence-led slice, excluding reflected-root
cuts, quantity/current Actual, storage, CLI/UI, and publication.

## Question, D/P/R and VR-01 selection

Given one `Correction_frontier.t`, which original Event ID is the root of each
disjoint path, and which retained Event is its terminal observation?

- D: existing frontier construction checks endpoint existence in one memory,
  unique targets/replacements, and acyclicity; its sources are retained unchanged.
- P: S1/S2/S4/S5/S6/S9/S10, exact opaque Event identity, and the disjoint-path
  policy already exercised by the frontier slice. Narrow upstream root/terminal
  definitions choose untargeted-by-replacement roots, follow explicit replacements,
  and retain singleton untouched Events. No chronology is encoded in list order.
- R: faithful OCaml root/terminal associations, source retention, independent
  structural oracle, tail-extension stability, and public construction boundaries.

**VR-01 root/terminal review: selection complete before code.**

Use source/evidence inspection plus an executable finite structural model:
immutable transitive closure over integer-labelled graphs, independent of Domain
IDs, production indexes, successor walks, and production constructor results.
First enumerate all 65,536 directed simple graphs on four represented nodes to
check the model's admitted root/terminal partition; then compare implementation
admission/associations against that model over the same graphs. Missing endpoints
and repeated edges lie outside simple-graph enumeration; cover them separately.

This gives bounded structural and model-to-code seam evidence, not unrestricted
proof. For this question, Alloy would repeat the selected finite exploration with
another toolchain; no distinct Alloy experiment is selected. Lean references are
inspected, not rerun or imported. A new general refinement proof remains deferred:
revisit if making unrestricted implementation claims or changing lineage policy.
DRAKON/D2 are not selected because the current single-source operation and inward
library dependencies are inspectable directly. TLA+/SPIN and failure injection
remain for real publication/recovery transitions; no such operation exists here.
No tool/library installation, generic graph package, or production Lean dependency.

VR-02 was OPEN at this slice's stop point. It is subsequently resolved by
[the cut contract](ROOT_CUT_SLICE.md), with its own declaration policy, finite seams
and optional algebraic laws. This root/terminal selection alone did not prove it.

## Upstream correspondence and excluded assumptions

Reference observed at `4d7a29a5`: `Loam/Application/CorrectionFrontierSemantics.lean`
(admissibility/terminal traversal) and `CorrectionFrontierIndexed.lean` (root/terminal
projection and adjacent root-exclusion definitions, lines 206–270). Existing root
cut semantics inform the next question; they do not prove this OCaml code.
No implementation source copied, proof run, upstream write, or private-data access.

Model-to-code mapping: finite integer nodes map injectively to caller-supplied Event
IDs; directed edges map to raw target/replacement corrections. Root/terminal pairs
map to root Event identity plus the exact retained terminal Event, including its
payload. Model closure does not validate identity grammar, payload conservation,
Measure, truth, Actual/Scheduled membership, dates, completeness, or loading.

## Small public contract

Extend `Loam_application.Correction_frontier` rather than introduce a second graph
admission authority or a separately reconstructed index/cache:

- abstract `lineage`, constructed only during successful `create`;
- `lineages : t -> lineage list`, materialized once;
- `root_id : lineage -> Identifier.Event.t`;
- `terminal_event : lineage -> Event.t`.

Each root is an original Event with no incoming correction. Each terminal is
reachable from that root and has no outgoing correction. Untouched Events form
singleton paths with identical root/terminal identity. Every supplied Event belongs
to exactly one path under the existing disjoint-path policy; roots/terminals are
pairwise distinct and terminal membership equals existing frontier membership.

Lineage rows follow **root order in the original Event list**; existing
`frontier_events` still follows terminal order in that list. These orders can differ
and imply no chronology/priority. Correction list permutation cannot select a
winner or change associations. Preserve original Event and correction lists.

"Stable root" means stable when extending a terminal by a fresh replacement while
preserving the admitted relation. It does NOT mean immutable under prefix insertion,
removal, omitted source facts, or arbitrary relation edits. Earlier admitted answers
remain unchanged when a new supplied snapshot is constructed.

Closed endpoint values/raw relation lists cannot manufacture a lineage association.
No forged record construction, guessed default Event, exception for missing lookup,
fuel-exhaustion partial terminal, or best-effort invalid graph answer is intended.
Use the already closed observations in the admission index, walk each disjoint root
path tail-recursively after cycle checks, and discard the transient structures.

## Acceptance before implementation

- Model-only enumeration/partition and a distinguishing invalid-root/terminal witness.
- Empty/untouched/disjoint/multi-hop cases; original payloads including huge exact,
  mixed-Measure, zero/empty observations; source retention and replay/permutation.
- Append a fresh tail: same root, new terminal; old answer unchanged. Prefix insertion
  deliberately changes root and must not be mislabeled a stability guarantee.
- Reuse existing refusals for absent endpoints, repeated edges, branches/merges/cycles;
  no new weakening of admission or outward dependency.
- Compare all four-node simple graphs with the structural oracle, and 10,000 generated
  disjoint paths with seed `loam-root-lineage-v1`, up to 10,000 shrink attempts,
  actual execution count asserted. Long-chain completion in both edge orders.
- Valid external client, forged lineage refusal, closed-edge/frontier type distinction;
  preserve existing CLI goldens, normal/package/install/clean engine-only checks.

## Local qualification

macOS x86_64: model-only enumeration passed before engine changes. Two model
expect tests and nine lineage expect tests now pass. All 65,536 four-node simple
graphs were checked both for model partition properties and model/code admission
and association agreement; all 73 admitted association sets matched. Generated
10,000-path cases with asserted execution count, fresh-tail extension per lineage,
replay/permutation, exact payload retention, explicit prefix re-rooting, and a
10,000-node chain in both correction orders passed. Missing/repeated edges have
separate specimens; neither is implied covered by simple-graph enumeration.

Complete normal/package-mode tests and install pass: 50 expect tests, 70,000
generated cases over seven seeds, three cram suites. The valid external client
inspects lineages without outer CMIs; forged lineage and closed-as-lineage clients
fail with expected diagnostics. Clean engine-only build leaves presentation/CLI
native libraries and CMIs unbuilt. No dependency/toolchain/lock change.

VR-01 root/terminal review and the scoped executable implementation checks are
complete. At that milestone no Alloy/TLA+/Lean tool was run; this model is an
OCaml executable finite exploration, not a formal proof. The later cut slice
separately records optional Lean specification execution; the one-group quantity
slice resolves VR-03, and VR-04 multi-group review is now OPEN.
No current quantity, root cut, observed anchor, historical proof, latency/scale,
platform extension, or operational authority follows from these results.
