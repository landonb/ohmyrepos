# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# USAGE: Ensure line exists in a file, possibly replacing another line.
#
# UCASE: E.g., to ensure "PasswordAuthentication no" is set in
# sshd_config, and to replace an existing setting, e.g.,
# "PasswordAuthentication yes", use the following call:
#
#   OMR_BECOME=sudo \
#   line_in_file \
#     /private/etc/ssh/sshd_config \
#     "^PasswordAuthentication " \
#     "PasswordAuthentication no"
# 
#
# UCASE: E.g., run line_in_file to comment out "message_size_limit = 10485760"
#        in /etc/postfix/main.cf (aka /private/etc/postfix/main.cf on macOS):
#
#   OMR_BECOME=sudo \
#   line_in_file \
#     /private/etc/postfix/main.cf \
#     "^message_size_limit = ([0-9]+)$" \
#     "# message_size_limit = ([0-9]+)" \
#     "# message_size_limit = \\\1"
#
# USAGE: As shown above, set OMR_BECOME=sudo to run privileged.

# REFER: https://docs.ansible.com/ansible/latest/collections/ansible/builtin/lineinfile_module.html

# REFER: The tac|awk|tac from:
#   https://unix.stackexchange.com/questions/651315/
#     sed-command-to-replace-last-occurrence-of-a-word-in-a-file-with-the-content-of-a
# - ALTLY: Using `sed`:
#     sed -n "/${regexp}/=" "${path}" \
#     | sed -e '$!d' -e $'s/.*/'"${line}"'\\\n&d/' \
#     | sed -i '' -f /dev/stdin "${path}"
#
#   - Where:
#     1. "Finds all lines in ${path} that matches ${regexp} and output the
#         line numbers corresponding to those lines."
#     2. "Deletes all but the last line number outputted by the first step
#         (using $!d, "if this is not the last line, delete it"), and creates
#         a two-line sed script that would modify the last matching line by
#         [replacing the original line with the new ${line}]."
#     3.  "Applies the constructed sed script on the file ${path}."

# BWARE: Assumes `grep -E` and `awk` compatible ${regexp} pattern.

line_in_file () {
  local path="$1"
  local regexp="$2"
  local line="$3"
  local replace="${4:-${line}}"

  if [ -z "${path}" ] || [ -z "${regexp}" ]; then
    >&2 echo "GAFFE: Missing path and/or regexp"

    return 1
  fi

  local state="present"

  if [ -z "${line}" ]; then
    state="absent"
  fi

  local friendly_path="$( \
    echo "${path}" | sed -E "s@^${HOME}(/|$)@~\1@"
  )"

  if [ "${state}" = "present" ]; then
    if [ ! -f "${path}" ]; then
      info "Creating $(fg_lightorange)${friendly_path}$(attr_reset)"

      # Assigns permissions per umask, e.g., 644 when umask is `0002`.
      echo "${line}" | ${OMR_BECOME} tee -a "${path}" > /dev/null
    else
      if grep -qE "^${line}\$" "${path}"; then
        info "Verified $(fg_lightorange)${friendly_path}$(attr_reset)"
      else
        info "Updating $(fg_lightorange)${friendly_path}$(attr_reset)"

        if ! grep -qE "${regexp}" "${path}"; then
          echo "${line}" | ${OMR_BECOME} tee -a "${path}" > /dev/null
        else
          # Use copy because pipeline truncates redirection target when it starts.
          # - ALTLY: See instead `| sponge "${path}"` vs. `> "${path}"`.
          local tmp_path="${path}.$(date +%Y_%m_%d_%Hh%Mm%Ss)-$(uuidgen | head -c8)"

          # Use cp, not mv, to preserve hardlinks.
          ${OMR_BECOME} cp --preserve=all -- "${path}" "${tmp_path}"

          # We cheat, sorta, and prepend ^.* and apped .*$ so that the
          # whole line is replaced.
          # - Note that ^.*^.* is valid, as is .*$.*$
          #   so (I think) this should always work.

          if ${_OMR_LINE_IN_FILE_TRACE:-false}; then
            cat <<EOF
    tac "${tmp_path}" \\
      | awk "/${regexp}/ && !n++ { print gensub(/^.*${regexp}.*\$/, \"${replace}\", \"g\"); next; } 1" \\
      | tac \
      | ${OMR_BECOME} tee -- "${path}" > /dev/null
EOF
          fi

          tac "${tmp_path}" \
            | awk "/${regexp}/ && !n++ { print gensub(/^.*${regexp}.*\$/, \"${replace}\", \"g\"); next; } 1" \
            | tac \
            | ${OMR_BECOME} tee -- "${path}" > /dev/null

          ${OMR_BECOME} rm -f -- "${tmp_path}"
        fi
      fi
    fi
  else
    if [ ! -f "${path}" ]; then
      info "Verified no file found at $(fg_lightorange)${friendly_path}$(attr_reset)"
    else
      if ! grep -qE "${regexp}" "${path}"; then
        info "Verified absent from file $(fg_lightorange)${friendly_path}$(attr_reset)"
      else
        info "Removing line from $(fg_lightorange)${friendly_path}$(attr_reset)"

        local tmp_path="${path}.$(date +%Y_%m_%d_%Hh%Mm%Ss)-$(uuidgen | head -c8)"

        # Use cp, not mv, to preserve hardlinks.
        ${OMR_BECOME} cp --preserve=all -- "${path}" "${tmp_path}"

        tac "${tmp_path}" \
          | awk "/${regexp}/ && !n++ { next; } 1" \
          | tac \
          | ${OMR_BECOME} tee -- "${path}" > /dev/null

        ${OMR_BECOME} rm -f -- "${tmp_path}"
      fi
    fi
  fi
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# Similar to line_in_file, but won't replace existing lines.
#
# - E.g., ensure a specific line exists in fstab
#
#     OMR_BECOME=true \
#     append_line_unless_exists \
#       "/etc/fstab" \
#       "192.168.11.123:/volume1/homes /private/myvolume nfs proto=tcp,port=2123,resvport"

append_line_unless_exists () {
  local path="$1"
  local line="$2"

  if [ -z "${line}" ] || [ -z "${path}" ]; then
    >&2 echo "GAFFE: Missing line and/or path"

    return 1
  fi

  local friendly_path="$( \
    echo "${path}" | sed -E "s@^${HOME}(/|$)@~\1@"
  )"

  # SAVVY: -q quiet, -x match the whole line, -F pattern is a plain string
  if [ -f "${path}" ] && grep -qxF "${line}" "${path}"; then
    info "Verified $(fg_lightorange)${friendly_path}$(attr_reset)"
  else
    if [ ! -e "${path}" ]; then
      info "Creating $(fg_lightorange)${friendly_path}$(attr_reset)"
    else
      info "Updating $(fg_lightorange)${friendly_path}$(attr_reset)"
    fi

    # If creating, assigns 644 permissions.
    echo "${line}" | ${OMR_BECOME} tee -a "${path}" > /dev/null
  fi
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

