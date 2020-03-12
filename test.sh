#!/usr/bin/env bash

echo "测试换行符是否影响脚本运行"

read -p "是否执行更新 [y/n]" isExe

if [[ $isExe == "y" ]];then
echo "执行更新....."
apt-get update && apt-get upgrade
else
echo "不更新..."
fi
echo "通过vscode修改过..."
exit 0
