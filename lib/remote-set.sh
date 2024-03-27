# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

remote_set () {
  local rem_name="$1"
  local rem_path="$2"
  local dst_path="$3"

  if [ -n "${MR_REPO_REMOTES}" ]; then
    if [ -n "${dst_path}" ]; then
      # Stop on errexit.
      >&2 fatal "ERROR: Only the first remote_set may contain a destination directory"
    fi

    MR_REPO_REMOTES="${MR_REPO_REMOTES} "
  fi

  MR_REPO_REMOTES="${MR_REPO_REMOTES}${rem_name} \"${rem_path}\""

  if [ -n "${dst_path}" ]; then
    # Add trailing slash, so mr_repo_checkout knows the first remote
    # args include the destination directory.
    MR_REPO_REMOTES="${MR_REPO_REMOTES} \"${dst_path%%+(/)}/\""
  fi
}

# ***

mr_repo_remotes_complete () {
  echo "${MR_REPO_REMOTES}" | tr -d '\n'
}

