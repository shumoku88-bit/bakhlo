# Reflected-root exclusion — one supplied, qualified relation

Status: implemented and locally tested. VR-02 contract/instrument selection was
recorded before implementation; user accepted proceeding to root exclusion. Current quantities/assertions,
Actual admission, storage, CLI/UI, publication, and operational cutover are excluded.

## Question and D/P/R

Given one `Correction_frontier.t` and independently supplied reflected root IDs,
which whole lineages remain unreflected, with which exact terminal observations?

- D: the constructor already establishes endpoint closure, disjoint paths and
  acyclicity; abstract root/terminal associations are materialized once. Source
  memory and raw correction list are retained unchanged.
- P: S2/S5/S6/S9/S10; ROOT_LINEAGE_SLICE's bounded model/code correspondence and
  fresh-tail stability witnesses. Upstream exclusion selects terminals by root,
  not by old terminal identity or timestamp. Upstream group admission requires
  unique declared roots; its current-anchor entrance requires represented roots.
- R: explicit cut admission/refusals, source binding, order/provenance retention,
  faithful implementation selection, and a reusable terminal-independence law.

## VR-02 — selection complete before implementation

Use narrow source/evidence inspection, reuse the existing immutable transitive-
closure graph model, and extend its integer-labelled specification with list-based
cut admission. Enumerate every four-node admitted graph against all 16 subsets of
represented IDs (73 relations, 1,168 relation/declaration cases). Validate duplicate,
unknown and non-root inputs separately; the enumeration does not include absent
IDs, repeated declarations, or arbitrary five-node graphs. Include fresh-terminal
extensions of these admitted specimens, not a claim of exhaustive five-node scope.
Alloy would duplicate this selected finite structural exploration; no new run.

**Select a small optional Lean artifact now:** for arbitrary finite root/terminal
rows, exclusion by root commutes with ANY terminal-only transformation; also retain
empty-cut and composition laws. This unrestricted algebraic property is worth
retaining independently of the graph bound, because current-anchor corrections
must not leak a reflected lineage when its terminal changes. It does NOT establish
graph-to-row correctness, root stability under relation edits, declaration admission,
OCaml refinement, or current quantities. Handwritten implementation seams still
need independent executable comparisons. Use the already installed Lean 4.33.1
binary; no installation, upstream imports/writes, or production build dependency.

DRAKON/D2 are deferred: one explicit fail-fast scan, one filter, and an inward module
dependency suffice to inspect current refusal order/authority. Revisit if composition
adds ownership or multi-stage fallbacks. TLA+/SPIN/fault injection remain for actual
retry/publication/recovery contracts, absent here. Checker-independence instruments
remain unselected: no such assurance claim is needed. Requalify model/proof mapping
when root-selection policy changes; review graph/refinement proof work before any
unrestricted implementation claim. Review current support/Actual consistency before
quantity composition; this cut alone supplies neither.

## Upstream evidence and deliberate entrance choice

Observed `../loam` at `4d7a29a5`:

- `Loam/Application/CorrectionFrontierIndexed.lean`, root/terminal and
  `correctionFrontierExcludingRoots?` definitions, lines 206–270;
- `Loam/Application/CurrentQuantityAnchor.lean`, `Group.ofLists?` uniqueness and
  `deltaFrontier` represented-root guard.

The lower-level upstream exclusion is permissive on its root list; the group and
current-anchor entrance supply its guards. This OCaml operation deliberately
consolidates those guards at a typed read-only cut entrance, NOT a new household
policy: duplicate/unknown/represented-non-root declarations refuse explicitly.
No silent deduplication or ignored unsupported references. Anonymous reconciliation
groups and asserted quantities are not introduced. Definitions are reference
semantics, not imported source or proofs of this implementation.

## Minimal public contract — `Reflected_root_cut`

A separate Application module consumes a qualified frontier; it does not accept
raw graphs, re-admit paths, or introduce another Root/Cut identity family.

- abstract `t`;
- `create ~frontier ~reflected_roots : (t, error) result`;
- `source_frontier : t -> Correction_frontier.t`;
- `reflected_roots : t -> Identifier.Event.t list` (original declaration order);
- `remaining_lineages : t -> Correction_frontier.lineage list`;
- `remaining_events : t -> Event.t list` (exact terminals of those lineages).

Errors, one-based positions, fail-fast in declaration order:

1. `Duplicate_root { id; first_position; position }` for a prior accepted ID;
2. otherwise accept only a represented root;
3. `Unknown_event { id; position }` if absent from this source memory;
4. `Not_root { id; position }` if represented but incoming-corrected.

Repeated IDs are factual-input errors, not retry/normalization policy. Earlier
invalid input refuses immediately even if a later declaration repeats it. No error
can yield a partial successful cut. Invalid raw graphs cannot be supplied via this
interface; ordinary well-typed clients cannot forge a cut or substitute a closed edge.

