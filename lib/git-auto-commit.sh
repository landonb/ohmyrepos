# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# *** <beg boilerplate `source_deps`: ------------------------------|
#                                                                   |

_git_auto_commit_sh__this_filename="git-auto-commit.sh"

_git_auto_commit_sh__source_deps() {
  local sourced_all=true

  # On Bash, user can source this file from anywhere.
  # - If not Bash, user must `cd` to this file's parent directory first.
  local prefix="$(dirname -- "${_git_auto_commit_sh__this_fullpath}")"

  # USAGE: Load dependencies using path relative to this file, e.g.:
  #   _source_file "${prefix}" "../deps/path/to/lib" "dependency.sh"

  #                                                                 |
  # *** stop boilerplate> ------------------------------------------|

  # Load the logger library, from github.com/landonb/sh-logger.
  # - Includes print commands: info, warn, error, debug.
  _git_auto_commit_sh__source_file "${prefix}" "../deps/sh-logger/bin" "logger.sh"

  _git_auto_commit_sh__source_file "${prefix}" "" "overlay-symlink.sh"

  # *** <more boilerplate: -----------------------------------------|
  #                                                                 |

  ${sourced_all}
}

_git_auto_commit_sh__smells_like_bash() { declare -p BASH_SOURCE >/dev/null 2>&1; }

_git_auto_commit_sh__print_this_fullpath() {
  if _git_auto_commit_sh__smells_like_bash; then
    echo "$(realpath -- "${BASH_SOURCE[0]}")"
  elif [ "$(basename -- "$0")" = "${_git_auto_commit_sh__this_filename}" ]; then
    # Assumes this script being executed, and $0 is its path.
    echo "$(realpath -- "$0")"
  else
    # Assumes cwd is this script's parent directory.
    echo "$(realpath -- "${_git_auto_commit_sh__this_filename}")"
  fi
}

_git_auto_commit_sh__this_fullpath="$(_git_auto_commit_sh__print_this_fullpath)"

_git_auto_commit_sh__shell_sourced() {
  [ "$(realpath -- "$0")" != "${_git_auto_commit_sh__this_fullpath}" ]
}

_git_auto_commit_sh__source_file() {
  local prfx="${1:-.}"
  local depd="${2:-.}"
  local file="${3:-.}"

  local deps_dir="${prfx}/${depd}"
  local deps_path="${deps_dir}/${file}"

  # Just in case sourced file overwrites top-level `_git_auto_commit_sh__this_filename`,
  # cache our copy, should we need it for an error message.
  local _this_file_name="${_git_auto_commit_sh__this_filename}"

  if [ -f "${deps_path}" ]; then
    # SAVVY: Source files from their dirs, so they can find their deps.
    local before_cd="$(pwd -L)"
    cd "${deps_dir}"
    # SAVVY: If errexit, error while sourcing kills process immediately,
    # and error you see might indicate this source file, but the line
    # number for the file being sourced. E.g.,
    #   /path/to/bin/myapp: 442: export: Illegal option -f
    # where `442` is line number from, e.g., 'deps/lib/dep.sh'.
    if ! . "${deps_path}"; then
      >&2 echo "ERROR: Dependency ‘${file}’ returned nonzero when sourced"
      sourced_all=false
    fi
    cd "${before_cd}"
  else
    local depstxt=""
    [ "${prfx}" = "." ] || depstxt="in ‘${deps_dir}’ or "
    >&2 echo "ERROR: ‘${file}’ not found under ‘${deps_dir}’"
    if _git_auto_commit_sh__smells_like_bash; then
      >&2 echo "- GAFFE: This looks like an error with the ‘_git_auto_commit_sh__source_file’ arguments"
    else
      >&2 echo "- HINT: You must source ‘${_this_file_name}’ from its parent directory"
    fi
    sourced_all=false
  fi
}

# BONUS: You can use these aliases instead of the uniquely-named functions,
# just be aware not to call any alias after calling _source_deps.
_shell_sourced() { _git_auto_commit_sh__shell_sourced; }
_source_deps() { _git_auto_commit_sh__source_deps; }

