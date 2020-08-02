#!/usr/bin/env bash

is_reboot=
last_reboot_path="/root/last_reboot.txt"
cur=`last reboot|awk 'NR==1{print $5,$6,$7,$8}'`

checkReboot() {
  if [[ -f ${last_reboot_path} ]];then
	lst=`cat ${last_reboot_path}`
	[[ $lst == $cur ]] && is_reboot="false" || is_reboot="true";echo $cur > $last_reboot_path
  else
    is_reboot="false"
  fi
}

checkReboot

rx=
tx=
start_time="$cur"

last_net_statistics_path="/root/last_net_statistics.txt"
cur_net_statistics_path="/root/net_statistics.txt"

[[ $is_reboot == "true" ]] && cp ${cur_net_statistics_path} ${last_net_statistics_path}

if [[ -f $last_net_statistics_path ]];then
  info=`<$last_net_statistics_path`
  rx=`awk -v FS="[:,]" '/rxtx/{print $2}' <<< "$info"`
  tx=`awk -v FS="[:,]" '/rxtx/{print $3}' <<< "$info"`
  start_time=`echo "$info"|awk -v FS="[:,]" '/start_time/{printf "%s:%s",$2,$3}'`
fi

while :
do
  awk -v start="$start_time" 'NR>2 && $1 !~ /lo:/{printf "start_time:%s\nrxtx:%.f,%.f\n",start,$2+"'$rx'",$10+"'$tx'" > "'${cur_net_statistics_path}'"}' /proc/net/dev 
  #awk 'NR>2 && $1 !~ /lo:/{printf "rxtx:%.f,%.f\n", $2+rx, $10+tx > "'${cur_net_statistics_path}'"}' /proc/net/dev 
  sleep 3s
done

