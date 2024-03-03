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

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

source_deps () {
  # Load the logger library, from github.com/landonb/sh-logger.
  # - Includes print commands: info, warn, error, debug.
  . logger.sh

  # For git_branch_exists, git_branch_name, git_latest_commit_date,
  # git_remote_branch_object_name, git_sha_shorten, etc.
  . ${SHOILERPLATE:-${HOME}/.kit/sh}/sh-git-nubs/bin/git-nubs.sh
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

rebase_tip () {
  local remote_ref="$1"
  local local_name="$2"
  local tip_friendly="$3"
  local skip_rebase="${4:-false}"

  # USAGE: Caller-scope variable.
  TIP_BRANCH=""

  # *** Guard clauses

  if [ -z "${remote_ref}" ]; then
    >&2 error "ERROR: Please specify the “remote/branch”"

    return 1
  fi

  # ****

  local remote_name
  remote_name="$(echo "${remote_ref}" | sed -E 's#^([^/]+).*$#\1#')"

  if [ "${remote_name}" = "${remote_ref}" ]; then
    >&2 error "ERROR: Not a 'remote/branch': “${remote_ref}”"

    return 1
  fi

  # ****

  local current_branch
  current_branch="$(git_branch_name)"

  local ref_branch="ref/${tip_friendly}"

  # Prefer create new tip/ branch from most recent tip, falling back
  # on ref/ if necessary, in case tip/ has recent conflict resolutions.
  if ${skip_rebase}; then
    ref_branch="${remote_ref}"
  elif echo "${current_branch}" | grep -q '^tip/'; then
    ref_branch="${current_branch}"
  elif ! git_branch_exists "${ref_branch}"; then
    >&2 error "ERROR: Not a TIP branch: “${current_branch}”"
    >&2 error "- HINT: Checkout a tip/ branch, or make a ref/ branch"

    return 1
    #fi
    #git checkout "${ref_branch}" > /dev/null 2>&1
  fi

  # ***

  git fetch --prune ${upstream}

  # ***

  # User can name a local ref to make a local branch for the remote ref.
  # But it's not necessary, just a convenience.
  if [ -n "${local_name}" ]; then
    if ! git checkout -b "${local_name}" "${remote_ref}" > /dev/null 2>&1; then
      git checkout "${local_name}" > /dev/null 2>&1
    fi

    git branch -u ${remote_ref} > /dev/null

    git merge --ff-only "${remote_ref}" > /dev/null
  fi

  # ***

  local name=""
  if [ -n "${tip_friendly}" ]; then
    name="${tip_friendly}/"
  fi

  local date="$(git_commit_date "${remote_ref}")"

  local remote_sha="$( \
    git_sha_shorten "$(git_remote_branch_object_name "${remote_ref}")" 7
  )"

  # SAVVY: Don't use current date in the name, so we can detect when up to date.
  local tip_branch="tip/${name}${date}/${remote_sha}"

  local up_to_date=false

  if ! git checkout -b "${tip_branch}" "${ref_branch}" > /dev/null 2>&1; then
    info "Latest project source already TIPped"
    info "- HINT: Delete the branch to recreate it:"
    info "    git branch -D ${tip_branch}"

    up_to_date=true

    git checkout "${tip_branch}" > /dev/null 2>&1
  fi

  git branch -u ${remote_ref} > /dev/null

  # ***

  local merge_base=$(git merge-base ${remote_ref} ${ref_branch})
  local ref_commit=$(git rev-parse ${remote_ref})

  # echo "remote_ref: ${remote_ref}"
  # echo "ref_branch: ${ref_branch}"
  # echo "merge_base: ${merge_base}"
  # echo "ref_commit: ${ref_commit}"

  if ! ${skip_rebase} && [ "${merge_base}" = "${ref_commit}" ]; then
    >&2 info "Tip branch up to date"

    up_to_date=true
  fi

  if ${up_to_date}; then
    return 0
  fi

  # ***

  if ! ${skip_rebase}; then
    echo "git rebase ${ref_commit}"

    git rebase ${ref_commit}

    if [ $? -ne 0 ]; then
      >&2 error "ERROR: The rebase encountered conflicts. Please fix it *yourself*"

      return 1
    fi
  fi

  # ***

  TIP_BRANCH="${tip_branch}"

  info "Create new TIP “${tip_branch}”"

  return 0
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main () {
  source_deps
}

main "$@"
unset -f main
unset -f source_deps

