# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash
# Author: Landon Bouma (landonb &#x40; retrosoft &#x2E; com)
# Project: https://github.com/landonb/ohmyrepos#😤
# License: MIT

print_homebrew_prefix () {
  # If `eval "$(brew shellenv)"` prev. called, HOMEBREW_PREFIX is set.
  local brew_prefix="${HOMEBREW_PREFIX}"

  # Apple Silicon (arm64) brew path is /opt/homebrew
  [ -d "${brew_prefix}" ] || brew_prefix="/opt/homebrew"

  # On Intel Macs it's under /usr/local (tho deprecated)
  [ -d "${brew_prefix}" ] || brew_prefix="/usr/local/Homebrew"

  if [ ! -d "${brew_prefix}" ]; then
    >&2 echo "ERROR: Where's HOMEBREW_PREFIX?"

    exit 1
  fi

  printf "%s" "${brew_prefix}"
}

