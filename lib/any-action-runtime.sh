# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash

source_deps () {
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
}

reveal_biz_vars () {
  # (lb): Because myrepos uses subprocesses, we cannot share values
  # using environment variables. So we use a temporary file instead.
  OMR_RUNTIME_TEMPFILE='/tmp/home-fries-myrepos.rntime-ieWeich9kaph5eiR'

  # YOU: Set this to minimum threshold for elapsed time to be displayed.
  # - Default: 0 secs., i.e., always show the action runtime (which is just
  #   a short value in paranetheses before the normal `mr` status report).
  OMR_RUNTIME_MIN_SECS=${OMR_RUNTIME_MIN_SECS:-0}
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# FIXME/2020-08-26: Move home_fries_nanos_now to shared dependency.
home_fries_nanos_now () {
  if command -v gdate > /dev/null 2>&1; then
    # macOS (brew install coreutils).
    gdate +%s.%N
  elif date --version > /dev/null 2>&1; then
    # Linux/GNU.
    date +%s.%N
  else
    # macOS pre-coreutils.
    python -c 'import time; print("{:.9f}".format(time.time()))'
  fi
}

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

git_any_command_started () {
  home_fries_nanos_now > "${OMR_RUNTIME_TEMPFILE}"
}

git_any_command_stopped () {
  local setup_time_0=$(cat "${OMR_RUNTIME_TEMPFILE}")
  [ -z "${setup_time_0}" ] && error "ERROR:" \
    "Missing start time! Be sure to call \`git_any_cache_setup\`."
  local setup_time_n="$(home_fries_nanos_now)"
  local seconds=$(echo "${setup_time_n} - ${setup_time_0}" | bc -l)
  if [ $(echo "${seconds} >= ${OMR_RUNTIME_MIN_SECS}" | bc -l) -ne 0 ]; then
    local time_elapsed="$(python_prettify_elapsed "${seconds}")"
    [ -z "${time_elapsed}" ] && time_elapsed="$(simple_bc_elapsed "${seconds}")"
    printf %s "$(attr_emphasis)(${time_elapsed})$(attr_reset) "
  fi
  /bin/rm -f "${OMR_RUNTIME_TEMPFILE}"
}

git_any_cache_setup () {
  git_any_command_started
}

git_any_cache_teardown () {
  git_any_command_stopped
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main () {
  source_deps
  reveal_biz_vars
}

main "$@"

