#!/usr/bin/env bash
yellow(){
  echo -e "\033[33m\033[01m[ $1 ]\033[0m"
}

# ��װ debian9 �ٷ�ISO
wget --no-check-certificate -qO InstallNET.sh 'https://moeclub.org/attachment/LinuxShell/InstallNET.sh' && chmod a+x InstallNET.sh

mirror_addr="http://ftp.hk.debian.org/debian/"

echo "Ĭ�Ͼ����ַ��:http://ftp.hk.debian.org/debian/"
read -p "�Ƿ�ʹ��Ĭ�Ͼ���?��[y/n]" isDef
if [[ $isDef != "y" ]];then
  read -p "�����뾵���ַ:" mirror_addr
fi
echo "��װ���̴�Լ30����,����vps���ܲ�ͬ��������..."
echo "Ĭ�� root ������:MoeClub.org"
echo "��װ��֮��,�ǵ��޸�����Ŷ!"
yellow "5s��,��ʼ��װ..."
sleep 5
bash InstallNET.sh -d 9 -v 64 -a --mirror "$mirror_addr"