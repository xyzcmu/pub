#!/usr/bin/env bash
# 基于 debian9 
# 安装系统必要的软件,配置trojan(可选项),其中证书文件和私钥
# 需要手动上传到本机的指定位置,下面有提示.

# echo 颜色显示函数
yellow(){
  echo -e "\033[33m\033[01m[ $1 ]\033[0m"
}

bred(){
    echo -e "\033[31m\033[01m[ $1 ]\033[0m"
}

# 设置镜像源地址列表
cat >> /etc/apt/sources.list << EOF
deb http://deb.debian.org/debian/ stretch main
deb-src http://deb.debian.org/debian/ stretch main
deb http://security.debian.org/ stretch/updates main
deb-src http://security.debian.org/ stretch/updates main
deb http://deb.debian.org/debian/ stretch-updates main
deb-src http://deb.debian.org/debian/ stretch-updates main
EOF


# 设置 vi 显示行号和tab缩进4个字符
cat >> ~/.vimrc << EOF
set nu
set ts=4
EOF

# 设置上海时间和硬件时间
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc

# 开启 BBR
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# 更新软件信息并升级软件 安装常用software
apt-get update && apt-get upgrade &&
apt-get -y install curl psmisc lsb-release net-tools lsof tree dos2unix xz-utils &&


yellow "Debian9常用软件和设置已经配置好了!"

# 是否安装 trojan
read -p "是否要安装trojan? [y/n]" installTro
if [[ $installTro != "y" ]];then
  exit 0
fi

isTrue="true"

while [[ $isTrue == "true" ]];do
  bred "请确认你的域名以可以正常解析(ping your_domain.com)"
  read -p "是否正常解析好了? [y/n]" domainOk
  if [[ $domainOk == "y" -o $domainOk == "Y" ]];then
    isTrue="false"
  else
    echo "你先去解析好域名再来!"  
  fi
sleep 2
done


# 安装 nginx 并设置开机启动
apt-get install nginx && systemctl enable nginx.service &&
read -p "请输入你的域名:" your_domain

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
rm -rf /usr/share/nginx/html/* &&
cd /usr/share/nginx/html/
wget --no-check-certificate "$my_web" &&
tar -xJf *.tar.xz &&
systemctl restart nginx.service

# 下载 trojan 服务端
cd /usr/src

version=$(curl -o trojan.info https://github.com/trojan-gfw/trojan/releases && cat trojan.info | grep -m 1 -E '<a href.*release.*\/a>'|
sed -r 's/<a href.*tag\/v(.*)\".*a>/\1/'|sed 's/[[:space:]]//g')

rm trojan.info

if [[ -n $version ]];then
  bred "开始下载trojan服务端..."
  wget --no-check-certificate https://github.com/trojan-gfw/trojan/releases/download/v$version/trojan-$version-linux-amd64.tar.xz
  echo "trojan服务端下载成功!"  
else
  echo "获取trojan版本号失败!"
fi

tar -xJf trojan-*.tar.xz

cert="/usr/src/trojan-cert/fullchain.cer"
key="/usr/src/trojan-cert/private.key"
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

bred "请将 ssl证书和私钥 改好名字放置到指定位置"
bred "若还没有证书,去申请... 参考--　https://freessl.cn＂
bred "ssl证书: $cert"
bred "私钥: $key"

read -p "是否已经放到指定位置? [y/n]" isRead

if [ $isRead == "y" -o $isRead == "Y"];then
  # 启动服务端
  # 设置开机启动
  systemctl start trojan.service
  systemctl enable trojan.service
fi

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
yellow "双击 trojan-start.bat trojan客户端将运行在1080端口..."

exit 0