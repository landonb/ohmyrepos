#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

source_deps () {
  # Load the logger library, from github.com/landonb/sh-logger.
  # - The .mrconfig-omr file uses SHLOGGER_BIN to update PATH.
  #   - Or if your script sources this file directly, just be
  #     sure the sh-logger/bin is on PATH.
  # - This also implicitly loads the colors.sh library.
  # - Note that .mrconfig-omr sets PATH so OMR's deps/ copy found.
  . logger.sh

  # Load: print_unresolved_path/realpath_s
  . print-unresolved-path.sh
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
    case $1 in
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
        MR_GIT_AUTO_COMMIT_MSG="${1}"
        shift
        ;;
      --message)
        shift
        MR_GIT_AUTO_COMMIT_MSG="${1}"
        shift
        ;;
      *)
        # Test if starts with prefix and assume an --option.
        # User can -- to specify filenames that start with dash.
        if [ "${1#-}" != "$1" ]; then
          fatal "ERROR: Unrecognized argument: $1"

          exit 1  # Be mean.
        fi
        shift
        ;;
    esac
  done
}

myrepostravel_opts_parse () {
  params_register_defaults
  params_register_switches "${@}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# MAYBE/2019-10-26 15:20: Could move these environ and echo fcns. to new lib file.

_debug_spew_and_die () {
  #
  local testing=false
  # Uncomment to spew vars and exit:
  testing=true
  if $testing; then
    >&2 echo "MR_REPO=${MR_REPO}"
    >&2 echo "MR_CONFIG=${MR_CONFIG}"
    >&2 echo "MRT_LINK_SAFE=${MRT_LINK_SAFE}"
    >&2 echo "MRT_LINK_FORCE=${MRT_LINK_FORCE}"
    >&2 echo "current dir: $(pwd)"

    exit 1
  fi
}

infuser_set_envs () {
  local repodir="${1:-"${MR_REPO}"}"

  # Ensure MR_REPO set so script can be called manually,
  # outside context of myrepos.
  export MR_REPO="${repodir}"

  # Note that if '.vim/.mrconfig' is absent, myrepos will have most likely set
  # MR_CONFIG=~/.mrconfig; but if it's present, then MR_CONFIG=~/.vim/.mrconfig.
  # So that the rest of the script works properly, force the MR_CONFIG value.
  export MR_CONFIG="${MR_CONFIG:-"${MR_REPO}/.mrconfig"}"
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
  myrepostravel_opts_parse "${@}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

font_emphasize () {
  echo "$(attr_emphasis)${1}$(attr_reset)"
}

font_highlight () {
  echo "$(fg_lightorange)${1}$(attr_reset)"
}

# ***

font_info_checked () {
  echo "$(fg_lightyellow)${1}$(attr_reset)"
}

font_info_created () {
  echo "$(fg_lightcyan)${1}$(attr_reset)"
}

font_info_updated () {
  echo "$(fg_lavender)${1}$(attr_reset)"
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

  error "Unreachable code!"

  exit 1
}

file_exists_and_not_symlink () {
  [ -e "${1}" ] && [ ! -h "${1}" ]
}

file_exists_and_not_linked_to_source () {
  [ -e "${1}" ] && ! [ "${1}" -ef "${2}" ]
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# Source verification.

symlink_verify_source () {
  local sourcep="$1"
  local srctype="$2"

  if [ "${srctype}" = 'file' ]; then
    if [ ! -f "${sourcep}" ]; then
      error "mrt: Failed to create symbolic link!"
      error "  Did not find linkable source file at:"
      error "    ${sourcep}"
      error "  From our perch at:"
      error "    $(pwd)"

      exit 1
    fi
  elif [ "${srctype}" = 'dir' ]; then
    if [ ! -d "${sourcep}" ]; then
      error "mrt: Failed to create symbolic link!"
      error "  Did not find linkable source directory at:"
      error "    ${sourcep}"
      error "  From our perch at:"
      error "    $(pwd)"

      exit 1
    fi
  else
    fatal "Not a real srctype: ${srctype}"

    exit 2
  fi
}

# NOTE: Orphan function (not called but this project, or any of author's).
ensure_source_file_exists () {
  symlink_verify_source "$1" 'file'
}

# NOTE: Orphan function (not called but this project, or any of author's).
ensure_source_dir_exists () {
  symlink_verify_source "$1" 'dir'
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

fail_target_exists_not_link () {
  local targetp="$1"
  local link_type="$2"

  error "mrt: Failed to create ${link_type}!"
  error "  Target exists and is not recognized by ohmyrepos."
  error "  Please examine the file:"
  error "    ${targetp}"
  error "  Relative to:"
  error "    $(pwd)"
  error "Use -f/--force, or -s/--safe, or remove the file," \
    "and try again, or stop trying."

  exit 1
}

safely_backup_or_die_if_not_forced () {
  local targetp="$1"
  local link_type="$2"

  if [ ${MRT_LINK_SAFE:-1} -eq 0 ]; then
    safe_backup_existing_target "${targetp}"
  elif [ ${MRT_LINK_FORCE:-1} -ne 0 ]; then
    fail_target_exists_not_link "${targetp}" "${link_type}"
  fi
}

# ***

ensure_symlink_target_overwritable () {
  local targetp="$1"

  file_exists_and_not_symlink "${targetp}" || return 0

  safely_backup_or_die_if_not_forced "${targetp}" 'symlink'
}

ensure_hardlink_target_overwritable () {
  local targetp="$1"
  local sourcep="$2"

  file_exists_and_not_linked_to_source "${targetp}" "${sourcep}" || return 0

  safely_backup_or_die_if_not_forced "${targetp}" 'hard link'
}

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

  eval "/bin/ln ${symlink} '${sourcep}' '${targetp}'" || (
    local link_type='hard link'
    [ -n "${symlink}" ] && link_type='symlink'

    error "Failed to create ${link_type} at: ${targetp}"

    exit 1
  )

  # Created new symlink.
  local info_msg
  info_msg="$( \
    symlink_get_msg_informative \
      "$(font_info_created "Created")" "${srctype}" "${targetp}" "${symlink}" \
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
      "$(font_info_updated "Updated")" "${srctype}" "${targetp}" "${symlink}" \
    )"
  elif [ -f "${targetp}" ]; then
    # SAVVY: -ef true when checking symlink and its link path.
    if ! [ "${sourcep}" -ef "${targetp}" ]; then
      # For how this function is used, the code would already have checked
      # that the user specified -f/--force; or else the code didn't care to
      # ask. See:
      #   safely_backup_or_die_if_not_forced.
      info_msg=" Clobbered file with ${link_type} $(font_highlight $(realpath_s "${targetp}"))"
    else
      info_msg="$(symlink_get_msg_informative \
        "$(font_info_checked "Checked")" "${srctype}" "${targetp}" "${symlink}" \
      )"
      info "${info_msg}"

      return 0
    fi
  else
    fatal "Unexpected path: target neither ${link_type} nor file, but exists?"

    exit 1
  fi

  # Note if target symlinks to a file, we can overwrite with force, e.g.,
  #   /bin/ln -sf source/path target/path
  # but if the target exists and is a symlink to a directory instead,
  # the new symlink gets created inside the referenced directory.
  # To handle either situation -- the existing symlink references
  # either a file or a directory -- remove the target first.
  command rm -- "${targetp}"

  eval "/bin/ln ${symlink} '${sourcep}' '${targetp}'" || (
    error "Failed to replace symlink at: $(realpath_s "${targetp}")"

    exit 1
  )

  info "${info_msg}"
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
  info_msg=" ${what} $( \
    font_emphasize ${srctype}) ${link_type} $(\
      font_highlight $( \
        realpath_s "${targetp}"
      )${targetd}
    )"

  printf "%s" "${info_msg}"
}

