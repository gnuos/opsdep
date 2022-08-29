#!/usr/bin/env bash

set -o errexit
set -o pipefail


jdk11::setup() {
  local version="$(< <(pkg::add jdk11))"

  echo -e "${SUCCESS}$(< <(date +"[%Y-%m-%d %H:%M:%S]")) jdk1.11 已安装到 ${PRODUCT_DIR}/${version}${C_End}"

  local pcount="$(< <(ps -ef |  grep tomcat | grep -v grep | wc -l))"

  if [ "$pcount" != "0" ]; then
    service::control stop tomcat
  fi

  if [[ -L "${PRODUCT_DIR}/java" ]]; then
    unlink ${PRODUCT_DIR}/java
  fi

  ln -sv "${PRODUCT_DIR}/${version}" "${PRODUCT_DIR}/java" >&3

  chown -R root:root "${PRODUCT_DIR}/${version}"
}

jdk11::initalize() {
  if which java >/dev/null 2>&1; then
    return 0
  fi

  if [ -z "${JAVA_HOME:-}" -a -z "${JRE_HOME:-}" ]; then
    JAVA_HOME="$JAVA11_INSTALL_DIR"
    JRE_HOME="${JAVA11_INSTALL_DIR}/jre"

    cat > /etc/profile.d/java.sh << EOF
JAVA_HOME="$JAVA_HOME"
JRE_HOME="$JRE_HOME"
CLASSPATH=.:\${JRE_HOME}/lib
PATH=\$PATH:\${JAVA_HOME}/bin

export JAVA_HOME JRE_HOME CLASSPATH PATH
EOF
  fi

  source /etc/profile.d/java.sh
}

jdk11::install() {
  [[ "$(< <(pkg::isneed jdk11))" == "no" ]] && return

  jdk11::setup
  jdk11::initalize

  # 检查java是否安装成功
  java -version
}

