#!/usr/bin/env bash
yellow(){
  echo -e "\033[33m\033[01m[ $1 ]\033[0m"
}

# 获取 安装脚本
sh_path='https://moeclub.org/attachment/LinuxShell/InstallNET.sh'
wget --no-check-certificate --spider --timeout=3 -o /dev/null $sh_path
[[ $? == 0 ]] || sh_path='https://raw.githubusercontent.com/xyzcmu/pub/master/backup/sysInstallNet.sh'

wget --no-check-certificate -qO InstallNET.sh $sh_path && chmod a+x InstallNET.sh

mirror_addr="http://ftp.us.debian.org/debian/"

yellow "默认 root 密码是:uMiss233"
echo "默认镜像地址是:$mirror_addr"
read -p "是否使用默认镜像?　[y/n]" isDef
if [[ $isDef == "n" ]];then
  echo -e "镜像源:\n\t1.香港\n"
  read -p "输入你的选择: " num
  if [[ $num == "1" ]];then
    mirror_addr="http://ftp.hk.debian.org/debian/"
  else
    echo "输入的数字不在选择列表中..."
    exit 1
  fi
elif [[ $isDef == "y" || $isDef == "" ]];then
  :
else 
  echo "输入错误..."
  exit 1
fi
echo "安装使用的镜像源地址是: $mirror_addr"
echo "安装过程大约30分钟,根据vps性能不同有所差异..."
echo "安装好之后,记得修改密码哦!"
yellow "3s后,开始安装..."
yellow "3..."
sleep 1
yellow "2..."
sleep 1
yellow "1..."
sleep 1
bash InstallNET.sh -p uMiss233 -d 9 -v 64 -a --mirror "$mirror_addr"
