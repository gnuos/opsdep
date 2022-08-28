#!/bin/bash
#查找进程号
tpid=$(ps -ef | grep soffice | grep -v grep | awk '{print $2}')

echo -n "$tpid" | wc -l

if [ ! -z ${tpid:+x} ]; then
  echo start:$(date)
  echo old libreoffice pid is ${tpid}
  echo 'Stop LibreOffice Process'
  #杀死进程
  kill -TERM $tpid
fi

sleep 5

echo $! > /tmp/libreoffice.tpid

#重新启动程序

#sh ./libreoffice_start.sh

LIBREOFFICE_PROGRAM/soffice --headless --accept="socket,host=127.0.0.1,port=8100;urp;" --nofirststartwizard &

echo Start LibreOffice Success

#新的进程号
tpid=`ps -ef|grep soffice|grep -v grep|awk '{print $2}'`

echo new libreoffice pid is ${tpid}

echo end:$(date)

