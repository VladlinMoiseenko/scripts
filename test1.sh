#!/usr/bin/env bash

: ${USE_SUDO:="true"}

runAsRoot() {
  if [ $EUID -ne 0 -a "$USE_SUDO" = "true" ]; then
    sudo "${@}"
  else
    "${@}"
  fi
}

runAsRoot apt update

exit 0 