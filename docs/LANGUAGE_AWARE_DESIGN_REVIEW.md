# OCaml-aware design and runtime review

Owner: [Bakhlo issue #28](https://github.com/shumoku88-bit/bakhlo/issues/28).
This is a lightweight recurring review, not an optimization backlog or a new gate.
Use native OCaml strengths without accumulating redundant representations, allocation,
fragile persistence shortcuts or unnecessary long-lived process overhead.
[Semantic contract](SEMANTIC_CONTRACT.md) and existing admission/publication owners remain authoritative.

## When and how

- During parser, store, index, query, TUI or event-loop changes, inspect only the
  relevant path and one or two meaningful neighbors. Unrelated work does not need an audit.
- During active development, roughly fortnightly is a suggested opportunity to review
  changes since the last review and existing measurements, not a mandatory schedule.
  Investigate further only when a concrete regression or design drift appears.
- Start with the current implementation and existing tests/benchmarks. Separate what
  source inspection establishes from what needs measurement. A no-findings result is valid;
  running a review does not require an optimization PR.
- Use synthetic inputs and existing isolated wrappers from [Development](DEVELOPMENT.md).
  Do not add audit CI, dependencies, global tools, a Python bridge, a separate framework
  or another test harness by default. This review does not authorize private-data analysis,
  LOAM-original changes, production cutover or pushing changes.

## Questions to retain

1. **Algorithm and ownership before runtime tuning.** Look for repeated full-file reads,
   parsing/admission passes, linear `List` searches, repeated image/query construction and
   redundant materialized views. Identify each check's purpose, generation and owner before
   sharing work: repeated-looking validation may protect a genuinely independent boundary.
2. **Allocation and GC need evidence.** Measure native phase timings, minor allocation,
   promotion, major allocation and peak/steady RSS on a named workload before changing `Gc`
   parameters or adding manual compaction. Distinguish startup, repeated operations and idle
   behavior. OCaml GC does not inherently imply ballooning idle memory; RSS alone is not
   evidence of a leak. State what was actually measured and what was not.
3. **Representation must preserve the contract.** `int` is immediate within its range;
   quantities use `Z.t` for unbounded exact quanta, and Zarith can represent small values
   immediately. Never narrow amount ranges or introduce floats for speed. Inspect string
   copies and intermediate S-expression trees; consider interning or `Bigarray` only after
   demonstrating their cost, ownership and lifetime benefit.
4. **Parsing and mmap are workload-specific choices.** Compare existing Parsexp parsing
   against bounded alternatives only for a demonstrated need. Mapped offsets retain the
   backing store's lifetime; truncation/replacement complicates ownership and concurrent
   mutation can cause SIGBUS. Do not weaken format refusal, CRC, LSN, concurrent-writer or
   torn-write checks to obtain a faster result. mmap is not the default next step.
5. **Correctness and longevity survive every optimization.** Preserve unknown versus zero,
   currency separation, correction/payment links, exact quantities, unsupported-operation
   refusal and recovery behavior. Transient indexes/caches remain rebuildable projections,
   never independent household authority. Confirm the same answers and refusals with the
   existing oracle and relevant tests, not timings alone.

Comparisons with [LOAM's independent Lean review #1946](https://github.com/shumoku88-bit/loam/issues/1946)
concern semantic/functional results. Raw times from different workloads, runtimes or hosts
are not a fair performance ranking.

## First focused candidate — investigation only

Inspect the Records load path in `tui/daily_file.ml`: format acquisition,
`Durable_append.recover_and_open`, post-recovery readback, `Daily_book.of_string`
and the separate `Records_book.of_string` used for LSN/CRC consistency.
The current Daily reader delegates Records decoding to `Records_book.of_string`.
This is a source-level observation, not a measured performance regression.

Ask whether one already-verified parsed Records value can serve multiple consumers
**after recovery**, while preserving whole semantic admission, required fresh reads,
engine/book consistency and race protection. Do not reuse pre-recovery bytes or remove
an independent verification just because its work resembles another pass.

Nearest owners: `sexp/daily_book.ml`, `sexp/records_book.ml`,
`sexp/durable_append.ml`, `tui/daily_file.ml`, the related storage/recovery tests,
and [existing scale/cost evidence](VERIFICATION.md). Respect earlier PR 6 indexing and
bytes-copy improvements; do not accidentally implement them again.
Before proposing a change, compare parse counts, bytes read, phase times, memory and
correctness/refusal outcomes. The storage study now includes monolithic save decomposition
with `./tools/storage-breakdown`, using observed source copies and an original-owner control;
it does not measure the Records load candidate above. Read its scoped results before adding
another probe or repeating existing indexing/GC work. No implementation change is selected
by this guide.

## Short report contract

Use a short issue/PR note rather than a new audit diary or expanding `HANDOFF.md`:

- Date and inspected commit range; name any uncommitted changes included.
- Exact files/owners and the observation or reader question.
- Evidence, workload/toolchain/environment and limits/unmeasured costs.
- Semantic safety: answers/refusals, generation/ownership, recovery and authority boundaries.
- Category: **confirmed**, **hypothesis needing measurement**, **intentional trade-off**
  or **no action**; give a recommendation and any concrete next measurement.

Do not turn a source observation into a measured claim or promise universal performance.
