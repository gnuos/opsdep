#!/usr/bin/env bash

set -o errexit
set -o pipefail

unset CDPATH

INSTALLER_ROOT=$(< <(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P))

source "${INSTALLER_ROOT}/include/color.sh"
source "${INSTALLER_ROOT}/include/util.sh"
source "${INSTALLER_ROOT}/include/logging.sh"
source "${INSTALLER_ROOT}/include/tabular.sh"
source "${INSTALLER_ROOT}/include/service.sh"
source "${INSTALLER_ROOT}/include/pkg.sh"
source "${INSTALLER_ROOT}/crontask/cron.sh"


function _cleanup {
  # 取消注册ERR事件监听，防止循环执行这个函数
  trap - ERR

  rm -rf /tmp/tmp.*

  local pids=( "$$" )
  local current_pid element
  local running_pids=("${pids[@]}")

  while :; do
    if [[ ${#running_pids[@]} -eq 0 ]] || [[ -z ${running_pids[0]:-} ]]; then
      break
    fi

    current_pid="${running_pids[0]}"
    [[ -z "$current_pid" ]] && break

    running_pids=("${running_pids[@]:1}")

    
    local new_pids="$(< <(_p="$current_pid"; ps x -o pid,ppid | awk '{if($2 == $_p){ print $1 }}'))"
    [[ -z "$new_pids" ]] && continue

    for element in $new_pids; do
      running_pids+=("$element")
      pids=("$element" "${pids[@]}")
    done
  done

  # 如果进程数是1，就说明没有未结束的子进程
  [[ ${#pids[@]} -gt 1 ]] && kill ${pids[@]} 2>/dev/null
}

function _init_logs {
  LOGINFO="${INSTALLER_ROOT}/logs/info.$(date +%Y-%m-%d).log"
  LOGERROR="${INSTALLER_ROOT}/logs/error.$(date +%Y-%m-%d).log"

  exec 3>&1 4>&2 1> >(tee "$LOGINFO" >&3) 2> >(tee "$LOGERROR" >&4)

  util::trap_add "_cleanup" INT
  util::trap_add "_cleanup" QUIT
  util::trap_add "_cleanup" TERM
  util::trap_add "_cleanup" EXIT

  logging::install_errexit
}

function _readlinkdashf {
  (
    if [[ -d "${1}" ]]; then
      cd "${1}"
      pwd -P
    else
      cd "$(< <(dirname "${1}"))"
      local f
      f="$(< <(basename "${1}"))"
      if [[ -L "${f}" ]]; then
        readlink "${f}"
      else
        echo "$(< <(pwd -P))/${f}"
      fi
    fi
  )
}

_realpath() {
  if [[ ! -e "${1}" ]]; then
    echo "${1}: No such file or directory" >&2
    return 1
  fi
  _readlinkdashf "${1}"
}

_check_pkg() {
  local mode="$1"
  local module

  if [[ "$mode" == "offline" ]]; then
    for module in ${REQUIREMENTS[@]}; do
      local pack=$(< <(util::find_package "$module"))

      if [ ! -f "$pack" ]; then
        echo "${module} 没有安装包" >&2
        return 1
      fi

      if [ ! -r "${INSTALLER_ROOT}/modules/${module}.sh" ]; then
        echo "要安装的包 $module 脚本无法执行" >&2
        return 1
      fi

      source "${INSTALLER_ROOT}/modules/${module}.sh"
    done
  elif [[ "$mode" == "online" ]]; then
    echo "当前版本不支持在线安装" >&2
    return 1
  fi
}

_unique() {
  local text=(${@})
  local has_add=(${text})

  local token
  for token in ${text[@]}; do
    if !(printf '%s\0' "${has_add[@]}" | grep -Fxqz -- "$token"); then
      has_add+=("${token}")
    fi
  done

  echo -n "${has_add[@]}"
}

# 查找模块 module 的下级依赖包
_check_deps() {
  local module="$1"
  local _depV="DEP_${module}"
  
  eval 'local _depA=(${'"${_depV}"'[@]})'

  # 如果没有定义依赖变量，或者定义的依赖变量是空列表
  # 说明这个模块没有其他的依赖，直接放到待安装的列表中
  if [ ! -v "$_depV" ] || [[ -z "${_depA[@]}" ]]; then
    return
  fi

  local _depC=${#_depA[@]}
  local _dep0="${_depA[0]}"

  # 检查如果定义的依赖变量不是空的，至少有一个依赖
  # 就递归检查依赖的包，并且放到待安装的列表中
  if [[ ${_depC} -gt 0 ]] && [[ -n "${_dep0}" ]]; then
    # 先对依赖项去重，防止重复分析依赖
    _depA=($(< <(_unique "${_depA[@]}")))

    # 避免循环检查依赖自己
    if (printf '%s\0' "${_depA[@]}" | grep -Fxqz -- "$module") ||\
       [[ "$module" == "${NEXT_INSTALL}" ]]; then
      _depA=(${_depA[@]/$module})
    fi

    local _dep
    for _dep in ${_depA[@]}; do
      _check_deps "$_dep"

      if !(printf '%s\0' "${REQUIREMENTS[@]}" | grep -Fxqz -- "$_dep"); then
        REQUIREMENTS+=("$_dep")
      fi
    done
  fi
}

# 安装软件的主要功能
_install() {
  local mode="$1"
  shift 1
  local mods=($(< <(_unique "${@}")))

  source "${INSTALLER_ROOT}/modules/default.conf"
  source "${INSTALLER_ROOT}/modules/depends.conf"

  if [ -z "${PRODUCT_DIR}" ]; then
    echo "没有设置安装的目标目录"
    echo "需要先设置安装目录环境变量 PRODUCT_DIR"

    return
  fi

  [[ -z "${*}" ]] && mods=(${__ALL_MODULES__[@]})

  # 已安装的包列表这个变量用于失败后清理环境的时候用，暂时没实现功能
  declare -a INSTALLED_MODS

  # 把需要安装的包记录到这个列表中，用于去重和检查依赖
  declare -a REQUIREMENTS
  
  NEXT_INSTALL=""

  for NEXT_INSTALL in ${mods[@]}; do
    _check_deps "${NEXT_INSTALL}"
    REQUIREMENTS+=("$NEXT_INSTALL")
  done

  # 检查包文件和安装脚本
  _check_pkg "${mode}"

  mkdir -pv "${PRODUCT_DIR}" >&3

  for mod in ${REQUIREMENTS[@]}; do
    echo
    echo -e "${MESSAGE}$(< <(date +"[%Y-%m-%d %H:%M:%S]")) 安装 ${mod} >>>>>>>>${C_End}" >&3
    echo

    ${mod}::install
    INSTALLED_MODS+=("$mod")

    printf "
=======================================================================
$(< <(date +"[%Y-%m-%d %H:%M:%S]")) INFO: ${mod} 已安装完成!
=======================================================================

" >&3

  done
}

_version() {
  echo -n $(< <(head -1 "${INSTALLER_ROOT}/version.txt"))
}

