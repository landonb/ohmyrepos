#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# This git-clone shim lets users dynamically set the GitHub URL
# depending on, say, what host they're on.
#
# Use case: The author uses this mechanism to choose the transport
# protocol (HTTPS vs. SSH) depending on which host I'm on, because
# I share the same OMR config between hosts, but I do not have SSH
# setup on all my hosts (like @biz client machines, I don't bother
# setting up my personal GH keys).

# ***

# USAGE:
#
#   # Clones https://github.com/user/repo.git or git@github.com:user/repo.git
#   # depending on OHMYREPOS_GIT_URL_GITHUB environ (defaults HTTPS):
#   git_clone_github "user/repo.git"
#
#   # Similar, but also specifies the remote name, e.g., "upstream":
#   git_clone_github -o "upstream" "user/repo.git"
#
#   # Specify the SSH transport protocol.
#   OHMYREPOS_GIT_URL_GITHUB="git@github.com:" mr -d . install
#
# Probably for each host you'll simply `export OHMYREPOS_GIT_URL_GITHUB`
# from some Bashrc or equivalent so you don't have to think about it.

git_clone_github () {
  local github_url=""
  local target_dir=""
  local remote_name="origin"

  local git_server="${OHMYREPOS_GIT_URL_GITHUB:-https://github.com/}"

  while [ "$1" != '' ]; do
    case $1 in
      -o | --origin)
        [ ${#@} -lt 2 ] \
          && >&2 echo "ERROR: bad git_clone_github args" \
          && return 1 || true

        remote_name="$2"

        shift 2
        ;;

      *)
        [ -n "${github_url}" ] && [ -n "${target_dir}" ] \
          && >&2 echo "ERROR: more than one git_clone_github path" \
          && return 1 || true

        [ -z "${github_url}" ] \
          && github_url="$1" \
          || target_dir="$1"

        shift
        ;;
    esac
  done

  [ -z "${github_url}" ] \
    && >&2 echo "ERROR: missing git_clone_github path or URL" \
    && return 1 || true

  # Strip prefix (if included) and replace with one indicated by environ.
  local github_path="${github_url}"
  github_path="${github_path#http://github.com/}"
  github_path="${github_path#https://github.com/}"
  github_path="${github_path#git@github.com:}"

  # ***

  local git_url="${git_server}${github_path}"

  # ***

  echo git clone -o "${remote_name}" "${git_url}" "${target_dir}"

  git clone -o "${remote_name}" "${git_url}" "${target_dir}"
}

