# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

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

_travel_source_deps () {
  # Load the logger library, from github.com/landonb/sh-logger.
  # - Includes print commands: info, warn, error, debug.
  . logger.sh
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

reveal_biz_vars () {
  local mrpid="$(mr_process_id)"

  # When called via multi-process `mr -j [n>1]`, colors.sh omits ANSI
  # color sequence (it checks if the process is connected to a terminal
  # ([ -t 0 ] && [ -t 1 ]), which is false, because subprocess pipes
  # output to the parent process, so technically not connected to stdout).
  # - Here we can assume terminaled unless explictly told to not use color,
  #   and if the main `mr` process is connected to stdout.
  # - To check if connected to stdout, we use the `mr` process ID
  #   and check the fdinfo/1 file.
  #   - CXREF: https://unix.stackexchange.com/questions/484789/
  #              testing-if-a-file-descriptor-is-valid-for-input
  local file_descriptor_stdout=1
  if [ ! -d "/proc/${mrpid}/fd/${file_descriptor_stdout}" ] \
    && grep -sq '^flags.*[02]$' "/proc/${mrpid}/fdinfo/${file_descriptor_stdout}" \
  ; then
    SHCOLORS_OFF=false
  fi

  # 2019-10-21: (lb): Because myrepos uses subprocesses, our best bet (read:
  # lazy path to profit) to collect data from all repos is with temporaries.
  # Add the parent process ID so this command may be run in parallel.
  MR_TMP_TRAVEL_HINT_FILE="/tmp/gitsmart-ohmyrepos-travel-hint-${mrpid}"
  # 2023-04-29: Stash mergefail copy-paste and print final list of chores.
  # - git-my-merge-status has had a similar feature for a few years.
  MR_TMP_TRAVEL_CHORES_FILE="/tmp/gitsmart-ohmyrepos-travel-chores-${mrpid}"

  # The actions use a mkdir mutex to gait access to the terminal and
  # to the tmp files. (The author was unable to cause interleaving
  # terminal output (even across multiple echoes). But it was easy (~50%
  # of the time) to cause tmp file to be clobbered when not locking).

  # Gait access to terminal and chores file output, to support multi-process (mr -j).
  MR_TMP_TRAVEL_LOCK_DIR="/tmp/gitsmart-ohmyrepos-travel-lock-${mrpid}"

  # The mutex mechanism only runs if multi-processing, a cached JIT variable.
  IS_MULTIPROCESSING=
}

mr_process_id () {
  local ancestor_pid

  if [ -z "${MR_REPO}" ]; then
    # MR_REPO is not set — the main process is calling this fcn on startup.
    ancestor_pid="${PPID}"
  # else, MR_REPO is set — the action fcn was called to process a specific repo.
  elif is_multiprocessing; then
    # This is a multi-process call, e.g., `mr --job 4`.
    # - Use the parent process ID of the parent process, aka grandparent PID (GPPID).
    # - Note that `ps` includes a leading whitespace for 4-digit PIDs.
    ancestor_pid="$(ps -o ppid= ${PPID} | tr -d ' ')"
  else
    # This is a normal, single-process repo task, e.g., `mr -j 1`.
    ancestor_pid="${PPID}"
  fi

  printf "${ancestor_pid}"
}

is_multiprocessing () {
  if [ -z "${IS_MULTIPROCESSING}" ]; then
    local match_int_over_2="([0-9]{2,}|[2-9]{1})"

    echo "${MR_SWITCHES}" | \
      grep -q -E \
        -e "-j[ =]?${match_int_over_2}" \
        -e "--jobs[ =]?${match_int_over_2}" \
      && IS_MULTIPROCESSING=true \
      || IS_MULTIPROCESSING=false
  fi

  ${IS_MULTIPROCESSING}
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

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
  ! is_multiprocessing || return 0

  local right_now="$(date "+%Y-%m-%d @ %T")"

  LONG_OP_MSG="$( _echo_e \
    "$(fg_lightorange)[WAIT]$(attr_reset) ${right_now} "\
    "$(fg_lightorange)⏳ ${1}$(attr_reset)" \
    "$(fg_lightorange)${MR_REPO}...$(attr_reset)" \
  )"

  _echo_en "${LONG_OP_MSG}"
}

_git_echo_long_op_finis () {
  ! is_multiprocessing || return 0

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

# Avoid overlapping output issues when multi-processing (e.g., `mr -j 2`).
# - Use a mutex, aka binary semaphore, to gait output.
# - This avoids two issues:
#   - Interleaving terminal output (a hypothetical problem, at least;
#     author was unable to cause this behavior).
#   - Clobbering/corrupting a tmp file by append to it simultaneously
#     (by more than one process calling `echo ... >> tmp-file`).
#     - If you disable this mutex, it's easy to observe this behavior.
# - We use `mkdir` to implement the mutex, because it's just so easy.
travel_process_chores_file_lock_acquire () {
  is_multiprocessing || return 0

  local tries=0

  while true; do
    # mkdir is atomic, how convenient.
    if $(/bin/mkdir "${MR_TMP_TRAVEL_LOCK_DIR}" 2> /dev/null); then

      return
    fi

    # BASHism: let 'tries += 1'
    tries=$(($tries + 1))
    if [ $(($tries % 100)) -eq 100 ]; then
      # 2023-04-29: Author has never seen this message.
      >&2 echo "BWARE: Still waiting on travel lock! [$$]"
    fi

    sleep 0.01
  done
}

travel_process_chores_file_lock_release () {
  is_multiprocessing || return 0

  /bin/rmdir "${MR_TMP_TRAVEL_LOCK_DIR}"
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
  fi

  travel_process_chores_file_lock_acquire

  if [ ! -d "${repo_path}" ]; then
    dir_okay=1

    info "No repo found: $(bg_maroon)$(attr_bold)${repo_path}$(attr_reset)"

    if [ "${repo_type}" = 'travel' ]; then
      touch ${MR_TMP_TRAVEL_HINT_FILE}
    else  # "${repo_type}" = 'local'
      # (lb): This should be unreacheable, because $repo_path is $MR_REPO,
      # and `mr` will have failed before now.

      critical
      critical "UNEXPECTED: local repo missing?"
      critical "  Path to pull from is missing:"
      critical "    “${repo_path}”"
      critical

      exit 1
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

  travel_process_chores_file_lock_release

  return ${dir_okay}
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

must_be_git_dirs () {
  local source_repo="$1"
  local target_repo="$2"
  local source_type="$3"
  local target_type="$4"

  _git_echo_long_op_start 'check-git'

  local a_problem=0

  git_dir_check "${source_repo}" "${source_type}"
  [ $? -ne 0 ] && a_problem=1

  git_dir_check "${target_repo}" "${target_type}"
  [ $? -ne 0 ] && a_problem=1

  _git_echo_long_op_finis

  return ${a_problem}
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ #
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_travel_cache_setup () {
  ([ "${MR_ACTION}" != 'travel' ] && return 0) || true

  /bin/rm -f "${MR_TMP_TRAVEL_HINT_FILE}"

  /bin/rm -f "${MR_TMP_TRAVEL_CHORES_FILE}"

  # Just in case something failed without releasing lock.
  [ ! -d "${MR_TMP_TRAVEL_LOCK_DIR}" ] || /bin/rmdir "${MR_TMP_TRAVEL_LOCK_DIR}"
}

git_travel_cache_teardown () {
  ([ "${MR_ACTION}" != 'travel' ] && return 0) || true

  # KLUGE: When not multiprocessing (`mr -j 1`), `mr` uses the final
  # MR_REPO process to call this teardown function, but `mr` doesn't
  # clear MR_REPO.
  # - Vs. when multiprocessing, MR_REPO is not set when this function is called.
  #
  # - FIXME/2023-04-29: Check `mr` GitHub if known issue, and/or fix it yourself.
  # - SPIKE/2023-04-29: Nor does multiprocessing reuse the final MR_REPO process
  #     to call teardown — Investigate this: Why doesn't `mr` use the main process?
  #     Or why doesn't it create a new process, because even when not multiprocessing,
  #     `mr` still runs each MR_REPO action in a separate process.
  #     - Which is why this smells like a bigger problem than simpling
  #       having `mr` clear MR_REPO before calling teardown.
  #       - Perhaps `mr` should call this fcn. in a new subprocess, like it
  #         does when multiprocessing.
  #
  # In any case, ensure MR_REPO is unset, because it affects how the parent
  # (or grandparent) process ID is determined (see mr_process_id).
  MR_REPO=

  # See comment above `main`, at the bottom of this file:
  # - `main` skips the setup call when MR_REPO is set, because the action
  #   function has already run (the short-circuit return is merely pedantics,
  #   because it's harmless to call the setup function from `main` for each
  #   MR_REPO process; but we do so to make note of program flow, to avoid
  #   accidental issues in the future, and to verify our understanding of
  #   how this all works).
  sync_travel_remote_setup

  git_travel_process_hint_file

  git_travel_process_chores_file
}

git_travel_process_hint_file () {
  [ -e "${MR_TMP_TRAVEL_HINT_FILE}" ] || return 0

  info
  warn "One or more errors suggest that you need to setup the travel device."
  info
  info "You can setup the travel device easily by running:"
  info
  info "  $(fg_lightorange)MR_TRAVEL=${MR_TRAVEL} ${MR_APP_NAME} travel$(attr_reset)"

  /bin/rm "${MR_TMP_TRAVEL_HINT_FILE}"
}

git_travel_process_chores_file () {
  [ -e "${MR_TMP_TRAVEL_CHORES_FILE}" ] || return 0

  git_travel_process_chores_notify
  echo
  cat "${MR_TMP_TRAVEL_CHORES_FILE}"
  echo

  /bin/rm "${MR_TMP_TRAVEL_CHORES_FILE}"
}

# COPYD/2023-04-29: MAYBE: DRY this: Copied from git-my-merge-status.sh.
git_travel_process_chores_notify () {
  # Note that some hints are multiple lines, but all hints' first line
  # starts with the cd command, e.g., "  cd /path/to/repo && ...".
  local untidy_count=$(cat "${MR_TMP_TRAVEL_CHORES_FILE}" | grep -e "^  ${OMR_CPYST_CD}" | wc -l)

  local infl=''
  local refl=''

  [ ${untidy_count} -ne 1 ] && infl='s'
  [ ${untidy_count} -eq 1 ] && refl='s'

  warn "GRIZZLY! We found ${untidy_count} repo${infl} which need${refl} attention."
  notice
  notice "Here's some copy-pasta if you wanna fix it:"
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

  # UNSURE/2019-10-30: Does subprocess mean Ctrl-C won't pass through?
  # I.e., does calling git-clone not in subprocess make mr command faster killable?
  #
  # if false; then
  #   local retco=0
  #   local git_resp
  #   git_resp=$( \
  #     git clone ${GIT_BARE_REPO} -- "${source_repo}" "${target_repo}" 2>&1 \
  #   ) || retco=$?
  # fi

  local retco=0

  local git_respf="$(mktemp --suffix='.ohmyrepos')"

  # 2021-08-16: I'm, like, 100% positive this script always called with
  # `set -e` in effect, but it's a little confusing because errexit is
  # not set *by* this script. So honor whatever it might be.
  # OH, BASH: Piping $SHELLOPTS will always disable errexit. E.g.,
  #           `echo $SHELLOPTS | grep -q "\berrexit\b"` is always false,
  #           because errexit is removed for the echo before the pipe.
  local shell_opts="${SHELLOPTS}"

  # Another Bashism? Variable set to empty string evaluate true:
  #   empty="" && $empty && echo "so true"
  # So being lazy: echoing false if false, else nothing (empty string).
  local restore_errexit=$(echo "${shell_opts}" | grep -q "\berrexit\b" || echo false)

  set +e

  git clone ${GIT_BARE_REPO} -- "${source_repo}" "${target_repo}" >"${git_respf}" 2>&1
  retco=$?

  ${restore_errexit} && set -e

  local git_resp="$(<"${git_respf}")"
  /bin/rm "${git_respf}"

  _git_echo_long_op_finis

  if [ ${retco} -ne 0 ]; then
    travel_process_chores_file_lock_acquire

    warn "Clone failed!"
    warn "  \$ git clone ${GIT_BARE_REPO} -- '${source_repo}' '${target_repo}'"
    warn "  ${git_resp}"
    warn_repo_problem_9char 'uncloned!'

    travel_process_chores_file_lock_release

    return 1
  fi

  DID_CLONE_REPO=1

  travel_process_chores_file_lock_acquire

  info "  $(fg_lightgreen)$(attr_emphasis)✓ cloned🖐$(attr_reset)  " \
    "$(fg_lightgreen)${MR_REPO}$(attr_reset)"

  travel_process_chores_file_lock_release
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

  # Likely $MR_REPO, and likely the cwd.
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
  # Check if SSH remote, i.e., ssh://....
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

# # I don't need this fcn. Reports the tracking branch, (generally 'upstream)
# #   I think, because @{u}. [Not quite sure what that is; *tracking* remote?]
# # WARNING/2020-03-14: (lb): This function not called.
# git_checkedout_remote_branch_name () {
#   # Include the name of the remote, e.g., not just feature/foo,
#   # but origin/feature/foo.
#   local before_cd="$(pwd -L)"
#
#   cd "$1"
#
#   local remote_branch
#   remote_branch=$(git rev-parse --abbrev-ref --symbolic-full-name @{u})
#
#   cd "${before_cd}"
#
#   printf %s "${remote_branch}"
# }

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ #
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_is_bare_repository () {
  [ $(git rev-parse --is-bare-repository) = 'true' ] && return 0 || return 1
}

git_must_be_tidy () {
  # If a bare repository, no working status... so inherently clean, er, negative.
  git_is_bare_repository && return 0 || true

  [ -z "$(git status --porcelain)" ] && return 0 || true

  travel_process_chores_file_lock_acquire

  info "   $(fg_lightorange)$(attr_underline)✗ messy$(attr_reset)   " \
    "$(fg_lightorange)$(attr_underline)${MR_REPO}$(attr_reset)  $(fg_hotpink)✗$(attr_reset)"

  echo \
      "  ${OMR_CPYST_CD} $(fg_lightorange)${MR_REPO}$(attr_reset)" \
      "&& $(fg_lightorange)git my-merge-status$(attr_reset)" \
        >> "${MR_TMP_TRAVEL_CHORES_FILE}"

  travel_process_chores_file_lock_release

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

  if [ ${extcd} -ne 0 ]; then
    # Wire new remote for “${MR_REMOTE}”.

    git remote add ${MR_REMOTE} "${source_repo}"

    DID_SET_REMOTE=1

    _git_echo_long_op_finis

    travel_process_chores_file_lock_acquire

    info "  $(fg_green)$(attr_emphasis)✓ r-wired👈$(attr_reset)" \
      "$(fg_green)${MR_REPO}$(attr_reset)"

    travel_process_chores_file_lock_release
  elif [ "${remote_url}" != "${source_repo}" ]; then
    # Change URL for existing remote.

    git remote set-url ${MR_REMOTE} "${source_repo}"

    DID_SET_REMOTE=1

    _git_echo_long_op_finis

    travel_process_chores_file_lock_acquire

    info "  $(fg_green)$(attr_emphasis)✓ r-wired👆$(attr_reset)" \
      "$(fg_green)${MR_REPO}$(attr_reset)"
    debug "  Reset remote wired for “${MR_REMOTE}”" \
      "(was: $(attr_italic)${remote_url}$(attr_reset))"

    travel_process_chores_file_lock_release
  else
    # Verified “${MR_REMOTE}” URL correct.

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

  travel_process_chores_file_lock_acquire

  verbose "git fetch says:\n${git_resp}"

  # Ignore uninteresting git-fetch messages.
  # - Ignore basic messages, including the "From" line and all
  #   the "... some/branch -> remote/some/branch ..." lines.
  # - Also ignore the auto-packing message, which is purely informative, e.g.,
  #     Auto packing the repository in background for optimum performance.
  #     See "git help gc" for manual housekeeping.
  # - Although mewonders now if using --quiet would be more appropriate...
  #   except then `verbose $git_resp` is not possible. Whatever, it's more
  #   work to filter, but at least we'll find out if there other any other
  #   interesting messages to care about.
  # - Don't worry about the became-dangling message, which is no longer
  #   possible now that the travel repos are all bare.
  #     | grep -v "(refs/remotes/origin/HEAD has become dangling)"
  #
  # - Note that `local` always returns true. So even when `grep -v` returns
  #   nonzero, it won't tickle errexit (so long as within `local` context).
  local culled="$(printf %s "${git_resp}" \
    | grep -v "^Fetching " \
    | grep -v "^From " \
    | grep -v "+\? *[a-f0-9]\{7,8\}\.\{2,3\}[a-f0-9]\{7,8\}.*->.*" \
    | grep -v -P '\* \[new branch\] +.* -> .*' \
    | grep -v -P '\* \[new tag\] +.* -> .*' \
    | grep -v "^ \?- \[deleted\] \+(none) \+-> .*" \
    | grep -v "^Auto packing the repository in background for optimum performance.$" \
    | grep -v '^See "git help gc" for manual housekeeping.$' \
  )"

  if [ -n "${culled}" ]; then
    warn "git fetch wha?\n${culled}"

    if [ ${LOG_LEVEL} -gt ${LOG_LEVEL_VERBOSE} ]; then
      notice "git fetch says:\n${git_resp}"
    fi
  fi

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

  travel_process_chores_file_lock_release

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

    if git_is_bare_repository; then
      git update-ref refs/heads/${source_branch} remotes/${MR_REMOTE}/${source_branch}
      git symbolic-ref HEAD refs/heads/${source_branch}
    else
      local extcd=0
      (git checkout ${source_branch} >/dev/null 2>&1) || extcd=$?

      if [ $extcd -ne 0 ]; then
        # FIXME/2019-10-24: On unpack, this might need/want to be origin/, not travel/
        git checkout --track ${MR_REMOTE}/${source_branch}
      fi
    fi
    DID_BRANCH_CHANGE=1

    _git_echo_long_op_finis

    travel_process_chores_file_lock_acquire

    info "  $(fg_mintgreen)$(attr_emphasis)✓ checkout $(attr_reset)" \
      "$(fg_lightorange)$(attr_underline)${target_branch}$(attr_reset)" \
      "》$(fg_lightorange)$(attr_underline)${source_branch}$(attr_reset)"

    travel_process_chores_file_lock_release
  elif [ "${wasref}" != "${newref}" ]; then
    travel_process_chores_file_lock_acquire

    # FIXME/2020-03-21: Added this elif and info, not sure I want to keep.
    info "  $(fg_mintgreen)$(attr_emphasis)✓ updt-ref $(attr_reset)" \
      "${target_branch}: " \
      "$(fg_lightorange)$(attr_underline)${wasref}$(attr_reset)" \
      "》$(fg_lightorange)$(attr_underline)${newref}$(attr_reset)"

    travel_process_chores_file_lock_release
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

  # Previously, we've changed local branch to match remote HEAD,
  # if necessary, and now we're ready to try local fast-forward.

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

  # ***

  travel_process_chores_file_lock_acquire

  verbose "git merge says:\n${git_resp}"

  travel_process_chores_file_lock_release

  # ***

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
    | grep -v "^fatal: Not possible to fast-forward, aborting.$" \
  )"

  _git_echo_long_op_finis

  if [ -n "${culled}" ]; then
    travel_process_chores_file_lock_acquire

    warn "Unknown git-merge response\n${culled}"
    warn "CHORE: Update source file grep chain if you see this message:"
    warn "  ${OHMYREPOS_LIB}/sync-travel-remote.sh"

    if [ ${LOG_LEVEL} -gt ${LOG_LEVEL_VERBOSE} ]; then
      notice "git merge says:\n${git_resp}"
    fi

    travel_process_chores_file_lock_release
  fi

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

  local changes_txt="$( \
    printf %s "${git_resp}" | grep -P "${pattern_txt}" | eval "${grep_sed_sed}" \
  )"
  local changes_bin="$( \
    printf %s "${git_resp}" | grep -P "${pattern_bin}" | eval "${grep_sed_sed}" \
  )"

  travel_process_chores_file_lock_acquire

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
    print_mergefail_msg "${target_repo}" "${to_commit}" "${git_resp}"
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

  travel_process_chores_file_lock_release

  cd "${before_cd}"

  return ${merge_success}
}

print_mergefail_msg () {
  local target_repo="$1"
  local to_commit="$2"
  local git_resp="$3"

  local local_head_sha="$(shorten_sha "$(git rev-parse HEAD)")"

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
  # KLUGE: Author's Vim syntax highlighter gets confused on escaped backticks,
  #        e.g., warn "foo \`bar\`", so using single quotes.
  warn 'Merge failed! `merge --ff-only '${to_commit}'` says:'
  warn " ${git_resp}"
  # Print CPYST to help user clobber, if that's what they really want.
  warn "$(attr_reset)$(bg_maroon)┌─ HINT ─┐\n┌────────────────────────────┘        └────────┐\n└─── You must resolve the conflicts manually ──┘\n" \
    "First, use git-diff to audit changes between the repos.\n" \
    "Then, decide whether to rebase or to accept the remote.\n" \
    "- If both repos have changes, try rebase:$(bg_forest)\n" \
    "    cd ${target_repo}\n" \
    "    git diff ${local_head_sha}..${to_commit}\n" \
    "    git rebase ${to_commit}$(bg_maroon)\n" \
    "- Otherwise, if the remote is canon, try:$(bg_forest)\n" \
    "    cd ${target_repo}\n" \
    "    git diff ${local_head_sha}..${to_commit}\n" \
    "    git reset --hard ${to_commit}$(bg_maroon)\n" \
    "- If you need to dig any deeper, use tig:\n" \
    "    cd ${target_repo}\n" \
    "    tig ${to_commit}\n" \
    "    tig ${local_head_sha}  # Local HEAD" \
    "$(attr_reset)"

  echo \
    "  ${OMR_CPYST_CD} $(fg_lightorange)${MR_REPO}$(attr_reset)" \
    "&& $(fg_lightorange)git diff ${local_head_sha}..${to_commit}$(attr_reset)" \
      >> "${MR_TMP_TRAVEL_CHORES_FILE}"
  echo \
    "  └─▶ THEN" \
      "$(fg_mintgreen)git rebase ${to_commit}$(attr_reset) OR" \
      "$(fg_mintgreen)git reset --hard ${to_commit}$(attr_reset) OR"\
      "$(fg_mintgreen)< Your choice >$(attr_reset)" \
      >> "${MR_TMP_TRAVEL_CHORES_FILE}"
}

shorten_sha () {
  PW_SHA1SUM_LENGTH=7

  printf "$1" | sed -E 's/^(.{'${PW_SHA1SUM_LENGTH}'}).*/\1/g'
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_fetch_n_cobr () {
  local source_repo="$1"
  local target_repo="$2"
  local source_type="$3"
  local target_type="$4"

  # ***

  must_be_git_dirs "${source_repo}" "${target_repo}" "${source_type}" "${target_type}"
  [ $? -ne 0 ] && return $? || true  # Obviously unreacheable if caller used `set -e`.

  # ***

  local before_cd="$(pwd -L)"
  cd "${target_repo}"  # (lb): Probably $MR_REPO, which is already cwd.

  local extcd=0
  git_must_be_tidy || extcd=$?

  if [ ${extcd} -ne 0 ]; then
    cd "${before_cd}"

    exit ${extcd}
  fi

  # 2018-03-22: Set a remote to the sync device. There's always only 1,
  # apparently. I think this'll work well.
  git_set_remote_travel "${source_repo}"
  git_fetch_remote_travel "${target_repo}" "${target_type}"

  # ***

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

# 2023-04-30: Let user specify different /user/home on remote,
# i.e., sync two hosts with different usernames.
# - Alternatively: Symlink /home/host1_user -> /home/host2_user on @host2,
#                      and /home/host2_user -> /home/host1_user on @host1.
#               Or perhaps /Users/macos_user -> /home/linux_user on @linux,
#                      and /home/linux_user -> /Users/macos_user on @macOS,
#   - But adding symlink requires root privileges, among other concerns,
#     so prefer MR_REMOTE_HOME.
repo_path_for_remote_user () {
  local local_repo="$1"

  if [ -z "${MR_REMOTE_HOME}" ]; then
    printf "%s" "${local_repo}"
  else
    printf "%s" "${local_repo}" | sed -E "s#^${HOME}(/|$)#${MR_REMOTE_HOME}\1#"
  fi
}

# The `mr ffssh` action.
git_merge_ffonly_ssh_mirror () {
  set -e

  reveal_biz_vars

  git_merge_check_env_remote
  git_merge_check_env_repo
  MR_FETCH_HOST=${MR_FETCH_HOST:-${MR_REMOTE}}
  local rem_repo="$(repo_path_for_remote_user "${MR_REPO}")"
  local rel_repo="$(lchop_sep "${rem_repo}")"
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
  #   local dev_path=$(realpath -m -- "${MR_TRAVEL}/${MR_REPO}")
  local git_name='_0.git'
  local dev_path=$(realpath -m -- "${MR_TRAVEL}/${MR_REPO}/${git_name}")

  printf %s "${dev_path}"
}

# The `mr travel` action.
git_update_device_fetch_from_local () {
  set -e

  reveal_biz_vars

  MR_REMOTE=${MR_REMOTE:-$(hostname)}

  local dev_path
  git_update_ensure_ready
  dev_path=$(git_update_dev_path)
  git_pack_travel_device "${MR_REPO}" "${dev_path}"
}

# The `mr unpack` action.
git_update_local_fetch_from_device () {
  set -e

  reveal_biz_vars

  git_merge_check_env_remote
  git_update_ensure_ready

  local dev_path
  dev_path=$(git_update_dev_path)

  git_fetch_n_cobr_n_merge "${dev_path}" "${MR_REPO}" 'travel' 'local'
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# When `mr` starts, the `lib = . sync-travel-remote.sh` statement
# (from `lib/sync-travel-remote`) is run by the main `mr` process.
# - The main process sources this file (because `lib`), and then
#   it calls the setup function (`git_travel_cache_setup`).
# - Then a new process is started for each MR_REPO (whether multi-
#   processing or not, it's always a new subprocess). Each of these
#   MR_REPO processes calls the action fcn.
#   (e.g., git_merge_ffonly_ssh_mirror).
# - Next, two other processes run, and they each source this file
#   (unrelated to the action fcn; the author has not investigated
#   `mr` to know what the two additional processes are doing).
#   - After these two processes run, the next MR_REPO process is
#     created, and the sequence repeats.
#
# Observations of previous behavior:
# - When multiprocessing (e.g., `mr -j 2`):
#   - The startup process calls `main` and then `git_travel_cache_setup`.
#   - Then the startup process forks a new process for each MR_REPO.
#     - The new process calls the action function (e.g.,
#       git_merge_ffonly_ssh_mirror).
#     - Then another new process runs, which sources this file as a
#       side-effect (because of the `lib = . sync-travel-remote.sh`)
#       [that the author did not investigate further; i.e., I don't
#       know what this process is doing].
#     - Finally, the first MR_REPO process (that called the action
#       function) sources this file (because the `lib = .` source
#       command doesn't run until after the action function? Dunno).
#       - So obviously the MR_REPO process inherits the original
#         process's environment, because it calls the action function
#         before sourcing this file.
#       - However, when not multiprocessing (e.g., `mr -j 1`), the author
#         sees 3 distinct PIDs for each MR_REPO process. So either `mr`
#         is doing something different, or maybe when multiprocessing,
#         the same PID is being reused, and it only looks like the same
#         process is making the first and third call to this file...
#         (so the action function runs in one process without sourcing
#         this file, and then two other distinct processes run which
#         incidentally source this file).
#   - After processing all MR_REPO repos, a final process calls
#     git_travel_cache_teardown.
# - When not multiprocessing (e.g., `mr -j 1`), something odd occurs:
#   - MR_REPO *is* set when the teardown function is called.
#     - It appears that the child process that runs the last action
#       command is the same process that calls the teardown function.
#     - This smells, as captured in comment in git_travel_cache_teardown.
#   - Kludge: As a work-around, the teardown function also calls this
#     setup function (see: sync_travel_remote_setup).

# Shared setup function: source dependencies, and set file VARS.

sync_travel_remote_setup () {
  _travel_source_deps

  reveal_biz_vars
}

main () {
  # Bail if MR_REPO set, because its action has already run.
  # - See previous long comment about how `mr` forks processes.
  # - It actually doesn't matter if the setup function runs, but
  #   bailing here illustrates our understanding (as outlined in
  #   the long comment above) of how `mr` processes work (or this
  #   will fail and prove us wrong).
  [ -z "${MR_REPO}" ] || return 0

  sync_travel_remote_setup
}

main "$@"

