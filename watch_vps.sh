#!/usr/bin/env bash

cur_dir=$(cd $(dirname $0) && pwd)

sh_a="https://raw.githubusercontent.com/xyzcmu/pub/master/lib/record_rxtx.sh"
sh_b="https://raw.githubusercontent.com/xyzcmu/pub/master/lib/show_vps_info.sh"

md="vps_data"
path_a="$md/a.sh"
path_b="$md/b.sh"

reg_a=${path_a:0:-3}
reg_a=${reg_a//\//\\\/}
reg_b=${path_b:0:-3}
reg_b=${reg_b//\//\\\/}

download() {
  wget --spider -q google.com &>/dev/null
  [[ $? == 127 ]] && apt update && apt install wget -y

  [[ ! -d $md ]] && mkdir $md
  rm -rf $md"/$path_a"
  rm -rf $md"/$path_b"

  wget --no-check-certificate -O $path_a $sh_a
  [[ $? == 0 ]] && chmod +x "$path_a" || echo "download $sh_a fail!"
  wget --no-check-certificate -O $path_b $sh_b
  [[ $? == 0 ]] && chmod +x "$path_b" || echo "download $sh_b fail!"
}

start() {
  [[ ! -f "$path_a" || ! -f "$path_b" ]] && download

  get_pids

  [[ $pid_a == "" ]] && { 
    ${cur_dir}"/"${path_a} &>/dev/null & 
    echo "$path_a is started..."
  } || echo "$path_a is running ..."
  sleep 1
  [[ $pid_b == "" ]] && { 
    ${cur_dir}"/"${path_b} &>/dev/null & 
    echo "$path_b is started..."
  } || echo "$path_b is running ..."
  
  echo "通过 ip[域名]/vps_info.html 查看vps使用情况"
}

get_pids() {
  pid_a=$(ps aux|awk '/'${reg_a}'/ && !/awk/{print $2}')
  pid_b=$(ps aux|awk '/'${reg_b}'/ && !/awk/{print $2}')
}

daemon() {
  crontab -l > /tmp/mycron 
  grep -q $path_a /tmp/mycron || {
    echo "@reboot sleep 2;"$cur_dir""/$path_a" &>/dev/null &" >> \
	/tmp/mycron && crontab /tmp/mycron
  }

  grep -q $path_b /tmp/mycron || {
	echo "@reboot sleep 3;"$cur_dir""/$path_b" &>/dev/null &" >> \
	/tmp/mycron && crontab /tmp/mycron
  }
  rm -rf /tmp/mycron
}

stop() {
  get_pids

  [[ $pid_a != "" ]] && kill $pid_a 
  echo "$path_a is stopped..."

  [[ $pid_b != "" ]] && kill $pid_b 
  echo "$path_b is stopped..."
}

stat() {
  get_pids
  [[ $pid_a != "" ]] && echo "$path_a ==>PID:$pid_a" || echo "$path_a is stopped..."
  [[ $pid_b != "" ]] && echo "$path_b ==>PID:$pid_b" || echo "$path_b is stopped..."
  
  echo "通过 ip[域名]/vps_info.html 查看vps使用情况"
}

uninstall() {
  stop
  
  rm -rf $cur_dir"/$md"
  rm -rf $cur_dir"/$0"

  crontab -l > /tmp/mycron && sed -i -e "/$reg_a/d" -e "/$reg_b/d" /tmp/mycron \
	&& crontab /tmp/mycron && rm -rf /tmp/mycron
  echo "$0 and its data are deleted..."
}

reset() {
  echo "reset netcard statistics,the vps will reboot." 
  read -p "reboot right now?(y/n):" ans
  [[ $ans == 'y' ]] && {
	find ${cur_dir}"/$md" -type f ! -name "*.sh"|xargs rm -rf
    echo "reboot...$(date "+%H:%M:%S")"
    reboot
  }
}

usage() {
cat << EOF
USAGE:
$0 [start][stop][stat][reset][uninstall]
EOF
}

main(){
  [[ $# > 1 ]] && echo "require one arg, but got > 1" && exit 1
  case "$1" in
    start) start;daemon;;
    stop) stop;;
    stat) stat;;
    uninstall) uninstall;;
    reset) reset;;
    *) usage;; 
  esac
}

main $@