# ***

# WONKY, SORRY: If source is relative, we verified source exists from the
# current directory ($(pwd)), but the symlink being created might exist in
# a subdirectory of this directory, i.e., the relative path for the symlink
# is different that the one the user specified (because the user specified
# the path relative to the project directory, not to the target's directory).
#
# If the target is also relative, we can count how many subdirectories away
# it is and prefix the source path accordingly.
#
# - For example, suppose user's ~/.vim/.mrconfig infuser specifices
#         symlink_mrinfuse_file 'spell/en.utf-8.add'
#   Then this function is called from ~/.vim with
#          source=.mrinfuse/spell/en.utf-8.add
#   and with
#          target=spell/en.utf-8.add,
#   which is accurate from the current ~/.vim directory's perspective.
#   But the actual symlink that's placed either needs to be fully
#   resolved, or it needs to be relative to the target directory, e.g.,
#          ~/.vim/spell/en.utf-8.add → ../.mrinfuse/spell/en.utf-8.add
#       or ~/.vim/spell/en.utf-8.add → ~/.vim/.mrinfuse/spell/en.utf-8.add
#
# This is not too hard (a little wonky, IMHO, but makes the .mrconfig
# more readable, I suppose).
# - (lb): But if target path is absolute, I did not go to the trouble of
#         accommodating that (other than to raise an error-issue).
#         (There's not much of a use case for handling relative source
#         but specifying an absolute target; if the target needs to be
#         an absolute path, there's no reason not to also specify an
#         absolute path for the source.)
#   - ALTLY/2024-03-03: The caller now resolves relative source when
#     target is absolute. This lets user call symlink_mrinfuse_file
#     with a relative source path and an absolute target path... and
#     I cannot think of a use case where this would be undesirable.
#     - This allows user to simplify, e.g.,
#         symlink_overlay_file \
#           $(realpath -- "${MR_REPO}/../.mrinfuse/some-file") \
#           /path/to/target/some-file
#       With:
#         symlink_mrinfuse_file some-file /path/to/target/some-file
#
# Note this fcn. prints the path to stdout, so errors should go to stderr.
symlink_adjust_source_relative () {
  local srctype="$1"
  local sourcep="$2"
  local targetp="$3"

  if ! is_relative_path "${sourcep}"; then
    echo "${sourcep}"

    return 0
  fi

  if ! is_relative_path "${targetp}"; then
    # ISOFF/2024-03-03: See comment above. We can allow this.
    # 
    #  >&2 error "Cannot link absolute target using a relative source path"
    #  >&2 error "- source: ${sourcep}"
    #  >&2 error "- target: ${targetp}"
    #
    #  exit 1

    realpath -- "${sourcep}"

    return 0
  fi

  # "Walk off" the release target path, directory by directory, ignoring
  # any '.' current directory in the path, and complaining on '..'
  # (because hard and unnecessary). For each directory, accumulate an
  # additional '..' to the source prefix, to walk from the target location
  # back to the current directory perspective (which is the perspective of
  # sourcep as specified by the user, which we need to modify here).

  local walk_off
  walk_off="${targetp}"
  if [ "${srctype}" = 'file' ]; then
    walk_off="$(dirname -- "${targetp}")"
  fi

  local prent_walk
  while [ "${walk_off}" != '.' ]; do
    local curname="$(basename -- "${walk_off}")"
    if [ "${curname}" = '..' ]; then
      >&2 error "A relative target cannot use dot dots in its path (No \`..\`)"
      >&2 error "- source: ${sourcep}"
      >&2 error "- target: ${targetp}"

      exit 1
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

  sourcep="${prent_walk}${sourcep}"

  echo "${sourcep}"
}

