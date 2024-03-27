# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

mr_repo_checkout () {
  if [ -z "${MR_REPO_REMOTES}" ]; then
    >&2 error "ERROR: The MR_REPO_REMOTES environ is unset"
    >&2 error "- Please set MR_REPO_REMOTES directly, or use \`remote_set\` to set it"
    >&2 error "- Or, define a custom 'checkout' action and do something else"

    # Stop on errexit.
    return 1
  fi

  eval "set -- $(echo "${MR_REPO_REMOTES}" | tr -d '\n')"
  local remote_name="$1"
  local remote_url_or_path="$2"
  local dest_dir=""
  # Test if couplet or thruple: If third arg. ends in /, indicates dest. dir;
  # otherwise (if set) is start of next remote name/url[/dest] pair/throuple
  # (which 'wireRemotes' uses, but not 'checkout').
  # - Use POSIX-compliant parameter expansion to test the third arg.
  #   - REFER: https://pubs.opengroup.org/onlinepubs/009695399/utilities/xcu_chap02.html#tag_02_06_02
  # - ALTLY: Use case test, e.g.,:
  #     case $3 in
  #       *"/") dest_dir="$3" ;;
  #     esac
  if [ "${3%/}" != "${3}" ]; then
    dest_dir="$3"
  fi

  # Note this uses `_git_url_according_to_user` to make appropriate URL.
  git_clone_giturl -o "${remote_name}" "${remote_url_or_path}" "${dest_dir}"
}

