#!/usr/bin/env bash
# Author:  liushuai <liushuai@yhmsi.com>

clear

set -o errexit
set -o pipefail

INSTALLER_ROOT=$(dirname "${BASH_SOURCE[0]}")

source "${INSTALLER_ROOT}/include/init.sh" && _init_logs

printf "${B_White}${On_Green}
_______________________________________________________________________
                                                                       
                       运维一键安装脚本 `_version`                           
                                                                       
  使用说明：                                                           
  这个脚本当前支持安装的包有：                                         
      jdk8 mysql tomcat libreoffice                                    
                                                                       
  在命令行执行 ./install 或者 bash ./install 运行脚本                  
                                                                       
  默认情况如果不指定参数就会自动安装上面全部的包。                     
  如果要安装指定的几个包，只需要把上面说的包名加到执行脚本的后面，     
  包名要用空格分开                                                     
_______________________________________________________________________
                                                                       
${C_End}
"

# Check if user is root
[ "$(< <(id -u))" != "0" ] && { echo -e "${FAILURE}错误：必须用root用户或者sudo运行这个脚本${C_End}"; exit 1; }

echo -e "${MESSAGE}$(< <(date +"[%Y-%m-%d %H:%M:%S]")) 开始安装 ...... ${C_End}"

pushd ${INSTALLER_ROOT} >/dev/null 2>&1

_install "offline" ${@}

echo -e "${SUCCESS}$(< <(date +"[%Y-%m-%d %H:%M:%S]")) ${@} 安装完成 ${C_End}\n"

pkg::list

