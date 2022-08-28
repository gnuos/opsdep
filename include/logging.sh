#!/usr/bin/env bash

VERBOSE="${VERBOSE:-3}"

logging::errexit() {
  local err="${PIPESTATUS[*]}"

  set +o | grep -qe "-o errexit" || return

  set +o xtrace
  local code="${1:-1}"
  if [ ${#FUNCNAME[@]} -gt 2 ]; then
    logging::error "调用链:"
    for ((i=1;i<${#FUNCNAME[@]}-1;i++))
    do
      logging::error " ${i}: ${BASH_SOURCE[${i}+1]}:${BASH_LINENO[${i}]} ${FUNCNAME[${i}]}(...)"
    done
  fi
  logging::error_exit "报错位置：${BASH_SOURCE[1]}:${BASH_LINENO[0]}. '${BASH_COMMAND}'; 状态码：${err}" "${1:-1}" 1
}

logging::install_errexit() {
  trap 'logging::errexit' ERR

  set -o errtrace
}

logging::stack() {
  local stack_skip=${1:-0}
  stack_skip=$((stack_skip + 1))
  if [[ ${#FUNCNAME[@]} -gt ${stack_skip} ]]; then
    echo "调用栈:" >&2
    local i

    for ((i=1 ; i <= ${#FUNCNAME[@]} - stack_skip ; i++))
    do
      local frame_no=$((i - 1 + stack_skip))
      local source_file=${BASH_SOURCE[${frame_no}]}
      local source_lineno=${BASH_LINENO[$((frame_no - 1))]}
      local funcname=${FUNCNAME[${frame_no}]}
      echo "  ${i}: ${source_file}:${source_lineno} ${funcname}(...)" >&2
    done
  fi
}

logging::error_exit() {
  local message="${1:-}"
  local code="${2:-1}"
  local stack_skip="${3:-0}"
  stack_skip=$((stack_skip + 1))

  if [[ ${VERBOSE} -ge 3 ]]; then
    local source_file=${BASH_SOURCE[${stack_skip}]}
    local source_line=${BASH_LINENO[$((stack_skip - 1))]}
    echo "!!! Error in ${source_file}:${source_line}" >&2
    [[ -z ${1-} ]] || {
      echo "  ${1}" >&2
    }

    logging::stack ${stack_skip}

    echo "Exiting with status ${code}" >&2
  fi

  exit "${code}"
}

logging::error() {
  timestamp=$(< <(date +"[%m%d %H:%M:%S]"))
  echo "!!! ${timestamp} ${1-}" >&2
  shift
  for message; do
    echo "    ${message}" >&2
  done
}

logging::usage() {
  echo >&2
  local message
  for message; do
    echo "${message}" >&2
  done
  echo >&2
}

logging::usage_from_stdin() {
  local messages=()
  while read -r line; do
    messages+=("${line}")
  done

  logging::usage "${messages[@]}"
}

logging::info() {
  local V="${V:-0}"
  if [[ ${VERBOSE} < ${V} ]]; then
    return
  fi

  for message; do
    echo "${message}"
  done
}

logging::status() {
  local V="${V:-0}"
  if [[ ${VERBOSE} < ${V} ]]; then
    return
  fi

  timestamp=$(< <(date +"[%m%d %H:%M:%S]"))
  echo "+++ ${timestamp} ${1}"
  shift
  for message; do
    echo "    ${message}"
  done
}

