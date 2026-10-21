The household launcher must warn and exit nonzero on any backup problem, while a
nonzero TUI exit is reported unchanged and wins over the backup status. Synthetic
local Git and bare remotes only: user/global Git config, signing and the network are
disabled; the fake TUI appends a record to the book (or not) and exits on demand.

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
  $ chmod +x run/tools/tui run/tools/household

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
  >   (cd run && BAKHLO_HOUSEHOLD="$1" FAKE_TUI_BOOK="$1/book.sexp" \
  >     FAKE_TUI_STATUS="$2" FAKE_TUI_EDIT="$3" sh ./tools/household)
  > }

A clean run with nothing to record or push is silent and successful.

  $ H0="$PWD/h0"; mkhousehold "$H0"; setremote "$H0" "$PWD/r0"
  $ runhh "$H0" 0 0

A recording is staged whole-household (book plus an untracked config file), committed,
pushed, and the remote configuration is left unchanged.

  $ H1="$PWD/h1"; mkhousehold "$H1"; setremote "$H1" "$PWD/r1"
  $ git -C "$H1" config --get remote.origin.url > before-url
  $ printf 'extra config\n' > "$H1/config.txt"
  $ runhh "$H1" 0 1
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
  Household commit failed; the change stays staged locally.
  [1]
  $ git -C "$H2" rev-list --count HEAD
  1
  $ git -C "$H2" status --porcelain
  M  book.sexp

No upstream is an explicit warning and a failed exit, never a silent skip.

  $ H3="$PWD/h3"; mkhousehold "$H3"
  $ runhh "$H3" 0 1
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
  Household backup pushed.

A nonzero TUI exit is preserved even when the backup also fails.

  $ H5="$PWD/h5"; mkhousehold "$H5"
  $ runhh "$H5" 7 1
  Household changes committed.
  No upstream branch configured; local commits cannot be pushed.
  [7]

A nonzero TUI exit also survives a successful, clean backup.

  $ runhh "$H0" 7 0
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
  Household changes committed.
  synthetic pending-log failure
  Failed to list pending commits; nothing was pushed.
  [1]
