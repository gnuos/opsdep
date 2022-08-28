#!/usr/bin/env bash

unalias -a
set -o errexit
set -o pipefail


tomcat::setup() {
  local version="$(< <(pkg::add tomcat))"

  pkg::default tomcat "$version"

  cat > /etc/logrotate.d/tomcat << EOF
${TOMCAT_INSTALL_DIR}/logs/catalina.out {
    daily
    rotate 35
    missingok
    dateext
    compress
    notifempty
    copytruncate
}
EOF

  cat > "${TOMCAT_INSTALL_DIR}/bin/setenv.sh" << EOF
JAVA_HOME="$JAVA8_INSTALL_DIR"
CATALINA_PID="\$CATALINA_BASE"/work/catalina.pid
EOF

  cp -fv "${INSTALLER_ROOT}/config/server.xml" "${TOMCAT_INSTALL_DIR}/conf/"
}

tomcat::initialize() {
  tomcat::autostart
  tomcat::set_firewall
}

tomcat::autostart() {
  if [ ! -f /etc/init.d/tomcat ] && [ -f "${INSTALLER_ROOT}/etc/init.d/tomcat" ]; then
    cp -fv "${INSTALLER_ROOT}/etc/init.d/tomcat" "${INSTALLER_ROOT}/prepare/sysvinit/"
    sed -i "s|PRODUCT_DIR|${PRODUCT_DIR}|" "${INSTALLER_ROOT}/prepare/sysvinit/tomcat"
  elif [ ! -f /etc/systemd/system/tomcat.service ] && [ -f "${INSTALLER_ROOT}/etc/systemd/system/tomcat.service" ] ; then
    cp -fv "${INSTALLER_ROOT}/etc/systemd/system/tomcat.service" "${INSTALLER_ROOT}/prepare/systemd/"
    sed -i "s|PRODUCT_DIR|${PRODUCT_DIR}|" "${INSTALLER_ROOT}/prepare/systemd/tomcat.service"
  fi

  service::add tomcat

  if (which java >/dev/null 2>&1); then
     service::control start tomcat
  fi
}

tomcat::set_firewall() {
  if (firewall-cmd --state >/dev/null 2>&1); then
    firewall-cmd --zone=public --list-ports
    firewall-cmd --zone=public --add-port=8080/tcp --permanent
    firewall-cmd --reload
  fi
}

tomcat::install() {
  [[ "$(< <(pkg::isneed tomcat))" == "no" ]] && return

  tomcat::setup
  tomcat::initialize
}

