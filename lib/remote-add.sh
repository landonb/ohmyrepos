#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:nospell:ft=bash

remote_add () {
  local remote_name="$1"
  local remote_url="$2"

  git remote remove "$1" 2> /dev/null || true
  git remote add "$1" "$2"
}

