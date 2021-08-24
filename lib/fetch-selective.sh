# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

reveal_biz_vars () {
  GITSMART_FETCH_REMOTES="${GITSMART_FETCH_REMOTES:-proving release starter myclone origin upstream}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# FIXME/DRY/2020-03-09: Or not? remote_exists also in git-my-merge-status.
remote_exists () {
  local remote="$1"
  # WEIRD: A simple `> /dev/null` nor a 2> nor a &> working here.
  git remote get-url ${remote} > /dev/null 2>&1
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

fetch_all () {
  git fetch --prune --tags --all
}

fetch_each () {
  local remotes="$@"
  while [ "$1" != '' ]; do
    local remote="$1"
    shift
    if remote_exists "${remote}"; then
      # echo "Fetching: ${remote}..."
      printf '\r%s' "${remote}..."
      git fetch --prune --tags "${remote}"
    fi
  done
  printf '\r'
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

fetch_selective () {
  local remotes
  if [ -z "$1" ] && [ -n "${GITSMART_FETCH_REMOTES}" ]; then
    # Because POSIX, only one array, the positional parameters.
    # NOTE: No quotes, else seen as just one var.
    set -- ${GITSMART_FETCH_REMOTES}
  fi

  if [ -z "$1" ]; then
    fetch_all
  else
    fetch_each "$@"
  fi
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main () {
  reveal_biz_vars
  # The myrepos wrapper, git-my-merge-status, calls, e.g.,:
  #  fetch_selective "$@"
}

main "$@"

