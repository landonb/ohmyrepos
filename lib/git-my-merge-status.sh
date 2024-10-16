# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

_my_merge_status_source_deps () {
  # Note .mrconfig-omr sets PATH so deps found in OMR's deps/.

  # Load the logger library, from github.com/landonb/sh-logger.
  if command -v "logger.sh" > /dev/null; then
    . "logger.sh"
  else
    . "$(dirname -- "${BASH_SOURCE[0]}")/../deps/sh-logger/bin/logger.sh"
  fi

  # Load `print_nanos_now`.
  if command -v "print-nanos-now.sh" > /dev/null; then
    . "print-nanos-now.sh"
  else
    . "$(dirname -- "${BASH_SOURCE[0]}")/../deps/sh-print-nanos-now/bin/print-nanos-now.sh"
  fi
}

_my_merge_status_source_deps_on_demand () {
  # Load: mr_process_id, is_multiprocessing
  if command -v "mr-process-id.sh" > /dev/null; then
    . "mr-process-id.sh"
  else
    . "$(dirname -- "${BASH_SOURCE[0]}")/mr-process-id.sh"
  fi
}

_my_merge_status_reveal_biz_vars () {
  local mrpid="$(mr_process_id)"

  # Each my_merge_status runs in a separate subshell without direct
  # inter-process communication, so we use temp files with specific
  # filenames to cache data for the final report. The $mrpid ensures
  # that the user can run my-merge-status separately simultanesouly.
  OMR_MYSTATUS_TMP_CHORES_FILE_BASE="/tmp/gitsmart-ohmyrepos-mystatus-chores"
  OMR_MYSTATUS_TMP_TIMEIT_FILE_BASE="/tmp/gitsmart-ohmyrepos-mystatus-timeit"
  OMR_MYSTATUS_TMP_FLPFLP_FILE_BASE="/tmp/gitsmart-ohmyrepos-mystatus-flpflp"
  OMR_MYSTATUS_TMP_CHORES_FILE="${OMR_MYSTATUS_TMP_CHORES_FILE_BASE}-${mrpid}"
  OMR_MYSTATUS_TMP_TIMEIT_FILE="${OMR_MYSTATUS_TMP_TIMEIT_FILE_BASE}-${mrpid}"
  OMR_MYSTATUS_TMP_FLPFLP_FILE="${OMR_MYSTATUS_TMP_FLPFLP_FILE_BASE}-${mrpid}"

  # MAYBE/2020-02-26: Could adjust width based on terminal width.
  OMR_MYSTATUS_ECHO_PATH_WIDTH=${OMR_MYSTATUS_ECHO_PATH_WIDTH:-60}

  # (lb): Set false for old, pre-emojified behavior. Rather than show information
  #       about the remotes using icons, the old behavior just showed text if the
  #       repo is untidy, e.g., 'unchanged' for up to date repo, or 'unstaged',
  #       'uncommitd', 'untracked', etc.
  # HRMM/MAYBE/2020-03-13: On `MR_INCLUDE=home mr -d / mystatus`,
  #                        I see 5.6s for fancy status; 0.6s without!
  #                        So maybe fancy is not always better!
  #   - At least you can override on CLI, so could alias around it...
  OMR_MYSTATUS_FANCY=${OMR_MYSTATUS_FANCY:-true}

  OMR_MYSTATUS_SHOW_PROG="${OMR_MYSTATUS_SHOW_PROG:-}"

  # ***

  MR_STRIPING=${MR_STRIPING:-true}
  if ${SHCOLORS_OFF:-false}; then
    MR_STRIPING=false
  fi
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

print_status () {
  # Originally used debug mechanism:
  #   debug "${@}"
  # but that takes valuable line space; and who cares about today's YYYY-MM-DD?
  # So then I tried a simple echo, which is fairly elegant in its simplicity:
  #   echo "${@}"
  # but I do sorta like knowing how fast the operation is going, so add a short
  # elapsed time report to each line. So defaulting to not showing progress time.
  _print_status_show_elapsed_time () {
    local time_n=$(print_nanos_now)
    local file_time_0="${OMR_MYSTATUS_TMP_TIMEIT_FILE}"
    
    local elapsed_frac="$(echo "(${time_n} - $(cat ${file_time_0}))" | bc -l)"
    local elapsed_secs=$(printf "${elapsed_frac}" | xargs printf "%04.1f")

    printf %s "(${elapsed_secs}s) "
  }

  _print_status_show_clock_time () {
    local clock=$(date "+%T")

    printf %s "${clock}: "
  }

  local prefix=''
  if [ -n "${OMR_MYSTATUS_SHOW_PROG}" ]; then
    if [ "${OMR_MYSTATUS_SHOW_PROG}" = 'elapsed' ] &&
       [ -s ${OMR_MYSTATUS_TMP_TIMEIT_FILE} ]
    then
      prefix="$(_print_status_show_elapsed_time)"
    elif [ "${OMR_MYSTATUS_SHOW_PROG}" = 'clock' ]; then
      prefix="$(_print_status_show_clock_time)"
    fi
  fi

  if ! ${MR_STRIPING}; then
    echo "${prefix}${@}"
  else
    # Alternate line backgrounds: Use sed to replace "$(attr_reset)" with 
    # "$(attr_reset)$(bg_other_color)" (insert the next line's background
    # color immediately after the attr_reset).
    printf '%s' "${prefix}${@}" | sed -E "s/\x1b\[0m/\x1b[0m$(bg_ff)/g"
    printf '%s\n' "$(attr_reset)"
  fi
}

git_status_cache_setup () {
  # The action name is the variable name from lib/git-my-merge-status.
  # - BWARE/2023-05-01: `mr` does not set MR_ACTION for setup and teardown,
  #   regardless of multiprocessing (`mr -j 1` vs. `mr -j [>1]`).
  #   - The author will try to merge this upstream, but no guarantees.
  #   - So for now, know that every setup function runs for any action,
  #     because MR_ACTION here might be unset.
  #     - Just be sure not to do any setup or teardown that conflicts
  #       with any another setup or teardown function.
  [ -z "${MR_ACTION}" ] || [ "${MR_ACTION}" = 'mystatus' ] || return 0

  command rm -f -- "${OMR_MYSTATUS_TMP_CHORES_FILE_BASE}-"*

  command rm -f -- "${OMR_MYSTATUS_TMP_FLPFLP_FILE_BASE}-"*

  # Set the start time for the elapsed time display.
  command rm -f -- "${OMR_MYSTATUS_TMP_TIMEIT_FILE_BASE}-"*

  if [ "${OMR_MYSTATUS_SHOW_PROG}" = 'elapsed' ]; then
    print_nanos_now > ${OMR_MYSTATUS_TMP_TIMEIT_FILE}
  fi
}

git_status_notify_chores () {
  local untidy_count=$(cat "${OMR_MYSTATUS_TMP_CHORES_FILE}" | wc -l)

  local infl=''
  local refl=''

  [ ${untidy_count} -ne 1 ] && infl='s'
  [ ${untidy_count} -eq 1 ] && refl='s'

  warn "GRIZZLY! We found ${untidy_count} repo${infl} which need${refl} attention."
  notice
  notice "Here's some copy-pasta if you wanna fix it:"
}

git_status_cache_teardown () {
  [ -z "${MR_ACTION}" ] || [ "${MR_ACTION}" = 'mystatus' ] || return 0

  local ret_code=0

  if [ -e "${OMR_MYSTATUS_TMP_CHORES_FILE}" ]; then
    git_status_notify_chores
    echo
    cat "${OMR_MYSTATUS_TMP_CHORES_FILE}"
    echo
    # We could return nonzero, which `mr` would see and die on,
    # but the action for each repo that's dirty also indicated
    # failure, so `mr` already knows to exit nonzero. Also, we
    # want to return 0 here so that the stats line is printed.
    # NOPE: ret_code=1
  fi

  command rm -f -- "${OMR_MYSTATUS_TMP_CHORES_FILE}"
  command rm -f -- "${OMR_MYSTATUS_TMP_TIMEIT_FILE}"
  command rm -f -- "${OMR_MYSTATUS_TMP_FLPFLP_FILE}"

  return ${ret_code}
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

insist_installed () {
  # See:
  #   https://github.com/landonb/git-my-merge-status
  command -v "git-my-merge-status" > /dev/null \
    && return

  >&2 echo "MISSING: https://github.com/landonb/git-my-merge-status"

  return 1
}

# NOTE: Parsing --porcelain=v1 response should be future-proof.
#
#   $ man git status
#   ...
#     --porcelain[=<version>]
#         Give the output in an easy-to-parse format for scripts. This
#         is similar to the short output, but will remain stable across
#         Git versions and regardless of user configuration.
#
git_status_check_reset () {
  UNTIDY_REPO=false
}

git_mrrepo_at_git_root () {
  # When a git command runs, the working directory is set to the project root,
  # and $GIT_PREFIX reflects the subdirectory, if any, where the command ran.
  # But this isn't a git command, so check with rev-parse, rather than [ -d .git/ ].
  if [ "$(git rev-parse --show-toplevel)" = "$(pwd)" ] ||
     [ "$(git rev-parse --show-toplevel)" = "$(pwd -P)" ]; \
   then

    return 0
  fi

  # The user can stub out the OMR config to support projects that are
  # not actual Git repos. Report that here. (Returns 1 so `main` will
  # `return 0`.)
  print_status "  $(attr_emphasis)$(git_status_format_minty " no .git/")  " \
    "$(git_status_format_minty "${MR_REPO}")"

  return 1
}

git_status_check_blocklisted () {
  ${OMR_MYSTATUS_BLOCKLISTED:-false} || return 0

  print_status "  $(attr_emphasis)$(git_status_format_minty "blocklist")  " \
    "$(git_status_format_minty "${MR_REPO}")"

  return 1
}

# ***

git_status_format_alert () {
  local text="$1"

  echo "$(bg_ff)$(fg_lightorange)${text}$(attr_reset)"
}

git_status_format_minty () {
  local text="$1"

  echo "$(bg_ff)$(fg_mintgreen)${text}$(attr_reset)"
}

# https://coolors.co/dec5e3-a9f8fb-81f7e5-b0f2b4-a5c4d4

bg_a5c4d4 () {
  printf "\033[48;2;165;196;212m"
}

bg_b0f2b4 () {
  printf "\033[48;2;176;242;180m"
}

bg_2e2532 () {
  printf "\033[48;2;46;37;50m"
}

bg_2c2730 () {
  # Raisin black
  printf "\033[48;2;44;39;48m"
}

bg_2a2a69 () {
  # St. Patrick's blue
  printf "\033[48;2;42;42;105m"
}

bg_flipflop () {
  touch -- "${OMR_MYSTATUS_TMP_FLPFLP_FILE}"

  local flipflopflag="$(cat "${OMR_MYSTATUS_TMP_FLPFLP_FILE}")"

  if [ "${flipflopflag}" = "1" ]; then
    flipflopflag="0"
    bg_2e2532
  else
    flipflopflag="1"
    bg_2a2a69
  fi

  printf %s "${flipflopflag}" > "${OMR_MYSTATUS_TMP_FLPFLP_FILE}"
}

bg_ff () {
  ${MR_STRIPING} || return

  local flipflopflag="$(cat "${OMR_MYSTATUS_TMP_FLPFLP_FILE}")"

  if [ "${flipflopflag}" = "1" ]; then
    bg_2e2532
  else
    bg_2a2a69
  fi
}

# ***

git_status_check_report_9chars_maybe () {
  ${OMR_MYSTATUS_FANCY} && return

  git_status_check_report_9chars "${@}"
}

git_status_check_report_9chars () {
  status_adj="$1"
  opt_prefix="$2"
  opt_suffix="$3"

  print_status " "\
    "${opt_prefix}$(attr_underline)$(git_status_format_alert "${status_adj}")${opt_suffix}" \
    "  $(attr_underline)$(git_status_format_alert "${MR_REPO}")  $(fg_hotpink)✗$(attr_reset)"
}

# ***

# In this function, and in others below, we use a subprocess and return
# true, otherwise we'd need to wrap the call with set +e and set -e,
# otherwise the function would fail if no unstaged changes found.
git_status_check_unstaged () {
  local extcd

  # ' M' is modified but not added.
  (git status --porcelain=v1 | grep "^ M " >/dev/null 2>&1) \
    || extcd=$?

  if [ -z ${extcd} ]; then
    UNTIDY_REPO=true

    git_status_check_report_9chars_maybe 'unstaged' '  '
  fi
}

git_status_check_uncommitted () {
  local extcd

  # 'M ' is added but not committed.
  (git status --porcelain=v1 | grep "^M  " >/dev/null 2>&1) \
    || extcd=$?

  if [ -z ${extcd} ]; then
    UNTIDY_REPO=true

    git_status_check_report_9chars_maybe 'uncommitd'
  fi
}

git_status_check_untracked () {
  local extcd

  # '^?? ' is untracked.
  (git status --porcelain=v1 | grep "^?? " >/dev/null 2>&1) \
    || extcd=$?

  if [ -z ${extcd} ]; then
    UNTIDY_REPO=true

    git_status_check_report_9chars_maybe 'untracked' ' '
  fi
}

git_status_check_any_porcelain_output () {
  ${UNTIDY_REPO} && return

  local n_bytes=$(git status --porcelain=v1 | wc -c)

  if [ ${n_bytes} -gt 0 ]; then
    UNTIDY_REPO=true

    warn "UNEXPECTED: \`git status --porcelain=v1\` nonempty output in repo at: “${MR_REPO}”"

    git_status_check_report_9chars_maybe 'confusing'
  fi
}

git_report_untidy_repo () {
  ! ${UNTIDY_REPO} && return

  # This function runs in a subshell, so it's not feasible to maintain the list
  # of untidy repos in memory. So we need to use a pipe or a file.
  # Note that sh (e.g., dash; or a POSIX shell) does not define `echo -e`
  # like Bash (and in fact `echo -e "some string" echoes "-e some string).
  if [ -n "${OMR_MYSTATUS_TMP_CHORES_FILE}" ]; then
    echo \
      "  ${OMR_CPYST_CD} $(fg_lightorange)${MR_REPO}$(attr_reset) && git my-merge-status" \
      >> "${OMR_MYSTATUS_TMP_CHORES_FILE}"
  fi
}

git_report_fancy () {
  # - The grep -P precludes us from escaping \{\} braces.
  # - The grep -o prints only matching parts.
  # - You get the rest of the regex.
  # Why not print the git-my-merge-status snippet first, using a fixed-
  # width so the MR_REPO path aligns in the final column instead?, e.g.,
  #   "$(printf '%40s' "$(git-my-merge-status | head -1)")"
  # Because the color codes mean the width isn't really the width!
  # - Though there are relatively easy ways to count escape sequences,
  #   I like the my-merge-status snippet trailing, because then the smiley
  #   face (or whatever the temperate icon is set to) appears last.
  local pthw=${OMR_MYSTATUS_ECHO_PATH_WIDTH}
  local padw=$((pthw - 3))
  local xwid=${pthw}

  if ${UNTIDY_REPO}; then
    # 3 chars for '  ✗'
    pthw=$((pthw - 3))
    padw=$((pthw - 3))
    # Add 7 each for underline and reset controls.
    #  7:  myvar="$(attr_underline)" && echo ${#myvar}
    #  7:  myvar="$(attr_reset)" && echo ${#myvar}
    # 20:  myvar="$(fg_hotpink)" && echo ${#myvar}
    #  7:  myvar="$(attr_reset)" && echo ${#myvar}
    # -3:  but then we tacked on '  ✗' (✗ is digraph, so 1 char wide
    # 41 total...
    # - Which adds 4 too many spaces.
    #   FIXME/MAYBE/2020-02-15: Is print ignoring some of the control characters?
    #   - Remove 4 more because anecdotally I had to.
    xwid=$((pthw + 41 - 3 - 4))
  fi

  # Correct for Unicode: printf works in bytes, not chars, so add two spaces for
  # each Unicode character (which applies to some but not all Unicode characters).
  local path_bytes=$(printf "${MR_REPO}" | wc --bytes)
  local path_chars=$(printf "${MR_REPO}" | wc --chars)

  if [ ${path_bytes} -ne ${path_chars} ]; then
    # Has Unicode characters. (lb): I don't know the ratio, but most Unicode
    # characters I've seen (but not all) are reported as 3 characters. Because
    # we've already accounted for 1 character, add 2 more for every 1 Unicode,
    # i.e., # Bytes * 2/3. E.g., 2 Unicode chars is 6 bytes * 2/3 = add 4 spaces.
    xwid=$((xwid + ((path_bytes - path_chars) * 2 / 3)))
  fi

  gnu_grep () {
    command -v ggrep || command -v grep
  }

  # Step 1 of 2: Truncate to maximum width.
  local rpath="$(eval "printf '${MR_REPO}' | $(gnu_grep) -o -P '.{0,${padw}}\$'")"

  # Step 1.5 of 2: Prefix with ellipses if truncated.
  [ "${rpath}" != "${MR_REPO}" ] && rpath="...${rpath}"

  # Underline the repo path and append a noticeable ✗ after it, if mussy.
  ${UNTIDY_REPO} &&
    rpath="$(attr_underline)${rpath}$(attr_reset)  $(fg_hotpink)✗$(attr_reset)"

  # Step 2 of 2: Ensure minimum width.
  rpath="$(eval "printf '%-${xwid}s' '${rpath}'")"

  # Cluttered, frowzled, tousled, untidy... mussy.
  if ${UNTIDY_REPO}; then
    rpath="$(git_status_format_alert "${rpath}")"
  else
    rpath="$(git_status_format_minty "${rpath}")"
  fi

  local synop="$( \
    GITSMART_MYST_ALIGN_COLS=true \
    git-my-merge-status \
    | head -n 1
  )"

  print_status "${rpath}  ${synop}"
}

git_report_short_unchanged () {
  print_status "  $(attr_emphasis)$(git_status_format_minty "unchanged")  " \
    "$(git_status_format_minty "${MR_REPO}")"
}

git_my_merge_status () {
  insist_installed

  ${MR_STRIPING} && bg_flipflop
  git_status_check_reset
  git_mrrepo_at_git_root || return 0
  git_status_check_blocklisted || return 0
  git_status_check_unstaged
  git_status_check_uncommitted
  git_status_check_untracked
  git_status_check_any_porcelain_output

  git_report_untidy_repo

  if ${OMR_MYSTATUS_FANCY}; then
    git_report_fancy
  elif ! ${UNTIDY_REPO}; then
    git_report_short_unchanged
  fi

  # Return falsey/1 in repo has chore work, so `mr` marks repo as failed,
  # and later exits falsey.
  # - NOTE: You can reduce a lot of myrepos output with this in your .mrconfig:
  #   [DEFAULT]
  #   # For all actions/any action, do not print line separator/blank line
  #   # between repo actions.
  #   no_print_sep = true
  #   # For mystatus action, do not print action or directory header line.
  #   no_print_action_mystatus = true
  #   no_print_dir_mystatus = true
  #   # For mystatus action, do not print if repo fails (action will do it).
  #   no_print_failed_mystatus = true
  ! ${UNTIDY_REPO}
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main () {
  # Only source deps when not included by OMR.
  # - This supports user sourcing this file directly,
  #   and it helps OMR avoid re-sourcing the same files.
  if [ -z "${MR_CONFIG}" ]; then
    _my_merge_status_source_deps
  fi
  _my_merge_status_source_deps_on_demand

  _my_merge_status_reveal_biz_vars
  # Ohmyrepos will source this file, then later call, e.g.,
  #  git_my_merge_status
}

main "$@"

unset -f main
unset -f _my_merge_status_source_deps
unset -f _my_merge_status_source_deps_on_demand
unset -f _my_merge_status_reveal_biz_vars