symlink_adjusted_source_verify_target () {
  local targetp="$1"
  # Double-check that symlink_adjust_source_relative worked!
  if [ ! -e "${targetp}" ]; then
    error "The target symlink is broken at: ${targetp}"

    exit 1
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
  symlink_verify_source "${sourcep}" "${srctype}"

  local origp="${sourcep}"
  sourcep="$(symlink_adjust_source_relative "${srctype}" "${sourcep}" "${targetp}")"

  local errcode
  # Check if target does not exist (and be sure not broken symlink).
  if [ ! -e "${targetp}" ] && [ ! -h "${targetp}" ]; then
    makelink_create_informative "${srctype}" "${sourcep}" "${targetp}" "${symlink}"
  else
    makelink_update_informative "${srctype}" "${sourcep}" "${targetp}" "${symlink}"
  fi

  if [ "${origp}" != "${sourcep}" ] && ! is_relative_path "${sourcep}"; then
    local info_msg
    info_msg="  Used absolute path  $(font_highlight ${sourcep})"

    info "${info_msg}"
  fi

  symlink_adjusted_source_verify_target "${targetp}"
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

  params_register_defaults

  # Caller cd'ed us to "${MR_REPO}".

  # Uses CLI params to check -s/--safe or -f/--force.
  ensure_symlink_target_overwritable "${targetp}"

  makelink_clobber_typed "${srctype}" "${sourcep}" "${targetp}" '-s'
}

