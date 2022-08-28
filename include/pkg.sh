#!/usr/bin/env bash

set -o errexit
set -o pipefail

unset CDPATH
unalias -a

pkg::prepared() {
  local name="$1"
  local pack="$(< <(util::find_package "$name"))"
  local _version="$(< <(util::query_version "$pack"))"

  echo -n "${_version} ${pack}"
}

pkg::installed() {
  local name="$1"
  local _version=""

  if [ ! -f "${PRODUCT_DIR}/installed.list" ]; then
    echo -n ""
    return
  fi

  if (grep -q "$name" "${PRODUCT_DIR}/installed.list" >/dev/null 2>&1); then
    _version=$(< <(grep "$name" "${PRODUCT_DIR}/installed.list" | tail -n1 | awk -F'|' '{print $2}'))
  fi

  echo -n "${_version}"
}

pkg::isneed() {
  local name="$1"

  local packinfo=($(< <(pkg::prepared "$name")))
  local installed="$(< <(pkg::installed "$name"))"

  if [ -z "$installed" ]; then
    echo -n "yes"
    return
  fi

  if [[ "$installed" != "${packinfo[0]}" ]]; then
    echo -n "yes"
    return
  fi

  echo -n "no"
}

pkg::add() {
  local name="$1"

  local packinfo=($(< <(pkg::prepared "$name")))

  if [ -f "${PRODUCT_DIR}/installed.list" ]; then
    local _installed="$(< <(pkg::installed "$name"))"
    if [ -n "${_installed}" ] && [[ "$_installed" == "${packinfo[0]}" ]]; then
      echo -n "${_installed}"
      return
    fi
  fi

  # 先解压安装包到临时目录
  local fakedest="$(< <(mktemp -d))"
  util::extract "${packinfo[1]}" "${fakedest}/"

  local dname=$(< <(basename `ls -1dA ${fakedest}/* | head -1`))

  if [ ! -d "${PRODUCT_DIR}/${packinfo[0]}" ]; then
    mv "${fakedest}/${dname}" "${PRODUCT_DIR}/${packinfo[0]}"
    echo "${name}|${packinfo[0]}|${PRODUCT_DIR}/${packinfo[0]}" >> "${PRODUCT_DIR}/installed.list"
  fi

  rm -rf "$fakedest"

  echo -n "${packinfo[0]}"
}

# 删除包只解除软链接，不实际删除文件
pkg::del() {
  local name="$1"

  local path=$(< <(grep "$name" "${PRODUCT_DIR}/software.list" | cut -d'|' -f3))
  local pcount=$(< <(ps -ef | grep "$name" | grep -v grep | wc -l))

  if [[ "$pcount" -ne "0" ]] ;then
    service::control stop "$name"
  fi

  unlink -vf ${PRODUCT_DIR}/${name}

  echo "可以手动删除${path}目录了"
}

pkg::default() {
  local name="$1"
  local version="$2"

  local pcount=$(< <(ps -ef | grep "$name" | grep -v grep | wc -l))

  if [[ "$pcount" != "0" ]] ;then
    service::control stop "$name"
  fi

  [[ -L "${PRODUCT_DIR}/${name}" ]] && unlink "${PRODUCT_DIR}/${name}"

  ln -sf "${PRODUCT_DIR}/${version}" "${PRODUCT_DIR}/${name}"
}

pkg::list() {
  if [ ! -f "${PRODUCT_DIR}/installed.list" ]; then
    return
  fi

  table::print "|" "安装包名字|安装包版本|安装位置\n$(<"${PRODUCT_DIR}/installed.list")"
}

