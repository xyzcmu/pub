#!/usr/bin/env bash

# 获取使用的网卡名
net_name=$(ip route show 2>/dev/null | awk '/default via/{print $5}')
[[ $net_name == "" ]] && {
  read -p "请手动输入网卡名称:" nn
  net_name=$nn
}

pwd_path=$(cd $(dirname $0) && pwd)
is_reboot=
last_reboot_path="${pwd_path}/last_reboot.txt"
cur=$(date -d "$(last reboot|awk 'NR==1{print $5,$6,$7,$8}')" "+%Y-%m-%d %H:%M:%S")

checkReboot() {
  if [[ -f ${last_reboot_path} ]];then
	lst=`cat ${last_reboot_path}`
	[[ $lst == $cur ]] && is_reboot="false" || {
      is_reboot="true"
      echo $cur > $last_reboot_path
    }
  else
    is_reboot="false"
    echo "$cur" > $last_reboot_path
  fi
}

checkReboot

rx=
tx=
start_time="$cur"

last_net_statistics_path="${pwd_path}/last_net_statistics.txt"
cur_net_statistics_path="${pwd_path}/net_statistics.txt"

[[ $is_reboot == "true" ]] && [[ -f $cur_net_statistics_path ]] && cp ${cur_net_statistics_path} ${last_net_statistics_path}

if [[ -f $last_net_statistics_path ]];then
  info=`<$last_net_statistics_path`
  rx=`awk -v FS="[:,]" '/rxtx/{print $2}' <<< "$info"`
  tx=`awk -v FS="[:,]" '/rxtx/{print $3}' <<< "$info"`
  start_time=`echo "$info"|grep -P -o '(?<=start_time:).*'`
fi
while :
do
  awk -v start="$start_time" 'NR>2 && $1 ~ "'$net_name'"{printf "start_time:%s\nrxtx:%.f,%.f\n",start,$2+"'$rx'",$10+"'$tx'" > "'${cur_net_statistics_path}'"}' /proc/net/dev
  sleep 3s
done

