#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 启动命令
chmod 777 /run.sh

# 应用目录
mkdir -pv /app
cd /app

# 软件安装（基础依赖已在 ubuntu 镜像中提供）
apt-get update && apt-get install -y ffmpeg
