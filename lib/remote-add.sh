#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

remote_add () {
  local remote_name="$1"
  local remote_url_or_path="$2"
  # Generally, you won't specify the following 2 args from a project.
  # - Prefer specifying the origin via an environ, OHMYREPOS_GIT_HOST_ORIGIN.
  local git_host_origin="$3"
  # - Prefer not setting this arg at all, ever. (DUNNO: Why did I add this?
  #   If it's really not used, nor useful, we should remove it.)
  local git_host_user="$4"

  local git_url
  git_url="$( \
    _git_url_according_to_user "${remote_url_or_path}" "${git_host_origin}" "${git_host_user}" \
  )"

  git remote remove "${remote_name}" 2> /dev/null || true
  git remote add "${remote_name}" "${git_url}"
}

