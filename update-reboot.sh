#!/usr/bin/env bash

: ${USE_SUDO:="true"}

runAsRoot() {
  if [ $EUID -ne 0 -a "$USE_SUDO" = "true" ]; then
    sudo "${@}"
  else
    "${@}"
  fi
}

updateReboot() {
  runAsRoot apt update 
  runAsRoot apt -y full-upgrade
  [ -f /var/run/reboot-required ] && runAsRoot reboot -f
}

updateReboot

exit 0 