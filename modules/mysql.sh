#!/usr/bin/env bash

unalias -a
set -o errexit
set -o pipefail


MYSQL_ROOT_PASSWORD="$(< <(openssl rand -base64 12))"


# 安装文件和服务
mysql::setup() {
  local version="$(< <(pkg::add mysql))"

  pkg::default mysql "$version"

  cp -fv "${INSTALLER_ROOT}/etc/my.cnf" "${MYSQL_INSTALL_DIR}/" >&3
  cp -frv "${INSTALLER_ROOT}/etc/my.cnf.d/" /etc/ >&3
  sed -i "s|MYSQL_INSTALL_DST|${MYSQL_INSTALL_DIR}|g" "${MYSQL_INSTALL_DIR}/my.cnf" /etc/my.cnf.d/*
  sed -i "s|MYSQL_DATA_DST|${MYSQL_DATA_DIR}|g" "${MYSQL_INSTALL_DIR}/my.cnf" /etc/my.cnf.d/*

  # 定时分割MySQL的日志
  cat > /etc/logrotate.d/mysqld <<EOF
/var/log/mysql/mysqld.log {
    # create 600 mysql mysql
    notifempty
    daily
    rotate 5
    missingok
    compress
    postrotate
        if test -x ${MYSQL_INSTALL_DIR}/bin/mysqladmin && \
           ${MYSQL_INSTALL_DIR}/bin/mysqladmin ping &>/dev/null
        then
           ${MYSQL_INSTALL_DIR}/bin/mysqladmin flush-logs
        fi
    endscript
}
EOF

}

# 初始化数据库和服务
mysql::initialize() {
  if !(id -u mysql >/dev/null 2>&1); then
    groupadd -f -r mysql
    useradd -r -M -g mysql -s /sbin/nologin mysql
  fi

  mkdir -pv "${MYSQL_DATA_DIR}"
  chown -R mysql:mysql "${MYSQL_DATA_DIR}"
  chmod 750 "${MYSQL_DATA_DIR}"

  mkdir -pv /var/log/mysql
  touch /var/log/mysql/mysqld.log
  chown -R mysql:mysql /var/log/mysql

  "${MYSQL_INSTALL_DIR}/bin/mysqld" --initialize-insecure --user=mysql --basedir="${MYSQL_INSTALL_DIR}" --datadir="${MYSQL_DATA_DIR}" >&3

  mysql::autostart
}

mysql::set_root_password() {
  local change_root_pass="alter user 'root'@'localhost' identified by '${MYSQL_ROOT_PASSWORD}'; flush privileges;"

  "${MYSQL_INSTALL_DIR}/bin/mysql" -S "${MYSQL_DATA_DIR}/mysql.sock" -u root --skip-password -e "${change_root_pass}" >&3

  cat > /root/.my.cnf <<EOF
[mysqladmin]
user = root
password = "${MYSQL_ROOT_PASSWORD}"
socket = "${MYSQL_DATA_DIR}/mysql.sock"

[mysqldump]
user = root
password = "${MYSQL_ROOT_PASSWORD}"
socket = "${MYSQL_DATA_DIR}/mysql.sock"

[mysqlshow]
user = root
password = "${MYSQL_ROOT_PASSWORD}"
socket = "${MYSQL_DATA_DIR}/mysql.sock"
EOF

}

mysql::autostart() {
  if [ ! -f /etc/init.d/mysqld ] && [ -f "${INSTALLER_ROOT}/etc/init.d/mysqld" ]; then
    cp -fv "${INSTALLER_ROOT}/etc/init.d/mysqld" "${INSTALLER_ROOT}/prepare/sysvinit/"
    sed -i "s|MYSQL_INSTALL_DST|${MYSQL_INSTALL_DIR}|g" "${INSTALLER_ROOT}/prepare/sysvinit/mysqld"
    sed -i "s|MYSQL_DATA_DST|${MYSQL_DATA_DIR}|g" "${INSTALLER_ROOT}/prepare/sysvinit/mysqld"
  elif [ ! -f /etc/systemd/system/mysqld.service ] && [ ! -f /etc/systemd/system/mysql.service ] && 
       [ ! -f /etc/systemd/system/mariadb.service ] && [ -f "${INSTALLER_ROOT}/etc/systemd/system/mysqld.service" ] ; then
    cp -fv "${INSTALLER_ROOT}/etc/systemd/system/mysqld.service" "${INSTALLER_ROOT}/prepare/systemd/"
    sed -i "s|MYSQL_INSTALL_DST|${MYSQL_INSTALL_DIR}|g" "${INSTALLER_ROOT}/prepare/systemd/mysqld.service"
    sed -i "s|MYSQL_DATA_DST|${MYSQL_DATA_DIR}|g" "${INSTALLER_ROOT}/prepare/systemd/mysqld.service"
  fi

  service::add mysqld
  service::control start mysqld
}

mysql::install() {
  [[ "$(< <(pkg::isneed mysql))" == "no" ]] && return

  mysql::setup
  mysql::initialize
  mysql::set_root_password

  "${MYSQL_INSTALL_DIR}/bin/mysqladmin" ping >&3
  "${MYSQL_INSTALL_DIR}/bin/mysqlshow" >&3

  service::control restart mysqld
}

