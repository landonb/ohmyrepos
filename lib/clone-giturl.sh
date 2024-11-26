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
#        This file uses an environ, `MR_GITHUB_HOST_ORIGIN`, that the
#        user will likely want to export from their shell.

# USAGE: You will likely want to export the environ from your shell.
#
# - E.g., call this during ~/.bashrc or equivalent, then don't worry
#   about it again:
#
#     export MR_GITHUB_HOST_ORIGIN="git@github.com:"
#
# Keep reading for more details.

# USAGE: Set `MR_GITHUB_HOST_ORIGIN` to specify if remote URLs use SSH or HTTPS.
#
# - When the environ is unset or set to "https://github.com/", calling, e.g.,
#
#     MR_GITHUB_HOST_ORIGIN= mr -d . checkout
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
#     MR_GITHUB_HOST_ORIGIN="git@github.com:" mr -d . checkout
#
#   will clone:
#
#     git@github.com:user/repo.git
#
# - Note the environ lets you specify a local remote instead, e.g.,
#
#     MR_GITHUB_HOST_ORIGIN=/media/user/some-mount mr -d /path/to/user/repo -n checkout
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
#   This function uses MR_GITHUB_HOST_ORIGIN to format the URL, and
#   to clone the remote repository.
#
# So generally the user will set MR_GITHUB_HOST_ORIGIN and use
# `remote_set`, but they won't call this function directly.

git_clone_giturl () {
  local remote_url_or_local_path=""
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
        [ -n "${remote_url_or_local_path}" ] && [ -n "${target_dir}" ] \
          && >&2 echo "ERROR: more than one git_clone_giturl path or URL" \
          && return 1 || true

        [ -z "${remote_url_or_local_path}" ] \
          && remote_url_or_local_path="$1" \
          || target_dir="$1"

        shift
        ;;
    esac
  done

  [ -z "${remote_url_or_local_path}" ] \
    && >&2 echo "ERROR: missing git_clone_giturl path or URL" \
    && return 1 || true

  local git_url
  git_url="$(_github_url_according_to_user "${remote_url_or_local_path}")"

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

# USAGE: Converts https:// git remotes to git@ remotes.
# - Useful if you use https:// on some machines but git@ on others.
# - E.g., if user's OMR config specifies an HTTPS remote, e.g.,
#     lib = remote_set publish https://github.com/landonb/ohmyrepos.git
#   This function will either print the HTTPS URL:
#     https://github.com/landonb/ohmyrepos.git
#   Or it'll print the SSH URL:
#     git@github.com:landonb/ohmyrepos.git
# - To use an SSH URL for GitHub URLs, define the
#   MR_GITHUB_HOST_ORIGINAL environ, e.g.,
#     MR_GITHUB_HOST_ORIGIN="git@github.com:"
#   otherwise defaults to HTTP, which is equivalent to:
#     MR_GITHUB_HOST_ORIGIN="https://github.com/"
#   This lets you set different environs on different machines you use.
# - To use an SSH URL for GitLab URLs, define the
#   MR_GITLAB_HOST_ORIGIN environ, e.g.,
#     MR_GITLAB_HOST_ORIGIN="git@gitlab.com:"
# - This function will leave other URLs, including local path URLs
#   (such as "/path/to/repo"), unchanged.
# - If you'd like to always use an SSH URL, or if you want to use a
#   different SSH URL than the environ specifies, you can specify
#   that instead, e.g.,
#     lib = remote_set publish git@github_user:landonb/ohmyrepos.git
#   will use the corresponding SSH identify defined ~/.ssh/config,
#   e.g.,
#       # https://github.com/user
#       # To test:
#       #   ssh -T git@github_user
#       Host github_user
#         HostName github.com
#         User user
#         IdentitiesOnly yes
#         IdentityFile ~/.ssh/id_github_user_ed25519
_github_url_according_to_user () {
  local remote_url_or_local_path="$1"

  # Strip trailing comment character and project emoji, if set.
  # - E.g., change "https://github.com/landonb/ohmyrepos#😤"
  #             to "https://github.com/landonb/ohmyrepos"
  local santized_url_or_path
  santized_url_or_path="$( \
    echo "${remote_url_or_local_path}" | sed 's/^\(.*\)\(#[^#]*\)$/\1/'
  )"

  # Leave "/"-prefixed local file path remote URLs as-is.
  if [ "${santized_url_or_path#/}" != "${santized_url_or_path}" ]; then
    printf "%s" "${santized_url_or_path}"

    return 0
  fi

  # ***

  # We know the remote is a URL and not a local path.
  local remote_url="${santized_url_or_path}"

  # Determine base HTTP URL, e.g., "https://github.com/", or
  # "https://gitlab.com/", etc.
  local https_host_origin
  https_host_origin="$( \
    echo "${remote_url}" | sed 's#^\(https\?://[^/]\+/\).*#\1#'
  )"

  # Check if user specified their own origin for either GH or GL,
  # e.g., "git@github.com:", or "git@gitlab.com:", etc.
  local git_host_origin=""
  if [ "${https_host_origin}" != "${remote_url}" ]; then
    if echo "${https_host_origin}" | grep -q -e "^https\?://github.com/$"; then
      git_host_origin="${MR_GITHUB_HOST_ORIGIN}"
    elif echo "${https_host_origin}" | grep -q -e "^https\?://gitlab.com/$"; then
      git_host_origin="${MR_GITLAB_HOST_ORIGIN}"
    fi
  fi

  # ***

  # If URL begins with https://github.com/ or https://gitlab.com/,
  # substitute ${git_host_origin}.
  # - Any other URL, including any git@ URL, will be left alone.
  # - WORDS: Just FYI, the Protocol (or Scheme) plus Host (plus Port)
  #   is called the *Origin*. E.g., "https://github.com".
  #     https://www.rfc-editor.org/rfc/rfc6454#section-5
  if [ -n "${git_host_origin}" ]; then
    # Strip the http:// or https:// prefix.
    local url_path_component
    url_path_component="$( \
      echo "${remote_url}" \
      | sed -E 's#^https?://[^/]+/(.*)#\1#' \
    )"

    # Reassemable URL using scheme/protocol (HTTPS/SSH) and domain (github.com)
    # from arg or environ.
    remote_url="${git_host_origin}${url_path_component}"
  fi

  printf "%s" "${remote_url}"
}

