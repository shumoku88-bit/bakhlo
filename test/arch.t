Architecture rules reject intentional violations. Every case starts from a
small valid synthetic tree (no product code) and introduces one violation.

  $ layer() { mkdir -p "$1"; printf '%s\n' "$2" > "$1/dune"; }
  $ base() {
  >   rm -rf t; mkdir t
  >   layer t/lib '(library (name core_lib))'
  >   layer t/tui/kit '(library (name bakhlo_tui_kit) (wrapped false))'
  >   layer t/tui/book '(library (name bakhlo_tui_book) (wrapped false) (libraries bakhlo_tui_kit))'
  >   layer t/tui/protocol '(library (name bakhlo_tui_protocol) (wrapped false) (libraries bakhlo_tui_book))'
  >   layer t/tui/screens/pace '(library (name bakhlo_screen_pace) (wrapped false) (libraries bakhlo_tui_protocol))'
  >   layer t/tui/screens/other '(library (name bakhlo_screen_other) (wrapped false) (libraries bakhlo_tui_protocol))'
  >   layer t/tui/screens/pace/test '(test (name pace_checks) (libraries bakhlo_screen_pace))'
  >   layer t/tui/shell '(library (name bakhlo_tui_shell) (wrapped false) (libraries bakhlo_screen_pace bakhlo.store unix))'
  >   layer t/tui/app '(executable (name main) (libraries bakhlo_tui_shell notty-community))'
  >   echo 'let form = Ui_form.create ~id:"pace_editor" ~payload:"x" ()' > t/tui/screens/pace/pace_screen.ml
  >   echo 'let () = Pool_checks.run ()' > t/tui/screens/pace/test/pace_checks.ml
  >   echo 'let run () = ()' > t/tui/screens/pace/test/pool_checks.ml
  >   echo '(* open_out in a comment *) let text = "Sys.rename"' > t/tui/kit/k.ml
  > }

A valid tree passes; I/O words inside comments and strings are not code.

  $ base; arch_check t
  arch_check: ok

Core may not depend on the TUI.

  $ base; layer t/lib '(library (name core_lib) (libraries bakhlo_tui_kit))'; arch_check t
  lib/dune: Core may not depend on bakhlo_tui_kit
  [1]

UI primitives may not depend on a screen (or anything above them).

  $ base; layer t/tui/kit '(library (name bakhlo_tui_kit) (wrapped false) (libraries bakhlo_screen_pace))'; arch_check t
  tui/kit: kit may not depend on bakhlo_screen_pace (screen pace)
  [1]

A screen may not depend on another screen's private implementation.

  $ base; layer t/tui/screens/other '(library (name bakhlo_screen_other) (wrapped false) (libraries bakhlo_screen_pace))'; arch_check t
  tui/screens/other: screen other may not depend on bakhlo_screen_pace (screen pace)
  [1]

A screen may not depend on the Shell.

  $ base; layer t/tui/screens/other '(library (name bakhlo_screen_other) (wrapped false) (libraries bakhlo_tui_shell))'; arch_check t
  tui/screens/other: screen other may not depend on bakhlo_tui_shell (shell)
  [1]

A screen may not reach the writer, directly or through operating-system access.

  $ base; layer t/tui/screens/other '(library (name bakhlo_screen_other) (wrapped false) (libraries bakhlo.store unix))'; arch_check t
  tui/screens/other: screen other may not depend on bakhlo.store (Shell and above only)
  tui/screens/other: screen other may not depend on unix (Shell and above only)
  [1]

  $ base; echo 'let save path = Durable_append.append path' > t/tui/screens/other/o.ml; arch_check t
  tui/screens/other/o.ml: screen other layer may not use Durable_append
  [1]

  $ base; echo 'let save p s = Out_channel.with_open_bin p (fun c -> output_string c s)' > t/tui/book/b.ml; arch_check t
  tui/book/b.ml: book layer may not use Out_channel
  [1]

  $ base; echo 'let commit = Publication.payload' > t/tui/screens/other/o.ml; arch_check t
  tui/screens/other/o.ml: screen other layer may not use Publication
  [1]

Only the terminal adapter may use the terminal library.

  $ base; layer t/tui/shell '(library (name bakhlo_tui_shell) (wrapped false) (libraries notty-community))'; arch_check t
  tui/shell: shell may not depend on notty-community (terminal adapter only)
  [1]

The Shell may not take back a migrated screen's forms or configuration files.

  $ base; echo 'let handle id = id = "pace_editor"' > t/tui/shell/s.ml; arch_check t
  tui/shell/s.ml: "pace_editor" belongs to screen pace
  [1]

The Shell cannot take back a browser, directly or through a module alias.
Comments and strings remain harmless.

  $ base; echo 'let rows = Record_browser.all_rows' > t/tui/shell/s.ml; arch_check t
  tui/shell/s.ml: shell may not use Record_browser (screen-owned browsing)
  [1]

  $ base; echo 'module RB = Record_browser' > t/tui/shell/s.ml; arch_check t
  tui/shell/s.ml: shell may not use Record_browser (screen-owned browsing)
  [1]

  $ base; echo '(* module RB = Record_browser *) let text = "Record_browser"' > t/tui/shell/s.ml; arch_check t
  arch_check: ok

Every source belongs to a known layer directory with a Dune stanza.

  $ base; mkdir t/tui/screens/other/lost; echo 'let x = 1' > t/tui/screens/other/lost/l.ml; arch_check t
  unknown TUI layer directory tui/screens/other/lost
  [1]

  $ base; rm t/tui/shell/dune; echo 'let x = 1' > t/tui/shell/s.ml; arch_check t
  tui/shell: sources without a dune file are never built
  [1]

Every check module is run by its test executable.

  $ base; echo 'let run () = ()' > t/tui/screens/pace/test/cycle_checks.ml; arch_check t
  tui/screens/pace/test/cycle_checks.ml: check module is not run by pace_checks
  [1]
