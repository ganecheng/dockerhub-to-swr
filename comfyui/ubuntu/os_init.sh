#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 启动命令
chmod 777 /run.sh

# 应用目录
mkdir -pv /default_comfyui_bundle

# 软件安装
apt-get update && apt-get install -y vim git git-lfs net-tools tree curl wget python3 python3-pip

ln -s /usr/bin/python3 /usr/bin/python

# 清理无用文件
sh /os_clean.sh