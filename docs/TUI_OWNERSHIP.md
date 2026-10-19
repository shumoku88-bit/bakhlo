# TUI ownership architecture (#42)

This file owns the TUI structure and its enforcement. Progress lives in
`tasks/todo.md`; exercised qualifications in `docs/VERIFICATION.md`; screen
behaviour in `tui/README.md`.

## Decision

Keep the existing Core, writer, editor sessions and renderer; replace the
horizontal controller (one State, one Context, one input function, one view
for every screen) with screen owners behind one small contract and a thin
Shell. A second parallel TUI was rejected: the mature sessions (Record,
reversal, date correction, cancellation, bulk, generation) and ~1,400
scenario assertions would have to be re-earned with no structural gain.
Migrated code is ported faithfully from the controller; an owner that
re-implements behaviour is not accepted (the unverified OMP Daily Pace owner
was replaced for this reason, see `0e537c8`).

## Layers

All TUI code builds in its own Dune project (`tools/build-bonsai-tui`) with
`implicit_transitive_deps false`, so using an undeclared library is a compile
error. Directory = layer:

| Directory | Library | May use |
|---|---|---|
| `store/` (Core workspace) | `bakhlo.store` | Core. The single household writer. |
| `tui/kit` | `bakhlo_tui_kit` | nothing of Bakhlo: input, cell geometry, frames, viewports, forms, overlays |
| `tui/book` | `bakhlo_tui_book` | kit, Core: pure drafts/candidates, calendar arithmetic, evidence text |
| `tui/protocol` | `bakhlo_tui_protocol` | kit, book: `Screen`, the Shell/screen contract |
| `tui/screens/<s>` | `bakhlo_screen_<s>` | kit, book, protocol, Core |
| `tui/screens/<s>/test` | test | its own screen and lower layers |
| `tui/shell` | `bakhlo_tui_shell` | everything below, `bakhlo.store`, `unix` |
| `tui/shell/test`, `tui/scenarios` | check libraries | Shell and below |
| `tui/app` | `bakhlo_tui_terminal`, `bonsai_daily` | Shell, Bonsai runtime |
| `tui/app/test` | `app_checks` | whole program |

Core never sees `tui/` (data only, for the check below).

Shell modules (`tui/shell`): `shell_state` (state, route entry, Record retention,
publication results) → `shell_record_actions` (Record_action targets),
`shell_files` (configuration and annual-history I/O), `shell_publication`
(ledger publications through the single writer) → `shell_dispatch` (env,
geometry, owner input/view, request application, reload, back, Commands,
annual rollover) → `shell_input` and `shell_view`. `screen_registry` lists
every owner; `daily_actions` and `record_session` are the retained Record
flow over `bakhlo.store`.

## The screen contract (`tui/protocol/screen.mli`)

A screen owner is an ordinary module with private state:

```ocaml
val config_files : string list
val create : unit -> t
val modal : t -> bool
val handle : Screen.env -> Screen.geometry -> t -> Ui_input.input -> t * Screen.request
val view : Screen.env -> Screen.geometry -> t -> Screen.view
val saved : Screen.env -> Screen.geometry -> (unit, string) result -> t -> t * Screen.request
```

`Screen.env` is read-only household context (book snapshot, Shell-selected
Measure, today, lazily verified annual provenance, accounting roles, captured
bytes of the declared configuration files, writes-stopped flag).
`Screen.request` is the only way out: `Stay`, `Ignored` (the Shell then applies
its global keys), `Message`, `Home`, `Commands`, `Reload`, `Cycle_measure`,
`Observe`, `Save_config` (with captured bytes and an admission precondition).
Owners never receive Shell state, never write and never see another screen.

Shell input order: paste guard, retained Record, a screen with an open editor
(takes everything but Ctrl-R, which always reloads), Shell overlays, Ctrl-Q/R/N, the route's owner,
then global keys. The view composes Shell header/feedback/footer around the
route owner's rows and draws the modal owner's overlay on top.
Selected Day owns its retained browser, panes, viewport and deferred search.
Its search ignores Ctrl-Q/N while typing (Ctrl-R reloads under it, keeping the text),
and the browser query changes only on Enter or Escape. Calendar's browser is
unchanged while Selected Day synchronizes its own selection.

