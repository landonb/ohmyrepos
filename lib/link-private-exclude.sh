#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# *** <beg boilerplate `source_deps`: ------------------------------|
#                                                                   |

_link_private_exclude_sh__this_filename="link-private-exclude.sh"

_link_private_exclude_sh__source_deps() {
  local sourced_all=true

  # On Bash, user can source this file from anywhere.
  # - If not Bash, user must `cd` to this file's parent directory first.
  local prefix="$(dirname -- "${_link_private_exclude_sh__this_fullpath}")"

  # USAGE: Load dependencies using path relative to this file, e.g.:
  #   _source_file "${prefix}" "../deps/path/to/lib" "dependency.sh"

  #                                                                 |
  # *** stop boilerplate> ------------------------------------------|

  # Load: symlink_*.
  _link_private_exclude_sh__source_file "${prefix}" "" "overlay-symlink.sh"

  # *** <more boilerplate: -----------------------------------------|
  #                                                                 |

  ${sourced_all}
}

_link_private_exclude_sh__smells_like_bash() { declare -p BASH_SOURCE >/dev/null 2>&1; }

_link_private_exclude_sh__print_this_fullpath() {
  if _link_private_exclude_sh__smells_like_bash; then
    # Technically an arry:
    #   echo "$(realpath -- "${BASH_SOURCE[0]}")"
    # but this file is POSIX-compatible.
    echo "$(realpath -- "${BASH_SOURCE}")"
  elif [ "$(basename -- "$0")" = "${_link_private_exclude_sh__this_filename}" ]; then
    # Assumes this script being executed, and $0 is its path.
    echo "$(realpath -- "$0")"
  else
    # Assumes cwd is this script's parent directory.
    echo "$(realpath -- "${_link_private_exclude_sh__this_filename}")"
  fi
}

_link_private_exclude_sh__this_fullpath="$(_link_private_exclude_sh__print_this_fullpath)"

_link_private_exclude_sh__shell_sourced() {
  [ "$(realpath -- "$0")" != "${_link_private_exclude_sh__this_fullpath}" ]
}

_link_private_exclude_sh__source_file() {
  local prfx="${1:-.}"
  local depd="${2:-.}"
  local file="${3:-.}"

  local deps_dir="${prfx}/${depd}"
  local deps_path="${deps_dir}/${file}"

  # Just in case sourced file overwrites top-level `_link_private_exclude_sh__this_filename`,
  # cache our copy, should we need it for an error message.
  local _this_file_name="${_link_private_exclude_sh__this_filename}"

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
    if _link_private_exclude_sh__smells_like_bash; then
      >&2 echo "- GAFFE: This looks like an error with the ‘_link_private_exclude_sh__source_file’ arguments"
    else
      >&2 echo "- HINT: You must source ‘${_this_file_name}’ from its parent directory"
    fi
    sourced_all=false
  fi
}

# BONUS: You can use these aliases instead of the uniquely-named functions,
# just be aware not to call any alias after calling _source_deps.
_shell_sourced() { _link_private_exclude_sh__shell_sourced; }
_source_deps() { _link_private_exclude_sh__source_deps; }

_link_private_exclude_sh__source_deps_unset_cleanup() {
  unset -v _link_private_exclude_sh__this_filename
  unset -f _link_private_exclude_sh__print_this_fullpath
  unset -f _link_private_exclude_sh__shell_sourced
  unset -f _shell_sourced
  unset -f _link_private_exclude_sh__smells_like_bash
  unset -f _link_private_exclude_sh__source_deps
  unset -f _source_deps
  unset -f _link_private_exclude_sh__source_deps_unset_cleanup
  unset -f _link_private_exclude_sh__source_file
}

# USAGE: When this file is being executed, before doing stuff, call:
#   _source_deps
# - When this file is being sourced, call both:
#   _source_deps
#   _link_private_exclude_sh__source_deps_unset_cleanup

#                                                                   |
# *** end boilerplate `source_deps`> -------------------------------|

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# CONVENTION: Store .git/info/exclude files under a directory named
# .mrinfuse located in the same directory as the .mrconfig file whose
# repo config calls this function. Under the .mrinfuse directory, mimic
# the directory alongside the .mrconfig file. For instance, the exclude
# file for home-fries (linked from ~/.git/info/exclude) is stored at:
#   ~/.mrinfuse/_git/info/exclude
# As another example, suppose you had a config file at:
#   /my/work/projects/.mrconfig
# and you had a public repo underneath that project space at:
#   /my/work/projects/cool/product/
# you would store your private .gitignore file at:
#   /my/work/projects/.mrinfuse/cool/product/_git/info/exclude
# Also note that the .git/ directory is mirrored as _git, because git
#   will not let you add files from under a directory named .git/.

