# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# USAGE: Use remote_set_private for projects that are not published online.
#
# This means the remote URL depends on the remote host name (if using SSH) or
# the local path prefix (if using a local path, such as a mounted USB device).
#
# - You will specify the remote host or local path prefix via environs,
#   and this library function will prepare MR_REPO_REMOTES for the action.
#
# Usage, e.g.,:
#
#   [/path/to/project]
#   lib = remote_set_private
#
# Or, to specify a custom destination directory on 'checkout':
#
#   [/path/to/project]
#   lib = remote_set_private "target-dir"
#
# The `remote_set_private` function will configure MR_REPO_REMOTES
# for use by certain actions, like `checkout` and `wireRemotes`.
#
# You'll need to specify the remote host when running OMR, e.g.,:
#
#   MR_REMOTE=hostname mr -d /path/to/project checkout
#
# You might also need the remote home path, if it's different, e.g.,:
#
#   MR_REMOTE=swamp MR_REMOTE_PATH=/home/kermit mr -d / wireRemotes
#
# Or if you're using a local remote, add its path prefix, e.g.,
#
#   MR_TRAVEL=/media/user/usb-stick MR_REMOTE=usb mr -d /path/to/project checkout
#
# Note as such that `remote_set_private` configures the URL depending on MR_TRAVEL.
#
# - If MR_TRAVEL is unset, the URL prefix is "ssh://${MR_REMOTE}/".
#
# - If MR_TRAVEL is set, the URL prefix is "${MR_TRAVEL}/".
#
# This flexibility lets you avoid hard-coding any URLs into individual
# project 'checkout' actions.

# HSTRY: Without `remote_set_private`, there's a long way to do this, e.g.,
#
#   [/path/to/project]
#   checkout = [ -z ${MR_TRAVEL} ] && fatal 'You must set MR_TRAVEL' ||
#     git clone -o "${MR_REMOTE}" "${MR_TRAVEL}/${MR_REPO}"

remote_set_private () {
  local dst_path="$1"

  if [ "${MR_ACTION}" = "checkout" ]; then
    # E.g., MR_REMOTE=<host>
    if [ -z "${MR_REMOTE}" ]; then
      # Stop on errexit.
      fatal "You must set MR_REMOTE"
    fi
  elif [ "${MR_ACTION}" = "wireRemotes" ] || [ "${MR_ACTION}" = "reportRemotes" ]; then
    if [ -z "${MR_REMOTE}" ]; then
      warn "Skipping remote_set_private b/c no MR_REMOTE: ${MR_REPO}"

      return 0
    fi
  else
    # No-op (nothing needed for this MR_ACTION).
    return 0
  fi

  # CXREF: Reusing functions from travel.sh:
  #   ~/.ohmyrepos/lib/sync-travel-remote.sh

  local rem_path

  if [ -z "${MR_TRAVEL}" ]; then
    # E.g., ssh://<remote>/path/to/repo
    local rem_repo="$(print_path_for_remote_user "${MR_REPO}")"
    local rel_repo="$(lchop_sep "${rem_repo}")"
    rem_path="ssh://${MR_REMOTE}/${rel_repo}"
  else
    # This path is useful for 'checkout', if you need to clone a repo
    # from a local path (such as a USB drive). (Though if you maintain
    # duplicate dev machines, you'll likely clone from the other host;
    # so MR_TRAVEL won't be set, and the if-block runs instead.)
    # - This path is less useful for 'wireRemotes', because the local
    #   path remote is usually a USB drive, which is usually only
    #   temporarily mounted. So you won't be pushing to or pulling
    #   from it often, and when you do, you'll like run the 'travel'
    #   and 'unpack' actions instead, which manage the local path
    #   remote themselves (and do not expect it to be pre-configured).
    # - So really this path supports one typical action:
    #     MR_TRAVEL=/media/user/path mr -d project/ checkout
    #   And isn't going to be useful for any other action.
    #
    # E.g., /media/user/travel/path/to/repo/_0.git
    rem_path="$(git_update_dev_path)"
  fi

  remote_set "${MR_REMOTE}" "${rem_path}" "${dst_path}"
}

