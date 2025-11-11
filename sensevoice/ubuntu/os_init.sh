#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 启动命令
chmod 777 /run.sh

# 应用目录
mkdir -pv /app
cd /app

# 软件安装
apt-get update && \
DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata && \
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
echo "Asia/Shanghai" > /etc/timezone

apt-get install -y git git-lfs net-tools tree curl wget python3 python3-pip python3-venv ffmpeg
