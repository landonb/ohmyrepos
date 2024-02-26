#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# This fcn. used by slather-defaults (macOS-onboarder) to print list
# of copy-paste OMR install tasks.

echoInstallHelp () {
  local which_os="${1:-os_all}"
  local dxy_scope="${2:-dxy_all}"
  local addendum="$3"

  # if ! ${SLATHER_DEFAULTS_ENABLE:-false}; then
  #   return 0
  # fi

  # Convert to lowercase.
  which_os="$(echo "${which_os}" | tr '[:upper:]' '[:lower:]')"
  dxy_scope="$(echo "${dxy_scope}" | tr '[:upper:]' '[:lower:]')"

  local checkbox="🔳"

  if [ "${which_os}" = "os_linux" ]; then
    if [ "$(uname)" != 'Linux' ]; then
      checkbox="❌"
    fi
  elif [ "${which_os}" = "os_macos" ]; then
    if [ "$(uname)" != 'Darmin' ]; then
      checkbox="❌"
    fi
  elif false \
    || [ "${which_os}" = "os_false" ] \
    || [ "${which_os}" = "os_none" ] \
    || [ "${which_os}" = "os_off" ] \
  ; then
    checkbox="❌"
  elif [ "${which_os}" != "os_all" ]; then
    >&2 echo "ERROR: Unknown \`echoInstallHelp\` OS target: ${which_os}"

    checkbox="❌"
  fi

  if [ "${dxy_scope}" = "dxy_limit" ]; then
    if [ "${OMR_ECHO_INSTALL_DXY_SCOPE:-dxy_all}" != "dxy_all" ]; then
      checkbox="❌"
    fi
  elif false \
    || [ "${dxy_scope}" = "dxy_false" ] \
    || [ "${dxy_scope}" = "dxy_none" ] \
    || [ "${dxy_scope}" = "dxy_off" ] \
  ; then
    checkbox="❌"
  elif [ "${dxy_scope}" != "dxy_all" ]; then
    >&2 echo "ERROR: Unknown \`echoInstallHelp\` env. scope: ${dxy_scope}"

    checkbox="❌"
  fi

  local app_name="$(basename "${MR_REPO}")"

  local addendum_txt=""
  if [ -n "${addendum}" ]; then
    addendum_txt=" (${addendum})"
  fi

  echo "${checkbox} DepoXy: Install \`${app_name}\` from source${addendum_txt}::
   mr -d \"${MR_REPO}\" -n install
"
}

