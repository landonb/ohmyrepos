#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

remote_add () {
  local remote_name="$1"
  local project_url="$2"
  local remote_user_url="$3"
  local remote_user_name="$4"

  local remote_url
  remote_url="$( \
    _git_url_according_to_user "${project_url}" "${remote_user_url}" "${remote_user_name}" \
  )"

  git remote remove "${remote_name}" 2> /dev/null || true
  git remote add "${remote_name}" "${remote_url}"
}

