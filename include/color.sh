#!/usr/bin/env bash

echo=echo
for cmd in echo /bin/echo; do
  $cmd >/dev/null 2>&1 || continue
  if ! $cmd -e "" | grep -qE '^-e'; then
    echo=$cmd
    break
  fi
done

# 普通颜色
C_Black='\e[0;30m'        # Black
C_Red='\e[0;31m'          # Red
C_Green='\e[0;32m'        # Green
C_Yellow='\e[0;33m'       # Yellow
C_Blue='\e[0;34m'         # Blue
C_Purple='\e[0;35m'       # Purple
C_Cyan='\e[0;36m'         # Cyan
C_White='\e[0;37m'        # White

# 加粗颜色额
B_Black='\e[1;30m'       # Black
B_Red='\e[1;31m'         # Red
B_Green='\e[1;32m'       # Green
B_Yellow='\e[1;33m'      # Yellow
B_Blue='\e[1;34m'        # Blue
B_Purple='\e[1;35m'      # Purple
B_Cyan='\e[1;36m'        # Cyan
B_White='\e[1;37m'       # White

# 背景颜色
On_Black='\e[40m'       # Black
On_Red='\e[41m'         # Red
On_Green='\e[42m'       # Green
On_Yellow='\e[43m'      # Yellow
On_Blue='\e[44m'        # Blue
On_Purple='\e[45m'      # Purple
On_Cyan='\e[46m'        # Cyan
On_White='\e[47m'       # White

C_End="\e[m"               # Color Reset

# 定义一些特别的消息样式
FAILURE="${B_Red}${On_White}"
ALERT=${B_White}${On_Red}
WARNING="${B_White}${On_Yellow}"
SUCCESS="$C_Green"
MESSAGE="$C_Cyan"

