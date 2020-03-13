# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=sh

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

source_deps () {
  :
}

reveal_biz_vars () {
  GITFLU_FETCH_REMOTES="${GITFLU_FETCH_REMOTES:-origin upstream}"
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
      echo -n "\r${remote}..."
      git fetch --prune --tags "${remote}"
    fi
  done
  echo -n "\r"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

fetch_selective () {
  local remotes
  if [ -z "$1" ] && [ -n "${GITFLU_FETCH_REMOTES}" ]; then
    # Because POSIX, only one array, the positional parameters.
    # NOTE: No quotes, else seen as just one var.
    set -- ${GITFLU_FETCH_REMOTES}
  fi

  if [ -z "$1" ]; then
    fetch_all
  else
    fetch_each "$@"
  fi
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main () {
  source_deps
  reveal_biz_vars
  # The myrepos wrapper, git-my-merge-status, calls, e.g.,:
  #  fetch_selective "$@"
}

main "$@"