_git_auto_commit_sh__source_deps_unset_cleanup() {
  unset -v _git_auto_commit_sh__this_filename
  unset -f _git_auto_commit_sh__print_this_fullpath
  unset -f _git_auto_commit_sh__shell_sourced
  unset -f _shell_sourced
  unset -f _git_auto_commit_sh__smells_like_bash
  unset -f _git_auto_commit_sh__source_deps
  unset -f _source_deps
  unset -f _git_auto_commit_sh__source_deps_unset_cleanup
  unset -f _git_auto_commit_sh__source_file
}

# USAGE: When this file is being executed, before doing stuff, call:
#   _source_deps
# - When this file is being sourced, call both:
#   _source_deps
#   _git_auto_commit_sh__source_deps_unset_cleanup

#                                                                   |
# *** end boilerplate `source_deps`> -------------------------------|

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

reveal_biz_vars() {
  MR_GIT_AUTO_COMMIT_SAID_HELLO=false
}

must_git_nothing_staged() {
  if git_nothing_staged; then
    return
  fi

  error "ERROR: Cannot auto-commit alongside staged changes"
  error "└→ Please tidy up: ${MR_REPO}"

  exit 1
}

git_auto_commit_parse_args() {
  # Note that both `shift` and `set -- $@` are scoped to this function,
  # so we'll process all args in one go (rather than splitting into two
  # functions, because myrepostravel_opts_parse complains on unknown args).
  myrepostravel_opts_parse "$@"
  [ ${MRT_AUTO_YES} -eq 0 ] && MR_AUTO_COMMIT=true || true

  # These two variables are use by git_auto_commit_many.
  # - The commit count is incremented by git_auto_commit_one, which the
  #   git_auto_commit_many feature uses (because DRY), and indicates if
  #   there's anything to commit. (We can either keep count, or we could
  #   check git-status and ignore untracked. But we prefer the count
  #   because it helps (but doesn't prevent) autocommit from committing
  #   previously staged work).
  MR_GIT_AUTO_COMMIT_STAGE_COUNT=0
  # This tracks the names of committed files to help craft the --message.
  MR_GIT_AUTO_COMMIT_FILES_ADDED=""

  MR_GIT_AUTO_COMMIT_FIXUP=""
}

git_auto_commit_cd_mrrepo() {
  # Only print the "examining" message once, e.g., affects calls such as:
  #     autocommit =
  #       git_auto_commit_one 'some/file' "$@"
  #       git_auto_commit_one 'ano/ther' "$@"
  if ! ${MR_GIT_AUTO_COMMIT_SAID_HELLO}; then
    MR_GIT_AUTO_COMMIT_BEFORE_CD="$(pwd -L)"
    cd "${MR_REPO}"
    debug "$(fg_mintgreen)$(attr_emphasis)autocommitting$(attr_reset)" \
      "$(fg_lightorange)${MR_REPO}$(attr_reset)"
  fi
  MR_GIT_AUTO_COMMIT_SAID_HELLO=true
}

git_auto_commit_cd_return() {
  cd "${MR_GIT_AUTO_COMMIT_BEFORE_CD}"
}

git_auto_commit_noop() {
  debug "  $(fg_mintgreen)$(attr_emphasis)excluding$(attr_reset)  " \
    "$(fg_mintgreen)${MR_REPO}$(attr_reset)"
}

git_auto_commit_one() {
  must_git_nothing_staged
  git_auto_commit_cd_mrrepo

  git_auto_commit_parse_args "$@"
  if ! git_auto_commit_process_rest "git_auto_commit_path_one" "$@"; then
    fatal "ERROR: Expecting a path to git_auto_commit_one."

    exit 1
  fi

  git_auto_commit_cd_return
}

