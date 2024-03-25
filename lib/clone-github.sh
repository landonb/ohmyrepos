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
#   # depending on OHMYREPOS_GIT_HOST_ORIGIN environ (defaults HTTPS):
#   git_clone_giturl "user/repo.git"
#
#   # Similar, but also specifies the remote name, e.g., "upstream":
#   git_clone_giturl -o "upstream" "user/repo.git"
#
#   # Specify the SSH transport protocol.
#   OHMYREPOS_GIT_HOST_ORIGIN="git@github.com:" mr -d . install
#
# Probably for each host you'll simply `export OHMYREPOS_GIT_HOST_ORIGIN`
# from some Bashrc or equivalent so you don't have to think about it.

git_clone_giturl () {
  local remote_url_or_path=""
  local target_dir=""
  local remote_name="origin"
  local config_name_vals=""

  while [ "$1" != '' ]; do
    case $1 in
      -o | --origin)
        [ ${#@} -lt 2 ] \
          && >&2 echo "ERROR: git_clone_giturl -o/--origin missing <name>" \
          && return 1 || true

        remote_name="$2"

        shift 2
        ;;

      -c | --config)
        [ ${#@} -lt 2 ] \
          && >&2 echo "ERROR: git_clone_giturl -c/--config missing <name>=<value>" \
          && return 1 || true

        config_name_vals="${config_name_vals}$1 $2 "

        shift 2
        ;;

      *)
        [ -n "${remote_url_or_path}" ] && [ -n "${target_dir}" ] \
          && >&2 echo "ERROR: more than one git_clone_giturl path or URL" \
          && return 1 || true

        [ -z "${remote_url_or_path}" ] \
          && remote_url_or_path="$1" \
          || target_dir="$1"

        shift
        ;;
    esac
  done

  [ -z "${remote_url_or_path}" ] \
    && >&2 echo "ERROR: missing git_clone_giturl path or URL" \
    && return 1 || true

  local git_url
  git_url="$(_git_url_according_to_user "${remote_url_or_path}")"

  echo "git clone -o \"${remote_name}\" \"${git_url}\" ${config_name_vals}\"${target_dir}\""

  # Because ${target_dir} might be empty, either need to not quote it:
  #   git clone -o "${remote_name}" "${git_url}" ${target_dir}
  # Or we can if-around [and find out].
  if [ -n "${target_dir}" ]; then
    git clone -o "${remote_name}" ${config_name_vals}"${git_url}" "${target_dir}"
  else
    git clone -o "${remote_name}" ${config_name_vals}"${git_url}"
  fi
}

# ***

# DEFIN: Protocol (or Scheme) plus Host (plus Port) is called the *Origin*
#   https://www.rfc-editor.org/rfc/rfc6454#section-5
_git_url_according_to_user () {
  local remote_url_or_path="$1"
  local git_host_origin="${2:-${OHMYREPOS_GIT_HOST_ORIGIN:-https://github.com/}}"
  local git_host_user="$3"

  # Strip prefix (if included) from project URL.
  local url_subdir
  url_subdir="$( \
    echo "${remote_url_or_path}" \
    | sed 's#\(https\?://\|git@\)\([^:/]\+\)[:/]\(.*\)#\3#' \
  )"

  # Replace Git host user/org name if specified.
  if [ -n "${git_host_user}" ]; then
    url_subdir="${git_host_user}/$(basename -- "${url_subdir}")"
  fi

  # If the host path is absolute, assume local remote.
  if [ "${remote_url_or_path#/}" != "${remote_url_or_path}" ]; then
    git_host_origin=""
  fi

  # Reassemable URL using scheme/protocol (HTTPS/SSH) and domain (github.com)
  # from arg or environ.
  local git_url="${git_host_origin}${url_subdir}"

  printf "%s" "${git_url}"
}

