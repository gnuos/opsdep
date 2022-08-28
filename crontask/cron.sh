#!/usr/bin/env bash

set -o errexit
set -o pipefail

unset CDPATH

cron::add_libreoffice() {
  crontab "${OFFICE_INSTALL_DIR}/cron"
}