symlink_overlay_file () {
  symlink_overlay_typed 'file' "${@}"
}

symlink_overlay_dir () {
  symlink_overlay_typed 'dir' "${@}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

hardlink_overlay_typed () {
  local srctype="$1"
  local sourcep="$2"
  local targetp="${3:-$(basename -- "${sourcep}")}"

  params_register_defaults

  # Caller cd'ed us to "${MR_REPO}".

  # Uses CLI params to check -s/--safe or -f/--force.
  ensure_hardlink_target_overwritable "${targetp}" "${sourcep}"

# SAVVY/2022-10-10: You should probably call `link_hard` instead.
# - hardlink_overlay_file has parity with symlink_overlay_file:
#   It's similarly named, and it honors --force and --safe options.
# - But link_hard checks the inode and reports when file is already
#   hard-linked.
#   - And you probably don't want to use --force to clobber an
#     existing file, but would probably want to know if two
#     versions of what should be the same file have diverged.
# 
# - MAYBE/2022-10-10: Remove this function.
#   - I'm pretty sure that this function doesn't do anything
#     that `link_hard` doesn't do, except support --force and
#     --safe, but I'm also pretty sure we don't need those.
#
#  hardlink_overlay_file () {
#    hardlink_overlay_typed 'file' "${@}"
#  }

  makelink_clobber_typed "${srctype}" "${sourcep}" "${targetp}"
}

# SAVVY/2022-10-10: This fcn. is not used by any of the author's projects.
hardlink_overlay_dir () {
  hardlink_overlay_typed 'dir' "${@}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

symlink_overlay_file_first_handler () {
  local optional="$1"
  local targetp="$2"
  shift 2

  local found_one=false

  local sourcep
  for sourcep in "${@}"; do
    if [ -e ${sourcep} ]; then
      symlink_overlay_file "${sourcep}" "${targetp}"
      found_one=true

      break
    fi
  done

  if ! ${found_one} && [ "${optional}" -eq 0 ] ; then
    warn "Did not find existing source file to symlink as: ${targetp}"

    exit 1
  fi
}

symlink_overlay_file_first () {
  symlink_overlay_file_first_handler '0' "${@}"
}

symlink_overlay_file_first_optional () {
  symlink_overlay_file_first_handler '1' "${@}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# Resolving magic .mrinfuse/ path.

_info_path_resolve () {
  local relative_path="$1"
  local mrinfuse_path="$2"
  local canonicalized="$3"
  #
  local testing=false
  # Uncomment to spew vars and exit:
  # testing=true
  if $testing; then
    >&2 echo "MR_REPO=${MR_REPO}"
    >&2 echo "MR_CONFIG=${MR_CONFIG}"
    >&2 echo "relative_path=${relative_path}"
    >&2 echo "mrinfuse_path=${mrinfuse_path}"
    >&2 echo "canonicalized=${canonicalized}"
    >&2 echo "current dir: $(pwd)"
    >&2 echo "MRT_LINK_FORCE=${MRT_LINK_FORCE}"
    >&2 echo "MRT_LINK_SAFE=${MRT_LINK_SAFE}"

    exit 1
  fi
}

# ***

# NOTE: Orphan function (not called but this project, or any of author's).
mrinfuse_findup_canonic () {
  # Search from parent of this directory (which is probably $MR_REPO)
  # up to the .mrconfig-containing directory looking for .mrinfuse/.
  local dirpath mr_root
  dirpath="$(dirname -- "$(realpath -- "$(pwd)")")"
  mr_root="$(dirname -- "$(realpath -- "${MR_CONFIG}")")"
  while [ "${dirpath}" != '/' ]; do
    local trypath="${dirpath}/${MRT_INFUSE_DIR:-.mrinfuse}"
    if [ -d "${trypath}" ]; then
      echo "${dirpath}"

      break
    elif [ "${dirpath}" = "${mr_root}" ]; then

      break
    fi
    dirpath="$(dirname -- "${dirpath}")"
  done
}

# Note this fcn. prints the path to stdout, so errors should go to stderr.
mrinfuse_findup () {
  # Search from parent of this directory (which is probably $MR_REPO)
  # up to the .mrconfig-containing directory looking for .mrinfuse/.
  local dirpath=""
  while [ -z "${dirpath}" ] || [ "$(realpath -- "${dirpath}")" != '/' ]; do
    if [ -d "${dirpath}${MRT_INFUSE_DIR:-.mrinfuse}" ]; then
      echo "${dirpath}"

      return 0
    fi
    dirpath="${dirpath}../"
  done

  return 1
}

# CONVENTION: Store private files under a directory named .mrinfuse,
# located in the same directory as the .mrconfig file whose repo config
# calls this function, or located along the oath between the root and repo.
# Under the .mrinfuse directory, mimic the directory alongside the .mrconfig
# file. For instance, suppose you had a config file at:
#   /my/work/projects/.mrconfig
# and you had a public repo underneath that project space at:
#   /my/work/projects/cool/product/
# you would store your private .ignore file at:
#   /my/work/projects/.mrinfuse/cool/product/.ignore
# then your infuse function would be specified in your .mrconfig as:
#   [cool/product]
#   symlink_mrinfuse_file '.ignore'
#
# Note this fcn. prints the path to stdout, so errors should go to stderr.
path_to_mrinfuse_resolve () {
  local fpath="$1"
  local canonicalized

  if is_relative_path "${fpath}"; then
    local relative_path
    local mrinfuse_root
    local mrinfuse_path
    local repo_path_n_sep

    repo_path_n_sep="${MR_REPO}/"

    mrinfuse_root="$(mrinfuse_findup)" || (
      >&2 error "Cannot symlink_mrinfuse_* because .mrinfuse/ not found up path"
      >&2 error "- start: $(pwd)"
      >&2 error "- target: ${MRT_INFUSE_DIR:-.mrinfuse}/.*/$(basename -- "$(pwd)")/${fpath}"

      exit 1
    )

    if [ -n "${mrinfuse_root}" ]; then
      mrinfuse_full=$(realpath -- "${mrinfuse_root}")
    else
      mrinfuse_full=$(realpath -- '.')
    fi

    relative_path=${repo_path_n_sep#"${mrinfuse_full}"/}
    mrinfuse_path="${mrinfuse_root}${MRT_INFUSE_DIR:-.mrinfuse}/${relative_path}${fpath}"

    # MAYBE/2020-01-23: Option to return full path?
    #                     canonicalized=$(realpath -- "${mrinfuse_path}")
    #                   - I like the shorter relative path.
    canonicalized="${mrinfuse_path}"
    # _info_path_resolve "${relative_path}" "${mrinfuse_path}" "${canonicalized}"
  else
    canonicalized="${fpath}"
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
  cd "${MR_REPO}"

  local sourcep
  sourcep="$(path_to_mrinfuse_resolve ${lnkpath})"

  if [ ! -e ${sourcep} ]; then
    if [ "${optional}" -eq 0 ]; then
      warn "Non-optional symlink source not found: ${sourcep} [relative to ${MR_REPO}]"

      exit 1
    fi

    return 0
  fi

  symlink_overlay_typed "${srctype}" "${sourcep}" "${targetp}"

  cd "${before_cd}"
}

# ***

symlink_mrinfuse_file () {
  symlink_mrinfuse_typed 'file' '0' "${@}"
}

symlink_mrinfuse_file_optional () {
  symlink_mrinfuse_typed 'file' '1' "${@}"
}

symlink_mrinfuse_dir () {
  symlink_mrinfuse_typed 'dir' 0 "${@}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

symlink_mrinfuse_file_first_handler () {
  local optional="$1"
  local targetp="$2"
  shift 2

  local found_one=false

  local lnkpath
  for lnkpath in "${@}"; do
    local sourcep
    sourcep="$(path_to_mrinfuse_resolve ${lnkpath})"
    if [ -e ${sourcep} ]; then
      symlink_overlay_file "${sourcep}" "${targetp}"
      found_one=true

      break
    fi
  done

  if ! ${found_one} && [ "${optional}" -eq 0 ] ; then
    warn "Did not find existing source file to symlink as: ${targetp}"

    exit 1
  fi
}

symlink_mrinfuse_file_first () {
  symlink_mrinfuse_file_first_handler '0' "${@}"
}

symlink_mrinfuse_file_first_optional () {
  symlink_mrinfuse_file_first_handler '1' "${@}"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

main () {
  source_deps
  # Caller will call functions explicitly as appropriate.
}

main "$@"
unset -f main
unset -f source_deps

