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
  local item_path="$1"
 
  local dir_name=""
  local base_name=""

  if ! [ -d "${item_path}" ]; then
    dir_name="$(dirname -- "${item_path}")"
    if [ -n "${item_path}" ]; then
      base_name="/$(basename -- "${item_path}")"
    fi
  else
    dir_name="${item_path}"
  fi

  dir_name="$(_logical_canonicalize_missing "${dir_name}")"

  printf "%s%s" "${dir_name}" "${base_name}"
}

# ***

_logical_canonicalize_missing () {
  local dir_name="$1"

  if [ -z "${dir_name}" ]; then
    dir_name="."
  fi

  local exists_part="${dir_name}"
  local absent_part=""

  local logical_path=""

  while [ "${exists_part}" != '.' ] && [ "${exists_part}" != '/' ]; do
    if logical_path="$(cd "${exists_part}" 2> /dev/null && pwd -L)"; then

      break
    fi

    if [ -n "${absent_part}" ]; then
      absent_part="/${absent_part}"
    fi
    absent_part="$(basename -- "${exists_part}")${absent_part}"
    exists_part="$(dirname -- "${exists_part}")"
  done

  if [ -z "${logical_path}" ]; then
    if [ "${exists_part}" = '.' ]; then
      logical_path="$(pwd -L)"
    elif [ "${exists_part}" = '/' ]; then 
      logical_path="/"
    else
      >&2 echo "GAFFE: Impossible path"
    fi
  fi

  if [ -n "${absent_part}" ]; then
    absent_part="/${absent_part}"
  fi

  printf "%s%s" "${logical_path}" "${absent_part}"
}

# ***

realpath_s () {
  print_unresolved_path "$@"
}

