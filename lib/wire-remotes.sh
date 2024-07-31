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
  _wire_remotes_exit_if_not_a_repo

  eval "set -- $(mr_repo_remotes_complete)"

  _wire_remotes_exit_if_no_remotes_configured "$1"

  local num_remotes=0
  local num_skipped=0

  local processed_first=false

  while [ -n "$1" ]; do
    local remote_name="$1"
    local remote_url_or_path="$2"

    _wire_remotes_exit_if_missing_url "${remote_name}" "${remote_url_or_path}"
    shift 2

    # Ignore the dest. dir (only used on 'checkout').
    if ! ${processed_first} && [ "${1%/}" != "${1}" ]; then
      shift
    fi
    processed_first=true

    local cmd_action
    cmd_action="$(remote_add "${remote_name}" "${remote_url_or_path}")"

    if [ "${cmd_action}" = "none" ]; then
      num_skipped=$((${num_skipped} + 1))
    else
      num_remotes=$((${num_remotes} + 1))
    fi
  done

  info "WIRED: ${num_remotes} remotes added/edited, ${num_skipped} already set:" \
    "$(fg_green)${MR_REPO}$(attr_reset)"
}

# ***

_wire_remotes_exit_if_not_a_repo () {
  if git_is_git_repo_root; then

    return 0
  fi

  info "SKIPD: The project has no .git/ direct'y: $(fg_orange)${MR_REPO}$(attr_reset)"

  exit 0
}

# ***

_wire_remotes_exit_if_no_remotes_configured () {
  if [ -n "$1" ]; then

    return 0
  fi

  # Nothing set via MR_REPO_REMOTES, remote_set, etc.
  info "SKIPD: No remotes configured for project: $(fg_lightorange)${MR_REPO}$(attr_reset)"

  exit 0
}

# ***

_wire_remotes_exit_if_missing_url () {
  local remote_name="$1"
  local url_or_path="$2"

  if [ -n "${url_or_path}" ]; then

    return 0
  fi

  # Misconfigured MR_REPO_REMOTES.
  info "FAILD: No URL for project remote “${remote_name}”: $(fg_lightorange)${MR_REPO}$(attr_reset)"

  exit 1
}

# ***

report_remotes () {
  _wire_remotes_exit_if_not_a_repo

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

    _wire_remotes_exit_if_missing_url "${remote_name}" "${remote_url_or_path}"
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

  command rm -- "${tmp_file}"
}

# ***

# COPYD: ~/.kit/sh/sh-git-nubs/lib/git-nubs.sh
git_is_git_repo_root () {
  local proj_path="${1:-$(pwd)}"

  local repo_root
  if ! repo_root="$(git rev-parse --show-toplevel 2> /dev/null)"; then

    return 1
  fi

  if [ "$(realpath -- "${proj_path}")" != "$(realpath -- "${repo_root}")" ]; then

    return 1
  fi

  return 0
}