# UCASE: Use fixup auto-commit when you don't care about an item's change
# history, or if it changes often and you don't want to suffer a noisy
# log, or maybe it's a binary item and you don't want to waste a lot of
# disk space tracking object states you don't care about.
git_auto_fixup_one() {
  local repo_file="$1"
  local fixup_msg="$2"

  if [ -z "${fixup_msg}" ]; then
    error "ERROR: Missing commit message:" \
      "\`git_auto_fixup_one \"${repo_file}\" \"<commit-msg>\"\`"

    exit 1
  fi

  shift 2

  # ***

  # Similar to: git_auto_commit_one "${repo_file}" "$@"
  # - Except setting MR_GIT_AUTO_COMMIT_FIXUP after parsing args
  #   (because git_auto_commit_parse_args clears that environ).

  must_git_nothing_staged
  git_auto_commit_cd_mrrepo

  git_auto_commit_parse_args "${repo_file}" "$@"

  # 2024-04-21: This mechanism is very much an after-thought (as in, plumbed
  # in years after the original features without too much consideration how
  # best to do it). There might be a more elegant way to do this. For now,
  # piggy-backing on existing git_auto_commit_path_one and jamming in fixup
  # option via environ.
  MR_GIT_AUTO_COMMIT_FIXUP="${fixup_msg}"

  if ! git_auto_commit_process_rest "git_auto_commit_path_one" "${repo_file}" "$@"; then
    fatal "ERROR: Expecting a path to git_auto_commit_one."

    exit 1
  fi

  git_auto_commit_cd_return
}

git_auto_commit_path_one() {
  local repo_file="$1"
  local skip_commit=${2:-false}

  if [ -z "${repo_file}" ]; then
    fatal "ERROR: Expecting a path to git_auto_commit_one."

    exit 1
  fi

  # NOTE/2021-08-22: The -f/--force option was originally plumbed for
  #                  overlay-symlink, hence the var name, MRT_LINK_FORCE.
  if [ ! -f "${repo_file}" ] && [ ! -h "${repo_file}" ] && [ ${MRT_LINK_FORCE:-1} -eq 1 ]; then
    error "ERROR: Expected a file or symlink at “${repo_file}” (git_auto_commit_one)"
    if [ ! -e "${repo_file}" ]; then
      error "- Found nothing"
    else
      error "- Found wrong type: $($(gnu_stat) -c %F "${repo_file}")"
    fi

    exit 1
  fi

  local msg_prefix="myrepos: autoci: Add Favorite: [@$(hostname)]"
  local commit_msg="${MR_GIT_AUTO_COMMIT_MSG:-${msg_prefix} “$(basename -- "${repo_file}")”}"

  local inclT=""
  [ ${MRT_LINK_FORCE} -ne 0 ] || inclT=" T|"
  git_status_unstaged_or_untracked "${repo_file}" "${inclT}"

  if [ $? -eq 0 ]; then
    local yorn
    if [ -z ${MR_AUTO_COMMIT} ] || ! ${MR_AUTO_COMMIT}; then
      printf '\n'
      printf '%s\n' "Yo! This file has changes: $(fg_lightorange)${MR_REPO}/${repo_file}$(attr_reset)"
      printf '%s' "Commit the file changes? [y/n] "
      read yorn
    else
      debug "$(fg_mintgreen)$(attr_emphasis)autocommit one$(attr_reset)" \
        "$(fg_lavender)${MR_REPO}/${repo_file}$(attr_reset)"
      yorn="Y"
    fi

    if [ "${yorn#y}" != "${yorn}" ] || [ "${yorn#Y}" != "${yorn}" ]; then
      git add "${repo_file}"
      MR_GIT_AUTO_COMMIT_STAGE_COUNT=$((MR_GIT_AUTO_COMMIT_STAGE_COUNT + 1))
      ${skip_commit} || git_auto_commit_path_one_or_many "${commit_msg}"
    elif [ -z ${MR_AUTO_COMMIT} ] || ! ${MR_AUTO_COMMIT}; then
      echo 'Skipped!'
    fi
  # else the file has no changes/is not changed.
  fi
}

