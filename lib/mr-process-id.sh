# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

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

