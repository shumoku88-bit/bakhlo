# What Tab offers after each typing, as bash completes bk (tools/bk-completion.bash),
# asking the bakhlo just built for its commands.
. "$1"
_bk_bakhlo=$2
offer() {
  COMP_WORDS=(bk "$@")
  COMP_CWORD=$#
  _bk
  echo "bk $*<Tab> -> [${COMPREPLY[*]}]"
}
offer sh
offer to
offer todo ""
offer pace ""
offer p
offer report ""
offer shop ""
offer ""