Home and Calendar share `Calendar_home_screen`: one retained browser, pane,
raw scroll offset and deferred Search/Jump inputs. Home search also filters
later Calendar visits; the old ambient search on other owners remains visible
and keeps the underlying route footer. Its searches ignore Ctrl-Q/N; Ctrl-R reloads.
Every route entry notifies this owner; synchronization resets selection on
empty external routes, preserves filters/order, and leaves its browser alone
on Selected Day. A direct drill return to Actual only notifies entry, without
synchronizing the Calendar browser. Legacy fallback navigation changes this
owner's private model rather than a Shell pane/browser mirror.
`Ui_workspace` now contains only route, calendar focus and Measure; Shell
record actions take the protocol's explicit `Screen.Entry`/`Screen.Plan` target. Calendar focus/zoom remain Shell authority through
`Set_calendar`; its explicit feedback policy preserves Esc zoom-back warnings.
Home paints the entire headerless body and alone forces the lazy annual notice.
The Shell retains the cross-year unavailable frame, including when predecessor
provenance becomes stale while a guarded screen is already open.

## Enforcement (`tools/arch`, run by Core `dune runtest`)

Dune enforces declared library use. `tools/arch/arch_check.ml` additionally
rejects: Core depending on TUI libraries; a library depending on a higher or
sibling layer (screen to screen, screen to Shell, kit to anything); `bakhlo.store`
or `unix` below the Shell; Bonsai/Notty outside `tui/app`; file access or writer
tokens (`Durable_append`, `open_out`, `Sys.rename`, `Daily_file`,
`Daily_actions`, …) in kit/book/protocol/screens; the Shell mentioning a
migrated screen's form ids, field ids or configuration files; sources in a
directory without a Dune stanza or outside a known layer; and `*_checks`
modules that their runner never calls; and the Shell using `Record_browser`
(directly or through a module alias), since record browsing is screen-owned. `test/arch.t` creates one violation per
rule and asserts the rejection message. `legacy_shared_literals` (now empty) is the only
escape hatch for a file shared with an unmigrated workflow; it may not grow.

## Tests

- `tools/tui --self-check` = `tools/build-bonsai-tui --test`: every TUI check.
- `tools/build-bonsai-tui --test screens/pace` (any subdirectory): one owner.
- Screen owner checks are pure (`Screen.env` built in memory, no files).
- Pure checks of a screen library live beside it in `tui/screens/<s>/test`
  (Actual workspace, Scheduled sessions); the app runner passes the native
  cell width.
- `tui/app/test/app_checks` runs Shell session checks, owner checks, cross-screen scenarios
  and Bonsai adapter checks with the real cell width, outside Dune's sandbox
  (the writer refuses symlinked inputs) from a materialized synthetic copy of
  `examples/daily-book.sexp`.
- The 34 suite PASS lines are compared with `efda2a3` after every slice;
  assertion labels and conditions were compared when files moved
  (40 conditions changed only where state moved into an owner; none weakened).

## Known defects found while migrating (not yet changed)

- `accounting-roles.tsv` is still read through a path search that turns an
  unreadable file into empty roles (`Screen.env.accounting_roles`). Writing
  was fixed when Loci moved: roles are saved with `Save_config` (captured
  bytes, atomic, failures shown), including the role chosen at admission.
- Settlements and Loci keep legacy navigation: Esc/q always return Home and
  Page/Home/End reset the list to its first row. Print previews stay open on
  Done. A successful publication still clears a retained Record draft
  (`finish_publication`), even when it came from another screen.
- Cycle-boundary saves now check the pure preconditions before the household
  admission; any failure still refuses with the same message family.
- Decision (2026-10-19, user: "the natural UI"): every open search or editor
  takes all keys but Ctrl-R. Ctrl-R reloads (as the footer advertises) and keeps
  the search text; Ctrl-Q/N stay ignored while typing. The old central Search
  overlay consumed Ctrl-R. Checked for Selected Day, Home and Scheduled.
