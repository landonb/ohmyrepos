#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

source_deps () {
  # Use fallback paths to support sourcing into user's Bash shell
  # (assumes BASH_SOURCE); otherwise being sourced by OMR (and
  # /bin/sh) and .mrconfig-omr put the libs on PATH.

  # Load the logger library, from github.com/landonb/sh-logger.
  # - Note that .mrconfig-omr adds deps/... path to PATH.
  # - This also implicitly loads the colors.sh library.
  if command -v "logger.sh" > /dev/null; then
    . "logger.sh"
  else
    . "$(dirname -- "${BASH_SOURCE[0]}")/../deps/sh-logger/bin/logger.sh"
  fi

  # Load: print_unresolved_path, realpath_s
  if command -v "print-unresolved-path.sh" > /dev/null; then
    . "print-unresolved-path.sh"
  else
    . "$(dirname -- "${BASH_SOURCE[0]}")/print-unresolved-path.sh"
  fi
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

params_register_defaults () {
  # Note that these names are backwards, or maybe it's the internal
  # values. We're using 0 to represent truthy, and 1 to signal off.
  MRT_LINK_SAFE=${MRT_LINK_SAFE:-1}
  MRT_LINK_FORCE=${MRT_LINK_FORCE:-1}
  MRT_AUTO_YES=${MRT_AUTO_YES:-1}
  MR_GIT_AUTO_COMMIT_MSG=""
  MRT_INFUSE_DIR="${MRT_INFUSE_DIR:-.mrinfuse}"
}

params_register_switches () {
  while [ "$1" != '' ]; do
    if [ "$1" = '--' ]; then
      shift

      break
    fi
    case "$1" in
      -f)
        MRT_LINK_FORCE=0
        shift
        ;;
      --force)
        MRT_LINK_FORCE=0
        shift
        ;;
      -s)
        MRT_LINK_SAFE=0
        shift
        ;;
      --safe)
        MRT_LINK_SAFE=0
        shift
        ;;
      -y)
        MRT_AUTO_YES=0
        shift
        ;;
      --yes)
        MRT_AUTO_YES=0
        shift
        ;;
      -m)
        shift
        MR_GIT_AUTO_COMMIT_MSG="$1"
        shift
        ;;
      --message)
        shift
        MR_GIT_AUTO_COMMIT_MSG="$1"
        shift
        ;;
      *)
        # Test if starts with prefix and assume an --option.
        # User can -- to specify filenames that start with dash.
        if [ "${1#-}" != "$1" ]; then
          >&2 error "ERROR: Unrecognized argument: $1"

          return 1
        fi
        shift
        ;;
    esac
  done
}

