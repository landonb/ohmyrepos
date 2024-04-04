# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# CXREF/2023-05-14: ~/.bash_completion is sourced by /etc/base_completion
#   /etc/bash_completion -> /usr/share/bash-completion/bash_completion
line_in_file () {
  local add_line="$1"
  local target_path="$2"

  local friendly_path="$( \
    echo "${target_path}" | sed -E "s#^${HOME}(/|$)#~\1#"
  )"

  # SAVVY: -q quiet, -x match the whole line, -F pattern is a plain string
  if [ -f "${target_path}" ] && grep -qxF "${add_line}" "${target_path}"; then
    info "Verified $(fg_lightorange)${friendly_path}$(attr_reset)"
  else
    if [ ! -e "${target_path}" ]; then
      info "Creating $(fg_lightorange)${friendly_path}$(attr_reset)"
    else
      info "Updating $(fg_lightorange)${friendly_path}$(attr_reset)"
    fi

    echo "${add_line}" >> "${target_path}"
  fi
}

