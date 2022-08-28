#!/usr/bin/env bash

set -o errexit
set -o pipefail

unset CDPATH

function table::print_stdin() {
  local text=()
  while read -r line; do
    text+=("${line}\n")
  done

  if [[ ${#text[@]} -eq 0 ]]; then
    echo "没有提供需要格式化的文本!" >&2
    return 1
  fi

   table::print "|" ${text[@]}
}

table::print() {
  local -r delimiter="${1}" ; shift 1
  local -r data="$(table::removeEmptyLines "$*")"

  if [[ "${delimiter}" != '' && "$(table::isEmptyString "${data}")" = 'false' ]]; then
    local -r numberOfLines="$(wc -l <<< "${data}")"

    if [[ "${numberOfLines}" -gt '0' ]]; then
      local table=''
      local i=1

      for ((i = 1; i <= "${numberOfLines}"; i = i + 1)); do
        local line=''
        line="$(sed "${i}q;d" <<< "${data}")"

        local numberOfColumns='0'
        numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"

        # Add Line Delimiter
        if [[ "${i}" -eq '1' ]]; then
          table="${table}$(printf '+%s' "$(table::repeatString '#+' "${numberOfColumns}")")"
        fi

        # Add Header Or Body
        table="${table}\n"

        local j=1
        for ((j = 1; j <= "${numberOfColumns}"; j = j + 1)); do
          table="${table}$(printf '| %s#' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
        done

        table="${table}|\n"

        # Add Line Delimiter
        if [[ "${i}" -eq '1' ]] ||
        [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]; then
          table="${table}$(printf '+%s' "$(table::repeatString '#+' "${numberOfColumns}")")"
        fi
      done

      if [[ "$(table::isEmptyString "${table}")" = 'false' ]]; then
        echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1'
      fi
    fi
  fi
}

table::removeEmptyLines() {
  local -r content="${1}"

  echo -e "${content}" | sed '/^\s*$/d'
}

table::repeatString() {
  local -r string="${1}"
  local -r numberToRepeat="${2}"

  if [[ "${string}" != '' && "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]; then
    local -r result="$(printf "%${numberToRepeat}s")"

    echo -e "${result// /${string}}"
  fi
}

table::isEmptyString() {
  local -r string="${1}"

  if [[ "$(< <(table::trimString "${string}"))" = '' ]]; then
    echo 'true' && return 0
  fi

  echo 'false' && return 1
}

table::trimString() {
  local -r string="${1}"

  sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}