myrepostravel_opts_parse () {
  params_register_defaults
  params_register_switches "$@"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

infuser_set_envs () {
  local repodir="${1:-"${MR_REPO}"}"

  # Ensure MR_REPO set so script can be called manually,
  # outside context of myrepos.
  export MR_REPO="${repodir}"
}

# 2019-10-26: This does not belong here. But all my infusers at least
# include this file. So. Being lazy.
repo_highlight () {
  echo "$(fg_mintgreen)${1}$(attr_reset)"
}

infuser_prepare () {
  local repodir="${1:-"${MR_REPO}"}"
  shift

  infuser_set_envs "${repodir}"
  info "Infusing $(repo_highlight ${repodir}) [for ‘$(basename -- "$0")’]"
  myrepostravel_opts_parse "$@"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

font_emphasize () {
  echo "$(attr_emphasis)$@$(attr_reset)"
}

font_highlight () {
  echo "$(fg_lightorange)$@$(attr_reset)"
}

# ***

font_info_checked () {
  echo "$(fg_lightyellow)$@$(attr_reset)"
}

font_info_created () {
  echo "$(fg_lightcyan)$@$(attr_reset)"
}

font_info_updated () {
  echo "$(fg_lavender)$@$(attr_reset)"
}

font_info_skipped () {
  echo "$(fg_lightred)$@$(attr_reset)"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

is_relative_path () {
  # POSIX does not support pattern matching, e.g.,
  #   if [[ "$DIR" = /* ]]; then ... fi
  # but we can use a case statement.
  case $1 in
    /*) return 1 ;;
    *) return 0 ;;
  esac

  >&2 error "GAFFE: Unreachable code"

  return 1
}

path_exists_and_not_symlink () {
  [ -e "$1" ] && [ ! -h "$1" ]
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# Source verification.

symlink_verify_source () {
  local sourcep="$1"
  local srctype="$2"
  local targetp="$3"

  emit_error () {
    local type_name="$1"

    >&2 error "ERROR: Cannot create symbolic link:"
    >&2 error "- Did not find linkable source ${type_name} at:"
    >&2 error "    ${sourcep}"
    >&2 error "- From the directory:"
    >&2 error "    $(pwd -L)"
    >&2 error "- For the target:"
    >&2 error "    ${targetp}"
  }

  if [ "${srctype}" = 'file' ]; then
    if [ ! -f "${sourcep}" ]; then
      emit_error "file"

    return 1
    fi
  elif [ "${srctype}" = 'dir' ]; then
    if [ ! -d "${sourcep}" ]; then
      emit_error "directory"

    return 1
    fi
  else
    >&2 error "GAFFE: Not a known srctype: ${srctype}"

    return 1
  fi
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# Target verification.

safe_backup_existing_target () {
  local targetp="$1"
  local targetf="$(basename -- "${targetp}")"
  local backup_postfix=$(date +%Y.%m.%d.%H.%M.%S)
  local backup_targetp="${targetp}-${backup_postfix}"

  command mv -- "${targetp}" "${targetp}-${backup_postfix}"

  info "Collision resolved: Moved existing ‘${targetf}’ to: ${backup_targetp}"
}

emit_error_target_exists_not_symlink () {
  local srctype="$1"
  local sourcep="$2"
  local targetp="$3"

  >&2 error "ERROR: Cannot create ‘${srctype}’:"
  >&2 error "- Target exists but is not a symlink (hence we won't replace)"
  >&2 error "- Please examine the target path:"
  >&2 error "    ${targetp}"
  >&2 error "- From the working directory:"
  >&2 error "    $(pwd -L)"
  >&2 error "- Use -f/--force, or -s/--safe, or remove the file,"
  >&2 error "  or edit overlay-symlink.sh, which could be broken"
}

safe_backup_if_not_forced () {
  local srctype="$1"
  local sourcep="$2"
  local targetp="$3"

  if [ ${MRT_LINK_SAFE:-1} -eq 0 ]; then
    safe_backup_existing_target "${targetp}"
  elif [ ${MRT_LINK_FORCE:-1} -ne 0 ]; then
    emit_error_target_exists_not_symlink "${srctype}" "${sourcep}" "${targetp}"

    return 1
  fi
}

# ***

ensure_symlink_target_overwritable () {
  local srctype="$1"
  local sourcep="$2"
  local targetp="$3"

  if path_exists_and_not_symlink "${targetp}"; then
    if ! safe_backup_if_not_forced "symlink" "${sourcep}" "${targetp}"; then

      return 1
    fi
  fi
}

# This fcn. not called, but what it might look like
# for parity w/ ensure_symlink_target_overwritable:
#
#   ensure_hardlink_target_overwritable () {
#     local sourcep="$1"
#     local targetp="$2"
#
#     # Complements path_exists_and_not_symlink
#     file_exists_and_not_linked_to_source () {
#       [ -e "$1" ] && ! [ "$1" -ef "$2" ]
#     }
#
#     if file_exists_and_not_linked_to_source "${targetp}" "${sourcep}"; then
#       safe_backup_if_not_forced "hard link" "${sourcep}" "${targetp}"
#     fi
#   }

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# Symlink creation.

makelink_create_informative () {
  local srctype="$1"
  local sourcep="$2"
  local targetp="$3"
  local symlink="$4"

  # Caller guarantees (via ! -e and ! -h) that $targetp does not exist.

  local targetd="$(dirname -- "${targetp}")"
  mkdir -p "${targetd}"

  local command_or_sudo="$(print_command_or_sudo)"

  eval "${command_or_sudo} ln ${symlink} '${sourcep}' '${targetp}'" || (
    local link_type='hard link'
    [ -n "${symlink}" ] && link_type='symlink'

    >&2 error "ERROR: Failed to create ‘${link_type}’ at: ${targetp}"

    return 1
  )

  # Created new symlink.
  local info_msg
  info_msg="$( \
    symlink_get_msg_informative \
      " $(font_info_created "Created")" "${srctype}" "${targetp}" "${symlink}" \
  )"

  info "${info_msg}"
}

makelink_update_informative () {
  local srctype="$1"
  local sourcep="$2"
  local targetp="$3"
  local symlink="$4"

  local link_type='hard link'
  [ -n "${symlink}" ] && link_type='symlink'

  local info_msg
  if [ -h "${targetp}" ]; then
    # (Will be) Overwriting existing symlink.
    info_msg="$(symlink_get_msg_informative \
      " $(font_info_updated "Updated")" "${srctype}" "${targetp}" "${symlink}" \
    )"
  elif [ -f "${targetp}" ]; then
    # SAVVY: -ef true when checking symlink and its link path.
    if ! [ "${sourcep}" -ef "${targetp}" ]; then
      # For how this function is used, the code would already have checked
      # that the user specified -f/--force; or else the code didn't care to
      # ask. See:
      #   safe_backup_if_not_forced.
      info_msg=" Clobbered file with ${link_type} $(font_highlight "$(realpath_s "${targetp}")")"
    else
      info_msg="$(symlink_get_msg_informative \
        " $(font_info_checked "Checked")" "${srctype}" "${targetp}" "${symlink}" \
      )"
      info "${info_msg}"

      return 0
    fi
  else
    >&2 error "GAFFE: Target neither ‘${link_type}’ nor file, but exists?"

    return 1
  fi

  local command_or_sudo="$(print_command_or_sudo)"

  # Note if target symlinks to a file, we can overwrite with force, e.g.,
  #   /bin/ln -sf source/path target/path
  # but if the target exists and is a symlink to a directory instead,
  # the new symlink gets created inside the referenced directory.
  # To handle either situation -- the existing symlink references
  # either a file or a directory -- remove the target first.
  ${command_or_sudo} rm -- "${targetp}"

  if ! eval "${command_or_sudo} ln ${symlink} '${sourcep}' '${targetp}'"; then
    >&2 error "ERROR: ‘ln’ failed to replace symlink at: $(realpath_s "${targetp}")"

    return 1
  fi

  info "${info_msg}"
}

# Caller can prefix `MRT_SUDO=sudo ` to their call to place
# root symlinks — but note we don't support running `mkdir -p`
# via sudo, but assume user is overwriting existing symlink.
# - The current/only use case (currently) is to replace
#     macOS:/var/select/sh
print_command_or_sudo () {
  local command_or_sudo="command"

  if [ "${MRT_SUDO}" = "sudo" ]; then
    command_or_sudo="sudo"
  fi

  printf "%s" "${command_or_sudo}"
}

symlink_get_msg_informative () {
  local what="$1"
  local srctype="$2"
  local targetp="$3"
  local symlink="$4"

  local link_type='hard link'
  [ -n "${symlink}" ] && link_type='symlink'

  local targetd=''

  # Like `/bin/ls -F`, "Display a slash (`/') ... after each pathname that is a [dir]."
  [ "${srctype}" = 'dir' ] && targetd='/' || true

  # Turn 'dir' into 'dir.' so same count as 'file' and output (filenames and dirnames) align.
  [ "${srctype}" = 'dir' ] && srctype='dir.' || true

  local info_msg
  info_msg="${what} $( \
    font_emphasize "${srctype}") ${link_type} $(\
      font_highlight "$( \
        realpath_s "${targetp}"
      )${targetd}"
    )"

  printf "%s" "${info_msg}"
}

# ***

# Prints the shortest relative path from targetp to sourcep,
# when both sourcep and targetp are relative paths.
#
# - Otherwise, when either or both is a full path,
#   prints sourcep unaltered.
#
# Note that when both paths are relative, they're relative to the
# currect working directory (which is often the project root, i.e.,
# MR_REPO).
#
# - E.g., calling:
#     symlink_overlay_dir "path/to/a/subdir" "path/elsewhere/subdir"
#   will create the symlink:
#     path/elsewhere/subdir -> ../to/a/subdir
#   (in the current working directory, e.g., MR_REPO).
#
# - But when sourcep is relative and targetp is a full path, the
#   sourcep path is specified relative to targetp base directory.
#
#   - This lets the user make a symlink at any arbitrary destination
#     without needed to `cd` first, and they can choose if they want
#     a relative link or full path link, e.g.,:
#       symlink_overlay_dir "path/to/subdir" "${HOME}/subdir"
#     will create the symlink:
#       /Users/user/subdir -> path/to/subdir
#     Whereas:
#       symlink_overlay_dir "${HOME}/path/to/subdir" "${HOME}/subdir"
#     will create the symlink:
#       /Users/user/subdir -> /Users/user/path/to/subdir
#
# The author realizes this might not be the most intuitive approach,
# because it varies what the link is relative to.
# - Perhaps when both path are relative, sourcep *should* be relative
#   to targetp, for parity, but they you end up with less readable
#   code, IMHO, e.g.:
#     symlink_overlay_dir "../to/a/subdir" "path/elsewhere/subdir"
# - And changing the call when sourcep is relative but targetp is
#   a full path doesn't make sense, because then what is sourcep
#   relative to? If it's relative to the current working directory,
#   that could also make for less readable code, e.g.,
#     # Assume `pwd` is /Users/user/some/other/path/completely,
#     # then the previous example could either be written like this:
#     symlink_overlay_dir "../../../../path/to/subdir" "${HOME}/subdir"
#     # Or like this:
#     ( cd ~ && symlink_overlay_dir "path/to/subdir" "${HOME}/subdir" )
#     # Neither or which is very appealing.
#
# Some more notes:
#
# - When sourcep is relative, we verified the path from the current
#   directory ($(pwd)), but the symlink being created might exist in
#   a subdirectory of this directory, i.e., the relative path for the
#   symlink is different than the one the user specified (because the
#   user specified the path relative to the project directory, not to
#   the target's directory).
#
#   When the target is also relative, we can remove the common path
#   prefix, and then replace uncommon directories with '../' to
#   remake the sourcep path relative to targetp.
#
#   - For example, suppose user's ~/.vim mrconfig 'infuse' specifies
#       symlink_mrinfuse_file 'spell/en.utf-8.add'
#     And assume ~/.vim/.mrinfuse/spell/en.utf-8.add exists.
#     Then this function is called from ~/.vim with
#        sourcep=.mrinfuse/spell/en.utf-8.add
#        targetp=spell/en.utf-8.add
#     which is accurate from the current ~/.vim directory's perspective.
#     But the actual symlink that's created needs to be relative to the
#     target directory, e.g.,
#        ~/.vim/spell/en.utf-8.add -> ../.mrinfuse/spell/en.utf-8.add
#
# - Here's another example, because I had it:
#
#   - When both paths are relative, this function removes the common
#     prefix from both paths and prints the shortest relative path
#     from targetp to sourcep.
#     - E.g., if:
#         sourcep=path/to/a/subdir
#         targetp=path/subdir
#       Then this function prints:
#         $ print_sourcep_relative_targetp file path/to/a/subdir path/subdir
#         to/a/subdir
#       Such that the symlink will be:
#         path/subdir -> to/a/subdir
#     - Similarly, e.g., if:
#         sourcep=foo/bar/baz
#         targetp=foo/bat/qux/quux
#       Then this function prints:
#         $ print_sourcep_relative_targetp file foo/bar/baz foo/bat/qux/quux
#         ../../bar/baz
#       Such that the symlink will be:
#         foo/bat/qux/quux -> ../../bar/baz

print_sourcep_relative_targetp () {
  local srctype="$1"
  local sourcep="$2"
  local targetp="$3"

  if ! is_relative_path "${sourcep}"; then
    # User specified full path, which we won't override.
    # - Note this is generally symlink_overlay_file|_dir only, and not
    #   symlink_mrinfuse_file|_dir, for which user would usually use a
    #   a relative sourcep (though it's not required, it's just unheard
    #   of not to).
    printf "%s" "${sourcep}"

    return 0
  fi

  if ! is_relative_path "${targetp}"; then
    # Check that caller has cd'd to targetp base dir (common
    # symlink_overlay_* flow). If not, switch to full path
    # (e.g., `symlink_mrinfuse_file "file" "/path/to/target"`).
    if ( \
      cd "$(dirname -- "${targetp}")" 2> /dev/null \
        && test -e "${sourcep}" \
    ); then
      printf "%s" "${sourcep}"
    else
      realpath -- "${sourcep}"
    fi

    return 0
  fi

  # Both paths are relative. Remove common prefix from both paths
  # and print shortest relative path from targetp to sourcep.
  # - See examples above.

  local common_prefix
  common_prefix="$(print_common_path_prefix "${sourcep}" "${targetp}")"

  # "Walk off" the release target path, directory by directory, ignoring
  # any '.' current directory in the path, and complaining on '..'
  # (because hard and unnecessary). For each directory, accumulate an
  # additional '..' to the source prefix, to walk from the target location
  # back to the current directory perspective (which is the perspective of
  # sourcep as specified by the user, which we need to modify here).

  local walk_off
  walk_off="${targetp#${common_prefix}}"
  if [ "${srctype}" = 'file' ]; then
    walk_off="$(dirname -- "${walk_off}")"
  fi

  local prent_walk
  while [ "${walk_off}" != '.' ]; do
    local curname="$(basename -- "${walk_off}")"

    if [ "${curname}" = '..' ]; then
      >&2 error "ERROR: A relative target cannot use double-dots in its path (No \`..\`)"
      >&2 error "- source: ${sourcep}"
      >&2 error "- target: ${targetp}"

      return 1
    fi
    [ "${curname}" != '.' ] && prent_walk="../${prent_walk}"
    walk_off="$(dirname -- "${walk_off}")"
  done

  if [ "${srctype}" = 'dir' ]; then
    # Remove one step for the target file itself! I.e., the first time through
    # the while loop above was for the target itself, which we did not want to
    # overlook with a $(dirname -- ...) first, because we still wanted to sanity
    # check that the target itself is not '.' or '..'! So we consider the target
    # directory in the while loop, but then we retract that consideration here.
    prent_walk="${prent_walk#../}"
  fi

  sourcep="${prent_walk}${sourcep#${common_prefix}}"

  echo "${sourcep}"
}

# SAVVY: S/O article gives following regex to find commone prefix:
#     printf ... | sed 'H;$!d;g;s/\`.\(.*\/\).*\x0\1.*/\1/'
# - THANX: https://stackoverflow.com/a/6973268
# - REFER: From `man sed`/`man gsed` and https://gnu.org:
#   H   Append a newline character followed by the contents
#       of the pattern space to the hold space
#   $   Select the last line of input
#   !   Apply the function only to the lines that are not
#       selected by the address(es)
#         (so apply `d` to all but the last line)
#   d   Delete the pattern space and start the next cycle
#         (delete all but the last line)
#   g   Replace the contents of the pattern space with the
#       contents of the hold space
#         (a newline plus the original printf)
#   s/.../
#       \`  Matches at the beginning of a buffer for multi-line
#           pattern (like ^ matches start of input line)
#           https://www.gnu.org/software/sed/manual/html_node/Regexp-Addresses.html#Regexp-Addresses
#           - The S/O articles uses this, but I think it only
#             works for s/<regexp>/M multi-line mode,
#             and doesn't seem to break if we remove it.
#             Though neither does replacing it with `^` change
#             the behavior.
#       .   The first dot matches the newline from `H`
#       \(.*\/\).*\x0\1.*/\1
#           Find and emit the largest common prefix
# - SAVVY: The simplest sed would typically always work for you:
#     sed 's/\(.*\/\).*\x0\1.*/\1/'
#   but the more complicated pattern handles newlines (not that
#   you really want newlines in your paths, but whatever, we
#   won't yuck your yum... and it shows off our `sed` skills,
#   even though this author is not quite clear on the `H;$!d;g`
#   though I think it assembles what would be separate lines
#   (because of possible newlines in the inputs) into a single
#   sed input).
# - ALTLY: Without the null byte trick, we could use newlines,
#   and the `N` sed command which appends (newline plus content)
#   the next line of input, i.e., combine sourcep and targetp
#   into single input:
#     printf "%s\n%s\n" "${sourcep}" "${targetp}" \
#       | sed -e 'N;s/^\(.*\).*\n\1.*$/\1/'
# - TRYME: Add this to fcn. for runtime CPYST:
#       >&2 cat <<EOF
#     printf '%s\\0%s\\n' "${sourcep}" "${targetp}" \
#     | $(gnu_sed) 'H;\$!d;g;s/\\\`.\\(.*\\/\\).*\\x0\\1.*/\\1/' \
#     | head -n 1 \
#     | tr -d '\\n'
#     EOF

print_common_path_prefix () {
  local sourcep="$1"
  local targetp="$2"

  gnu_sed () {
    command -v gsed || command -v sed
  }

  # Note POSIX printf recognizes \0 but not \x0
  printf '%s\0%s\n' "${sourcep}" "${targetp}" \
    | $(gnu_sed) 'H;$!d;g;s/\`.\(.*\/\).*\x0\1.*/\1/' \
    | head -n 1 \
    | tr -d '\n'
}

symlink_adjusted_source_verify_target () {
  local targetp="$1"
  # Double-check that print_sourcep_relative_targetp worked!
  if [ ! -e "${targetp}" ]; then
    >&2 error "ERROR: The target symlink is broken at: ${targetp}"

    return 1
  fi

  return 0
}

makelink_clobber_typed () {
  local srctype="$1"
  local sourcep="$2"
  local targetp="$3"
  local symlink="$4"

  # Check that the source file or directory exists.
  # - This may interrupt the flow if errexit.
  if ! symlink_verify_source "${sourcep}" "${srctype}" "${targetp}"; then

    return 1
  fi

  local origp="${sourcep}"
  if ! sourcep="$(print_sourcep_relative_targetp "${srctype}" "${sourcep}" "${targetp}")"; then

    return 1
  fi

  local errcode
  # Check if target does not exist (and be sure not broken symlink).
  if [ ! -e "${targetp}" ] && [ ! -h "${targetp}" ]; then
    if ! makelink_create_informative "${srctype}" "${sourcep}" "${targetp}" "${symlink}"; then

      return 1
    fi
  else
    if ! makelink_update_informative "${srctype}" "${sourcep}" "${targetp}" "${symlink}"; then

      return 1
    fi
  fi

  if [ "${origp}" != "${sourcep}" ] && ! is_relative_path "${sourcep}"; then
    local info_msg
    info_msg="  Used absolute path  $(font_highlight "${sourcep}")"

    info "${info_msg}"
  fi

  if ! symlink_adjusted_source_verify_target "${targetp}"; then

    return 1
  fi
}

# ***

symlink_file_clobber () {
  local sourcep="$1"
  local targetp="${2:-$(basename -- "${sourcep}")}"

  makelink_clobber_typed 'file' "${sourcep}" "${targetp}" '-s'
}

# NOTE: (lb): I have nothing that calls symlink_dir_clobber,
#       but it's provided to complement symlink_file_clobber.
symlink_dir_clobber () {
  local sourcep="$1"
  local targetp="${2:-$(basename -- "${sourcep}")}"

  makelink_clobber_typed 'dir' "${sourcep}" "${targetp}" '-s'
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

symlink_overlay_typed () {
  local srctype="$1"
  local sourcep="$2"
  local targetp="${3:-$(basename -- "${sourcep}")}"

  # At this point, expect targetp exists relative to the current
  # working directory.
  # - Uses CLI params to check -s/--safe or -f/--force.
  ensure_symlink_target_overwritable "${srctype}" "${sourcep}" "${targetp}"

  makelink_clobber_typed "${srctype}" "${sourcep}" "${targetp}" '-s'
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

symlink_overlay_path () {
  local srctype="$1"
  local sourcep="$2"
  local targetp="${3:-$(basename -- "${sourcep}")}"

  params_register_defaults

  # Caller cd'ed us to "${MR_REPO}".
  # - But cd again to target base dir if relative sourcep, but
  #   absoluete target, so we can truly verify if sourcep exists.
  # - See comments atop print_sourcep_relative_targetp for more.
  local before_cd="$(pwd -L)"
  if is_relative_path "${sourcep}" \
    && ! is_relative_path "${targetp}"; then
    # So that relative sourcep works.
    cd "$(dirname -- "${targetp}")"
  fi

  symlink_overlay_typed "${srctype}" "${sourcep}" "${targetp}"

  cd "${before_cd}"
}

symlink_overlay_file () {
  symlink_overlay_path 'file' "$@"
}

symlink_overlay_dir () {
  symlink_overlay_path 'dir' "$@"
}

# ***

# USAGE: Use full paths but create relative symlink.
#
# - E.g., calling
#
#     symlink_overlay_path_rel "${HOME}/path/to/foo" "${HOME}/foo"
#
#   creates the symlink
#
#     /Users/user/foo -> path/to/foo
#
# This lets us keep the convention that the regular
# symlink_overlay_file and symlink_overlay_dir do
# not modify sourcep or targetp if a full path.
#
# - The previous alternative to this function was to `cd` first,
#   e.g.,
#
#     ( cd && symlink_overlay_path_rel "path/to/foo" "foo" )

symlink_overlay_path_rel () {
  local srctype="$1"
  local sourcep="$2"
  local targetp="${3:-$(basename -- "${sourcep}")}"

  params_register_defaults

  if is_relative_path "${sourcep}"; then
    sourcep="$(realpath -- "${sourcep}")"
  fi

  if is_relative_path "${targetp}"; then
    targetp="$(realpath -- "${targetp}")"
  fi

  local common_prefix
  common_prefix="$(print_common_path_prefix "${sourcep}" "${targetp}")"
  sourcep="${sourcep#${common_prefix}}"
  targetp="${targetp#${common_prefix}}"

  local before_cd="$(pwd -L)"

  cd "${common_prefix}"

  symlink_overlay_typed "${srctype}" "${sourcep}" "${targetp}"

  cd "${before_cd}"
}

symlink_overlay_file_rel () {
  symlink_overlay_path_rel 'file' "$@"
}

symlink_overlay_dir_rel () {
  symlink_overlay_path_rel 'dir' "$@"
}

# ***

# CXREF: For hard-linking, see link_hard:
#   ~/.kit/git/ohmyrepos/lib/link-hard.sh

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

symlink_overlay_file_first_handler () {
  local optional="$1"
  local targetp="$2"
  shift 2

  local found_one=false

  local sourcep
  for sourcep in "$@"; do
    if [ -e ${sourcep} ]; then
      symlink_overlay_file "${sourcep}" "${targetp}"
      found_one=true

      break
    fi
  done

  if ! ${found_one} && [ "${optional}" -eq 0 ] ; then
    >&2 warn "Did not find existing source file to symlink as: ${targetp}"

    return 1
  fi
}

symlink_overlay_file_first () {
  symlink_overlay_file_first_handler '0' "$@"
}

symlink_overlay_file_first_optional () {
  symlink_overlay_file_first_handler '1' "$@"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# Find proper .mrinfuse/ path

# Prints relative path to .mrinfuse/ dir found in or above start_dir.
mrinfuse_findup () {
  local start_dir="$1"

  if [ -n "${start_dir}" ]; then
    start_dir="${start_dir%%/}/"

    cd "${start_dir}"
  fi

  # Search from this directory upwards looking for .mrinfuse/ dir.
  # - We could technically walk up until root ('/') but for we also
  #   don't want to suggest that the user should put a '.mrinfuse/'
  #   directory at '/.mrinfuse' or under '/home' (or '/Users'), so
  #   we won't. (Though we still check root in case this function
  #   not run from under user home.)
  local dirpath=""
  while [ -z "${dirpath}" ] || [ "$(realpath -- "${dirpath}")" != '/' ]; do
    if [ -d "${dirpath}${MRT_INFUSE_DIR:-.mrinfuse}" ]; then
      printf "%s" "${start_dir}${dirpath}"

      return 0
    fi

    if [ -n "${dirpath}" ] && [ "$(realpath -- "${dirpath}")" = "${HOME}" ]; then
      # Not found at ~/.mrinfuse, and not walking up further.

      return 1
    fi

    dirpath="${dirpath}../"
  done

  return 1
}

# USAGE: Store private files under a directory named .mrinfuse/
# located in the same directory as the project (MR_REPO), or along
# the path between the project and user home (including user home).
# 
# - Within the .mrinfuse/ directory, mimic the directory hierarchy
#   leading to the symlink target.
#
# - For instance, suppose you had a project at:
#
#     ~/work/acme/dynamite/
#
#   and you created (or symlinked) a .mrinfuse/ path
#   alongside it:
#
#     ~/work/acme/.mrinfuse/
#
#   then you would store your private symlink assets
#   under a dynamite/ directory within .mrinfuse/:
#
#     ~/work/acme/.mrinfuse/dynamite/
#
# - Continuing that example, if you wanted to 'infuse'
#   an ignore file, create one:
#
#     ~/work/acme/.mrinfuse/dynamite/_ignore
#
#   then symlink it from your mrconfig, e.g.,:
#
#     [$HOME/work/acme/dynamite]
#     infuse = symlink_mrinfuse_file "_ignore" ".ignore"
#
#   and finally call `mr`:
#
#     mr -d ~/work/acme/dynamite infuse
#
#   to create the symlink:
#
#     ~/work/acme/dynamite/.ignore -> ../.mrinfuse/dynamite/_ignore
#
# USAGE: You can store assets in separate .mrinfuse/ paths using
# one .mrinfuse/ per ancestor directory, and also by including
# a .mrinfuse/ path within a .mrinfuse/ directory (so-called
# *descendency support*).
#
# This enables you to keep different assets in separate repos,
# e.g., one for private files, and one you might publish to GH.
#
# - This function searches upwards for one or more .mrinfuse/
#   until it finds one that contains the desired infuse asset.
#
# - This function always searches *downwards* into a .mrinfuse/
#   if that .mrinfuse/ also contains its own .mrinfuse/ directory.
#
# - This function will search downward whenever possible before
#   continuing upward.
#
# - The two features let you more easily combine assets from
#   multiple sources.
#
# - The descendency support, in particular, is one way to solve
#   the problem of supporting multiple .mrinfuse/ assets for
#   home directory symlinks.
#
#   - E.g., suppose you create the two symlinks:
#
#       ~/.mrinfuse -> ~/my/private/home
#       ~/my/private/home/.mrinfuse -> ~/my/fallback/home
#
#     Where the latter is also:
#
#       ~/.mrinfuse/.mrinfuse -> ~/my/fallback/home
#
#     Then the symlink function will first inspect
#     ~/.mrinfuse for the asset, and if not found
#     therein, will next check ~/.mrinfuse/.mrinfuse
#
#   - Use case: Wire ~/.mrinfuse to your own private repo,
#     and they use ~/.mrinfuse/.mrinfuse to include assets
#     from another project.
#
#     - Previously, one would only be allowed to wire
#       a single ~/.mrinfuse, without the descendency option,
#       and if you wanted to include assets from another repo,
#       you'd have to include them in the top-level ~/.mrinfuse.
#       E.g., if you wanted to use ~/my/fallback/home/foo, you
#       could make a symlink:
#         ~/my/private/home/foo -> ~/my/fallback/home/foo
#       But now you can just use a single embedded .mrinfuse/
#       symlink
#         ~/my/private/home/.mrinfuse -> ~/my/fallback/home
#       and not have to worry about wiring individual files.

# Prints the found path, if any, to stdout.
path_to_mrinfuse_resolve () {
  local fpath="$1"

  local canonicalized

  if ! is_relative_path "${fpath}"; then
    canonicalized="${fpath}"
  else
    # Produce a relative symlink path.
    local mrinfuse_path=""
    local first_path=""

    local repo_path_n_sep
    if [ -n "${MR_REPO}" ]; then
      repo_path_n_sep="${MR_REPO}/"
    else
      # So dev can source this script and call its fcns directly.
      >&2 warn "ALERT: No MR_REPO specified (assuming local directory)"

      repo_path_n_sep="$(pwd -L)/"
    fi

    local curr_mrinfuse_root
    if ! curr_mrinfuse_root="$(mrinfuse_findup)"; then
      >&2 error "Cannot symlink_mrinfuse_* because .mrinfuse/ not found up path"
      >&2 error "- start: $(pwd -L)"
      >&2 error "- target: ${MRT_INFUSE_DIR:-.mrinfuse}/.../$(basename -- "$(pwd)")/${fpath}"

      return 1
    fi

    set_mrinfuse_path () {
      local mrinfuse_root="$1"
      local mrinfuse_hole="$2"

      if [ -n "${mrinfuse_root}" ]; then
        mrinfuse_full=$(realpath -- "${mrinfuse_root}")
      else
        mrinfuse_full=$(realpath -- '.')
      fi

      local relative_path=${repo_path_n_sep#"${mrinfuse_full}"/}

      if [ "${relative_path}" != "${repo_path_n_sep}" ]; then
        mrinfuse_path="${mrinfuse_root}${MRT_INFUSE_DIR:-.mrinfuse}/${mrinfuse_hole}${relative_path}${fpath}"
      else
        # Because repo_path_n_sep logical and mrinfuse_full from realpath,
        # the two paths might be on different trees. E.g., if logical path
        # is under user home but symlinks mounted device under /Volumes.
        mrinfuse_path="${repo_path_n_sep}${MRT_INFUSE_DIR:-.mrinfuse}/${mrinfuse_hole}${fpath}"
      fi
    }

    # See comments above for how .mrinfuse/ descendency works.
    local curr_mrinfuse_hole=""
    local next_mrinfuse_hole="${MRT_INFUSE_DIR:-.mrinfuse}/"

    while true; do
      set_mrinfuse_path "${curr_mrinfuse_root}" "${curr_mrinfuse_hole}"

      if [ -e "${mrinfuse_path}" ]; then
        # MAYBE/2020-01-23: Option to return full path?
        #                     canonicalized=$(realpath -- "${mrinfuse_path}")
        #                   - I like the shorter relative path.
        canonicalized="${mrinfuse_path}"

        break
      fi

      if [ -z "${first_path}" ]; then
        first_path="${mrinfuse_path}"
      fi

      if [ -d "${curr_mrinfuse_root}${next_mrinfuse_hole}/" ]; then
        # Look down .mrinfuse/ rabbit hole.
        curr_mrinfuse_hole="${next_mrinfuse_hole}"
        next_mrinfuse_hole="${curr_mrinfuse_hole}${MRT_INFUSE_DIR:-.mrinfuse}/"
      else
        # Look upwards for .mrinfuse/ in ancestor.
        local mrinfuse_parent="${curr_mrinfuse_root}../"
        if ! curr_mrinfuse_root="$(mrinfuse_findup "${mrinfuse_parent}")"; then

          break
        fi
        # else, keep looking upward.
        curr_mrinfuse_hole=""
        next_mrinfuse_hole="${MRT_INFUSE_DIR:-.mrinfuse}/"
      fi
    done
  fi

  if [ -z "${canonicalized}" ]; then
    # Choose path from first .mrinfuse/ found (path doesn't
    # exist, but ${optional} might be enabled).
    canonicalized="${first_path}"
  fi

  echo "${canonicalized}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

symlink_mrinfuse_typed () {
  local srctype="$1"
  local optional="$2"
  local lnkpath="$3"
  local targetp="${4:-${lnkpath}}"

  params_register_defaults

  local before_cd="$(pwd -L)"
  cd "${MR_REPO:-.}"

  local sourcep
  if ! sourcep="$(path_to_mrinfuse_resolve "${lnkpath}")"; then

    return 1
  fi

  if [ ! -e "${sourcep}" ]; then
    if [ "${optional}" -eq 0 ]; then
      >&2 warn "Non-optional symlink source not found: ${sourcep} [relative to ${MR_REPO:-.}]"

      return 1
    fi

    return 0
  fi

  # HSTRY/2024-07-08: Until now, would use relative link, e.g.,
  # ../../.mrinfuse/foo. But with new descendency feature, the links can
  # be meaningless, e.g., ../../../.mrinfuse/.mrinfuse/.mrinfuse/foo. So
  # new default is to expand .mrinfuse/ links so user knows what target
  # really is.
  if ${MRT_MRINFUSE_EXPAND_LINK:-true}; then
    sourcep="$(realpath -- "${sourcep}")"
  fi

  symlink_overlay_typed "${srctype}" "${sourcep}" "${targetp}"

  cd "${before_cd}"
}

# ***

symlink_mrinfuse_file () {
  symlink_mrinfuse_typed 'file' '0' "$@"
}

symlink_mrinfuse_file_optional () {
  symlink_mrinfuse_typed 'file' '1' "$@"
}

symlink_mrinfuse_dir () {
  symlink_mrinfuse_typed 'dir' 0 "$@"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

symlink_mrinfuse_file_first_handler () {
  local optional="$1"
  local targetp="$2"
  shift 2

  local found_one=false

  local lnkpath
  for lnkpath in "$@"; do
    local sourcep
    if ! sourcep="$(path_to_mrinfuse_resolve ${lnkpath})"; then

      return 1
    fi

    if [ -e "${sourcep}" ]; then
      symlink_overlay_file "${sourcep}" "${targetp}"
      found_one=true

      break
    fi
  done

  if ! ${found_one} && [ "${optional}" -eq 0 ] ; then
    >&2 warn "Did not find existing source file to symlink as: ${targetp}"

    return 1
  fi
}

symlink_mrinfuse_file_first () {
  symlink_mrinfuse_file_first_handler '0' "$@"
}

symlink_mrinfuse_file_first_optional () {
  symlink_mrinfuse_file_first_handler '1' "$@"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main () {
  source_deps
  # Caller will call functions explicitly as appropriate.
}

# Only source deps when not included by OMR.
# - This supports user sourcing this file directly,
#   and it helps OMR avoid re-sourcing the same files.
if [ -z "${MR_CONFIG}" ]; then
  main "$@"
fi

unset -f main
unset -f source_deps

