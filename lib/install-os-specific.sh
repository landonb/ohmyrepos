#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

install_os_specific() {
  if os_is_macos; then
    mr -d ${MR_REPO} -n installDarwin "$@"
  else
    mr -d ${MR_REPO} -n installLinux "$@"
  fi
}

isInstalled_os_specific() {
  if os_is_macos; then
    mr -d ${MR_REPO} -n isInstalledDarwin "$@"
  else
    mr -d ${MR_REPO} -n isInstalledLinux "$@"
  fi
}