gnu_stat() {
  for cmd in "gstat" "stat"; do
    (
      unset -f ${cmd}
      unalias ${cmd}
      command -v ${cmd}
    ) 2>/dev/null &&
      break
  done
}

# - Check for ' M unstaged/files'
#         and ' T typechanged/files' (but only if MRT_LINK_FORCE=0, b/c obscure case,
#                                     and user probably wants to know if typechanged),
#         and '?? untracked/files',
#         at least.
#   We could also check 'M  staged/files'
#   and for combination 'MM staged/and/unstaged/changes'
#   but I'd rather start strict and see if the latter is
#   something for which I eventually yearn.
# - Note that a path with spaces or special characters will be quoted.
git_status_unstaged_or_untracked() {
  local repo_file="$1"
  local inclT="$2"

  # SAVVY: Set quotepath off, so unicode path characters are not converted
  # to octal UTF8 (e.g., "🪤" !→ "\360\237\252\244"), which would break our
  # filename grep.
  git -c core.quotepath=off status --porcelain=v1 -- "${repo_file}" |
    grep -q -E -e "^(${inclT} M|\?\?) \"?${repo_file}\"?$"
}

git_nothing_staged() {
  git diff --cached --quiet
}

git_auto_commit_path_one_or_many() {
  local commit_msg="$1"

  if [ -z "${commit_msg}" ]; then
    fatal "ERROR: Expecting a commit message to git_auto_commit_path_one_or_many."

    exit 1
  fi

  # ***

  git_auto_commit_resolve_fixup_commit() {
    if [ -z "${MR_GIT_AUTO_COMMIT_FIXUP}" ]; then
      return 0

    fi

    git --no-pager log -1 --format=%H ":/^${MR_GIT_AUTO_COMMIT_FIXUP}\$" 2>/dev/null ||
      true
  }

  local commit_opts=""
  commit_opts="$(git_auto_commit_resolve_fixup_commit)"

  if [ -z "${commit_opts}" ]; then
    if [ -n "${MR_GIT_AUTO_COMMIT_FIXUP}" ]; then
      commit_msg="${MR_GIT_AUTO_COMMIT_FIXUP}"
    fi

    commit_opts="-m \"${MR_GIT_AUTO_COMMIT_FIXUP:-${commit_msg}}\""
  fi

  # ***

  # BWARE: Be careful to preserve newlines in the message
  # when composing the eval.
  # - HSTRY/2025-09-09: The quotes around the eval string are new.
  #   - If that doesn't work for all cases, make the -m arg inline.
  #     - E.g., disable `commit_opts="-m ..."` above, and use this:
  #         if ! eval git commit ${commit_opts} "$(
  #           test -n "${commit_opts}" \
  #             || echo "-m \"${MR_GIT_AUTO_COMMIT_FIXUP:-${commit_msg}}\""
  #           )" >/dev/null 2>&1; then

  if ! eval "git commit ${commit_opts}" >/dev/null 2>&1; then
    error "Commit failed:"

    eval "git commit ${commit_opts}" 2>&1 |
      while IFS= read -r line; do
        error "  ${line}"
      done

    exit 1
  fi

  if [ -z ${MR_AUTO_COMMIT} ] || ! ${MR_AUTO_COMMIT}; then
    echo 'Committed!'
  fi
}

git_auto_commit_many() {
  must_git_nothing_staged
  git_auto_commit_cd_mrrepo

  git_auto_commit_parse_args "$@"
  if ! git_auto_commit_process_rest "git_auto_commit_path_many" "$@"; then
    # ISOFF/2024-04-29: Zero counts as many, doesn't it?
    if false; then
      fatal "ERROR: Expecting a path(s) to git_auto_commit_many."

      exit 1
    else
      return 0
    fi
  fi

  if [ ${MR_GIT_AUTO_COMMIT_STAGE_COUNT} -gt 0 ]; then
    local msg_prefix="myrepos: autoci: Add Favorite: [@$(hostname)]"
    local commit_msg="${MR_GIT_AUTO_COMMIT_MSG:-${msg_prefix} ${MR_GIT_AUTO_COMMIT_FILES_ADDED}.}"
    git_auto_commit_path_one_or_many "${commit_msg}"
  fi

  git_auto_commit_cd_return
}