Empty declarations exclude nothing; all roots excludes everything; explicitly empty
source/empty declaration is valid. Missing/failed loading is never an empty source.
A root is only the exact Event ID selected by this relation, not label/date/time.
Both intermediate and terminal replacement IDs refuse unless singleton untouched
roots. Output rows follow original ROOT order, matching upstream cut projection;
this can differ from `frontier_events` even for empty declarations. Declaration
permutation changes retained representation, not exclusion or output order.

Keep the source frontier plus the exact declaration list. Materialize remaining
rows and Events once, using transient immutable sets/maps for admission/membership.
No payload narrowing to Movement, arithmetic, synthetic Events, persistent mutable
cache, or revalidation in getters. Filtering results does not erase source facts.

The cut is bound to its immutable supplied frontier. No `apply old_cut new_frontier`
operation exists. Reusing declarations means calling `create` on the new frontier,
which rechecks membership. Fresh-tail extension preserves roots; prefix insertion,
removed roots, or changed source scope can invalidate old declarations and must
refuse. This binding is consistency of supplied values, not global snapshot isolation,
truth of reflection, chronology, history completeness, or publication authorization.

## Proof/model/code mapping and gap

Lean rows are `(root, terminal)` pairs; root predicates map to exact-ID finite-set
membership, terminal transforms to changed observations that leave root IDs intact.
The proof assumes rows, not a graph admission theorem. Integer graph nodes map
injectively to fixture Event IDs; transitive closure supplies expected associations.
Model cut admission uses list inspection, not production maps/sets or success values.
Neither model nor proof validates payload/world truth, identity transport, dates,
asserted balances, loading, or processes. OCaml/compiler/Base/Lean implementations
remain separate trusted boundaries; no formal refinement is claimed.

## Acceptance before code

- Run the optional proof with pinned installed Lean, reject warnings/unfinished
  proofs, record exact tool version and theorem axioms. Ordinary `tools/check`
  must not invoke or require Lean.
- Model-only cut/extension exploration before product changes; compare all 1,168
  four-node declaration cases with actual cut admission and terminal associations.
- Distinguishing `a -> b`, reflected `a`, later `b -> c`: exclude `c` after extension;
  filtering old terminal `b` would leak `c`. Preserve both old/new immutable sources.
- Empty/all/partial/untouched cuts, exact-token distinction, input/output orders,
  huge mixed/zero/empty Event payloads, source retention/replay/permutation.
- Ordered duplicate/absent/non-root diagnostics, prefix re-rooting and omitted-root
  rebinding refusals; invalid declarations never become successful empty answers.
- 10,000 generated path/declaration cases, seed `loam-reflected-root-cut-v1`, up to
  10,000 shrink attempts, count asserted; independent source-list oracle, valid and
  invalid inputs, extension, replay/permutation. 10,000-node chain cut completes.
- Public valid client, forged cut and wrong-qualified-value compiler specimens;
  normal/package/install/clean engine-only checks, unchanged CLI/dependencies.

## Executed local qualification

macOS x86_64: model-only cut exploration and optional specification proof passed
before product changes. Model/code tests then compared all 1,168 relation/subset
cases: 304 admitted cuts and ordered non-root refusals matched; fresh-tail seams
also passed. One model and eight implementation expect tests pass, with 10,000
actual generated cases, seed/counts above, and a 10,000-node chain cut. Empty/all/
partial cases, exact payload/order/source retention, old-terminal leak witness,
prefix/absent-root rebinding refusals, replay and permutation passed.

Lean 4.33.1 release `819816b2e0a3bf405af45ae5c7af2491d8f5bee6` checked three
specification theorems with warnings fatal. Axiom inventory is `[propext]` for
terminal-update commutation and `[propext, Quot.sound]` for empty/composition;
no `sorryAx` or custom axiom. See [artifact/reproduction](../formal/README.md).
The optional script passed positive execution and refused missing selection,
relative path, wrong-version fixture, and isolated proof-hole specimen with expected
statuses/diagnostics. Those guards are focused hygiene, not checker independence.

Normal/package-mode tests and install pass: **59 expect tests**, **80,000 generated
cases** over eight seeds, **three cram suites**. New public cut client compiles;
forged cut, closed-as-cut-source and cut-as-frontier specimens fail with expected
diagnostics. Clean engine-only build leaves presentation/CLI libraries and CMIs
unbuilt. Ordinary `tools/check` also passed with `LEAN` explicitly pointing to a
nonexistent binary, and unchanged product tooling contains no formal invocation.
No runtime/test dependency, lock, storage/UI adapter, or upstream source change.

VR-02 is complete within these stated scopes. VR-03 was OPEN at this milestone;
[the one-group quantity contract](CURRENT_QUANTITY_SLICE.md) subsequently qualifies
independent exact assertions plus unreflected deltas. VR-04 is subsequently resolved
within the [multi-group contract](CURRENT_GROUPS_SLICE.md); VR-05 Actual/support-
family composition is OPEN. A successful empty cut/mathematical zero sum alone still supplies no
origin/current assertion. No OCaml refinement, unrestricted graph law, operational
balance, wider platform or measured latency claim follows.
