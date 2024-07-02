# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# USAGE: Useful for sorting and saving changes to your ~/.vim/spell/en.utf-8.add
#   There are probably additional uses, too.
# E.g.,
#
#   [${HOME}/.dotfiles]
#   autocommit =
#     # Sort the spell file, for easy diff'ing, or merging/meld'ing.
#     # - The .vimrc startup file will remake the .spl file when you restart Vim.
#     sort_file_then_commit '.mrinfuse/.vim/spell/en.utf-8.add'

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

source_deps () {
  # Load the logger library, from github.com/landonb/sh-logger.
  # - Includes print commands: info, warn, error, debug.
  if ! . logger.sh 2> /dev/null; then
    . "$(dirname -- "${BASH_SOURCE[0]}")/../deps/sh-logger/bin/logger.sh"
  fi
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

sort_file_then_commit () {
  local targetf="$1"
  shift

  # If `mr` run from a subdir, top-level .mrconfig found, but still run from subdir.
  local before_cd="$(pwd -L)"
  cd "${MR_REPO}"

  if [ -f "${targetf}" ]; then
    # NOTE: cat'ing and sort'ing to the cat'ed file results in a 0-size file.
    #   So we use an intermediate file.
    local sortedf
    sortedf="$(mktemp --suffix='.ohmyrepos')"

    # --dictionary-order: Emoji, A-Z, then a-z.
    cat "${targetf}" | LC_ALL='C' sort -d > "${sortedf}"
    command mv -f -- "${sortedf}" "${targetf}"

    git_auto_commit_one "${targetf}" "$@"
  else
    >&2 warn
    >&2 warn 'WARNING: No file to sort and commit found at:'
    >&2 warn "  ${targetf}"
    >&2 warn

    return 1
  fi

  cd "${before_cd}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main () {
  source_deps
}

# Only source deps when not included by OMR.
# - This supports user sourcing this file directly,
#   and it helps OMR avoid re-sourcing the same files.
if [ -z "${MR_CONFIG}" ]; then
  main "$@"
fi

unset -f main
unset -f source_deps