git_auto_commit_path_many() {
  local repo_file="$1"
  if [ -z "${repo_file}" ]; then
    fatal "ERROR: Expecting a path to git_auto_commit_path_many."

    exit 1
  fi

  local skip_commit=true

  [ -z "${MR_GIT_AUTO_COMMIT_FILES_ADDED}" ] ||
    MR_GIT_AUTO_COMMIT_FILES_ADDED="${MR_GIT_AUTO_COMMIT_FILES_ADDED}, "
  MR_GIT_AUTO_COMMIT_FILES_ADDED="${MR_GIT_AUTO_COMMIT_FILES_ADDED}“$(basename -- "${repo_file}")”"

  git_auto_commit_path_one "${repo_file}" ${skip_commit}
}

git_auto_commit_all() {
  must_git_nothing_staged
  git_auto_commit_cd_mrrepo

  git_auto_commit_parse_args "$@"
  if git_auto_commit_process_rest "git_auto_commit_path_all" "$@"; then
    fatal "ERROR: Not expecting a path to git_auto_commit_path_all."

    exit 1
  fi
  local commit_msg="${MR_GIT_AUTO_COMMIT_MSG:-update(aci): commit all changes [@$(hostname)].}"

  # We ignore untracked files here because they cannot be added
  # by a generic `git add -u` -- in fact, git should complain.
  #
  # So auto-commit works on existing git files, but not on new ones.
  #
  # (However, `git add --all` adds untracked files, but rather than
  # automate this, don't. Because user might really want to update
  # .gitignore instead, or might still be considering where an un-
  # tracked file should reside, or maybe it's just a temp file, etc.)
  #
  # Also, either grep pattern should work:
  #
  #   git status --porcelain=v1 | grep "^\W*M\W*" >/dev/null 2>&1
  #   git status --porcelain=v1 | grep "^[^\?]" >/dev/null 2>&1
  #
  # but I'm ignorant of anything other than the two codes,
  # '?? filename', and ' M filename', so let's be inclusive and
  # just ignore new files, rather than being exclusive and only
  # looking for modified files. If there are untracted files, a
  # later call to git-status--porcelain on the same repo will die.
  local extcd
  (git status --porcelain=v1 | grep "^[^\?]" >/dev/null 2>&1) || extcd=$?
  if [ -z ${extcd} ]; then
    local yorn
    if [ -z ${MR_AUTO_COMMIT} ] || ! ${MR_AUTO_COMMIT}; then
      printf '\n'
      printf '%s\n' "Yo! This repo has changes: $(fg_lightorange)${MR_REPO}$(attr_reset)"
      printf '%s' "Commit *all* object changes? [y/n] "
      read yorn
    else
      local pretty_path="$(attr_underline)$(bg_darkgray)${MR_REPO}$(attr_reset)"
      notice "$(fg_mintgreen)$(attr_emphasis)autocommit all$(attr_reset)" \
        "$(fg_lavender)${pretty_path}$(attr_reset)"
      yorn="Y"
    fi

    if [ "${yorn#y}" != "${yorn}" ] || [ "${yorn#Y}" != "${yorn}" ]; then
      git add -u
      git commit -m "${commit_msg}" >/dev/null 2>&1
      if [ -z ${MR_AUTO_COMMIT} ] || ! ${MR_AUTO_COMMIT}; then
        echo 'Committed!'
      else
        verbose 'Committed!'
      fi
    elif [ -z ${MR_AUTO_COMMIT} ] || ! ${MR_AUTO_COMMIT}; then
      echo 'Skipped!'
    fi
  fi

  git_auto_commit_cd_return
}

