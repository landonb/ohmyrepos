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
  exit_if_arg_missing () {
    if [ -z "$1" ]; then
      >&2 echo "ERROR: Please set MR_REPO_REMOTES for project: ${MR_REPO}"
      #
      exit 1
    fi
  }
  #
  eval "set -- ${MR_REPO_REMOTES}"
  #
  exit_if_arg_missing "$1"
  #
  local processed_first=false
  #
  while [ -n "$1" ]; do
    local remote_name="$1"
    local remote_url_or_path="$2"
    #
    exit_if_arg_missing "${remote_url_or_path}"
    shift 2
    #
    # Ignore the dest. dir (only used on 'checkout').
    if ! ${processed_first} && [ "${1%/}" != "${1}" ]; then
      shift
    fi
    #
    remote_add "${remote_name}" "${remote_url_or_path}"
    #
    processed_first=true
  done
}

