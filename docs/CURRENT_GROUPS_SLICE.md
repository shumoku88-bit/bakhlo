# Multiple anonymous quantity groups — ownership and explicit re-observation

Status: implemented and locally tested; VR-04 complete within this scope. Contract/
instrument selection below was recorded BEFORE implementation; model-only exploration
and three optional lookup laws passed BEFORE product changes. User requests
continuing with qualified incremental local commits. Baseline `8974041`
contains root/cut/one-group quantity slices. No push, UI, storage, Actual admission,
support-family routing, clock, publication or operational authority is added here.

## Question, D/P/R and source consistency

Can independent reconciliation groups keep different reflected cuts while each
coordinate has ONE live assertion owner, and can explicit re-observation replace
only selected coordinates without changing unrelated premises?

- D: qualified frontier, source-bound cut and one-group projection already retain
  exact facts, refuse duplicates/unsupported coordinates, and materialize components.
- P: S2–S6/S8–S10; one-group/cut laws and bounded executable seams. Upstream
  CurrentQuantityAnchor.Evidence separates groups and globally rejects coordinate
  overlap; replacingWithGroup? removes selected old assertions, drops empty residual
  groups and appends the explicit incoming observation. Groups have no stable ID.
- R: cross-group ownership/index agreement, deterministic admission, binding ALL
  groups to one supplied source, refusal before replacement, preservation of other
  assertion/cut pairs and typed/public construction boundaries.

Evidence inspected at `../loam` revision `4d7a29a5`:
`Loam/Application/CurrentQuantityAnchor.lean`, Group/Evidence definitions and
withoutCoordinates/replacingWithGroup? (lines 33–184). No source-text copy,
upstream proof/build/write, or private-data read. Do not repeat previously earned
cut information-independence questions or claim upstream proves new OCaml.

## VR-04 — selected before code

Use independent list-model ownership/admission/re-observation, direct original-Effect
Zarith quantities, and a finite distinction: two represented roots (one two-Event
path plus one singleton), two exact coordinates, two old groups, each coordinate
in neither/first/second/both group. Vary both old cuts across all root subsets:
256 construction cases, expected 144 admitted. For each admitted case vary all four
incoming-coordinate subsets and four incoming root subsets: 2,304 re-observation
cases. Fixed signed/mixed/huge payloads and quantities; not exhaustive graphs,
quantities, more groups/coordinates or malformed lists. Other errors get fixtures
and 10,000 generated cases (`loam-current-groups-v1`, max 10,000 shrink attempts,
actual execution count asserted). Run the list model alone before product code.

Extend optional installed Lean 4.33.1 specification with three functional ownership
laws: an incoming premise wins at its coordinate, absent incoming support preserves
its old premise (including cut), and applying the same replacement twice is
idempotent at the lookup level. The value is the ENTIRE assertion/cut premise, not
an amount alone. This deliberately abstracts grouping representation, admission,
index correctness and source truth; executable model/code seams remain necessary.
No OCaml/refinement or persistent idempotent publisher claim. Run before product code.

Alloy would duplicate this selected finite ownership exploration; no distinct run.
The old one-pass DRAKON deferral is revisited: record the refusal/operation order
below because qualification precedes pruning. A separate diagram/toolchain adds no
new state to this pure procedure; reconsider DRAKON when source rebinding, multiple
fallback families or ownership effects add paths. D2 remains unselected: one source
argument mechanically owns every qualified group; no new authority topology.
TLA+/SPIN/fault injection remain for real retry/crash/publication contracts, not a
fictional concurrent in-memory workflow. Revisit proof mapping on ownership/update
policy changes; revisit support/Actual admission before operational quantity claims.
No new dependency/installation, production Lean requirement, cache or generic bus.

## Minimal API — `Current_quantity_groups`

Raw immutable `group = { reflected_roots; assertions }` factors independent evidence;
no group ID/date/revision. Use existing Event IDs and one-group assertion type.
Abstract `t` binds all groups by `create ~frontier ~groups`; it does NOT accept a list
of separately source-bound projection values. Each cut is qualified against the
SAME frontier. Reusing facts on different source requires explicit construction;
old declarations can refuse as non-root/absent. No physical-identity heuristic or
structural equality of arbitrary snapshots is needed.

Accessors `source_frontier`, `groups` retain original facts and representation.
`group_for t coordinate : Current_quantity_projection.t option` resolves the unique
qualified group. `query` returns its existing abstract answer or Assertion_unknown;
no new arithmetic, root walk, zero default, source argument or query-time rebuild.

### Refusal/operation order

For `create`, scan groups in declaration order. For each group:

1. qualify reflected-root cut; `Invalid_cut { group_position; error }`;
2. qualify one-group assertions; `Invalid_assertions { group_position; error }`;
3. scan its assertions for cross-group ownership conflicts;
   `Repeated_coordinate { coordinate; first_group_position; first_assertion_position;
   group_position; assertion_position }`.

All positions are one-based. Whole-group local checks precede that group's global
ownership scan (even when an earlier assertion overlaps another group). Earlier
groups' refusal/conflict wins before any later group's checks. Equal quantities or
identical repeated groups are not retry/deduplication/winner policy. No partial image.
Root lists can overlap between groups: coordinates, not roots, have exclusive owners.
Explicit empty groups/image are allowed but their declared roots still qualify;
an unknown root in an empty group is not silently ignored. Admission is eagerly
source-bound, unlike upstream query-lazy root checking; this follows the existing
OCaml cut entrance, not a new statement about external household truth.

