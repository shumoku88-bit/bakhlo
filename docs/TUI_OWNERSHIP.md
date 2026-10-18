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
(takes everything but Ctrl-R), Shell overlays, Ctrl-Q/R/N, the route's owner,
then global keys. The view composes Shell header/feedback/footer around the
route owner's rows and draws the modal owner's overlay on top.

## Enforcement (`tools/arch`, run by Core `dune runtest`)

Dune enforces declared library use. `tools/arch/arch_check.ml` additionally
rejects: Core depending on TUI libraries; a library depending on a higher or
sibling layer (screen to screen, screen to Shell, kit to anything); `bakhlo.store`
or `unix` below the Shell; Bonsai/Notty outside `tui/app`; file access or writer
tokens (`Durable_append`, `open_out`, `Sys.rename`, `Daily_file`,
`Daily_actions`, …) in kit/book/protocol/screens; the Shell mentioning a
migrated screen's form ids, field ids or configuration files; sources in a
directory without a Dune stanza or outside a known layer; and `*_checks`
modules that their runner never calls. `test/arch.t` creates one violation per
rule and asserts the rejection message. A few literals still shared with
unmigrated Shell workflows are listed in `legacy_shared_literals`; that list
may only shrink.

## Tests

- `tools/tui --self-check` = `tools/build-bonsai-tui --test`: every TUI check.
- `tools/build-bonsai-tui --test screens/pace` (any subdirectory): one owner.
- Screen owner checks are pure (`Screen.env` built in memory, no files).
- `tui/app/test/app_checks` runs Shell session checks, cross-screen scenarios
  and Bonsai adapter checks with the real cell width, outside Dune's sandbox
  (the writer refuses symlinked inputs) from a materialized synthetic copy of
  `examples/daily-book.sexp`.
- The 34 suite PASS lines are compared with `efda2a3` after every slice;
  assertion labels and conditions were compared when files moved
  (40 conditions changed only where state moved into an owner; none weakened).

## Known defects found while migrating (not yet changed)

- `accounting-roles.tsv` is read through a path search that turns an
  unreadable file into empty roles, and the Loci role editor writes it
  non-atomically and ignores one save error. To be fixed when Loci moves to
  `Save_config`.
- Cycle-boundary saves now check the pure preconditions before the household
  admission; any failure still refuses with the same message family.
