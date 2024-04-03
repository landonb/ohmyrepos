# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# Use a project environ to specify both the clone URL, and additional remotes.
# - E.g.,:
#
#     [/path/to/one/repo]
#     lib = MR_REPO_REMOTES="
#       origin https://github.com/git/git.git dest-dir/
#       fork https://github.com/user1/git.git
#       spoon https://github.com/user2/git.git
#       "
#
# - As a convenience, use `remote_set` for improved readability, e.g.,
#
#     [/path/to/one/repo]
#     lib =
#       remote_set origin https://github.com/git/git.git dest-dir
#       remote_set fork https://github.com/user1/git.git
#       remote_set spoon https://github.com/user2/git.git
#
# Note that the clone destination directory ('dest-dir' in the previous
# examples) must end in a slash in the MR_REPO_REMOTES string (e.g.,
# 'dest-dir/'. But when using `remote_set`, it may be omitted (e.g.,
# 'dest-dir').

wire_remotes () {
  eval "set -- $(mr_repo_remotes_complete)"

  _wire_remotes_exit_if_arg_missing "$1"

  local processed_first=false
  
  while [ -n "$1" ]; do
    local remote_name="$1"
    local remote_url_or_path="$2"

    _wire_remotes_exit_if_arg_missing "${remote_url_or_path}"
    shift 2

    # Ignore the dest. dir (only used on 'checkout').
    if ! ${processed_first} && [ "${1%/}" != "${1}" ]; then
      shift
    fi
    processed_first=true

    remote_add "${remote_name}" "${remote_url_or_path}"
  done
}

_wire_remotes_exit_if_arg_missing () {
  if [ -z "$1" ]; then
    >&2 echo "ERROR: Please set or fix MR_REPO_REMOTES for project: ${MR_REPO}"
    #
    exit 1
  fi
}

# ***

report_remotes () {
  local alert_msg=""

  alert_msg_add_comma () {
    if [ -n "${alert_msg}" ]; then
      alert_msg="${alert_msg}, "
    fi
  }

  # ***

  local known_remotes=""

  local processed_first=false

  eval "set -- $(mr_repo_remotes_complete)"

  while [ -n "$1" ]; do
    local remote_name="$1"
    local remote_url_or_path="$2"
    local local_dest_dir=""

    _wire_remotes_exit_if_arg_missing "${remote_url_or_path}"
    shift 2

    if ! ${processed_first} && [ "${1%/}" != "${1}" ]; then
      local_dest_dir="$1"

      shift
    fi
    processed_first=true

    known_remotes="${known_remotes}${remote_name}\n"

    local git_url
    if git_url="$(git remote get-url ${remote_name} 2>/dev/null)"; then
      # Note we ignore trailing '.git', not a big deal if disparate.
      if [ "${remote_url_or_path%.git}" != "${git_url%.git}" ]; then
        debug "ALERT: '${remote_name}' URL expected to be: ${remote_url_or_path}" \
          "(not ${git_url})"

        alert_msg_add_comma
        alert_msg="${alert_msg}${remote_name} (?)"
      fi
    else
      debug "ALERT: No remote configured for: ${remote_name}"

      alert_msg_add_comma
      alert_msg="${alert_msg}${remote_name} (✗)"
    fi

    # info "  ${remote_name} ${remote_url_or_path} ${local_dest_dir}"
  done

  # ***

  if [ -n "${alert_msg}" ]; then
    warn "ALERT: Working dir remote(s) missing or URLs dissimilar: $(echo "${alert_msg}" | sed 's/ \+$//')"
  fi

  # ***

  local tmp_file="$(mktemp --tmpdir "omr-report-remotes-XXXXXXX")"

  trap "command rm -- \"${tmp_file}\"" EXIT

  echo "${known_remotes}$(echo "${MR_KNOWN_REMOTES}" | tr ' ' '\n')" \
    | sed '/^$/d' | LC_COLLATE=C sort >${tmp_file}

  local diff_remotes

  diff_remotes="$( \
    git remote | LC_COLLATE=C sort | LC_COLLATE=C comm -1 -3 "${tmp_file}" -
  )"

  if [ -n "${diff_remotes}" ]; then
    warn "ALERT: Working dir remote(s) not registered in mrconfig:" \
      "$(echo "${diff_remotes}" | sed -z 's/\n/, /g' | sed 's/, $//')"
  fi
}

