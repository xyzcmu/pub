#!/usr/bin/env bash
# 将网卡流量(接受,发送) 写入到rxtx.txt中,避免vps重启后网卡流量重置为零
# 每3s写一次

[[ -d /root/network_traffic ]] || mkdir -p /root/network_traffic

isReboot=""
lsReboot="/root/network_traffic/last_reboot.txt"
net_usage="/root/network_traffic/rxtx.txt"
start_time="/root/network_traffic/record_start_time.txt"

lst=""
cur=$(last reboot|awk 'NR == 1{print $5,$6,$7,$8}')

checkReboot(){
  if [[ -f $lsReboot ]];then
    lst=`cat $lsReboot`
    [[ $lst == $cur ]] && isReboot="false" || isReboot="true";echo $cur > $lsReboot
  else
    isReboot="false"
    echo $cur > $lsReboot
  fi
}

setStartTime(){
  [[ $isReboot == "false" ]] && echo $cur > $start_time || echo $lst > $start_time
}

checkReboot
setStartTime

last_usage="/root/network_traffic/last_usage.txt"

if [[ -f $net_usage ]] && [[ $isReboot == "true" ]];then
  cp $net_usage $last_usage 
else
  rx=0
  tx=0
fi

if [[ -f $last_usage ]];then
  rx=`cut -d " " -f 1 $last_usage`
  tx=`cut -d " " -f 2 $last_usage`
fi

while :
do
  netcard=`ifconfig|grep -v lo|grep -Po '^[[:alpha:]].*?(?=:)'`
  grep $netcard /proc/net/dev | awk '{print $2+"'$rx'",$10+"'$tx'"}' > $net_usage
  sleep 3s
done
