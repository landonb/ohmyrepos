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

# *** <beg boilerplate `source_deps`: ------------------------------|
#                                                                   |

_sorted_commit_sh__this_filename="sorted-commit.sh"

_sorted_commit_sh__source_deps () {
  local sourced_all=true

  # On Bash, user can source this file from anywhere.
  # - If not Bash, user must `cd` to this file's parent directory first.
  local prefix="$(dirname -- "${_sorted_commit_sh__this_fullpath}")"

  # USAGE: Load dependencies using path relative to this file, e.g.:
  #   _source_file "${prefix}" "../deps/path/to/lib" "dependency.sh"

  #                                                                 |
  # *** stop boilerplate> ------------------------------------------|

  # Load the logger library, from github.com/landonb/sh-logger.
  # - Includes print commands: info, warn, error, debug.
  _sorted_commit_sh__source_file "${prefix}" "../deps/sh-logger/bin" "logger.sh"

  # *** <more boilerplate: -----------------------------------------|
  #                                                                 |

  ${sourced_all}
}

_sorted_commit_sh__smells_like_bash () { declare -p BASH_SOURCE > /dev/null 2>&1; }

_sorted_commit_sh__print_this_fullpath () {
  if _sorted_commit_sh__smells_like_bash; then
    echo "$(realpath -- "${BASH_SOURCE[0]}")"
  elif [ "$(basename -- "$0")" = "${_sorted_commit_sh__this_filename}" ]; then
    # Assumes this script being executed, and $0 is its path.
    echo "$(realpath -- "$0")"
  else
    # Assumes cwd is this script's parent directory.
    echo "$(realpath -- "${_sorted_commit_sh__this_filename}")"
  fi
}

_sorted_commit_sh__this_fullpath="$(_sorted_commit_sh__print_this_fullpath)"

_sorted_commit_sh__shell_sourced () {
  [ "$(realpath -- "$0")" != "${_sorted_commit_sh__this_fullpath}" ]
}

_sorted_commit_sh__source_file () {
  local prfx="${1:-.}"
  local depd="${2:-.}"
  local file="${3:-.}"

  local deps_dir="${prfx}/${depd}"
  local deps_path="${deps_dir}/${file}"

  # Just in case sourced file overwrites top-level `_sorted_commit_sh__this_filename`,
  # cache our copy, should we need it for an error message.
  local _this_file_name="${_sorted_commit_sh__this_filename}"

  if [ -f "${deps_path}" ]; then
    # SAVVY: Source files from their dirs, so they can find their deps.
    local before_cd="$(pwd -L)"
    cd "${deps_dir}"
    # SAVVY: If errexit, error while sourcing kills process immediately,
    # and error you see might indicate this source file, but the line
    # number for the file being sourced. E.g.,
    #   /path/to/bin/myapp: 442: export: Illegal option -f
    # where `442` is line number from, e.g., 'deps/lib/dep.sh'.
    if ! . "${deps_path}"; then
      >&2 echo "ERROR: Dependency ‘${file}’ returned nonzero when sourced"
      sourced_all=false
    fi
    cd "${before_cd}"
  else
    local depstxt=""
    [ "${prfx}" = "." ] || depstxt="in ‘${deps_dir}’ or "
    >&2 echo "ERROR: ‘${file}’ not found under ‘${deps_dir}’"
    if _sorted_commit_sh__smells_like_bash; then
      >&2 echo "- GAFFE: This looks like an error with the ‘_sorted_commit_sh__source_file’ arguments"
    else
      >&2 echo "- HINT: You must source ‘${_this_file_name}’ from its parent directory"
    fi
    sourced_all=false
  fi
}

# BONUS: You can use these aliases instead of the uniquely-named functions,
# just be aware not to call any alias after calling _source_deps.
_shell_sourced () { _sorted_commit_sh__shell_sourced; }
_source_deps () { _sorted_commit_sh__source_deps; }

_sorted_commit_sh__source_deps_unset_cleanup () {
  unset -v _sorted_commit_sh__this_filename
  unset -f _sorted_commit_sh__print_this_fullpath
  unset -f _sorted_commit_sh__shell_sourced
  unset -f _shell_sourced
  unset -f _sorted_commit_sh__smells_like_bash
  unset -f _sorted_commit_sh__source_deps
  unset -f _source_deps
  unset -f _sorted_commit_sh__source_deps_unset_cleanup
  unset -f _sorted_commit_sh__source_file
}

# USAGE: When this file is being executed, before doing stuff, call:
#   _source_deps
# - When this file is being sourced, call both:
#   _source_deps
#   _sorted_commit_sh__source_deps_unset_cleanup

#                                                                   |
# *** end boilerplate `source_deps`> -------------------------------|

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
  _source_deps
}

# Only source deps when not included by OMR.
# - This supports user sourcing this file directly,
#   and it helps OMR avoid re-sourcing the same files.
if [ -z "${MR_CONFIG}" ]; then
  main "$@"
fi

_sorted_commit_sh__source_deps_unset_cleanup
unset -f main

