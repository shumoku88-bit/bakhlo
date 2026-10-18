# TUI ownership target (#42)

This is the implementation boundary decision, not a completion claim. Progress is
owned by `tasks/todo.md`; exercised qualifications by `VERIFICATION.md`.

## Decision

Replace the horizontal controller with vertical screen owners, reusing the existing
Core, sessions, native renderer and publication implementation. Do not create a
second product TUI. The independent assessment found reusable review/draft/tiny
gates in Record, cancellation, bulk, generation and reversal sessions. Recreating
these in a parallel frontend increases regression work without removing the need
for ownership boundaries. Keeping the old State/Context/View architecture and
adding wrappers is also insufficient: its shared workspace and publication-result
handlers still interpret screen-private state.

Each migrated owner replaces its old implementation; no long-lived dual routing.
No accounting semantics, wire format, production authority or new feature is part
of this reconstruction. All experiments use synthetic data.

## Dependencies and capabilities

The intended dependency direction is:

```
Bonsai adapter -> Shell -> screen owners -> pure UI/editor/query modules -> Core
                       -> publication executor -> existing single writer -> Core
```

Owners receive a book snapshot, explicit configuration values, current dimensions
and their own state. They never receive the Shell state. Their interfaces expose
only events, rendering, concrete intents and results needed by callers. Ordinary
OCaml modules and `.mli` boundaries suffice; there is no plugin/event framework.

- **UI primitives** own input, frame, viewport and caret mechanics. A generic
  overlay frame belongs here, not to Balances or Pace.
- **Pure editor contracts** own draft/payload construction and validation. They
  cannot import publication or filesystem capabilities. Time/ID generation must
  enter explicitly when needed; a module alias must not smuggle in a writer.
- **Screen owners** own local selection, focus, scrolling, query assembly, input,
  rendering, forms and tests. Other screens cannot inspect private models.
- **Shell** owns routing, terminal-wide events, explicit cross-screen transfers,
  retained Record drafts, serialization of publication requests and global
  conflict/uncertainty inhibition. It dispatches results; it does not interpret
  a screen's selected row, form fields or follow-up workflow.
- **Publication executor** invokes the existing writer. Requests retain captured
  base bytes and payloads. No auto-retry follows uncertainty. Configuration writes
  retain their own captured bytes and admission requirements.
- **Bonsai adapter** supplies the current dimensions at event application and
  renders the result. Captured stale dimensions must not admit publication.

Local state is stored once. In particular, synchronizing owner state into a second
all-screen `Ui_workspace.t` is a migration debt, not the target architecture.

## Acceptance of boundaries

Compiler/Dune boundaries and a small dependency check must reject Core-to-UI,
owner-to-Shell, owner-to-writer (including aliases/transitive paths), primitive-to-
screen and private cross-screen imports. Negative tests must demonstrate rejection
for the intended reason. Build/test registration must cover every source and
suite. A line-count cap or passing grep alone does not establish ownership.

Feature tests belong to their owners; cross-screen and publication scenarios keep
their own small suites. Existing assertions, fixture transitions, refusals and
loop inputs are preserved with a migration map. The runner contains registration,
not feature assertions. Narrow execution should not require running all suites.

## Measurement

Compare a representative screen-only change and a public-interface change using
the same toolchain: touched source files, compiled units, cold/warm wall time and
relevant/full suite time. Record actual read/edit scope separately from estimates
about future AI effort or merge conflicts. No speedup is implied by extraction.

The beginning baseline is `efda2a3` plus preserved OMP changes: Core passes;
native compilation fails in unfinished Pace code. That failure is not a usable
runtime baseline. Restore and verify it before making before/after runtime claims.
