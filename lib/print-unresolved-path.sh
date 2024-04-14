#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# AVOID/2024-04-13: GNU coreutils `realpath -s` is not supported by macOS
# built-in `realpath`, so rather than look for Homebrew `realpath`, avoid
# this:
#   # -s, --strip, --no-symlinks: don't expand symlinks
#   realpath -s -- "${local_file}"
# And use `pwd` instead, with explicit `-L` (the default).
print_unresolved_path () {
  local local_file="$1"
  
  (
    cd "$(dirname -- "${local_file}")"

    pwd -L
  )
}

realpath_s () {
  print_unresolved_path "$@"
}