SOURCE_REL="${SOURCE_REL:-_git/info/exclude}"
TARGET_REL="${TARGET_REL:-.git/info/exclude}"

MRT_SILENT="${MRT_SILENT:-false}"

# ***

_info_path_exclude() {
  local testing=false
  # Uncomment to spew vars and exit:
  testing=true
  if $testing; then
    >&2 echo "MR_REPO=${MR_REPO}"
    >&2 echo "MR_CONFIG=${MR_CONFIG}"
    >&2 echo "current dir: $(pwd)"
    >&2 echo "MRT_LINK_FORCE=${MRT_LINK_FORCE}"
    >&2 echo "MRT_LINK_SAFE=${MRT_LINK_SAFE}"
    return 1
  fi
}

# ***

# `git init` create a descriptive .git/info/exclude file that we can
# replace without asking if boilerplate.
#
# E.g., here's the file that git makes:
#
#   $ cat .git/info/exclude
#   git ls-files --others --exclude-from=.git/info/exclude
#   Lines that start with '#' are comments.
#   For a project mostly in C, the following would be a good set of
#   exclude patterns (uncomment them if you want to use them):
#   *.[oa]
#   *~
#
# We can use the file checksum to check for change:
#
#   $ sha256sum .git/info/exclude | awk '{print $1}'
#   6671fe83b7a07c8932ee89164d1f2793b2318058eb8b98dc5c06ee0a5a3b0ec1

_OMR_XSUM_FRESH_EXCLUDE="6671fe83b7a07c8932ee89164d1f2793b2318058eb8b98dc5c06ee0a5a3b0ec1"

try_clobbering_exclude_otherwise_try_normal_overlay() {
  local sourcep="$1"

  mkdir -p .git/info
  cd .git/info
  # Because of the two directories nowunder:
  if is_relative_path "${sourcep}"; then
    sourcep="../../${sourcep}"
  fi

  local clobbered=false
  local exclude_f='exclude'
  if [ -f "${exclude_f}" ]; then
    local xsum=$(sha256sum "${exclude_f}" | awk '{print $1}')
    if [ "${xsum}" = "${_OMR_XSUM_FRESH_EXCLUDE}" ]; then
      # info "Removed default: .git/info/exclude"
      symlink_file_clobber "${sourcep}" 'exclude'
      clobbered=true
    fi
  fi

  if ! $clobbered; then
    symlink_overlay_file "${sourcep}" 'exclude'
  fi

  cd ../..
}

# ***

link_exclude_resolve_source_and_overlay() {
  local targetf="${1:-".gitignore.local"}"

  local sourcep
  sourcep=$(path_to_mrinfuse_resolve "${SOURCE_REL}")

  if [ ! -f "${sourcep}" ] && ${MRT_SILENT:-false}; then
    # Use case: `MRT_SILENT=true link_private_exclude` is simpler than:
    #   sourcep="$(path_to_mrinfuse_resolve "_git/info/exclude")" \
    #     && [ -f "${sourcep}" ] \
    #     && link_private_exclude
    # for *optional* symlink.

    return 1
  fi

  # Clobber .git/info/exclude if `git init` boilerplate, otherwise try
  # updating normally (replace/update if symlink, or check --force or
  # --safe if regular file to decide what to do).
  try_clobbering_exclude_otherwise_try_normal_overlay "${sourcep}"

  # Place the ./.gitignore.local symlink.
  symlink_overlay_file "${TARGET_REL}" "${targetf}"
}

# ***

link_private_exclude() {
  local was_link_force="${MRT_LINK_FORCE}"
  local was_link_safe="${MRT_LINK_SAFE}"
  myrepostravel_opts_parse "$@"

  local before_cd="$(pwd -L)"
  cd "${MR_REPO}"

  # _info_path_exclude

  # Short-circuits on errexit.
  link_exclude_resolve_source_and_overlay

  cd "${before_cd}"

  MRT_LINK_FORCE="${was_link_force}"
  MRT_LINK_SAFE="${was_link_safe}"
}

link_private_exclude_force() {
  link_private_exclude --force
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main() {
  # Only source deps when not included by OMR.
  # - This supports user sourcing this file directly,
  #   and it helps OMR avoid re-sourcing the same files.
  if [ -z "${MR_CONFIG}" ]; then
    _source_deps
  fi

  if ! _link_private_exclude_sh__shell_sourced; then
    if [ -z "${MR_REPO}" ]; then
      MR_REPO="."
    fi

    link_private_exclude
  fi
}

main "$@"

_link_private_exclude_sh__source_deps_unset_cleanup
unset -f main
