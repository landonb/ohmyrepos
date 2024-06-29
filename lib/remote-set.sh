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
      >&2 error "ERROR: Only the first remote_set may contain a destination directory"

      # Stop OMR on errexit (or return falsey to user's shell).
      return 1
    fi

    MR_REPO_REMOTES="${MR_REPO_REMOTES} "
  fi

  local git_url
  git_url="$(_github_url_according_to_user "${rem_path}")"

  MR_REPO_REMOTES="${MR_REPO_REMOTES}${rem_name} \"${git_url}\""

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

