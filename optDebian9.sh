#!/usr/bin/env bash

# 基于 debian9 
# 安装系统必要的软件,配置trojan(可选项)

# echo 颜色显示函数
yellow(){
  echo -e "\033[33m\033[01m[ $1 ]\033[0m"
}

bred(){
    echo -e "\033[31m\033[01m[ $1 ]\033[0m"
}


commonSet() {
# 设置镜像源地址列表
cat > /etc/apt/sources.list << EOF
deb http://ftp.hk.debian.org/debian/ stretch main
deb-src http://ftp.hk.debian.org/debian/ stretch main
deb http://deb.debian.org/debian/ stretch main
deb-src http://deb.debian.org/debian/ stretch main
deb http://security.debian.org/ stretch/updates main
deb-src http://security.debian.org/ stretch/updates main
deb http://deb.debian.org/debian/ stretch-updates main
deb-src http://deb.debian.org/debian/ stretch-updates main
EOF

# 设置 vi 显示行号和tab缩进4个字符
if [[ -z $(grep "set nu" ~/.vimrc) && -z $(grep "set ts=4" ~/.vimrc) ]];then
cat >> ~/.vimrc << EOF
set nu
set ts=4
EOF
fi

# 设置别名 ll
if [[ -z $(grep "^alias ll=" ~/.bashrc) ]];then
cat >> ~/.bashrc << EOF
alias ll='ls -l --color'
EOF
source ~/.bashrc
fi

# 设置上海时间和硬件时间
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc

# 开启 BBR
[[ -z $(grep "net.core.default_qdisc=fq" /etc/sysctl.conf) ]] && echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
[[ -z $(grep "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf) ]] && echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 更新软件信息并升级软件 安装常用software
apt-get update && apt-get upgrade
apt-get -y install curl psmisc lsb-release net-tools lsof tree dos2unix xz-utils

yellow "Debian9常用软件和设置已经配置好了!"
}


checkDomain() {
while :;do
  bred "请确认你的域名以可以正常解析[ping your_domain.com]"
  read -p "是否正常解析好了? [y/n]" domainOk
  if [[ $domainOk == "y" ]];then
    break
  else
    echo "你先去解析好域名再来!"  
  fi
sleep 2
done
read -p "请输入你的域名:" your_domain
}


nginxStaticWeb() {
# 安装 nginx 并设置开机启动
apt-get install nginx && systemctl enable nginx.service

cat > /etc/nginx/nginx.conf << EOF
user  root;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    server {
        listen       80;
        server_name  $your_domain;
        root /usr/share/nginx/html;
        index index.php index.html index.htm;
    }
}
EOF

# 设置 trojan-web站点 重启 nginx
my_web=https://github.com/xyzcmu/pub/releases/download/static-web/static-web-demo.tar.xz
rm -rf /usr/share/nginx/html/*
cd /usr/share/nginx/html/
wget --no-check-certificate "$my_web"
tar -xJf *.tar.xz
systemctl restart nginx.service
}


applySSL() {
# 证书和私钥 位置
cert="/usr/src/trojan-cert/fullchain.cer"
key="/usr/src/trojan-cert/private.key"
mkdir /usr/src/trojan-cert

# 通过 acme.sh 申请证书
# 证书来自 Let's Encrypt 有效期 90天
# 到期 自动更新
# 也可手动强制续签 	acme.sh --renew -d 域名 --force
# acme.sh --help
curl https://get.acme.sh | sh
source ~/.bashrc

# 证书签发成功后,放在 /root/.acme.sh/your_domain目录下
/root/.acme.sh/acme.sh --issue -d $your_domain -w /usr/share/nginx/html/
if [[ $? == 0 ]];then
yellow "证书签发成功!"
else
yellow "证书签发失败!"
return 1
fi

# 自动更新 acme.sh
/root/.acme.sh/acme.sh  --upgrade  --auto-upgrade

# 安装证书(通过拷贝的方式放到相应目录)
# 重启 nginx
/root/.acme.sh/acme.sh --installcert -d $your_domain \
--key-file $key \
--fullchain-file $cert \
--reloadcmd "nginx -s reload"
}


getLatestVer() {
# 下载最新版本 trojan服务端
cd /usr/src
cur_ver=""
[[ -f trojan.version ]] && cur_ver=`cat trojan.ver`

version=$(curl -o trojan.info https://github.com/trojan-gfw/trojan/releases && cat trojan.info | grep -m 1 -E '<a href.*release.*\/a>'|
sed -r 's/<a href.*tag\/v(.*)\".*a>/\1/'|sed 's/[[:space:]]//g')

bred "---查询到trojan最新版本$version---"
sleet 3s

if [[ "$version" != "$cur_ver" ]];then
  echo "$version" > trojan.ver
  bred "开始下载trojan服务端..."
  wget --no-check-certificate https://github.com/trojan-gfw/trojan/releases/download/v$version/trojan-$version-linux-amd64.tar.xz &&
  echo "trojan服务端下载成功!"  
else
  echo "当前trojan已经是最新版本!"
fi

tar -xJf trojan-$version-linux-amd64.tar.xz
}


trojanServer() {
# 下载 最新trojan 服务端
getLatestVer

read -p "输入trojan服务端密码:" trojan_psw

cat > /usr/src/trojan/server.conf << EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "$trojan_psw"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "$cert",
        "key": "$key",
        "key_password": "",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	"prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": ""
    }
}
EOF

# trojan服务配置文件
cat > /lib/systemd/system/trojan.service << EOF
[Unit]  
Description=trojan  
After=network.target  
   
[Service]  
Type=simple  
PIDFile=/usr/src/trojan/trojan/trojan.pid
ExecStart=/usr/src/trojan/trojan -c "/usr/src/trojan/server.conf"  
ExecReload=  
ExecStop=/usr/src/trojan/trojan  
PrivateTmp=true  
   
[Install]  
WantedBy=multi-user.target
EOF

 # 启动服务端
 # 设置开机启动
 systemctl start trojan.service
 systemctl enable trojan.service
}


trojanCli() {
# trojan客户端
trojan_cli="https://github.com/trojan-gfw/trojan/releases"

bred "请到 ${trojan_cli} 下载对应的客户端"

read -p "是否要创建trojan客户端启动 bat文件? [y/n]" isBat

if [[ $isBat == "y" ]];then
mkdir /root/trojan-cli-bat
cat > /root/trojan-cli-bat/trojan-start.bat << EOF
@ECHO OFF
%1 start mshta vbscript:createobject("wscript.shell").run("""%~0"" ::",0)(window.close)&&exit
start /b trojan.exe
EOF
cat > /root/trojan-cli-bat/trojan-stop.bat << EOF
@ECHO OFF
taskkill /im trojan.exe /f
ping -n 2 127.1 >nul
EOF
bred "请将 /root/trojan-cli-bat/ 目录下的两个bat文件, 拷贝到 trojan.exe 同个目录下" 
fi

yellow "修改trojan客户端的 config.json 文件"
yellow "修改 remote_addr:${your_domain} 和 password:${trojan_psw}"
yellow "手动启动trojan客户端 将运行在1080端口..."
}


changeSshPort() {
# 查找当前端口
sshfile="/etc/ssh/sshd_config"
[[ -z "`grep ^Port $sshfile`" ]] && ssh_port=22 || ssh_port=`grep ^Port $sshfile | awk '{print $2}'`
while :;do
read -p "请输入新的ssh端口[当前--$ssh_port]:" newport
# 检测 端口范围 不能是 22, 且在 1025-65534 之间
if [[ $newport != 22 && $newport -gt 1024 && $newport -lt 65535 ]];then
# 检测 端口 是否被占用
if [[ -z "`lsof -i:$newport`" ]];then
break
else
echo "$newport 被占用!"
fi
else
echo "端口不能是22, 且不在 1025-65534 之间"
fi
done
# 修改
if [[ "`grep ^Port $sshfile`" ]];then
sed -i "s/^Port.*/Port $newport/" $sshfile
elif [[ "`grep ^#Port /etc/ssh/sshd_config`" ]];then
sed -i "s/^#Port.*/&\nPort $newport/" $sshfile
fi
# 重启服务
systemctl restart ssh
yellow "新的ssh端口: $newport 已生效!"
}


installTrojan() {
checkDomain

nginxStaticWeb

applySSL && trojanServer && trojanCli
}


reInstallVim() {
apt-get -y remove --purge vim vim-runtime vim-tiny vim-common vim-scripts vim-doc
apt-get -y install vim
}


main() {
# 菜单选项
opts[0]="退出"
opts[1]="设置镜像源地址(hk) 开启BBR 时间校准 常用软件,建议重装系统后执行一次"
opts[2]="安装trojan服务端 设置静态站点"
opts[3]="更新trojan服务端"
opts[4]="修改ssh 端口"
opts[5]="卸载系统自带的 vim-tiny, 安装 VIM"

ifs_old=$IFS
export IFS=$''
export PS3="根据提示,输入你的选择: "

select opt in ${opts[@]}
do
  case $REPLY in
    "1")
      break
      ;;
    "2")
      commonSet
      break
      ;;
    "3")
      installTrojan
      break
      ;;
    "4")
      systemctl stop trojan.service      
      getLatestVer
      # 启动服务端
      # 设置开机启动
      systemctl start trojan.service
      systemctl enable trojan.service
      break
      ;;
    "5")
      changeSshPort
      break
      ;;
    "6")
      reInstallVim
      break
      ;;
    *)
      echo 输入无效
  esac
done
IFS=$ifs_old
exit 0
}


main
