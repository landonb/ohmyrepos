#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# This git-clone shim lets users dynamically set the GitHub URL
# depending on, say, what host they're on.
#
# Use case: The author uses this mechanism to choose the transport
# protocol (HTTPS vs. SSH) depending on which host I'm on, because
# I share the same OMR config between hosts, but I do not have SSH
# setup on all my hosts (like @biz client machines, I don't bother
# setting up my personal GH keys).

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# OVIEW: This file defines a function, `git_clone_giturl` that the
#        user is unlikely to call directly if they use `remote_set`.
#
#        This file uses an environ, `MR_GIT_HOST_ORIGIN`, that the
#        user will likely want to export from their shell.

# USAGE: You will likely want to export the environ from your shell.
#
# - E.g., call this during ~/.bashrc or equivalent, then don't worry
#   about it again:
#
#     export MR_GIT_HOST_ORIGIN="git@github.com:"
#
# Keep reading for more details.

# USAGE: Set `MR_GIT_HOST_ORIGIN` to specify if remote URLs use SSH or HTTPS.
#
# - When the environ is unset or set to "https://github.com/", calling, e.g.,
#
#     MR_GIT_HOST_ORIGIN= mr -d . checkout
#
#   will clone:
#
#     https://github.com/user/repo.git
#
#   This assumes the 'checkout' action calls this function:
#
#     [/path/to/project]
#     checkout = git_clone_giturl -o "upstream" "user/repo.git"
#
#   or the user uses `remote_set` instead and leaves 'checkout' unset:
#
#     [/path/to/project]
#     lib = remote_set "upstream" "user/repo.git"
#
# - You can use SSH transport by setting the environ to "git@github.com:", e.g.,
#
#     MR_GIT_HOST_ORIGIN="git@github.com:" mr -d . checkout
#
#   will clone:
#
#     git@github.com:user/repo.git
#
# - Note the environ lets you specify a local remote instead, e.g.,
#
#     MR_GIT_HOST_ORIGIN=/media/user/some-mount mr -d /path/to/user/repo -n checkout
#
#   will clone:
#
#     /media/user/some-mount/path/to/user/repo

# USAGE: The `git_clone_giturl` function accepts two options from git-clone:
#
#   -c/--config and -o/--origin
# 
# - This example shows how to specify the remote name:
#
#     git_clone_giturl -o "upstream" "user/repo.git"

# USAGE: The `git_clone_giturl` function accepts an optional destination
# directory as the final non-option argument, e.g.,:
#
#     git_clone_giturl -o "upstream" "user/repo.git" "dest-dir/"

# USAGE: As mentioned above, not all users will call this function.
#
# - If they want to, the user can wire this from a 'checkout' action, e.g.,
#
#     [/path/to/project]
#     checkout = git_clone_giturl -o "upstream" "user/repo.git"
#
# - But the `remote_set` approach offers a better solution, e.g.,
#
#     [/path/to/project]
#     lib = remote_set "upstream" "user/repo.git"
#
# - `remote_set` lets you define multiple remotes, and those remotes
#   can be used by other actions, e.g., `mr -d / wireRemotes'.
#
# - If the 'checkout' action is absent, the default action calls
#   `mr_repo_checkout` (from checkout.sh) which passes the first
#   remote from `remote_set` to this function, `git_clone_giturl`.
#   This function uses MR_GIT_HOST_ORIGIN to format the URL, and
#   to clone the remote repository.
#
# So generally the user will set MR_GIT_HOST_ORIGIN and use
# `remote_set`, but they won't call this function directly.

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
  git_url="$(_github_url_according_to_user "${remote_url_or_path}")"

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

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# DEFIN: Protocol (or Scheme) plus Host (plus Port) is called the *Origin*
#   https://www.rfc-editor.org/rfc/rfc6454#section-5
_github_url_according_to_user () {
  local remote_url_or_path="$1"
  local git_host_origin="$2"
  local git_host_user="$3"

  if [ -z "${2+x}" ]; then
    git_host_origin="${MR_GIT_HOST_ORIGIN:-https://github.com/}"
  fi

  if [ -z "${3+x}" ]; then
    git_host_user="${MR_GIT_HOST_USER}"
  fi

  # ***

  # If URL begins with https://github.com/, substitute ${git_host_origin}.
  # - Any other URL, and any git@ URL, will be left alone.
  # - This also precludes altering /-prefixed local file paths.
  local url_subdir="${remote_url_or_path}"
  if true \
    && [ "${remote_url_or_path#/}" = "${remote_url_or_path}" ] \
    && echo "${remote_url_or_path}" | grep -q -e "^https\?://github.com/" \
  ; then
    # This strips any https:// or git@ prefix, but we know it's
    # either https://github.com or http://github.com.
    # - macOS sed doesn't like that which works with GNU sed:
    #   | sed 's#\(https\?://\|git@\)\([^:/]\+\)[:/]\(.*\)#\3#' \
    url_subdir="$( \
      echo "${remote_url_or_path}" \
      | sed -E 's#(https?://|git@)([^:/]+)[:/](.*)#\3#' \
    )"

    # Replace Git host user/org name if specified.
    if [ -n "${git_host_user}" ]; then
      url_subdir="${git_host_user}/$(echo "${url_subdir}" | cut -d'/' -f2-)"
    fi
  else
    git_host_origin=""
  fi

  # Reassemable URL using scheme/protocol (HTTPS/SSH) and domain (github.com)
  # from arg or environ.
  local git_url="${git_host_origin}${url_subdir}"

  printf "%s" "${git_url}"
}

