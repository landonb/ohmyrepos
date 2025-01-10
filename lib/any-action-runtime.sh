# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# *** <beg boilerplate `source_deps`: ------------------------------|
#                                                                   |

_any_action_runtime_sh__this_filename="any-action-runtime.sh"

_any_action_runtime_sh__source_deps () {
  local sourced_all=true

  # On Bash, user can source this file from anywhere.
  # - If not Bash, user must `cd` to this file's parent directory first.
  local prefix="$(dirname -- "${_any_action_runtime_sh__this_fullpath}")"

  # USAGE: Load dependencies using path relative to this file, e.g.:
  #   _source_file "${prefix}" "../deps/path/to/lib" "dependency.sh"

  #                                                                 |
  # *** stop boilerplate> ------------------------------------------|

  # Load the log library, which includes `warn`, etc.
  # - As a side-effect, this also loads the stream-injectable
  #   color/style library, colors.sh.
  # - And, because this file is the first `include` from this
  #   project's .mrconfig-omr, the libraries sourced here will
  #   be available to all the other ohmyrepos/lib/*.sh scripts.
  # - Lastly, the .mrconfig-omr file sets, e.g., `lib = PATH=...`
  #   which enables the path-less source logger.sh here to work.
  # Load the logger library, from github.com/landonb/sh-logger.
  _any_action_runtime_sh__source_file "${prefix}" "../deps/sh-logger/bin" "logger.sh"

  # Load `print_nanos_now`.
  _any_action_runtime_sh__source_file "${prefix}" "../deps/sh-print-nanos-now/bin" "print-nanos-now.sh"

  # *** <more boilerplate: -----------------------------------------|
  #                                                                 |

  ${sourced_all}
}

_any_action_runtime_sh__smells_like_bash () { declare -p BASH_SOURCE > /dev/null 2>&1; }

_any_action_runtime_sh__print_this_fullpath () {
  if _any_action_runtime_sh__smells_like_bash; then
    echo "$(realpath -- "${BASH_SOURCE[0]}")"
  elif [ "$(basename -- "$0")" = "${_any_action_runtime_sh__this_filename}" ]; then
    # Assumes this script being executed, and $0 is its path.
    echo "$(realpath -- "$0")"
  else
    # Assumes cwd is this script's parent directory.
    echo "$(realpath -- "${_any_action_runtime_sh__this_filename}")"
  fi
}

_any_action_runtime_sh__this_fullpath="$(_any_action_runtime_sh__print_this_fullpath)"

_any_action_runtime_sh__shell_sourced () {
  [ "$(realpath -- "$0")" != "${_any_action_runtime_sh__this_fullpath}" ]
}

_any_action_runtime_sh__source_file () {
  local prfx="${1:-.}"
  local depd="${2:-.}"
  local file="${3:-.}"

  local deps_dir="${prfx}/${depd}"
  local deps_path="${deps_dir}/${file}"

  # Just in case sourced file overwrites top-level `_any_action_runtime_sh__this_filename`,
  # cache our copy, should we need it for an error message.
  local _this_file_name="${_any_action_runtime_sh__this_filename}"

  if [ -f "${deps_path}" ]; then
    # SAVVY: Source files from their dirs, so they can find their deps.
    local before_cd="$(pwd -L)"
    cd "${deps_dir}"
    # SAVVY: If errexit, error while sourcing kills process immediately,
    # and error you see might indicate this source file, but the line
    # number for the file being sourced. E.g.,
    #   /path/to/bin/myapp: 442: export: Illegal option -f
    # where `442` is line number from, e.g., 'deps/lib/dep.sh'.
    if ! . "${deps_path}"; then
      >&2 echo "ERROR: Dependency ‘${file}’ returned nonzero when sourced"
      sourced_all=false
    fi
    cd "${before_cd}"
  else
    local depstxt=""
    [ "${prfx}" = "." ] || depstxt="in ‘${deps_dir}’ or "
    >&2 echo "ERROR: ‘${file}’ not found under ‘${deps_dir}’"
    if _any_action_runtime_sh__smells_like_bash; then
      >&2 echo "- GAFFE: This looks like an error with the ‘_any_action_runtime_sh__source_file’ arguments"
    else
      >&2 echo "- HINT: You must source ‘${_this_file_name}’ from its parent directory"
    fi
    sourced_all=false
  fi
}

# BONUS: You can use these aliases instead of the uniquely-named functions,
# just be aware not to call any alias after calling _source_deps.
_shell_sourced () { _any_action_runtime_sh__shell_sourced; }
_source_deps () { _any_action_runtime_sh__source_deps; }

_any_action_runtime_sh__source_deps_unset_cleanup () {
  unset -v _any_action_runtime_sh__this_filename
  unset -f _any_action_runtime_sh__print_this_fullpath
  unset -f _any_action_runtime_sh__shell_sourced
  unset -f _shell_sourced
  unset -f _any_action_runtime_sh__smells_like_bash
  unset -f _any_action_runtime_sh__source_deps
  unset -f _source_deps
  unset -f _any_action_runtime_sh__source_deps_unset_cleanup
  unset -f _any_action_runtime_sh__source_file
}

# USAGE: When this file is being executed, before doing stuff, call:
#   _source_deps
# - When this file is being sourced, call both:
#   _source_deps
#   _any_action_runtime_sh__source_deps_unset_cleanup

#                                                                   |
# *** end boilerplate `source_deps`> -------------------------------|

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

# Mimic `mr`'s `showstats` and check these options to decide whether
# to show footer. (Else user might see lonely "(n secs.)" printed.)
mr_show_stats () {
  local show_time=true

  if ( \
    false \
    || [ "${MR_OPTS_QUIET:-0}" -eq 1 ] \
    || [ "${MR_OPTS_MINIMAL:-0}" -eq 1 ] \
    || [ "${MR_OPTS_MORE_MINIMAL:-0}" -eq 1 ] \
    || [ "${MR_OPTS_PRINT_FOOTER:-1}" -eq 0 ] \
    ) && [ "${MR_OPTS_STATS:-0}" -eq 0 ]; then
    show_time=false
  fi

  ${show_time}
}

git_any_cache_setup () {
  if mr_show_stats; then
    git_any_action_started
  fi
}

git_any_cache_teardown () {
  if mr_show_stats; then
    git_any_action_stopped
  fi
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main () {
  # Only source deps when not included by OMR.
  # - This supports user sourcing this file directly,
  #   and it helps OMR avoid re-sourcing the same files.
  if [ -z "${MR_CONFIG}" ]; then
    _source_deps
  fi

  reveal_biz_vars
}

main "$@"

_any_action_runtime_sh__source_deps_unset_cleanup
unset -f main
unset -f reveal_biz_vars

