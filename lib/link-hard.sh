#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash

source_deps () {
  :
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# Pass in a full path to the canon file ($1)
# and a partial path to local deps/ file to hard link.
# WHY: If you package shell or Git dependencies in source code of
# other projects and don't want to accidentally have different
# copies of the source diverge; and you only want search results
# from one copy of the file when grepping across projects.
link_hard () {
  # The reference file.
  local canon_file="$1"
  local local_file="${2:-${MR_REPO}/$(basename "${canon_file}")}"

  # Use `ls -i` to get the inode, e.g.,:
  #   $ ls -i ${canon_file}
  #   55182863 /path/to/file

  file_index_number_or_warn () {
    local file_path="$1"
    local file_inode

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

  if [ -e "${local_file}" ]; then
    local canon_inode
    local local_inode
    canon_inode=$(file_index_number_or_warn "${canon_file}") || return 1
    local_inode=$(file_index_number_or_warn "${local_file}") || return 1

    # Compare inode values.
    if [ "${canon_inode}" = "${local_inode}" ]; then
      # Same inode; already at the desired state.
      info " Hard link $(font_emphasize inode) same $(font_highlight "$(basename ${local_file})")"
      return 0
    elif ! diff -q "${canon_file}" "${local_file}" > /dev/null; then
      # Different inode, and different file contents. Cannot proceed.
      warn "Refuses to hard link disparate files:"
      warn "  meld '${canon_file}' '${local_file}' &"
      return 1
    fi
  fi

  mkdir -p "$(dirname "${local_file}")"

  # Different inode but nothing diff means we're cleared to clobber.
  ln -f "${canon_file}" "${local_file}"
  # info "File hard link created: $(basename ${local_file})"
  info " Placed new $(font_emphasize "hard link") $(font_highlight "$(basename ${local_file})")"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main () {
  source_deps
}

main "$@"

