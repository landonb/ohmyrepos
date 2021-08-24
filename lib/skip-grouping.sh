#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# USAGE:
#
# In .mrconfig:
#
#   [<path>]
#   skip = mr_exclusive "group"
#
# From the CLI:
#
#   $ MR_INCLUDE=group mr -d / ls
#
# If you set skip on all projects, then this'll return no projects:
#
#   $ MR_INCLUDE= mr -d / ls
#
# and this'll return all projects still:
#
#   $ mr -d / ls
#
# To add to more than one group, try:
#
#   [<path>]
#   skip = mr_exclusive "group1" && mr_exclusive "group2"
#
# and then any of these will include <path>:
#
#   $ MR_INCLUDE=group1 mr -d / ls
#   $ MR_INCLUDE=group2 mr -d / ls
#   $ mr -d / ls

mr_exclusive () {
  ! [ -z ${MR_INCLUDE+x} ] && [ "${MR_INCLUDE}" != "$1" ]
}

