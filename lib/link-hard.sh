#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

source_deps () {
  # Load the logger library, from github.com/landonb/sh-logger.
  # - Includes print commands: info, warn, error, debug.
  . logger.sh
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# Pass in a the full path to the source file being hard linked ($1),
# and a partial path to the local deps/ file to create/maintain ($2).
# WHY: If you package shell or Git dependencies in source code of
# other projects and don't want to accidentally have different
# copies of the source diverge; and you only want search results
# from one copy of the file when grepping across projects.
link_hard () {
  # The reference file.
  local canon_file="$1"
  local local_file="${2:-${MR_REPO}/$(basename -- "${canon_file}")}"

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

    file_inode=$(ls -i "${file_path}" | cut -d' ' -f1 2> /dev/null)
    if [ $? -ne 0 ] || [ -z "${file_inode}" ]; then
      >&2 error "No file index for: ${file_path}"

      return 1
    fi

    printf '%s' "${file_inode}"
  }

  local msg_action="Placed new"

  if [ -e "${local_file}" ]; then
    local local_inode
    local canon_inode
    local_inode=$(file_index_number_or_warn "${local_file}") || return 1
    canon_inode=$(file_index_number_or_warn "${canon_file}") || return 1

    msg_action=" Recreated"

    # Compare inode values.
    if [ "${local_inode}" = "${canon_inode}" ]; then
      # Same inode; already at the desired state.
      info " Hard link $(font_emphasize inode) same" \
        "$(font_highlight "$(realpath -s -- "${local_file}")")"

      return 0
    elif ! diff -q "${local_file}" "${canon_file}" > /dev/null; then
      # Different inode, and different file contents.
      # - If local file has no changes, then it's safe to assume its
      #   last commit was a normal "Update dependency" commit, and we
      #   can re-link it.
      msg_action="Replace w/"
      # - Otherwise, if local file has changes, defer to user to resolve.
      if [ -n "$(git status --porcelain=v1 -- "${local_file}")" ]; then
        # Cannot proceed.
        warn "Refuses to hard link disparate files."
        warn "- Depending on your workflow, this might help:"
        warn "    cd '$(pwd -L)'"
        warn "    meld '${local_file}' '${canon_file}' &"
        warn "    git add '${local_file}'"
        warn "    git commit -m 'Deps: Update dependency ($(basename -- "${local_file}"))'"
        # This assumes user uses link_hard from 'infuse' tasks.
        warn "    mr -d . -n infuse"

        return 1
      fi
    fi
  fi

  mkdir -p "$(dirname -- "${local_file}")"

  # Different inode but either nothing different from canon,
  # or nothing changed locally, so we're cleared to clobber.
  ln -f "${canon_file}" "${local_file}"

  info " ${msg_action} $(font_emphasize "hard link")" \
    "$(font_highlight "$(realpath -s -- "${local_file}")")"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main () {
  source_deps
}

main "$@"
unset -f main
unset -f source_deps

