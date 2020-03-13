#!/usr/bin/env bash

# 配置 Gmail 用于发送邮件
# 先去申请 google账号 --> 安全性 --> 应用专用密码
echoColor() {
  echo -e "\033[$1m $2 \033[0m"
}

echoColor 34 "==== 设置 Gmail ===="
echoColor 33 "拥有Gmail 应用专用密码? [y/n]"
read hasCode
if [[ $hasCode != 'y' ]];then
  echoColor 34 "请去 google账号-->安全性-->应用专用密码 生成"
  exit 1
else
  while :;do
  echoColor 33 "请输入你的 Gmail账号: "
  read your_email
  echoColor 33 "请输入 专用密码:"
  read your_code
  echoColor 34 "你的邮箱: $your_email;专用密码: $your_code"
  echoColor 33 "以上信息是否正确 ? [y/n]"
  read isOk
  if [[ $isOk == 'y' ]];then
    break
  fi
  done
  apt-get install heirloom-mailx
  cat >> /etc/s-nail.rc << EOF
  set from=$your_email
  set smtp=smtps://smtp.gmail.com:465
  set smtp-auth=login
  set smtp-auth-user=$your_email
  set smtp-auth-password=$your_code
  set ssl-verify=ignore
  set nss-config-dir=/etc/pki/nssdb/
EOF
  echoColor 34 "s-nail 安装完成!"
  echoColor 34 "一般用法:　s-nail -s 主题 -a /path/some.file xxx@email.com < /path/some.file"
  echoColor 34 "一般用法:　echo 内容 | s-nail -s 主题 -a /path/some.file xxx@email.com"
fi
