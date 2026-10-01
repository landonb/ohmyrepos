#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma <https://tallybark.com/>
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

download_and_diff() {
  local url="$1"
  local local_file="$2"

  if [ -z "${url}" ] || [ -z "${local_file}" ]; then
    error "ERROR: USAGE: download_and_diff <URL> <local_file_path>"

    return 1
  fi

  if [ ! -f "${local_file}" ]; then
    download_first_time
  else
    download_refresh_time
  fi
}

download_first_time() {
  # Aka 'premier'.
  debug "Inaugural download..."

  if curl -s -f -L -o "${local_file}" "${url}"; then
    debug "Successfully downloaded to ${local_file}"

    # 201 Created.
    return 201
  else
    error "ERROR: Failed to download remote file: ${url}"

    return 1
  fi
}

download_refresh_time() {
  debug "Refreshing download..."

  local temp_file
  temp_file=$(mktemp)

  # Such manners.
  # - Except: Bashism:
  #   trap 'command rm -f -- "${temp_file}"' RETURN
  remove_temp_file() {
    command rm -f -- "${temp_file}"
  }

  if curl -s -f -L -z "${local_file}" -o "${temp_file}" "${url}"; then
    # If temp. file empty, didn't download anything because nothing changed.
    if [ ! -s "${temp_file}" ]; then
      debug "No changes detected (Remote file matches local timestamp)"
      remove_temp_file

      # 204 No Content, eh.
      return 204
    fi

    # If it did download, print the text diff
    debug -e "\n--- Changes Detected! Showing Diff ---"
    # FIXME: debug fmting:
    diff --color=always -u "${local_file}" "${temp_file}"

    # Overwrite the old local file with the newly downloaded version
    command mv -- "${temp_file}" "${local_file}"

    debug -e "----------------------------------------\nLocal file updated."

    # HTTP 200, eh.
    return 200
  fi

  error "ERROR: Failed to update local file: ${local_file}"
  remove_temp_file

  return 1
}
