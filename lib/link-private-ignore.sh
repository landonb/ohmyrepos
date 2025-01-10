#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# *** <beg boilerplate `source_deps`: ------------------------------|
#                                                                   |

_link_private_ignore_sh__this_filename="link-private-ignore.sh"

_link_private_ignore_sh__source_deps () {
  local sourced_all=true

  # On Bash, user can source this file from anywhere.
  # - If not Bash, user must `cd` to this file's parent directory first.
  local prefix="$(dirname -- "${_link_private_ignore_sh__this_fullpath}")"

  # USAGE: Load dependencies using path relative to this file, e.g.:
  #   _source_file "${prefix}" "../deps/path/to/lib" "dependency.sh"

  #                                                                 |
  # *** stop boilerplate> ------------------------------------------|

  # Load: symlink_*.
  _link_private_ignore_sh__source_file "${prefix}" "" "overlay-symlink.sh"

  # *** <more boilerplate: -----------------------------------------|
  #                                                                 |

  ${sourced_all}
}

_link_private_ignore_sh__smells_like_bash () { declare -p BASH_SOURCE > /dev/null 2>&1; }

_link_private_ignore_sh__print_this_fullpath () {
  if _link_private_ignore_sh__smells_like_bash; then
    echo "$(realpath -- "${BASH_SOURCE[0]}")"
  elif [ "$(basename -- "$0")" = "${_link_private_ignore_sh__this_filename}" ]; then
    # Assumes this script being executed, and $0 is its path.
    echo "$(realpath -- "$0")"
  else
    # Assumes cwd is this script's parent directory.
    echo "$(realpath -- "${_link_private_ignore_sh__this_filename}")"
  fi
}

_link_private_ignore_sh__this_fullpath="$(_link_private_ignore_sh__print_this_fullpath)"

_link_private_ignore_sh__shell_sourced () {
  [ "$(realpath -- "$0")" != "${_link_private_ignore_sh__this_fullpath}" ]
}

_link_private_ignore_sh__source_file () {
  local prfx="${1:-.}"
  local depd="${2:-.}"
  local file="${3:-.}"

  local deps_dir="${prfx}/${depd}"
  local deps_path="${deps_dir}/${file}"

  # Just in case sourced file overwrites top-level `_link_private_ignore_sh__this_filename`,
  # cache our copy, should we need it for an error message.
  local _this_file_name="${_link_private_ignore_sh__this_filename}"

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
    if _link_private_ignore_sh__smells_like_bash; then
      >&2 echo "- GAFFE: This looks like an error with the ‘_link_private_ignore_sh__source_file’ arguments"
    else
      >&2 echo "- HINT: You must source ‘${_this_file_name}’ from its parent directory"
    fi
    sourced_all=false
  fi
}

# BONUS: You can use these aliases instead of the uniquely-named functions,
# just be aware not to call any alias after calling _source_deps.
_shell_sourced () { _link_private_ignore_sh__shell_sourced; }
_source_deps () { _link_private_ignore_sh__source_deps; }

_link_private_ignore_sh__source_deps_unset_cleanup () {
  unset -v _link_private_ignore_sh__this_filename
  unset -f _link_private_ignore_sh__print_this_fullpath
  unset -f _link_private_ignore_sh__shell_sourced
  unset -f _shell_sourced
  unset -f _link_private_ignore_sh__smells_like_bash
  unset -f _link_private_ignore_sh__source_deps
  unset -f _source_deps
  unset -f _link_private_ignore_sh__source_deps_unset_cleanup
  unset -f _link_private_ignore_sh__source_file
}

# USAGE: When this file is being executed, before doing stuff, call:
#   _source_deps
# - When this file is being sourced, call both:
#   _source_deps
#   _link_private_ignore_sh__source_deps_unset_cleanup

#                                                                   |
# *** end boilerplate `source_deps`> -------------------------------|

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

link_private_ignore () {
  local retcode=0

  local lnkpath='.ignore'

  # Assume first param an alternative filename unless an -o/--option.
  if [ -n "$1" ] && [ "${1#-}" = "$1" ]; then
    lnkpath="$1"  # E.g., '_ignore'

    shift
  fi

  local targetp="$(dirname -- "${lnkpath}")/.ignore"

  local was_link_force="${MRT_LINK_FORCE}"
  local was_link_safe="${MRT_LINK_SAFE}"

  myrepostravel_opts_parse "$@"

  local before_cd="$(pwd -L)"

  cd "${MR_REPO}"

  set -- "${lnkpath}" "${targetp}" "$@"
  symlink_mrinfuse_file "$@" \
    || retcode=$?

  cd "${before_cd}"

  MRT_LINK_FORCE="${was_link_force}"
  MRT_LINK_SAFE="${was_link_safe}"

  return ${retcode}
}

# An alias, of sorts.
link_private_ignore_force () {
  link_private_ignore "$@" --force
}

# Another alias.
link_private_ignore_ () {
  link_private_ignore "_ignore" "$@"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# Only source deps when not included by OMR.
# - This supports user sourcing this file directly,
#   and it helps OMR avoid re-sourcing the same files.
if [ -z "${MR_CONFIG}" ]; then
  _source_deps
fi

_link_private_ignore_sh__source_deps_unset_cleanup

