#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

remote_add () {
  local remote_name="$1"
  local project_url="$2"
  local git_host_origin="$3"
  local git_host_user="$4"

  local git_url
  git_url="$( \
    _git_url_according_to_user "${project_url}" "${git_host_origin}" "${git_host_user}" \
  )"

  git remote remove "${remote_name}" 2> /dev/null || true
  git remote add "${remote_name}" "${git_url}"
}

