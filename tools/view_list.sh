#!/usr/bin/env bash

set -o errexit
set -o pipefail

INSTALLER_ROOT=$(dirname "${BASH_SOURCE[0]}")

source "${INSTALLER_ROOT}/include/init.sh"
source "${INSTALLER_ROOT}/modules/default.conf"

pkg::list

