#!/usr/bin/env bash

# 查看 cpu名称/频率/缓存大小,硬盘,内存,网卡流量 使用情况
# 每5s刷新一次

convert(){
  r=$1
  if [[ $r -le 1024 ]];then
	r=$r" B"
	echo $r
  elif [[ $r -ge 1024*1024*1024 ]];then
	r=$(echo $r|awk '{print $1/1024/1024/1024" GB"}')
	echo $r
  elif [[ $r -ge 1024*1024 ]];then
	r=$(echo $r|awk '{print $1/1024/1024" MB"}')
	echo $r
  else 
	r=$(echo $r|awk '{print $1/1024" KB"}')
	echo $r
  fi
}

cpuinfo=$(awk -F: '/model name/{m[$1]=$2}
       /MHz/{m[$1]=$2}
       /cache size/{m[$1]=$2}
       END{for (i in m){printf "%s:%s\\n", i,m[i] }}' /proc/cpuinfo|sort)

net_path="/root/network_traffic/rxtx.txt"
start_time_path="/root/network_traffic/record_start_time.txt"

while :
do
  meminfo=$(free -m|awk '/Mem/{printf "Mem Total: %s MB\\nMem used: %s MB",$2,$3}')
  diskinfo=$(df -h|awk '/vda1/{printf "disk Total: %s\\ndisk Used: %s", $2, $3}')
  rxtx=$(cat $net_path)
  rx=$(echo $rxtx|cut -d " " -f 1)
  tx=$(echo $rxtx|cut -d " " -f 2)
  rx=`convert $rx`
  tx=`convert $tx`

  start_time=`[[ -f $start_time_path ]] && cat $start_time_path`

  echo -e "$cpuinfo"
  echo -e "$meminfo"
  echo -e "$diskinfo"
  echo -e "流量统计开始时间:${start_time:-undefined}"
  echo "rx: $rx"
  echo "tx: $tx"
  echo ==========
  sleep 5s
done
