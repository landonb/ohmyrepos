#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

source_deps () {
  # Load: symlink_*.
  # - Note that .mrconfig-omr sets PATH to include OMR's lib/.
  if command -v "overlay-symlink.sh" > /dev/null; then
    . "overlay-symlink.sh"
  else
    . "$(dirname -- "${BASH_SOURCE[0]}")/overlay-symlink.sh"
  fi
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

link_private_ignore () {
  local lnkpath='.ignore'

  # Assume first param an alternative filename unless an -o/--option.
  if [ -n "$1" ] && [ "${1#-}" = "$1" ]; then
    lnkpath="$1"  # E.g., '_ignore'

    shift
  fi

  local targetp="$(dirname -- "${lnkpath}")/.ignore"

  local was_link_force="${MRT_LINK_FORCE}"
  local was_link_safe="${MRT_LINK_SAFE}"

  myrepostravel_opts_parse "$@"

  local before_cd="$(pwd -L)"

  cd "${MR_REPO}"

  set -- "${lnkpath}" "${targetp}" "$@"
  symlink_mrinfuse_file "$@"

  cd "${before_cd}"

  MRT_LINK_FORCE="${was_link_force}"
  MRT_LINK_SAFE="${was_link_safe}"
}

# An alias, of sorts.
link_private_ignore_force () {
  link_private_ignore "$@" --force
}

# Another alias.
link_private_ignore_ () {
  link_private_ignore "_ignore" "$@"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main () {
  source_deps
}

# Only source deps when not included by OMR.
# - This supports user sourcing this file directly,
#   and it helps OMR avoid re-sourcing the same files.
if [ -z "${MR_CONFIG}" ]; then
  main "$@"
fi

unset -f main
unset -f source_deps

