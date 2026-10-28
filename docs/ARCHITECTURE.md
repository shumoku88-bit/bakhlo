# Architecture

The current shape of the code. Meaning and safety rules: [semantic contract](SEMANTIC_CONTRACT.md);
today's work: [handoff](HANDOFF.md); TUI layering in detail: [TUI ownership](TUI_OWNERSHIP.md).
The previous long version (storage research, the old CLI, client options) is in Git at
`90a5867:docs/ARCHITECTURE.md`.

## Layers

```text
tui/app ─> tui/shell ─> tui/screens/<s> ─> tui/protocol ─> tui/book ─> tui/kit
               │                                              │
               └─> store ─> household ─> book_txt <───────────┘
```

| Directory | Library | Role | Dependencies |
|---|---|---|---|
| `household/` | `bakhlo.household` | `Book` (the household book: an admitted `Book_txt.book` and its TXs as entries; every change is one `Book_txt.change` after Bakhlo's write policies; balances, Daily Pace and past-day pools; the changes the Shell publishes, roles and Attention included; its book.txt text both ways with `read` and `print`; an entry holds book.txt postings) | book_txt |
| `store/` | `bakhlo.store` | `Book_file`: the single writer of `book.txt` (load, whole-file publish with `F_FULLFSYNC` and `.prev`, conflict and uncertain outcomes, copies). The session keeps the admitted book, so a save checks and prints only what it changes | household, book_txt, Unix, a C stub |
| `tui/` | nested Dune project (`tui/dune-project`) | English terminal UI; only `tui/app` uses Notty | store and Core |
| `book_txt/` | `bakhlo.book_txt` | `Book_txt`: the line-based `book.txt` shared with LOAM (`docs/COMMON_FORMAT.ja.md`); read, admit, print, current balance, and the admitted `book` whose `change` admits a change by the same rules without re-reading untouched TXs. The household store reads and writes it | Zarith |

Dependencies point inward only. `book_txt/` and `household/` are pure: no clock,
filesystem, randomness or global state; every input is an explicit immutable value.
File I/O lives in `store/` and `tui/shell`; terminal effects in `tui/app`.

`household/amount.ml` owns exact amount text and arithmetic independently of a book;
`Book` supplies the admitted Measure scale and keeps its existing input API.
`Book_file.t` is a private record: callers may read the session, but cannot replace
its book, path or revision separately. Observe, roles and Attention use the same
publication-result mapping and pending-revision recovery as ordinary recording.
Configuration and settlements keep their own admission and conflict checks and
share only the durable file-replacement mechanism (`Book_file.write_atomic`).

Matching editor layouts share `Ui_form.render_panel` for forms and
`Ui_panel.preview` for previews with notice/action rows, and `Ui_panel.preview_window`
/ `review_scroll` for the review's window and scroll keys. These helpers only own
frame geometry and scrolling; each editor keeps its content, actions, key set and
terminal-size guards. Report screens share `Report_frame.content` (scrollable body
or refusal block) and `Report_period.handle_overlays` (print preview, then help).
Centred overlays go through `Ui_overlay.form` / `centered`, row motion keys through
`Ui_input.motion_delta`, and Selected Day and Scheduled share
`Record_browser.search_overlay`.

## What enforces it

- Dune libraries: an undeclared dependency does not compile (`implicit_transitive_deps
  false` in the TUI project).
- `tools/arch/arch_check.ml` (run by `./tools/check`): TUI layer ↔ library mapping, no
  stray sources, no file I/O in pure layers, every check module is run.
- `test/type_boundaries.t`: abstract types cannot be forged by an outside client.
- `test/compiler_policy.t`: `-strict-sequence` and fatal warnings 8/9/11 in every profile.
- `test/book_cold_reload_tests.ml`: every in-place `Book` mutation equals the cold
  reload of its book.txt; `test/book_txt_tests.ml`: change admission equals whole-file
  admission and the kept balances equal the specification's.

## Portability note (MirageOS)

The pure core (`book_txt`, `household`) needs only Base and Zarith. Only
`store/` (Unix, `F_FULLFSYNC` stub) and the TUI (Notty, Unix terminal) are host-specific,
so another runtime replaces those edges, not the core. An earlier Solo5-SPT boot of the former `lib/` and `application/`
is recorded in `90a5867:docs/VERIFICATION.md` ("Linux native replay and MirageOS/Solo5-SPT
engine"), with the VM recipe in `90a5867:docs/DEVELOPMENT.md`.
