The household launcher must run the pushed code in its own worktree, from an installed
copy that a failed build cannot take away, and warn and exit nonzero on any backup
problem, while a nonzero TUI exit is reported unchanged and wins over the backup
status. Synthetic local Git and bare remotes only: user/global Git config, signing and
the network are disabled; the fake build installs a fake TUI as the worktree binary,
tagged with the commit it was built from, which the launcher copies to .run.

  $ export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_TERMINAL_PROMPT=0
  $ export HOME="$PWD/home"
  $ mkdir -p "$HOME"

  $ mkdir -p run/tools
  $ cp ../tools/household run/tools/household
  $ cat > run/tools/tui <<'EOF'
  > #!/bin/sh
  > if [ "${FAKE_TUI_EDIT:-0}" = 1 ]; then
  >   printf 'record\n' >> "${FAKE_TUI_BOOK}"
  > fi
  > exit "${FAKE_TUI_STATUS:-0}"
  > EOF
  $ cat > run/tools/opam <<'EOF'
  > #!/bin/sh
  > # Fake build: install the fake TUI as the worktree binary, tagged with the commit.
  > root=""
  > while [ "$#" -gt 0 ]; do
  >   if [ "$1" = "--root" ]; then root=$2; shift 2; continue; fi
  >   shift
  > done
  > commit=$(git -C "$root" rev-parse --short HEAD)
  > mkdir -p "$root/_build/default/tui/app"
  > {
  >   printf '#!/bin/sh\n'
  >   printf 'printf "TUI built from %%s\\n" "%s"\n' "$commit"
  >   cat "$(dirname -- "$0")/tui"
  > } > "$root/_build/default/tui/app/bakhlo_tui.exe"
  > chmod +x "$root/_build/default/tui/app/bakhlo_tui.exe"
  > EOF
  $ chmod +x run/tools/tui run/tools/opam run/tools/household

The launcher runs its own repository: a fake origin with a pushed main branch.

  $ cd run
  $ git init -q -b main .
  $ git config user.name test
  $ git config user.email test@example.invalid
  $ git config commit.gpgsign false
  $ git add -A
  $ git commit -q -m initial
  $ git init -q --bare -b main ../remote.git
  $ git remote add origin ../remote.git
  $ git push -q -u origin main
  $ cd ..

  $ mkhousehold() {
  >   git init -q -b main "$1"
  >   git -C "$1" config user.name test
  >   git -C "$1" config user.email test@example.invalid
  >   git -C "$1" config commit.gpgsign false
  >   : > "$1/book.sexp"
  >   git -C "$1" add -A
  >   git -C "$1" commit -q -m initial
  > }
  $ setremote() {
  >   git init -q --bare -b main "$2"
  >   git -C "$1" remote add origin "$2"
  >   git -C "$1" push -q -u origin main
  > }
  $ runhh() {
  >   status=0
  >   (cd run && BAKHLO_HOUSEHOLD="$1" FAKE_TUI_BOOK="$1/book.sexp" \
  >     FAKE_TUI_STATUS="$2" FAKE_TUI_EDIT="$3" sh ./tools/household) \
  >     > "$PWD/out.log" 2>&1 || status=$?
  >   sed -e 's/[0-9a-f]\{7,\}/SHA/g' "$PWD/out.log"
  >   return $status
  > }

The launcher fetches origin/main, builds it in its own worktree, installs the built binary
at a stable path and names the commit it runs; nothing is recorded or pushed.

  $ H0="$PWD/h0"; mkhousehold "$H0"; setremote "$H0" "$PWD/r0"
  $ runhh "$H0" 0 0
  Building bakhlo SHA …
  Running bakhlo from commit SHA
  TUI built from SHA
  $ grep -qF "Running bakhlo from commit $(git -C run rev-parse --short origin/main)" out.log && echo commit-named
  commit-named
  $ test "$(git -C run/.run/src rev-parse HEAD)" = "$(git -C run rev-parse origin/main)" && echo worktree-at-origin-main
  worktree-at-origin-main
  $ test -x run/.run/src/_build/default/tui/app/bakhlo_tui.exe && echo worktree-binary-built
  worktree-binary-built
  $ test -x run/.run/bakhlo_tui.exe && echo stable-copy-installed
  stable-copy-installed

