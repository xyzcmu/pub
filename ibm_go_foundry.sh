#!/usr/bin/env bash

# 先创建 IBM cloud 账号,登录进去,点击IBM Cloud shell 
# 创建资源,选择cloud foundry,公共应用,创建
# 选择 dalas, 选择 go语言, 输入应用名称, 点击创建
# 进入到 Cloud shell,后,执行该脚本,最后获得vmess链接

# 加速
# 登录 cloudflare 选择 worker, 复制如下内容:
# addEventListener(
# "fetch",event => {
# let url=new URL(event.request.url);
# url.hostname="你的应用名称.us-south.cf.appdomain.cloud";
# let request=new Request(url,event.request);
# event. respondWith(
# fetch(request)
# )
# }
# )
# 获得 cloudflare 提供给你的 网址
# 将该网址 填入 服务器地址栏 和 TLS设置里的服务器栏
# ws 协议块中的请求头: HOST 该网址

# 自选 cloudflare ip 加速(https://github.com/badafans/better-cloudflare-ip)
# 将 获取到的比较快的ip 填入上面的 服务器地址栏 即可.


SH_PATH=$(cd "$(dirname "$0")";pwd)
cd ${SH_PATH}

create_mainfest_file(){
    echo "进行配置。。。"
    read -p "请输入你的应用名称：" IBM_APP_NAME
    echo "应用名称：${IBM_APP_NAME}"
    read -p "请输入你的应用内存大小(默认256)：" IBM_MEM_SIZE
    if [ -z "${IBM_MEM_SIZE}" ];then
    IBM_MEM_SIZE=256
    fi
    echo "内存大小：${IBM_MEM_SIZE}"
    UUID=$(cat /proc/sys/kernel/random/uuid)
    echo "生成随机UUID：${UUID}"
    WSPATH=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
    echo "生成随机WebSocket路径：${WSPATH}"
    
    cat >  ${SH_PATH}/IBMVPS/v2ray-cloudfoundry/manifest.yml  << EOF
    applications:
    - path: .
      name: ${IBM_APP_NAME}
      random-route: true
      memory: ${IBM_MEM_SIZE}M
EOF

    cat >  ${SH_PATH}/IBMVPS/v2ray-cloudfoundry/v2ray/config.json  << EOF
    {
        "inbounds": [
            {
                "port": 8080,
                "protocol": "vmess",
                "settings": {
                    "clients": [
                        {
                            "id": "${UUID}",
                            "alterId": 6
                        }
                    ]
                },
                "streamSettings": {
                    "network":"ws",
                    "wsSettings": {
                        "path": "${WSPATH}"
                    }
                }
            }
        ],
        "outbounds": [
            {
                "protocol": "freedom",
                "settings": {}
            }
        ]
    }
EOF
    echo "配置完成。"
}

clone_repo(){
    echo "进行初始化。。。"
    rm -rf IBMVPS
    rm -rf IBMyes
    git clone https://github.com/bigfangfang/IBMVPS
    cd IBMVPS
    git submodule update --init --recursive
    cd v2ray-cloudfoundry/v2ray
    # Upgrade V2Ray to the latest version
    rm v2ray v2ctl
    
    # Script from https://github.com/v2fly/fhs-install-v2ray/blob/master/install-release.sh
    # Get V2Ray release version number
    TMP_FILE="$(mktemp)"
    if ! curl -s -o "$TMP_FILE" 'https://api.github.com/repos/v2fly/v2ray-core/releases/latest'; then
        rm "$TMP_FILE"
        echo 'error: 获取最新V2Ray版本号失败。请重试'
        exit 1
    fi
    RELEASE_LATEST="$(sed 'y/,/\n/' "$TMP_FILE" | grep 'tag_name' | awk -F '"' '{print $4}')"
    rm "$TMP_FILE"
    echo "当前最新V2Ray版本为$RELEASE_LATEST"
    # Download latest release
    DOWNLOAD_LINK="https://github.com/v2fly/v2ray-core/releases/download/$RELEASE_LATEST/v2ray-linux-64.zip"
    if ! curl -L -H 'Cache-Control: no-cache' -o "latest-v2ray.zip" "$DOWNLOAD_LINK"; then
        echo 'error: 下载V2Ray失败，请重试'
        return 1
    fi
    unzip latest-v2ray.zip v2ray v2ctl geoip.dat geosite.dat
    rm latest-v2ray.zip
    
    chmod 0755 ./*
    cd ${SH_PATH}/IBMVPS/v2ray-cloudfoundry
    echo "初始化完成。"
}

install(){
    echo "进行安装。。。"
    cd ${SH_PATH}/IBMVPS/v2ray-cloudfoundry
    ibmcloud target --cf
    ibmcloud cf install
    ibmcloud cf push
    echo "安装完成。"
    echo "生成的随机 UUID：${UUID}"
    echo "生成的随机 WebSocket路径：${WSPATH}"
    VMESSCODE=$(base64 -w 0 << EOF
    {
      "v": "2",
      "ps": "IBM",
      "add": "${IBM_APP_NAME}.us-south.cf.appdomain.cloud",
      "port": "443",
      "id": "${UUID}",
      "aid": "6",
      "net": "ws",
      "type": "none",
      "host": "",
      "path": "${WSPATH}",
      "tls": "tls"
    }
EOF

    )
	echo "配置链接："
    echo vmess://${VMESSCODE}

}

clone_repo
create_mainfest_file
install
exit 0