git_auto_commit_path_all() {
  : # pass/no-op.
}

git_auto_commit_new() {
  must_git_nothing_staged
  git_auto_commit_cd_mrrepo

  git_auto_commit_parse_args "$@"
  if ! git_auto_commit_process_rest "git_auto_commit_path_new" "$@"; then
    # If not path/files/globs specified, run on repo root.
    git_auto_commit_path_new "."
  fi

  git_auto_commit_cd_return
}

git_auto_commit_process_rest() {
  local processor="$1"
  shift

  local processed_path=false
  while [ "$1" != '' ]; do
    if [ "$1" = '--' ]; then
      shift
      break
    fi
    # These options were previously processed by params_register_switches.
    # Here we just need to ignore them.
    case $1 in
    -f)
      shift
      ;;
    --force)
      shift
      ;;
    -s)
      shift
      ;;
    --safe)
      shift
      ;;
    -y)
      shift
      ;;
    --yes)
      shift
      ;;
    -m)
      shift 2
      ;;
    --message)
      shift 2
      ;;
    *)
      eval "${processor} \"$1\""
      shift
      processed_path=true
      ;;
    esac
  done

  if [ $# -gt 0 ]; then
    # Saw --.
    while [ "$1" != '' ]; do
      eval "${processor} \"$1\""
      shift
      processed_path=true
    done
  fi

  ${processed_path}
}

git_auto_commit_path_new() {
  local add_path="${1:-.}"

  local msg_prefix="myrepos: autoci: Add Untracked [@$(hostname)]"
  local msg_postfix
  if [ "${add_path}" != "." ]; then
    msg_postfix=" “${add_path}”"
  fi
  local commit_msg="${MR_GIT_AUTO_COMMIT_MSG:-${msg_prefix}${msg_postfix}.}"

  local extcd
  (git status --porcelain=v1 "${add_path}" | grep "^[\?][\?]" >/dev/null 2>&1) || extcd=$?

  if [ -z ${extcd} ]; then
    local yorn
    if [ -z ${MR_AUTO_COMMIT} ] || ! ${MR_AUTO_COMMIT}; then
      printf '\n'
      printf '%s\n' "Yo! This repo has untracked paths: $(fg_lightorange)${MR_REPO}$(attr_reset)"
      printf '%s' "Add *untracked* paths therein? [y/n] "
      read yorn
    else
      debug "$(fg_mintgreen)$(attr_emphasis)autocommit new$(attr_reset)" \
        "$(fg_lavender)${MR_REPO}/${add_path}$(attr_reset)"
      yorn="Y"
    fi

    if [ "${yorn#y}" != "${yorn}" ] || [ "${yorn#Y}" != "${yorn}" ]; then
      # Hilarious. There's one way to programmatically add only
      # untracked files, and it's using the interactive feature.
      # (Because `git add .` adds untracked files but also includes
      # edited files; but we provide git_auto_commit_all for edited
      # files.)
      # TOO INCLUSIVE: git add .  # Adds edited files, too.
      # Interactive: 4. [a]dd untracked / 7: [q]uit.
      printf "a\n*\nq\n" | git add -i "${add_path}" >/dev/null 2>&1
      git commit -m "${commit_msg}" >/dev/null 2>&1
      if [ -z ${MR_AUTO_COMMIT} ] || ! ${MR_AUTO_COMMIT}; then
        echo 'Committed!'
      else
        verbose 'Committed!'
      fi
    elif [ -z ${MR_AUTO_COMMIT} ] || ! ${MR_AUTO_COMMIT}; then
      echo 'Skipped!'
    fi
  fi
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main() {
  # Only source deps when not included by OMR.
  # - This supports user sourcing this file directly,
  #   and it helps OMR avoid re-sourcing the same files.
  if [ -z "${MR_CONFIG}" ]; then
    _source_deps
  fi

  reveal_biz_vars
}

main "$@"

_git_auto_commit_sh__source_deps_unset_cleanup
unset -f main
unset -f reveal_biz_vars
