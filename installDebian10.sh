#!/usr/bin/env bash
yellow(){
  echo -e "\033[33m\033[01m[ $1 ]\033[0m"
}

# 安装 debian10 官方ISO
wget --no-check-certificate -qO InstallNET.sh 'https://moeclub.org/attachment/LinuxShell/InstallNET.sh' && chmod a+x InstallNET.sh

mirror_addr="http://ftp.hk.debian.org/debian/"

yellow "默认 root 密码是:uMiss233"
echo "默认镜像地址是:$mirror_addr"
read -p "是否使用默认镜像?　[y/n]" isDef
if [[ $isDef != "y" ]];then
  read -p "请输入镜像地址:" mirror_addr
  if [[ ! $mirror_addr =~ http://ftp\.[a-z]+\.debian\.org/debian/ ]];then
        echo "输入的地址有误..."
    exit 1
  fi
fi
echo "安装过程大约30分钟,根据vps性能不同有所差异..."
echo "安装好之后,记得修改密码哦!"
yellow "3s后,开始安装..."
yellow "3..."
sleep 1
yellow "2..."
sleep 1
yellow "1..."
sleep 1
bash InstallNET.sh -p uMiss233 -d 10 -v 64 -a --mirror "$mirror_addr"
