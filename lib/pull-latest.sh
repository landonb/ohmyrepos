#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

pull_latest () {
  local remote_name="$1"
  local remote_branch="$2"
  local version_tag="$3"

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
  git checkout ${remote_branch}
  git branch -u ${remote_name}/${remote_branch}
  git pull --ff-only

  local install_version="${version_tag}"
  # REFER: `git-latest-version-normal` from
  #   https://github.com/landonb/git-smart#💡
  if [ -z "${install_version}" ]; then
    install_version="$(git latest-version-normal)"
  fi

  local install_branch="${remote_name}/${install_version}"

  git checkout -b ${install_branch} ${install_version} || true
  git checkout ${install_branch}

  echo "Installing ${install_version} from branch ${install_branch}..."
}

