#!/usr/bin/env bash
# ���� debian9 
# ��װϵͳ��Ҫ�����,����trojan(��ѡ��),����֤���ļ���˽Կ
# ��Ҫ�ֶ��ϴ���������ָ��λ��,��������ʾ.

# echo ��ɫ��ʾ����
yellow(){
  echo -e "\033[33m\033[01m[ $1 ]\033[0m"
}

bred(){
    echo -e "\033[31m\033[01m[ $1 ]\033[0m"
}

# ���þ���Դ��ַ�б�
cat >> /etc/apt/sources.list << EOF
deb http://deb.debian.org/debian/ stretch main
deb-src http://deb.debian.org/debian/ stretch main
deb http://security.debian.org/ stretch/updates main
deb-src http://security.debian.org/ stretch/updates main
deb http://deb.debian.org/debian/ stretch-updates main
deb-src http://deb.debian.org/debian/ stretch-updates main
EOF


# ���� vi ��ʾ�кź�tab����4���ַ�
cat >> ~/.vimrc << EOF
set nu
set ts=4
EOF

# �����Ϻ�ʱ���Ӳ��ʱ��
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc

# ���� BBR
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# ���������Ϣ��������� ��װ����software
apt-get update && apt-get upgrade &&
apt-get -y install curl psmisc lsb-release net-tools lsof tree dos2unix xz-utils &&


yellow "Debian9��������������Ѿ����ú���!"

# �Ƿ�װ trojan
read -p "�Ƿ�Ҫ��װtrojan? [y/n]" installTro
if [[ $installTro != "y" ]];then
  exit 0
fi

isTrue="true"

while [[ $isTrue == "true" ]];do
  bred "��ȷ����������Կ�����������(ping your_domain.com)"
  read -p "�Ƿ�������������? [y/n]" domainOk
  if [[ $domainOk == "y" -o $domainOk == "Y" ]];then
    isTrue="false"
  else
    echo "����ȥ��������������!"  
  fi
sleep 2
done


# ��װ nginx �����ÿ�������
apt-get install nginx && systemctl enable nginx.service &&
read -p "�������������:" your_domain

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

# ���� trojan-webվ�� ���� nginx
my_web=https://github.com/xyzcmu/pub/releases/download/static-web/static-web-demo.tar.xz
rm -rf /usr/share/nginx/html/* &&
cd /usr/share/nginx/html/
wget --no-check-certificate "$my_web" &&
tar -xJf *.tar.xz &&
systemctl restart nginx.service

# ���� trojan �����
cd /usr/src

version=$(curl -o trojan.info https://github.com/trojan-gfw/trojan/releases && cat trojan.info | grep -m 1 -E '<a href.*release.*\/a>'|
sed -r 's/<a href.*tag\/v(.*)\".*a>/\1/'|sed 's/[[:space:]]//g')

rm trojan.info

if [[ -n $version ]];then
  bred "��ʼ����trojan�����..."
  wget --no-check-certificate https://github.com/trojan-gfw/trojan/releases/download/v$version/trojan-$version-linux-amd64.tar.xz
  echo "trojan��������سɹ�!"  
else
  echo "��ȡtrojan�汾��ʧ��!"
fi

tar -xJf trojan-*.tar.xz

cert="/usr/src/trojan-cert/fullchain.cer"
key="/usr/src/trojan-cert/private.key"
read -p "����trojan���������:" trojan_psw

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

# trojan���������ļ�
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

bred "�뽫 ssl֤���˽Կ �ĺ����ַ��õ�ָ��λ��"
bred "����û��֤��,ȥ����... �ο�--��https://freessl.cn��
bred "ssl֤��: $cert"
bred "˽Կ: $key"

read -p "�Ƿ��Ѿ��ŵ�ָ��λ��? [y/n]" isRead

if [ $isRead == "y" -o $isRead == "Y"];then
  # ���������
  # ���ÿ�������
  systemctl start trojan.service
  systemctl enable trojan.service
fi

# trojan�ͻ���
trojan_cli="https://github.com/trojan-gfw/trojan/releases"

bred "�뵽 ${trojan_cli} ���ض�Ӧ�Ŀͻ���"

read -p "�Ƿ�Ҫ����trojan�ͻ������� bat�ļ�? [y/n]" isBat

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
bred "�뽫 /root/trojan-cli-bat/ Ŀ¼�µ�����bat�ļ�, ������ trojan.exe ͬ��Ŀ¼��" 
fi

yellow "�޸�trojan�ͻ��˵� config.json �ļ�"
yellow "�޸� remote_addr:${your_domain} �� password:${trojan_psw}"
yellow "˫�� trojan-start.bat trojan�ͻ��˽�������1080�˿�..."

exit 0