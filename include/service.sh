#!/usr/bin/env bash

set -o errexit
set -o pipefail

unset CDPATH
unalias -a

service::control() {
  local action="$1"
  local name="$2"

  case $action in
    start|stop|restart|reload)
      if !(service $name $action); then
        if !(systemctl $action ${name}.service); then
          if !(/etc/init.d/$name $action); then
            if [ -f ${PRODUCT_DIR}/${name} ]; then
              sh ${PRODUCT_DIR}/${name} $action
            else
              echo "${name}服务启动失败!" >&2
              return 1
            fi
          fi
        fi
      fi
    ;;
    *) echo "${action}参数不存在！" >&2;  return 1;;
  esac
}

service::add() {
  local name="$1"

  if test -f "${INSTALLER_ROOT}/prepare/sysvinit/$name" ; then
    cp -fv "${INSTALLER_ROOT}/prepare/sysvinit/$name" /etc/init.d/ >&3
    chmod 755 /etc/init.d/$name
    chkconfig --add $name
  elif test -f "${INSTALLER_ROOT}/prepare/systemd/$name" ; then
    cp -fv "${INSTALLER_ROOT}/prepare/systemd/${name}.service" /etc/systemd/system/ >&3
    systemctl daemon-reload
  elif test -f "${INSTALLER_ROOT}/prepare/runit/$name" ; then
    cp -frv "${INSTALLER_ROOT}/prepare/runit/$name" /etc/sv/ >&3
    chmod 755 /etc/sv/$name/run
    ln -sfv "/etc/sv/$name" "/var/service/$name" >&3
  fi
}

service::del() {
  local name="$1"

}

