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

# SAVVY/2023-05-01: If `ffssh` processes appear stuck and spike the CPU,
# likely the locking mechanism coded incorrectly.
#
# - Kill all `mr` processes:
#
#       pkill -9 -f "mr config"
#
# - Then look for proper
#     travel_process_chores_file_lock_acquire
#   and
#     travel_process_chores_file_lock_release
#   usage.

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

MR_APP_NAME='mr'

GIT_BARE_REPO='--bare'

# Required environ(s) for `ffssh`:
#
#   MR_REMOTE
#
# Optional environs for `ffssh`:
#
#   MR_REMOTE_HOME=${MR_REMOTE_HOME}
#
# Environs used from `mr`:
#
#   MR_ACTION
#   MR_HOME
#   MR_SWITCHES

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

_travel_source_deps () {
  # Load the logger library, from github.com/landonb/sh-logger.
  # - Includes print commands: info, warn, error, debug.
  . logger.sh
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

_travel_reveal_biz_vars () {
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
  MR_TMP_TRAVEL_HINT_FILE_BASE="/tmp/gitsmart-ohmyrepos-travel-hint"
  MR_TMP_TRAVEL_HINT_FILE="${MR_TMP_TRAVEL_HINT_FILE_BASE}-${mrpid}"
  # 2023-04-29: Stash mergefail copy-paste and print final list of chores.
  # - git-my-merge-status has had a similar feature for a few years.
  MR_TMP_TRAVEL_CHORES_FILE_BASE="/tmp/gitsmart-ohmyrepos-travel-chores"
  MR_TMP_TRAVEL_CHORES_FILE="${MR_TMP_TRAVEL_CHORES_FILE_BASE}-${mrpid}"

  # The actions use a mkdir mutex to gait access to the terminal and
  # to the tmp files. (The author was unable to cause interleaving
  # terminal output (even across multiple echoes). But it was easy (~50%
  # of the time) to cause tmp file to be clobbered when not locking).

  # Gait access to terminal and chores file output, to support multi-process (mr -j).
  MR_TMP_TRAVEL_LOCK_DIR_BASE="/tmp/gitsmart-ohmyrepos-travel-lock"
  MR_TMP_TRAVEL_LOCK_DIR="${MR_TMP_TRAVEL_LOCK_DIR_BASE}-${mrpid}"

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
    if $(mkdir -- "${MR_TMP_TRAVEL_LOCK_DIR}" 2> /dev/null); then

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

  rmdir -- "${MR_TMP_TRAVEL_LOCK_DIR}"
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

  if [ ! -d "${repo_path}" ]; then
    dir_okay=1

    info "No repo found: $(bg_maroon)$(attr_bold)${repo_path}$(attr_reset)"

    if [ "${repo_type}" = 'travel' ]; then
      touch -- "${MR_TMP_TRAVEL_HINT_FILE}"
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

git_travel_verify_mr_action () {
  # The action name is the variable name from lib/sync-travel-remote.
  # - Older `mr` doesn't specify MR_ACTION, in which case must always
  #   run on any command (hence the empty string check).
  false \
    || [ "${MR_ACTION}" = '' ] \
    || [ "${MR_ACTION}" = 'ffmirror' ] \
    || [ "${MR_ACTION}" = 'ffssh' ] \
    || [ "${MR_ACTION}" = 'ffdefault' ]
}

git_travel_cache_setup () {
  # BWARE/2023-05-01: `mr` leaves MR_ACTION unset on setup and teardown.
  # - Author will try to merge this upstream, we'll see.
  # - In the meantime, just know that every setup and every teardown runs
  #   for every action (so play nice).
  # - CXREF: See longer comment in `git_status_cache_setup`.
  git_travel_verify_mr_action || return 0

  # Crap out if MR_REMOTE unreachable.
  test_ssh_or_kill_ssh

  # Cleanup old temp files, possibly orphaned if user Ctrl-c's an action.
  # (Mostly being tidy — OS clears temp files every reboot — but there's
  #  also the (slim) possibility a PID gets reused that clashes with an
  #  old PID, and then the user sees old hints or chores. Or more importantly,
  #  the action cannot obtain the lock because an old lock dir was orphaned).

  command rm -f -- "${MR_TMP_TRAVEL_HINT_FILE_BASE}-"*
  command rm -f -- "${MR_TMP_TRAVEL_CHORES_FILE_BASE}-"*

  rmdir -- "${MR_TMP_TRAVEL_LOCK_DIR_BASE}-"* 2> /dev/null || true
}

git_travel_cache_teardown () {
  git_travel_verify_mr_action || return 0

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

# ***

test_ssh_or_kill_ssh () {
  [ "${MR_ACTION}" = 'ffssh' ] || return

  # BWARE/2023-05-01: Currently, `mr` doesn't set MR_ACTION on setup or teardown.
  # - The author's own repo fixes this, but if you are running stock `mr`,
  #   the following check never runs.
  #   - Instead, all the MR_REPO subprocesses will run, and their git-fetch
  #     checks will see the error.
  #     - Meaning, you'll see the same error for every repo.
  #   - This function, on the other hand, does the check on startup instead,
  #     and if MR_REMOTE is unreachable, it'll kill `mr`, so you'll only see
  #     the error once, and none of the MR_REPO subprocesses will run.

  if [ -n "${MR_REMOTE}" ]; then
    if ! test_ssh; then
      >&2 echo "ERROR: SSH test failed on MR_REMOTE: “${MR_REMOTE}”"
      >&2 echo "- Unable to connect to remote host."
      >&2 echo "- Is the remote host online? Is MR_REMOTE correct?"

      kill_mr
    fi
  else
    >&2 echo "ERROR: Missing MR_REMOTE"
    >&2 echo "- Please try again, e.g.:"
    >&2 echo "    MR_REMOTE=<some-host> mr -d / ffssh"

    kill_mr
  fi
}

test_ssh () {
  ssh -q -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=1 "${MR_REMOTE}" 'exit 0'
}

kill_mr () {
  >&2 echo
  >&2 echo "Killing \`mr\` because you got work to do"
  >&2 echo "  🥩 🥩 chop chop"
  >&2 echo

  # Cannot redirect stderr to suppress "Killed" message,
  # which is redundant to what we just said, or perhaps
  # we just said it so the user knows what was "Killed".
  # (I checked StackOverflow and there doesn't seem to
  #  be a way, not even `exec 2>/dev/null`, deal w/ it).
  kill -s 9 $(mr_process_id)

  # Note that this process continues to run.
}

# ***

git_travel_process_hint_file () {
  [ -e "${MR_TMP_TRAVEL_HINT_FILE}" ] || return 0

  info
  warn "One or more errors suggest that you need to setup the travel device."
  info
  info "You can setup the travel device easily by running:"
  info
  info "  $(fg_lightorange)MR_TRAVEL=${MR_TRAVEL} ${MR_APP_NAME} travel$(attr_reset)"

  command rm -- "${MR_TMP_TRAVEL_HINT_FILE}"
}

git_travel_process_chores_file () {
  [ -e "${MR_TMP_TRAVEL_CHORES_FILE}" ] || return 0

  git_travel_process_chores_notify
  echo
  cat "${MR_TMP_TRAVEL_CHORES_FILE}"
  if [ -n "$(tail -1 "${MR_TMP_TRAVEL_CHORES_FILE}")" ]; then
    echo
  fi

  command rm -- "${MR_TMP_TRAVEL_CHORES_FILE}"
}

# COPYD/2023-04-29: MAYBE: DRY this: Copied from git-my-merge-status.sh.
git_travel_process_chores_notify () {
  # Note that some hints are multiple lines, but all hints' first line
  # starts with the cd command, e.g., "  cd /path/to/repo && ...".
  local untidy_count=$( \
    cat "${MR_TMP_TRAVEL_CHORES_FILE}" \
      | grep \
        -e "^  ${OMR_CPYST_CD}" \
        -e "MR_REMOTE=<fixme>" \
        -e "ssh ${MR_REMOTE} " \
      | wc -l \
  )

  local infl=''
  local refl=''

  [ ${untidy_count} -ne 1 ] && infl='s'
  [ ${untidy_count} -eq 1 ] && refl='s'

  warn "GRIZZLY! We found ${untidy_count} repo${infl} which need${refl} attention."
  notice
  notice "Here's some copy-pasta to help you get started:"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ #
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

travel_ops_reset_stats () {
  DID_CLONE_REPO=0
  DID_SET_REMOTE=0
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
  command rm -- "${git_respf}"

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

  local before_cd="$(pwd -L)"

  # Likely $MR_REPO, and likely the cwd.
  cd "${target_repo}"

  local branch_name
  branch_name=$( \
    git remote show ${MR_REMOTE} |
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
    # If detached HEAD (b/c git submodule, or other), remote-show shows "(unknown)".
    source_branch=$(git_checkedout_branch_name_remote "${target_repo}")
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

  info "   $(fg_lightorange)$(attr_underline)✗ messy$(attr_reset)   " \
    "$(fg_lightorange)$(attr_underline)${MR_REPO}$(attr_reset)  $(fg_hotpink)✗$(attr_reset)"

  # ***

  travel_process_chores_file_lock_acquire

  echo \
      "  ${OMR_CPYST_CD} $(fg_lightorange)${MR_REPO}$(attr_reset)" \
      "&& $(fg_lightorange)git my-merge-status$(attr_reset)" \
        >> "${MR_TMP_TRAVEL_CHORES_FILE}"

  travel_process_chores_file_lock_release

  # ***

  # Exit using errexit.
  false
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

  local git_remote_cmd=""
  if [ ${extcd} -ne 0 ]; then
    # Wire new remote for “${MR_REMOTE}”.
    git_remote_cmd="add"
  elif [ "${remote_url}" != "${source_repo}" ]; then
    # Change URL for existing remote.
    git_remote_cmd="set-url"
  else
    # Verified “${MR_REMOTE}” URL correct.
    : # no-op

    _git_echo_long_op_finis
  fi

  if [ -n "${git_remote_cmd}" ]; then
    git remote ${git_remote_cmd} ${MR_REMOTE} "${source_repo}"

    DID_SET_REMOTE=1

    _git_echo_long_op_finis

    info "  $(fg_green)$(attr_emphasis)✓ r-wired👆$(attr_reset)" \
      "$(fg_green)${MR_REPO}$(attr_reset)"
    if [ "${git_remote_cmd}" = "set-url" ]; then
      debug "  Reset remote wired for “${MR_REMOTE}”" \
        "(was: $(attr_italic)${remote_url}$(attr_reset))"
    fi
  fi

  cd "${before_cd}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_fetch_remote_travel () {
  local target_repo="${1:-$(pwd -L)}"
  # Instead of $(pwd), could use environ:
  #   local target_repo="${1:-${MR_REPO}}"
  local target_type="$2"
  local source_repo="$3"
  local rel_repo="$4"

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

  # Check that the remote URL is reachable.
  # - We could call `git ls-remote "${MR_REMOTE}/${source_repo}"`
  #   to check remote, but we want to call git-fetch anyway, so we
  #   parse latter's output to see if URL was valid of not.
  local remote_name_invalid=false
  local remote_path_invalid=false

  if printf %s "${git_resp}" \
    | grep -q -e "^ssh: Could not resolve hostname ${MR_REMOTE}: Name or service not known\s*$" \
  ; then
    # Invalid remote.
    remote_name_invalid=true
  elif printf %s "${git_resp}" \
    | grep -q -e "^fatal: '\([^']*\)' does not appear to be a git repository$" \
  ; then
    # Valid remote, invalid path.
    remote_path_invalid=true
  fi

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
    \
    | grep -v "^fatal: '\([^']*\)' does not appear to be a git repository$" \
    | grep -v '^fatal: Could not read from remote repository.$' \
    | grep -v '^Please make sure you have the correct access rights$' \
    | grep -v '^and the repository exists.$' \
    \
    | grep -v "^ssh: Could not resolve hostname ${MR_REMOTE}: Name or service not known\s*$" \
    | grep -v '^fatal: Could not read from remote repository.$' \
    | grep -v '^Please make sure you have the correct access rights$' \
    | grep -v '^and the repository exists.$' \
  )"

  if [ -n "${culled}" ]; then
    warn "Unrecognized git-fetch text spotted:\n${culled}"
    warn "CHORE: Update source file grep chain if you see this message."
    warn "- Edit:"
    warn "  ${OHMYREPOS_LIB}/sync-travel-remote.sh"

    if [ ${LOG_LEVEL} -gt ${LOG_LEVEL_VERBOSE} ]; then
      notice "- Full git fetch output:\n${git_resp}"
    fi
  fi

  if ${remote_name_invalid} || ${remote_path_invalid}; then
    print_fatchfail_msg "${target_repo}" "${source_repo}" "${rel_repo}" \
      ${remote_name_invalid} ${remote_path_invalid}

    if ${remote_name_invalid}; then
      git remote remove "${MR_REMOTE}"
    fi

    false  # errexit's
  elif [ ${fetch_success} -ne 0 ]; then
    # Trigger errexit with `fatal`'s `return 1`.
    # - Note this might be the 3rd time we print the git-fetch response.

    travel_process_chores_file_lock_acquire
    echo \
      "  ${OMR_CPYST_CD} $(fg_lightorange)${MR_REPO}$(attr_reset)" \
      "&& $(fg_lightorange)git fetch ${MR_REMOTE}$(attr_reset)" \
        >> "${MR_TMP_TRAVEL_CHORES_FILE}"
    travel_process_chores_file_lock_release

    fatal "Unexpected fetch failure!\n${git_resp}"
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

print_fatchfail_msg () {
  local target_repo="$1"
  local source_repo="$2"
  local rel_repo="$3"
  local remote_name_invalid="$4"
  local remote_path_invalid="$5"

  local hintful_msg=""
  if ${remote_name_invalid}; then
    hintful_msg="$(echo \
      "The remote host is unreachable: “${MR_REMOTE}”\n" \
      "- The full URL is: $(git remote get-url ${MR_REMOTE})\n" \
      "- Use $(bg_orange)MR_REMOTE$(bg_maroon) to specify a different remote name, e.g.,$(bg_forest)\n" \
      "    MR_REMOTE=<remote> mr ...$(bg_maroon)\n" \
      "- If you need to remove the errant remotes, try:$(bg_forest)\n" \
      "    mr -d / run git remote remove ${MR_REMOTE}$(attr_reset)" \
    )"
  elif ${remote_path_invalid}; then
    hintful_msg="$(echo \
      "It's likely the path is incorrect: “/${rel_repo}”\n" \
      "- The full URL is: $(git remote get-url ${MR_REMOTE})\n" \
      "- Use $(bg_orange)MR_REMOTE_HOME$(bg_maroon) to specify a custom home path substitution, e.g.,$(bg_forest)\n" \
      "    MR_REMOTE=${MR_REMOTE} MR_REMOTE_HOME=/home/<remote-user> mr ...$(bg_maroon)\n" \
      "- If that's not the solution, your remotes might not be mirrored (don't share a common path)$(attr_reset)" \
    )"
  else
    # Unreachable.
    hintful_msg="$(echo \
      "There's a bug in the code — this message should be unreachable.\n" \
      "- Inspect and fix the source:\n" \
      "  ${OHMYREPOS_LIB}/sync-travel-remote.sh$(attr_reset)" \
    )"
  fi

  info "  $(fg_lightorange)$(attr_underline)fetchfail$(attr_reset)  " \
    "$(fg_lightorange)$(attr_underline)${MR_REPO}$(attr_reset)  $(fg_hotpink)✗$(attr_reset)"

  # Print CPYST to help user fix the issue.
  warn "$(attr_reset)$(bg_maroon)┌─ HINT ─┐\n┌────────────────────────────┘        └─────┐\n└─── You must resolve this issue manually ──┘\n${hintful_msg}"

  # ***

  travel_process_chores_file_lock_acquire

  # If MR_REMOTE is unreachable, then all subprocesses will fail on the
  # same concern.
  # - Ideally, we'd bail now, but there's no mechanism.
  #   - We could `kill -s 9 $(mr_process_id)`, but `mr` captures this
  #     action's output before displaying it, so killing `mr` means
  #     nothing this action output will be printed.
  if ${remote_name_invalid}; then
    echo \
      "  $(fg_lightorange)MR_REMOTE=<fixme>$(attr_reset) mr -d $(fg_lightorange)${MR_REPO}$(attr_reset) -n ffssh" \
        >> "${MR_TMP_TRAVEL_CHORES_FILE}"
  elif ${remote_path_invalid}; then
    # On the other hand, if it's the path that's incorrect, then it's
    # likely a MR_REMOTE_HOME issue, and it's likely to affect all
    # repos under user's home. But we don't know that all repos are
    # stored under user's home, so some repo tasks might succeed.
    echo \
      "  ${OMR_CPYST_CD} $(fg_lightorange)${MR_REPO}$(attr_reset)" \
      "&& $(fg_lightorange)git remote get-url ${MR_REMOTE}$(attr_reset)" \
        >> "${MR_TMP_TRAVEL_CHORES_FILE}"
  fi

  travel_process_chores_file_lock_release
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

  # ***

  local to_commit
  # Detached HEAD either "HEAD" (--abbrev-ref) or "(unknown)" (remote show).
  if [ "${source_branch}" = "HEAD" ] || [ "${source_branch}" = "(unknown)" ]; then
    debug "  $(fg_mediumgrey)skip-HEAD$(attr_reset)  " \
      "$(fg_mediumgrey)${target_repo}$(attr_reset)"

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

  # ***

  # Cannot fast-forward merge if HEAD not at or behind remote.
  # - If that's the case, the local repo could be ahead of the
  #   remote repo (a happy state), or the repos have diverged
  #   (and the user will want to resolve the conflict).
  if git merge-base --is-ancestor "HEAD" "${to_commit}"; then
    _synctrem_git_merge_ff_only_safe "${target_repo}" "${to_commit}"
  elif git merge-base --is-ancestor "${to_commit}" "HEAD"; then
    # Local ahead of remote.
    print_mergefail_msg_localahead "${target_repo}"

    false
  else
    # Diverged.
    print_mergefail_msg_diverged "${target_repo}" "${to_commit}" ""

    false
  fi
}

_synctrem_git_merge_ff_only_safe () {
  local target_repo="$1"
  local to_commit="$2"

  local before_cd="$(pwd -L)"
  cd "${target_repo}"

  _git_echo_long_op_start 'mergerin’'

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
  local merge_retcode=${extcd}

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

  verbose "git merge says:\n${git_resp}"

  # ***

  # NOTE: The checking-out-files line looks like this would work:
  #         | grep -P -v "^Checking out files: 100% \(\d+/\d+\), done.$" \
  #       but it doesn't, I think because the "100%" was updated live,
  #       so there are other digits and then backspaces, I'd guess.
  #       Though this doesn't work:
  #         | grep -P -v "^Checking out files: [\d\b]+" \
  # OMITD: If you git-merge an unknown host URL, e.g., @host exists,
  #        but ssh://host/this/path/does/not/exist does not,
  #        git-merge says:
  #          merge: host/ - not something we can merge
  #        but don't make a rule for that text: git-fetch fails first.
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
    # OMITD: See note above:
    #  | grep -v "^merge: [-a-z0-9]+/ - not something we can merge$"
  )"

  _git_echo_long_op_finis

  if [ -n "${culled}" ]; then
    warn "Unrecognized git-merge text spotted:\n${culled}"
    warn "CHORE: Update source file grep chain if you see this message."
    warn "- Edit:"
    warn "  ${OHMYREPOS_LIB}/sync-travel-remote.sh"

    if [ ${LOG_LEVEL} -gt ${LOG_LEVEL_VERBOSE} ]; then
      notice "- Full git merge output:\n${git_resp}"
    fi
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
  if [ ${merge_retcode} -ne 0 ]; then
    print_mergefail_msg_diverged "${target_repo}" "${to_commit}" "${git_resp}"
  elif (printf %s "${git_resp}" | grep '^Already up to date.$' >/dev/null); then
    debug "  $(fg_mediumgrey)up-2-date$(attr_reset)  " \
      "$(fg_mediumgrey)${MR_REPO}$(attr_reset)"
  elif [ -z "${changes_txt}" ] && [ -z "${changes_bin}" ]; then
    # A warning, so you can update the grep above and recognize this output.
    warn "  $(fg_mintgreen)$(attr_emphasis)!familiar$(attr_reset)  " \
      "$(fg_mintgreen)${MR_REPO}$(attr_reset)"
  # else, ${merge_retcode} is 0/true, and either/or changes_txt/_bin,
  # and we've already printed multiple info statements, nothing more
  # to say.
  fi

  cd "${before_cd}"

  return ${merge_retcode}
}

print_mergefail_msg_diverged () {
  local target_repo="$1"
  local to_commit="$2"
  local git_resp="$3"

  local local_head_sha="$(shorten_sha "$(git rev-parse HEAD)")"

  local common_ancestor_sha="$(shorten_sha "$(git merge-base HEAD ${to_commit})")"

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
  if [ -n "${git_resp}" ]; then
    warn 'Merge failed! `merge --ff-only '${to_commit}'` says:'
    warn " ${git_resp}"
  fi
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
    "    tig ${local_head_sha}  # Local HEAD\n" \
    "- The common ancestor is: ${common_ancestor_sha}" \
    "$(attr_reset)"

  # ***

  travel_process_chores_file_lock_acquire

  # Add empties before and after multiple chore lines for the same repo,
  # to make easier for user to track which chore they're on.
  if [ -e "${MR_TMP_TRAVEL_CHORES_FILE}" ] \
    && [ -n "$(tail -1 "${MR_TMP_TRAVEL_CHORES_FILE}")" ] \
  ; then
    echo >> "${MR_TMP_TRAVEL_CHORES_FILE}"
  fi
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
  echo >> "${MR_TMP_TRAVEL_CHORES_FILE}"

  travel_process_chores_file_lock_release
}

shorten_sha () {
  PW_SHA1SUM_LENGTH=7

  printf "$1" | sed -E 's/^(.{'${PW_SHA1SUM_LENGTH}'}).*/\1/g'
}

# Local ahead of remote, which seems like something user might care to know,
# so using 'warn', not 'info', and caller fails the action for this repo.
# - Because normally users run `ff` to pull changes to a host they expect
#   to be behind. So this alert means user may want to run `ff` on the
#   remote host they were pulling from.
print_mergefail_msg_localahead () {
  local target_repo="$1"

  warn "  $(fg_lightorange)$(attr_underline)✗ local-ahead❗$(attr_reset)  " \
    "$(fg_lightorange)$(attr_underline)${target_repo}$(attr_reset)"

  local rem_repo="$(repo_path_for_remote_user "${MR_REPO}")"
  local mr_repo="$(repo_path_for_remote_user "$(command -v mr)")"

  echo \
    "  $(fg_lightorange)ssh ${MR_REMOTE}" \
    "'cd ${rem_repo} && MR_REMOTE=$(hostname) ${mr_repo} -d . -n ffssh'$(attr_reset)" \
      >> "${MR_TMP_TRAVEL_CHORES_FILE}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_fetch_n_cobr () {
  local source_repo="$1"
  local target_repo="$2"
  local source_type="$3"
  local target_type="$4"
  local rel_repo="$5"

  # ***

  must_be_git_dirs "${source_repo}" "${target_repo}" "${source_type}" "${target_type}"
  [ $? -ne 0 ] && return $? || true  # Obviously unreacheable if caller used `set -e`.

  # ***

  local before_cd="$(pwd -L)"
  cd "${target_repo}"  # (lb): Probably $MR_REPO, which is already cwd.

  git_must_be_tidy

  # ***

  # 2018-03-22: Set a remote to the sync device. There's always only 1,
  # apparently. I think this'll work well.
  git_set_remote_travel "${source_repo}"
  git_fetch_remote_travel "${target_repo}" "${target_type}" "${source_repo}" "${rel_repo}"

  # ***

  local source_branch
  source_branch=$(git_source_branch_deduce "${source_repo}" "${target_repo}")
  # Set caller's variable.
  MR_ACTIVE_BRANCH="${source_branch}"

  # ***

  local target_branch
  target_branch=$(git_checkedout_branch_name_direct "${target_repo}")

  # Because `cd` above, do not need to pass "${target_repo}" (on $3).
  git_change_branches_if_necessary "${source_branch}" "${target_branch}"

  # ***

  cd "${before_cd}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_fetch_n_cobr_n_merge () {
  local source_repo="$1"
  local target_repo="$2"
  local source_type="$3"
  local target_type="$4"
  local rel_repo="$5"

  travel_ops_reset_stats

  local MR_ACTIVE_BRANCH
  # Insist local repo tidy; set remote; fetch remote; change local branch.
  git_fetch_n_cobr "${source_repo}" "${target_repo}" "${source_type}" "${target_type}" "${rel_repo}"

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
    # KLUGE/2023-05-17: Another Shell filetype highlight bug: The backslash↑  "
  fi
}

# The `mr ffssh` action.
git_merge_ffonly_ssh_mirror () {
  set -e

  _travel_reveal_biz_vars

  git_merge_check_env_remote
  git_merge_check_env_repo
  MR_FETCH_HOST=${MR_FETCH_HOST:-${MR_REMOTE}}
  local rem_repo="$(repo_path_for_remote_user "${MR_REPO}")"
  local rel_repo="$(lchop_sep "${rem_repo}")"
  local ssh_path="ssh://${MR_FETCH_HOST}/${rel_repo}"
  git_fetch_n_cobr_n_merge "${ssh_path}" "${MR_REPO}" 'ssh' 'local' "${rel_repo}"
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

  _travel_reveal_biz_vars

  MR_REMOTE=${MR_REMOTE:-$(hostname)}

  local dev_path
  git_update_ensure_ready
  dev_path=$(git_update_dev_path)
  git_pack_travel_device "${MR_REPO}" "${dev_path}"
}

# The `mr unpack` action.
git_update_local_fetch_from_device () {
  set -e

  _travel_reveal_biz_vars

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

  _travel_reveal_biz_vars
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
unset -f _travel_source_deps

