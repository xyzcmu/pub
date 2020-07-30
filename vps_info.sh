#!/usr/bin/env bash

# 查看 cpu名称/频率/缓存大小,硬盘,内存,网卡流量 使用情况
# 将结果写入 html 文件

# 每10s刷新一次
sleep_time="10s"
# 网卡rxtx 信息
net_path="/root/network_traffic/rxtx.txt"
# 流量记录 开始时间
start_time_path="/root/network_traffic/record_start_time.txt"

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

cpu_model=`awk -F: '/model name/{print $2}' /proc/cpuinfo`
cpu_hz=`awk -F: '/MHz/{print $2}' /proc/cpuinfo`
cpu_cache=`awk -F: '/cache size/{print $2}' /proc/cpuinfo`
cpu_cores=`awk -F: '/cpu cores/{print $2}' /proc/cpuinfo`

createHTML(){

  local html_path="/usr/share/nginx/html/vps_info.html"

  before_body='
  <html>
  <head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0">
	<meta http-equiv="X-UA-Compatible" content="ie=edge">
	<title>vps硬件使用情况</title>
  </head>
  <style>
  body {
	background: darkgray;
	font-size: 22px;
    margin: 0;
    padding: 0;
  }
  .box {
	position: absolute;
	top: 50%;
	left: 50%;
	transform: translate(-50%, -50%);
	border: 6px solid #232323;
	border-radius: 30px;
  }
  div {
    padding: 5px;
  }
  </style>

  <body>
  '

  body="<div class=\"box\">
  <div>cpu_model: ${1}</div>
  <div>cpu_cores: ${4}</div>
  <div>cpu_MHz: ${2}</div>
  <div>cpu_cache: ${3}</div>
  <div>cpu_used: ${12}%</div><hr />
  <div>mem_total: $5</div>
  <div>mem_used: ${6}</div><hr />
  <div>disk_total: ${7}</div>
  <div>disk_used: ${8}</div><hr />
  <div>流量统计时间: ${9}</div>
  <div>rx: ${10}</div>
  <div>tx: ${11}</div>
  </div>
  "

  after_body=`cat << EOF
</body>
  <script>
  window.onload=() => {
	setTimeout('window.location.reload()',10000)
  }
  </script>
</html>
EOF
` 
  html=${before_body}${body}${after_body}
  echo $html > $html_path
}


while :
do
  eval `free -m|awk '/Mem/{printf "mem_total=%sMB;mem_used=%sMB",$2,$3}'`

  eval `df -h|awk '$1~/dev\// && $2~/G$/{printf "disk_total=%s;disk_used=%s",$2,$3}'`

  eval `awk '{printf "rx=%s;tx=%s",$1,$2}' $net_path` 
  rx=`convert $rx`
  tx=`convert $tx`

  start_time=`[[ -f $start_time_path ]] && cat $start_time_path`

  cpu_used=$((100 - `vmstat 1 2|awk 'NR==4{print $(NF-2)}'`))

  echo "---每${sleep_time},刷新一次---"

  echo -e "cpu_model: $cpu_model\ncpu_cores: $cpu_cores\ncpu_MHz: $cpu_hz\ncpu_cache: $cpu_cache\ncpu_used: $cpu_used%"
  echo -e "mem_total: $mem_total\nmem_used: $mem_used"
  echo -e "disk_total: $disk_total\ndisk_used: $disk_used"

  echo -e "流量统计开始时间:${start_time:-undefined}"
  echo "rx: $rx"
  echo "tx: $tx"

  createHTML "$cpu_model" "$cpu_hz" "$cpu_cache" "$cpu_cores" "$mem_total" "$mem_used" "$disk_total" "$disk_used" "$start_time" "$rx" "$tx" "${cpu_used}"

  sleep ${sleep_time}
done
