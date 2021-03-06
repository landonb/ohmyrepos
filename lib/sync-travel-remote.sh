# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash

# Summary: Methods to manage a mirrored remote, either locally via path, or via ssh.
#
# Mirrored as in, you have the same set of repositories on each
# machine/device/path, which can all be found at the same path.
#
# - For local-path mirrors, the repos are managed bare, so that files
#   are not unnecessarily duplicated. (E.g., the local path might be
#   to an encrypted filesystem that you mount off a thumb drive that
#   you carry around as a backup device.) You can then either ff-merge
#   your local repos into the mirror, or you can ff-merge the mirror
#   repos into your local repos, thereby making it easy for you to
#   switch between development machines.
#
# - For ssh mirrors, you can ff-merge the mirrored repos into your
#   local repos. (The ssh paths are simply added as remotes to each
#   of your local repos, then fetched, and then a --ff-only merge is
#   attempted, but only in the local repository is tidy (nothing
#   unstaged, uncommitted, nor untracked).

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

MR_APP_NAME='mr'

GIT_BARE_REPO='--bare'

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

reveal_biz_vars () {
  # 2019-10-21: (lb): Because myrepos uses subprocesses, our best bet (read:
  # lazy path to profit) to collect data from all repos is with temporaries.
  # Add the parent process ID so this command may be run in parallel.
  MR_TMP_TRAVEL_HINT_FILE="/tmp/gitsmart-ohmyrepos-travel-${PPID}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

source_deps () {
  . "omr-lib-readlink.sh"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ #
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# 2020-09-21: Because `echo -e` not universally supported, and to avoid
# interpreting unknown input escape-looking characters, we use printf.
# - The following subshell functions were inspired by this discussion:
#   https://unix.stackexchange.com/questions/65803/why-is-printf-better-than-echo/65819
# - Note that we're using a subshell function to scope $IFS changes.
#   - I.e., `foo () ( ... )`, and not `foo () { ...; }`.
#   - We could avoid subshell with, e.g., `echo () { local IFS=" "... }`,
#     but `local` may not be as universal as using a subshell function.
#   - We could avoid subshell be storing/restoring IFS, but that seems tedious.
# - Note that "$*" returns a string of args. joined by first char. of IFS.
#   - We could instead use "$@" which stringifies array with space delimiters.

# We only need `echo -e` and `echo -en` replacements herein.
#
# Here's what `echo` and `echo -n` would look like:
#
#   _echo() (
#     IFS=" "
#     printf '%s\n' "$*"
#   )
#
#   _echo_n() (
#     IFS=" "
#     printf %s "$*"
#   )

_echo_e() (
  local IFS=" "
  printf '%b\n' "$*"
)

_echo_en() (
  local IFS=" "
  printf %b "$*"
)

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

_git_echo_long_op_start () {
  local right_now="$(date "+%Y-%m-%d @ %T")"
  LONG_OP_MSG=
  LONG_OP_MSG="$( _echo_e \
    "$(fg_lightorange)[WAIT]$(attr_reset) ${right_now} "\
    "$(fg_lightorange)⏳ ${1}$(attr_reset)" \
    "$(fg_lightorange)${MR_REPO}...$(attr_reset)" \
  )"
  _echo_en "${LONG_OP_MSG}"
}

_git_echo_long_op_finis () {
  _echo_en "\r"
  # Clear out the previous message (lest ellipses remain in terminal) e.g., clear:
  #      "[WAIT] 2019-10-30 @ 19:34:04 ⏳ fetchin’  /..." → 43 chars
  #                                       fetched🤙 /kit/Coldsprints
  _echo_en "                                           "  # add one extra for Unicode, or something.
  _echo_en "$(printf "${MR_REPO}..." | /usr/bin/env sed -E "s/./ /g")"
  _echo_en "\r"
  LONG_OP_MSG=
}


# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ #
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

is_ssh_path () {
  [ "${1#ssh://}" != "${1}" ] && return 0 || return 1
}

lchop_sep () {
  printf "$1" | /usr/bin/env sed "s#^/##"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ #
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

warn_repo_problem_9char () {
  status_adj="$1"
  opt_prefix="$2"
  opt_suffix="$3"
  warn "$(attr_reset) " \
    "${opt_prefix}$(fg_mintgreen)$(attr_emphasis)${status_adj}$(attr_reset)${opt_suffix}" \
    "   $(fg_mintgreen)${MR_REPO}$(attr_reset)"
}

git_dir_check () {
  local repo_path="$1"
  local repo_type="$2"
  local dir_okay=0
  if is_ssh_path "${repo_path}"; then
    return ${dir_okay}
  elif [ ! -d "${repo_path}" ]; then
    dir_okay=1
    info "No repo found: $(bg_maroon)$(attr_bold)${repo_path}$(attr_reset)"
    if [ "${repo_type}" = 'travel' ]; then
      touch ${MR_TMP_TRAVEL_HINT_FILE}
    else  # "${repo_type}" = 'local'
      # (lb): This should be unreacheable, because $repo_path is $MR_REPO,
      # and `mr` will have failed before now.
      fatal
      fatal "UNEXPECTED: local repo missing?"
      fatal "  Path to pull from is missing:"
      fatal "    “${repo_path}”"
      fatal
    fi
    warn_repo_problem_9char 'notsynced'
  elif [ ! -e "${repo_path}/.git" ] && [ ! -f "${repo_path}/HEAD" ]; then
    dir_okay=1
    info "No .git/|HEAD: $(bg_maroon)$(attr_bold)${repo_path}$(attr_reset)"
    warn_repo_problem_9char 'gitless' ' ' ' '
  else
    local before_cd="$(pwd -L)"
    cd "${repo_path}"
    (git rev-parse --git-dir --quiet >/dev/null 2>&1) && dir_okay=0 || dir_okay=1
    cd "${before_cd}"
    if [ ${dir_okay} -ne 0 ]; then
      info "Bad --git-dir: $(bg_maroon)$(attr_bold)${repo_path}$(attr_reset)"
      info "  “$(git rev-parse --git-dir --quiet 2>&1)”"
      warn_repo_problem_9char 'rev-parse'
    fi
  fi
  return ${dir_okay}
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

must_be_git_dirs () {
  local source_repo="$1"
  local target_repo="$2"
  local source_type="$3"
  local target_type="$4"

  _git_echo_long_op_start 'check-git'
  #

  local a_problem=0

  git_dir_check "${source_repo}" "${source_type}"
  [ $? -ne 0 ] && a_problem=1

  git_dir_check "${target_repo}" "${target_type}"
  [ $? -ne 0 ] && a_problem=1

  #
  _git_echo_long_op_finis

  return ${a_problem}
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ #
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_travel_cache_setup () {
  ([ "${MR_ACTION}" != 'travel' ] && return 0) || true
  /bin/rm -f "${MR_TMP_TRAVEL_HINT_FILE}"
}

git_travel_cache_teardown () {
  ([ "${MR_ACTION}" != 'travel' ] && return 0) || true
  local ret_code=0
  if [ -e ${MR_TMP_TRAVEL_HINT_FILE} ]; then
    info
    warn "One or more errors suggest that you need to setup the travel device."
    info
    info "You can setup the travel device easily by running:"
    info
    info "  $(fg_lightorange)MR_TRAVEL=${MR_TRAVEL} ${MR_APP_NAME} travel$(attr_reset)"
    ret_code=0
  fi
  /bin/rm -f ${MR_TMP_TRAVEL_HINT_FILE}
  return ${ret_code}
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ #
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

travel_ops_reset_stats () {
  DID_CLONE_REPO=0
  DID_SET_REMOTE=0
  DID_FETCH_CHANGES=0
  DID_BRANCH_CHANGE=0
  DID_MERGE_FFWD=0
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ #
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_ensure_or_clone_target () {
  local source_repo="$1"
  local target_repo="$2"

  # The caller will all `must_be_git_dirs` later to ensure that
  # the target is indeed a git repo, so all we care about here
  # is if the target is missing or an empty directory, then we
  # can clone (into) it.
  if [ -d "${target_repo}" ]; then
    # Check whether the target directory is nonempty and return if so.
    if [ -n "$(/usr/bin/env ls -A ${target_repo} 2>/dev/null)" ]; then
      return 0
    fi
  fi

  _git_echo_long_op_start 'clonin’  '
  #
  # UNSURE/2019-10-30: Does subprocess mean Ctrl-C won't pass through?
  # I.e., does calling git-clone not in subprocess make mr command faster killable?
  if false; then
    local retco=0
    local git_resp
    git_resp=$( \
      git clone ${GIT_BARE_REPO} -- "${source_repo}" "${target_repo}" 2>&1 \
    ) || retco=$?
  fi
  #
  local retco=0
  local git_respf="$(mktemp --suffix='.myrepostravel-clone')"
  set +e
  git clone ${GIT_BARE_REPO} -- "${source_repo}" "${target_repo}" >"${git_respf}" 2>&1
  retco=$?
  set -e
  local git_resp="$(<"${git_respf}")"
  /bin/rm "${git_respf}"
  #
  _git_echo_long_op_finis

  if [ ${retco} -ne 0 ]; then
    warn "Clone failed!"
    warn "  \$ git clone ${GIT_BARE_REPO} -- '${source_repo}' '${target_repo}'"
    warn "  ${git_resp}"
    warn_repo_problem_9char 'uncloned!'
    return 1
  fi

  DID_CLONE_REPO=1
  info "  $(fg_lightgreen)$(attr_emphasis)✓ cloned🖐$(attr_reset)  " \
    "$(fg_lightgreen)${MR_REPO}$(attr_reset)"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ #
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_checkedout_branch_name_direct () {
  local before_cd="$(pwd -L)"
  cd "$1"
  local branch_name
  branch_name=$(git rev-parse --abbrev-ref=loose HEAD)
  cd "${before_cd}"
  printf %s "${branch_name}"
}

git_checkedout_branch_name_remote () {
  local target_repo="$1"
  local remote_name="${2:-${MR_REMOTE}}"

  local before_cd="$(pwd -L)"
  cd "${target_repo}"
  local branch_name
  branch_name=$( \
    git remote show ${remote_name} |
    grep "HEAD branch:" |
    /usr/bin/env sed -e "s/^.*HEAD branch:\s*//" \
  )
  cd "${before_cd}"
  printf %s "${branch_name}"
}

git_source_branch_deduce () {
  local source_repo="$1"
  local target_repo="$2"

  local source_branch
  if is_ssh_path "${source_repo}"; then
    # If detached HEAD (b/c git submodule, or other why), remote-show shows "(unknown)".
    source_branch=$(git_checkedout_branch_name_remote "${target_repo}" "${MR_REMOTE}")
  else
    # If detached HEAD (b/c git submodule, or other), rev-parse--abbrev-ref says "HEAD".
    source_branch=$(git_checkedout_branch_name_direct "${source_repo}")
  fi

  printf %s "${source_branch}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# I don't need this fcn. Reports the tracking branch, (generally 'upstream)
#   I think, because @{u}. [Not quite sure what that is; *tracking* remote?]
# WARNING/2020-03-14: (lb): This function not called.
git_checkedout_remote_branch_name () {
  # Include the name of the remote, e.g., not just feature/foo,
  # but origin/feature/foo.
  local before_cd="$(pwd -L)"
  cd "$1"
  local remote_branch
  remote_branch=$(git rev-parse --abbrev-ref --symbolic-full-name @{u})
  cd "${before_cd}"
  printf %s "${remote_branch}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ #
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_is_bare_repository () {
  [ $(git rev-parse --is-bare-repository) = 'true' ] && return 0 || return 1
}

git_must_be_clean () {
  # If a bare repository, no working status... so inherently clean, er, negative.
  git_is_bare_repository && return 0 || true
  [ -z "$(git status --porcelain)" ] && return 0 || true
  info "   $(fg_lightorange)$(attr_underline)✗ dirty$(attr_reset)   " \
    "$(fg_lightorange)$(attr_underline)${MR_REPO}$(attr_reset)  $(fg_hotpink)✗$(attr_reset)"
  exit 1
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ #
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_set_remote_travel () {
  local source_repo="$1"
  local target_repo="${2:-$(pwd -L)}"
  # Instead of $(pwd), could use environ:
  #   local target_repo="${2:-${MR_REPO}}"

  _git_echo_long_op_start 'get-url’g'

  local before_cd="$(pwd -L)"
  cd "${target_repo}"

  local extcd=0
  local remote_url
  remote_url=$(git remote get-url ${MR_REMOTE} 2>/dev/null) || extcd=$?

  # trace "  git_set_remote_travel:"
  # trace "   target: ${target_repo}"
  # trace "   remote: ${remote_url}"
  # trace "  git-url: ${extcd}"

  if [ ${extcd} -ne 0 ]; then
    #trace "  Fresh remote wired for “${MR_REMOTE}”"
    git remote add ${MR_REMOTE} "${source_repo}"
    DID_SET_REMOTE=1
    #
    _git_echo_long_op_finis
    info "  $(fg_green)$(attr_emphasis)✓ r-wired👈$(attr_reset)" \
      "$(fg_green)${MR_REPO}$(attr_reset)"
  elif [ "${remote_url}" != "${source_repo}" ]; then
    git remote set-url ${MR_REMOTE} "${source_repo}"
    DID_SET_REMOTE=1
    #
    _git_echo_long_op_finis
    info "  $(fg_green)$(attr_emphasis)✓ r-wired👆$(attr_reset)" \
      "$(fg_green)${MR_REPO}$(attr_reset)"
    debug "  Reset remote wired for “${MR_REMOTE}”" \
      "(was: $(attr_italic)${remote_url}$(attr_reset))"
  else
    #trace "  The “${MR_REMOTE}” remote url is already correct!"
    : # no-op
    _git_echo_long_op_finis
  fi

  cd "${before_cd}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_fetch_remote_travel () {
  local target_repo="${1:-$(pwd -L)}"
  # Instead of $(pwd), could use environ:
  #   local target_repo="${1:-${MR_REPO}}"
  local target_type="$2"

  _git_echo_long_op_start 'fetchin’ '

  local before_cd="$(pwd -L)"
  cd "${target_repo}"

  local extcd=0
  local git_resp
  # MAYBE/2019-12-23: Do we need a --prune-tags, too?
  git_resp="$(git fetch ${MR_REMOTE} --prune 2>&1)" || extcd=$?
  local fetch_success=${extcd}

  _git_echo_long_op_finis

  verbose "git fetch says:\n${git_resp}"
  # Use `&& true` in case grep does not match anything,
  # so as not to tickle errexit.
  # 2018-03-23: Is the "has become dangling" message meaningful to me?
  local culled="$(printf %s "${git_resp}" \
    | grep -v "^Fetching " \
    | grep -v "^From " \
    | grep -v "+\? *[a-f0-9]\{7,8\}\.\{2,3\}[a-f0-9]\{7,8\}.*->.*" \
    | grep -v -P '\* \[new branch\] +.* -> .*' \
    | grep -v -P '\* \[new tag\] +.* -> .*' \
    | grep -v "^ \?- \[deleted\] \+(none) \+-> .*" \
    | grep -v "(refs/remotes/origin/HEAD has become dangling)" \
  )"

  [ -n "${culled}" ] && warn "git fetch wha?\n${culled}" || true
  [ -n "${culled}" ] && [ ${LOG_LEVEL} -gt ${LOG_LEVEL_VERBOSE} ] && \
    notice "git fetch says:\n${git_resp}" || true

  if [ ${fetch_success} -ne 0 ]; then
    error "Unexpected fetch failure! ${git_resp}"
  fi

  if [ -n "${git_resp}" ]; then
    DID_FETCH_CHANGES=1
  fi
  if [ "${target_type}" = 'travel' ]; then
    if [ -n "${git_resp}" ]; then
      info "  $(fg_green)$(attr_emphasis)✓ fetched🤙$(attr_reset)" \
        "$(fg_green)${MR_REPO}$(attr_reset)"
    else
      debug "  $(fg_green)fetchless$(attr_reset)  " \
        "$(fg_green)${MR_REPO}$(attr_reset)"
    fi
  # else, "$target_type" = 'local'.
  fi

  cd "${before_cd}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ #
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_show_ref_branch_sha8 () {
  local target_branch="${1:-release}"
  git show-ref -s refs/heads/${target_branch} |
    /usr/bin/env sed 's/^\(.\{8\}\).*/\1/'
}

git_change_branches_if_necessary () {
  local source_branch="$1"
  local target_branch="$2"
  local target_repo="${3:-$(pwd -L)}"
  # Instead of $(pwd), could use environ:
  #   local target_repo="${3:-${MR_REPO}}"

  # FIXED?/2020-09-21: Avoid the problem described in this comment,
  # by using `loose`:
  #
  #     $ git rev-parse --abbrev-ref=loose HEAD
  #     release
  #
  # Read on for the older (fixed?) comment...
  #
  #   BEWARE/2020-07-02: (lb): I don't quite understand the mechanics, but:
  #
  #   If there's a HEAD file, the source_branch will have a 'heads/' prefix, e.g.,
  #       source_branch=heads/release
  #   and then the `git update-ref` below will fail on the error:
  #       fatal: remotes/<DEVICE>/heads/<branch>: not a valid SHA1
  #
  #   This happens if you do something like:
  #       $ git remote set-head release --auto
  #   Because then (as called from git_checkedout_branch_name_direct):
  #       $ git rev-parse --abbrev-ref HEAD
  #       heads/release
  #   Which occurs because of the file:
  #       $ cat .git/refs/remotes/release/HEAD
  #       ref: refs/remotes/release/release
  #
  #   You can resolve this issue by removing the HEAD file thusly:
  #       $ git remote set-head release --delete
  #   And then:
  #       $ git rev-parse --abbrev-ref HEAD
  #       release
  #
  #   (I did not create the HEAD file intentionally; I renamed all 'master'
  #   branches, mostly to 'release', and deleted said branch from GitHub,
  #   and then I had this issue in a few of my projects, but not all.)
  #
  #   In lieu of fixing this automatically, check for it.
  #   (NOTE: Because POSIX, we use case for wildcard matching, i.e.,
  #          in Bash we could [[ "${source_branch}" == heads/* ]]; but
  #           not in POSIX
  #           endbut
  #
  # NOTE/2020-09-21: This case block might not fire any more, if the change
  # to `git_checkedout_branch_name_direct` works (I set --abbrev-ref=loose).
  case "${source_branch}" in
    "heads/"*) >&2 error "ERROR?: Try \`cd <source_repo> &&" \
                         "git remote set-head ${target_branch} --delete\`"
  esac

  # Detached HEAD either "HEAD" (--abbrev-ref) or "(unknown)" (remote show).
  if [ "${source_branch}" = "HEAD" ] || [ "${source_branch}" = "(unknown)" ]; then
    # If (detached) HEAD is active branch, do naught.
    info "  $(fg_mintgreen)$(attr_emphasis)✗ checkout $(attr_reset)" \
      "SKIP: $(fg_lightorange)$(attr_underline)${target_branch}$(attr_reset)" \
      "》$(fg_lightorange)$(attr_underline)${source_branch}$(attr_reset)"
    return
  fi

  local before_cd="$(pwd -L)"
  cd "${target_repo}"

  local wasref newref
  if git_is_bare_repository; then
    wasref="$(git_show_ref_branch_sha8 "${target_branch}")"
    git update-ref refs/heads/${source_branch} remotes/${MR_REMOTE}/${source_branch}
    newref="$(git_show_ref_branch_sha8 "${target_branch}")"
  fi

  if [ "${source_branch}" != "${target_branch}" ]; then
    _git_echo_long_op_start 'branchin’'
    #
    if git_is_bare_repository; then
      git update-ref refs/heads/${source_branch} remotes/${MR_REMOTE}/${source_branch}
      git symbolic-ref HEAD refs/heads/${source_branch}
    else
      local extcd=0
      (git checkout ${source_branch} >/dev/null 2>&1) || extcd=$?
      if [ $extcd -ne 0 ]; then
  # FIXME: On unpack, this might need/want to be origin/, not travel/ !
        git checkout --track ${MR_REMOTE}/${source_branch}
      fi
    fi
    DID_BRANCH_CHANGE=1
    #
    _git_echo_long_op_finis

    info "  $(fg_mintgreen)$(attr_emphasis)✓ checkout $(attr_reset)" \
      "$(fg_lightorange)$(attr_underline)${target_branch}$(attr_reset)" \
      "》$(fg_lightorange)$(attr_underline)${source_branch}$(attr_reset)"
  elif [ "${wasref}" != "${newref}" ]; then
    # FIXME/2020-03-21: Added this elif and info, not sure I want to keep.
    info "  $(fg_mintgreen)$(attr_emphasis)✓ updt-ref $(attr_reset)" \
      "${target_branch}: " \
      "$(fg_lightorange)$(attr_underline)${wasref}$(attr_reset)" \
      "》$(fg_lightorange)$(attr_underline)${newref}$(attr_reset)"
  fi

  cd "${before_cd}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ #
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_merge_ff_only () {
  local source_branch="$1"
  local target_repo="${2:-$(pwd -L)}"
  # Instead of $(pwd), could use environ:
  #   local target_repo="${2:-${MR_REPO}}"

  local to_commit
  # Detached HEAD either "HEAD" (--abbrev-ref) or "(unknown)" (remote show).
  if [ "${source_branch}" = "HEAD" ] || [ "${source_branch}" = "(unknown)" ]; then
    debug "  $(fg_mediumgrey)skip-HEAD$(attr_reset)  " \
      "$(fg_mediumgrey)${MR_REPO}$(attr_reset)"
    return
    # MEH/2019-11-21 03:12: We could get around detached HEAD by using SHA, e.g.,:
    #   # Remote is non-local (ssh) and detached head ((unknown)). Get HEAD's SHA.
    #   to_commit=$(git ls-remote ${MR_REMOTE} | grep -P "\tHEAD$" | cut -f1)
    # but the use case for detached HEAD is slim (so far just my ~/.vim repo which
    # has submodules, as far as I'm aware), so I'd rather do nothing/skip merge on
    # detached HEAD repos.
  else
    to_commit="${MR_REMOTE}/${source_branch}"
  fi

  _git_echo_long_op_start 'mergerin’'

  local before_cd="$(pwd -L)"
  cd "${target_repo}"

  # For a nice fast-forward vs. --no-ff article, see:
  #   https://ariya.io/2013/09/fast-forward-git-merge

  # Ha! 2019-01-24: Seeing:
  #   "fatal: update_ref failed for ref 'ORIG_HEAD': could not write to '.git/ORIG_HEAD'"
  # because my device is full. Guh.

  local extcd=0
  local git_resp
  git_resp=$(git merge --ff-only ${to_commit} 2>&1) || extcd=$?
  local merge_success=${extcd}

  # 2018-03-26 16:41: Weird: was this directory moved, hence the => ?
  #    src/js/{ => solutions}/settings/constants.js       |  85 ++-
  #local pattern_txt='^ \S* *\| +\d+ ?[+-]*$'
  local pattern_txt='^ [^\|]+\| +\d+ ?[+-]*$'
  #local pattern_bin='^ \S* *\| +Bin \d+ -> \d+ bytes$'
  #  | grep -P -v " +\S+ +\| +Bin$" \
  #local pattern_bin='^ \S* *\| +Bin( \d+ -> \d+ bytes)?$'
  #local pattern_bin='^ \S*( => \S*)? *\| +Bin( \d+ -> \d+ bytes)?$'
  local pattern_bin='^ [^\|]+\| +Bin( \d+ -> \d+ bytes)?$'

  verbose "git merge says:\n${git_resp}"
  # NOTE: The checking-out-files line looks like this would work:
  #         | grep -P -v "^Checking out files: 100% \(\d+/\d+\), done.$" \
  #       but it doesn't, I think because the "100%" was updated live,
  #       so there are other digits and then backspaces, I'd guess.
  #       Though this doesn't work:
  #         | grep -P -v "^Checking out files: [\d\b]+" \
  local culled="$(printf %s "${git_resp}" \
    | grep -v "^Already up to date.$" \
    | grep -v "^Updating [a-f0-9]\{7,10\}\.\.[a-f0-9]\{7,10\}$" \
    | grep -v "^Fast-forward$" \
    | grep -P -v "^Checking out files: " \
    | grep -P -v "^ \d+ files? changed, \d+ insertions?\(\+\), \d+ deletions?\(-\)$" \
    | grep -P -v "^ \d+ files? changed, \d+ insertions?\(\+\)$" \
    | grep -P -v "^ \d+ files? changed, \d+ deletions?\(-\)$" \
    | grep -P -v "^ \d+ insertions?\(\+\), \d+ deletions?\(-\)$" \
    | grep -P -v "^ \d+ files? changed$" \
    | grep -P -v " rename .* \(\d+%\)$" \
    | grep -P -v " create mode \d+ \S+" \
    | grep -P -v " delete mode \d+ \S+" \
    | grep -P -v " mode change \d+ => \d+ \S+" \
    | grep -P -v "^ \d+ insertions?\(\+\)$" \
    | grep -P -v "^ \d+ deletions?\(-\)$" \
    | grep -P -v "${pattern_txt}" \
    | grep -P -v "${pattern_bin}" \
  )"

  _git_echo_long_op_finis

  [ -n "${culled}" ] && warn "git merge wha?\n${culled}" || true
  [ -n "${culled}" ] && [ ${LOG_LEVEL} -gt ${LOG_LEVEL_VERBOSE} ] && \
    notice "git merge says:\n${git_resp}" || true

  # NOTE: The grep -P option only works on one pattern grep, so cannot use -e, eh?
  # 2018-03-26: First attempt, naive, first line has black bg between last char and NL,
  # but subsequent lines have changed background color to end of line, seems weird:
  #   local changes_txt="$(printf %s "${git_resp}" | grep -P "${pattern_txt}")"
  #   local changes_bin="$(printf %s "${git_resp}" | grep -P "${pattern_bin}")"
  # So use sed to sandwich each line with color changes.
  # - Be sure color is enabled, lest:
  #     /usr/bin/env sed: -e expression #1, char 7: unterminated `s' command
  #   because $() returns empty.
  SHCOLORS_OFF=false
  local grep_sed_sed='
    /usr/bin/env sed "s/\$/\\$(attr_reset)/g" |
    /usr/bin/env sed "s/^/\\$(bg_blue)/g"
  '
  #
  local changes_txt="$( \
    printf %s "${git_resp}" | grep -P "${pattern_txt}" | eval "${grep_sed_sed}" \
  )"
  local changes_bin="$( \
    printf %s "${git_resp}" | grep -P "${pattern_bin}" | eval "${grep_sed_sed}" \
  )"
  #
  if [ -n "${changes_txt}" ]; then
    info "  $(fg_mintgreen)$(attr_emphasis)txt+$(attr_reset)       " \
      "$(fg_mintgreen)${MR_REPO}$(attr_reset)"
    info "${changes_txt}"
  fi
  if [ -n "${changes_bin}" ]; then
    info "       $(fg_mintgreen)$(attr_emphasis)bin+$(attr_reset)  " \
      "$(fg_mintgreen)${MR_REPO}$(attr_reset)"
    info "${changes_bin}"
  fi

  # We verified `git status --porcelain` indicated nothing before trying to merge,
  # so this could mean the branch diverged from remote, or something. Inform user.
  if [ ${merge_success} -ne 0 ]; then
    # CXPX/NOT-DRY: This info copied from git-my-merge-status, probably same as:
    #   git_status_check_report_9chars 'mergefail' '  '
    info "  $(fg_lightorange)$(attr_underline)mergefail$(attr_reset)  " \
      "$(fg_lightorange)$(attr_underline)${MR_REPO}$(attr_reset)  $(fg_hotpink)✗$(attr_reset)"
    # (lb): So weird: Dubs Vim syntax highlight broken on "... ${to_commit}\` ...".
    #       For some reason the bracket-slash, }\, causes the rest of file
    #       to appear quoted. E.g., $to_commit\` is okay but ${to_commit}\`
    #       breaks my syntax highlighter. - Sorry for the comment non sequitur!
    #       This remark really has nothing to do with this code. I should take
    #       my problems offline, I know.
    warn "Merge failed! \`merge --ff-only $to_commit\` says:"
    warn " ${git_resp}"
    # warn " target_repo: ${target_repo}"
  elif (printf %s "${git_resp}" | grep '^Already up to date.$' >/dev/null); then
    debug "  $(fg_mediumgrey)up-2-date$(attr_reset)  " \
      "$(fg_mediumgrey)${MR_REPO}$(attr_reset)"
  elif [ -z "${changes_txt}" ] && [ -z "${changes_bin}" ]; then
    # A warning, so you can update the grep above and recognize this output.
    warn "  $(fg_mintgreen)$(attr_emphasis)!familiar$(attr_reset)  " \
      "$(fg_mintgreen)${MR_REPO}$(attr_reset)"
  # else, ${merge_success} true, and either/or changes_txt/_bin,
  # so we've already printed multiple info statements.
  fi

  cd "${before_cd}"

  return ${merge_success}
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_fetch_n_cobr () {
  local source_repo="$1"
  local target_repo="$2"
  local source_type="$3"
  local target_type="$4"

  # ...

  must_be_git_dirs "${source_repo}" "${target_repo}" "${source_type}" "${target_type}"
  [ $? -ne 0 ] && return $? || true  # Obviously unreacheable if caller used `set -e`.

  # ...

  local before_cd="$(pwd -L)"
  cd "${target_repo}"  # (lb): Probably $MR_REPO, which is already cwd.

  local extcd=0
  (git_must_be_clean) || extcd=$?
  if [ ${extcd} -ne 0 ]; then
    cd "${before_cd}"
    exit ${extcd}
  fi

  # 2018-03-22: Set a remote to the sync device. There's always only 1,
  # apparently. I think this'll work well.
  git_set_remote_travel "${source_repo}"
  git_fetch_remote_travel "${target_repo}" "${target_type}"

  # ...

  local source_branch
  source_branch=$(git_source_branch_deduce "${source_repo}" "${target_repo}")
  # A global for later.
  MR_ACTIVE_BRANCH="${source_branch}"

  local target_branch
  target_branch=$(git_checkedout_branch_name_direct "${target_repo}")

  # Because `cd` above, do not need to pass "${target_repo}" (on $3).
  git_change_branches_if_necessary "${source_branch}" "${target_branch}"

  cd "${before_cd}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_fetch_n_cobr_n_merge () {
  local source_repo="$1"
  local target_repo="$2"
  local source_type="$3"
  local target_type="$4"
  travel_ops_reset_stats
  git_fetch_n_cobr "${source_repo}" "${target_repo}" "${source_type}" "${target_type}"
  # Fast-forward merge, so no new commits, and complain if cannot.
  git_merge_ff_only "${MR_ACTIVE_BRANCH}" "${target_repo}"
}

git_pack_travel_device () {
  local source_repo="$1"
  local target_repo="$2"
  travel_ops_reset_stats
  git_ensure_or_clone_target "${source_repo}" "${target_repo}"
  git_fetch_n_cobr "${source_repo}" "${target_repo}" 'local' 'travel'
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_merge_check_env_remote () {
  [ -z "${MR_REMOTE}" ] && error 'You must set MR_REMOTE!' && exit 1 || true
}

git_merge_check_env_repo () {
  [ -z "${MR_REPO}" ] && error 'You must set MR_REPO!' && exit 1 || true
}

git_merge_check_env_travel () {
  [ -z "${MR_TRAVEL}" ] && error 'You must set MR_TRAVEL!' && exit 1 || true
}

# The `mr ffssh` action.
git_merge_ffonly_ssh_mirror () {
  git_merge_check_env_remote
  git_merge_check_env_repo
  MR_FETCH_HOST=${MR_FETCH_HOST:-${MR_REMOTE}}
  local rel_repo=$(lchop_sep "${MR_REPO}")
  local ssh_path="ssh://${MR_FETCH_HOST}/${rel_repo}"
  git_fetch_n_cobr_n_merge "${ssh_path}" "${MR_REPO}" 'ssh' 'local'
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_update_ensure_ready () {
  git_merge_check_env_travel
  git_merge_check_env_repo
}

git_update_dev_path () {
  # 2019-10-30: To avoid mixing git-dir subdirectories and my subdirs,
  # add a path postfix to the repo path.
  #   local dev_path=$(readlink_m "${MR_TRAVEL}/${MR_REPO}")
  local git_name='_0.git'
  local dev_path=$(readlink_m "${MR_TRAVEL}/${MR_REPO}/${git_name}")
  printf %s "${dev_path}"
}

# The `mr travel` action.
git_update_device_fetch_from_local () {
  MR_REMOTE=${MR_REMOTE:-$(hostname)}
  local dev_path
  git_update_ensure_ready
  dev_path=$(git_update_dev_path)
  git_pack_travel_device "${MR_REPO}" "${dev_path}"
}

# The `mr unpack` action.
git_update_local_fetch_from_device () {
  git_merge_check_env_remote
  local dev_path
  git_update_ensure_ready
  dev_path=$(git_update_dev_path)
  git_fetch_n_cobr_n_merge "${dev_path}" "${MR_REPO}" 'travel' 'local'
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main () {
  source_deps
  reveal_biz_vars
}

main "$@"

