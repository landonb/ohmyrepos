#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# This fcn. used by slather-defaults (macOS-GNOME-onboarder)
# to print list of copy-paste OMR install tasks.

echoInstallHelp() {
  local which_os="${1:-os_all}"
  local dxy_scope="${2:-dxy_all}"
  local addendum="$3"
  local alt_name="$4"
  local is_installed="$5"

  # if ! ${SLATHER_DEFAULTS_ENABLE:-false}; then
  #   return 0
  # fi

  # Convert to lowercase.
  which_os="$(echo "${which_os}" | tr '[:upper:]' '[:lower:]')"
  dxy_scope="$(echo "${dxy_scope}" | tr '[:upper:]' '[:lower:]')"

  local checkbox="$(echoInstallHelpWidget "${which_os}" "${dxy_scope}" ${is_installed})"

  # If you want the app name to be double-click selectable in
  # the terminal, use `backticks` and not “‘curly’ quotes”.
  local app_name="*$(basename -- "${MR_REPO}")*"

  local addendum_txt=""
  if [ -n "${addendum}" ]; then
    addendum_txt=" (${addendum})"
  fi

  echo "${checkbox} DepoXy [${MR_ORDER}]: Install ${alt_name:-${app_name}} project${addendum_txt}::
   mr -d \"${MR_REPO}\" -n install
"
}

# Some checkboxes, checkmarks, and cross marks: ✅ ☑  ✔  ✔️  ❌ ❎
echoInstallHelpWidget() {
  local which_os="${1:-os_all}"
  local dxy_scope="${2:-dxy_all}"
  local is_installed="$3"

  OMR_REMINDER_AWAITING="${OMR_REMINDER_AWAITING:-🔳}"
  OMR_REMINDER_COMPLETE="${OMR_REMINDER_COMPLETE:-✅}"
  OMR_REMINDER_OPTIONAL="${OMR_REMINDER_OPTIONAL:-❓}"
  OMR_REMINDER_DISABLED="${OMR_REMINDER_DISABLED:-❌}"
  OMR_REMINDER_OFFBUTON="${OMR_REMINDER_OFFBUTON:-❎}"

  local checkbox="${OMR_REMINDER_AWAITING}"

  if [ "${which_os}" = "os_linux" ]; then
    if [ "$(uname)" != 'Linux' ]; then
      checkbox="${OMR_REMINDER_DISABLED}"
    fi
  elif [ "${which_os}" = "os_macos" ]; then
    if [ "$(uname)" != 'Darwin' ]; then
      checkbox="${OMR_REMINDER_DISABLED}"
    fi
  elif [ "${which_os}" = "os_macos_maybe" ]; then
    if [ "$(uname)" = 'Darwin' ]; then
      checkbox="${OMR_REMINDER_OPTIONAL}"
    fi
  elif [ "${which_os}" = "os_maybe" ]; then
    checkbox="${OMR_REMINDER_OPTIONAL}"
  elif false ||
    [ "${which_os}" = "os_false" ] ||
    [ "${which_os}" = "os_none" ] ||
    [ "${which_os}" = "os_off" ] \
    ; then

    checkbox="${OMR_REMINDER_DISABLED}"
  elif [ "${which_os}" != "os_all" ]; then
    >&2 echo "ERROR: Unknown \`echoInstallHelp\` OS target: ${which_os}"

    checkbox="${OMR_REMINDER_DISABLED}"
  fi

  if [ "${dxy_scope}" = "dxy_limit" ]; then
    if [ "${OMR_ECHO_INSTALL_DXY_SCOPE:-dxy_all}" != "dxy_all" ]; then
      checkbox="${OMR_REMINDER_DISABLED}"
    fi
  elif [ "${dxy_scope}" = "dxy_limit_maybe" ]; then
    if [ "${OMR_ECHO_INSTALL_DXY_SCOPE:-dxy_all}" = "dxy_limit" ]; then
      checkbox="${OMR_REMINDER_OPTIONAL}"
    fi
  elif [ "${dxy_scope}" = "dxy_maybe" ]; then
    checkbox="${OMR_REMINDER_OPTIONAL}"
  elif false ||
    [ "${dxy_scope}" = "dxy_false" ] ||
    [ "${dxy_scope}" = "dxy_none" ] ||
    [ "${dxy_scope}" = "dxy_off" ] \
    ; then

    checkbox="${OMR_REMINDER_DISABLED}"
  elif [ "${dxy_scope}" != "dxy_all" ]; then
    >&2 echo "ERROR: Unknown \`echoInstallHelp\` env. scope: ${dxy_scope}"

    checkbox="${OMR_REMINDER_DISABLED}"
  fi

  if ([ -z "${is_installed}" ] && mr -d . -n isInstalled >/dev/null 2>&1) ||
    ${is_installed:-false} \
    ; then
    if [ "${checkbox}" = "${OMR_REMINDER_AWAITING}" ] ||
      [ "${checkbox}" = "${OMR_REMINDER_OPTIONAL}" ] \
      ; then

      # "👍"
      checkbox="${OMR_REMINDER_COMPLETE}"
    elif [ "${checkbox}" = "${OMR_REMINDER_DISABLED}" ]; then
      checkbox="${OMR_REMINDER_OFFBUTON}"
    fi
  fi

  printf "%s" "${checkbox}"
}
