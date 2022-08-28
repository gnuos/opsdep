#!/usr/bin/env bash

# 这个脚本参考的是 kubernetes 的项目脚本，可以在kubernetes的hack/lib/utils.sh文件中看到

function util::sourced_variable {
  true
}

util::command_exists() {
  command -v "$@" > /dev/null 2>&1
}

util::sortable_date() {
  date "+%Y%m%d-%H%M%S"
}

util::array_contains() {
  local search="$1"
  local element
  shift
  for element; do
    if [[ "${element}" == "${search}" ]]; then
      return 0
     fi
  done
  return 1
}

util::trap_add() {
  local trap_add_cmd
  trap_add_cmd=$1
  shift

  for trap_add_name in "$@"; do
    local existing_cmd
    local new_cmd

    existing_cmd=$(< <(trap -p "${trap_add_name}" |  awk -F"'" '{print $2}'))

    if [[ -z "${existing_cmd}" ]]; then
      new_cmd="${trap_add_cmd}"
    else
      new_cmd="${trap_add_cmd};${existing_cmd}"
    fi

    trap "${new_cmd}" "${trap_add_name}"
  done
}

function util::get_distribution {
  local lsb_dist=""
  if [ -r /etc/os-release ]; then
    lsb_dist="$(< <(. /etc/os-release && echo "$ID"))"
  fi
  echo "$lsb_dist"
}

util::host_os() {
  local host_os=$(< <(util::get_distribution) )
  local dist_version=""
  host_os="$(< <(echo "$host_os" | tr '[:upper:]' '[:lower:]'))"

  case "$host_os" in
    ubuntu)
      if util::command_exists lsb_release; then
        dist_version="$(< <(lsb_release --codename | cut -f2))"
      fi
      if [ -z "$dist_version" ] && [ -r /etc/lsb-release ]; then
        dist_version="$(< <(. /etc/lsb-release && echo "$DISTRIB_CODENAME"))"
      fi
    ;;
    debian)
      dist_version="$(< <(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//'))"
        case "$dist_version" in
          11)
            dist_version="bullseye"
          ;;
          10)
            dist_version="buster"
          ;;
          9)
            dist_version="stretch"
          ;;
          8)
            dist_version="jessie"
          ;;
        esac
    ;;
    centos|rhel)
      if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
        dist_version="$(< <(. /etc/os-release && echo "$VERSION_ID"))"
      fi
    ;;
    *)
      if util::command_exists lsb_release; then
        dist_version="$(< <(lsb_release --release | cut -f2))"
      fi
      if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
        dist_version="$(< <(. /etc/os-release && echo "$VERSION_ID"))"
      fi
      ;;
  esac
  echo "${host_os}/${dist_version}"
}

util::host_arch() {
  local host_arch
  case "$(uname -m)" in
    x86_64*)
      host_arch=amd64
      ;;
    i?86_64*)
      host_arch=amd64
      ;;
    amd64*)
      host_arch=amd64
      ;;
    aarch64*)
      host_arch=arm64
      ;;
    arm64*)
      host_arch=arm64
      ;;
    arm*)
      host_arch=arm
      ;;
    i?86*)
      host_arch=x86
      ;;
    *)
      logging::error "Unsupported host arch. Must be x86_64, x86, arm, arm64."
      exit 1
      ;;
  esac
  echo "${host_arch}"
}

util::host_platform() {
  echo "$(< <(util::host_arch))/$(< <(util::host_os))"
}

util::find_package() {
  local -r lookfor="$1"
  local -r platform="$(util::host_platform)"
  local -r basearch="$(util::host_arch)"

  local location="${INSTALLER_ROOT}/pkgs/${basearch}/${lookfor}"

  local -r bin=$(< <((ls -t "${location}"* 2>/dev/null || true) | head -1 ))

  if [[ -z "${bin}" ]]; then
    echo "找不到包 ${lookfor}" >&2
    return 1
  fi

  echo -n "${bin}"
}

util::query_version() {
  local pack="$1"
  local suffix=(
    \\.tar\\.bz2
    \\.tar\\.xz
    \\.tar\\.gz
    \\.tbz2
    \\.txz
    \\.tgz
    \\.tar
    \\.zip
    \\.bz2
    \\.xz
    \\.gz
  )

  pack=$(< <(basename "$pack"))

  for format in "${suffix[@]}"; do
    if [[ "$pack" =~ ^(.*)($format) ]]; then
      echo -n "$(< <(basename "${BASH_REMATCH[1]}" | cut -d'-' -f1))"
      break
    fi
  done
}

util::extract() {
  local src="$1"
  local dst="$2"

  if [ ! -d $dst ] && [ ! -d $(< <(dirname $dst)) ]; then
    echo -e "${FAILURE}解压的目标目录 $dst 不存在！${CEnd}" >&2
    exit 4
  fi

  if [ -f $src ] ; then
    case $src in
      *.tar.bz2)   tar xjf $1      -C "$dst" ;;
      *.tar.xz)    tar xJf $1      -C "$dst" ;;
      *.tar.gz)    tar xzf $1      -C "$dst" ;;
      *.tbz2)      tar xjf $1      -C "$dst" ;;
      *.txz)       tar xJf $1      -C "$dst" ;;
      *.tgz)       tar xzf $1      -C "$dst" ;;
      *.tar)       tar xf $1       -C "$dst" ;;
      *.zip)       unzip -o -q $1  -d "$dst" ;;
      *.bz2)       (cd $dst; bunzip2 -fkq $1) ;;
      *.gz)        (cd $dst; gunzip -fq $1) ;;
      *.xz)        (cd $dst; xz -dfkq $1) ;;
      *) echo -e "${FAILURE}无法解压'$1'文件的压缩格式!${CEnd}" >&2 ; exit 4 ;;
    esac
  else
    echo -e "${FAILURE}'$1' 文件不存在!${CEnd}" >&2
     exit 4
  fi
}


util::wait-for-jobs() {
  local fail=0
  local job
  for job in $(jobs -p); do
    wait "${job}" || fail=$((fail + 1))
  done
  return ${fail}
}

function util::join {
  local IFS="$1"
  shift
  echo "$*"
}

util::md5() {
  if which md5 >/dev/null 2>&1; then
    md5 -q "$1"
  else
    md5sum "$1" | awk '{ print $1 }'
  fi
}

function util::read-array {
  local i=0
  unset -v "$1"
  while IFS= read -r "$1[i++]"; do :; done
  eval "[[ \${$1[--i]} ]]" || unset "$1[i]"
}

if [[ -z "${color_start-}" ]]; then
  declare -r color_start="\033["
  declare -r color_red="${color_start}0;31m"
  declare -r color_yellow="${color_start}0;33m"
  declare -r color_green="${color_start}0;32m"
  declare -r color_blue="${color_start}1;34m"
  declare -r color_cyan="${color_start}1;36m"
  declare -r color_norm="${color_start}0m"

  util::sourced_variable "${color_start}"
  util::sourced_variable "${color_red}"
  util::sourced_variable "${color_yellow}"
  util::sourced_variable "${color_green}"
  util::sourced_variable "${color_blue}"
  util::sourced_variable "${color_cyan}"
  util::sourced_variable "${color_norm}"
fi

# ex: ts=2 sw=2 et filetype=sh
