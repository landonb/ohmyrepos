#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# Symlink-aware path canonicalization.

readlink_m () {
  local resolve_path="$1"
  local ret_code=0
  if [ "$(readlink --version 2> /dev/null)" ]; then
    # Linux: Modern readlink.
    resolve_path="$(readlink -m -- "${resolve_path}")"
  else
    # macOHHHH-ESS/macOS: No `readlink -m`.
    local before_cd="$(pwd -L)"
    # - `readlink -m` operates "without requirements on components
    #   existence", unlike `readlink -f` or `readlink -e`.
    local basedir_link="${resolve_path}"
    if [ -d "${basedir_link}" ]; then
      cd "${basedir_link}" > /dev/null
      resolve_path="$(pwd -P)"
    else
      basedir_link="$(dirname -- "${resolve_path}")"
      if [ -d "${basedir_link}" ]; then
        cd "${basedir_link}" > /dev/null
        resolve_path="$(pwd -P)/$(basename -- "${resolve_path}")"
      fi
    fi
    local resolve_link="$(readlink -- "${resolve_path}")"
    while [ -n "${resolve_link}" ]; do
      case "${resolve_link}" in
        /*)
          # Absolute path.
          resolve_path="${resolve_link}"
          ;;
        *)
          # Relative path.
          basedir_link="$(dirname -- "${resolve_path}")"
          if [ -d "${basedir_link}" ]; then
            cd "${basedir_link}" > /dev/null
            basedir_link="$(pwd -P)"
          fi
          resolve_path="${basedir_link}/${resolve_link}"
          ;;
      esac
      local resolve_link="$(readlink -- "${resolve_path}")"
    done
    cd "${before_cd}"
  fi
  [ -n "${resolve_path}" ] && echo "${resolve_path}"
  return ${ret_code}
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main () {
  :
}

main "$@"

