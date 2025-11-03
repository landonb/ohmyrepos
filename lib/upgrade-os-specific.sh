#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma <https://tallybark.com/>
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

upgrade_os_specific() {
  if os_is_macos; then
    mr -d ${MR_REPO} -n upgradeDarwin "$@"
  else
    mr -d ${MR_REPO} -n upgradeLinux "$@"
  fi
}
