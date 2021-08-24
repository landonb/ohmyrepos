#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# Automatically rebase the current branch against the specified
# "upstream/branch". E.g.,
#
#   rebase_tip 'upstream/release'
#
# This is useful if you've forked a project to add a few tweaks
# and you want to follow mainline without submitting a PR to have
# your work integrated. (I.e., you can't run a simple "git pull"
# but would need to rebase instead -- this command helps automate
# the rebase.)
#
# The command fetches the indicated remote first. Then it checks
# merge-base to see if the rebase is necessary. Next, it creates
# a conventionally-named "tip" branch using the "tip/" prefix,
# followed by today's date, and then the first seven digits of the
# latest remote branch ID. E.g., "tip/2021-02-19-abcd123".
#
# This command is also useful if the branch to rebase on is not
# the same as the upstream tracking branch. E.g., normally you
# might run:
#   git branch --set-upstream-to={upstream} {branchname}
#   git pull --rebase --autostash
# Except if you've forked a project, the tracking branch is likely
# the remote branch on your user's account; but the rebase branch
# is likely from the project you forked from. I.e., the remote
# branch used to rebase onto is not the remote branch to which you
# push the tip.
#
# And why do I call it a TIPped branch? Only to honor the somewhat
# conventional Git concept of a WIP branch (Work In Progress). A
# TIP branch is similarly somewhat transient, like a WIP branch.
# Using the tip/ prefix, the date and part of the commit hash gives
# other developers a little hint that the branch they're looking at
# is not a normal feature or development branch.

rebase_tip () {
  local remote_ref="$1"
  [ -z "${remote_ref}" ] &&
    >&2 error "ERROR: Please specify the “remote/branch”" &&
    return 1

  local remote_name="$(echo "${remote_ref}" | sed -E 's#^([^/]+).*$#\1#')"
  [ "${remote_name}" = "${remote_ref}" ] &&
    >&2 error "ERROR: Not a 'remote/branch': “${remote_ref}”" &&
    return 1

  local local_branch="$(
    git rev-parse --abbrev-ref=loose HEAD 2> /dev/null
  )"
  echo "${local_branch}" | grep -q '^tip/' || (
    >&2 error "ERROR: Not a TIP branch: “${local_branch}”" &&
    return 1
  )

  git fetch ${upstream}

  local merge_base=$(git merge-base ${remote_ref} ${local_branch})
  local ref_commit=$(git rev-parse ${remote_ref})
  [ "${merge_base}" = "${ref_commit}" ] &&
    >&2 info "Tip branch already up to date" &&
    return 0

  local ref_id7="$(echo ${ref_commit} | sed -E 's/^([0-9a-f]{7}).*$/\1/')"
  local tipped_branch="tip/$(date "+%Y-%m-%d")-${ref_id7}"

  git checkout -b ${tipped_branch}

  git rebase ${ref_commit}
  [ $? -ne 0 ] &&
    >&2 error "ERROR: The rebase encountered conflicts. Please fix it *yourself*" &&
    return 1

  return 0
}