The launcher runs the installed copy, not the worktree's build output.

  $ printf '#!/bin/sh\nprintf "worktree binary ran\\n"\n' > run/.run/src/_build/default/tui/app/bakhlo_tui.exe
  $ chmod +x run/.run/src/_build/default/tui/app/bakhlo_tui.exe
  $ runhh "$H0" 0 0
  Running bakhlo from commit SHA
  TUI built from SHA

A moved origin/main is rebuilt and the new commit is run.

  $ git -C run commit -q --allow-empty -m moved
  $ git -C run push -q origin main
  $ runhh "$H0" 0 0
  Building bakhlo SHA …
  Running bakhlo from commit SHA
  TUI built from SHA
  $ grep -qF "TUI built from $(git -C run rev-parse --short origin/main)" out.log && echo rebuilt-at-the-new-commit
  rebuilt-at-the-new-commit

A recording is staged whole-household (book plus an untracked config file), committed,
pushed, and the remote configuration is left unchanged.

  $ H1="$PWD/h1"; mkhousehold "$H1"; setremote "$H1" "$PWD/r1"
  $ git -C "$H1" config --get remote.origin.url > before-url
  $ printf 'extra config\n' > "$H1/config.txt"
  $ runhh "$H1" 0 1
  Running bakhlo from commit SHA
  TUI built from SHA
  Household changes committed.
  Household backup pushed.
  $ git -C "$H1" log --oneline '@{upstream}..'
  $ git -C "$H1" ls-tree -r --name-only HEAD
  book.sexp
  config.txt
  $ git -C "$H1" config --get remote.origin.url > after-url
  $ diff before-url after-url && echo remote-url-unchanged
  remote-url-unchanged

A rejecting commit hook warns, fails the exit, keeps the change staged, and makes no
new commit.

  $ H2="$PWD/h2"; mkhousehold "$H2"; setremote "$H2" "$PWD/r2"
  $ cat > "$H2/.git/hooks/pre-commit" <<'EOF'
  > #!/bin/sh
  > exit 1
  > EOF
  $ chmod +x "$H2/.git/hooks/pre-commit"
  $ runhh "$H2" 0 1
  Running bakhlo from commit SHA
  TUI built from SHA
  Household commit failed; the change stays staged locally.
  [1]
  $ git -C "$H2" rev-list --count HEAD
  1
  $ git -C "$H2" status --porcelain
  M  book.sexp

No upstream is an explicit warning and a failed exit, never a silent skip.

  $ H3="$PWD/h3"; mkhousehold "$H3"
  $ runhh "$H3" 0 1
  Running bakhlo from commit SHA
  TUI built from SHA
  Household changes committed.
  No upstream branch configured; local commits cannot be pushed.
  [1]
  $ git -C "$H3" rev-list --count HEAD
  2

A rejecting pre-receive hook fails the push but keeps the local commit; removing the
hook and running again with no new edit retries the pending commit successfully.

  $ H4="$PWD/h4"; mkhousehold "$H4"; setremote "$H4" "$PWD/r4"
  $ cat > "$PWD/r4/hooks/pre-receive" <<'EOF'
  > #!/bin/sh
  > exit 1
  > EOF
  $ chmod +x "$PWD/r4/hooks/pre-receive"
  $ runhh "$H4" 0 1 > push.log 2>&1
  [1]
  $ grep -F 'pre-receive hook declined' push.log >/dev/null && echo git-reason-retained
  git-reason-retained
  $ grep -E '^(Household changes committed\.|Push failed;)' push.log
  Household changes committed.
  Push failed; the commit is kept locally and will be pushed next time.
  $ git -C "$H4" rev-list --count HEAD
  2
  $ rm "$PWD/r4/hooks/pre-receive"
  $ runhh "$H4" 0 0
  Running bakhlo from commit SHA
  TUI built from SHA
  Household backup pushed.

