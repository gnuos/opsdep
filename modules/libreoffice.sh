#!/usr/bin/env bash

set -o errexit
set -o pipefail


libreoffice::setup() {
  local pack=$(< <(util::find_package "libreoffice"))

  mkdir -pv "${OFFICE_INSTALL_DIR}"

  # 先解压安装包
  util::extract "$pack" "${OFFICE_INSTALL_DIR}"

  local to_install=()

  for p in $(find ${OFFICE_INSTALL_DIR}/RPMS/ -name "*.rpm" -type f); do
    local name="$(< <(basename -s .rpm $p))"

    if (rpm -qa | grep $name >/dev/null 2>&1); then
      continue
    fi

    to_install+=($(< <(basename $p)))
  done

  pushd "${OFFICE_INSTALL_DIR}/RPMS" >/dev/null

  if [[ -n "${to_install[@]}" ]]; then
    yum install -y ${to_install[@]}
    ls -1FA ./*.rpm | tee "./Packages.txt" >&3
  fi

  popd >/dev/null

  libreoffice::install_fonts

  local version="$(< <(basename `ls -1dtA /opt/libreoffice* | head -1`))"

  LibreOffice_Program="/opt/${version}/program"

  echo "libreoffice|${version}|/opt/${version}" >> "${PRODUCT_DIR}/installed.list"
}

function libreoffice::install_fonts {
  # 安装Windows系统的字体
  if test -f "${INSTALLER_ROOT}/pkgs/windows-font.tar.gz"; then
    cp -fv "${INSTALLER_ROOT}/pkgs/windows-font.tar.gz" /tmp/ >&3
    mkdir -pv /usr/share/fonts/windows >&3
    tar xf /tmp/windows-font.tar.gz -C /usr/share/fonts/windows/
    chmod 644 /usr/share/fonts/windows/*

    fc-cache –fv >&3
  fi
}

function libreoffice::initialize {
  cp -fv "${INSTALLER_ROOT}/crontask/libreoffice" "${OFFICE_INSTALL_DIR}/cron"
  cp -fv "${INSTALLER_ROOT}/crontask/job_start_libreoffice.sh" "${OFFICE_INSTALL_DIR}/"

  sed -i "s|OFFICE_INSTALL_DIR|${OFFICE_INSTALL_DIR}|g" ${OFFICE_INSTALL_DIR}/cron
  sed -i "s|LIBREOFFICE_PROGRAM|${LibreOffice_Program}|g" "${OFFICE_INSTALL_DIR}/job_start_libreoffice.sh"

  sh "${OFFICE_INSTALL_DIR}/job_start_libreoffice.sh" &

  cron::add_libreoffice
  service::control reload crond
}

libreoffice::install() {
  libreoffice::setup
  libreoffice::initialize
}

