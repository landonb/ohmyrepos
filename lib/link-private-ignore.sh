#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=sh

source_deps () {
  # Load: warn, etc.
  . "${HOMEFRIES_LIB:-${HOME}/.homefries/lib}/logger.sh"

  # Load: 
  . "${OHMYREPOS_LIB:-${HOME}/.ohmyrepos/lib}/overlay-symlink.sh"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

link_private_ignore () {
  local lnkpath='.ignore'
  local targetp='.ignore'
  # Assume first param the commit message unless an -o/--option.
  if [ -n "${1}" ] && [ "${1#-}" = "$1" ]; then
    lnkpath="${1}"  # E.g., '_ignore'
    shift
  fi

  local was_link_force="${MRT_LINK_FORCE}"
  local was_link_safe="${MRT_LINK_SAFE}"
  myrepostravel_opts_parse "${@}"

  local before_cd="$(pwd -L)"
  cd "${MR_REPO}"

  set -- "${lnkpath}" "${targetp}" "${@}"
  symlink_mrinfuse_file "${@}"

  cd "${before_cd}"

  MRT_LINK_FORCE="${was_link_force}"
  MRT_LINK_SAFE="${was_link_safe}"
}

# An alias, of sorts.
link_private_ignore_force () {
  link_private_ignore "${@}" --force
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main () {
  source_deps
}

main "$@"

