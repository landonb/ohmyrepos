# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

source_deps () {
  # Note .mrconfig-omr sets PATH so deps found in OMR's deps/.

  # Load the log library, which includes `warn`, etc.
  # - As a side-effect, this also loads the stream-injectable
  #   color/style library, colors.sh.
  # - And, because this file is the first `include` from this
  #   project's .mrconfig-omr, the libraries sourced here will
  #   be available to all the other ohmyrepos/lib/*.sh scripts.
  # - Lastly, the .mrconfig-omr file sets, e.g., `lib = PATH=...`
  #   which enables the path-less source logger.sh here to work.
  # Load the logger library, from github.com/landonb/sh-logger.
  . logger.sh

  # Load `print_nanos_now`.
  . print-nanos-now.sh
}

reveal_biz_vars () {
  # (lb): Because myrepos uses subprocesses, we cannot share values
  # using environment variables. So we use a temporary file instead.
  # And we use the parent process ID so `mr` can run in parallel.
  OMR_RUNTIME_TEMPFILE_BASE="/tmp/gitsmart-ohmyrepos-all-cmds-timing-"
  OMR_RUNTIME_TEMPFILE="${OMR_RUNTIME_TEMPFILE_BASE}-${PPID}"

  # YOU: Set this to minimum threshold for elapsed time to be displayed.
  # - Default: 0 secs., i.e., always show the action runtime (which is just
  #   a short value in paranetheses before the normal `mr` status report).
  OMR_RUNTIME_MIN_SECS=${OMR_RUNTIME_MIN_SECS:-0}

  # YOU: Set this to the command to use in the copy-paste lines,
  #      e.g., maybe you'd prefer 'pushd' instead.
  # - 2023-04-29: Back. compat.: OMR_MYSTATUS_SNIP_CD is previous name.
  OMR_CPYST_CD="${OMR_CPYST_CD:-${OMR_MYSTATUS_SNIP_CD:-cd}}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

python_prettify_elapsed () {
  local seconds="${1:-0}"

  # This spits to stderr if user does not have package installed.
  /usr/bin/env python -c \
    "from pedantic_timedelta import PedanticTimedelta; \
     pdtd = PedanticTimedelta(seconds=${seconds}); \
     print(pdtd.time_format_scaled(field_width=1, precision=1, abbreviate=2)[0]);" \
     2> /dev/null
}

simple_bc_elapsed () {
  local seconds="${1:-0}"

  echo "$(echo "scale=1; ${seconds} * 100 / 100" | bc -l) secs."
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_any_action_started () {
  # DEBUG: Uncomment to trace setup and teardown calls:
  #
  #  _trace_ps_heritage "STAND-UP"

  remove_old_temp_files

  print_nanos_now > "${OMR_RUNTIME_TEMPFILE}"
}

git_any_action_stopped () {
  # DEBUG: Uncomment to trace setup and teardown calls:
  #
  #  _trace_ps_heritage "TEARDOWN"

  local setup_time_0
  setup_time_0="$(cat "${OMR_RUNTIME_TEMPFILE}")"

  if [ -z "${setup_time_0}" ]; then
    # Unreachable.
    >&2 error "ERROR: Missing start time: Is \`git_any_cache_setup\` working?"
  fi

  local setup_time_n="$(print_nanos_now)"

  local seconds=$(echo "${setup_time_n} - ${setup_time_0}" | bc -l)

  if [ $(echo "${seconds} >= ${OMR_RUNTIME_MIN_SECS}" | bc -l) -ne 0 ]; then
    local time_elapsed="$(python_prettify_elapsed "${seconds}")"

    [ -z "${time_elapsed}" ] \
      && time_elapsed="$(simple_bc_elapsed "${seconds}")"

    printf %s "$(attr_emphasis)(${time_elapsed})$(attr_reset) "
  fi

  # User can call `mr` from an `mr` action, so only remove the file
  # associated with the current process, because there might be
  # multiple runtime temp files in use.
  command rm -- "${OMR_RUNTIME_TEMPFILE}"
}

# ***

# Cleanup old temp files abandoned on previous runs.
# - This scenario happens when uses <Ctrl-c>'s an `mr` command.
# - Note there's no way to use `trap` effectively, because `mr`
#   calls `setup_dispatch_append` and `teardown_dispatch_append`
#   in separate processes.
#   - So we cannot just set a trap when the temp file is created.
# - But we can infer when `mr` runs us for the first time:
#   - The very first time `mr` calls `setup_dispatch_append`,
#     and the last time it calls `teardown_dispatch_append`,
#     it does so with the user's shell as its parent process.
#   - In all cases, this process is a `sh -c` command, and
#     the parent is `perl mr`.
#     - Except on the first call, the grandparent is another
#       `sh -c` command.
#       - But on the first call, the g/p is the user's shell.
# - Note this means there might always be one stray temp file
#   that won't get cleaned up until user runs OMR again (or
#   logsout).
remove_old_temp_files () {
  # E.g.,
  #   if [ "/home/user/.local/bin/bash" = "$( \
  #     ps -ocommand= -p $(ps -o ppid= ${PPID} | tr -d ' ')
  #   )" ]; then
  if ps -ocommand= -p $(ps -o ppid= ${PPID} | tr -d ' ') \
    | grep -q -E '(^-?|\/)(ba|da|fi|z)?sh$' - \
  ; then
    # DEBUG: Uncomment to trace setup and teardown calls:
    #
    #  _trace_ps_heritage "CLEAN-UP"

    command rm -f -- "${OMR_RUNTIME_TEMPFILE_BASE}"*
  fi
}

# DEBUG: You can uncomment calls to this function to see what's going on.
_trace_ps_heritage () {
  >&2 echo "$1: $$ / $PPID / $(ps -o ppid= ${PPID} | tr -d ' ')"

  # Print the command namesa:
  ps -ocommand= -p $$ | head -c 40 >&2
  ps -ocommand= -p $PPID | head -c 40 >&2
  ps -ocommand= -p $(ps -o ppid= ${PPID} | tr -d ' ') | head -c 40 >&2
}

# ***

mr_is_quieted () {
  for switch in ${MR_SWITCHES}; do
    if [ "${switch}" = "-q" ] || [ "${switch}" = "--quiet" ]; then
      return 0
    fi

    if [ "${switch}" = "-M" ] || [ "${switch}" = "--more-minimal" ]; then
      return 0
    fi
  done

  return 1
}

git_any_cache_setup () {
  if ! mr_is_quieted; then
    git_any_action_started
  fi
}

git_any_cache_teardown () {
  if ! mr_is_quieted; then
    git_any_action_stopped
  fi
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main () {
  source_deps
  reveal_biz_vars
}

main "$@"
unset -f main
unset -f source_deps
unset -f reveal_biz_vars

