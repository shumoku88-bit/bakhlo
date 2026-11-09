# Tab completion of the bk commands in bash (user decision 2026-11-09):
#
#   bk sh<Tab>        -> bk shop
#   bk to<Tab>        -> bk todo
#   bk todo <Tab><Tab>   add  done  drop
#
# Load it from ~/.bashrc:  source ~/Projects/moko/bakhlo/tools/bk-completion.bash
# The words come from the bakhlo that bk runs (the launcher's build of origin/main,
# `bakhlo --commands`), so they are the commands in cli/command_line.ml; until that
# build knows --commands, Tab offers nothing. Nothing else is completed.
_bk_bakhlo=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)/.run/bakhlo.exe

_bk() {
  local typed=("${COMP_WORDS[@]:1:COMP_CWORD-1}") next=() line words
  while IFS= read -r line; do
    read -r -a words <<<"$line"
    # A command whose first words are the ones typed offers its next word.
    # (todo, todo add, todo done: todo once). Plain arrays, for bash 3.2 as well.
    if [ "${#words[@]}" -gt "${#typed[@]}" ] && [ "${words[*]:0:${#typed[@]}}" = "${typed[*]}" ]; then
      case " ${next[*]} " in
        *" ${words[${#typed[@]}]} "*) ;;
        *) next+=("${words[${#typed[@]}]}") ;;
      esac
    fi
  done < <("$_bk_bakhlo" --commands 2>/dev/null)
  COMPREPLY=($(compgen -W "${next[*]}" -- "${COMP_WORDS[COMP_CWORD]}"))
}
complete -F _bk bk