### `reobserve t incoming_group`

An explicit pure replacement, not chronology inferred from list order:

1. qualify incoming cut/assertions against `source_frontier t`; malformed incoming
   input refuses before old premises are removed. Incoming errors use group position
   1 (the single incoming declaration), with original within-group positions;
2. remove only incoming coordinates from old assertions, preserving surviving
   assertion order and each group's original root list; drop empty residual groups;
3. retain/reuse untouched qualified groups, rebuild only partially reduced one-group
   projections using their SAME cut, then append the qualified incoming group;
4. reconstruct/check the ownership index and return a new immutable image.

The old image/source remain unchanged even on success/refusal. Existing source
Events/corrections are never pruned. Replacement changes the supplied current-support
value, not a persisted assertion history; no write/receipt/source ownership claim.
Empty incoming assertions replace no coordinate: empty residual old groups are
dropped and the incoming empty group is appended, matching upstream factoring.
Explicit `create` still rejects overlapping live coordinates rather than selecting
an appended group; only `reobserve` performs intentional replacement.

## Acceptance / correspondence / limits

- Model-only finite ownership/update exploration and three optional laws before
  product changes; actual results and axioms versus plans recorded separately.
- Distinguishing cuts: first group reflects root a, second reflects a and x;
  merging cuts would incorrectly erase x's contribution to the first coordinate.
  Re-observe only that coordinate with the second cut; unrelated premise unchanged.
- Ordered root/local/global refusals (including equal repeated groups), exact
  position witnesses, root overlaps allowed, same-coordinate/different-Measure
  separation, huge/zero/mixed Effects, representation and source retention.
- All 256/2,304 finite model/code seams; 10,000 original-source/list-oracle generated
  groups/updates, valid/invalid inputs, unknown support, replay/permutation and
  incoming precedence/noninterference/idempotent lookup. Invalid updates never
  expose a partially emptied image; changed-source declarations rechecked.
- Public valid client; forged image, separately-bound-model input and wrong source
  types refuse with relevant diagnostics. Curated public exports and engine-only
  dependencies remain inward. Normal/package/install and optional proof checks;
  update evidence/handoff and commit the qualified slice before further work.

Models use integer roots/coordinates; fixture mapping to Event IDs/typed coordinates
is injective. Quantity oracle walks original lists, not production owner/totals maps.
The proof treats coordinate → optional whole premise; it does not prove group-list
representation, duplicate guards, query arithmetic, root truth, Actual kind selection,
support-family separation, loading or OCaml refinement. Broader current-support
admission remains a distinct required seam before operational balances.

## Executed local qualification

macOS x86_64, isolated OCaml 5.3.0/Dune 3.24.2, dependency lock unchanged:

- Model-only exploration BEFORE product code: all 256 construction cases, 144
  admitted, 2,304 updates/replays preserve whole-premise support/lookup laws.
- Three optional installed Lean 4.33.1 laws BEFORE product code: incoming/unrelated
  premise `[propext]`, lookup idempotence `[propext, Quot.sound]`. Six earlier laws
  remain checked; no custom axiom/proof hole, warnings fatal. Not grouping/OCaml
  refinement; [reproduction, assumptions and trust boundary](../formal/README.md).
- Eight product expect tests: all finite model/code admission/update/replay seams
  above, original-Effect Zarith decomposition, distinguishing independent-cut
  witness, ordered refusals, partial replacement, empty-group factoring, invalid
  incoming/old-image retention and explicit prefix/omission source-rebinding refusal.
- 10,000 generated cases: raw malformed groups/incoming, separately constructed
  globally unique owners/valid incoming, integer closure/list oracle, direct exact
  quantities, incoming whole-cut precedence, replay/permutation/noninterference.
  Actual count asserted, deterministic seed/shrink bounds as selected above.
- Public client compiles; forged image, separately bound projection-as-group and
  cut-as-source fail with relevant diagnostics. Public root exports seven deliberate
  operations; arithmetic remains private. Existing zero-origin/CLI goldens pass.
- Normal/package/install checks, clean engine-only build and optional proof check
  pass. Presentation/CLI CMIs/native libraries remain unbuilt in engine-only build.
  Ordinary product check passes with nonexistent `LEAN`. Suite: 77 expect tests,
  100,000 generated cases over ten seeds, three cram suites. No new dependency,
  tool bootstrap/lock/product-check change, private data or upstream modification.

Development catches resolved without weakening policy: an assumed test helper did
not exist; explicit original-source equality replaced it. Fatal useless-record-with
warnings removed by writing an explicit complete fixture, not suppressing warnings.
No runtime algorithm change was needed after the model/code seam tests.

VR-05 is OPEN before full Actual/support-family composition. One supplied frontier
is a consistency owner, NOT proof of Actual kind/completeness/assertion/reflection
truth. No measured latency, wider platform, certification or operational cutover
claim. Group reduction retains facts only in old immutable values, not a new durable
history/publication record; those contracts still require their own selection.