A nonzero TUI exit is preserved even when the backup also fails.

  $ H5="$PWD/h5"; mkhousehold "$H5"
  $ runhh "$H5" 7 1
  Running bakhlo from commit SHA
  TUI built from SHA
  Household changes committed.
  No upstream branch configured; local commits cannot be pushed.
  [7]

A nonzero TUI exit also survives a successful, clean backup.

  $ runhh "$H0" 7 0
  Running bakhlo from commit SHA
  TUI built from SHA
  [7]

A staging lock stops before committing or announcing a push.

  $ H6="$PWD/h6"; mkhousehold "$H6"; setremote "$H6" "$PWD/r6"
  $ touch "$H6/.git/index.lock"
  $ runhh "$H6" 0 1 > staging.log 2>&1
  [1]
  $ grep -F 'index.lock' staging.log >/dev/null && echo git-reason-retained
  git-reason-retained
  $ grep '^Household staging failed;' staging.log
  Household staging failed; the book was not committed or pushed.
  $ git -C "$H6" rev-list --count HEAD
  1
  $ grep -c 'Household backup pushed.' staging.log
  0
  [1]

A failed pending-log command is not mistaken for an empty list.

  $ H7="$PWD/h7"; mkhousehold "$H7"; setremote "$H7" "$PWD/r7"
  $ export REAL_GIT="$(command -v git)"
  $ mkdir bin
  $ cat > bin/git <<'EOF'
  > #!/bin/sh
  > if [ "${3:-}" = log ]; then
  >   echo 'synthetic pending-log failure' >&2
  >   exit 2
  > fi
  > exec "$REAL_GIT" "$@"
  > EOF
  $ chmod +x bin/git
  $ PATH="$PWD/bin:$PATH" runhh "$H7" 0 1
  Running bakhlo from commit SHA
  TUI built from SHA
  Household changes committed.
  synthetic pending-log failure
  Failed to list pending commits; nothing was pushed.
  [1]
  $ export PATH="${PATH#"$PWD/bin:"}"

Offline keeps the last built binary and says so.

  $ git -C run remote set-url origin "$PWD/missing-remote.git"
  $ runhh "$H0" 0 0
  Offline: origin/main could not be fetched; the last built binary is used.
  Running bakhlo from commit SHA
  TUI built from SHA
  $ grep -qF "TUI built from $(git -C run rev-parse --short origin/main)" out.log && echo last-binary-used
  last-binary-used

A failed build keeps the previous binary and names the commit it could not build. The
failing build removes the target it was going to replace; the installed copy stays.

  $ git -C run remote set-url origin "$PWD/remote.git"
  $ cat > run/tools/opam <<'EOF'
  > #!/bin/sh
  > # A failing build may remove the target it was going to replace.
  > root=""
  > while [ "$#" -gt 0 ]; do
  >   if [ "$1" = "--root" ]; then root=$2; shift 2; continue; fi
  >   shift
  > done
  > rm -f "$root/_build/default/tui/app/bakhlo_tui.exe"
  > printf 'synthetic build failure\n' >&2
  > exit 1
  > EOF
  $ chmod +x run/tools/opam
  $ git -C run commit -q --allow-empty -m moved2
  $ git -C run push -q origin main
  $ runhh "$H0" 0 0
  Building bakhlo SHA …
  synthetic build failure
  The build of SHA failed; the last built binary is used.
  Running bakhlo from commit SHA
  TUI built from SHA
  $ grep -qF "TUI built from $(git -C run rev-parse --short HEAD~1)" out.log && echo previous-binary-kept
  previous-binary-kept
  $ test -x run/.run/bakhlo_tui.exe && echo installed-copy-survived
  installed-copy-survived

Without any binary the launcher refuses instead of running the shared tree.

  $ rm -rf run/.run
  $ git -C run remote set-url origin "$PWD/missing-remote.git"
  $ runhh "$H0" 0 0
  Offline: origin/main could not be fetched; the last built binary is used.
  No TUI binary is built for the launcher; run it once online so the pushed code is built.
  [2]
