# Architecture

The current shape of the code. Meaning and safety rules: [semantic contract](SEMANTIC_CONTRACT.md);
today's work: [handoff](HANDOFF.md). The TUI's own layering is in
[TUI_OWNERSHIP](TUI_OWNERSHIP.md); the previous long version (storage research, the old CLI, client options) is at
`90a5867:docs/ARCHITECTURE.md`.

## Layers

```text
tui ─> cli ─> store ─> household ─> book_txt
        └──────────────┘
```

| Directory | Library | Role | Dependencies |
|---|---|---|---|
| `book_txt/` | `bakhlo.book_txt` | `Book_txt`: the line-based `book.txt` shared with LOAM (`docs/COMMON_FORMAT.ja.md`); read, admit, print, current balance, and the admitted `book` whose `change` admits a change by the same rules without re-reading untouched TXs | Zarith |
| `household/` | `bakhlo.household` | Every household rule: `Book` (entries, plans, balances, Daily Pace, past paces, roles, Attention; every change is one `Book_txt.change` after Bakhlo's write policies), `Record` (the record form, refunds, exchanges), `Schedule` (plans in series), `Query` (finding records), `Amount`, `Day`, `Period` and the reports | book_txt |
| `store/` | `bakhlo.store` | `Book_file`: the single writer of `book.txt` (load, whole-file publish with `F_FULLFSYNC` and `.prev`, conflict and uncertain outcomes, copies) | household, book_txt, Unix, a C stub |
| `cli/` | `bakhlo.cli`, executable `bakhlo` | The bk commands: ask one line at a time, preview, save through `Book_file`, print tables aligned by display width; settings files beside the book | store and the core |
| `tui/` | its own Dune project, executable `bakhlo_tui` (what `bk` runs) | The screens: plain `bk` opens them, `bk COMMAND` runs the `cli/` command. Notty draws; the Shell owns the single writer's use | cli, store, the core, Notty, uutf, Base |

Dependencies point inward only. `book_txt/` and `household/` are pure: no clock,
filesystem, randomness or global state; every input is an explicit immutable value.
File I/O lives in `store/`, `cli/` (settings files) and the TUI's Shell; the commands read
the clock once in `cli/command_line.ml`, the screens in `tui/shell/clock.ml`.

## What enforces it

- Dune libraries: an undeclared dependency does not compile (in `tui/`, not even a
  transitive one); `tools/arch` pins the TUI's layer order and `test/arch.t` shows each
  rule refusing a violation.
- The answer samples in `test/` (one format, `test/README.md`) pin every household rule;
  `cli/test/` runs every bk command on synthetic books with scripted answers;
  `tui/` runs its screens on synthetic books (`tools/tui --self-check`) and CI drives the
  program on a real PTY (`tools/ci-tui-pty`).
- `test/type_boundaries.t`: abstract types cannot be forged by an outside client.
- `test/compiler_policy.t`: `-strict-sequence` and fatal warnings 8/9/11 in every profile.
- `test/book_cold_reload_tests.ml`: every in-place `Book` mutation equals the cold
  reload of its book.txt; `test/book_txt_tests.ml`: change admission equals whole-file
  admission and the kept balances equal the specification's.

## Portability note

The pure core (`book_txt`, `household`) needs only Base and Zarith. Only `store/` (Unix,
`F_FULLFSYNC` stub), `cli/` (standard input and output) and `tui/` (the terminal) touch the host, so another
runtime or language replaces those edges and keeps the core's samples.
