#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

remote_add () {
  local remote_name="$1"
  local remote_url_or_path="$2"
  # Generally, you won't specify the following 2 args from a project.
  # - Prefer specifying the origin via an environ, MR_GIT_HOST_ORIGIN.
  local git_host_origin="$3"
  # - The remote user part of the URL can be overriden with this arg,
  #   or the MR_GIT_HOST_USER arg. It's not generally very useful,
  #   because you'll always want to just use the user from the original
  #   URL. But if you maintain the same repo under different users
  #   (e.g., you keep a private copy of some repos under a different
  #   GH user), you can use this injector to make it easier.
  local git_host_user="$4"

  # BWARE: Leave the last 2 args unquoted, because unset has meaning
  # in the called function.
  local git_url
  git_url="$( \
    _github_url_according_to_user "${remote_url_or_path}" ${git_host_origin} ${git_host_user} \
  )"

  git remote remove "${remote_name}" 2> /dev/null || true
  git remote add "${remote_name}" "${git_url}"
}

