#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

pull_latest () {
  local remote_name="$1"
  local remote_branch="$2"
  local version_tag="$3"
  local local_branch="${4:-${remote_branch}}"

  echo "SAVVY: We'll update to the latest tagged version, something like:

    git fetch ${remote_name} --prune
    git checkout ${remote_branch}
    git branch -u ${remote_name}/${remote_branch}
    git pull --ff-only
    local install_version=\"\$(git latest-version-normal)\"
    local install_branch=\"${remote_name}/\${install_version}\"
    git checkout -b \${install_branch} \${install_version} || true
    git checkout \${install_branch}

  - ALTLY: If you want to install a specific version, run \`git tags\`
    and pick the desired tag, then update the 'install' action to call
    this instead:

      pull_latest \"${remote_name}\" \"${remote_branch}\" \"<version-tag>\"
  "

  git fetch ${remote_name} --prune
  git checkout -b ${local_branch} ${remote_name}/${remote_branch} 2> /dev/null || true
  git checkout ${local_branch}
  git branch -u ${remote_name}/${remote_branch}
  git pull --ff-only

  local install_version="${version_tag}"
  # REFER: `git-latest-version-normal` from
  #   https://github.com/landonb/git-smart#💡
  if [ -z "${install_version}" ]; then
    # Note: If the latest tag is in a different branch, you'll see on stderr:
    #   * BWARE: The latest version tag is outside this branch
    # SAVVY: The previous checkout/branch -u/pull is unnecessary unless
    #        no version tag found (and this path not followed).
    #        - But included anyway to *try* to avoid warning, i.e., if
    #          user knows repo is versioned, they can all pull_latest
    #          with the branch name that contains the version, and they'll
    #          avoid the warning.
    #          - But doesn't work for all projects. E.g., Ansible only
    #            tags special "stable-X.X" branches, so unless you want
    #            to periodically have to update the version number manually,
    #            just live with the warning.
    install_version="$( \
      GITNUBS_PREFIX="${GITNUBS_PREFIX}" \
        git latest-version-normal
    )"
    if [ $? -ne 0 ] || [ -z "${install_version}" ]; then
      >&2 echo
      >&2 echo "ERROR: git latest-version-normal failed:"
      >&2 echo
      >&2 echo "  $ GITNUBS_PREFIX=\"${GITNUBS_PREFIX}\" git latest-version-normal"
      >&2 echo "$( \
        GITNUBS_PREFIX="${GITNUBS_PREFIX}" \
          git latest-version-normal 2>&1 \
        | sed 's/^/  /'
      )"
      >&2 echo

      return 1
    fi
  fi

  local prefix="_"
  local install_branch="${prefix}${remote_name}/${install_version}"

  git checkout -b ${install_branch} ${install_version} 2> /dev/null || true
  git checkout ${install_branch}
  git branch -u ${remote_name}/${remote_branch}

  echo "Installing ${install_version} from branch ${install_branch}..."
}

