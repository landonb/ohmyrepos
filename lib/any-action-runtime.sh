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
  if ! . logger.sh 2> /dev/null; then
    . "$(dirname -- "${BASH_SOURCE[0]}")/../deps/sh-logger/bin/logger.sh"
  fi

  # Load `print_nanos_now`.
  if ! . print-nanos-now.sh 2> /dev/null; then
    . "$(dirname -- "${BASH_SOURCE[0]}")/../deps/sh-print-nanos-now/bin/print-nanos-now.sh"
  fi
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

  local ppid_count
  ppid_count="$(read_ppid_count_from_tempfile)"
  ppid_count=$((${ppid_count} + 1))
  remove_old_temp_files

  print_nanos_now > "${OMR_RUNTIME_TEMPFILE}"
  echo "${ppid_count}" >> "${OMR_RUNTIME_TEMPFILE}"
}

git_any_action_stopped () {
  # DEBUG: Uncomment to trace setup and teardown calls:
  #
  #  _trace_ps_heritage "TEARDOWN"

  local setup_time_0
  setup_time_0="$(head -n 1 -- "${OMR_RUNTIME_TEMPFILE}" 2> /dev/null)" \
    || true

  if [ -z "${setup_time_0}" ]; then
    # BUGGY: This path happens occasionally, because some race condition
    # the author has yet to explain.
    # - KLUGE: See `find -mmin -delete` below: Now hopefully this path
    #   is unreachable, because cleanup lets young temp files live.
    >&2 warn "GAFFE: Missing start time: Is \`git_any_cache_setup\` working?"

    printf %s "$(attr_emphasis)(Unk. secs.)$(attr_reset) "

    return 0
  fi

  local setup_time_n="$(print_nanos_now)"

  local seconds=$(echo "${setup_time_n} - ${setup_time_0}" | bc -l)

  if [ $(echo "${seconds} >= ${OMR_RUNTIME_MIN_SECS}" | bc -l) -ne 0 ]; then
    local time_elapsed="$(python_prettify_elapsed "${seconds}")"

    [ -z "${time_elapsed}" ] \
      && time_elapsed="$(simple_bc_elapsed "${seconds}")"

    printf %s "$(attr_emphasis)(${time_elapsed})$(attr_reset) "
  fi

  update_or_remove_tempfile
}

# ***

# User can call `mr` from an `mr` action, so only remove the file
# associated with the current process, because there might be
# multiple runtime temp files in use.
update_or_remove_tempfile () {
  local ppid_count
  ppid_count="$(read_ppid_count_from_tempfile)"
  ppid_count=$((${ppid_count} - 1))

  if [ ${ppid_count} -gt 0 ]; then
    head -n 1 -- "${OMR_RUNTIME_TEMPFILE}" \
      | tee -- "${OMR_RUNTIME_TEMPFILE}" > /dev/null
    echo "${ppid_count}" >> "${OMR_RUNTIME_TEMPFILE}"
  else
    ( sleep 1 && command rm -f -- "${OMR_RUNTIME_TEMPFILE}" ) &
  fi
}

read_ppid_count_from_tempfile () {
  tail -n +2 "${OMR_RUNTIME_TEMPFILE}" 2> /dev/null \
    || echo "0"
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
  # If parent is the shell, assume this is the main `mr`
  # process running setup_dispatch_append for the first
  # time.
  # - E.g.,
  #     if [ "/home/user/.local/bin/bash" = "$( \
  #       ps -ocommand= -p $(ps -o ppid= ${PPID} | tr -d ' ')
  #     )" ]; then
  if ps -ocommand= -p $(ps -o ppid= ${PPID} | tr -d ' ') \
    | grep -q -E '(^-?|\/)(ba|da|fi|z)?sh$' - \
  ; then
    # DEBUG: Uncomment to trace setup and teardown calls:
    #
    #  _trace_ps_heritage "CLEAN-UP"

    # BWARE/2024-04-15: There's a race condition where sometimes
    # the tempfile is missing on final git_any_action_stopped
    # time_elapsed report. The author isn't quite sure what's
    # up, I'd guess something with `mr -j 10` usage, but all
    # the tracing in the world hasn't shown me the fault.
    # - KLUGE: So instead, try this: rather than *assume*
    #   that we're safe to delete all runtime temp files,
    #   delete only those older than 10 minutes.
    #   - How could this not work around the race condition?
    #   - So not this:
    #
    #       command rm -f -- "${OMR_RUNTIME_TEMPFILE_BASE}"*

    find "$(dirname -- "${OMR_RUNTIME_TEMPFILE_BASE}")" \
      -maxdepth 1 \
      -name "$(basename -- "${OMR_RUNTIME_TEMPFILE_BASE}")*" \
      -type f \
      -mmin +${_ten_minutes_ago:-10} \
      -delete
  fi
}

# DEBUG: You can uncomment calls to this function to see what's going on.
_trace_ps_heritage () {
  >&2 echo "$1: $$ / $PPID / $(ps -o ppid= ${PPID} | tr -d ' ')"

  # Print the command names:
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
  # Only source deps when not included by OMR.
  # - This supports user sourcing this file directly,
  #   and it helps OMR avoid re-sourcing the same files.
  if [ -z "${MR_CONFIG}" ]; then
    source_deps
  fi

  reveal_biz_vars
}

main "$@"

unset -f main
unset -f source_deps
unset -f reveal_biz_vars

