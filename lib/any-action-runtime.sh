# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=sh

source_deps () {
  # Load: warn, etc.
  . "${HOMEFRIES_LIB:-${HOME}/.homefries/lib}/logger.sh"
}

reveal_biz_vars () {
  # 2019-10-21: (lb): Because myrepos uses subprocesses, our best bet for
  # maintaining data across all repos is to use temporary files.
  OMR_RUNTIME_TEMPFILE='/tmp/home-fries-myrepos.rntime-ieWeich9kaph5eiR'

  # YOU: Set this to minimum runtime in seconds for elapsed time to be displayed.
  OMR_RUNTIME_MIN_SECS=${OMR_RUNTIME_MIN_SECS:-0}
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

git_any_command_started () {
  date +%s.%N > "${OMR_RUNTIME_TEMPFILE}"
}

git_any_command_stopped () {
  local setup_time_0=$(cat "${OMR_RUNTIME_TEMPFILE}")
  [ -z ${setup_time_0} ] && error "ERROR:" \
    "Missing start time! Be sure to call \`git_status_cache_setup\`."
  local setup_time_n="$(date +%s.%N)"
  local seconds=$(echo "${setup_time_n} - ${setup_time_0}" | bc -l)
  if [ $(echo "${seconds} >= ${OMR_RUNTIME_MIN_SECS}" | bc -l) -ne 0 ]; then
    local time_elapsed="$(python_prettify_elapsed "${seconds}")"
    [ -z "${time_elapsed}" ] && time_elapsed="$(simple_bc_elapsed "${seconds}")"
    echo -n "$(attr_emphasis)(${time_elapsed})$(attr_reset) "
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

