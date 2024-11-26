#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

remote_add () {
  local remote_name="$1"
  local remote_url_or_path="$2"

  local action=""

  # BWARE: Leave the last 2 args unquoted, because unset has meaning
  # in the called function.
  local git_url
  git_url="$(_github_url_according_to_user "${remote_url_or_path}")"

  # Avoid remove if remote exists. Otherwise breaks the remote HEAD
  # and tracking branch. And then user may have to git-fetch and
  # maybe `git branch -u` to restore things.

  local current_url
  if current_url="$(git remote get-url ${remote_name} 2> /dev/null)"; then
    if [ "${current_url}" != "${git_url}" ]; then
      action="reset"

      git remote set-url "${remote_name}" "${git_url}"
    else
      action="none"
    fi
  else
    action="added"

    git remote add "${remote_name}" "${git_url}"
  fi

  echo "${action}"
}

