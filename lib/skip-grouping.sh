#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# USAGE:
#
# In .mrconfig:
#
#   [<path>]
#   skip = mr_exclusive "group"
#
# From the CLI:
#
#   $ MR_INCLUDE=group mr -d / ls
#
# If you set skip on all projects, then this'll return no projects:
#
#   $ MR_INCLUDE= mr -d / ls
#
# and this'll return all projects still:
#
#   $ mr -d / ls
#
# To add to more than one group, try:
#
#   [<path>]
#   skip = mr_exclusive "group1" && mr_exclusive "group2"
#
# and then any of these will include <path>:
#
#   $ MR_INCLUDE=group1 mr -d / ls  # chooses `mr_exclusive "group1"` projects
#   $ MR_INCLUDE=group2 mr -d / ls
#   $ mr -d / ls
#
# To ignore skip settings altogether, --force, e.g.,
#   $ cd <path>
#   $ mr -n --force <action>

# mr_exclusive_tag returns True if project should be skipped per MR_INCLUDE.
mr_exclusive_tag () {
  # If MR_INCLUDE unset, don't skip anything.
  # - Returns 1, aka false, aka don't skip.
  [ -z "${MR_INCLUDE+x}" ] && return 1

  # MR_INCLUDE is set.

  # Sort negated tags first.
  local sorted_tags
  sorted_tags="$(
    for tag in "$@"; do echo "${tag}" | sed '/^[^!]/d'; done
    for tag in "$@"; do echo "${tag}" | sed '/^!/d'; done
  )"

  # Check tags, and return 1 (don't skip) if MR_INCLUDE
  # matches input tag, or if a negated tag and doesn't.
  while [ $# -gt 0 ]; do
    local tag="$1"
    shift

    if [ -z "${tag}" ]; then

      continue
    fi

    # MR_INCLUDE tag matches, so don't skip this project.
    if [ "${MR_INCLUDE}" = "${tag}" ]; then

      return 1
    fi

    # Check if OMR config uses negated tag.
    # - E.g., `skip = mr_exclusive "!foo"`.
    local nonnegated
    nonnegated="$(echo "${tag}" | sed 's/^!//')"
    if [ "${tag}" != "${nonnegated}" ] \
      && [ "${MR_INCLUDE}" != "${nonnegated}" ] \
    ; then

      return 1
    fi
  done

  # MR_INCLUDE tag didn't match.
  # - Returns 0 (skip) by default.
  return 0
}

# ***

mr_exclusive_remote () {
  if [ -z "${MR_REPO}" ]; then
    # Called outside a repo, e.g., from a [DEFAULT] `include` block.
    # - Use case: Lets user check MR_INCLUDE tags before conditionally
    #   loading additional config.

    # Don't skip
    return 1
  fi

  if [ -z "${MR_INCLUDE_REMOTE}" ]; then

    # Don't skip
    return 1
  fi

  # Skip unless remote exists.
  ! git_remote_exists "${MR_INCLUDE_REMOTE}"
}

# COPYD: ~/.kit/git/git-bump-version-tag/deps/sh-git-nubs/lib/git-nubs.sh
git_remote_exists () {
  local remote="$1"

  git remote get-url ${remote} > /dev/null 2>&1
}

# ***

mr_exclusive () {
  mr_exclusive_tag "$@" || mr_exclusive_remote
}

