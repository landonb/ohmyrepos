#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

source_deps () {
  # Load the logger library, from github.com/landonb/sh-logger
  # - Includes print commands: info, warn, error, debug
  if command -v "logger.sh" > /dev/null; then
    . "logger.sh"
  else
    . "$(dirname -- "${BASH_SOURCE[0]}")/../deps/sh-logger/bin/logger.sh"
  fi

  # Load: print_unresolved_path/realpath_s
  if command -v "print-unresolved-path.sh" > /dev/null; then
    . "print-unresolved-path.sh"
  else
    . "$(dirname -- "${BASH_SOURCE[0]}")/print-unresolved-path.sh"
  fi

  # Load: font_emphasize, font_highlight
  if command -v "overlay-symlink.sh" > /dev/null; then
    . "overlay-symlink.sh"
  else
    . "$(dirname -- "${BASH_SOURCE[0]}")/overlay-symlink.sh"
  fi
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# Pass in a the full path to the source file being hard linked ($1),
# and a partial path to the local deps/ file to create/maintain ($2).
# WHY: If you package shell or Git dependencies in source code of
# other projects and don't want to accidentally have different
# copies of the source diverge; and you only want search results
# from one copy of the file when grepping across projects.

# Note this doesn't know about update-faithful.sh
#   https://github.com/thegittinsgood/git-update-faithful#⛲
# Which otherwise supports a local file being at a known
# previous version of the file that it links.
# - The DepoXy environment uses a git post-rebase exec command
#   to ensure that hard links are never broken, so link_hard
#   conflicts should hopefully happen rarely. (Otherwise we
#   might consider adding update-faithful.sh-type awareness
#   to this feature.)

link_hard () {
  # The reference file.
  local canon_file="$1"
  local chase_file="${2:-${MR_REPO}/$(basename -- "${canon_file}")}"

  # Use `ls -i` to get the inode, e.g.,:
  #   $ ls -i ${canon_file}
  #   55182863 /path/to/file

  file_index_number_or_warn () {
    local file_path="$1"
    local file_inode=""

    if [ ! -f "${file_path}" ]; then
      >&2 warn "File not found: ${file_path}"

      return 1
    fi

    file_inode=$(command ls -i "${file_path}" | cut -d' ' -f1 2> /dev/null)
    if [ $? -ne 0 ] || [ -z "${file_inode}" ]; then
      >&2 error "No file index for: ${file_path}"

      return 1
    fi

    printf '%s' "${file_inode}"
  }

  local msg_action="Placed new"

  if [ -e "${chase_file}" ]; then
    local chase_inode
    local canon_inode
    chase_inode=$(file_index_number_or_warn "${chase_file}") || return 1
    canon_inode=$(file_index_number_or_warn "${canon_file}") || return 1

    msg_action=" Recreated"

    # Compare inode values.
    if [ "${chase_inode}" = "${canon_inode}" ]; then
      # Same inode; already at the desired state.
      info " Hard link $(font_emphasize inode) same" \
        "$(font_highlight "$(print_unresolved_path "${chase_file}")")"

      return 0
    elif ! diff -q "${chase_file}" "${canon_file}" > /dev/null; then
      # Different inode, and different file contents.
      # - If local file has no changes, then it's safe to assume its
      #   last commit was a normal "Update dependency" commit, and we
      #   can re-link it.
      msg_action="Rewrote as"
      # - Otherwise, if local file has changes, defer to user to resolve.

      local changed_file="${chase_file}"
      local status
      if ! status="$(git status --porcelain=v1 -- "${chase_file}" 2> /dev/null)"; then
        # The chase_file is outside the repo.
        warn "The two files are different, and the destination is outside the repo"
        warn "- Compare the files and make equal, or remove the target,"
        warn "  and try again:"
        warn "    cd \"$(pwd -L)\""
        warn "    meld \"${chase_file}\" \"${canon_file}\" &"
        warn "    command rm \"${chase_file}\""
        warn "    mr -d . -n ${MR_ACTION:-infuse}"

        return 1
      elif [ -n "${status}" ]; then
        # Cannot proceed.
        warn "The two files are different, and the local file has uncommitted changes"
        warn "- Compare the files and try again"
        warn "- Depending on your workflow, this might help:"
        warn "    cd \"$(pwd -L)'"
        warn "    meld \"${chase_file}\" \"${canon_file}\" &"
        warn "    git add \"${chase_file}\""
        warn "    git commit -m 'Deps: Update dependency ($(basename -- "${chase_file}"))'"
        # This assumes user uses link_hard from 'infuse' tasks.
        warn "    mr -d . -n ${MR_ACTION:-infuse}"

        return 1
      # else, chase_file belongs to the local repo and is unedited,
      # so we now it's safe to clobber.
      # - This works well if you use link_hard to manage local deps.
      #   E.g., say you have a shell command project that uses multiple
      #   scripts from other projects. Rather than require end users to
      #   download multiple projects, you could create hard-links in the
      #   application repo to track each of the upstream dependencies.
      #   Whenever an upstream file changes, you just commit the local
      #   copy. If the local hard link breaks and the file is unchanged,
      #   it's safe to recreate the hard link, even if the source file
      #   is different.
      # - But the opposite scenario is not handled, and the user must
      #   resolve it manually. In this case, the file from the local
      #   repo is what's being placed somewhere else, outside the repo.
      #   This is useful for installing '.gitignore' files (which Git
      #   doesn't allow to be symlinked). You'd keep some _gitignore
      #   files locally in your repo that you hard-link where you need
      #   as '.gitignore' files. In this case, we don't want to clobber
      #   the destination, because it's outside this repo.
      fi
    fi
  fi

  mkdir -p "$(dirname -- "${chase_file}")"

  # Different inode but either nothing different from canon,
  # or nothing changed locally, so we're cleared to clobber.
  command ln -f "${canon_file}" "${chase_file}"

  info " ${msg_action} $(font_emphasize "hard link")" \
    "$(font_highlight "$(print_unresolved_path "${chase_file}")")"
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

