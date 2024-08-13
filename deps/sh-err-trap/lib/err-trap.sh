# vim:tw=0:ts=2:sw=2:et:norl:ft=bash
# Author: Landon Bouma <https://tallybark.com/>
# Project: https://github.com/DepoXy/sh-err-trap#🪤
# License: MIT

# Copyright (c) © 2021-2024 Landon Bouma. All Rights Reserved.

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

os_is_macos () {
  [ "$(uname)" = "Darwin" ]
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# Preserve tty flags
_TTY_FLAGS="$([ -t 0 ] && stty -g)" \
  || true

clear_traps () {
  trap - EXIT INT
}

set_traps () {
  trap -- trap_exit EXIT
  trap -- trap_int INT
}

set_traps_safe () {
  trap -- trap_exit_safe EXIT
  trap -- trap_int INT
}

exit_0 () {
  clear_traps

  exit 0
}

exit_1 () {
  clear_traps

  exit 1
}

trap_exit () {
  local return_value=$?
  
  clear_traps

  # USAGE: Alert on unexpected error path, so you can add happy path.
  >&2 echo "ALERT: "$(basename -- "$0")" exited abnormally!"
  >&2 echo "- Hint: Enable \`set -x\` and run again..."

  # If user calls `exit 0` and not exit_0, this'll hit.
  if [ ${return_value} -eq 0 ]; then
    >&2 echo "- DEV: Try \`exit_0\`, not \`exit 0\`"

    # Any nonzero value will do.
    return_value=2
  fi

  exit ${return_value}
}

trap_exit_safe () {
  >&2 echo "ALERT: "$(basename -- "$0")" tossed an error!"
  >&2 echo "- Hint: Enable \`set -x\` and run again..."
  >&2 echo "- But this script is playing it loose, and will keep going!"

  return 0
}

# Ctrl-C generates 130 in Bash, or 128+SIGINT.
# - "Other shells will use diff. reps., like 256+signum in ksh93,
#    128+256+signum in yash, textual representations like sigint
#    or sigquit+core in rc/es."
#   https://unix.stackexchange.com/a/386856
#   https://unix.stackexchange.com/questions/386836/
#     why-is-doing-an-exit-130-is-not-the-same-as-dying-of-sigint
trap_int () {
  local return_value=$?

  clear_traps

  # Restore tty flags
  # - If not, `exit` from INT trap might leave terminal in 'silent mode'
  #   (and nothing is echoed as user types).
  #   - E.g., if user <Ctrl-C>'s a `read -s` prompt.
  #   - SAVVY: Pro tip: If this ever happens to you, type `stty sane<CR>`
  #     to the terminal and hopefully that'll right the sh'ip.
  # - Note that `stty sane` also works here, but that's more like a reset.
  #   We use save-load to show that we restored the original tty settings.
  [ -t 0 ] && stty "${_TTY_FLAGS}" \
    || true

  exit ${return_value}
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

