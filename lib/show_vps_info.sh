#!/usr/bin/env bash

# 查看 cpu名称/频率/缓存大小,硬盘,内存,网卡流量 使用情况
# $1 == "-screen" 输出到命令行, 也可以通过 ip/vps_info.html 查看.
# 依赖 nginx, 若没有nginx, 自动安装.
# 将结果写入 /usr/share/nginx/html/vps_info.html 文件

#当前脚本所在路径
pwd_path=$(cd $(dirname $0) && pwd)

# 每10s刷新一次
sleep_time="10s"

# 网卡rxtx 信息
net_path="${pwd_path}/net_statistics.txt"

if [[ ! -f ${net_path} ]];then
  echo ${net_path}--Not Found.
  exit 1
fi

# 流量记录 开始时间
start_time=`awk -v FS="[:,]" '/start_time/{printf "%s:%s:%s",$2,$3,$4}' $net_path`

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

html_dir="/usr/share/nginx/html"

# curl 是否安装
curl -I -m 3 google.com > /dev/null 2>&1
rt=$?
if [[ $rt == 127 ]];then
  apt update && apt install curl -y
fi

while :
do
my_ip=$(curl -s -m 3 ipinfo.io/ip)
[[ $my_ip =~ ([0-9]+.){3}[0-9]+ ]] && break
echo "网络异常,重新获取 本机ip中 ..."
done

[[ ! -f $html_dir ]] && mkdir -p /usr/share/nginx/html

# nginx 是否安装
systemctl status nginx > /dev/null 2>&1
rt=$?
# $? == 127 systemctl命令不存在
if [[ $rt != 127 && $rt != 0 ]];then
  # install nginx
  apt update && apt insatll nginx -y
  cat > /etc/nginx/conf.d/vps_info.conf << EOF
server {
listen 80;
server_name $my_ip;
root /usr/share/nginx/html;
}
EOF
  systemctl enable nginx
  systemctl start nginx
fi


html_path="${html_dir}/vps_info.html"

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

createHTML(){
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
  <div>网络流量</div>
  <div>开始时间: ${9}</div>
  <div>当前时间: ${13}</div>
  <div>rx: ${10}</div>
  <div>tx: ${11}</div>
  </div>
  "

  html=${before_body}${body}${after_body}
  echo $html > $html_path
}

screen() {
  echo -e "cpu_model: $cpu_model\ncpu_cores: $cpu_cores\ncpu_MHz: $cpu_hz\ncpu_cache: $cpu_cache\ncpu_used: $cpu_used%"
  echo -e "mem_total: $mem_total\nmem_used: $mem_used"
  echo -e "disk_total: $disk_total\ndisk_used: $disk_used"

  #cur_time=$(date '+%Y-%m-%d %H:%M:%S')
  echo -e "流量统计开始时间:${start_time:-undefined}"
  echo "当前时间: $cur_time"
  echo "rx: $rx"
  echo "tx: $tx"
}

while :
do
  eval `free -m|awk '/Mem/{printf "mem_total=%sMB;mem_used=%sMB",$2,$3}'`

  eval `df -h|awk '$1~/dev\// && $2~/G$/{printf "disk_total=%s;disk_used=%s",$2,$3}'`

  rx=`awk -v FS="[:,]" '/rxtx/{print $2}' $net_path`
  tx=`awk -v FS="[:,]" '/rxtx/{print $3}' $net_path`
  rx=`convert $rx`
  tx=`convert $tx`

  cpu_used=$((100 - `vmstat 1 2|awk 'NR==4{print $(NF-2)}'`))

  echo "---每${sleep_time},刷新一次---"

  cur_time=$(date '+%Y-%m-%d %H:%M:%S')

  createHTML "$cpu_model" "$cpu_hz" "$cpu_cache" "$cpu_cores" "$mem_total" "$mem_used" "$disk_total" "$disk_used" "$start_time" "$rx" "$tx" "${cpu_used}" "$cur_time"
  
  echo "可通过 ${my_ip}/vps_info.html 查看vps信息"
  # 是否显示到stdout
  [[ $1 == "-screen" ]] && screen
  sleep ${sleep_time}
done
